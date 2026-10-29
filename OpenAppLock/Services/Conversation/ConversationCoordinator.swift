import FamilyControls
import ManagedSettings
import Foundation
import Observation
import SwiftData

/// Owns shared chat, saved app identity and timestamped cross-app access outcomes.
/// Unambiguous saved names route locally before any API call; unresolved requests
/// preserve the draft and request explicit selection. Private activity records
/// capture coach decisions separately from actual outcomes, atomically with replies.
/// Clear Chat retains the log; clearing the log never clears enforcement history.
/// Independent app grants preserve each expiry. Per-app waits persist while chat
/// remains available; local validation prevents approval before that app’s deadline. Clearing messages retains access outcomes and an active wait.
/// Only confirmed approvals enter history as grants; returning after expiry records it.
/// Captures target/configuration per request and revalidates after every await.
/// Clearing history or changing a rule invalidates in-flight model decisions.
/// The unsent draft lives here for the session so sidebar view replacement does
/// not discard it; it is not saved to history or sent until Send is pressed.
@Observable
final class ConversationCoordinator {
    var selectedSection: AppSection = .chat
    private(set) var target: ApplicationToken?
    private(set) var nickname = ""
    private(set) var appSelectionNeeded = false
    private(set) var selectionAttention = 0
    private var selectionPromptText: String?
    private var confirmedSelectionText: String?
    let composer = ConversationDraft()
    var draftMessage: String {
        get { composer.text }
        set { composer.text = newValue }
    }
    var coachAvailable: Bool { service.isConfigured }
    var selectedAppID: UUID? { target.flatMap { ConversationGrantStore.applicable(to: $0, in: knownSnapshots).first?.id } }
    private(set) var history = ConversationHistory()
    private(set) var isSending = false
    private(set) var grants: [ConversationGrantStore.Grant] = []
    var grant: ConversationGrantStore.Grant? { grants.first { $0.token == target } }
    private var grantVersion = UUID()
    var errorMessage: String?
    private let service: any CoachService
    let preferences: CoachPreferences
    private let clock: ConversationClock
    private let requests = ConversationRequestExecutor()
    let keys: any ConversationKeyStoring
    private let historyStore: any ConversationHistoryStoring
    private let access: ConversationEnforcement
    private let timer: any ConversationTimerScheduling
    private let requestStore: ConversationRequestStore
    private var selectionVersion = UUID()
    private var requestID: UUID?
    private var generation = UUID()
    private var loadFailed = false
    private var knownSnapshots: [RuleSnapshotDTO] = []
    var cooldownUntil: Date? {
        guard let target, let id = ConversationGrantStore.applicable(to: target, in: knownSnapshots).first?.id else { return nil }
        return waitUntil(for: id)
    }
    private func waitUntil(for appID: UUID) -> Date? {
        let waits = history.accessEvents.filter { $0.decision == .wait && $0.waitUntil != nil }
        let until = waits.isEmpty ? history.cooldownUntil : waits.filter { $0.appID == appID }.compactMap(\.waitUntil).max()
        return until.flatMap { $0 > clock.now() ? $0 : nil }
    }
    func appName(for grant: ConversationGrantStore.Grant) -> String {
        ConversationGrantStore.applicable(to: grant.token, in: knownSnapshots).first?.name ?? CopyKey.conversationTargetGeneric.string
    }

    convenience init(context: ModelContext, preferences: CoachPreferences = .init(), service: (any CoachService)? = nil, client: any ConversationClient = OpenAIConversationClient(),
         keys: any ConversationKeyStoring = ConversationEnvironmentKeyStore(),
         access: ConversationEnforcement = ConversationEnforcement(store: ConversationGrantStore(), shields: ManagedSettingsShieldController()),
         timer: any ConversationTimerScheduling = DeviceConversationTimer(),
         requestStore: ConversationRequestStore = .init()) {
        self.init(historyStore: ConversationHistoryStore(context: context), preferences: preferences, service: service, client: client, keys: keys, access: access, timer: timer, requestStore: requestStore)
    }

