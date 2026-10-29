import FamilyControls
import Foundation
import ManagedSettings
import Testing
@testable import OpenAppLock

@MainActor
@Suite("Shared conversation lifecycle", .serialized)
struct ConversationCoordinatorTests {
    private func setup(priorPause: Bool = false, client: any ConversationClient = MockConversationClient(), shields: any ShieldApplying = MockShieldController(), selectTarget: Bool = true, hardWait: Bool = false, requests: ConversationRequestStore = .init()) throws -> (ConversationCoordinator, HistoryMemory, RuleSnapshotDTO, ApplicationToken) {
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
        if priorPause {
            var pause = ConversationReflection(appID: rule.id, appName: rule.name, reason: "Boredom", reply: "Pause", unlockMinutes: 3,
                seconds: 10, fingerprint: ConversationGrantStore.fingerprint([rule]), activityID: UUID(), now: .now.addingTimeInterval(-60))
            pause.state = .completed; pause.finishedAt = .now.addingTimeInterval(-45)
            history.value.reflections = [pause]
        }
        let coordinator = ConversationCoordinator(historyStore: history, client: client,
            keys: MockConversationKeyStore(),
            access: .init(store: .init(fileURL: directory.appendingPathComponent("access.json")), shields: shields),
            timer: MockConversationTimer(), requestStore: requests)
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
        let restored = ConversationCoordinator(historyStore: history, client: client, keys: MockConversationKeyStore(),
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
        let restored = ConversationCoordinator(historyStore: history, client: client, keys: MockConversationKeyStore(),
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

    @Test("Compaction retains the full archive and passes shared memory forward")
    func compaction() async throws {
        let (coordinator, history, rule, _) = try setup()
        history.value.messages = (0..<65).map { .init(role: .user, text: "Past request \($0)") }
        // Reload through the same archive interface, as on app relaunch.
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let restored = ConversationCoordinator(historyStore: history, client: MockConversationClient(), keys: MockConversationKeyStore(),
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
        #expect(coordinator.grants.count == 1)
        #expect(archive.value.reflections.first?.emotion == .skip)
        #expect(await client.calls == 1)
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

    @Test("A premature deal asks for a pause, and the model cannot skip exception guards")
    func pauseFirstAndExceptionGuards() async throws {
        let (fresh, freshHistory, freshRule, _) = try setup()
        await fresh.send("deal", snapshots: { [freshRule] })
        #expect(fresh.pendingReflections.isEmpty)
        #expect(freshHistory.value.messages.last?.text == CopyKey.pauseProposal.string)
        let (coach, _, rule, _) = try setup(priorPause: true)
        await coach.send("deal", snapshots: { [rule] })
        await coach.completeReflection(try #require(coach.pendingReflections.first).id, acceptDeal: true, snapshots: { [rule] })
        await coach.endUnlock()
        await coach.send("override", snapshots: { [rule] })
        #expect(coach.grants.isEmpty)
        await coach.send("deny", snapshots: { [rule] })
        await coach.send("deny", snapshots: { [rule] })
        await coach.send("override", snapshots: { [rule] })
        #expect(coach.grants.count == 1)
        #expect(coach.cooldownUntil == nil)
        await coach.endUnlock()
        coach.clearHistory()
        await coach.send("deal", snapshots: { [rule] })
        await coach.completeReflection(try #require(coach.pendingReflections.first).id, acceptDeal: true, snapshots: { [rule] })
        await coach.endUnlock()
        await coach.send("deny", snapshots: { [rule] }); await coach.send("deny", snapshots: { [rule] })
        await coach.send("override", snapshots: { [rule] })
        #expect(coach.grants.isEmpty)
        #expect(coach.cooldownUntil != nil)
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
    var failNextSave = false
    enum Failure: Error { case save }
    func load() -> ConversationHistory { value }
    func save(_ history: ConversationHistory) throws {
        if failNextSave { failNextSave = false; throw Failure.save }
        if failApprovalSave && history.lastGrantID != nil { throw Failure.save }
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
