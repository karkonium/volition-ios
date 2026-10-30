import Foundation

/// User-owned content log, kept in the private conversation archive. Technical
/// diagnostics never receive these messages/replies. Outcome describes the local
/// result, independently of the model decision; exports are explicit user actions.
nonisolated struct ConversationActivityEntry: Codable, Equatable, Identifiable, Sendable {
    enum ExperienceRating: String, Codable, CaseIterable, Sendable {
        case helpful, neutral, annoying
        var copy: CopyKey {
            switch self { case .helpful: .feedbackHelpful; case .neutral: .feedbackNeutral; case .annoying: .feedbackAnnoying }
        }
        var symbol: String {
            switch self { case .helpful: "hand.thumbsup"; case .neutral: "minus.circle"; case .annoying: "hand.thumbsdown" }
        }
    }
    var canRateExperience: Bool {
        [.unlocked, .denied, .dealDeclined].contains(outcome) || (outcome == .cancelled && reflectionID != nil)
    }
    enum FeedbackSignal: String, Codable, Sendable { case highFrustration = "high_frustration" }
    enum Outcome: String, Codable, Sendable {
        case pending, unlocked, asked, denied, wait, failed, cancelled, unconfirmed, interrupted
        case blockedByWait = "blocked_by_wait"
        case alreadyUnlocked = "already_unlocked"
        case reflection, dealOffered, dealDeclined, removalRequested
        case selectionRequired = "app_selection_required"
        var title: String {
            switch self {
            case .removalRequested: CopyKey.removalFeedbackTitle.string
            case .dealOffered: CopyKey.dealOffered.string
            case .dealDeclined: CopyKey.dealDeclined.string
            case .reflection: CopyKey.reflectionRecorded.string
            case .pending: CopyKey.activityPending.string
            case .unlocked: CopyKey.activityUnlocked.string
            case .asked: CopyKey.activityAsked.string
            case .denied: CopyKey.activityDenied.string
            case .wait: CopyKey.activityWait.string
            case .failed: CopyKey.activityFailed.string
            case .cancelled: CopyKey.activityCancelled.string
            case .unconfirmed: CopyKey.activityUnconfirmed.string
            case .interrupted: CopyKey.activityInterrupted.string
            case .blockedByWait: CopyKey.activityBlockedByWait.string
            case .alreadyUnlocked: CopyKey.activityAlreadyUnlocked.string
            case .selectionRequired: CopyKey.activitySelectionRequired.string
            }
        }
    }
    var id = UUID()
    var date: Date = .now
    var appID: UUID?
    var appName: String?
    var message: String
    var outcome: Outcome = .pending
    var modelDecision: ConversationDecision.Decision?
    var coachResponse: String?
    var systemResponse: String?
    var completedAt: Date?
    var unlockMinutes: Int?
    var unlockUntil: Date?
    var grantID: UUID?
    var endedAt: Date?
    var waitUntil: Date?
    var reflectionID: UUID?
    var emotion: ConversationReflection.Emotion?
    var customEmotion: String? = nil
    var experienceRating: ExperienceRating? = nil
    var ratedAt: Date? = nil
    var pauseSeconds: Int?
    var reflectionSkipped: Bool?
    var blockMinutes: Int?
    var feedbackSignal: FeedbackSignal?
    var removalID: UUID?
    var failureStage: String?

    enum CodingKeys: String, CodingKey {
        case feedbackSignal = "feedback_signal", removalID = "removal_id"
        case blockMinutes = "block_minutes"
        case id, message, outcome, emotion
        case customEmotion = "custom_emotion", experienceRating = "experience_rating", ratedAt = "rated_at"
        case reflectionID = "reflection_id", pauseSeconds = "pause_seconds", reflectionSkipped = "reflection_skipped"
        case date = "timestamp", appID = "app_id", appName = "app_name"
        case modelDecision = "model_decision", coachResponse = "coach_response", systemResponse = "system_response"
        case completedAt = "completed_at", unlockMinutes = "unlock_minutes", unlockUntil = "unlock_until"
        case grantID = "grant_id", endedAt = "ended_at", waitUntil = "wait_until", failureStage = "failure_stage"
    }

    init(event: ConversationAccessEvent) {
        date = event.date; appID = event.appID; appName = event.appName
        message = event.reason; modelDecision = event.decision; coachResponse = event.reply
        grantID = event.grantID; unlockUntil = event.expiresAt; endedAt = event.endedAt; waitUntil = event.waitUntil
        switch event.decision {
        case .deal: outcome = .dealOffered
        case .pause, .choice: outcome = .reflection
        case .ask: outcome = .asked
        case .deny: outcome = .denied
        case .wait: outcome = .wait
        case .approve, .override: outcome = event.grantID == nil ? .unconfirmed : .unlocked
        }
        systemResponse = outcome.title
        if let until = event.expiresAt { unlockMinutes = Int(until.timeIntervalSince(event.date) / 60) }
        completedAt = event.date
    }

    init(date: Date = .now, appID: UUID? = nil, appName: String? = nil, message: String,
         outcome: Outcome = .pending, modelDecision: ConversationDecision.Decision? = nil,
         coachResponse: String? = nil, systemResponse: String? = nil) {
        self.date = date; self.appID = appID; self.appName = appName; self.message = message
        self.outcome = outcome; self.modelDecision = modelDecision
        self.coachResponse = coachResponse; self.systemResponse = systemResponse
    }
}

