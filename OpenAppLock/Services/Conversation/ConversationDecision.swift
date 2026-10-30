import Foundation

/// Model output is advice until validated and bound to a live local request.
nonisolated struct ConversationDecision: Codable, Equatable, Sendable {
    enum Decision: String, Codable, Sendable { case ask, deny, approve, wait, pause, deal, choice, override }
    let reply: String
    let decision: Decision
    let unlockMinutes: Int?
    var waitMinutes: Int? = nil
    var pauseSeconds: Int? = nil
    var blockMinutes: Int? = nil
    enum CodingKeys: String, CodingKey { case reply, decision; case unlockMinutes = "unlock_minutes"; case waitMinutes = "wait_minutes"; case pauseSeconds = "pause_seconds"; case blockMinutes = "block_minutes" }
    enum InvalidResponse: Error { case invalid }

    static func parse(_ data: Data) throws -> Self {
        let result = try JSONDecoder().decode(Self.self, from: data)
        guard !result.reply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              result.reply.count <= 8000 else { throw InvalidResponse.invalid }
        if [.approve, .pause, .deal, .choice, .override].contains(result.decision) {
            guard let minutes = result.unlockMinutes, (1...60).contains(minutes) else { throw InvalidResponse.invalid }
        } else if result.unlockMinutes != nil { throw InvalidResponse.invalid }
        if result.decision == .wait {
            guard let minutes = result.waitMinutes, (1...5).contains(minutes) else { throw InvalidResponse.invalid }
        } else if result.waitMinutes != nil { throw InvalidResponse.invalid }
        if result.decision == .pause || result.decision == .choice {
            guard let seconds = result.pauseSeconds, (10...1800).contains(seconds) else { throw InvalidResponse.invalid }
        } else if result.pauseSeconds != nil { throw InvalidResponse.invalid }
        if [.deal, .choice, .override].contains(result.decision) {
            guard let minutes = result.blockMinutes, (1...1440).contains(minutes) else { throw InvalidResponse.invalid }
        } else if result.blockMinutes != nil { throw InvalidResponse.invalid }
        return result
    }
}
