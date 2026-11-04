import DeviceActivity
import Foundation

/// Replace only superseded Focus registrations. At capacity, retire restorable
/// Focus schedules before adding replacements; restore them if registration fails.
/// Grant registrations are never stopped. Empty stop lists are never sent because
/// DeviceActivity treats them as stopping all monitoring. Callers serialize policy writes.
nonisolated enum FocusMonitorReplacement {
    static func apply(existing: [String: DeviceActivitySchedule], occupied: Set<String>,
                      desired: [String: DeviceActivitySchedule],
                      start: (String, DeviceActivitySchedule) throws -> Void,
                      stop: ([String]) -> Void) throws {
        let retired = Set(existing.keys.filter { $0.hasPrefix("focus-") }).subtracting(desired.keys)
        try MonitoringCapacity.validate(existing: Array(occupied.subtracting(retired)), adding: Array(desired.keys))
        let retireFirst = occupied.union(desired.keys).count > MonitoringCapacity.maximum
        var attempted: [String] = []
        if retireFirst && !retired.isEmpty { stop(retired.sorted()) }
        do {
            for name in desired.keys.sorted() {
                guard let schedule = desired[name], existing[name] != schedule else { continue }
                attempted.append(name)
                try start(name, schedule)
            }
            if !retireFirst && !retired.isEmpty { stop(retired.sorted()) }
        } catch {
            let added = attempted.filter { existing[$0] == nil }
            if !added.isEmpty { stop(added) }
            let restore = Set(attempted).union(retireFirst ? retired : [])
            var restoreFailed = false
            for name in restore.sorted() {
                guard let schedule = existing[name] else { continue }
                do { try start(name, schedule) } catch { restoreFailed = true }
            }
            if restoreFailed { throw ConversationAccessError.storageUnavailable }
            throw error
        }
    }
}