    init(historyStore: any ConversationHistoryStoring, preferences: CoachPreferences = .init(), service: (any CoachService)? = nil, clock: ConversationClock = .init(), client: any ConversationClient = OpenAIConversationClient(),
         keys: any ConversationKeyStoring = ConversationEnvironmentKeyStore(),
         access: ConversationEnforcement = ConversationEnforcement(store: ConversationGrantStore(), shields: ManagedSettingsShieldController()),
         timer: any ConversationTimerScheduling = DeviceConversationTimer(),
         requestStore: ConversationRequestStore = .init()) {
        self.service = service ?? DevelopmentCoachService(client: client, keys: keys)
        self.preferences = preferences
        self.clock = clock
        self.keys = keys
        ConversationDiagnostics.live.log("config.loaded source=\(keys is ConversationEnvironmentKeyStore ? "bundled-env" : "injected") key_present=\((try? keys.read()) != nil)")
        self.historyStore = historyStore
        var clockedAccess = access
        clockedAccess.currentTime = clock.now
        self.access = clockedAccess
        self.timer = timer
        self.requestStore = requestStore
        do { history = try historyStore.load(); history.prepareActivityLog() }
        catch {
            ConversationDiagnostics.live.log("history.load_failed requests_disabled")
            loadFailed = true; errorMessage = CopyKey.conversationStorageError.string
        }
    }

    func select(_ token: ApplicationToken) {
        selectionVersion = UUID()
        confirmedSelectionText = appSelectionNeeded ? selectionPromptText : nil
        appSelectionNeeded = false
        if target != token {
            if isSending { cancelRequest() } else { requestID = nil; generation = UUID() }
            nickname = ""
        }
        target = token
        errorMessage = nil
        nickname = ConversationGrantStore.applicable(to: token, in: knownSnapshots).first?.name ?? ""
        selectedSection = .chat
    }

    func refresh(snapshots: [RuleSnapshotDTO], consumeRequests: Bool = true) async {
        knownSnapshots = snapshots
        let observedGrantVersion = grantVersion
        let observedSelectionVersion = selectionVersion
        do {
            let access = access
            let requests = requestStore
            let state = try await Task.detached {
                let grants = try access.store.transaction { $0.activeGrants }
                let pending = consumeRequests ? try access.store.consumePending() : nil
                let request = consumeRequests ? requests.pending() : nil
                if let request { requests.acknowledge(request) }
                return (grants, request?.token ?? pending)
            }.value
            if observedGrantVersion == grantVersion { grants = state.0.filter { !$0.plan.hasExpired(at: clock.now()) } }
            if target == nil, let first = grants.first { target = first.token }
            if observedSelectionVersion == selectionVersion, let pending = state.1,
               !ConversationGrantStore.applicable(to: pending, in: snapshots).isEmpty { select(pending) }
            if let target { nickname = ConversationGrantStore.applicable(to: target, in: snapshots).first?.name ?? "" }
            if let target, ConversationGrantStore.applicable(to: target, in: snapshots).isEmpty {
                self.target = nil
                if isSending { cancelRequest() } else { requestID = nil; generation = UUID() }
            }
            let activeIDs = Set(grants.map(\.plan.grantID))
            var recordedEndIDs = Set<UUID>()
            for index in history.accessEvents.indices {
                guard let id = history.accessEvents[index].grantID,
                      history.accessEvents[index].endedAt == nil, !activeIDs.contains(id) else { continue }
                let expiry = history.accessEvents[index].expiresAt ?? clock.now()
                let expired = expiry <= clock.now()
                history.accessEvents[index].endedAt = expired ? expiry : clock.now()
                let endedAt = history.accessEvents[index].endedAt
                for entry in history.activityLog.indices where history.activityLog[entry].grantID == id {
                    history.activityLog[entry].endedAt = endedAt
                }
                recordedEndIDs.insert(id)
                try append(.event, "\(history.accessEvents[index].appName): \(expired ? CopyKey.conversationGrantExpired.string : CopyKey.conversationGrantEnded.string)")
            }
            if let id = history.lastGrantID, !activeIDs.contains(id), !recordedEndIDs.contains(id) {
                let expired = (history.lastGrantExpiry ?? .distantPast) <= clock.now()
                try append(.event, expired ? CopyKey.conversationGrantExpired.string : CopyKey.conversationGrantEnded.string)
            }
            history.lastGrantID = grants.first?.plan.grantID
            history.lastGrantExpiry = grants.first?.plan.expiresAt
            try persist()
        } catch { errorMessage = CopyKey.conversationStorageError.string }
    }