nonisolated enum ConversationActivityExport {
    private static let exportLock = NSLock()
    nonisolated(unsafe) private static var epoch = 0
    static var currentEpoch: Int { exportLock.lock(); defer { exportLock.unlock() }; return epoch }
    static func eraseFiles(directory: URL = FileManager.default.temporaryDirectory.appendingPathComponent("VolitionActivityExports")) throws {
        exportLock.lock(); defer { exportLock.unlock() }
        epoch += 1
        if FileManager.default.fileExists(atPath: directory.path) { try FileManager.default.removeItem(at: directory) }
    }
    enum Format: Sendable, Equatable { case text, jsonLines }
    static func jsonLines(_ entries: [ConversationActivityEntry]) throws -> String {
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try entries.map { String(decoding: try encoder.encode($0), as: UTF8.self) }.joined(separator: "\n") + (entries.isEmpty ? "" : "\n")
    }
    static func text(_ entries: [ConversationActivityEntry]) -> String {
        let iso = ISO8601DateFormatter()
        return entries.map { entry in
            var lines = ["\(iso.string(from: entry.date)) | \(entry.appName ?? "No app selected") | \(entry.outcome.title)",
                "Message: \(entry.message)"]
            if let reply = entry.coachResponse { lines.append("Coach: \(reply)") }
            if let response = entry.systemResponse { lines.append("System: \(response)") }
            if let decision = entry.modelDecision { lines.append("Model decision: \(decision.rawValue)") }
            if let until = entry.unlockUntil { lines.append("Unlocked until: \(iso.string(from: until))") }
            if let until = entry.waitUntil { lines.append("Reconsider after: \(iso.string(from: until))") }
            if let ended = entry.endedAt { lines.append("Access ended: \(iso.string(from: ended))") }
            if let minutes = entry.blockMinutes { lines.append("Deal break minutes: \(minutes)") }
            if let seconds = entry.pauseSeconds { lines.append("Pause seconds: \(seconds)") }
            if let custom = entry.customEmotion { lines.append("Custom check-in: \(custom)") }
            if let rating = entry.experienceRating { lines.append("Experience: \(rating.rawValue)") }
            if let emotion = entry.emotion { lines.append("Check-in: \(emotion.rawValue)") }
            if let skipped = entry.reflectionSkipped { lines.append("Pause skipped: \(skipped)") }
            if let signal = entry.feedbackSignal { lines.append("Feedback signal: \(signal.rawValue)") }
            if let stage = entry.failureStage { lines.append("Failure stage: \(stage)") }
            return lines.joined(separator: "\n")
        }.joined(separator: "\n\n")
    }
    static func file(_ entries: [ConversationActivityEntry], format: Format,
                     directory: URL = FileManager.default.temporaryDirectory.appendingPathComponent("VolitionActivityExports"),
                     expectedEpoch: Int? = nil) throws -> URL {
        exportLock.lock(); defer { exportLock.unlock() }
        if let expectedEpoch, expectedEpoch != epoch { throw CancellationError() }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("Volition-activity.\(format == .text ? "txt" : "jsonl")")
        let content = try format == .text ? text(entries) : jsonLines(entries)
        try Data(content.utf8).write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        return url
    }
}
