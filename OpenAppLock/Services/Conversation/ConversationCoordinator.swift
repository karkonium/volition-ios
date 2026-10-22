import FamilyControls
import ManagedSettings
import Foundation
import Observation
import SwiftData

/// Owns shared chat, saved app identity and timestamped cross-app access outcomes.
/// Independent app grants preserve each expiry. Per-app waits persist while chat
/// remains available; local validation prevents approval before that app’s deadline. Clearing messages retains access outcomes and an active wait.
/// Only confirmed grants enter access history; returning after expiry records it.
/// Captures target/configuration per request and revalidates after every await.
/// Clearing history or changing a rule invalidates in-flight model decisions.
/// The unsent draft lives here for the session so sidebar view replacement does
/// not discard it; it is not saved to history or sent until Send is pressed.
@Observable
final class ConversationCoordinator {
    var selectedSection: AppSection = .chat
    private(set) var target: ApplicationToken?
    private(set) var nickname = ""
    var draftMessage = ""
    private(set) var history = ConversationHistory()
    private(set) var isSending = false
    private(set) var grants: [ConversationGrantStore.Grant] = []
    var grant: ConversationGrantStore.Grant? { grants.first { $0.token == target } }
    private var grantVersion = UUID()
    var errorMessage: String?
    private let client: any ConversationClient
    let keys: any ConversationKeyStoring
    private let historyStore: any ConversationHistoryStoring
    private let access: ConversationEnforcement
    private let timer: any ConversationTimerScheduling
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
        return until.flatMap { $0 > Date() ? $0 : nil }
    }
    func appName(for grant: ConversationGrantStore.Grant) -> String {
        ConversationGrantStore.applicable(to: grant.token, in: knownSnapshots).first?.name ?? CopyKey.conversationTargetGeneric.string
    }

    convenience init(context: ModelContext, client: any ConversationClient = OpenAIConversationClient(),
         keys: any ConversationKeyStoring = ConversationEnvironmentKeyStore(),
         access: ConversationEnforcement = ConversationEnforcement(store: ConversationGrantStore(), shields: ManagedSettingsShieldController()),
         timer: any ConversationTimerScheduling = DeviceConversationTimer()) {
        self.init(historyStore: ConversationHistoryStore(context: context), client: client, keys: keys, access: access, timer: timer)
    }

    init(historyStore: any ConversationHistoryStoring, client: any ConversationClient = OpenAIConversationClient(),
         keys: any ConversationKeyStoring = ConversationEnvironmentKeyStore(),
         access: ConversationEnforcement = ConversationEnforcement(store: ConversationGrantStore(), shields: ManagedSettingsShieldController()),
         timer: any ConversationTimerScheduling = DeviceConversationTimer()) {
        self.client = client
        self.keys = keys
        ConversationDiagnostics.live.log("config.loaded source=\(keys is ConversationEnvironmentKeyStore ? "bundled-env" : "injected") key_present=\((try? keys.read()) != nil)")
        self.historyStore = historyStore
        self.access = access
        self.timer = timer
        do { history = try historyStore.load() }
        catch {
            ConversationDiagnostics.live.log("history.load_failed requests_disabled")
            loadFailed = true; errorMessage = CopyKey.conversationStorageError.string
        }
    }

    func select(_ token: ApplicationToken) {
        if target != token { requestID = nil; generation = UUID(); nickname = "" }
        target = token
        errorMessage = nil
        nickname = ConversationGrantStore.applicable(to: token, in: knownSnapshots).first?.name ?? ""
        selectedSection = .chat
    }

    func refresh(snapshots: [RuleSnapshotDTO]) async {
        knownSnapshots = snapshots
        let observedGrantVersion = grantVersion
        do {
            let access = access
            let state = try await Task.detached {
                let grants = try access.store.transaction { $0.activeGrants }
                let pending = try access.store.consumePending()
                return (grants, pending)
            }.value
            if observedGrantVersion == grantVersion { grants = state.0.filter { !$0.plan.hasExpired(at: .now) } }
            if target == nil, let first = grants.first { target = first.token }
            if let pending = state.1,
               !ConversationGrantStore.applicable(to: pending, in: snapshots).isEmpty { select(pending) }
            if let target { nickname = ConversationGrantStore.applicable(to: target, in: snapshots).first?.name ?? "" }
            if let target, ConversationGrantStore.applicable(to: target, in: snapshots).isEmpty {
                self.target = nil; requestID = nil; generation = UUID()
            }
            let activeIDs = Set(grants.map(\.plan.grantID))
            var recordedEndIDs = Set<UUID>()
            for index in history.accessEvents.indices {
                guard let id = history.accessEvents[index].grantID,
                      history.accessEvents[index].endedAt == nil, !activeIDs.contains(id) else { continue }
                let expiry = history.accessEvents[index].expiresAt ?? .now
                let expired = expiry <= Date()
                history.accessEvents[index].endedAt = expired ? expiry : .now
                recordedEndIDs.insert(id)
                try append(.event, "\(history.accessEvents[index].appName): \(expired ? CopyKey.conversationGrantExpired.string : CopyKey.conversationGrantEnded.string)")
            }
            if let id = history.lastGrantID, !activeIDs.contains(id), !recordedEndIDs.contains(id) {
                let expired = (history.lastGrantExpiry ?? .distantPast) <= Date()
                try append(.event, expired ? CopyKey.conversationGrantExpired.string : CopyKey.conversationGrantEnded.string)
            }
            history.lastGrantID = grants.first?.plan.grantID
            history.lastGrantExpiry = grants.first?.plan.expiresAt
            try persist()
        } catch { errorMessage = CopyKey.conversationStorageError.string }
    }

    func send(_ text: String, rules: [BlockingRule]) async {
        await send(text, snapshots: { rules.filter { !$0.isDeleted }.map(\.dto) })
    }

    func send(_ text: String, snapshots: () -> [RuleSnapshotDTO]) async {
        guard !isSending, !loadFailed else {
            ConversationDiagnostics.live.log("send.skipped reason=\(loadFailed ? "history_load_failed" : "busy")")
            return
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 4000, let target else {
            ConversationDiagnostics.live.log("send.skipped invalid_input_or_missing_target")
            return
        }
        ConversationDiagnostics.live.log("send.begin messages=\(history.messages.count)")
        let key: String
        do {
            guard let stored = try keys.read(), !stored.isEmpty else {
                ConversationDiagnostics.live.log("key.missing request_not_sent")
                errorMessage = CopyKey.conversationMissingKey.string; return
            }
            key = stored
            ConversationDiagnostics.live.log("key.loaded request_ready")
        } catch {
            ConversationDiagnostics.live.log("key.load_failed request_not_sent")
            errorMessage = CopyKey.conversationMissingKey.string; return
        }
        let initial = snapshots()
        knownSnapshots = initial
        let syncInstant = Date()
        let applicable = ConversationGrantStore.applicable(to: target, in: initial)
        guard !applicable.isEmpty else {
            ConversationDiagnostics.live.log("send.skipped no_applicable_rule")
            errorMessage = CopyKey.conversationStaleRequest.string; return
        }
        nickname = applicable[0].name
        let fingerprint = ConversationGrantStore.fingerprint(initial)
        let currentGeneration = generation
        let id = requestID ?? UUID()
        isSending = true
        errorMessage = nil
        defer { isSending = false }
        var stage = "enforcement_sync"
        var activatedForRequest: ConversationGrantStore.Grant?
        var attemptedApproval = false
        do {
            let access = access
            _ = try await Task.detached { try access.sync(initial, now: syncInstant) }.value
            guard generation == currentGeneration else { return }
            stage = "history_save"
            if requestID == nil {
                requestID = id
                let name = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
                try append(.event, CopyKey.conversationRequestMarker.string(name.isEmpty ? CopyKey.conversationTargetGeneric.string : String(name.prefix(100))), request: id)
            }
            // Retrying an unanswered network request reuses its saved user turn.
            if history.messages.last?.role != .user || history.messages.last?.text != trimmed || history.messages.last?.requestID != id {
                try append(.user, trimmed, request: id)
            }
            if history.recentMessages.count > 60 {
                let count = history.messages.count - 30
                let older = Array(history.messages[history.summarizedCount..<count])
                stage = "summary_request"
                ConversationDiagnostics.live.log("summary.begin messages=\(older.count)")
                let summary = try await client.summarize(memory: history.memory, messages: older, apiKey: key)
                guard generation == currentGeneration else { return }
                history.memory = summary; history.summarizedCount = count
                try persist()
            }
            let contextInstant = Date()
            let context = ConversationContext(goals: applicable.map(\.conversationGoal),
                appNickname: String(nickname.prefix(100)), memory: history.memory,
                recentMessages: history.recentMessages, currentTime: contextInstant, currentAppID: applicable[0].id, accessEvents: Array(history.accessEvents.suffix(100)),
                activitySummary: .init(events: history.accessEvents, appID: applicable[0].id, now: contextInstant),
                activeUnlocks: grants.filter { !$0.plan.hasExpired(at: contextInstant) }.map {
                    .init(appID: ConversationGrantStore.applicable(to: $0.token, in: initial).first?.id,
                        appName: appName(for: $0), expiresAt: $0.plan.expiresAt)
                }, waitUntil: waitUntil(for: applicable[0].id))
            stage = "decision_request"
            let response = try await client.respond(to: context, apiKey: key)
            let decision = try ConversationDecision.parse(JSONEncoder().encode(response))
            guard generation == currentGeneration, self.target == target,
                  fingerprint == ConversationGrantStore.fingerprint(snapshots()) else {
                ConversationDiagnostics.live.log("decision.discarded stale_configuration")
                errorMessage = CopyKey.conversationStaleRequest.string; requestID = nil; return
            }
            ConversationDiagnostics.live.log("decision.received decision=\(decision.decision.rawValue) minutes=\(decision.unlockMinutes ?? 0) wait_minutes=\(decision.waitMinutes ?? 0)")
            stage = "assistant_save"
            if decision.decision != .approve { try append(.assistant, decision.reply, request: id) }
            var event = ConversationAccessEvent(date: .now, appID: applicable[0].id,
                appName: nickname, reason: trimmed, decision: decision.decision, reply: decision.reply)
            if decision.decision == .approve, let minutes = decision.unlockMinutes {
                attemptedApproval = true
                if waitUntil(for: applicable[0].id) != nil { throw ConversationAccessError.waiting }
                let access = access; let timer = timer
                stage = "grant_registration"
                ConversationDiagnostics.live.log("grant.begin rule=\(applicable[0].id.logTag) minutes=\(minutes)")
                let activated = try await Task.detached {
                    return try access.approve(token: target, minutes: minutes, fingerprint: fingerprint, timer: timer)
                }.value
                activatedForRequest = activated
                // Clearing history/target while registration was in flight must not activate stale access.
                guard generation == currentGeneration,
                      fingerprint == ConversationGrantStore.fingerprint(snapshots()) else {
                    try await Task.detached { try access.end(grantID: activated.plan.grantID) }.value
                    errorMessage = CopyKey.conversationStaleRequest.string
                    return
                }
                ConversationDiagnostics.live.log("grant.activated id=\(activated.plan.grantID.logTag) minutes=\(minutes)")
                stage = "grant_save"
                grants.append(activated)
                grantVersion = UUID()
                history.lastGrantID = grants.first?.plan.grantID
                history.lastGrantExpiry = grants.first?.plan.expiresAt
                event.date = activated.plan.start
                event.grantID = activated.plan.grantID
                event.expiresAt = activated.plan.expiresAt
                history.accessEvents.append(event)
                try append(.assistant, decision.reply, request: id)
                try append(.event, minutes == 1 ? CopyKey.conversationApprovalOne.string : CopyKey.conversationApprovalMarker.string(minutes), request: id)
                requestID = nil
            } else {
                if decision.decision == .wait, let minutes = decision.waitMinutes {
                    history.cooldownUntil = waitUntil(for: applicable[0].id) ?? Date().addingTimeInterval(Double(minutes * 60))
                    event.waitUntil = history.cooldownUntil
                    ConversationDiagnostics.live.log("cooldown.started minutes=\(minutes)")
                }
                history.accessEvents.append(event)
                try persist()
                if decision.decision != .ask { requestID = nil }
            }
        } catch {
            let reason = (error as? ConversationClientError)?.diagnosticSummary ?? (error is PersistenceFailure ? "persistence" : (error as? ConversationAccessError).map { "enforcement_" + String(describing: $0) } ?? "unexpected")
            ConversationDiagnostics.live.log("send.failed stage=\(stage) reason=\(reason) access_not_granted")
            if let activated = activatedForRequest {
                let access = access
                try? await Task.detached { try access.end(grantID: activated.plan.grantID) }.value
                history.accessEvents.removeAll { $0.grantID == activated.plan.grantID }
                grants.removeAll { $0.plan.grantID == activated.plan.grantID }
                grantVersion = UUID()
                history.lastGrantID = grants.first?.plan.grantID; history.lastGrantExpiry = grants.first?.plan.expiresAt
            }
            if let until = waitUntil(for: applicable[0].id), error as? ConversationAccessError == .waiting {
                errorMessage = CopyKey.volitionWaitError.string(until.formatted(date: .omitted, time: .shortened))
            } else if error as? ConversationAccessError == .alreadyUnlocked {
                errorMessage = CopyKey.conversationGrantActive.string
            } else if error is PersistenceFailure { errorMessage = CopyKey.conversationStorageError.string }
            else if let failure = error as? ConversationClientError { errorMessage = failure.copyKey.string }
            else { errorMessage = error is ConversationAccessError ? CopyKey.conversationGrantFailed.string : CopyKey.conversationNetworkError.string }
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
            finishAccessEvent(id: id, at: .now)
            grants.removeAll { $0.plan.grantID == id }
            grantVersion = UUID()
            history.lastGrantID = grants.first?.plan.grantID
            history.lastGrantExpiry = grants.first?.plan.expiresAt
            try append(.event, CopyKey.conversationGrantEnded.string)
        } catch { errorMessage = CopyKey.conversationStorageError.string }
    }

    func clearHistory() {
        ConversationDiagnostics.live.log("history.clear_requested")
        generation = UUID(); requestID = nil
        let previous = history
        history = ConversationHistory()
        history.cooldownUntil = previous.cooldownUntil
        history.accessEvents = previous.accessEvents
        history.lastGrantID = grants.first?.plan.grantID
        history.lastGrantExpiry = grants.first?.plan.expiresAt
        do { try persist(); loadFailed = false }
        catch { history = previous; errorMessage = CopyKey.conversationStorageError.string }
    }

    func cancelRequest() {
        generation = UUID(); requestID = nil
        // The URLSession call may finish, but its result cannot authorize access.
    }

    private func finishAccessEvent(id: UUID, at date: Date) {
        if let index = history.accessEvents.firstIndex(where: { $0.grantID == id }) {
            history.accessEvents[index].endedAt = date
        }
    }

    private func append(_ role: ConversationMessage.Role, _ text: String, request: UUID? = nil) throws {
        history.messages.append(.init(role: role, text: text, requestID: request))
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
