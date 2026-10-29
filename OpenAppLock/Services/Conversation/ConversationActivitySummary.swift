import Foundation

/// Counts confirmed local grants, never measured app usage. Derived from the full
/// access archive so transcript compaction/repeated asks cannot hide recent grants.
nonisolated struct ConversationActivitySummary: Codable, Equatable, Sendable {
    let grantsLast30Minutes: Int
    let grantsLastHour: Int
    let sameAppGrantsLastHour: Int
    let grantedMinutesLastHour: Double
    let minutesSinceLastGrantEnded: Double?
    let denialsLastHour: Int

    /// Short means 1–5 granted minutes; longer means 6–30, never observed usage.
    let shortGrantsToday: Int
    let longGrantsToday: Int
    let sameAppShortGrantsToday: Int
    let sameAppLongGrantsToday: Int

    init(events: [ConversationAccessEvent], appID: UUID, now: Date) {
        let grants = events.filter { $0.date <= now && $0.decision == .approve && $0.grantID != nil }
        let today = grants.filter { Calendar.current.isDate($0.date, inSameDayAs: now) }
        let short = today.filter { (60...300).contains(($0.expiresAt ?? $0.date).timeIntervalSince($0.date)) }
        let long = today.filter { ($0.expiresAt ?? $0.date).timeIntervalSince($0.date) > 300 && ($0.expiresAt ?? $0.date).timeIntervalSince($0.date) <= 1800 }
        shortGrantsToday = short.count; longGrantsToday = long.count
        sameAppShortGrantsToday = short.filter { $0.appID == appID }.count
        sameAppLongGrantsToday = long.filter { $0.appID == appID }.count
        let hour = grants.filter { now.timeIntervalSince($0.date) < 3600 }
        grantsLastHour = hour.count
        grantsLast30Minutes = hour.filter { now.timeIntervalSince($0.date) < 1800 }.count
        sameAppGrantsLastHour = hour.filter { $0.appID == appID }.count
        grantedMinutesLastHour = hour.reduce(0) { total, event in
            let expiry = event.expiresAt ?? event.date
            let end = min(expiry, event.endedAt ?? expiry)
            return total + max(0, end.timeIntervalSince(event.date) / 60)
        }
        let lastEnd = grants.compactMap { event -> Date? in
            guard let expiry = event.expiresAt else { return event.endedAt }
            return min(expiry, event.endedAt ?? expiry)
        }.max()
        minutesSinceLastGrantEnded = lastEnd.map { max(0, now.timeIntervalSince($0) / 60) }
        denialsLastHour = events.filter {
            $0.date <= now && now.timeIntervalSince($0.date) < 3600 && $0.decision == .deny
        }.count
    }
}
