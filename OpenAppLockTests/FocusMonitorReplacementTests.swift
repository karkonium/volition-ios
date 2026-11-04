import DeviceActivity
import Foundation
import Testing
@testable import OpenAppLock

@Suite struct FocusMonitorReplacementTests {
    private func schedule(_ hour: Int) -> DeviceActivitySchedule {
        .init(intervalStart: DateComponents(hour: hour), intervalEnd: DateComponents(hour: hour + 1), repeats: true)
    }
    @Test func replacesAtCapacityWithoutEvictingGrants() throws {
        var registered = Dictionary(uniqueKeysWithValues: (0..<19).map { ("grant-\($0)", schedule(9)) })
        registered["focus-old"] = schedule(10)
        let original = registered
        var stopped: [String] = []
        try FocusMonitorReplacement.apply(existing: original, occupied: Set(original.keys), desired: ["focus-new": schedule(11)], start: { name, schedule in
            #expect(registered.count < 20)
            registered[name] = schedule
        }, stop: { names in
            stopped += names
            for name in names { registered[name] = nil }
        })
        #expect(registered.count == 20)
        #expect(registered["focus-new"] == schedule(11))
        #expect(stopped == ["focus-old"])
        for index in 0..<19 { #expect(registered["grant-\(index)"] != nil) }
    }
    @Test func failedReplacementRestoresPreviousSchedule() throws {
        var registered = Dictionary(uniqueKeysWithValues: (0..<19).map { ("grant-\($0)", schedule(9)) })
        registered["focus-old"] = schedule(10)
        let original = registered
        #expect(throws: (any Error).self) {
            try FocusMonitorReplacement.apply(existing: original, occupied: Set(original.keys), desired: ["focus-new": schedule(11)], start: { name, schedule in
                if name == "focus-new" { throw ConversationAccessError.monitoringUnavailable }
                registered[name] = schedule
            }, stop: { names in for name in names { registered[name] = nil } })
        }
        #expect(registered == original)
    }
    @Test func unchangedPlanNeverRequestsAnEmptyStop() throws {
        let existing = ["focus-current": schedule(9), "grant-live": schedule(10)]
        try FocusMonitorReplacement.apply(existing: existing, occupied: Set(existing.keys), desired: ["focus-current": schedule(9)],
            start: { _, _ in Issue.record("Unchanged monitor must not restart") },
            stop: { _ in Issue.record("No stale monitor means no stop call; an empty OS stop would cancel every timer") })
    }
    @Test func excessCapacityDoesNotMutateAnyRegistration() {
        let original = Dictionary(uniqueKeysWithValues: (0..<20).map { ("grant-\($0)", schedule(9)) })
        var touched = false
        #expect(throws: (any Error).self) {
            try FocusMonitorReplacement.apply(existing: original, occupied: Set(original.keys), desired: ["focus-new": schedule(11)], start: { _, _ in touched = true }, stop: { _ in touched = true })
        }
        #expect(!touched)
    }
}

@MainActor @Suite struct FocusCommitRecoveryTests {
    @Test func failedGrantCommitRestoresFocusPolicyAndMonitoring() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("access.json")
        let access = ConversationEnforcement(store: .init(fileURL: url), shields: MockShieldController())
        var original = FocusProtectionState()
        original.periods = [.init(name: "Original", appIDs: [], weekdays: [2], startMinutes: 540, endMinutes: 600)]
        let monitor = AuditFocusMonitor()
        try access.updateFocus(original, monitor: monitor)
        let mirror = url.appendingPathExtension("configuration")
        try FileManager.default.removeItem(at: mirror)
        try FileManager.default.createDirectory(at: mirror, withIntermediateDirectories: true)
        var replacement = original
        replacement.periods[0].startMinutes = 510
        #expect(throws: (any Error).self) { try access.updateFocus(replacement, monitor: monitor) }
        #expect(try access.focusStore.load() == original)
        #expect(monitor.latest == original)
    }
}
nonisolated private final class AuditFocusMonitor: FocusMonitoring, @unchecked Sendable {
    private let lock = NSLock()
    private var stored = FocusProtectionState()
    var latest: FocusProtectionState { lock.lock(); defer { lock.unlock() }; return stored }
    func register(_ state: FocusProtectionState, now: Date) throws { lock.lock(); defer { lock.unlock() }; stored = state }
    func keepOnly(_ names: Set<String>) {}
}