    /// A notification names its own saved profile; a newer pending request must
    /// not redirect an older notification to a different app. No link grants access.
    func openRequestURL(_ url: URL, snapshots: [RuleSnapshotDTO]) {
        guard let id = ConversationShieldRequest.appID(from: url),
              let app = snapshots.first(where: { $0.id == id && $0.isEnabled && $0.kind == .conversation }) else { return }
        let selection = AppSelectionCodec.decode(app.selectionData)
        guard selection.applicationTokens.count == 1, selection.categoryTokens.isEmpty,
              selection.webDomainTokens.isEmpty, let token = selection.applicationTokens.first else { return }
        knownSnapshots = snapshots
        if let pending = requestStore.pending() { requestStore.acknowledge(pending) }
        select(token)
    }

    func send(_ text: String, rules: [BlockingRule]) async {
        await send(text, snapshots: { rules.filter { !$0.isDeleted }.map(\.dto) })
    }

    func send(_ text: String, snapshots: @escaping () -> [RuleSnapshotDTO]) async {
        await requests.run { await self.performSend(text, snapshots: snapshots) }
    }

    private func performSend(_ text: String, snapshots: () -> [RuleSnapshotDTO]) async {
        guard !isSending, !loadFailed else {
            ConversationDiagnostics.live.log("send.skipped reason=\(loadFailed ? "history_load_failed" : "busy")")
            return
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 4000 else { return }
        guard preferences.hasConsent else { errorMessage = CopyKey.aiConsentRequired.string; return }
        let initial = snapshots()
        knownSnapshots = initial
        if confirmedSelectionText != trimmed {
            switch ConversationAppResolver.resolve(trimmed, in: initial) {
            case .selected(let app): select(app)
            case .ambiguous:
                requireAppSelection(for: trimmed, ambiguous: true); return
            case .none:
                if target == nil || appSelectionNeeded { requireAppSelection(for: trimmed); return }
            }
        }
        guard let target else { requireAppSelection(for: trimmed); return }
        let applicable = ConversationGrantStore.applicable(to: target, in: initial)
        guard let requestedApp = applicable.first else { requireAppSelection(for: trimmed); return }
        confirmedSelectionText = nil; selectionPromptText = nil; appSelectionNeeded = false
        nickname = requestedApp.name
        let entry = ConversationActivityEntry(date: clock.now(), appID: requestedApp.id, appName: requestedApp.name, message: trimmed)
        history.activityLog.append(entry)
        do { try persist() }
        catch {
            errorMessage = CopyKey.conversationStorageError.string
            updateActivity(entry.id) {
                $0.outcome = .failed; $0.completedAt = clock.now()
                $0.systemResponse = CopyKey.conversationStorageError.string; $0.failureStage = "activity_save"
            }
            try? persist(); return
        }
        defer {
            if history.activityLog.first(where: { $0.id == entry.id })?.outcome == .pending {
                updateActivity(entry.id) {
                    $0.outcome = .cancelled; $0.completedAt = clock.now()
                    $0.systemResponse = errorMessage ?? CopyKey.activityCancelled.string
                }
                try? persist()
            }
        }
        guard service.isConfigured else {
            errorMessage = CopyKey.coachUnavailable.string
            updateActivity(entry.id) {
                $0.outcome = .failed; $0.completedAt = clock.now()
                $0.systemResponse = errorMessage; $0.failureStage = "service_configuration"
            }
            try? persist(); return
        }
        ConversationDiagnostics.live.log("send.begin messages=\(history.messages.count)")
        ConversationDiagnostics.live.log("key.loaded request_ready")
        let fingerprint = ConversationGrantStore.fingerprint(initial)
        let currentGeneration = generation
        let id = requestID ?? UUID()
        let syncInstant = clock.now()
        isSending = true; errorMessage = nil
        defer { if generation == currentGeneration { isSending = false } }
        var stage = "enforcement_sync"
        var activatedForRequest: ConversationGrantStore.Grant?
        var attemptedApproval = false
        var receivedDecision: ConversationDecision?
        do {
            let access = access
            let protection = try await Task.detached {
                _ = try access.sync(initial, now: syncInstant)
                return try access.focusStore.load()
            }.value
            guard generation == currentGeneration else { return }
            stage = "history_save"
            if requestID == nil {
                requestID = id
                try append(.event, CopyKey.conversationRequestMarker.string(String(requestedApp.name.prefix(100))), request: id)
            }
            if history.messages.last?.role != .user || history.messages.last?.text != trimmed || history.messages.last?.requestID != id {
                try append(.user, trimmed, request: id)
            }
            if history.recentMessages.count > 60 {
                let count = history.messages.count - 30
                let older = Array(history.messages[history.summarizedCount..<count])
                stage = "summary_request"
                ConversationDiagnostics.live.log("summary.begin messages=\(older.count)")
                do {
                    let summary = try await service.summarize(memory: history.memory, messages: older, requestID: id)
                    guard generation == currentGeneration else { return }
                    history.memory = summary; history.summarizedCount = count
                    try persist()
                } catch {
                    guard generation == currentGeneration, !Task.isCancelled else { return }
                    ConversationDiagnostics.live.log("summary.deferred bounded_context")
                }
            }
            let contextInstant = clock.now()
            let context = ConversationContext(goals: applicable.map(\.conversationGoal),
                appNickname: String(requestedApp.name.prefix(100)), memory: history.memory,
                recentMessages: Array(history.recentMessages.suffix(60)), currentTime: contextInstant, currentAppID: requestedApp.id,
                accessEvents: Array(history.accessEvents.suffix(100)),
                activitySummary: .init(events: history.accessEvents, appID: requestedApp.id, now: contextInstant),
                activeUnlocks: grants.filter { !$0.plan.hasExpired(at: contextInstant) }.map {
                    .init(appID: ConversationGrantStore.applicable(to: $0.token, in: initial).first?.id,
                        appName: appName(for: $0), expiresAt: $0.plan.expiresAt)
                }, waitUntil: waitUntil(for: requestedApp.id), tone: preferences.tone,
                focusProtected: protection.protects(appID: requestedApp.id, at: contextInstant))
            stage = "decision_request"
            let response = try await service.respond(to: context, requestID: id)
            let decision = try ConversationDecision.parse(JSONEncoder().encode(response))
            receivedDecision = decision
            guard generation == currentGeneration, !Task.isCancelled else { return }
            guard self.target == target,
                  fingerprint == ConversationGrantStore.fingerprint(snapshots()) else {
                ConversationDiagnostics.live.log("decision.discarded stale_configuration")
                errorMessage = CopyKey.conversationStaleRequest.string; requestID = nil; return
            }
            ConversationDiagnostics.live.log("decision.received decision=\(decision.decision.rawValue) minutes=\(decision.unlockMinutes ?? 0) wait_minutes=\(decision.waitMinutes ?? 0)")
            var event = ConversationAccessEvent(date: clock.now(), appID: requestedApp.id,
                appName: requestedApp.name, reason: trimmed, decision: decision.decision, reply: decision.reply)
            if decision.decision == .approve, let minutes = decision.unlockMinutes {
                attemptedApproval = true
                if waitUntil(for: requestedApp.id) != nil { throw ConversationAccessError.waiting }
                let access = access; let timer = timer; let approvalInstant = clock.now()
                stage = "grant_registration"
                ConversationDiagnostics.live.log("grant.begin rule=\(requestedApp.id.logTag) minutes=\(minutes)")
                let activated = try await Task.detached {
                    try access.approve(token: target, minutes: minutes, fingerprint: fingerprint, now: approvalInstant, timer: timer)
                }.value
                activatedForRequest = activated
                guard generation == currentGeneration,
                      fingerprint == ConversationGrantStore.fingerprint(snapshots()) else {
                    try await Task.detached { try access.end(grantID: activated.plan.grantID) }.value
                    if generation == currentGeneration { errorMessage = CopyKey.conversationStaleRequest.string }
                    return
                }
                stage = "grant_save"
                let beforePublishing = history
                do {
                    history.lastGrantID = grants.first?.plan.grantID ?? activated.plan.grantID
                    history.lastGrantExpiry = grants.first?.plan.expiresAt ?? activated.plan.expiresAt
                    event.date = activated.plan.start; event.grantID = activated.plan.grantID; event.expiresAt = activated.plan.expiresAt
                    history.accessEvents.append(event)
                    let marker = minutes == 1 ? CopyKey.conversationApprovalOne.string : CopyKey.conversationApprovalMarker.string(minutes)
                    history.messages.append(.init(date: clock.now(), role: .assistant, text: decision.reply, requestID: id))
                    history.messages.append(.init(date: clock.now(), role: .event, text: marker, requestID: id))
                    updateActivity(entry.id) {
                        $0.outcome = .unlocked; $0.modelDecision = decision.decision
                        $0.coachResponse = decision.reply; $0.systemResponse = marker; $0.completedAt = clock.now()
                        $0.unlockMinutes = minutes; $0.unlockUntil = activated.plan.expiresAt; $0.grantID = activated.plan.grantID
                    }
                    try persist()
                } catch { history = beforePublishing; throw error }
                grants.append(activated); grantVersion = UUID()
                ConversationDiagnostics.live.log("grant.activated id=\(activated.plan.grantID.logTag) minutes=\(minutes)")
                requestID = nil
            } else {
                stage = "assistant_save"
                let beforePublishing = history
                do {
                    if decision.decision == .wait, let minutes = decision.waitMinutes {
                        history.cooldownUntil = waitUntil(for: requestedApp.id) ?? clock.now().addingTimeInterval(Double(minutes * 60))
                        event.waitUntil = history.cooldownUntil
                    }
                    history.accessEvents.append(event)
                    history.messages.append(.init(date: clock.now(), role: .assistant, text: decision.reply, requestID: id))
                    updateActivity(entry.id) {
                        $0.outcome = decision.decision == .ask ? .asked : decision.decision == .deny ? .denied : .wait
                        $0.modelDecision = decision.decision; $0.coachResponse = decision.reply
                        $0.systemResponse = $0.outcome.title; $0.waitUntil = event.waitUntil; $0.completedAt = clock.now()
                    }
                    try persist()
                } catch { history = beforePublishing; throw error }
                if let minutes = decision.waitMinutes {
                    ConversationDiagnostics.live.log("cooldown.started minutes=\(minutes)")
                }
                if decision.decision != .ask { requestID = nil }
            }
        } catch {
            guard generation == currentGeneration, !Task.isCancelled else {
                if let activated = activatedForRequest {
                    let access = access
                    try? await Task.detached { try access.end(grantID: activated.plan.grantID) }.value
                }
                return
            }
            let reason = (error as? ConversationClientError)?.diagnosticSummary ?? (error is PersistenceFailure ? "persistence" : (error as? ConversationAccessError).map { "enforcement_" + String(describing: $0) } ?? "unexpected")
            ConversationDiagnostics.live.log("send.failed stage=\(stage) reason=\(reason) access_not_granted")
            if let activated = activatedForRequest {
                let access = access
                try? await Task.detached { try access.end(grantID: activated.plan.grantID) }.value
                history.accessEvents.removeAll { $0.grantID == activated.plan.grantID }
                grants.removeAll { $0.plan.grantID == activated.plan.grantID }; grantVersion = UUID()
                history.lastGrantID = grants.first?.plan.grantID
                history.lastGrantExpiry = grants.first?.plan.expiresAt
            }
            let outcome: ConversationActivityEntry.Outcome
            if error as? ConversationAccessError == .focusProtected {
                errorMessage = CopyKey.focusProtected.string; outcome = .failed
            } else if error as? ConversationAccessError == .waiting {
                errorMessage = CopyKey.volitionWaitError.string; outcome = .blockedByWait
            } else if error as? ConversationAccessError == .alreadyUnlocked {
                errorMessage = CopyKey.conversationGrantActive.string; outcome = .alreadyUnlocked
            } else {
                outcome = .failed
                if error is PersistenceFailure { errorMessage = CopyKey.conversationStorageError.string }
                else if let failure = error as? ConversationClientError { errorMessage = failure.copyKey.string }
                else { errorMessage = error is ConversationAccessError ? CopyKey.conversationGrantFailed.string : CopyKey.conversationNetworkError.string }
            }
            updateActivity(entry.id) {
                $0.outcome = outcome; $0.modelDecision = receivedDecision?.decision
                $0.coachResponse = receivedDecision?.reply; $0.systemResponse = errorMessage
                $0.completedAt = clock.now(); $0.failureStage = stage
            }
            try? persist()
        }
        #if DEBUG
        if attemptedApproval, keys is ConversationEnvironmentKeyStore {
            await Task.detached { ConversationSupportExport.recordApproval(requestID: id) }.value
        }
        #endif
    }

    func endUnlock(grantID: UUID? = nil) async {
        guard let id = grantID ?? grant?.plan.grantID else { return }
        ConversationDiagnostics.live.log("grant.end_requested id=\(id.logTag)")
        do {
            let access = access
            try await Task.detached { try access.end(grantID: id) }.value
            finishAccessEvent(id: id, at: clock.now())
            grants.removeAll { $0.plan.grantID == id }
            grantVersion = UUID()
            history.lastGrantID = grants.first?.plan.grantID
            history.lastGrantExpiry = grants.first?.plan.expiresAt
            try append(.event, CopyKey.conversationGrantEnded.string)
        } catch { errorMessage = CopyKey.conversationStorageError.string }
    }

    func clearHistory() {
        ConversationDiagnostics.live.log("history.clear_requested")
        cancelRequest()
        let previous = history
        history = ConversationHistory()
        history.cooldownUntil = previous.cooldownUntil
        history.accessEvents = previous.accessEvents
        history.activityLog = previous.activityLog
        history.lastGrantID = grants.first?.plan.grantID
        history.lastGrantExpiry = grants.first?.plan.expiresAt
        do { try persist(); loadFailed = false }
        catch { history = previous; errorMessage = CopyKey.conversationStorageError.string }
    }

    func cancelRequest() {
        composer.cancel()
        generation = UUID(); requestID = nil
        requests.cancel()
        isSending = false
        for index in history.activityLog.indices where history.activityLog[index].outcome == .pending {
            history.activityLog[index].outcome = .cancelled
            history.activityLog[index].systemResponse = CopyKey.activityCancelled.string
            history.activityLog[index].completedAt = clock.now()
        }
        try? persist()
        // Generation checks also protect against transports that ignore cancellation.
    }

    func setAIConsent(_ granted: Bool) {
        cancelRequest()
        preferences.setConsent(granted)
        errorMessage = nil
    }

    /// Erase content while retaining only active wait deadlines. Grants remain
    /// independently owned by enforcement and keep their original expiry.
    @discardableResult
    func eraseCoachingContent() -> Bool {
        cancelRequest()
        let previous = history
        var clean = ConversationHistory()
        clean.cooldownUntil = history.cooldownUntil.flatMap { $0 > clock.now() ? $0 : nil }
        clean.accessEvents = history.accessEvents.filter { ($0.waitUntil ?? .distantPast) > clock.now() }.map {
            var event = $0; event.appName = ""; event.reason = ""; event.reply = ""; return event
        }
        clean.lastGrantID = grants.first?.plan.grantID
        clean.lastGrantExpiry = grants.first?.plan.expiresAt
        history = clean
        do {
            try ConversationActivityExport.eraseFiles()
            try persist()
            loadFailed = false
            return true
        } catch { history = previous; errorMessage = CopyKey.conversationStorageError.string; return false }
    }


    private func requireAppSelection(for text: String, ambiguous: Bool = false) {
        appSelectionNeeded = true; selectionAttention += 1; selectionPromptText = text
        confirmedSelectionText = nil
        errorMessage = (ambiguous ? CopyKey.conversationAmbiguousApp : .conversationSelectAppHelp).string
        var entry = ConversationActivityEntry(date: clock.now(), message: text, outcome: .selectionRequired, systemResponse: errorMessage)
        entry.completedAt = clock.now(); history.activityLog.append(entry)
        do { try persist() } catch { errorMessage = CopyKey.conversationStorageError.string }
    }

    private func updateActivity(_ id: UUID, _ update: (inout ConversationActivityEntry) -> Void) {
        // A late network result cannot rewrite an already-cancelled request.
        if let index = history.activityLog.firstIndex(where: { $0.id == id && $0.outcome == .pending }) {
            update(&history.activityLog[index])
        }
    }

    @discardableResult
    func clearActivityLog() -> Bool {
        let previous = history.activityLog
        history.activityLog = []
        do {
            try persist()
            try ConversationActivityExport.eraseFiles()
            return true
        } catch { history.activityLog = previous; errorMessage = CopyKey.conversationStorageError.string; return false }
    }

    private func finishAccessEvent(id: UUID, at date: Date) {
        for index in history.activityLog.indices where history.activityLog[index].grantID == id {
            history.activityLog[index].endedAt = date
        }
        if let index = history.accessEvents.firstIndex(where: { $0.grantID == id }) {
            history.accessEvents[index].endedAt = date
        }
    }

    private func append(_ role: ConversationMessage.Role, _ text: String, request: UUID? = nil) throws {
        history.messages.append(.init(date: clock.now(), role: role, text: text, requestID: request))
        try persist()
    }
    private struct PersistenceFailure: Error {}
    private func persist() throws {
        do { try historyStore.save(history) }
        catch {
            ConversationDiagnostics.live.log("history.save_failed")
            throw PersistenceFailure()
        }
    }
}

nonisolated struct MockConversationTimer: ConversationTimerScheduling {
    func start(_ plan: ConversationUnlockPlan) throws {}
    func stop(_ name: String) {}
}
