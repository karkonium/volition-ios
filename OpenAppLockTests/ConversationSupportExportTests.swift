#if DEBUG
import Foundation
import Testing
@testable import OpenAppLock

@Suite struct ConversationSupportExportTests {
    @Test func snapshotTimestampAndMissingStateDoNotReuseAnEarlierGrant() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let group = root.appendingPathComponent("group"), output = root.appendingPathComponent("export")
        try FileManager.default.createDirectory(at: group, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let state = group.appendingPathComponent("conversation-access.json")
        try Data("old-state".utf8).write(to: state)
        try ConversationSupportExport.export(group: group, destination: output)
        try FileManager.default.removeItem(at: state)
        try ConversationSupportExport.export(group: group, destination: output)
        #expect(!FileManager.default.fileExists(atPath: output.appendingPathComponent("conversation-access.json").path))
        let manifest = try JSONDecoder().decode([String: String].self,
            from: Data(contentsOf: output.appendingPathComponent("capture.json")))
        #expect(manifest["capturedAt"].flatMap { ISO8601DateFormatter().date(from: $0) } != nil)
    }
    @Test func exportsOnlyDiagnosticsAndEnforcementState() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let group = root.appendingPathComponent("group"), output = root.appendingPathComponent("export")
        let logs = group.appendingPathComponent("Logs")
        try FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        for name in ["conversation-access.json", "Conversation.env", "default.store", "conversation-transcript.json"] {
            try Data(name.utf8).write(to: group.appendingPathComponent(name))
        }
        try Data("diagnostic".utf8).write(to: logs.appendingPathComponent("app-2026-10-22.log"))
        try Data("private".utf8).write(to: logs.appendingPathComponent("private.txt"))
        try ConversationSupportExport.export(group: group, destination: output)
        var expected: Set<String> = ["Logs", "conversation-access.json", "capture.json"]
        if #available(iOS 26.5, *) { expected.insert("shield-configuration.json") }
        #expect(Set(try FileManager.default.contentsOfDirectory(atPath: output.path)) == expected)
        #expect(try FileManager.default.contentsOfDirectory(atPath: output.appendingPathComponent("Logs").path) == ["app-2026-10-22.log"])
    }
}
#endif
