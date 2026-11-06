import Foundation

/// Commands validate against the live profiles and exact occurrence in the grant transaction.
nonisolated struct FocusCommand: Decodable, Sendable {
    enum Kind: String, Decodable, Sendable {
        case saveRoutine, deleteRoutine, savePreferences, startSession, endSession, exceptApp
    }
    let kind: Kind
    var expectedRevision: Int?
    var period: FocusPeriod?
    var sourceId: UUID?
    var preferences: QuickFocusPreferences?
    var occurrenceID: String?
    var appID: UUID?

    func apply(to focus: inout FocusProtectionState, apps: Set<UUID>, now: Date) throws {
        if let expectedRevision, expectedRevision != (focus.revision ?? 0) {
            throw ConversationAccessError.staleRequest
        }
        switch kind {
        case .saveRoutine:
            guard var period, period.isValid, let allApps = period.allApps else {
                throw ConversationAccessError.focusInvalid
            }
            if period.isEnabled && !allApps && period.appIDs.isDisjoint(with: apps) {
                throw ConversationAccessError.focusNeedsApps
            }
            if allApps { period.appIDs = [] }
            period.revision = UUID()
            period.skippedUntil = nil
            if let index = focus.periods.firstIndex(where: { $0.id == period.id }) {
                focus.periods[index] = period
            } else {
                focus.periods.append(period)
            }
        case .deleteRoutine:
            guard let sourceId else { throw ConversationAccessError.focusInvalid }
            focus.periods.removeAll { $0.id == sourceId }
        case .savePreferences:
            guard var preferences, (15...180).contains(preferences.minutes) else {
                throw ConversationAccessError.focusInvalid
            }
            guard preferences.allApps ? !apps.isEmpty : !preferences.appIDs.isDisjoint(with: apps) else {
                throw ConversationAccessError.focusNeedsApps
            }
            if preferences.allApps { preferences.appIDs = [] }
            focus.preferences = preferences
        case .startSession:
            if focus.session?.isActive(at: now) == true { return }
            guard let preferences = focus.preferences,
                preferences.allApps ? !apps.isEmpty : !preferences.appIDs.isDisjoint(with: apps)
            else { throw ConversationAccessError.focusNeedsApps }
            focus.session = FocusSession(
                appIDs: preferences.appIDs, allApps: preferences.allApps,
                start: Date(timeIntervalSince1970: floor(now.timeIntervalSince1970)), minutes: preferences.minutes)
        case .endSession:
            if let sourceId, focus.session?.id != sourceId { throw ConversationAccessError.staleRequest }
            focus.session = nil
        case .exceptApp:
            guard let occurrenceID, let appID,
                let occurrence = focus.occurrences(at: now, apps: apps, includeUpcoming: false).active
                    .first(where: { $0.id == occurrenceID && $0.protects(appID) })
            else { throw ConversationAccessError.staleRequest }
            focus.exceptions =
                (focus.exceptions ?? []).filter { $0.endsAt > now } + [
                    FocusException(occurrenceID: occurrenceID, appID: appID, endsAt: occurrence.endsAt)
                ]
        }
    }
}

nonisolated struct FocusSnapshot: Encodable {
    let revision: Int
    let observedAt: String
    let periods: [FocusPeriod]
    let session: FocusSession?
    let preferences: QuickFocusPreferences?
    let active: [FocusOccurrence]
    let upcoming: [FocusOccurrence]
    let nextRefreshAt: Date?

    init(_ focus: FocusProtectionState, apps: Set<UUID>, now: Date) {
        revision = focus.revision ?? 0
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        observedAt = formatter.string(from: now)
        periods = focus.periods
        session = focus.session.flatMap { $0.isActive(at: now) ? $0 : nil }
        preferences = focus.preferences
        let occurrences = focus.occurrences(at: now, apps: apps)
        active = occurrences.active
        upcoming = occurrences.upcoming
        nextRefreshAt = [active.first?.endsAt, upcoming.first?.startsAt].compactMap { $0 }.min()
    }
}
