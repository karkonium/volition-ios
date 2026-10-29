import Foundation
import SwiftData
import Testing
@testable import OpenAppLock

@MainActor
@Suite("Conversation record migration", .serialized)
struct ConversationRecordMigrationTests {
    private func writeV4(_ url: URL, history: ConversationHistory) throws {
        let container = try ModelContainer(for: Schema(versionedSchema: OpenAppLockSchemaV4.self),
            configurations: ModelConfiguration(url: url))
        let archive = ConversationArchive(); archive.payload = try JSONEncoder().encode(history)
        container.mainContext.insert(archive)
        try container.mainContext.save()
    }

    @Test("An on-disk V4 archive migrates once without losing IDs, dates or memory")
    func reopenArchive() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("history.sqlite")
        var history = ConversationHistory()
        history.messages = [.init(role: .user, text: "Remember this")]
        history.memory = "Saved intention"; history.cooldownUntil = Date().addingTimeInterval(200)
        try writeV4(url, history: history)
        let container = try ModelContainer(for: Schema(versionedSchema: OpenAppLockSchemaV5.self),
            migrationPlan: OpenAppLockSchemaMigrationPlan.self, configurations: ModelConfiguration(url: url))
        let store = ConversationHistoryStore(context: container.mainContext)
        let migrated = try store.load()
        #expect(migrated.messages == history.messages)
        #expect(migrated.memory == history.memory)
        #expect(migrated.cooldownUntil == history.cooldownUntil)
        #expect(try store.load().messages == history.messages)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<ConversationRecord>()) == 1)
        try store.save(migrated)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<ConversationRecord>()) == 1)
    }
}
