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

nonisolated struct ConversationHistory: Codable, Equatable, Sendable {
    var messages: [ConversationMessage] = []
    var memory: String = ""
    var summarizedCount: Int = 0
    var cooldownUntil: Date?
    private var recordedAccess: [ConversationAccessEvent]?
    var accessEvents: [ConversationAccessEvent] {
        get { recordedAccess ?? [] }
        set { recordedAccess = newValue }
    }
    private var recordedActivity: [ConversationActivityEntry]?
    var activityLog: [ConversationActivityEntry] {
        get { recordedActivity ?? [] }
        set { recordedActivity = newValue }
    }
    mutating func prepareActivityLog() {
        if recordedActivity == nil { recordedActivity = accessEvents.map(ConversationActivityEntry.init(event:)) }
        for index in activityLog.indices where activityLog[index].outcome == .pending {
            activityLog[index].outcome = .interrupted
            activityLog[index].systemResponse = CopyKey.activityInterruptedHelp.string
        }
    }
    private var savedProfiles: [UUID: ConversationUsageProfile]?
    var usageProfiles: [UUID: ConversationUsageProfile] {
        get { savedProfiles ?? [:] }
        set { savedProfiles = newValue }
    }
    private var savedReflections: [ConversationReflection]?
    var reflections: [ConversationReflection] {
        get { savedReflections ?? [] }
        set { savedReflections = newValue }
    }
    private var recordedRemovals: [ConversationRemovalAttempt]?
    var removalAttempts: [ConversationRemovalAttempt] {
        get { recordedRemovals ?? [] }
        set { recordedRemovals = newValue }
    }
    func recommendedPauseSeconds(for appID: UUID, now: Date) -> Int {
        let started = reflections.filter {
            $0.appID == appID && !$0.isDeal && $0.deadline != nil && $0.createdAt <= now && now.timeIntervalSince($0.createdAt) < 86400
        }.count
        return 10 + min(5, started) * 10
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

/// Writes only changed records. A small archive holds memory and timer metadata;
/// a legacy archive is converted in one save, so interrupted migration can retry.
final class ConversationHistoryStore: ConversationHistoryStoring {
    let context: ModelContext
    private var lastSaved: ConversationHistory?
    private struct Metadata: Codable { var format = 5; var history: ConversationHistory }
    init(context: ModelContext) { self.context = context }

    func load() throws -> ConversationHistory {
        guard let archive = try context.fetch(FetchDescriptor<ConversationArchive>()).first,
              !archive.payload.isEmpty else { return ConversationHistory() }
        if let metadata = try? JSONDecoder().decode(Metadata.self, from: archive.payload), metadata.format == 5 {
            var history = metadata.history
            for record in try context.fetch(FetchDescriptor<ConversationRecord>(sortBy: [SortDescriptor(\.position)])) {
                switch record.category {
                case "message": history.messages.append(try JSONDecoder().decode(ConversationMessage.self, from: record.payload))
                case "access": history.accessEvents.append(try JSONDecoder().decode(ConversationAccessEvent.self, from: record.payload))
                case "activity": history.activityLog.append(try JSONDecoder().decode(ConversationActivityEntry.self, from: record.payload))
                default: throw CocoaError(.coderReadCorrupt)
                }
            }
            lastSaved = history
            return history
        }
        var legacy = try JSONDecoder().decode(ConversationHistory.self, from: archive.payload)
        legacy.prepareActivityLog()
        try save(legacy)
        return legacy
    }

    func save(_ history: ConversationHistory) throws {
        guard history != lastSaved else { return }
        let encoder = JSONEncoder()
        var metadata = history
        metadata.messages = []; metadata.accessEvents = []; metadata.activityLog = []
        let data = try encoder.encode(Metadata(history: metadata))
        do {
            let archive: ConversationArchive
            if let existing = try context.fetch(FetchDescriptor<ConversationArchive>()).first { archive = existing }
            else { archive = ConversationArchive(); context.insert(archive) }
            let records = try context.fetch(FetchDescriptor<ConversationRecord>())
            let existing = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
            var retained = Set<String>()
            func upsert<T: Encodable>(_ values: [T], category: String, identity: (T, Int) -> String) throws {
                for (position, value) in values.enumerated() {
                    let id = category + "-" + identity(value, position)
                    retained.insert(id)
                    let payload = try encoder.encode(value)
                    if let record = existing[id] {
                        if record.payload != payload { record.payload = payload }
                        if record.position != position { record.position = position }
                    } else { context.insert(ConversationRecord(id: id, category: category, position: position, payload: payload)) }
                }
            }
            try upsert(history.messages, category: "message") { value, _ in value.id.uuidString }
            try upsert(history.accessEvents, category: "access") { value, index in value.grantID?.uuidString ?? String(index) }
            try upsert(history.activityLog, category: "activity") { value, _ in value.id.uuidString }
            for record in records where !retained.contains(record.id) { context.delete(record) }
            if archive.payload != data { archive.payload = data }
            if context.hasChanges { try context.save() }
            lastSaved = history
        } catch { context.rollback(); throw error }
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

struct UnavailableHistoryStore: ConversationHistoryStoring {
    func load() throws -> ConversationHistory { throw CocoaError(.fileReadUnknown) }
    func save(_ history: ConversationHistory) throws { throw CocoaError(.fileReadUnknown) }
}
