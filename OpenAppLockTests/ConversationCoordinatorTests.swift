import FamilyControls
import Foundation
import ManagedSettings
import Testing
@testable import OpenAppLock

@MainActor
@Suite("Shared conversation lifecycle", .serialized)
struct ConversationCoordinatorTests {
    private func setup(client: any ConversationClient = MockConversationClient(), shields: any ShieldApplying = MockShieldController()) throws -> (ConversationCoordinator, HistoryMemory, RuleSnapshotDTO, ApplicationToken) {
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
        let coordinator = ConversationCoordinator(historyStore: history, client: client,
            keys: MockConversationKeyStore(),
            access: .init(store: .init(fileURL: directory.appendingPathComponent("access.json")), shields: shields),
            timer: MockConversationTimer())
        coordinator.select(token)
        return (coordinator, history, rule, token)
    }

    @Test("Wait persists for its app while chat and another app remain available")
    func waiting() async throws {
        let client = WaitingConversationClient()
        let (coordinator, history, rule, original) = try setup(client: client)
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
        let (coordinator, history, rule, _) = try setup()
        await coordinator.send("wait", snapshots: { [rule] })
        let deadline = try #require(coordinator.cooldownUntil)
        await coordinator.send("Hello", snapshots: { [rule] })
        #expect(history.value.messages.last?.role == .assistant)
        await coordinator.send("approve", snapshots: { [rule] })
        #expect(coordinator.grants.isEmpty)
        #expect(coordinator.cooldownUntil == deadline)
        #expect(coordinator.errorMessage != nil)
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
}

@MainActor
private final class HistoryMemory: ConversationHistoryStoring {
    var value = ConversationHistory()
    var failApprovalSave = false
    enum Failure: Error { case save }
    func load() -> ConversationHistory { value }
    func save(_ history: ConversationHistory) throws {
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
    private var continuation: CheckedContinuation<ConversationDecision, Never>?
    func respond(to context: ConversationContext, apiKey: String) async throws -> ConversationDecision {
        await withCheckedContinuation { continuation = $0 }
    }
    func waitUntilStarted() async {
        while continuation == nil { await Task.yield() }
    }
    func complete() {
        continuation?.resume(returning: .init(reply: "Yes", decision: .approve, unlockMinutes: 1))
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
