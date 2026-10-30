import FamilyControls
import Foundation
import ManagedSettings
import Testing
@testable import OpenAppLock

@MainActor
@Suite("Shared conversation lifecycle", .serialized)
struct ConversationCoordinatorTests {
    private func setup(priorPause: Bool = false, client: any ConversationClient = MockConversationClient(), shields: any ShieldApplying = MockShieldController(), selectTarget: Bool = true, hardWait: Bool = false, requests: ConversationRequestStore = .init(), checkIn: Bool = false, pauseAttempts: Int = 0) throws -> (ConversationCoordinator, HistoryMemory, RuleSnapshotDTO, ApplicationToken) {
        let token = try JSONDecoder().decode(ApplicationToken.self,
            from: JSONSerialization.data(withJSONObject: ["data": Data([1]).base64EncodedString()]))
        var selection = FamilyActivitySelection(); selection.applicationTokens = [token]
        let rule = RuleSnapshotDTO(id: UUID(), name: "Coach", kindRaw: "conversation", isEnabled: true,
            hardMode: false, selectionModeRaw: "block", selectionData: AppSelectionCodec.encode(selection),
            dayNumbers: [], startMinutes: 0, endMinutes: 0, dailyLimitMinutes: 45, maxOpens: 5,
            conversationGoal: "Use with purpose")
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let history = HistoryMemory()
        if hardWait {
            history.value.accessEvents = [.init(date: .now, appID: rule.id, appName: rule.name,
                reason: "Previously agreed wait", decision: .wait, reply: "Agreed.", waitUntil: Date().addingTimeInterval(180))]
            history.value.cooldownUntil = history.value.accessEvents.first?.waitUntil
        }
        for _ in 0..<(priorPause ? max(1, pauseAttempts) : pauseAttempts) {
            var pause = ConversationReflection(appID: rule.id, appName: rule.name, reason: "Boredom", reply: "Pause", unlockMinutes: 3,
                seconds: 10, fingerprint: ConversationGrantStore.fingerprint([rule]), activityID: UUID(), now: .now.addingTimeInterval(-60))
            pause.state = .completed; pause.finishedAt = .now.addingTimeInterval(-45)
            history.value.reflections.append(pause)
        }
        let coordinator = ConversationCoordinator(historyStore: history, preferences: .testing(), client: client,
            keys: MockConversationKeyStore(),
            access: .init(store: .init(fileURL: directory.appendingPathComponent("access.json")), shields: shields),
            timer: MockConversationTimer(), requestStore: requests, checkInRoll: { checkIn })
        if selectTarget { coordinator.select(token) }
        return (coordinator, history, rule, token)
    }

