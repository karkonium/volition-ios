import ActivityKit
import FamilyControls
import Foundation

/// The intent host uses the same native command path as the Expo bridge.
public nonisolated enum FocusSystemActions {
    public enum Failure: Error {
        case permission, configure, unavailable
    }

    public static func start() async throws -> Date {
        guard isAuthorized else { throw Failure.permission }
        let enforcement = service
        do {
            try enforcement.mutateFocus(FocusCommand(kind: .startSession))
            guard let end = try enforcement.store.transaction({ $0.focus?.session?.expiresAt }) else {
                throw Failure.unavailable
            }
            await endRevokedActivities(store: enforcement.store)
            return end
        } catch ConversationAccessError.focusNeedsApps { throw Failure.configure } catch { throw Failure.unavailable }
    }

    public static func end() async throws {
        guard isAuthorized else { throw Failure.permission }
        do {
            let enforcement = service
            try enforcement.mutateFocus(FocusCommand(kind: .endSession))
            await endRevokedActivities(store: enforcement.store)
        } catch { throw Failure.unavailable }
    }

    private static var isAuthorized: Bool {
        let status = AuthorizationCenter.shared.authorizationStatus
        if #available(iOS 26.4, *), status == .approvedWithDataAccess { return true }
        return status == .approved
    }

    private static var service: ConversationEnforcement {
        ConversationEnforcement(store: ConversationGrantStore(), shields: ManagedSettingsShieldController())
    }

    private static func endRevokedActivities(store: ConversationGrantStore) async {
        guard let ids = try? store.transaction({ Set($0.activeGrants.map(\.plan.grantID)) }) else { return }
        for activity in Activity<ConversationUnlockActivityAttributes>.activities
        where !ids.contains(activity.attributes.grantID) {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
