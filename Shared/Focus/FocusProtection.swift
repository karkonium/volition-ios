import Foundation
import DeviceActivity

/// App IDs are local profile identities. An empty set means all saved apps.
nonisolated struct FocusPeriod: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var name: String
    var appIDs: Set<UUID>
    var weekdays: Set<Int>
    var startMinutes: Int
    var endMinutes: Int
    var isEnabled = true
    var skippedUntil: Date?
    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 100 &&
        !weekdays.isEmpty && weekdays.allSatisfy { (1...7).contains($0) } &&
        (0..<1440).contains(startMinutes) && (0..<1440).contains(endMinutes) &&
        (endMinutes - startMinutes + 1440) % 1440 >= 15
    }
    func activeInterval(at now: Date, calendar: Calendar = .current) -> DateInterval? {
        guard isEnabled, isValid, skippedUntil.map({ now >= $0 }) ?? true else { return nil }
        let minute = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
        let overnight = endMinutes < startMinutes
        let day = calendar.startOfDay(for: now)
        let owner = overnight && minute < endMinutes ? calendar.date(byAdding: .day, value: -1, to: day)! : day
        guard weekdays.contains(calendar.component(.weekday, from: owner)),
              let start = calendar.date(bySettingHour: startMinutes / 60, minute: startMinutes % 60, second: 0, of: owner),
              let endDay = calendar.date(byAdding: .day, value: overnight ? 1 : 0, to: owner),
              let end = calendar.date(bySettingHour: endMinutes / 60, minute: endMinutes % 60, second: 0, of: endDay),
              now >= start, now < end else { return nil }
        return DateInterval(start: start, end: end)
    }
    func isActive(at now: Date, calendar: Calendar = .current) -> Bool { activeInterval(at: now, calendar: calendar) != nil }
    var activityName: String { "focus-period-\(id.uuidString)-\(startMinutes)-\(endMinutes)" }
}

nonisolated struct FocusSession: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var appIDs: Set<UUID>
    var start: Date
    var minutes: Int
    var expiresAt: Date { start.addingTimeInterval(Double(minutes * 60)) }
    var isValid: Bool { (15...180).contains(minutes) }
    func isActive(at now: Date) -> Bool { isValid && now >= start && now < expiresAt }
    var activityName: String { "focus-session-" + id.uuidString }
}

nonisolated struct FocusProtectionState: Codable, Equatable, Sendable {
    var periods: [FocusPeriod] = []
    var session: FocusSession?
    func protects(appID: UUID, at now: Date, calendar: Calendar = .current) -> Bool {
        if let session, session.isActive(at: now), session.appIDs.isEmpty || session.appIDs.contains(appID) { return true }
        return periods.contains { ($0.appIDs.isEmpty || $0.appIDs.contains(appID)) && $0.isActive(at: now, calendar: calendar) }
    }
    func activityNames(at now: Date) -> Set<String> {
        var names = Set(periods.filter { $0.isEnabled && $0.isValid }.map(\.activityName))
        if let session, session.isActive(at: now) { names.insert(session.activityName) }
        return names
    }
}

nonisolated struct FocusStore: Sendable {
    let fileURL: URL?
    func load() throws -> FocusProtectionState {
        guard let fileURL else { throw ConversationAccessError.storageUnavailable }
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return FocusProtectionState() }
        let state = try JSONDecoder().decode(FocusProtectionState.self, from: Data(contentsOf: fileURL))
        guard state.periods.allSatisfy(\.isValid), state.session?.isValid ?? true else { throw ConversationAccessError.storageUnavailable }
        return state
    }
    // All writes are made under the grant transaction; shield requests never read it.
    func save(_ state: FocusProtectionState) throws {
        guard let fileURL else { throw ConversationAccessError.storageUnavailable }
        try JSONEncoder().encode(state).write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}

nonisolated protocol FocusMonitoring: Sendable {
    func register(_ state: FocusProtectionState, now: Date) throws
    func keepOnly(_ names: Set<String>)
}

nonisolated struct DeviceFocusMonitor: FocusMonitoring {
    func register(_ state: FocusProtectionState, now: Date) throws {
        let center = DeviceActivityCenter()
        let existing = Set(center.activities.map(\.rawValue))
        try MonitoringCapacity.validate(existing: Array(existing), adding: Array(state.activityNames(at: now)))
        for period in state.periods where period.isEnabled && !existing.contains(period.activityName) {
            try center.startMonitoring(DeviceActivityName(period.activityName), during: DeviceActivitySchedule(
                intervalStart: DateComponents(hour: period.startMinutes / 60, minute: period.startMinutes % 60),
                intervalEnd: DateComponents(hour: period.endMinutes / 60, minute: period.endMinutes % 60), repeats: true))
        }
        if let session = state.session, session.isActive(at: now), !existing.contains(session.activityName) {
            let components: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
            try center.startMonitoring(DeviceActivityName(session.activityName), during: DeviceActivitySchedule(
                intervalStart: Calendar.current.dateComponents(components, from: session.start),
                intervalEnd: Calendar.current.dateComponents(components, from: session.expiresAt), repeats: false))
        }
    }
    func keepOnly(_ names: Set<String>) {
        let center = DeviceActivityCenter()
        center.stopMonitoring(center.activities.filter { $0.rawValue.hasPrefix("focus-") && !names.contains($0.rawValue) })
    }
}

nonisolated struct MockFocusMonitor: FocusMonitoring {
    func register(_ state: FocusProtectionState, now: Date) throws {}
    func keepOnly(_ names: Set<String>) {}
}
