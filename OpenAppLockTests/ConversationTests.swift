import FamilyControls
import Foundation
import Testing
import SwiftData
@testable import OpenAppLock

@MainActor
@Suite("Conversation rules and decisions")
struct ConversationTests {
    @Test("Conversation rules require a goal and individual apps")
    func validation() throws {
        var draft = RuleDraft(kind: .conversation)
        #expect(!draft.hasValidConfiguration)
        draft.conversationConfig.goal = "Use social apps only to contact friends."
        #expect(!draft.hasValidConfiguration)
        let context = try makeInMemoryContext()
        let list = AppList(name: "Empty")
        context.insert(list)
        draft.appLists = [list]
        #expect(!draft.hasValidConfiguration)
    }

    @Test("Conversation blocking ignores weekdays and pauses")
    func alwaysBlocks() {
        var rule = RuleSnapshotDTO(id: UUID(), name: "Coach", kindRaw: "conversation", isEnabled: true,
            hardMode: false, selectionModeRaw: "block", dayNumbers: [], startMinutes: 0,
            endMinutes: 0, dailyLimitMinutes: 45, maxOpens: 5, pausedUntil: .distantFuture)
        #expect(rule.status().isActive)
        #expect(!RulePolicy.canPause(rule))
        rule.isEnabled = false
        #expect(rule.status() == .disabled)
    }

    @Test("Approval requires an integer duration within bounds")
    func decisions() throws {
        let valid = Data(#"{"reply":"Take five minutes.","decision":"approve","unlock_minutes":5}"#.utf8)
        #expect(try ConversationDecision.parse(valid).unlockMinutes == 5)
        for text in [
            #"{"reply":"Yes","decision":"approve","unlock_minutes":61}"#,
            #"{"reply":"Yes","decision":"approve","unlock_minutes":0}"#,
            #"{"reply":"No","decision":"deny","unlock_minutes":5}"#,
            #"{"reply":"Yes","decision":"approve","unlock_minutes":null}"#,
            #"{"reply":"","decision":"ask","unlock_minutes":null}"#
        ] {
            #expect(throws: (any Error).self) { try ConversationDecision.parse(Data(text.utf8)) }
        }
    }

    @Test("Old snapshots still decode without a conversation goal")
    func oldSnapshot() throws {
        let rule = RuleSnapshotDTO(id: UUID(), name: "Old", kindRaw: "schedule", isEnabled: true,
            hardMode: false, selectionModeRaw: "block", dayNumbers: [2], startMinutes: 0,
            endMinutes: 0, dailyLimitMinutes: 45, maxOpens: 5)
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(rule)) as? [String: Any])
        object.removeValue(forKey: "conversationGoal")
        let decoded = try JSONDecoder().decode(RuleSnapshotDTO.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(decoded.conversationGoal.isEmpty)
    }
}

@MainActor
@Suite("V3 to V4 conversation migration", .serialized)
struct ConversationMigrationTests {
    @Test("Upgrade preserves rule values, lists, and relationships")
    func migration() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("migration.sqlite")
        let ruleID = UUID(), listID = UUID()
        try seed(url, ruleID: ruleID, listID: listID)
        let container = try ModelContainer(for: Schema(versionedSchema: OpenAppLockSchemaV4.self),
            migrationPlan: OpenAppLockSchemaMigrationPlan.self, configurations: ModelConfiguration(url: url))
        let context = ModelContext(container)
        let rule = try #require(context.fetch(FetchDescriptor<BlockingRule>()).first)
        #expect(rule.id == ruleID)
        #expect(rule.name == "Preserved")
        #expect(rule.configuration == .timeLimit(TimeLimitConfig(dailyLimitMinutes: 90)))
        #expect(rule.hardMode)
        #expect(rule.appLists.map(\.id) == [listID])
        #expect(rule.appLists.first?.rules.contains { $0.id == ruleID } == true)
        #expect(rule.conversationGoal.isEmpty)
        #expect(try context.fetch(FetchDescriptor<ConversationArchive>()).isEmpty)
    }
    private func seed(_ url: URL, ruleID: UUID, listID: UUID) throws {
        let container = try ModelContainer(for: Schema(versionedSchema: OpenAppLockSchemaV3.self),
            migrationPlan: OpenAppLockSchemaMigrationPlan.self, configurations: ModelConfiguration(url: url))
        let context = ModelContext(container)
        let list = OpenAppLockSchemaV3.AppList(id: listID, name: "Apps", selectionData: Data([1]), selectionCount: 1)
        let rule = OpenAppLockSchemaV3.BlockingRule(id: ruleID, name: "Preserved",
            configuration: .timeLimit(TimeLimitConfig(dailyLimitMinutes: 90)), hardMode: true)
        context.insert(list); context.insert(rule); rule.appLists = [list]
        try context.save()
    }
}
