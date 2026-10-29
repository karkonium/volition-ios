import Foundation
import SwiftData
import Testing
@testable import OpenAppLock

@MainActor
@Suite("Volition expansion", .serialized)
struct VolitionExpansionTests {
    @Test("Failed fetch does not become an empty successful configuration")
    func failedFetchPreservesConfiguration() async throws {
        let enforcer = RuleEnforcer(shields: MockShieldController())
        let controller = AppLifecycleController()
        await controller.reconcile(load: { throw CocoaError(.fileReadCorruptFile) }, enforcer: enforcer, conversation: nil)
        #expect(controller.health == .failed)
        #expect(controller.lastValidSnapshots == nil)
    }

    @Test("Focus uses the starting weekday for overnight windows")
    func overnightFocus() {
        let period = FocusPeriod(name: "Sleep", appIDs: [], weekdays: [2], startMinutes: 22 * 60, endMinutes: 6 * 60)
        #expect(period.isActive(at: date(2025, 1, 7, 1), calendar: utc))
        #expect(!period.isActive(at: date(2025, 1, 7, 7), calendar: utc))
        #expect(!period.isActive(at: date(2025, 1, 6, 1), calendar: utc))
        #expect(period.isValid)
        #expect(!FocusPeriod(name: "Short", appIDs: [], weekdays: [2], startMinutes: 600, endMinutes: 605).isValid)
    }

    @Test("Overlapping protection preserves the stricter active period")
    func focusOverlap() {
        let app = UUID(), other = UUID()
        var state = FocusProtectionState()
        state.periods = [FocusPeriod(name: "Morning", appIDs: [app], weekdays: [2], startMinutes: 9 * 60, endMinutes: 11 * 60)]
        state.session = FocusSession(appIDs: [], start: date(2025, 1, 6, 9), minutes: 25)
        #expect(state.protects(appID: other, at: date(2025, 1, 6, 9, 10), calendar: utc))
        state.session = nil
        #expect(state.protects(appID: app, at: date(2025, 1, 6, 10), calendar: utc))
        #expect(!state.protects(appID: other, at: date(2025, 1, 6, 10), calendar: utc))
    }

    @Test("Access insights count actual outcomes and opportunities, never failed model approvals")
    func insightsUseActualOutcomes() {
        var grant = ConversationActivityEntry(date: date(2025, 1, 6, 10), appID: UUID(), appName: "Maps", message: "Directions", outcome: .unlocked)
        grant.grantID = UUID(); grant.unlockMinutes = 5; grant.unlockUntil = date(2025, 1, 6, 10, 5)
        grant.endedAt = date(2025, 1, 6, 10, 2)
        let failed = ConversationActivityEntry(date: grant.date, message: "Again", outcome: .failed, modelDecision: .approve)
        let summary = AccessInsights(entries: [grant, failed], start: date(2025, 1, 6), end: date(2025, 1, 7))
        #expect(summary.requests == 2)
        #expect(summary.grants == 1)
        #expect(summary.grantedMinutes == 5)
        #expect(summary.earlyEndings == 1)
    }

    @Test("Local focus boundaries survive spring and autumn daylight-saving changes")
    func focusDST() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Toronto"))
        let period = FocusPeriod(name: "Sunday", appIDs: [], weekdays: [1], startMinutes: 60, endMinutes: 4 * 60)
        func local(_ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
            calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
        }
        #expect(period.isActive(at: local(3, 8, 3, 15), calendar: calendar))
        #expect(!period.isActive(at: local(3, 8, 4, 0), calendar: calendar))
        #expect(period.isActive(at: local(11, 1, 2, 30), calendar: calendar))
        #expect(!period.isActive(at: local(11, 1, 4, 0), calendar: calendar))
    }

    @Test("Focus state survives reload and stale callbacks cannot replace a newer session")
    func persistedFocus() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let store = FocusStore(fileURL: url)
        var state = FocusProtectionState()
        let old = FocusSession(appIDs: [], start: .now, minutes: 15)
        state.session = old; try store.save(state)
        let newer = FocusSession(appIDs: [], start: .now, minutes: 25)
        state.session = newer; try store.save(state)
        #expect(try store.load().session?.id == newer.id)
        #expect(old.activityName != newer.activityName)
    }

    @Test("Monitoring capacity never steals another active registration")
    func capacity() throws {
        let existing = (0..<20).map(String.init)
        try MonitoringCapacity.validate(existing: existing, adding: ["0"])
        #expect(throws: ConversationAccessError.monitoringUnavailable) {
            try MonitoringCapacity.validate(existing: existing, adding: ["new"])
        }
    }
}
