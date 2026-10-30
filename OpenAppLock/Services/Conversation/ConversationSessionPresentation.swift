import ActivityKit
import Foundation
import UserNotifications

nonisolated struct ConversationPresentedUnlock: Equatable, Sendable {
    let plan: ConversationUnlockPlan
    let appID: UUID?
    let appName: String
}

/// Presentation is advisory and starts only for a published, durable grant.
/// Revalidate after notification awaits so ending cannot leave late-added alerts.
/// Native date text advances while suspended; enforcement never depends on it.
/// Only activity IDs cross to async SDK cleanup; non-Sendable Activity handles
/// are looked up and consumed together on that executor.
actor ConversationSessionPresentation {
    static let shared = ConversationSessionPresentation()
    private var revision = UUID()
    private var endedIDs = Set<UUID>()

    func end(_ id: UUID) async {
        endedIDs.insert(id)
        ConversationUnlockNotifications.cancel(grantIDs: [id])
        let activityIDs = Activity<ConversationUnlockActivityAttributes>.activities.filter { $0.attributes.grantID == id }.map(\.id)
        for activityID in activityIDs {
            await Self.endActivity(activityID)
        }
    }

    func sync(_ unlocks: [ConversationPresentedUnlock], store: ConversationGrantStore) async {
        let version = UUID(); revision = version
        let now = Date()
        let desired = unlocks.filter { !$0.plan.hasExpired(at: now) }
        let desiredIDs = Set(desired.map(\.plan.grantID))
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard revision == version else { return }
        let pending = await center.pendingNotificationRequests()
        let delivered = await center.deliveredNotifications()
        guard revision == version else { return }
        let allowed = Set(desired.flatMap { ConversationReminderPlan.identifiers(for: $0.plan.grantID) })
        center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix("unlock-reminder-") && !allowed.contains($0) })
        center.removeDeliveredNotifications(withIdentifiers: delivered.map(\.request.identifier).filter { $0.hasPrefix("unlock-reminder-") && !allowed.contains($0) })
        let existing = Set(pending.map(\.identifier) + delivered.map(\.request.identifier))
        let canNotify = [.authorized, .provisional, .ephemeral].contains(settings.authorizationStatus)
        for unlock in desired {
            guard revision == version, active(unlock.plan.grantID, in: store) else { continue }
            if canNotify {
                for alert in ConversationReminderPlan.alerts(for: unlock.plan, now: .now) where !existing.contains(alert.identifier) {
                    guard revision == version, active(unlock.plan.grantID, in: store) else { break }
                    do { try await center.add(ConversationUnlockNotifications.request(alert, appName: unlock.appName, appID: unlock.appID, now: .now)) }
                    catch { ConversationDiagnostics.live.log("reminder.schedule_failed") }
                    if !active(unlock.plan.grantID, in: store) { ConversationUnlockNotifications.cancel(grantIDs: [unlock.plan.grantID]) }
                }
            }
        }
        guard revision == version else { return }
        let staleActivityIDs = Activity<ConversationUnlockActivityAttributes>.activities.filter {
            !desiredIDs.contains($0.attributes.grantID) || !active($0.attributes.grantID, in: store)
        }.map(\.id)
        for activityID in staleActivityIDs {
            await Self.endActivity(activityID)
        }
        guard revision == version, ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        for unlock in desired where active(unlock.plan.grantID, in: store) {
            guard revision == version else { return }
            guard !Activity<ConversationUnlockActivityAttributes>.activities.contains(where: { $0.attributes.grantID == unlock.plan.grantID }) else { continue }
            let attributes = ConversationUnlockActivityAttributes(grantID: unlock.plan.grantID, appName: unlock.appName, appID: unlock.appID)
            do {
                let activity = try Activity.request(attributes: attributes,
                    content: ActivityContent(state: .init(start: unlock.plan.start, expiresAt: unlock.plan.expiresAt), staleDate: unlock.plan.expiresAt), pushType: nil)
                if !active(unlock.plan.grantID, in: store) { await Self.endActivity(activity.id) }
            } catch { ConversationDiagnostics.live.log("live_activity.unavailable") }
        }
    }
    nonisolated private static func endActivity(_ id: String) async {
        guard let activity = Activity<ConversationUnlockActivityAttributes>.activities.first(where: { $0.id == id }) else { return }
        await activity.end(nil, dismissalPolicy: .immediate)
    }
    func active(_ id: UUID, in store: ConversationGrantStore) -> Bool {
        guard !endedIDs.contains(id) else { return false }
        return (try? store.transaction { state in
            state.activeGrants.contains { $0.plan.grantID == id && !$0.plan.hasExpired(at: .now) && ConversationGrantStore.isValid($0, in: state.snapshots) }
        }) == true
    }
}
