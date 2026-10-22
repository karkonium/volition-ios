import Foundation
import Testing
@testable import OpenAppLock

@MainActor
struct ConversationEnvironmentTests {
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
