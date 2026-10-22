import Foundation
import Testing
@testable import OpenAppLock

@Suite struct ConversationActivityTests {
    @Test func summaryCountsActualGrantsAcrossAppsAndRespectsTime() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let app = UUID(), other = UUID()
        func event(minutesAgo: Double, appID: UUID, granted: Bool = true) -> ConversationAccessEvent {
            let start = now.addingTimeInterval(-minutesAgo * 60)
            return .init(date: start, appID: appID, appName: "App", reason: "Task", decision: granted ? .approve : .deny,
                reply: "Reply", grantID: granted ? UUID() : nil, expiresAt: granted ? start.addingTimeInterval(120) : nil)
        }
        let summary = ConversationActivitySummary(events: [event(minutesAgo: 5, appID: app),
            event(minutesAgo: 20, appID: other), event(minutesAgo: 45, appID: app),
            event(minutesAgo: 90, appID: app), event(minutesAgo: 1, appID: app, granted: false),
            event(minutesAgo: -5, appID: app)], appID: app, now: now)
        #expect(summary.grantsLast30Minutes == 2)
        #expect(summary.grantsLastHour == 3)
        #expect(summary.sameAppGrantsLastHour == 2)
        #expect(summary.grantedMinutesLastHour == 6)
        #expect(summary.minutesSinceLastGrantEnded == 3)
        #expect(summary.denialsLastHour == 1)
    }
}
