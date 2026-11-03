import Foundation

/// Removal intent is a product-friction signal, not an emotional diagnosis.
/// This private coaching ledger survives clearing the transcript/activity export.
nonisolated struct ConversationRemovalAttempt: Codable, Equatable, Identifiable, Sendable {
    enum Outcome: String, Codable, Sendable { case considering, kept, removed, temporaryUnlockRequested }
    let id: UUID
    let appID: UUID
    let appName: String
    let date: Date
    var reason: String?
    var outcome: Outcome = .considering
    var requestedMinutes: Int?
    var completedAt: Date?
}
