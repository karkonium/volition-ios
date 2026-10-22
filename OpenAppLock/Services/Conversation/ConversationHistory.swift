import Foundation
import SwiftData

nonisolated struct ConversationMessage: Codable, Identifiable, Equatable, Sendable {
    enum Role: String, Codable, Sendable { case user, assistant, event }
    var id: UUID = UUID()
    var date: Date = .now
    var role: Role
    var text: String
    var requestID: UUID?
}

nonisolated struct ConversationHistory: Codable, Sendable {
    var messages: [ConversationMessage] = []
    var memory: String = ""
    var summarizedCount: Int = 0
    var cooldownUntil: Date?
    private var recordedAccess: [ConversationAccessEvent]?
    var accessEvents: [ConversationAccessEvent] {
        get { recordedAccess ?? [] }
        set { recordedAccess = newValue }
    }
    var lastGrantID: UUID?
    var lastGrantExpiry: Date?
    var recentMessages: [ConversationMessage] { Array(messages.dropFirst(summarizedCount)) }
}

/// A single SwiftData archive, saved before requests and after each decision.
/// Writes fail visibly; decoding failure never silently destroys the transcript.
protocol ConversationHistoryStoring {
    func load() throws -> ConversationHistory
    func save(_ history: ConversationHistory) throws
}

struct ConversationHistoryStore: ConversationHistoryStoring {
    let context: ModelContext
    func load() throws -> ConversationHistory {
        guard let archive = try context.fetch(FetchDescriptor<ConversationArchive>()).first,
              !archive.payload.isEmpty else { return ConversationHistory() }
        return try JSONDecoder().decode(ConversationHistory.self, from: archive.payload)
    }
    func save(_ history: ConversationHistory) throws {
        let data = try JSONEncoder().encode(history)
        let archive: ConversationArchive
        if let existing = try context.fetch(FetchDescriptor<ConversationArchive>()).first { archive = existing }
        else { archive = ConversationArchive(); context.insert(archive) }
        archive.payload = data
        try context.save()
    }
}

/// Structured decisions and actual grants survive transcript compaction. An end
/// timestamp records early revocation or scheduled expiry, never measured usage.
nonisolated struct ConversationAccessEvent: Codable, Equatable, Sendable {
    var date: Date
    var appID: UUID
    var appName: String
    var reason: String
    var decision: ConversationDecision.Decision
    var reply: String
    var grantID: UUID?
    var expiresAt: Date?
    var endedAt: Date?
    var waitUntil: Date?
}
