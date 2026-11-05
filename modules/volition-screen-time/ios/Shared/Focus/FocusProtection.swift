import Foundation
import DeviceActivity

/// A missing allApps flag decodes the original format. New writes always specify scope.
nonisolated struct FocusPeriod: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var name: String
    var appIDs: Set<UUID>
    var allApps: Bool?
    var revision: UUID?
    var weekdays: Set<Int>
    var startMinutes: Int
    var endMinutes: Int
    var isEnabled = true
    var skippedUntil: Date?
    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 100 && !weekdays.isEmpty
            && weekdays.allSatisfy { (1...7).contains($0) } && (0..<1440).contains(startMinutes)
            && (0..<1440).contains(endMinutes) && (endMinutes - startMinutes + 1440) % 1440 >= 15
    }
    func interval(startingOn day: Date, calendar: Calendar) -> DateInterval? {
        guard isEnabled, isValid, weekdays.contains(calendar.component(.weekday, from: day)),
            let endDay = calendar.date(byAdding: .day, value: endMinutes < startMinutes ? 1 : 0, to: day)
        else { return nil }
        func time(_ minutes: Int, on date: Date) -> Date? {
            calendar.date(
                bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: date,
                matchingPolicy: .nextTimePreservingSmallerComponents, repeatedTimePolicy: .first)
        }
        guard let start = time(startMinutes, on: day), let end = time(endMinutes, on: endDay), end > start
        else { return nil }
        return DateInterval(start: start, end: end)
    }
    var activityName: String { "focus-period-\(id.uuidString)-\(startMinutes)-\(endMinutes)" }
}

nonisolated struct FocusSession: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var appIDs: Set<UUID>
    var allApps: Bool?
    var start: Date
    var minutes: Int
    var expiresAt: Date { start.addingTimeInterval(Double(minutes * 60)) }
    var isValid: Bool { (15...180).contains(minutes) }
    func isActive(at now: Date) -> Bool { isValid && now >= start && now < expiresAt }
    var activityName: String { "focus-session-" + id.uuidString }
}

nonisolated struct QuickFocusPreferences: Codable, Equatable, Sendable {
    var appIDs: Set<UUID>
    var allApps: Bool
    var minutes: Int
}

nonisolated struct FocusOccurrence: Codable, Sendable {
    let id: String
    let sourceId: UUID
    let kind: String
    let name: String?
    let appIDs: Set<UUID>
    var exceptedAppIDs: Set<UUID> = []
    let startsAt: Date
    let endsAt: Date

    func protects(_ appID: UUID) -> Bool {
        appIDs.contains(appID) && !exceptedAppIDs.contains(appID)
    }
}

nonisolated struct FocusException: Codable, Equatable, Sendable {
    let occurrenceID: String
    let appID: UUID
    let endsAt: Date
}

/// One calendar calculation serves grants, the monitor, the bridge and shield copy.
nonisolated struct FocusProtectionState: Codable, Equatable, Sendable {
    var periods: [FocusPeriod] = []
    var session: FocusSession?
    var preferences: QuickFocusPreferences?
    var exceptions: [FocusException]?
    var revision: Int?

    var isValid: Bool {
        periods.allSatisfy(\.isValid) && Set(periods.map(\.id)).count == periods.count
            && (session?.isValid ?? true)
            && (preferences.map { (15...180).contains($0.minutes) } ?? true)
    }

    func occurrences(
        at now: Date, apps: Set<UUID>, calendar: Calendar = .current, includeUpcoming: Bool = true
    ) -> (active: [FocusOccurrence], upcoming: [FocusOccurrence]) {
        let today = calendar.startOfDay(for: now)
        var active: [FocusOccurrence] = []
        var upcoming: [FocusOccurrence] = []
        func scope(_ ids: Set<UUID>, _ all: Bool?) -> Set<UUID> {
            (all ?? ids.isEmpty) ? apps : apps.intersection(ids)
        }
        func add(_ occurrence: FocusOccurrence) {
            guard !occurrence.appIDs.isEmpty else { return }
            var occurrence = occurrence
            occurrence.exceptedAppIDs = Set(
                (exceptions ?? []).filter {
                    $0.occurrenceID == occurrence.id && $0.endsAt > now && occurrence.appIDs.contains($0.appID)
                }.map(\.appID))
            if occurrence.startsAt <= now && now < occurrence.endsAt {
                active.append(occurrence)
            } else if includeUpcoming && occurrence.startsAt > now {
                upcoming.append(occurrence)
            }
        }
        if let session, session.isActive(at: now) {
            add(
                .init(
                    id: session.id.uuidString, sourceId: session.id, kind: "session", name: nil,
                    appIDs: scope(session.appIDs, session.allApps), startsAt: session.start, endsAt: session.expiresAt))
        }
        for period in periods where period.isEnabled {
            let ids = scope(period.appIDs, period.allApps)
            guard !ids.isEmpty else { continue }
            for offset in -1...(includeUpcoming ? 7 : 0) {
                guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                    let interval = period.interval(startingOn: day, calendar: calendar),
                    interval.end > now, period.skippedUntil.map({ interval.start >= $0 }) ?? true
                else { continue }
                let key =
                    "\(period.id.uuidString):\((period.revision ?? period.id).uuidString):\(Int(interval.start.timeIntervalSince1970))"
                add(
                    .init(
                        id: key, sourceId: period.id, kind: "routine", name: period.name, appIDs: ids,
                        startsAt: interval.start, endsAt: interval.end))
                if interval.start > now { break }
            }
        }
        return (
            active.sorted { ($0.endsAt, $0.id) < ($1.endsAt, $1.id) },
            upcoming.sorted { ($0.startsAt, $0.id) < ($1.startsAt, $1.id) }
        )
    }

    func activityNames(at now: Date) -> Set<String> {
        var names = Set(periods.filter { $0.isEnabled && $0.isValid }.map(\.activityName))
        if let session, session.isActive(at: now) { names.insert(session.activityName) }
        return names
    }
}

