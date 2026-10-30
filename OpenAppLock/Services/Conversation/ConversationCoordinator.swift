import FamilyControls
import ManagedSettings
import Foundation
import Observation
import SwiftData
import UserNotifications

/// Owns shared chat, saved app identity and timestamped cross-app access outcomes.
/// Unambiguous saved names route locally before any API call; unresolved requests
/// preserve the draft and request explicit selection. Private activity records
/// capture coach decisions separately from actual outcomes, atomically with replies.
/// Clear Chat retains the log; clearing the log never clears enforcement history.
/// Soft reflections persist independently per app, never override hard waits,
/// and activate at most once in foreground through the existing grant transaction.
/// Longer pauses require consent. Expiry, check-ins and End delay never grant;
/// only explicit Unlock/Accept activates. A delay can always be ended or cancelled.
/// Restored offers are cancelled when sharing is off. Activation rechecks consent
/// around asynchronous enforcement, including preferences changed outside this UI.
/// Deals require acceptance and preserve shared cooldowns after early end. A
/// persistent request may offer replacement terms after two real pushbacks;
/// explicit Accept atomically replaces the old break with a longer new one.
/// End unlock hides its banner while reblocking; failures restore actionable UI.
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
    private var endingGrantIDs = Set<UUID>()
    private var dealCommitments: [ConversationGrantStore.DealCommitment] = []
    var displayedGrants: [ConversationGrantStore.Grant] { grants.filter { !endingGrantIDs.contains($0.plan.grantID) } }
    var selectedActivitySummary: ConversationActivitySummary? {
        guard let target, let app = ConversationGrantStore.applicable(to: target, in: knownSnapshots).first else { return nil }
        return .init(events: history.accessEvents, appID: app.id, now: .now)
    }
    var errorMessage: String?
    private let service: any CoachService
    private let checkInRoll: @Sendable () -> Bool
    let preferences: CoachPreferences
    private let clock: ConversationClock
    private let requests = ConversationRequestExecutor()
    let keys: any ConversationKeyStoring
    private let historyStore: any ConversationHistoryStoring
    private let access: ConversationEnforcement
    private let timer: any ConversationTimerScheduling
    private let requestStore: ConversationRequestStore
    private var selectionVersion = UUID()
    private(set) var routedRequestID: UUID?
    private var requestID: UUID?
    private var generation = UUID()
    private var loadFailed = false
    var isForeground = true
    private var completingReflections = Set<UUID>()
    private var knownSnapshots: [RuleSnapshotDTO] = []
    var cooldownUntil: Date? {
        guard let target, let id = ConversationGrantStore.applicable(to: target, in: knownSnapshots).first?.id else { return nil }
        return waitUntil(for: id)
    }
    private func waitUntil(for appID: UUID, excludingDealGrantID: UUID? = nil, replacingDealID: UUID? = nil) -> Date? {
        let waits = history.accessEvents.filter { $0.decision == .wait && $0.waitUntil != nil }
        let until = waits.isEmpty ? history.cooldownUntil : waits.filter { $0.appID == appID }.compactMap(\.waitUntil).max()
        let token = knownSnapshots.first { $0.id == appID }.flatMap { try? VolitionApps.selectedApp(in: AppSelectionCodec.decode($0.selectionData)) }
        let deal = dealCommitments.filter { commitment in
            commitment.token == token && commitment.isBlocking(at: clock.now()) && commitment.grantID != excludingDealGrantID && commitment.grantID != replacingDealID &&
            !grants.contains { grant in
                grant.plan.grantID == commitment.grantID && !grant.plan.hasExpired(at: clock.now())
            }
        }.map(\.blockedUntil).max()
        return [until, deal].compactMap { $0 }.filter { $0 > clock.now() }.max()
    }
    private var presentableGrants: [ConversationGrantStore.Grant] {
        displayedGrants.filter { grant in history.accessEvents.contains { $0.grantID == grant.plan.grantID && $0.decision == .approve } }
    }
    var presentationID: String { presentableGrants.map { "\($0.plan.grantID)-\($0.plan.expiresAt.timeIntervalSince1970)-\(appName(for: $0))" }.joined() }
    func updateSessionPresentation() async {
        guard isForeground, !LaunchConfiguration.current.isUITesting || ProcessInfo.processInfo.arguments.contains("-ui-testing-live-activity") else { return }
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-live-activity") {
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        }
        let windows = presentableGrants.map { grant in
            ConversationPresentedUnlock(plan: grant.plan,
                appID: ConversationGrantStore.applicable(to: grant.token, in: knownSnapshots).first?.id,
                appName: appName(for: grant))
        }
        await ConversationSessionPresentation.shared.sync(windows, store: access.store)
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
         requestStore: ConversationRequestStore = .init(), checkInRoll: @escaping @Sendable () -> Bool = { true }) {
        self.service = service ?? DevelopmentCoachService(client: client, keys: keys)
        self.checkInRoll = checkInRoll
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
        do {
            history = try historyStore.load(); history.prepareActivityLog()
            for index in history.reflections.indices where history.reflections[index].state == .activating {
                history.reflections[index].state = .interrupted
                history.reflections[index].finishedAt = .now
                let activityID = history.reflections[index].activityID
                if let entry = history.activityLog.firstIndex(where: { $0.id == activityID }) {
                    history.activityLog[entry].outcome = .interrupted
                    history.activityLog[entry].systemResponse = CopyKey.activityInterruptedHelp.string
                }
            }
            if !preferences.hasConsent {
                for offer in history.reflections where offer.isPending {
                    finishReflection(offer.id, state: .cancelled, message: CopyKey.aiConsentRequired.string)
                }
            }
            try historyStore.save(history)
        }
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
                let stored = try access.store.transaction { ($0.activeGrants, $0.dealCommitments) }
                let pending = consumeRequests ? try access.store.consumePending() : nil
                let request = consumeRequests ? requests.pending() : nil
                if let request { requests.acknowledge(request) }
                // Transfer bytes across the task boundary; the SDK's token type
                // does not declare Sendable. Decode it on the receiving actor.
                let pendingData = try (request?.token ?? pending).map { try JSONEncoder().encode($0) }
                return (stored.0, pendingData, stored.1)
            }.value
            if observedGrantVersion == grantVersion { grants = state.0.filter { !$0.plan.hasExpired(at: clock.now()) }; dealCommitments = state.2 }
            if target == nil, let first = grants.first { target = first.token }
            let pendingToken = try state.1.map { try JSONDecoder().decode(ApplicationToken.self, from: $0) }
            if observedSelectionVersion == selectionVersion, let pending = pendingToken,
               !ConversationGrantStore.applicable(to: pending, in: snapshots).isEmpty {
                select(pending); routedRequestID = UUID()
            }
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
        select(token); routedRequestID = UUID()
    }

    /// An explicit app-bound action must not be rerouted by another app name in
    /// its removal feedback. All normal request/enforcement checks still run.
    func sendToApp(_ text: String, token: ApplicationToken, snapshots: @escaping () -> [RuleSnapshotDTO]) async {
        guard !isSending else { return }
        select(token)
        confirmedSelectionText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        await send(text, snapshots: snapshots)
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
        cancelReflections(appID: requestedApp.id)
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
            let dealState = try await Task.detached { try access.store.transaction { $0 } }.value
            guard generation == currentGeneration else { return }
            dealCommitments = dealState.dealCommitments
            let contextInstant = clock.now()
            let activeDeal = dealState.dealCommitments.first { $0.token == target && $0.isBlocking(at: contextInstant) }
            let lastBroken = ConversationEnforcement.lastResolvedDealWasBroken(dealState, at: contextInstant)
            let context = ConversationContext(goals: applicable.map(\.conversationGoal),
                appNickname: String(requestedApp.name.prefix(100)), memory: history.memory,
                recentMessages: Array(history.recentMessages.suffix(60)), currentTime: contextInstant, currentAppID: requestedApp.id,
                accessEvents: Array(history.accessEvents.suffix(100)),
                activitySummary: .init(events: history.accessEvents, appID: requestedApp.id, now: contextInstant),
                activeUnlocks: grants.filter { !$0.plan.hasExpired(at: contextInstant) }.map {
                    .init(appID: ConversationGrantStore.applicable(to: $0.token, in: initial).first?.id,
                        appName: appName(for: $0), expiresAt: $0.plan.expiresAt)
                }, waitUntil: waitUntil(for: requestedApp.id),
                usageProfile: history.usageProfiles[requestedApp.id],
                recentReflections: history.reflections.filter { contextInstant.timeIntervalSince($0.createdAt) < 86400 }
                    .suffix(10).map(\.context))
            var coachingContext = context
            coachingContext.tone = preferences.tone
            coachingContext.focusProtected = protection.protects(appID: requestedApp.id, at: contextInstant)
            let recentBrokenDeals = dealState.dealCommitments.filter {
                $0.token == target && $0.overriddenAt.map { $0 <= contextInstant && contextInstant.timeIntervalSince($0) < 86400 } == true
            }.count
            coachingContext.recommendedPauseSeconds = min(1800,
                history.recommendedPauseSeconds(for: requestedApp.id, now: contextInstant) + min(29, recentBrokenDeals) * 60)
            coachingContext.recentRemovalAttempts = Array(history.removalAttempts.filter {
                $0.date <= contextInstant && contextInstant.timeIntervalSince($0.date) < 86400
            }.suffix(10))
            coachingContext.recentPauseAttempts = history.recentPauseAttempts(for: requestedApp.id, now: contextInstant)
            coachingContext.recommendedIntervention = ConversationContext.intervention(after: context.activitySummary?.grantsLastHour ?? 0)
            coachingContext.preferDeal = coachingContext.recentPauseAttempts >= 2 || coachingContext.recommendedIntervention == "deal"
            coachingContext.emotionCheckInSuggested = history.canAskEmotion(at: contextInstant) && checkInRoll()
            coachingContext.waitUntilLocal = context.waitUntil.map { $0.formatted(date: .abbreviated, time: .shortened) }
            coachingContext.deal = activeDeal.map { .init(grantID: $0.grantID, blockedUntil: $0.blockedUntil,
                pushbackCount: $0.pushbackCount ?? 0, lastResolvedDealWasBroken: lastBroken,
                canOverride: ($0.pushbackCount ?? 0) >= 2,
                minimumReplacementBreakMinutes: ConversationEnforcement.minimumReplacementBreakMinutes(for: $0, at: contextInstant)) }
            stage = "decision_request"
            let response = try await service.respond(to: coachingContext, requestID: id)
            let decision = try ConversationDecision.parse(JSONEncoder().encode(response))
            receivedDecision = response
            guard generation == currentGeneration, !Task.isCancelled else { return }
            guard self.target == target,
                  fingerprint == ConversationGrantStore.fingerprint(snapshots()) else {
                ConversationDiagnostics.live.log("decision.discarded stale_configuration")
                errorMessage = CopyKey.conversationStaleRequest.string; requestID = nil; return
            }
            ConversationDiagnostics.live.log("decision.received decision=\(decision.decision.rawValue) minutes=\(decision.unlockMinutes ?? 0) wait_minutes=\(decision.waitMinutes ?? 0)")
            var event = ConversationAccessEvent(date: clock.now(), appID: requestedApp.id,
                appName: requestedApp.name, reason: trimmed, decision: decision.decision, reply: decision.reply)
            if [.pause, .wait, .deal, .choice, .override].contains(decision.decision) {
                let protected = try await Task.detached { try access.focusStore.load() }.value
                guard !protected.protects(appID: requestedApp.id, at: clock.now()) else { throw ConversationAccessError.focusProtected }
                guard generation == currentGeneration, !Task.isCancelled else { return }
                let overridingID = decision.decision == .override ? activeDeal?.grantID : nil
                if decision.decision == .override {
                    guard let activeDeal, (activeDeal.pushbackCount ?? 0) >= 2,
                          let blockMinutes = decision.blockMinutes,
                          blockMinutes >= ConversationEnforcement.minimumReplacementBreakMinutes(for: activeDeal, at: clock.now()) else {
                        throw ConversationAccessError.waiting
                    }
                }
                if waitUntil(for: requestedApp.id, excludingDealGrantID: overridingID) != nil { throw ConversationAccessError.waiting }
                if grants.contains(where: { $0.token == target && !$0.plan.hasExpired(at: .now) }) { throw ConversationAccessError.alreadyUnlocked }
                let previous = history
                do {
                    var reflection = ConversationReflection(appID: requestedApp.id, appName: requestedApp.name,
                        reason: trimmed, reply: decision.reply, unlockMinutes: decision.unlockMinutes ?? 5,
                        seconds: decision.pauseSeconds ?? (decision.waitMinutes ?? 1) * 60,
                        fingerprint: fingerprint, activityID: entry.id)
                    reflection.usageProfile = history.usageProfiles[requestedApp.id]
                    reflection.checkInRequested = coachingContext.emotionCheckInSuggested && history.canAskEmotion(at: clock.now())
                    if reflection.checkInRequested == true { history.lastEmotionQuestionAt = clock.now() }
                    reflection.overridingDealID = overridingID
                    if reflection.awaitingCheckIn { reflection.state = .offered; reflection.deadline = nil }
                    if [.deal, .choice, .override].contains(decision.decision) {
                        reflection.blockMinutes = decision.blockMinutes; reflection.state = .offered; reflection.deadline = nil
                        reflection.offersChoice = decision.decision == .choice
                    }
                    history.reflections.append(reflection)
                    history.accessEvents.append(event)
                    history.messages.append(.init(role: .assistant,
                        text: reflection.awaitingCheckIn ? CopyKey.reflectionQuestion.string : decision.reply, requestID: id))
                    updateActivity(entry.id) {
                        $0.outcome = reflection.isDeal ? .dealOffered : .reflection; $0.modelDecision = decision.decision
                        $0.coachResponse = decision.reply; $0.systemResponse = reflection.isDeal ? CopyKey.dealOffered.string : CopyKey.reflectionRecorded.string
                        $0.reflectionID = reflection.id; $0.pauseSeconds = reflection.isDeal ? nil : reflection.seconds; $0.blockMinutes = reflection.blockMinutes
                    }
                    try persist(); requestID = nil
                } catch { history = previous; throw error }
            } else if [.approve, .urgent, .frustration].contains(decision.decision), let minutes = decision.unlockMinutes {
                attemptedApproval = true
                let relief = decision.decision == .urgent || decision.decision == .frustration
                let reliefDealID = relief ? activeDeal?.grantID : nil
                if waitUntil(for: requestedApp.id, excludingDealGrantID: reliefDealID) != nil { throw ConversationAccessError.waiting }
                let access = access; let timer = timer; let approvalInstant = clock.now()
                stage = "grant_registration"
                ConversationDiagnostics.live.log("grant.begin rule=\(requestedApp.id.logTag) minutes=\(minutes)")
                let targetData = try JSONEncoder().encode(target)
                let activated = try await Task.detached {
                    let isolatedTarget = try JSONDecoder().decode(ApplicationToken.self, from: targetData)
                    return try access.approve(token: isolatedTarget, minutes: minutes, fingerprint: fingerprint, now: approvalInstant, timer: timer, overridingDealID: reliefDealID, immediateRelief: relief)
                }.value
                activatedForRequest = activated
                guard generation == currentGeneration,
                      fingerprint == ConversationGrantStore.fingerprint(snapshots()) else {
                    try await Task.detached { try access.end(grantID: activated.plan.grantID, cancelDeal: true) }.value
                    if generation == currentGeneration { errorMessage = CopyKey.conversationStaleRequest.string }
                    return
                }
                stage = "grant_save"
                let beforePublishing = history
                do {
                    history.lastGrantID = grants.first?.plan.grantID ?? activated.plan.grantID
                    history.lastGrantExpiry = grants.first?.plan.expiresAt ?? activated.plan.expiresAt
                    event.decision = .approve
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
                dealCommitments = (try? await Task.detached { try access.store.transaction { $0.dealCommitments } }.value) ?? dealCommitments
                ConversationDiagnostics.live.log("grant.activated id=\(activated.plan.grantID.logTag) minutes=\(minutes)")
                requestID = nil
            } else {
                stage = "assistant_save"
                let beforePublishing = history
                do {
                    history.accessEvents.append(event)
                    history.messages.append(.init(date: clock.now(), role: .assistant, text: decision.reply, requestID: id))
                    updateActivity(entry.id) {
                        $0.outcome = decision.decision == .ask ? .asked : .denied
                        $0.modelDecision = response.decision; $0.coachResponse = response.reply
                        $0.systemResponse = decision.decision != response.decision ? decision.reply : $0.outcome.title; $0.waitUntil = event.waitUntil; $0.completedAt = clock.now()
                    }
                    try persist()
                } catch { history = beforePublishing; throw error }
                if activeDeal != nil {
                    let targetData = try JSONEncoder().encode(target)
                    try await Task.detached {
                        let isolatedTarget = try JSONDecoder().decode(ApplicationToken.self, from: targetData)
                        try access.recordDealPushback(token: isolatedTarget)
                    }.value
                }
                if decision.decision != .ask { requestID = nil }
            }
        } catch {
            guard generation == currentGeneration, !Task.isCancelled else {
                if let activated = activatedForRequest {
                    let access = access
                    try? await Task.detached { try access.end(grantID: activated.plan.grantID, cancelDeal: true) }.value
                }
                return
            }
            let reason = (error as? ConversationClientError)?.diagnosticSummary ?? (error is PersistenceFailure ? "persistence" : (error as? ConversationAccessError).map { "enforcement_" + String(describing: $0) } ?? "unexpected")
            ConversationDiagnostics.live.log("send.failed stage=\(stage) reason=\(reason) access_not_granted")
            if let activated = activatedForRequest {
                let access = access
                try? await Task.detached { try access.end(grantID: activated.plan.grantID, cancelDeal: true) }.value
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
        guard let id = grantID ?? grant?.plan.grantID, !endingGrantIDs.contains(id) else { return }
        endingGrantIDs.insert(id); grantVersion = UUID()
        defer { endingGrantIDs.remove(id) }
        ConversationDiagnostics.live.log("grant.end_requested id=\(id.logTag)")
        do {
            let access = access
            try await Task.detached { try access.end(grantID: id) }.value
            finishAccessEvent(id: id, at: clock.now())
            grants.removeAll { $0.plan.grantID == id }
            grantVersion = UUID()
            history.lastGrantID = grants.first?.plan.grantID
            history.lastGrantExpiry = grants.first?.plan.expiresAt
            if !LaunchConfiguration.current.isUITesting || ProcessInfo.processInfo.arguments.contains("-ui-testing-live-activity") {
                await ConversationSessionPresentation.shared.end(id)
            }
            try append(.event, CopyKey.conversationGrantEnded.string)
        } catch { errorMessage = CopyKey.conversationStorageError.string }
    }

    func clearHistory() {
        ConversationDiagnostics.live.log("history.clear_requested")
        cancelRequest()
        let previous = history
        cancelReflections()
        let reflections = history.reflections
        let activityLog = history.activityLog
        history = ConversationHistory()
        history.lastEmotionQuestionAt = previous.lastEmotionQuestionAt
        history.usageProfiles = previous.usageProfiles
        history.reflections = reflections
        history.removalAttempts = previous.removalAttempts
        history.cooldownUntil = previous.cooldownUntil
        history.accessEvents = previous.accessEvents
        history.activityLog = activityLog
        history.lastGrantID = grants.first?.plan.grantID
        history.lastGrantExpiry = grants.first?.plan.expiresAt
        do { try persist(); loadFailed = false }
        catch { history = previous; errorMessage = CopyKey.conversationStorageError.string }
    }

    func cancelRequest() {
        cancelReflections()
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

    /// Erase content while retaining sanitized active wait/grant evidence. Grants remain
    /// independently owned by enforcement and keep their original expiry.
    @discardableResult
    func eraseCoachingContent() -> Bool {
        cancelRequest()
        let previous = history
        var clean = ConversationHistory()
        clean.lastEmotionQuestionAt = history.lastEmotionQuestionAt
        clean.cooldownUntil = history.cooldownUntil.flatMap { $0 > clock.now() ? $0 : nil }
        let activeGrantIDs = Set(grants.map(\.plan.grantID))
        clean.accessEvents = history.accessEvents.filter {
            ($0.waitUntil ?? .distantPast) > clock.now() || $0.grantID.map(activeGrantIDs.contains) == true
        }.map {
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

extension ConversationCoordinator {
    var pendingReflections: [ConversationReflection] {
        history.reflections.filter { $0.isPending || $0.state == .activating }
    }
    var reflectionScheduleID: String {
        pendingReflections.map { "\($0.id)-\($0.state.rawValue)-\($0.deadline?.timeIntervalSince1970 ?? 0)-\($0.emotion?.rawValue ?? "unanswered")" }.joined()
    }
    var nextReflectionDeadline: Date? { nextReflectionDeadline(at: .now) }
    func nextReflectionDeadline(at now: Date) -> Date? {
        guard !loadFailed else { return nil }
        return pendingReflections.filter(\.isPending).map { reflection in
            // Elapsed delays wait for an explicit Unlock/Keep locked action.
            if let deadline = reflection.deadline, deadline > now { return min(deadline, reflection.validUntil) }
            return reflection.validUntil
        }.min()
    }
    func reloadUsageProfiles() throws {
        history.usageProfiles = try historyStore.load().usageProfiles
    }

    func chooseCustomEmotion(_ text: String, for id: UUID) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 160 else { return }
        chooseEmotion(.other, for: id, custom: trimmed)
    }

    func chooseEmotion(_ emotion: ConversationReflection.Emotion, for id: UUID, custom: String? = nil) {
        guard let index = history.reflections.firstIndex(where: { $0.id == id && $0.isPending }) else { return }
        let previous = history
        guard history.reflections[index].emotion == nil, clock.now() < history.reflections[index].validUntil else { return }
        let wasAwaiting = history.reflections[index].awaitingCheckIn
        history.reflections[index].emotion = emotion
        history.reflections[index].customEmotion = emotion == .other ? custom : nil
        if wasAwaiting {
            history.messages.append(.init(role: .assistant, text: history.reflections[index].reply))
            if !history.reflections[index].isDeal && !history.reflections[index].isChoice && history.reflections[index].seconds == 10 {
                history.reflections[index].state = .counting
                history.reflections[index].deadline = clock.now().addingTimeInterval(10)
            }
        }
        let activityID = history.reflections[index].activityID
        if let entry = history.activityLog.firstIndex(where: { $0.id == activityID }) {
            history.activityLog[entry].emotion = emotion
            history.activityLog[entry].customEmotion = history.reflections[index].customEmotion
        }
        do { try persist() } catch { history = previous; errorMessage = CopyKey.conversationStorageError.string }
    }

    func startReflection(_ id: UUID, now: Date = .now) {
        guard let index = history.reflections.firstIndex(where: { $0.id == id && $0.state == .offered && !$0.isDeal && !$0.isChoice }),
              now < history.reflections[index].validUntil, !history.reflections[index].awaitingCheckIn else { return }
        let previous = history
        history.reflections[index].state = .counting
        history.reflections[index].deadline = now.addingTimeInterval(Double(history.reflections[index].seconds))
        do { try persist() } catch { history = previous; errorMessage = CopyKey.conversationStorageError.string }
    }

    /// Ending a delay never opens an app. The subsequent Unlock action still
    /// validates current configuration, Focus, waits and durable activation.
    func endReflectionDelay(_ id: UUID, now: Date = .now) {
        guard let index = history.reflections.firstIndex(where: { $0.id == id && $0.state == .counting && !$0.isDeal && !$0.isChoice }),
              now < history.reflections[index].validUntil, !history.reflections[index].awaitingCheckIn else { return }
        let previous = history
        history.reflections[index].deadline = min(history.reflections[index].deadline ?? now, now)
        history.reflections[index].skipped = true
        do { try persist() } catch { history = previous; errorMessage = CopyKey.conversationStorageError.string }
    }

    /// A choice binds exactly the model's validated terms. Selecting the delay
    /// is consent to start it; selecting the deal still requires activation.
    func chooseIntervention(_ id: UUID, deal: Bool, now: Date = .now) {
        chooseIntervention(id, option: deal ? .deal : .delay, now: now)
    }

    func chooseIntervention(_ id: UUID, option: ConversationReflection.InterventionOption, now: Date = .now) {
        guard let index = history.reflections.firstIndex(where: { $0.id == id && $0.isChoice && $0.state == .offered }),
              now < history.reflections[index].validUntil, !history.reflections[index].awaitingCheckIn else { return }
        let previous = history
        history.reflections[index].offersChoice = false
        if option != .deal {
            history.reflections[index].blockMinutes = nil
            history.reflections[index].state = .counting
            history.reflections[index].deadline = option == .open ? now : now.addingTimeInterval(Double(history.reflections[index].seconds))
            history.reflections[index].skipped = option == .open
            history.reflections[index].openedWithoutIntervention = option == .open
        }
        if let entry = history.activityLog.firstIndex(where: { $0.id == history.reflections[index].activityID }) {
            history.activityLog[entry].blockMinutes = history.reflections[index].blockMinutes
        }
        do { try persist() } catch { history = previous; errorMessage = CopyKey.conversationStorageError.string }
    }

    func declineDeal(_ id: UUID) {
        guard history.reflections.contains(where: { $0.id == id && $0.isDeal && $0.isPending }) else { return }
        finishReflection(id, state: .declined, message: CopyKey.dealDeclined.string)
        history.messages.append(.init(role: .event, text: CopyKey.dealDeclined.string))
        do { try persist() } catch { errorMessage = CopyKey.conversationStorageError.string }
    }

    func cancelReflection(_ id: UUID) {
        guard history.reflections.contains(where: { $0.id == id && ($0.isPending || $0.state == .activating) }) else { return }
        finishReflection(id, state: .cancelled, message: CopyKey.reflectionCancelled.string)
        // A failed write must not re-arm the cancelled unlock in this process.
        do { try persist() } catch { errorMessage = CopyKey.conversationStorageError.string }
    }

    private func cancelReflections(appID: UUID? = nil) {
        for reflection in pendingReflections where appID == nil || reflection.appID == appID {
            finishReflection(reflection.id, state: .cancelled, message: CopyKey.reflectionCancelled.string)
        }
    }

    private func finishReflection(_ id: UUID, state: ConversationReflection.State, message: String) {
        guard let index = history.reflections.firstIndex(where: { $0.id == id }) else { return }
        history.reflections[index].state = state; history.reflections[index].finishedAt = .now
        if let entry = history.activityLog.firstIndex(where: { $0.id == history.reflections[index].activityID }) {
            history.activityLog[entry].outcome = state == .failed ? .failed : (state == .declined ? .dealDeclined : .cancelled)
            history.activityLog[entry].systemResponse = message
            history.activityLog[entry].completedAt = .now
        }
    }

    /// Called by the foreground shell, not the Chat view. Background/termination
    /// only advances the deadline, never grants access or consumes unlock minutes.
    func resumeReflections(snapshots: () -> [RuleSnapshotDTO], now: Date = .now) async {
        for reflection in pendingReflections where reflection.isPending {
            if now >= reflection.validUntil {
                finishReflection(reflection.id, state: .cancelled, message: CopyKey.reflectionExpired.string)
                do { try persist() } catch { errorMessage = CopyKey.conversationStorageError.string }
            }
        }
    }

    /// Consume a durable intent before registration. Skipping is explicit consent
    /// to the bounded unlock, never permission to bypass an existing hard wait.
    func completeReflection(_ id: UUID, skip: Bool = false, acceptDeal: Bool = false, snapshots: () -> [RuleSnapshotDTO], now: Date = .now) async {
        guard isForeground, !loadFailed, !completingReflections.contains(id),
              let index = history.reflections.firstIndex(where: { $0.id == id && $0.isPending }) else { return }
        guard preferences.hasConsent else {
            cancelReflection(id)
            errorMessage = CopyKey.aiConsentRequired.string
            return
        }
        let reflection = history.reflections[index]
        guard !reflection.awaitingCheckIn, !reflection.isChoice, now < reflection.validUntil, reflection.isDeal ? acceptDeal : (skip || reflection.isReady(at: now)) else { return }
        let current = snapshots()
        knownSnapshots = current
        guard reflection.fingerprint == ConversationGrantStore.fingerprint(current),
              reflection.usageProfile == history.usageProfiles[reflection.appID],
              let rule = current.first(where: { $0.id == reflection.appID && $0.isEnabled && $0.kind == .conversation }),
              let token = try? VolitionApps.selectedApp(in: AppSelectionCodec.decode(rule.selectionData)) else {
            finishReflection(id, state: .cancelled, message: CopyKey.conversationStaleRequest.string)
            try? persist(); return
        }
        guard waitUntil(for: reflection.appID, excludingDealGrantID: reflection.overridingDealID) == nil else {
            finishReflection(id, state: .failed, message: CopyKey.volitionWaitError.string)
            errorMessage = CopyKey.volitionWaitError.string; try? persist(); return
        }
        completingReflections.insert(id)
        defer { completingReflections.remove(id) }
        let beforeClaim = history
        history.reflections[index].state = .activating
        history.reflections[index].skipped = (skip || reflection.skipped) && !reflection.isDeal
        do { try persist() }
        catch {
            history = beforeClaim
            finishReflection(id, state: .failed, message: CopyKey.conversationStorageError.string)
            errorMessage = CopyKey.conversationStorageError.string
            try? persist()
            return
        }
        let access = access; let timer = timer
        var activated: ConversationGrantStore.Grant?
        do {
            let tokenData = try JSONEncoder().encode(token)
            _ = try await Task.detached { try access.sync(current, now: now) }.value
            guard isForeground, preferences.hasConsent,
                  history.reflections.first(where: { $0.id == id })?.state == .activating else { throw ConversationAccessError.staleRequest }
            activated = try await Task.detached {
                let isolatedToken = try JSONDecoder().decode(ApplicationToken.self, from: tokenData)
                return try access.approve(token: isolatedToken, minutes: reflection.unlockMinutes, fingerprint: reflection.fingerprint, timer: timer, blockMinutes: reflection.blockMinutes, overridingDealID: reflection.overridingDealID)
            }.value
            guard let grant = activated else { return }
            guard isForeground, preferences.hasConsent, history.reflections.first(where: { $0.id == id })?.state == .activating,
                  reflection.fingerprint == ConversationGrantStore.fingerprint(snapshots()),
                  reflection.usageProfile == history.usageProfiles[reflection.appID],
                  waitUntil(for: reflection.appID, excludingDealGrantID: grant.plan.grantID, replacingDealID: reflection.overridingDealID) == nil else { throw ConversationAccessError.staleRequest }
            let beforePublishing = history
            do {
                if let i = history.reflections.firstIndex(where: { $0.id == id }) {
                    history.reflections[i].state = .completed; history.reflections[i].finishedAt = .now
                }
                let marker = (reflection.isDeal ? CopyKey.dealAccepted : CopyKey.reflectionCompleted).string(reflection.appName, reflection.unlockMinutes)
                history.accessEvents.append(.init(date: grant.plan.start, appID: reflection.appID, appName: reflection.appName,
                    reason: reflection.reason, decision: .approve, reply: marker,
                    grantID: grant.plan.grantID, expiresAt: grant.plan.expiresAt))
                history.messages.append(.init(role: .event, text: marker))
                if let entry = history.activityLog.firstIndex(where: { $0.id == reflection.activityID }) {
                    history.activityLog[entry].outcome = .unlocked
                    history.activityLog[entry].systemResponse = marker; history.activityLog[entry].completedAt = .now
                    history.activityLog[entry].unlockMinutes = reflection.unlockMinutes
                    history.activityLog[entry].unlockUntil = grant.plan.expiresAt
                    history.activityLog[entry].grantID = grant.plan.grantID
                    history.activityLog[entry].reflectionSkipped = (skip || reflection.skipped) && !reflection.isDeal
                    history.activityLog[entry].blockMinutes = reflection.blockMinutes
                    history.activityLog[entry].waitUntil = reflection.blockMinutes.map { grant.plan.expiresAt.addingTimeInterval(Double($0 * 60)) }
                }
                history.lastGrantID = grants.first?.plan.grantID ?? grant.plan.grantID
                history.lastGrantExpiry = grants.first?.plan.expiresAt ?? grant.plan.expiresAt
                try persist()
            } catch { history = beforePublishing; throw error }
            grants.append(grant)
            if let replaced = reflection.overridingDealID,
               let index = dealCommitments.firstIndex(where: { $0.grantID == replaced }) {
                dealCommitments[index].overriddenAt = grant.plan.start
                dealCommitments[index].overrideGrantID = grant.plan.grantID
            }
            if let minutes = reflection.blockMinutes {
                dealCommitments.append(.init(grantID: grant.plan.grantID, token: token,
                    blockedUntil: grant.plan.expiresAt.addingTimeInterval(Double(minutes * 60))))
            }
            dealCommitments = (try? await Task.detached { try access.store.transaction { $0.dealCommitments } }.value) ?? dealCommitments
            grantVersion = UUID(); errorMessage = nil
            ConversationDiagnostics.live.log("reflection.activated id=\(id.logTag)")
        } catch {
            if let activated { try? await Task.detached { try access.end(grantID: activated.plan.grantID, cancelDeal: true) }.value }
            if history.reflections.first(where: { $0.id == id })?.state == .cancelled { return }
            if !isForeground, let i = history.reflections.firstIndex(where: { $0.id == id && $0.state == .activating }) {
                history.reflections[i].state = .counting
                try? persist(); return
            }
            let message = error is PersistenceFailure ? CopyKey.conversationStorageError.string :
                (error as? ConversationAccessError == .alreadyUnlocked ? CopyKey.conversationGrantActive.string : CopyKey.conversationGrantFailed.string)
            finishReflection(id, state: .failed, message: message)
            errorMessage = message
            try? persist()
            ConversationDiagnostics.live.log("reflection.failed access_not_granted")
        }
    }
}

extension ConversationCoordinator {
    func beginRemoval(appID: UUID, appName: String) throws -> UUID {
        let previous = history
        let attempt = ConversationRemovalAttempt(id: UUID(), appID: appID, appName: appName, date: .now)
        history.removalAttempts.append(attempt)
        var entry = ConversationActivityEntry(appID: appID, appName: appName,
            message: CopyKey.removalIntentRecorded.string, outcome: .removalRequested,
            systemResponse: CopyKey.removalIntentRecorded.string)
        entry.feedbackSignal = .highFrustration; entry.removalID = attempt.id
        history.activityLog.append(entry)
        do { try persist() } catch { history = previous; throw error }
        return attempt.id
    }
    func recordRemovalReason(_ id: UUID, reason: String) throws {
        let reason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !reason.isEmpty, reason.count <= 2000,
              let index = history.removalAttempts.firstIndex(where: { $0.id == id && $0.outcome == .considering }) else { throw PersistenceFailure() }
        let previous = history
        history.removalAttempts[index].reason = reason
        if let entry = history.activityLog.firstIndex(where: { $0.removalID == id }) { history.activityLog[entry].message = reason }
        do { try persist() } catch { history = previous; throw error }
    }
    func finishRemoval(_ id: UUID, outcome: ConversationRemovalAttempt.Outcome, minutes: Int? = nil) throws {
        guard let index = history.removalAttempts.firstIndex(where: { $0.id == id && $0.outcome == .considering }) else { return }
        if outcome == .temporaryUnlockRequested {
            guard let minutes, (1...60).contains(minutes), history.removalAttempts[index].reason != nil else { throw PersistenceFailure() }
        }
        let previous = history
        history.removalAttempts[index].outcome = outcome
        history.removalAttempts[index].requestedMinutes = minutes
        history.removalAttempts[index].completedAt = .now
        if let entry = history.activityLog.firstIndex(where: { $0.removalID == id }) {
            history.activityLog[entry].systemResponse = switch outcome {
            case .considering: CopyKey.removalIntentRecorded.string
            case .kept: CopyKey.removalKept.string
            case .removed: CopyKey.removalCompleted.string
            case .temporaryUnlockRequested: CopyKey.removalTemporaryRequested.string(minutes ?? 5)
            }
            history.activityLog[entry].completedAt = .now
        }
        do { try persist() } catch { history = previous; throw error }
    }
}

extension ConversationCoordinator {
    var feedbackEntry: ConversationActivityEntry? { history.activityLog.last.flatMap { $0.canRateExperience ? $0 : nil } }

    func rateExperience(_ rating: ConversationActivityEntry.ExperienceRating, activityID: UUID) {
        guard let index = history.activityLog.firstIndex(where: { $0.id == activityID && $0.canRateExperience }) else { return }
        let previous = history
        history.activityLog[index].experienceRating = rating
        history.activityLog[index].ratedAt = clock.now()
        do { try persist() } catch { history = previous; errorMessage = CopyKey.conversationStorageError.string }
    }
}
