import Foundation
import Observation
import SwiftData

/// Owns startup and refresh. A failed fetch is never an empty configuration;
/// only a successful load may remove restrictions or replace the last mirror.
@Observable
final class AppLifecycleController {
    private(set) var prepared = false
    var needsSetup = false
    private(set) var preparationError = false
    private(set) var health: EnforcementHealth = .healthy
    private(set) var lastValidSnapshots: [RuleSnapshotDTO]?

    func start(context: ModelContext, settings: AppSettingsStore, enforcer: RuleEnforcer,
               conversation: ConversationCoordinator, consumeRequests: Bool) async {
        do {
            preparationError = false
            #if DEBUG
            if !LaunchConfiguration.current.isUITesting { try ConversationTimerProbe.reset() }
            #endif
            try VolitionApps.prepare(in: context)
            settings.uninstallProtectionEnabled = false
            settings.notifyScheduleStartEnabled = false
            settings.notifyTimeLimitEndingEnabled = false
            let rules = try context.fetch(FetchDescriptor<BlockingRule>())
            needsSetup = !rules.contains { $0.kind == .conversation && $0.isEnabled }
            await reconcile(load: { rules }, enforcer: enforcer, conversation: conversation, consumeRequests: consumeRequests)
            prepared = true
        } catch { preparationError = true; health = .failed }
    }

    func resumeSetupForShieldRequest(_ conversation: ConversationCoordinator, snapshots: [RuleSnapshotDTO]) {
        guard needsSetup, conversation.isForeground, conversation.routedRequestID != nil,
              let id = conversation.selectedAppID,
              snapshots.contains(where: { $0.id == id && $0.isEnabled && $0.kind == .conversation }) else { return }
        needsSetup = false
        conversation.selectedSection = .chat
    }

    func reconcile(load: () throws -> [BlockingRule], enforcer: RuleEnforcer,
                   conversation: ConversationCoordinator?, consumeRequests: Bool = true) async {
        do {
            let rules = try load()
            let snapshots = rules.map(\.dto)
            await enforcer.refresh(rules: rules)
            lastValidSnapshots = snapshots
            health = enforcer.health
            await conversation?.refresh(snapshots: snapshots, consumeRequests: consumeRequests)
            if consumeRequests, let conversation { resumeSetupForShieldRequest(conversation, snapshots: snapshots) }
        } catch {
            health = .failed
            Diag.error(.enforcer, "refresh fetch failed; preserving configured restrictions")
        }
    }
}