/// Presentation-only snapshot. Shield callbacks read atomically without the grant lock.
nonisolated struct FocusDisplayStore {
    let url: URL?

    init(base: URL? = ConversationGrantStore().fileURL) {
        url = base?.appendingPathExtension("focus-display")
    }

    func load() -> FocusProtectionState? {
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(FocusProtectionState.self, from: data)
    }

    func publish(_ state: FocusProtectionState) throws {
        guard let url else { return }
        var display = state
        display.preferences = nil
        display.periods.removeAll { !$0.isEnabled }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        if load() != display {
            try encoder.encode(display).write(
                to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        }
    }
}

nonisolated protocol FocusMonitoring: Sendable {
    func register(_ state: FocusProtectionState, now: Date, reservingSlots: Bool) throws
    func keepOnly(_ names: Set<String>)
}

nonisolated struct DeviceFocusMonitor: FocusMonitoring {
    func register(_ state: FocusProtectionState, now: Date, reservingSlots: Bool) throws {
        let center = DeviceActivityCenter()
        let existing = Set(center.activities.map(\.rawValue))
        let wanted = state.activityNames(at: now)
        try MonitoringCapacity.validate(existing: Array(existing), adding: Array(wanted))
        if reservingSlots {
            // Recurring protection may not use the last slots for Quick Focus and Chat.
            let persistent = existing.filter {
                !$0.hasPrefix("focus-") && !$0.hasPrefix(ConversationUnlockPlan.prefix)
            }.union(wanted.filter { $0.hasPrefix("focus-period-") })
            guard persistent.count <= MonitoringCapacity.maximum - 2 else {
                throw ConversationAccessError.monitoringUnavailable
            }
        }
        for period in state.periods where period.isEnabled && !existing.contains(period.activityName) {
            try center.startMonitoring(
                DeviceActivityName(period.activityName),
                during: DeviceActivitySchedule(
                    intervalStart: DateComponents(hour: period.startMinutes / 60, minute: period.startMinutes % 60),
                    intervalEnd: DateComponents(hour: period.endMinutes / 60, minute: period.endMinutes % 60),
                    repeats: true))
        }
        if let session = state.session, session.isActive(at: now), !existing.contains(session.activityName) {
            let components: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
            var utc = Calendar(identifier: .gregorian)
            utc.timeZone = TimeZone(secondsFromGMT: 0)!
            func parts(_ date: Date) -> DateComponents {
                var result = utc.dateComponents(components, from: date)
                result.timeZone = utc.timeZone
                return result
            }
            try center.startMonitoring(
                DeviceActivityName(session.activityName),
                during: DeviceActivitySchedule(
                    intervalStart: parts(session.start),
                    intervalEnd: parts(session.expiresAt), repeats: false))
        }
    }
    func keepOnly(_ names: Set<String>) {
        let center = DeviceActivityCenter()
        center.stopMonitoring(
            center.activities.filter { $0.rawValue.hasPrefix("focus-") && !names.contains($0.rawValue) })
    }
}

nonisolated struct MockFocusMonitor: FocusMonitoring {
    func register(_ state: FocusProtectionState, now: Date, reservingSlots: Bool) throws {}
    func keepOnly(_ names: Set<String>) {}
}
