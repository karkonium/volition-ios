import Foundation

/// A 1–60 minute wall-clock grant. DeviceActivity monitors at least 16 minutes;
/// its end warning is requested at the grant expiry. Device verification is
/// required before this mechanism can authorize production conversation grants.
/// A unique activity per grant prevents old callbacks ending a newer grant.
nonisolated struct ConversationUnlockPlan: Codable, Equatable, Sendable {
    enum ValidationError: Error { case invalidDuration }
    let grantID: UUID
    let minutes: Int
    let start: Date

    init(grantID: UUID, minutes: Int, start: Date) throws {
        guard (1...60).contains(minutes) else { throw ValidationError.invalidDuration }
        self.grantID = grantID
        self.minutes = minutes
        self.start = start
    }

    private enum CodingKeys: String, CodingKey { case grantID, minutes, start }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(grantID: values.decode(UUID.self, forKey: .grantID),
                      minutes: values.decode(Int.self, forKey: .minutes),
                      start: values.decode(Date.self, forKey: .start))
    }

    var expiresAt: Date { start.addingTimeInterval(Double(minutes * 60)) }
    var monitoringEndsAt: Date { start.addingTimeInterval(Double(max(16, minutes + 5) * 60)) }
    var warningMinutes: Int { max(16, minutes + 5) - minutes }
    var activityName: String { Self.prefix + grantID.uuidString }
    func hasExpired(at now: Date) -> Bool { now >= expiresAt }

    private static let prefix = "conversation-grant-"
    static func grantID(from name: String) -> UUID? {
        guard name.hasPrefix(prefix) else { return nil }
        return UUID(uuidString: String(name.dropFirst(prefix.count)))
    }
}
