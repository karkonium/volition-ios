import ActivityKit
import FamilyControls
import Foundation

/// The intent host uses the same native command path as the Expo bridge.
public nonisolated enum FocusSystemActions {
    public enum Failure: Error {
        case permission, configure, unavailable
    }

    public static func start() async throws -> Date {
        let status = AuthorizationCenter.shared.authorizationStatus
        guard status == .approved || status == .approvedWithDataAccess else { throw Failure.permission }
        let enforcement = service
        do {
            try enforcement.mutateFocus(FocusCommand(kind: .startSession))
            guard let end = try enforcement.store.transaction({ $0.focus?.session?.expiresAt }) else {
                throw Failure.unavailable
            }
            await endRevokedActivities(store: enforcement.store)
            return end
        } catch ConversationAccessError.focusNeedsApps { throw Failure.configure }
        catch { throw Failure.unavailable }
    }

    public static func end() throws {
        let status = AuthorizationCenter.shared.authorizationStatus
        guard status == .approved || status == .approvedWithDataAccess else { throw Failure.permission }
        do { try service.mutateFocus(FocusCommand(kind: .endSession)) }
        catch { throw Failure.unavailable }
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
