import Foundation

/// The product-facing coach contract never accepts a provider credential.
/// A future authenticated gateway can replace the development adapter.
protocol CoachService {
    var isConfigured: Bool { get }
    func respond(to context: ConversationContext, requestID: UUID) async throws -> ConversationDecision
    func summarize(memory: String, messages: [ConversationMessage], requestID: UUID) async throws -> String
}

struct DevelopmentCoachService: CoachService {
    let client: any ConversationClient
    let keys: any ConversationKeyStoring
    var isConfigured: Bool { ((try? keys.read()) ?? nil)?.isEmpty == false }
    private func key() throws -> String {
        guard let key = try keys.read(), !key.isEmpty else { throw ConversationClientError.unavailable }
        return key
    }
    func respond(to context: ConversationContext, requestID: UUID) async throws -> ConversationDecision {
        try await client.respond(to: context, apiKey: key())
    }
    func summarize(memory: String, messages: [ConversationMessage], requestID: UUID) async throws -> String {
        try await client.summarize(memory: memory, messages: messages, apiKey: key())
    }
}

struct UnavailableCoachService: CoachService {
    var isConfigured: Bool { false }
    func respond(to context: ConversationContext, requestID: UUID) async throws -> ConversationDecision {
        throw ConversationClientError.unavailable
    }
    func summarize(memory: String, messages: [ConversationMessage], requestID: UUID) async throws -> String {
        throw ConversationClientError.unavailable
    }
}

nonisolated struct ConversationClock: Sendable {
    var now: @Sendable () -> Date = { .now }
}
