import Foundation

/// Counts confirmed access opportunities. These values never describe observed
/// foreground use or time saved. Failed model approvals do not count as grants.
nonisolated struct AccessInsights: Sendable {
    let requests: Int
    let grants: Int
    let grantedMinutes: Int
    let denials: Int
    let waits: Int
    let earlyEndings: Int
    init(entries: [ConversationActivityEntry], start: Date, end: Date) {
        let entries = entries.filter { $0.date >= start && $0.date < end }
        let confirmed = entries.filter { $0.outcome == .unlocked && $0.grantID != nil }
        requests = entries.count
        grants = confirmed.count
        grantedMinutes = confirmed.reduce(0) { $0 + max(0, $1.unlockMinutes ?? 0) }
        denials = entries.filter { $0.outcome == .denied }.count
        waits = entries.filter { $0.outcome == .wait }.count
        earlyEndings = confirmed.filter {
            guard let end = $0.endedAt, let expiry = $0.unlockUntil else { return false }
            return end < expiry
        }.count
    }
}
