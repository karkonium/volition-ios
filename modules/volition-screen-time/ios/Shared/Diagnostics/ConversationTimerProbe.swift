#if DEBUG
import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

/// Debug-only device experiment. Uses its own ManagedSettings store so existing
/// rules are never lifted. All probe mutations are coordinated across processes.
/// No foreground expiry fallback: a successful test must come from the monitor.
nonisolated enum ConversationTimerProbe {
    struct Record: Codable {
        let selection: FamilyActivitySelection
        var plan: ConversationUnlockPlan?
        var callbackAt: Date?
        var callbackKind: String?
    }
    enum ProbeError: Error { case missingContainer, selectOneApp, noSelection, grantActive }
    private static var store: ManagedSettingsStore.Name { .init("conversation-timer-probe") }

    private static func withRecord<T>(_ body: (inout Record?) throws -> T) throws -> T {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier)
        else { throw ProbeError.missingContainer }
        let url = container.appendingPathComponent("conversation-timer-probe.json")
        var coordinationError: NSError?
        var result: Result<T, Error>?
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forMerging, error: &coordinationError) { coordinated in
            result = Result {
                var record: Record?
                if FileManager.default.fileExists(atPath: coordinated.path) {
                    record = try JSONDecoder().decode(Record.self, from: Data(contentsOf: coordinated))
                }
                let value = try body(&record)
                if let record {
                    try JSONEncoder().encode(record).write(to: coordinated, options: .atomic)
                } else if FileManager.default.fileExists(atPath: coordinated.path) {
                    try FileManager.default.removeItem(at: coordinated)
                }
                return value
            }
        }
        if let coordinationError { throw coordinationError }
        guard let result else { throw ProbeError.missingContainer }
        return try result.get()
    }

    static func read() throws -> Record? { try withRecord { $0 } }

    static func block(_ selection: FamilyActivitySelection) throws {
        guard selection.applicationTokens.count == 1, selection.categoryTokens.isEmpty,
              selection.webDomainTokens.isEmpty else { throw ProbeError.selectOneApp }
        try withRecord { record in
            if let plan = record?.plan, !plan.hasExpired(at: .now) { throw ProbeError.grantActive }
            if let plan = record?.plan { DeviceActivityCenter().stopMonitoring([DeviceActivityName(plan.activityName)]) }
            ManagedSettingsStore(named: store).shield.applications = selection.applicationTokens
            record = Record(selection: selection)
        }
    }

    static func unlock(minutes: Int) throws {
        try withRecord { record in
            guard var current = record else { throw ProbeError.noSelection }
            if let plan = current.plan, !plan.hasExpired(at: .now) { throw ProbeError.grantActive }
            if let plan = current.plan { DeviceActivityCenter().stopMonitoring([DeviceActivityName(plan.activityName)]) }
            let start = Date(timeIntervalSince1970: floor(Date().timeIntervalSince1970))
            let plan = try ConversationUnlockPlan(grantID: UUID(), minutes: minutes, start: start)
            let parts: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
            let schedule = DeviceActivitySchedule(
                intervalStart: Calendar.current.dateComponents(parts, from: start),
                intervalEnd: Calendar.current.dateComponents(parts, from: plan.monitoringEndsAt),
                repeats: false, warningTime: DateComponents(minute: plan.warningMinutes))
            try DeviceActivityCenter().startMonitoring(DeviceActivityName(plan.activityName), during: schedule)
            current.plan = plan
            current.callbackAt = nil
            current.callbackKind = nil
            record = current
            Diag.log(.scheduler, .event, "timer probe armed id=\(plan.grantID) duration=\(minutes) expiry=\(plan.expiresAt)")
        }
        // Clear only after persistence; serialize with an expiry arriving meanwhile.
        try withRecord { record in
            if let plan = record?.plan, !plan.hasExpired(at: .now), record?.callbackAt == nil {
                ManagedSettingsStore(named: store).clearAllSettings()
            }
        }
    }

    static func handle(activity: String, kind: String, now: Date = .now) {
        guard ConversationUnlockPlan.grantID(from: activity) != nil else { return }
        do {
            try withRecord { record in
                guard var current = record, let plan = current.plan, plan.activityName == activity else { return }
                Diag.log(.monitor, .event, "timer probe \(kind) id=\(plan.grantID) delta=\(now.timeIntervalSince(plan.expiresAt))s")
                guard plan.hasExpired(at: now) else { return }
                ManagedSettingsStore(named: store).shield.applications = current.selection.applicationTokens
                if current.callbackAt == nil {
                    current.callbackAt = now
                    current.callbackKind = kind
                }
                record = current
            }
        } catch { Diag.error(.monitor, "timer probe callback persistence failed: \(error)") }
    }

    static func reset() throws {
        try withRecord { record in
            if let plan = record?.plan { DeviceActivityCenter().stopMonitoring([DeviceActivityName(plan.activityName)]) }
            ManagedSettingsStore(named: store).clearAllSettings()
            record = nil
        }
    }
}
#endif
