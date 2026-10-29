import Foundation
import UserNotifications
import Testing
@testable import OpenAppLock

@Suite("Unlock reminders")
struct ConversationReminderTests {
    @Test func threeAlertsShareThreadButNotPendingIdentity() throws {
        let now = Date()
        let plan = try ConversationUnlockPlan(grantID: UUID(), minutes: 30, start: now)
        let alerts = ConversationReminderPlan.alerts(for: plan, now: now)
        #expect(alerts.map(\.secondsRemaining) == [60, 30, 10])
        #expect(Set(alerts.map(\.identifier)).count == 3)
        #expect(Set(alerts.map(\.threadIdentifier)).count == 1)
        #expect(alerts.first?.fireAt == plan.expiresAt.addingTimeInterval(-60))
        #expect(ConversationReminderPlan.alerts(for: plan, now: plan.expiresAt.addingTimeInterval(-20)).map(\.secondsRemaining) == [10])
        #expect(ConversationReminderPlan.alerts(for: plan, now: plan.expiresAt).isEmpty)
    }
    @Test func nativeRequestUsesGrantDeadlineAndCorrectAppLink() throws {
        let start = Date(), appID = UUID()
        let plan = try ConversationUnlockPlan(grantID: UUID(), minutes: 30, start: start)
        let alert = try #require(ConversationReminderPlan.alerts(for: plan, now: start).first)
        let request = ConversationUnlockNotifications.request(alert, appName: "Maps", appID: appID, now: start)
        #expect(request.content.title.contains("Maps"))
        #expect(request.content.threadIdentifier == alert.threadIdentifier)
        #expect((request.trigger as? UNTimeIntervalNotificationTrigger)?.timeInterval == 1740)
        #expect(request.content.url.flatMap(ConversationShieldRequest.appID) == appID)
        let short = try ConversationUnlockPlan(grantID: UUID(), minutes: 1, start: start)
        #expect(ConversationReminderPlan.alerts(for: short, now: start).map(\.secondsRemaining) == [30, 10])
        #expect(Set(ConversationReminderPlan.identifiers(for: short.grantID)).isDisjoint(with: Set(ConversationReminderPlan.identifiers(for: plan.grantID))))
    }

}