    @Test("Repeated shield requests return to Chat; notification links select their own app")
    func repeatedShieldRequestsAndNotificationLinks() async throws {
        let defaults = try #require(UserDefaults(suiteName: "Routing-\(UUID().uuidString)"))
        let requests = ConversationRequestStore(defaults: defaults)
        let (coordinator, history, first, original) = try setup(requests: requests)
        let other = try JSONDecoder().decode(ApplicationToken.self,
            from: JSONSerialization.data(withJSONObject: ["data": Data([23]).base64EncodedString()]))
        var selection = FamilyActivitySelection(); selection.applicationTokens = [other]
        var second = first; second.id = UUID(); second.name = "Maps"; second.selectionData = AppSelectionCodec.encode(selection)
        let oldNotification = requests.begin(token: original, appID: first.id)
        _ = requests.begin(token: other, appID: second.id)
        coordinator.selectedSection = .settings
        await coordinator.refresh(snapshots: [first, second], consumeRequests: false)
        #expect(requests.pending() != nil)
        #expect(coordinator.target == original)
        await coordinator.refresh(snapshots: [first, second])
        #expect(coordinator.target == other)
        #expect(coordinator.selectedSection == .chat)
        #expect(requests.pending() == nil)
        coordinator.openRequestURL(try #require(oldNotification.url), snapshots: [first, second])
        #expect(coordinator.target == original)
        _ = requests.begin(token: other, appID: second.id)
        coordinator.selectedSection = .apps
        await coordinator.refresh(snapshots: [first, second])
        #expect(coordinator.target == other)
        #expect(coordinator.selectedSection == .chat)
        #expect(coordinator.grants.isEmpty)
        #expect(history.value.accessEvents.isEmpty)
        var disabled = first; disabled.isEnabled = false
        coordinator.openRequestURL(try #require(oldNotification.url), snapshots: [disabled, second])
        #expect(coordinator.target == other)
    }

    @Test("A named saved app routes a request without manual selection")
    func namedAppRouting() async throws {
        let (coordinator, history, rule, token) = try setup(selectTarget: false)
        await coordinator.send("approve COACH for a task", snapshots: { [rule] })
        #expect(coordinator.target == token)
        #expect(coordinator.grant != nil)
        let entry = try #require(history.value.activityLog.last)
        #expect(entry.outcome == .unlocked)
        #expect(entry.appID == rule.id)
        #expect(entry.message == "approve COACH for a task")
        #expect(entry.modelDecision == .approve)
        #expect(entry.unlockUntil != nil)
        coordinator.clearHistory()
        #expect(history.value.activityLog.last?.id == entry.id)
        await coordinator.endUnlock()
        #expect(history.value.activityLog.last?.endedAt != nil)
    }

    @Test("An unresolved request asks for selection without sending or losing its message")
    func noAppGuidance() async throws {
        let client = RecordingConversationClient()
        let (coordinator, history, rule, _) = try setup(client: client, selectTarget: false)
        await coordinator.send("Please unlock it", snapshots: { [rule] })
        #expect(await client.contexts().isEmpty)
        #expect(coordinator.appSelectionNeeded)
        #expect(coordinator.selectionAttention == 1)
        #expect(history.value.messages.isEmpty)
        #expect(history.value.activityLog.last?.outcome == .selectionRequired)
        #expect(history.value.activityLog.last?.message == "Please unlock it")
        coordinator.clearActivityLog()
        #expect(history.value.activityLog.isEmpty)
    }

    @Test("Explicit selection resolves a message naming multiple apps")
    func ambiguousMessageCanBeConfirmed() async throws {
        let client = RecordingConversationClient()
        let (coordinator, history, first, _) = try setup(client: client, selectTarget: false)
        let token = try JSONDecoder().decode(ApplicationToken.self,
            from: JSONSerialization.data(withJSONObject: ["data": Data([3]).base64EncodedString()]))
        var selection = FamilyActivitySelection(); selection.applicationTokens = [token]
        var second = first; second.id = UUID(); second.name = "Maps"
        second.selectionData = AppSelectionCodec.encode(selection)
        let message = "Coach or Maps for directions"
        await coordinator.send(message, snapshots: { [first, second] })
        #expect(coordinator.appSelectionNeeded)
        #expect(await client.contexts().isEmpty)
        coordinator.select(token)
        await coordinator.send(message, snapshots: { [first, second] })
        #expect(await client.contexts().last?.currentAppID == second.id)
        #expect(!coordinator.appSelectionNeeded)
        #expect(history.value.activityLog.map(\.outcome) == [.selectionRequired, .asked])
    }

    @Test("A failed initial log save does not send or leave a pending request")
    func failedInitialLogSave() async throws {
        let client = RecordingConversationClient()
        let (coordinator, history, rule, _) = try setup(client: client)
        history.failNextSave = true
        await coordinator.send("Hello", snapshots: { [rule] })
        #expect(await client.contexts().isEmpty)
        #expect(coordinator.history.activityLog.last?.outcome == .failed)
        #expect(coordinator.errorMessage == CopyKey.conversationStorageError.string)
        #expect(history.value.activityLog.last?.outcome == .failed)
    }

    @Test("Cancelling a request remains cancelled regardless of the late network result", arguments: [false, true])
    func cancelledRequestIsLogged(networkFails: Bool) async throws {
        let client = GatedConversationClient()
        let (coordinator, history, rule, _) = try setup(client: client)
        let task = Task { await coordinator.send("approve", snapshots: { [rule] }) }
        await client.waitUntilStarted()
        coordinator.cancelRequest()
        #expect(history.value.activityLog.last?.outcome == .cancelled)
        if networkFails { await client.fail() } else { await client.complete() }
        await task.value
        #expect(history.value.activityLog.last?.outcome == .cancelled)
        #expect(coordinator.grants.isEmpty)
    }

    @Test("Failed release logs a failed outcome even when the coach approved")
    func actualOutcomeLog() async throws {
        let (coordinator, history, rule, _) = try setup(shields: UnreleasedShield())
        await coordinator.send("approve now", snapshots: { [rule] })
        let entry = try #require(history.value.activityLog.last)
        #expect(entry.modelDecision == .approve)
        #expect(entry.outcome == .failed)
        #expect(entry.coachResponse != nil)
        #expect(entry.systemResponse == coordinator.errorMessage)
        #expect(entry.unlockUntil == nil)
        #expect(coordinator.grant == nil)
    }

    @Test("Wait persists for its app while chat and another app remain available")
    func waiting() async throws {
        let client = WaitingConversationClient()
        let (coordinator, history, rule, original) = try setup(client: client, hardWait: true)
        await coordinator.send("More time", snapshots: { [rule] })
        let until = try #require(history.value.cooldownUntil)
        #expect(until > Date())
        #expect(coordinator.grant == nil)
        coordinator.clearHistory()
        #expect(history.value.cooldownUntil == until)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let restored = ConversationCoordinator(historyStore: history, preferences: .testing(), client: client, keys: MockConversationKeyStore(),
            access: .init(store: .init(fileURL: directory.appendingPathComponent("access.json")), shields: MockShieldController()), timer: MockConversationTimer())
        let another = try JSONDecoder().decode(ApplicationToken.self,
            from: JSONSerialization.data(withJSONObject: ["data": Data([8]).base64EncodedString()]))
        var selection = FamilyActivitySelection(); selection.applicationTokens = [another]
        var second = rule; second.id = UUID(); second.selectionData = AppSelectionCodec.encode(selection)
        restored.select(another)
        await restored.send("approve now", snapshots: { [rule, second] })
        #expect(await client.calls == 2)
        #expect(restored.grant == nil)
        restored.select(original)
        #expect(restored.cooldownUntil == until)
    }

    @Test("An elapsed wait allows a request and sends structured cross-app history")
    func expiredWaitAndContext() async throws {
        let client = RecordingConversationClient()
        let (_, history, rule, token) = try setup(client: client)
        history.value.cooldownUntil = Date().addingTimeInterval(-1)
        history.value.accessEvents = [.init(date: Date().addingTimeInterval(-300), appID: UUID(),
            appName: "Another app", reason: "Contact a friend", decision: .approve, reply: "Take a minute.",
            grantID: UUID(), expiresAt: Date().addingTimeInterval(-240), endedAt: Date().addingTimeInterval(-240))]
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let restored = ConversationCoordinator(historyStore: history, preferences: .testing(), client: client, keys: MockConversationKeyStore(),
            access: .init(store: .init(fileURL: directory.appendingPathComponent("access.json")), shields: MockShieldController()), timer: MockConversationTimer())
        restored.select(token)
        await restored.send("Ready now", snapshots: { [rule] })
        let received = try #require(await client.contexts().last)
        #expect(received.appNickname == rule.name)
        #expect(received.currentAppID == rule.id)
        #expect(received.activitySummary?.grantsLastHour == 1)
        #expect(received.goals == [rule.conversationGoal])
        #expect(received.accessEvents.first?.appName == "Another app")
        #expect(received.accessEvents.first?.reason == "Contact a friend")
        #expect(restored.cooldownUntil == nil)
    }

    @Test("Saved app name, intention and exact grant history reach the next request")
    func savedContextAndOutcomes() async throws {
        let (coordinator, history, rule, _) = try setup()
        await coordinator.send("approve to message a friend", snapshots: { [rule] })
        #expect(coordinator.nickname == rule.name)
        let event = try #require(history.value.accessEvents.first)
        #expect(event.appName == rule.name)
        #expect(event.reason == "approve to message a friend")
        #expect(event.grantID != nil)
        #expect(event.expiresAt != nil)
        await coordinator.endUnlock()
        #expect(history.value.accessEvents.first?.endedAt != nil)
    }

    @Test("Failed shield release never displays a successful approval or starts a timer")
    func shieldFailure() async throws {
        let (coordinator, history, rule, _) = try setup(shields: UnreleasedShield())
        await coordinator.send("approve", snapshots: { [rule] })
        #expect(coordinator.grant == nil)
        #expect(history.value.lastGrantID == nil)
        #expect(history.value.accessEvents.isEmpty)
        #expect(!history.value.messages.contains { $0.role == .assistant })
        #expect(coordinator.errorMessage == CopyKey.conversationGrantFailed.string)
    }

    @Test("Follow-up, denial and approval remain in the shared persisted chat")
    func sharedHistory() async throws {
        let (coordinator, history, rule, _) = try setup()
        await coordinator.send("Hello", snapshots: { [rule] })
        #expect(coordinator.grant == nil)
        await coordinator.send("deny", snapshots: { [rule] })
        #expect(coordinator.grant == nil)
        await coordinator.send("approve", snapshots: { [rule] })
        #expect(coordinator.grant?.plan.minutes == 1)
        #expect(history.value.messages.filter { $0.role == .assistant }.count == 3)
        #expect(history.value.lastGrantID != nil)
        await coordinator.endUnlock()
        #expect(coordinator.grant == nil)
        #expect(history.value.messages.last?.text == CopyKey.conversationGrantEnded.string)
    }

    @Test("API authentication and quota errors reach chat without granting access", arguments: [
        ConversationClientError.http(status: 401, code: "invalid_api_key"),
        ConversationClientError.http(status: 429, code: "insufficient_quota"),
        ConversationClientError.transport(code: -1009),
        ConversationClientError.response(reason: "not_completed")
    ])
    func actionableError(failure: ConversationClientError) async throws {
        let (coordinator, _, rule, _) = try setup(client: FailingConversationClient(failure: failure))
        await coordinator.send("Hello", snapshots: { [rule] })
        #expect(coordinator.grant == nil)
        #expect(coordinator.errorMessage == failure.copyKey.string)
        #expect(!coordinator.isSending)
    }

    @Test("A second app target preserves the earlier grant and expiry")
    func activeTargetIsPreserved() async throws {
        let (coordinator, _, rule, original) = try setup()
        await coordinator.send("approve", snapshots: { [rule] })
        let expiry = coordinator.grant?.plan.expiresAt
        let other = try JSONDecoder().decode(ApplicationToken.self,
            from: JSONSerialization.data(withJSONObject: ["data": Data([2]).base64EncodedString()]))
        coordinator.select(other)
        #expect(coordinator.target == other)
        #expect(coordinator.grants.first?.token == original)
        #expect(coordinator.grants.first?.plan.expiresAt == expiry)
        #expect(coordinator.errorMessage == nil)
    }

    @Test("Chatting while unlocked and requesting another app retains independent grants")
    func continuedChatAndAnotherApp() async throws {
        let (coordinator, _, first, _) = try setup()
        let token = try JSONDecoder().decode(ApplicationToken.self,
            from: JSONSerialization.data(withJSONObject: ["data": Data([7]).base64EncodedString()]))
        var selection = FamilyActivitySelection(); selection.applicationTokens = [token]
        var second = first; second.id = UUID(); second.name = "Second app"; second.selectionData = AppSelectionCodec.encode(selection)
        let rules = [first, second]
        await coordinator.send("approve", snapshots: { rules })
        let original = try #require(coordinator.grant)
        await coordinator.send("Hello", snapshots: { rules })
        #expect(coordinator.grant?.plan == original.plan)
        #expect(coordinator.history.messages.last?.role == .assistant)
        coordinator.select(token)
        await coordinator.send("approve", snapshots: { rules })
        #expect(coordinator.grants.count == 2)
        #expect(coordinator.grants.first?.plan == original.plan)
        await coordinator.endUnlock(grantID: original.plan.grantID)
        #expect(coordinator.grants.count == 1)
        #expect(coordinator.grant?.token == token)
        await coordinator.send("approve", snapshots: { rules })
        #expect(coordinator.grants.count == 1)
        #expect(coordinator.errorMessage == CopyKey.conversationGrantActive.string)
    }

    @Test("An API failure for another app cannot cancel an existing unlock")
    func otherRequestFailurePreservesGrant() async throws {
        let client = FailsSecondConversationClient()
        let (coordinator, _, first, _) = try setup(client: client)
        let token = try JSONDecoder().decode(ApplicationToken.self,
            from: JSONSerialization.data(withJSONObject: ["data": Data([9]).base64EncodedString()]))
        var selection = FamilyActivitySelection(); selection.applicationTokens = [token]
        var second = first; second.id = UUID(); second.selectionData = AppSelectionCodec.encode(selection)
        let rules = [first, second]
        await coordinator.send("approve", snapshots: { rules })
        let original = try #require(coordinator.grant)
        coordinator.select(token)
        await coordinator.send("Another task", snapshots: { rules })
        #expect(coordinator.grants.map(\.plan.grantID) == [original.plan.grantID])
        #expect(coordinator.grants.first?.plan.expiresAt == original.plan.expiresAt)
    }

    @Test("A wait permits conversation but cannot locally approve that same app early")
    func waitAllowsDiscussionWithoutGrant() async throws {
        let (coordinator, history, rule, _) = try setup(hardWait: true)
        await coordinator.refresh(snapshots: [rule])
        let deadline = try #require(coordinator.cooldownUntil)
        await coordinator.send("Hello", snapshots: { [rule] })
        #expect(history.value.messages.last?.role == .assistant)
        await coordinator.send("approve", snapshots: { [rule] })
        #expect(coordinator.grants.isEmpty)
        #expect(coordinator.cooldownUntil == deadline)
        #expect(coordinator.errorMessage != nil)
        #expect(history.value.activityLog.map(\.outcome) == [.wait, .asked, .blockedByWait])
        #expect(history.value.activityLog.last?.modelDecision == .approve)
        #expect(coordinator.clearActivityLog())
        #expect(history.value.activityLog.isEmpty)
        #expect(coordinator.cooldownUntil == deadline)
        #expect(history.value.accessEvents.count == 2)
    }

    @Test("Switching apps sends the earlier conversation as shared context")
    func memoryAcrossApps() async throws {
        let client = RecordingConversationClient()
        let (coordinator, _, first, _) = try setup(client: client)
        await coordinator.send("First app reason", snapshots: { [first] })
        let token = try JSONDecoder().decode(ApplicationToken.self,
            from: JSONSerialization.data(withJSONObject: ["data": Data([2]).base64EncodedString()]))
        var selection = FamilyActivitySelection(); selection.applicationTokens = [token]
        var second = first
        second.id = UUID(); second.selectionData = AppSelectionCodec.encode(selection)
        coordinator.select(token)
        await coordinator.send("Second app reason", snapshots: { [first, second] })
        let contexts = await client.contexts()
        #expect(contexts.count == 2)
        #expect(contexts.last?.recentMessages.contains { $0.text == "First app reason" } == true)
        #expect(contexts.last?.recentMessages.contains { $0.text == "Second app reason" } == true)
    }

    @Test("Clearing history while a response is pending prevents its approval")
    func clearCancelsResponse() async throws {
        let client = GatedConversationClient()
        let (coordinator, history, rule, _) = try setup(client: client)
        let task = Task { await coordinator.send("approve", snapshots: { [rule] }) }
        await client.waitUntilStarted()
        coordinator.clearHistory()
        await client.complete()
        await task.value
        #expect(coordinator.grant == nil)
        #expect(history.value.messages.isEmpty)
    }

    @Test("Rule edits while a response is pending prevent its approval")
    func staleResponse() async throws {
        let client = GatedConversationClient()
        let (coordinator, _, rule, _) = try setup(client: client)
        let box = RuleBox(rule: rule)
        let task = Task { await coordinator.send("approve", snapshots: { [box.rule] }) }
        await client.waitUntilStarted()
        box.rule.conversationGoal = "New goal"
        await client.complete()
        await task.value
        #expect(coordinator.grant == nil)
        #expect(coordinator.errorMessage == CopyKey.conversationStaleRequest.string)
    }

    @Test("Clearing history retains the active grant's original expiry")
    func clearRetainsExpiry() async throws {
        let (coordinator, history, rule, _) = try setup()
        await coordinator.send("approve", snapshots: { [rule] })
        let expiry = coordinator.grant?.plan.expiresAt
        coordinator.clearHistory()
        #expect(coordinator.grant?.plan.expiresAt == expiry)
        #expect(history.value.messages.isEmpty)
        #expect(history.value.lastGrantExpiry == expiry)
    }

    @Test("A transcript save failure after approval revokes the new grant")
    func failedApprovalSave() async throws {
        let (coordinator, history, rule, _) = try setup()
        history.failApprovalSave = true
        await coordinator.send("approve", snapshots: { [rule] })
        #expect(coordinator.grant == nil)
        #expect(coordinator.errorMessage == CopyKey.conversationStorageError.string)
        #expect(history.value.activityLog.last?.outcome == .failed)
        #expect(history.value.activityLog.last?.modelDecision == .approve)
        await coordinator.refresh(snapshots: [rule])
        #expect(coordinator.grant == nil)
    }

    @Test("No consent means no provider transmission")
    func explicitConsentRequired() async throws {
        let client = RecordingConversationClient()
        let (coordinator, history, rule, _) = try setup(client: client)
        coordinator.setAIConsent(false)
        await coordinator.send("Hello", snapshots: { [rule] })
        #expect(await client.contexts().isEmpty)
        #expect(history.value.messages.isEmpty)
        #expect(coordinator.errorMessage == CopyKey.aiConsentRequired.string)
    }

    @Test("Withdrawing consent invalidates an in-flight approval")
    func withdrawConsent() async throws {
        let client = GatedConversationClient()
        let (coordinator, _, rule, _) = try setup(client: client)
        let task = Task { await coordinator.send("approve", snapshots: { [rule] }) }
        await client.waitUntilStarted()
        coordinator.setAIConsent(false)
        #expect(!coordinator.isSending)
        await client.complete()
        await task.value
        #expect(coordinator.grants.isEmpty)
    }

    @Test("A cancelled reply cannot clear the busy state or publish into a newer request")
    func immediateResendAfterCancellation() async throws {
        let client = SequencedConversationClient()
        let (coordinator, _, rule, _) = try setup(client: client)
        let first = Task { await coordinator.send("first", snapshots: { [rule] }) }
        await client.waitFor(1)
        coordinator.cancelRequest()
        let second = Task { await coordinator.send("second", snapshots: { [rule] }) }
        await client.waitFor(2)
        await client.complete(0)
        await first.value
        #expect(coordinator.isSending)
        #expect(coordinator.grants.isEmpty)
        #expect(coordinator.errorMessage == nil)
        await client.complete(1)
        await second.value
        #expect(!coordinator.isSending)
        #expect(coordinator.grants.count == 1)
    }

    @Test("Content erasure preserves active waits without preserving reasons or replies")
    func eraseContentRetainsOnlyDeadlines() async throws {
        let (coordinator, history, rule, _) = try setup()
        await coordinator.send("wait for a private reason", snapshots: { [rule] })
        let deadline = coordinator.cooldownUntil
        #expect(coordinator.eraseCoachingContent())
        #expect(history.value.messages.isEmpty)
        #expect(history.value.memory.isEmpty)
        #expect(history.value.activityLog.isEmpty)
        #expect(history.value.accessEvents.allSatisfy { $0.reason.isEmpty && $0.reply.isEmpty && $0.appName.isEmpty })
        #expect(coordinator.cooldownUntil == deadline)
    }

    @Test("Summary failure keeps bounded context and still gets a decision")
    func failedSummaryFallsBack() async throws {
        let (original, history, rule, token) = try setup()
        _ = original
        history.value.messages = (0..<65).map { .init(role: .user, text: "Past \($0)") }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let client = SummaryFailureClient()
        let coordinator = ConversationCoordinator(historyStore: history, preferences: .testing(), client: client, keys: MockConversationKeyStore(),
            access: .init(store: .init(fileURL: directory.appendingPathComponent("access.json")), shields: MockShieldController()), timer: MockConversationTimer())
        coordinator.select(token)
        await coordinator.send("Hello", snapshots: { [rule] })
        #expect(coordinator.errorMessage == nil)
        #expect(history.value.messages.last?.text == "Still here")
        #expect(history.value.memory.isEmpty)
    }

    @Test("Cancellation immediately restores the composer")
    func cancellationRestoresComposer() async throws {
        let client = GatedConversationClient()
        let (coordinator, _, rule, _) = try setup(client: client)
        let task = Task { await coordinator.send("approve", snapshots: { [rule] }) }
        await client.waitUntilStarted()
        coordinator.cancelRequest()
        #expect(!coordinator.isSending)
        await client.complete()
        await task.value
        #expect(coordinator.grants.isEmpty)
    }

    @Test("Compaction retains the full archive and passes shared memory forward")
    func compaction() async throws {
        let (coordinator, history, rule, _) = try setup()
        history.value.messages = (0..<65).map { .init(role: .user, text: "Past request \($0)") }
        // Reload through the same archive interface, as on app relaunch.
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let restored = ConversationCoordinator(historyStore: history, preferences: .testing(), client: MockConversationClient(), keys: MockConversationKeyStore(),
            access: .init(store: .init(fileURL: directory.appendingPathComponent("access.json")), shields: MockShieldController()), timer: MockConversationTimer())
        restored.select(try #require(coordinator.target))
        await restored.send("Hello", snapshots: { [rule] })
        #expect(history.value.messages.count > 65)
        #expect(!history.value.memory.isEmpty)
        #expect(history.value.summarizedCount > 0)
    }
    @Test("Reflection grants once after its deadline with no second model request")
    func reflectionCompletesOnce() async throws {
        let client = ReflectionClient()
        let (coordinator, history, rule, _) = try setup(client: client)
        await coordinator.send("A casual visit", snapshots: { [rule] })
        let reflection = try #require(coordinator.pendingReflections.first)
        #expect(coordinator.grants.isEmpty)
        #expect(history.value.activityLog.last?.outcome == .reflection)
        await coordinator.completeReflection(reflection.id, snapshots: { [rule] }, now: reflection.createdAt)
        #expect(coordinator.grants.isEmpty)
        coordinator.chooseEmotion(.boredom, for: reflection.id)
        await coordinator.completeReflection(reflection.id, snapshots: { [rule] }, now: reflection.createdAt.addingTimeInterval(11))
        await coordinator.completeReflection(reflection.id, skip: true, snapshots: { [rule] })
        #expect(coordinator.grants.count == 1)
        #expect(coordinator.grants.first?.plan.minutes == 5)
        #expect(await client.calls == 1)
        #expect(history.value.activityLog.last?.outcome == .unlocked)
        #expect(history.value.activityLog.last?.emotion == .boredom)
        #expect(history.value.reflections.last?.state == .completed)
        #expect(!history.value.messages.contains { $0.text.contains("boredom") })
    }

    @Test("Skipping requires no emotion and still uses normal shield enforcement")
    func skipReflection() async throws {
        let (coordinator, history, rule, _) = try setup(client: ReflectionClient())
        await coordinator.send("Relax", snapshots: { [rule] })
        let id = try #require(coordinator.pendingReflections.first?.id)
        await coordinator.completeReflection(id, skip: true, snapshots: { [rule] })
        #expect(coordinator.grants.count == 1)
        #expect(history.value.reflections.first?.emotion == nil)
        #expect(history.value.activityLog.last?.reflectionSkipped == true)
    }

    @Test("Long pauses and legacy wait outputs are offers until consent")
    func longPauseConsent() async throws {
        let (coordinator, history, rule, _) = try setup(client: ReflectionClient(seconds: 180))
        await coordinator.send("A pause might help", snapshots: { [rule] })
        let pause = try #require(coordinator.pendingReflections.first)
        await coordinator.completeReflection(pause.id, snapshots: { [rule] }, now: pause.createdAt.addingTimeInterval(200))
        #expect(coordinator.grants.isEmpty)
        #expect(history.value.reflections.first?.deadline == nil)
        coordinator.startReflection(pause.id)
        #expect(history.value.reflections.first?.state == .counting)
        #expect(history.value.reflections.first?.deadline != nil)
        await coordinator.completeReflection(pause.id, skip: true, snapshots: { [rule] })
        #expect(coordinator.grants.count == 1)
        await coordinator.endUnlock()
        await coordinator.send("wait", snapshots: { [rule] })
    }

    @Test("Legacy model wait cannot silently impose a new cooldown")
    func waitOutputIsVoluntary() async throws {
        let (coordinator, history, rule, _) = try setup(client: WaitingConversationClient())
        await coordinator.send("More time", snapshots: { [rule] })
        #expect(coordinator.cooldownUntil == nil)
        #expect(history.value.accessEvents.last?.waitUntil == nil)
        #expect(coordinator.pendingReflections.first?.state == .offered)
        #expect(coordinator.pendingReflections.first?.seconds == 120)
    }

    @Test("Deadline persists across relaunch; background never starts an unlock")
    func restoredReflection() async throws {
        let (_, archive, rule, token) = try setup()
        let id = UUID()
        let now = Date()
        var pause = ConversationReflection(appID: rule.id, appName: rule.name, reason: "Relax", reply: "A moment",
            unlockMinutes: 3, seconds: 10, fingerprint: ConversationGrantStore.fingerprint([rule]), activityID: id, now: now.addingTimeInterval(-20))
        pause.emotion = .skip
        archive.value.reflections = [pause]
        archive.value.activityLog = [.init(appID: rule.id, appName: rule.name, message: "Relax", outcome: .reflection)]
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let restored = ConversationCoordinator(historyStore: archive, keys: MockConversationKeyStore(),
            access: .init(store: .init(fileURL: directory.appendingPathComponent("access.json")), shields: MockShieldController()), timer: MockConversationTimer())
        restored.select(token); restored.isForeground = false
        await restored.resumeReflections(snapshots: { [rule] })
        #expect(restored.grants.isEmpty)
        restored.isForeground = true
        await restored.resumeReflections(snapshots: { [rule] })
        #expect(restored.grants.isEmpty)
        await restored.completeReflection(pause.id, snapshots: { [rule] })
        #expect(restored.grants.count == 1)
        #expect(restored.grant?.plan.minutes == 3)
    }

    @Test("Failed reflection activation never logs or displays an unlock")
    func reflectionActivationFailure() async throws {
        let (coordinator, history, rule, _) = try setup(client: ReflectionClient(), shields: UnreleasedShield())
        await coordinator.send("Relax", snapshots: { [rule] })
        await coordinator.completeReflection(try #require(coordinator.pendingReflections.first?.id), skip: true, snapshots: { [rule] })
        #expect(coordinator.grants.isEmpty)
        #expect(history.value.activityLog.last?.outcome == .failed)
        #expect(history.value.accessEvents.allSatisfy { $0.grantID == nil })
        #expect(history.value.reflections.last?.state == .failed)
    }

    @Test("Clear Chat cancels soft interventions and keeps profiles")
    func clearCancelsReflection() async throws {
        let (coordinator, history, rule, _) = try setup(client: ReflectionClient())
        await coordinator.send("Relax", snapshots: { [rule] })
        let id = try #require(coordinator.pendingReflections.first?.id)
        coordinator.clearHistory()
        await coordinator.completeReflection(id, skip: true, snapshots: { [rule] })
        #expect(coordinator.grants.isEmpty)
        #expect(history.value.reflections.last?.state == .cancelled)
    }

    @Test("Profile edits and expired offers cannot activate stale reflection")
    func staleReflection() async throws {
        let (coordinator, history, rule, _) = try setup(client: ReflectionClient())
        await coordinator.send("Relax", snapshots: { [rule] })
        var edited = rule; edited.conversationGoal = "Changed intention"
        await coordinator.completeReflection(try #require(coordinator.pendingReflections.first?.id), skip: true, snapshots: { [edited] })
        #expect(coordinator.grants.isEmpty)
        #expect(history.value.reflections.first?.state == .cancelled)
        await coordinator.send("Relax again", snapshots: { [rule] })
        let latest = try #require(coordinator.pendingReflections.first)
        await coordinator.resumeReflections(snapshots: { [rule] }, now: latest.createdAt.addingTimeInterval(1900))
        #expect(coordinator.pendingReflections.isEmpty)
        #expect(coordinator.grants.isEmpty)
    }

    @Test("Concurrent reflection and active unlock preserve original deadlines")
    func independentReflections() async throws {
        let (coordinator, _, first, original) = try setup(client: ReflectionClient())
        let token = try JSONDecoder().decode(ApplicationToken.self,
            from: JSONSerialization.data(withJSONObject: ["data": Data([44]).base64EncodedString()]))
        var selection = FamilyActivitySelection(); selection.applicationTokens = [token]
        var second = first; second.id = UUID(); second.name = "Other"; second.selectionData = AppSelectionCodec.encode(selection)
        let snapshots = [first, second]
        await coordinator.send("Relax", snapshots: { snapshots })
        let firstPause = try #require(coordinator.pendingReflections.first)
        coordinator.select(token)
        await coordinator.send("Relax", snapshots: { snapshots })
        let secondPause = try #require(coordinator.pendingReflections.last)
        #expect(coordinator.pendingReflections.count == 2)
        await coordinator.completeReflection(firstPause.id, skip: true, snapshots: { snapshots })
        let expiry = try #require(coordinator.grants.first?.plan.expiresAt)
        await coordinator.completeReflection(secondPause.id, skip: true, snapshots: { snapshots })
        #expect(coordinator.grants.count == 2)
        #expect(coordinator.grants.first(where: { $0.token == original })?.plan.expiresAt == expiry)
    }

    @Test("Failure to publish a reflection grant rolls it back")
    func reflectionSaveFailure() async throws {
        let (coordinator, history, rule, _) = try setup(client: ReflectionClient())
        await coordinator.send("Relax", snapshots: { [rule] })
        history.failApprovalSave = true
        await coordinator.completeReflection(try #require(coordinator.pendingReflections.first?.id), skip: true, snapshots: { [rule] })
        #expect(coordinator.grants.isEmpty)
        #expect(history.value.activityLog.last?.outcome == .failed)
        #expect(history.value.activityLog.last?.grantID == nil)
        await coordinator.refresh(snapshots: [rule])
        #expect(coordinator.grants.isEmpty)
    }

    @Test("An existing enforced wait blocks a reflection regardless of skip")
    func reflectionCannotBypassWait() async throws {
        let (coordinator, history, rule, _) = try setup(client: ReflectionClient(), hardWait: true)
        await coordinator.send("Relax", snapshots: { [rule] })
        #expect(coordinator.pendingReflections.isEmpty)
        #expect(coordinator.grants.isEmpty)
        #expect(history.value.activityLog.last?.outcome == .blockedByWait)
    }

    @Test("Structured intentions reach the model without changing the free-text goal")
    func profileContext() async throws {
        let client = RecordingConversationClient()
        let (coordinator, archive, rule, _) = try setup(client: client)
        let profile = ConversationUsageProfile(purposes: [.relaxation], changes: [.habit], sessionStyle: .longerSessions)
        archive.value.usageProfiles[rule.id] = profile
        try coordinator.reloadUsageProfiles()
        await coordinator.send("A planned session", snapshots: { [rule] })
        let context = try #require(await client.contexts().last)
        #expect(context.usageProfile == profile)
        #expect(context.goals == [rule.conversationGoal])
        coordinator.clearHistory()
        #expect(archive.value.usageProfiles[rule.id] == profile)
    }

    @Test("Restored pending offers are cancelled when sharing is off")
    func restoredOffersRespectWithdrawnConsent() async throws {
        for message in ["reflect", "deal", "choice"] {
            let (coach, archive, rule, token) = try setup()
            await coach.send(message, snapshots: { [rule] })
            let offer = try #require(coach.pendingReflections.first)
            let preferences = CoachPreferences.testing()
            preferences.setConsent(false)
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            let restored = ConversationCoordinator(historyStore: archive, preferences: preferences, keys: MockConversationKeyStore(),
                access: .init(store: .init(fileURL: directory.appendingPathComponent("access.json")), shields: MockShieldController()), timer: MockConversationTimer())
            restored.select(token)
            #expect(restored.pendingReflections.isEmpty)
            await restored.completeReflection(offer.id, skip: true, acceptDeal: true, snapshots: { [rule] })
            #expect(restored.grants.isEmpty)
            #expect(archive.value.reflections.last?.state == .cancelled)
        }
    }

    @Test("Activation rechecks consent even if the preference changes independently")
    func activationRechecksConsent() async throws {
        let (coach, history, rule, _) = try setup()
        await coach.send("reflect", snapshots: { [rule] })
        let offer = try #require(coach.pendingReflections.first)
        coach.preferences.setConsent(false)
        await coach.completeReflection(offer.id, skip: true, snapshots: { [rule] })
        #expect(coach.grants.isEmpty)
        #expect(history.value.reflections.last?.state == .cancelled)
        #expect(coach.errorMessage == CopyKey.aiConsentRequired.string)
    }

    @Test("A consumed activation is interrupted on relaunch rather than replayed")
    func interruptedActivationDoesNotReplay() async throws {
        let (_, archive, rule, _) = try setup()
        var reflection = ConversationReflection(appID: rule.id, appName: rule.name, reason: "Relax", reply: "A moment",
            unlockMinutes: 3, seconds: 10, fingerprint: ConversationGrantStore.fingerprint([rule]), activityID: UUID())
        reflection.state = .activating
        archive.value.reflections = [reflection]
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let restored = ConversationCoordinator(historyStore: archive, keys: MockConversationKeyStore(),
            access: .init(store: .init(fileURL: directory.appendingPathComponent("access.json")), shields: MockShieldController()), timer: MockConversationTimer())
        await restored.resumeReflections(snapshots: { [rule] })
        #expect(restored.grants.isEmpty)
        #expect(archive.value.reflections.first?.state == .interrupted)
    }

    @Test("A cancellation save failure cannot re-arm a soft unlock in this session")
    func failedCancellationStaysClosed() async throws {
        let (coordinator, archive, rule, _) = try setup(client: ReflectionClient())
        await coordinator.send("Relax", snapshots: { [rule] })
        let id = try #require(coordinator.pendingReflections.first?.id)
        archive.failNextSave = true
        coordinator.cancelReflection(id)
        await coordinator.completeReflection(id, skip: true, snapshots: { [rule] })
        #expect(coordinator.grants.isEmpty)
        #expect(coordinator.pendingReflections.isEmpty)
        #expect(coordinator.errorMessage != nil)
    }

    @Test("A failed durable activation claim stops automatic retries")
    func failedReflectionClaimStops() async throws {
        let (coordinator, archive, rule, _) = try setup(client: ReflectionClient())
        await coordinator.send("Relax", snapshots: { [rule] })
        let reflection = try #require(coordinator.pendingReflections.first)
        archive.failNextSave = true
        await coordinator.completeReflection(reflection.id, skip: true, snapshots: { [rule] })
        await coordinator.resumeReflections(snapshots: { [rule] }, now: reflection.createdAt.addingTimeInterval(11))
        #expect(coordinator.grants.isEmpty)
        #expect(coordinator.pendingReflections.isEmpty)
        #expect(coordinator.errorMessage != nil)
    }

    @Test("Elapsed reflection waits for an answer and does not repeatedly schedule an elapsed deadline")
    func elapsedReflectionWaitsForChoice() async throws {
        let client = ReflectionClient()
        let (coordinator, archive, rule, _) = try setup(client: client)
        await coordinator.send("Relax", snapshots: { [rule] })
        let reflection = try #require(coordinator.pendingReflections.first)
        let later = reflection.createdAt.addingTimeInterval(11)
        await coordinator.resumeReflections(snapshots: { [rule] }, now: later)
        #expect(coordinator.grants.isEmpty)
        #expect(coordinator.pendingReflections.first?.id == reflection.id)
        #expect(coordinator.nextReflectionDeadline(at: later) == reflection.validUntil)
        let schedule = coordinator.reflectionScheduleID
        coordinator.chooseEmotion(.skip, for: reflection.id)
        #expect(coordinator.reflectionScheduleID != schedule)
        await coordinator.resumeReflections(snapshots: { [rule] }, now: later)
        #expect(coordinator.grants.isEmpty)
        await coordinator.completeReflection(reflection.id, snapshots: { [rule] }, now: later)
        #expect(coordinator.grants.count == 1)
        #expect(archive.value.reflections.first?.emotion == .skip)
        #expect(await client.calls == 1)
    }

    @Test("Ending a delay reveals a choice without unlocking or requiring an emotion")
    func endDelayNeedsExplicitUnlock() async throws {
        let (coach, history, rule, _) = try setup(client: ReflectionClient())
        await coach.send("Relax", snapshots: { [rule] })
        let pause = try #require(coach.pendingReflections.first)
        coach.endReflectionDelay(pause.id)
        await coach.resumeReflections(snapshots: { [rule] })
        #expect(coach.grants.isEmpty)
        #expect(history.value.reflections.last?.skipped == true)
        await coach.completeReflection(pause.id, snapshots: { [rule] })
        #expect(coach.grants.count == 1)
        #expect(history.value.activityLog.last?.reflectionSkipped == true)
    }

    @Test("Keeping an app locked after a pause records the choice without a grant")
    func keepLockedAfterPause() async throws {
        let (coach, history, rule, _) = try setup(client: ReflectionClient())
        await coach.send("Relax", snapshots: { [rule] })
        let pause = try #require(coach.pendingReflections.first)
        coach.cancelReflection(pause.id)
        await coach.resumeReflections(snapshots: { [rule] }, now: pause.createdAt.addingTimeInterval(11))
        #expect(coach.grants.isEmpty)
        #expect(coach.pendingReflections.isEmpty)
        #expect(history.value.activityLog.last?.outcome == .cancelled)
    }

    @Test("A stale keep-locked tap cannot rewrite an already-published unlock outcome")
    func completedReflectionIgnoresLateCancellation() async throws {
        let (coach, history, rule, _) = try setup(client: ReflectionClient())
        await coach.send("Relax", snapshots: { [rule] })
        let id = try #require(coach.pendingReflections.first?.id)
        await coach.completeReflection(id, skip: true, snapshots: { [rule] })
        coach.cancelReflection(id)
        #expect(coach.grants.count == 1)
        #expect(history.value.reflections.last?.state == .completed)
        #expect(history.value.activityLog.last?.outcome == .unlocked)
    }

    @Test("Context prefers deals after two same-app pause attempts without removing safeguards")
    func contextMovesFromPausesTowardDeals() async throws {
        let client = RecordingConversationClient()
        let (coach, _, rule, _) = try setup(client: client, checkIn: true, pauseAttempts: 2)
        await coach.send("More time for the same scroll", snapshots: { [rule] })
        let context = try #require(await client.contexts().last)
        #expect(context.recentPauseAttempts == 2)
        #expect(context.preferDeal)
        #expect(!context.pauseBeforeDealRequired)
        #expect(context.emotionCheckInSuggested)
    }

    @Test("Check-in precedes the intervention and starts ten seconds only after answering")
    func checkInIsASeparateStep() async throws {
        let (coach, history, rule, _) = try setup(checkIn: true)
        await coach.send("reflect", snapshots: { [rule] })
        let offer = try #require(coach.pendingReflections.first)
        #expect(offer.awaitingCheckIn)
        #expect(offer.deadline == nil)
        #expect(!history.value.messages.contains { $0.text == offer.reply })
        coach.chooseEmotion(.skip, for: offer.id)
        let revealed = try #require(coach.pendingReflections.first)
        #expect(!revealed.awaitingCheckIn)
        #expect(revealed.deadline != nil)
        #expect(!history.value.messages.contains { $0.text == ConversationReflection.Emotion.skip.copy.string })
        #expect(history.value.messages.filter { $0.text == offer.reply }.count == 1)
        coach.chooseEmotion(.boredom, for: offer.id)
        #expect(history.value.messages.filter { $0.text == offer.reply }.count == 1)
        #expect(coach.grants.isEmpty)
    }

    @Test("Custom emotions are bounded, private and do not repeat the check-in within two minutes")
    func customEmotionAndQuestionCooldown() async throws {
        let (coach, memory, rule, _) = try setup(checkIn: true)
        await coach.send("reflect", snapshots: { [rule] })
        let first = try #require(coach.pendingReflections.first)
        coach.chooseCustomEmotion("  Restless  ", for: first.id)
        #expect(coach.history.reflections.last?.customEmotion == "Restless")
        #expect(memory.value.activityLog.last?.customEmotion == "Restless")
        #expect(!coach.history.messages.contains { $0.text.contains("Restless") })
        coach.clearHistory()
        await coach.send("deal", snapshots: { [rule] })
        #expect(coach.pendingReflections.first?.checkInRequested == false)
        #expect(coach.history.canAskEmotion(at: Date().addingTimeInterval(121)))
    }

    @Test("Feedback belongs to a completed outcome and preserves enforcement")
    func experienceFeedbackPersists() async throws {
        let (coach, memory, rule, _) = try setup()
        await coach.send("approve", snapshots: { [rule] })
        let entry = try #require(coach.feedbackEntry)
        let deadline = try #require(coach.grant?.plan.expiresAt)
        coach.rateExperience(.helpful, activityID: entry.id)
        #expect(memory.value.activityLog.last?.experienceRating == .helpful)
        #expect(coach.grant?.plan.expiresAt == deadline)
        coach.clearHistory()
        #expect(coach.history.activityLog.last?.experienceRating == .helpful)
        #expect(ConversationActivityExport.text(coach.history.activityLog).contains("Experience: helpful"))
    }

    @Test("Three-way choice Open grants without accepting a deal")
    func choiceOpenUsesNormalActivation() async throws {
        let (coach, memory, rule, _) = try setup()
        await coach.send("choice", snapshots: { [rule] })
        let offer = try #require(coach.pendingReflections.first)
        coach.chooseIntervention(offer.id, option: .open)
        await coach.completeReflection(offer.id, snapshots: { [rule] })
        #expect(coach.grants.count == 1)
        #expect(coach.history.recentPauseAttempts(for: rule.id, now: .now) == 0)
        #expect(memory.value.activityLog.last?.blockMinutes == nil)
        await coach.endUnlock()
        #expect(coach.cooldownUntil == nil)
    }

    @Test("Invalid custom emotions do not answer the check-in and storage failure rolls back")
    func customEmotionValidationAndRollback() async throws {
        let (coach, memory, rule, _) = try setup(checkIn: true)
        await coach.send("reflect", snapshots: { [rule] })
        let id = try #require(coach.pendingReflections.first).id
        for text in ["   ", String(repeating: "x", count: 161)] {
            coach.chooseCustomEmotion(text, for: id)
            #expect(coach.pendingReflections.first?.awaitingCheckIn == true)
        }
        memory.failNextSave = true
        coach.chooseCustomEmotion("Excited", for: id)
        #expect(coach.pendingReflections.first?.awaitingCheckIn == true)
        #expect(memory.value.activityLog.last?.customEmotion == nil)
        coach.chooseCustomEmotion("Excited", for: id)
        #expect(coach.pendingReflections.first?.context.customEmotion == "Excited")
        let decoded = try JSONDecoder().decode(ConversationHistory.self, from: JSONEncoder().encode(coach.history))
        #expect(decoded.reflections.last?.customEmotion == "Excited")
        #expect(!decoded.canAskEmotion(at: .now))
    }

    @Test("Feedback is available for denial but not an unfinished offer and fails atomically")
    func feedbackMatchesTheActualOutcome() async throws {
        let (coach, memory, rule, _) = try setup()
        await coach.send("deny", snapshots: { [rule] })
        let entry = try #require(coach.feedbackEntry)
        memory.failNextSave = true
        coach.rateExperience(.annoying, activityID: entry.id)
        #expect(memory.value.activityLog.last?.experienceRating == nil)
        coach.rateExperience(.neutral, activityID: entry.id)
        #expect(memory.value.activityLog.last?.experienceRating == .neutral)
        #expect(coach.grants.isEmpty)
        await coach.send("deal", snapshots: { [rule] })
        #expect(coach.feedbackEntry == nil)
        let unfinished = try #require(memory.value.activityLog.last).id
        coach.rateExperience(.helpful, activityID: unfinished)
        #expect(memory.value.activityLog.last?.experienceRating == nil)
    }

    @Test("Saved-app setup only yields to a valid foreground shield request")
    func setupResumesChatForShieldRequest() async throws {
        let defaults = try #require(UserDefaults(suiteName: "SetupRouting-\(UUID().uuidString)"))
        let requests = ConversationRequestStore(defaults: defaults)
        let (coach, _, rule, token) = try setup(requests: requests)
        let lifecycle = AppLifecycleController()
        lifecycle.needsSetup = true
        await coach.refresh(snapshots: [rule], consumeRequests: false)
        lifecycle.resumeSetupForShieldRequest(coach, snapshots: [rule])
        #expect(lifecycle.needsSetup)
        _ = requests.begin(token: token, appID: rule.id)
        await coach.refresh(snapshots: [rule], consumeRequests: false)
        lifecycle.resumeSetupForShieldRequest(coach, snapshots: [rule])
        #expect(lifecycle.needsSetup)
        await coach.refresh(snapshots: [rule])
        lifecycle.resumeSetupForShieldRequest(coach, snapshots: [rule])
        #expect(!lifecycle.needsSetup)
        #expect(coach.selectedAppID == rule.id)
        #expect(coach.grants.isEmpty)
        lifecycle.needsSetup = true
        coach.openRequestURL(try #require(requests.begin(token: token, appID: rule.id).url), snapshots: [rule])
        lifecycle.resumeSetupForShieldRequest(coach, snapshots: [rule])
        #expect(!lifecycle.needsSetup)
    }

    @Test("Emotion check-ins are sampled independently for delays and deals")
    func optionalCheckInDoesNotAcceptAnOffer() async throws {
        for message in ["reflect", "deal", "choice"] {
            for show in [false, true] {
                let (coach, history, rule, _) = try setup(checkIn: show)
                await coach.send(message, snapshots: { [rule] })
                let offer = try #require(coach.pendingReflections.first)
                #expect(offer.checkInRequested == show)
                coach.chooseEmotion(.boredom, for: offer.id)
                await coach.resumeReflections(snapshots: { [rule] }, now: offer.createdAt.addingTimeInterval(11))
                #expect(coach.grants.isEmpty)
                #expect(history.value.activityLog.last?.emotion == .boredom)
            }
        }
    }

    @Test("A choice cannot grant until selected, then binds only its selected terms")
    func interventionChoiceBindsSelectedTerms() async throws {
        for deal in [false, true] {
            let (coach, history, rule, _) = try setup()
            await coach.send("choice", snapshots: { [rule] })
            let offer = try #require(coach.pendingReflections.first)
            #expect(offer.isChoice)
            await coach.completeReflection(offer.id, skip: true, acceptDeal: true, snapshots: { [rule] })
            #expect(coach.grants.isEmpty)
            coach.chooseIntervention(offer.id, deal: deal)
            if !deal {
                #expect(coach.pendingReflections.first?.deadline != nil)
                #expect(coach.pendingReflections.first?.blockMinutes == nil)
                coach.endReflectionDelay(offer.id)
            }
            await coach.completeReflection(offer.id, acceptDeal: deal, snapshots: { [rule] })
            #expect(coach.grants.count == 1)
            #expect(history.value.activityLog.last?.blockMinutes == (deal ? 10 : nil))
            await coach.endUnlock()
            #expect((coach.cooldownUntil != nil) == deal)
        }
    }

    @Test("A deal stays blocked until explicit acceptance and cannot be skipped")
    func dealNeedsAcceptance() async throws {
        let (coach, history, rule, _) = try setup(priorPause: true)
        await coach.send("offer a deal", snapshots: { [rule] })
        let offer = try #require(coach.pendingReflections.first)
        #expect(offer.isDeal)
        #expect(coach.grants.isEmpty)
        await coach.completeReflection(offer.id, skip: true, snapshots: { [rule] })
        #expect(coach.grants.isEmpty)
        await coach.resumeReflections(snapshots: { [rule] }, now: offer.createdAt.addingTimeInterval(20))
        #expect(coach.grants.isEmpty)
        await coach.completeReflection(offer.id, acceptDeal: true, snapshots: { [rule] })
        #expect(coach.grants.count == 1)
        #expect(history.value.activityLog.last?.outcome == .unlocked)
        #expect(history.value.activityLog.last?.blockMinutes == 10)
        #expect(coach.selectedActivitySummary?.sameAppShortGrantsToday == 1)
        await coach.endUnlock()
        #expect(coach.displayedGrants.isEmpty)
        #expect(coach.cooldownUntil != nil)
        coach.clearHistory()
        #expect(coach.cooldownUntil != nil)
        await coach.refresh(snapshots: [rule])
        await coach.send("approve please", snapshots: { [rule] })
        #expect(coach.grants.isEmpty)
        #expect(history.value.activityLog.last?.outcome == .blockedByWait)
    }

    @Test("Declining a deal adds no cooldown and is recorded separately")
    func declinedDeal() async throws {
        let (coach, history, rule, _) = try setup(priorPause: true)
        await coach.send("deal", snapshots: { [rule] })
        coach.declineDeal(try #require(coach.pendingReflections.first).id)
        #expect(coach.pendingReflections.isEmpty)
        #expect(history.value.activityLog.last?.outcome == .dealDeclined)
        #expect(coach.cooldownUntil == nil)
        await coach.send("approve", snapshots: { [rule] })
        #expect(coach.grants.count == 1)
    }

    @Test("A failed accepted deal rolls back its restriction")
    func dealFailureRollsBack() async throws {
        let (coach, history, rule, _) = try setup(priorPause: true)
        await coach.send("deal", snapshots: { [rule] })
        let id = try #require(coach.pendingReflections.first).id
        history.failApprovalSave = true
        await coach.completeReflection(id, acceptDeal: true, snapshots: { [rule] })
        #expect(coach.grants.isEmpty)
        await coach.refresh(snapshots: [rule])
        #expect(coach.cooldownUntil == nil)
        #expect(history.value.activityLog.last?.outcome != .unlocked)
    }

    @Test("A deal can be offered without a completed pause, while exception guards remain")
    func pauseFirstAndExceptionGuards() async throws {
        let (fresh, freshHistory, freshRule, _) = try setup()
        await fresh.send("deal", snapshots: { [freshRule] })
        #expect(fresh.pendingReflections.first?.isDeal == true)
        #expect(fresh.grants.isEmpty)
        #expect(freshHistory.value.activityLog.last?.outcome == .dealOffered)
        let (coach, _, rule, _) = try setup(priorPause: true)
        await coach.send("deal", snapshots: { [rule] })
        await coach.completeReflection(try #require(coach.pendingReflections.first).id, acceptDeal: true, snapshots: { [rule] })
        await coach.endUnlock()
        await coach.send("override", snapshots: { [rule] })
        #expect(coach.pendingReflections.isEmpty)
        #expect(coach.grants.isEmpty)
        await coach.send("deny", snapshots: { [rule] })
        await coach.send("deny", snapshots: { [rule] })
        await coach.send("override", snapshots: { [rule] })
        let replacement = try #require(coach.pendingReflections.first)
        #expect(replacement.overridingDealID != nil)
        #expect(coach.grants.isEmpty)
        coach.declineDeal(replacement.id)
        #expect(coach.cooldownUntil != nil)
        await coach.send("override", snapshots: { [rule] })
        await coach.completeReflection(try #require(coach.pendingReflections.first).id, acceptDeal: true, snapshots: { [rule] })
        #expect(coach.grants.count == 1)
        await coach.endUnlock()
        coach.clearHistory()
        await coach.send("deny", snapshots: { [rule] }); await coach.send("deny", snapshots: { [rule] })
        await coach.send("override", snapshots: { [rule] })
        #expect(coach.grants.isEmpty)
        let second = try #require(coach.pendingReflections.first)
        #expect(second.blockMinutes ?? 0 >= 45)
        await coach.completeReflection(second.id, acceptDeal: true, snapshots: { [rule] })
        #expect(coach.grants.count == 1)
        await coach.endUnlock()

    }

    @Test("Broken deals increase future pauses and failed replacement activation preserves old terms")
    func brokenDealsAndReplacementFailure() async throws {
        let client = NegotiationRecordingClient()
        let (coach, memory, rule, _) = try setup(client: client)
        await coach.send("deal", snapshots: { [rule] })
        await coach.completeReflection(try #require(coach.pendingReflections.first).id, acceptDeal: true, snapshots: { [rule] })
        await coach.endUnlock()
        await coach.send("deny", snapshots: { [rule] })
        await coach.send("deny", snapshots: { [rule] })
        let originalDeadline = try #require(coach.cooldownUntil)
        await coach.send("override", snapshots: { [rule] })
        memory.failReplacementPublication = true
        await coach.completeReflection(try #require(coach.pendingReflections.first).id, acceptDeal: true, snapshots: { [rule] })
        #expect(coach.grants.isEmpty)
        await coach.refresh(snapshots: [rule])
        #expect(coach.cooldownUntil == originalDeadline)
        #expect(memory.value.activityLog.last?.outcome != .unlocked)
        memory.failReplacementPublication = false
        await coach.send("override", snapshots: { [rule] })
        await coach.completeReflection(try #require(coach.pendingReflections.first).id, acceptDeal: true, snapshots: { [rule] })
        #expect(coach.grants.count == 1)
        await coach.endUnlock()
        coach.clearHistory()
        await coach.send("ask", snapshots: { [rule] })
        let context = try #require(await client.contexts().last)
        #expect(context.recommendedPauseSeconds == 70)
        #expect(context.deal?.lastResolvedDealWasBroken == true)
    }

    @Test("Content erasure retains only the evidence needed for active unlock presentation")
    func erasureKeepsActiveGrantProof() async throws {
        let (coach, _, rule, _) = try setup()
        await coach.send("approve a private purpose", snapshots: { [rule] })
        let grant = try #require(coach.grant)
        #expect(coach.eraseCoachingContent())
        let event = try #require(coach.history.accessEvents.first { $0.grantID == grant.plan.grantID })
        #expect(event.reason.isEmpty && event.reply.isEmpty && event.appName.isEmpty)
        #expect(coach.history.messages.isEmpty && coach.history.activityLog.isEmpty)
        #expect(coach.presentationID.contains(grant.plan.grantID.uuidString))
    }

    @Test("A removal alternative stays bound to its app when feedback names another")
    func explicitRemovalAlternativeTarget() async throws {
        let client = RecordingConversationClient()
        let (coach, _, first, token) = try setup(client: client)
        let other = try JSONDecoder().decode(ApplicationToken.self,
            from: JSONSerialization.data(withJSONObject: ["data": Data([2]).base64EncodedString()]))
        var selection = FamilyActivitySelection(); selection.applicationTokens = [other]
        var second = first
        second.id = UUID(); second.name = "Maps"; second.selectionData = AppSelectionCodec.encode(selection)
        await coach.sendToApp("Maps is less frustrating. Can I get five minutes instead?", token: token, snapshots: { [first, second] })
        #expect(await client.contexts().last?.currentAppID == first.id)
    }

    @Test("Removal friction and progressive pause reach the next coaching request")
    func removalFeedbackContext() async throws {
        let client = RecordingConversationClient()
        let (coach, memory, rule, _) = try setup(priorPause: true, client: client)
        let id = try coach.beginRemoval(appID: rule.id, appName: rule.name)
        try coach.recordRemovalReason(id, reason: "Too much friction")
        try coach.finishRemoval(id, outcome: .temporaryUnlockRequested, minutes: 5)
        await coach.send("A short unlock instead?", snapshots: { [rule] })
        let sent = try #require(await client.contexts().last)
        #expect(sent.recommendedPauseSeconds == 20)
        #expect(sent.recentRemovalAttempts.first?.reason == "Too much friction")
        #expect(sent.recentRemovalAttempts.first?.outcome == .temporaryUnlockRequested)
        #expect(memory.value.activityLog.first?.outcome == .removalRequested)
        try coach.finishRemoval(id, outcome: .kept)
        #expect(coach.history.removalAttempts.first?.outcome == .temporaryUnlockRequested)
    }

    @Test("Removal feedback keeps intent and disposition after chat/log clearing")
    func removalFeedbackPersists() throws {
        let (coach, memory, rule, _) = try setup()
        let id = try coach.beginRemoval(appID: rule.id, appName: rule.name)
        try coach.recordRemovalReason(id, reason: " Too much friction ")
        try coach.finishRemoval(id, outcome: .temporaryUnlockRequested, minutes: 5)
        #expect(memory.value.removalAttempts.first?.reason == "Too much friction")
        #expect(memory.value.activityLog.last?.feedbackSignal == .highFrustration)
        #expect(ConversationActivityExport.text(memory.value.activityLog).contains("Feedback signal: high_frustration"))
        #expect(try ConversationActivityExport.jsonLines(memory.value.activityLog).contains("\"feedback_signal\":\"high_frustration\""))
        #expect(memory.value.removalAttempts.first?.requestedMinutes == 5)
        coach.clearHistory()
        #expect(coach.clearActivityLog())
        #expect(coach.history.removalAttempts.first?.outcome == .temporaryUnlockRequested)
        let restored = try JSONDecoder().decode(ConversationHistory.self, from: JSONEncoder().encode(coach.history))
        #expect(restored.removalAttempts.count == 1)
    }

    @Test("Removal feedback validation and persistence failures do not publish completion")
    func removalFeedbackValidation() throws {
        let (coach, memory, rule, _) = try setup()
        let id = try coach.beginRemoval(appID: rule.id, appName: rule.name)
        #expect(throws: (any Error).self) { try coach.recordRemovalReason(id, reason: "   ") }
        try coach.recordRemovalReason(id, reason: "I prefer to manage it myself")
        memory.failNextSave = true
        #expect(throws: (any Error).self) { try coach.finishRemoval(id, outcome: .removed) }
        #expect(coach.history.removalAttempts.first?.outcome == .considering)
    }

}

@MainActor
private final class HistoryMemory: ConversationHistoryStoring {
    var value = ConversationHistory()
    var failApprovalSave = false
    var failReplacementPublication = false
    var failNextSave = false
    enum Failure: Error { case save }
    func load() -> ConversationHistory { value }
    func save(_ history: ConversationHistory) throws {
        if failNextSave { failNextSave = false; throw Failure.save }
        if failApprovalSave && history.lastGrantID != nil { throw Failure.save }
        if failReplacementPublication && history.activityLog.filter({ $0.outcome == .unlocked }).count >= 2 { throw Failure.save }
        value = history
    }
}
@MainActor
private final class RuleBox {
    var rule: RuleSnapshotDTO
    init(rule: RuleSnapshotDTO) { self.rule = rule }
}
private actor GatedConversationClient: ConversationClient {
    private var continuation: CheckedContinuation<ConversationDecision, any Error>?
    func respond(to context: ConversationContext, apiKey: String) async throws -> ConversationDecision {
        try await withCheckedThrowingContinuation { continuation = $0 }
    }
    func waitUntilStarted() async {
        while continuation == nil { await Task.yield() }
    }
    func complete() {
        continuation?.resume(returning: .init(reply: "Yes", decision: .approve, unlockMinutes: 1))
        continuation = nil
    }
    func fail() {
        continuation?.resume(throwing: ConversationClientError.transport(code: -1009))
        continuation = nil
    }
    func summarize(memory: String, messages: [ConversationMessage], apiKey: String) async throws -> String { memory }
}

private actor RecordingConversationClient: ConversationClient {
    private var received: [ConversationContext] = []
    func respond(to context: ConversationContext, apiKey: String) async throws -> ConversationDecision {
        received.append(context)
        return .init(reply: "Tell me more.", decision: .ask, unlockMinutes: nil)
    }
    func summarize(memory: String, messages: [ConversationMessage], apiKey: String) async throws -> String { memory }
    func contexts() -> [ConversationContext] { received }
}

nonisolated private struct FailingConversationClient: ConversationClient {
    let failure: ConversationClientError
    func respond(to context: ConversationContext, apiKey: String) async throws -> ConversationDecision { throw failure }
    func summarize(memory: String, messages: [ConversationMessage], apiKey: String) async throws -> String { throw failure }
}

private actor WaitingConversationClient: ConversationClient {
    private(set) var calls = 0
    func respond(to context: ConversationContext, apiKey: String) async throws -> ConversationDecision {
        calls += 1
        return .init(reply: "Let's pause for two minutes.", decision: .wait, unlockMinutes: nil, waitMinutes: 2)
    }
    func summarize(memory: String, messages: [ConversationMessage], apiKey: String) async throws -> String { memory }
}

nonisolated private final class UnreleasedShield: ShieldApplying, @unchecked Sendable {
    func applyShield(ruleID: UUID, selectionData: Data?, mode: SelectionMode) {}
    func clearShield(ruleID: UUID) {}
    func clearShields(except activeRuleIDs: Set<UUID>) {}
    func setAppRemovalDenied(_ denied: Bool) {}
    func blockingRuleIDs(for token: ApplicationToken, among ruleIDs: Set<UUID>) -> Set<UUID> { ruleIDs }
}

private actor FailsSecondConversationClient: ConversationClient {
    private var calls = 0
    func respond(to context: ConversationContext, apiKey: String) async throws -> ConversationDecision {
        calls += 1
        if calls > 1 { throw ConversationClientError.transport(code: -1009) }
        return .init(reply: "One minute for that task.", decision: .approve, unlockMinutes: 1)
    }
    func summarize(memory: String, messages: [ConversationMessage], apiKey: String) async throws -> String { memory }
}

private actor ReflectionClient: ConversationClient {
    private(set) var calls = 0
    let seconds: Int
    init(seconds: Int = 10) { self.seconds = seconds }
    func respond(to context: ConversationContext, apiKey: String) async throws -> ConversationDecision {
        calls += 1
        return .init(reply: "Let’s take a moment.", decision: .pause, unlockMinutes: 5, pauseSeconds: seconds)
    }
    func summarize(memory: String, messages: [ConversationMessage], apiKey: String) async throws -> String { memory }
}

nonisolated private struct SummaryFailureClient: ConversationClient {
    func respond(to context: ConversationContext, apiKey: String) async throws -> ConversationDecision {
        #expect(context.recentMessages.count <= 60)
        return .init(reply: "Still here", decision: .ask, unlockMinutes: nil)
    }
    func summarize(memory: String, messages: [ConversationMessage], apiKey: String) async throws -> String {
        throw URLError(.timedOut)
    }
}

private actor SequencedConversationClient: ConversationClient {
    private var continuations: [CheckedContinuation<ConversationDecision, Error>] = []
    func respond(to context: ConversationContext, apiKey: String) async throws -> ConversationDecision {
        try await withCheckedThrowingContinuation { continuations.append($0) }
    }
    func waitFor(_ count: Int) async { while continuations.count < count { await Task.yield() } }
    func complete(_ index: Int) {
        continuations[index].resume(returning: .init(reply: "Approved", decision: .approve, unlockMinutes: 1))
    }
    func summarize(memory: String, messages: [ConversationMessage], apiKey: String) async throws -> String { memory }
}

private actor NegotiationRecordingClient: ConversationClient {
    private var received: [ConversationContext] = []
    func respond(to context: ConversationContext, apiKey: String) async throws -> ConversationDecision {
        received.append(context)
        return try await MockConversationClient().respond(to: context, apiKey: apiKey)
    }
    func summarize(memory: String, messages: [ConversationMessage], apiKey: String) async throws -> String { memory }
    func contexts() -> [ConversationContext] { received }
}
