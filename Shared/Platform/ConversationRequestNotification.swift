import Foundation
import UserNotifications

/// Explicit request-access shortcut, independent of retired schedule alerts.
/// Delivery is best-effort; denied/quiet notifications never remove manual access.
nonisolated enum ConversationRequestNotification {
    static func send(_ request: ConversationShieldRequest) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard [.authorized, .provisional, .ephemeral].contains(settings.authorizationStatus) else {
            Diag.log(.session, "conversation notification unavailable; manual opening remains available")
            return
        }
        let pending = await center.pendingNotificationRequests()
        let delivered = await center.deliveredNotifications()
        center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix("conversation-request-") })
        center.removeDeliveredNotifications(withIdentifiers: delivered.map(\.request.identifier).filter { $0.hasPrefix("conversation-request-") })
        let content = UNMutableNotificationContent()
        content.title = CopyKey.conversationChatHere.string
        content.body = CopyKey.conversationNotificationBody.string
        content.sound = .default
        if let url = request.url { content.setURL(url) }
        do {
            try await center.add(UNNotificationRequest(identifier: request.notificationIdentifier, content: content, trigger: nil))
            Diag.log(.session, "conversation notification scheduled request=\(request.id.logTag)")
        } catch { Diag.error(.session, "conversation notification scheduling failed; manual opening remains available") }
    }
}
