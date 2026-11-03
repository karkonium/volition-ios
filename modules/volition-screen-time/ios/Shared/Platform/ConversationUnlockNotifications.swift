import Foundation
import UserNotifications

/// Delivery is best-effort and never authorizes access. Removing one grant's
/// identifiers preserves other apps' warnings and request-access notifications.
nonisolated enum ConversationUnlockNotifications {
    static func request(_ alert: ConversationReminderPlan.Alert, appName: String, appID: UUID?, now: Date) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = CopyKey.unlockReminderTitle.string(appName)
        content.body = alert.secondsRemaining == 60 ? CopyKey.unlockReminderMinute.string : CopyKey.unlockReminderSeconds.string(alert.secondsRemaining)
        content.threadIdentifier = alert.threadIdentifier
        content.sound = .default
        if let appID, let url = URL(string: "openapplock://conversation?app=\(appID.uuidString)") { content.setURL(url) }
        return .init(identifier: alert.identifier, content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(1, alert.fireAt.timeIntervalSince(now)), repeats: false))
    }
    static func cancel(grantIDs: [UUID]) {
        let identifiers = grantIDs.flatMap(ConversationReminderPlan.identifiers)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }
}
