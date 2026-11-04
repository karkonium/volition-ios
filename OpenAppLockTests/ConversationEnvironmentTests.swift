import Foundation
import Testing
@testable import OpenAppLock

@MainActor
struct ConversationEnvironmentTests {
    @Test("Bundled prototype credentials load the same way in Debug and Release")
    func bundledConfigurationIsNotDisabled() throws {
        let url = Bundle.main.url(forResource: "Conversation", withExtension: "env")
        let expected = try ConversationEnvironment(contents: try url.map { try String(contentsOf: $0, encoding: .utf8) } ?? "")
        // Compare via a Boolean so a regression cannot print the credential.
        let matches = ConversationEnvironment.bundled.apiKey == expected.apiKey
        #expect(matches)
    }

    @Test func parsesQuotedLocalEnvironment() throws {
        let config = try ConversationEnvironment(contents: "# local config\nexport OPENAI_API_KEY = \"test-only\"\nCONVO_LOG_ENABLED=0\n")
        #expect(config.apiKey == "test-only")
        #expect(!config.logsEnabled)
    }

    @Test("Missing, empty and placeholder keys are unconfigured", arguments: ["", "OPENAI_API_KEY=", "OPENAI_API_KEY=your-openai-api-key"])
    func missingKey(contents: String) throws {
        #expect(try ConversationEnvironment(contents: contents).apiKey == nil)
    }

    @Test("Malformed credentials fail locally", arguments: ["OPENAI_API_KEY=\"unterminated", "OPENAI_API_KEY=two words"])
    func malformed(contents: String) {
        #expect(throws: (any Error).self) { try ConversationEnvironment(contents: contents) }
    }
}
