import Foundation
import Testing
@testable import OpenAppLock

@MainActor
@Suite("Conversation unlock timing")
struct ConversationUnlockPlanTests {
    @Test("Short grants use a valid interval with a warning at expiry", arguments: [1, 5, 10])
    func warningAtExpiry(minutes: Int) throws {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let plan = try ConversationUnlockPlan(grantID: UUID(), minutes: minutes, start: start)
        #expect(plan.expiresAt == start.addingTimeInterval(Double(minutes * 60)))
        #expect(plan.monitoringEndsAt.timeIntervalSince(start) == 16 * 60)
        #expect(plan.monitoringEndsAt.addingTimeInterval(-Double(plan.warningMinutes * 60)) == plan.expiresAt)
        #expect(!plan.hasExpired(at: plan.expiresAt.addingTimeInterval(-1)))
        #expect(plan.hasExpired(at: plan.expiresAt))
    }

    @Test("Invalid durations are rejected", arguments: [-1, 0, 11, 60])
    func invalidDuration(minutes: Int) {
        #expect(throws: ConversationUnlockPlan.ValidationError.invalidDuration) {
            try ConversationUnlockPlan(grantID: UUID(), minutes: minutes, start: .now)
        }
    }

    @Test("Grant IDs prevent stale callbacks matching a new unlock")
    func distinctActivities() throws {
        let first = try ConversationUnlockPlan(grantID: UUID(), minutes: 1, start: .now)
        let second = try ConversationUnlockPlan(grantID: UUID(), minutes: 1, start: .now)
        #expect(first.activityName != second.activityName)
        #expect(ConversationUnlockPlan.grantID(from: first.activityName) == first.grantID)
        #expect(ConversationUnlockPlan.grantID(from: "rule-" + first.grantID.uuidString) == nil)
        #expect(ConversationUnlockPlan.grantID(from: "conversation-grant-invalid") == nil)
    }

    @Test("Absolute expiry remains correct across midnight")
    func midnight() throws {
        let start = try #require(ISO8601DateFormatter().date(from: "2026-10-21T23:59:30Z"))
        let plan = try ConversationUnlockPlan(grantID: UUID(), minutes: 1, start: start)
        #expect(plan.expiresAt == start.addingTimeInterval(60))
        let decoded = try JSONDecoder().decode(ConversationUnlockPlan.self, from: JSONEncoder().encode(plan))
        #expect(decoded == plan)
    }
    @Test("Persisted durations are validated on decode")
    func persistedDurationValidation() throws {
        let data = try JSONSerialization.data(withJSONObject: [
            "grantID": UUID().uuidString, "minutes": 999, "start": 0
        ])
        #expect(throws: (any Error).self) { try JSONDecoder().decode(ConversationUnlockPlan.self, from: data) }
    }

}
