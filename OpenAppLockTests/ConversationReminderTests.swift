import FamilyControls
import ManagedSettings
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

    @MainActor @Test("An unrelated app edit preserves a valid live countdown")
    func countdownSurvivesUnrelatedConfiguration() async throws {
        func rule(_ byte: UInt8) throws -> (RuleSnapshotDTO, ApplicationToken) {
            let token = try JSONDecoder().decode(ApplicationToken.self,
                from: JSONSerialization.data(withJSONObject: ["data": Data([byte]).base64EncodedString()]))
            var selection = FamilyActivitySelection(); selection.applicationTokens = [token]
            return (.init(id: UUID(), name: "App", kindRaw: "conversation", isEnabled: true,
                hardMode: false, selectionModeRaw: "block", selectionData: AppSelectionCodec.encode(selection),
                dayNumbers: [], startMinutes: 0, endMinutes: 0, dailyLimitMinutes: 45, maxOpens: 5,
                conversationGoal: "Be intentional"), token)
        }
        let (first, token) = try rule(1), (other, _) = try rule(2)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let access = ConversationEnforcement(store: .init(fileURL: directory.appendingPathComponent("access.json")), shields: MockShieldController())
        _ = try access.sync([first])
        let grant = try access.approve(token: token, minutes: 5, fingerprint: ConversationGrantStore.fingerprint([first]), timer: MockConversationTimer())
        _ = try access.sync([first, other])
        let presenter = ConversationSessionPresentation()
        #expect(await presenter.active(grant.plan.grantID, in: access.store))
        try access.end(grantID: grant.plan.grantID)
        #expect(await presenter.active(grant.plan.grantID, in: access.store) == false)
    }

}
