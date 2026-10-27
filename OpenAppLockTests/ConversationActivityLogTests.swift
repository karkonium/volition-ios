import Foundation
import Testing
@testable import OpenAppLock

@MainActor struct ConversationActivityLogTests {
    @Test func exportsActualOutcomeAndEscapesMultilineContent() throws {
        let entry = ConversationActivityEntry(date: Date(timeIntervalSince1970: 1_800_000_000),
            appName: "SoundCloud", message: "Play a song\ncalled \"Sun\"", outcome: .failed,
            modelDecision: .approve, coachResponse: "I'll unlock it.", systemResponse: "Unlock failed.")
        let lines = try ConversationActivityExport.jsonLines([entry])
        #expect(lines.split(separator: "\n").count == 1)
        let record = try #require(JSONSerialization.jsonObject(with: Data(lines.utf8)) as? [String: Any])
        #expect(record["outcome"] as? String == "failed")
        #expect(record["message"] as? String == entry.message)
        #expect(record["timestamp"] is String)
        #expect(record["coach_response"] as? String == entry.coachResponse)
        #expect(record["system_response"] as? String == "Unlock failed.")
        let readable = ConversationActivityExport.text([entry])
        #expect(readable.contains("SoundCloud"))
        #expect(readable.contains("Unlock failed."))
        #expect(readable.contains("Play a song"))
    }
    @Test func legacyMigrationAndClearAreStableAcrossEncoding() throws {
        var history = ConversationHistory()
        history.accessEvents = [.init(date: .now, appID: UUID(), appName: "Maps",
            reason: "Directions", decision: .approve, reply: "Yes")]
        history.prepareActivityLog()
        #expect(history.activityLog.first?.outcome == .unconfirmed)
        let id = history.activityLog.first?.id
        var decoded = try JSONDecoder().decode(ConversationHistory.self, from: JSONEncoder().encode(history))
        decoded.prepareActivityLog()
        #expect(decoded.activityLog.first?.id == id)
        decoded.activityLog = []
        decoded.prepareActivityLog()
        #expect(decoded.activityLog.isEmpty)
        #expect(decoded.accessEvents.count == 1)
    }
    @Test func exportFilesPreserveRecordsInBothFormats() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let entries = [ConversationActivityEntry(appName: "Maps", message: "Directions", outcome: .asked),
                       ConversationActivityEntry(appName: "Maps", message: "Five minutes", outcome: .unlocked)]
        let text = try ConversationActivityExport.file(entries, format: .text, directory: directory)
        let json = try ConversationActivityExport.file(entries, format: .jsonLines, directory: directory)
        #expect(text.pathExtension == "txt")
        #expect(try String(contentsOf: text, encoding: .utf8) == ConversationActivityExport.text(entries))
        let lines = try String(contentsOf: json, encoding: .utf8).split(separator: "\n")
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let restored = try lines.map { try decoder.decode(ConversationActivityEntry.self, from: Data($0.utf8)) }
        #expect(restored.map(\.id) == entries.map(\.id))
        #expect(restored.map(\.outcome) == [.asked, .unlocked])
    }
    @Test func interruptedRequestDoesNotBecomeAnUnlockAfterRelaunch() throws {
        var history = ConversationHistory()
        history.activityLog = [.init(appName: "Maps", message: "Directions")]
        var restored = try JSONDecoder().decode(ConversationHistory.self, from: JSONEncoder().encode(history))
        restored.prepareActivityLog()
        #expect(restored.activityLog.first?.outcome == .interrupted)
        #expect(restored.activityLog.first?.systemResponse == CopyKey.activityInterruptedHelp.string)
        #expect(restored.activityLog.first?.grantID == nil)
    }
}
