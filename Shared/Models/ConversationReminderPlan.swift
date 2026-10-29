import Foundation

/// Separate pending identities preserve all three alerts; one thread groups them.
/// Dates are absolute grant deadlines, never a new enforcement timer.
nonisolated enum ConversationReminderPlan {
    struct Alert: Equatable, Sendable {
        let identifier: String
        let threadIdentifier: String
        let secondsRemaining: Int
        let fireAt: Date
    }
    static func identifiers(for grantID: UUID) -> [String] {
        [60, 30, 10].map { "unlock-reminder-\(grantID.uuidString)-\($0)" }
    }
    static func alerts(for plan: ConversationUnlockPlan, now: Date) -> [Alert] {
        zip([60, 30, 10], identifiers(for: plan.grantID)).compactMap { seconds, id in
            let date = plan.expiresAt.addingTimeInterval(-Double(seconds))
            guard date > now else { return nil }
            return .init(identifier: id, threadIdentifier: "unlock-\(plan.grantID.uuidString)", secondsRemaining: seconds, fireAt: date)
        }
    }
}
