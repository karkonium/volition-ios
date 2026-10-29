import Foundation

protocol ConversationKeyStoring {
    func read() throws -> String?
}

/// OpenAppLock/Conversation.env is copied into the main app bundle at build time.
/// Accepts comments, optional export, and single/double quoted values without
/// shell expansion. Missing/placeholder keys stay unconfigured. Malformed known
/// values fail locally; credentials never enter defaults or extension storage.
nonisolated struct ConversationEnvironment: Sendable {
    let apiKey: String?
    let logsEnabled: Bool
    enum InvalidConfiguration: Error { case malformed }

    static let bundled: ConversationEnvironment = {
        #if !DEBUG
        return try! ConversationEnvironment(contents: "")
        #else
        do {
            let url = Bundle.main.url(forResource: "Conversation", withExtension: "env")
            return try ConversationEnvironment(contents: try url.map { try String(contentsOf: $0, encoding: .utf8) } ?? "")
        } catch {
            let fallback = try! ConversationEnvironment(contents: "")
            if fallback.logsEnabled { Diag.error(.conversation, "///CONVO-LOG config.invalid source=bundled-env; check local file and rebuild") }
            return fallback
        }
        #endif
    }()

    init(contents: String) throws {
        var values: [String: String] = [:]
        for rawLine in contents.split(whereSeparator: \.isNewline) {
            var line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            if line.hasPrefix("export ") { line = String(line.dropFirst(7)).trimmingCharacters(in: .whitespaces) }
            let parts = line.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            let name = parts[0].trimmingCharacters(in: .whitespaces)
            guard name == "OPENAI_API_KEY" || name == "CONVO_LOG_ENABLED" else { continue }
            guard parts.count == 2 else { throw InvalidConfiguration.malformed }
            var value = parts[1].trimmingCharacters(in: .whitespaces)
            if let first = value.first, first == "\"" || first == "'" {
                guard value.count >= 2, value.last == first else { throw InvalidConfiguration.malformed }
                value = String(value.dropFirst().dropLast())
            }
            guard !value.contains(where: { $0.isWhitespace || $0.isNewline || $0 == "\"" || $0 == "'" }) else {
                throw InvalidConfiguration.malformed
            }
            values[name] = value
        }
        let key = values["OPENAI_API_KEY"] ?? ""
        apiKey = key.isEmpty || key == "your-openai-api-key" ? nil : key
        if let flag = values["CONVO_LOG_ENABLED"] {
            guard ["0", "1", "false", "true"].contains(flag) else { throw InvalidConfiguration.malformed }
            logsEnabled = flag == "1" || flag == "true"
        } else {
            #if DEBUG
            logsEnabled = true
            #else
            logsEnabled = false
            #endif
        }
    }
}

struct ConversationEnvironmentKeyStore: ConversationKeyStoring {
    func read() -> String? { ConversationEnvironment.bundled.apiKey }
}

final class MockConversationKeyStore: ConversationKeyStoring {
    var key: String? = "test-key"
    func read() -> String? { key }
}
