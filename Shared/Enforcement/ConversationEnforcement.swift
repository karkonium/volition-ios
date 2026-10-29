import DeviceActivity
import FamilyControls
import ManagedSettings
import Foundation

/// Conversation shields subtract all independently approved apps, preserving separate
/// stores owned by other rule kinds. Every mutation uses the shared file lock;
/// stale responses/callbacks cannot clear a replacement grant. Short background
/// expiry still requires physical-device verification (see timer probe).
nonisolated struct ConversationEnforcement {
    let store: ConversationGrantStore
    let shields: any ShieldApplying

    func sync(_ snapshots: [RuleSnapshotDTO], now: Date = .now) throws -> Set<UUID> {
        try store.transaction { state in
            // Detached foreground operations can arrive out of order. Never
            // replace a newer mirror with an older captured rule configuration.
            if let synced = state.syncedAt, now < synced { return reconcile(&state, now: .now) }
            let old = state.snapshots
            state.snapshots = snapshots
            state.syncedAt = now
            let invalid = state.activeGrants.filter {
                $0.plan.hasExpired(at: now) || $0.fingerprint != ConversationGrantStore.fingerprint(snapshots)
            }
            state.activeGrants.removeAll { grant in invalid.contains { $0.plan.grantID == grant.plan.grantID } }
            for grant in invalid { DeviceActivityCenter().stopMonitoring([DeviceActivityName(grant.plan.activityName)]) }
            for removed in old where removed.kind == .conversation && !snapshots.contains(where: { $0.id == removed.id }) {
                shields.clearShield(ruleID: removed.id)
            }
            return reconcile(&state, now: now)
        }
    }

    /// Register first, durably save second, then reconcile under a second lock.
    /// All covering stores are reconciled and checked before approval returns.
    /// A remaining configured blocker revokes the grant and stops its timer.
    /// Readback is configuration evidence, not proof of the OS-visible screen.
    func approve(token: ApplicationToken, minutes: Int, fingerprint: String,
                 now: Date = .now, timer: any ConversationTimerScheduling = DeviceConversationTimer(),
                 blockMinutes: Int? = nil, overridingDealID: UUID? = nil) throws -> ConversationGrantStore.Grant {
        if let blockMinutes, !(1...1440).contains(blockMinutes) { throw ConversationUnlockPlan.ValidationError.invalidDuration }
        let plan = try ConversationUnlockPlan(grantID: UUID(), minutes: minutes,
            start: Date(timeIntervalSince1970: floor(now.timeIntervalSince1970)))
        do {
            try store.transaction { state in
                guard !state.activeGrants.contains(where: { $0.token == token && !$0.plan.hasExpired(at: now) }) else { throw ConversationAccessError.alreadyUnlocked }
                let commitment = state.dealCommitments.firstIndex { $0.token == token && $0.isBlocking(at: now) }
                if let commitment {
                    let deal = state.dealCommitments[commitment]
                    guard overridingDealID == deal.grantID, (deal.pushbackCount ?? 0) >= 2,
                          !Self.lastResolvedDealWasBroken(state, at: now) else { throw ConversationAccessError.waiting }
                } else if overridingDealID != nil { throw ConversationAccessError.staleRequest }
                guard fingerprint == ConversationGrantStore.fingerprint(state.snapshots) else { throw ConversationAccessError.staleRequest }
                guard !ConversationGrantStore.applicable(to: token, in: state.snapshots).isEmpty else { throw ConversationAccessError.noApplicableRule }
                let expired = state.activeGrants.filter { $0.plan.hasExpired(at: now) }
                for previous in expired { timer.stop(previous.plan.activityName) }
                state.activeGrants.removeAll { $0.plan.hasExpired(at: now) }
                try timer.start(plan)
                state.activeGrants.append(.init(plan: plan, token: token, fingerprint: fingerprint))
                if let commitment {
                    state.dealCommitments[commitment].overriddenAt = now
                    state.dealCommitments[commitment].overrideGrantID = plan.grantID
                }
                if let blockMinutes {
                    state.dealCommitments.append(.init(grantID: plan.grantID, token: token,
                        blockedUntil: plan.expiresAt.addingTimeInterval(Double(blockMinutes * 60))))
                }
            }
        } catch {
            timer.stop(plan.activityName)
            throw error
        }
        do {
            return try store.transaction { state in
                guard let grant = state.activeGrants.first(where: { $0.plan.grantID == plan.grantID }),
                      grant.fingerprint == ConversationGrantStore.fingerprint(state.snapshots),
                      !plan.hasExpired(at: .now) else { throw ConversationAccessError.staleRequest }
                // Retired/removed rules must not keep an independent restriction.
                let enabled = Set(state.snapshots.filter(\.isEnabled).map(\.id))
                for snapshot in state.snapshots where !snapshot.isEnabled { shields.clearShield(ruleID: snapshot.id) }
                shields.clearShields(except: enabled)
                _ = apply(state, now: .now)
                let blockers = shields.blockingRuleIDs(for: token, among: Set(state.snapshots.map(\.id)))
                Diag.log(.conversation, .event, "///CONVO-LOG grant.shields_checked id=\(plan.grantID.logTag) configured_blockers=\(blockers.count)")
                guard blockers.isEmpty else { throw ConversationAccessError.shieldReleaseFailed }
                return grant
            }
        } catch {
            // A saved timer alone is not a successful unlock. Revoke and re-shield
            // before surfacing the failure; do not let it consume a grant record.
            try? end(grantID: plan.grantID, cancelDeal: true)
            timer.stop(plan.activityName)
            throw error
        }
    }

    /// Shared exception eligibility cannot be reset by deleting the transcript.
    static func lastResolvedDealWasBroken(_ state: ConversationGrantStore.State, at now: Date) -> Bool {
        state.dealCommitments.filter { $0.resolutionDate <= now }
            .max { $0.resolutionDate < $1.resolutionDate }?.overriddenAt != nil
    }

    func recordDealPushback(token: ApplicationToken, now: Date = .now) throws {
        try store.transaction { state in
            guard !state.activeGrants.contains(where: { $0.token == token && !$0.plan.hasExpired(at: now) }),
                  let index = state.dealCommitments.firstIndex(where: { $0.token == token && $0.isBlocking(at: now) }) else { return }
            state.dealCommitments[index].pushbackCount = min(1000, (state.dealCommitments[index].pushbackCount ?? 0) + 1)
        }
    }

    /// User ending preserves accepted terms. Rollback alone cancels the new deal.
    /// Commit re-blocking before slow monitor IPC, which never holds the file lock.
    func end(grantID: UUID? = nil, now: Date = .now, cancelDeal: Bool = false) throws {
        let names = try store.transaction { state in
            let ended = state.activeGrants.filter { grantID == nil || $0.plan.grantID == grantID }
            state.activeGrants.removeAll { grantID == nil || $0.plan.grantID == grantID }
            if cancelDeal {
                state.dealCommitments.removeAll { grantID == nil || $0.grantID == grantID }
                for index in state.dealCommitments.indices where state.dealCommitments[index].overrideGrantID == grantID {
                    state.dealCommitments[index].overriddenAt = nil
                    state.dealCommitments[index].overrideGrantID = nil
                }
            }
            _ = apply(state, now: now)
            return ended.map(\.plan.activityName)
        }
        ConversationUnlockNotifications.cancel(grantIDs: names.compactMap(ConversationUnlockPlan.grantID))
        if !names.isEmpty { DeviceActivityCenter().stopMonitoring(names.map { DeviceActivityName($0) }) }
    }

    func expire(activity: String, now: Date = .now) {
        do {
            let expired: ConversationGrantStore.Grant? = try store.transaction { state in
                guard let grant = state.activeGrants.first(where: { $0.plan.activityName == activity }),
                      grant.plan.hasExpired(at: now) else { return nil }
                state.activeGrants.removeAll { $0.plan.grantID == grant.plan.grantID }
                _ = apply(state, now: now)
                return grant
            }
            guard let expired else { return }
            ConversationUnlockNotifications.cancel(grantIDs: [expired.plan.grantID])
            Diag.log(.session, .event, "conversation grant expired id=\(expired.plan.grantID)")
            DeviceActivityCenter().stopMonitoring([DeviceActivityName(activity)])
        } catch { Diag.error(.monitor, "conversation expiry storage failed") }
    }

    /// Re-check stored grants after foreground/storage recovery. A later failed
    /// shield write must not leave a valid-looking timer in the shared state.
    private func reconcile(_ state: inout ConversationGrantStore.State, now: Date) -> Set<UUID> {
        let enabled = Set(state.snapshots.filter(\.isEnabled).map(\.id))
        for snapshot in state.snapshots where !snapshot.isEnabled { shields.clearShield(ruleID: snapshot.id) }
        shields.clearShields(except: enabled)
        let blocking = apply(state, now: now)
        let blockedGrants = state.activeGrants.filter { grant in
            !grant.plan.hasExpired(at: now) && !shields.blockingRuleIDs(for: grant.token, among: Set(state.snapshots.map(\.id))).isEmpty
        }
        guard !blockedGrants.isEmpty else { return blocking }
        for grant in blockedGrants {
            Diag.log(.conversation, .error, "///CONVO-LOG grant.revoked id=\(grant.plan.grantID.logTag) configured_blocker")
            DeviceActivityCenter().stopMonitoring([DeviceActivityName(grant.plan.activityName)])
        }
        state.activeGrants.removeAll { grant in blockedGrants.contains { $0.plan.grantID == grant.plan.grantID } }
        return apply(state, now: now)
    }

    private func apply(_ state: ConversationGrantStore.State, now: Date) -> Set<UUID> {
        let valid = state.activeGrants.filter { grant in
            !grant.plan.hasExpired(at: now) && grant.fingerprint == ConversationGrantStore.fingerprint(state.snapshots) &&
            !state.dealCommitments.contains { $0.token == grant.token && $0.grantID != grant.plan.grantID && $0.isBlocking(at: now) }
        }
        var blocking: Set<UUID> = []
        for snapshot in state.snapshots where snapshot.kind == .conversation {
            guard snapshot.isEnabled else { shields.clearShield(ruleID: snapshot.id); continue }
            var selection = AppSelectionCodec.decode(snapshot.selectionData)
            // Conversation rules never grant category/domain exceptions. Any
            // categories introduced through a shared list remain fully blocked.
            selection.applicationTokens.subtract(valid.map(\.token))
            if AppSelectionCodec.count(of: selection) == 0 { shields.clearShield(ruleID: snapshot.id) }
            else {
                shields.applyShield(ruleID: snapshot.id, selectionData: AppSelectionCodec.encode(selection), mode: .block)
                blocking.insert(snapshot.id)
            }
        }
        return blocking
    }
}

nonisolated protocol ConversationTimerScheduling: Sendable {
    func start(_ plan: ConversationUnlockPlan) throws
    func stop(_ name: String)
}

nonisolated struct DeviceConversationTimer: ConversationTimerScheduling {
    func start(_ plan: ConversationUnlockPlan) throws {
        let center = DeviceActivityCenter()
        // Registration is authoritative: never evict another rule to make space.
        guard center.activities.count < 20 else { throw ConversationAccessError.monitoringUnavailable }
        let parts: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        let schedule = DeviceActivitySchedule(
            intervalStart: Calendar.current.dateComponents(parts, from: plan.start),
            intervalEnd: Calendar.current.dateComponents(parts, from: plan.monitoringEndsAt),
            repeats: false, warningTime: DateComponents(minute: plan.warningMinutes))
        try center.startMonitoring(DeviceActivityName(plan.activityName), during: schedule)
    }
    func stop(_ name: String) { DeviceActivityCenter().stopMonitoring([DeviceActivityName(name)]) }
}
