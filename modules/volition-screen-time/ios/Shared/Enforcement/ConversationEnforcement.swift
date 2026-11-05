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
    var currentTime: @Sendable () -> Date = { .now }
    func mutateFocus(
        _ command: FocusCommand, monitor: any FocusMonitoring = DeviceFocusMonitor(), now: Date = .now
    ) throws {
        // Serialize registration and cleanup between the app and Shortcuts.
        // DeviceActivity IPC stays outside the grant lock: starting or stopping
        // an activity may cause the monitor extension to reconcile immediately.
        try withFocusMonitorLock {
            let (previous, apps) = try store.transaction { state in
                (state.focus ?? FocusProtectionState(), state.focusAppIDs)
            }
            var next = previous
            try command.apply(to: &next, apps: apps, now: now)
            guard next != previous else { return }
            next.revision = (previous.revision ?? 0) + 1
            monitor.keepOnly(previous.activityNames(at: now))
            do {
                try monitor.register(next, now: now, reservingSlots: command.kind == .saveRoutine)
                try withRevokedGrantCleanup { state in
                    guard state.focus == previous, state.focusAppIDs == apps else {
                        throw ConversationAccessError.staleRequest
                    }
                    // An edit or exception after a cutoff cannot restore the old grant.
                    state.activeGrants.removeAll { $0.hasExpired(at: now) }
                    state.focus = next
                    refreshFocusGrants(&state, now: currentTime())
                }
            } catch {
                monitor.keepOnly(previous.activityNames(at: now))
                throw error
            }
            monitor.keepOnly(next.activityNames(at: currentTime()))
            reconcileStored()
        }
    }

    func repairFocusMonitoring(monitor: any FocusMonitoring = DeviceFocusMonitor(), now: Date = .now) throws {
        try withFocusMonitorLock {
            let focus = try store.transaction { $0.focus ?? FocusProtectionState() }
            monitor.keepOnly(focus.activityNames(at: now))
            try monitor.register(focus, now: now, reservingSlots: false)
        }
    }

    private func withFocusMonitorLock(_ body: () throws -> Void) throws {
        guard let url = store.fileURL?.appendingPathExtension("focus-monitor-lock") else {
            throw ConversationAccessError.storageUnavailable
        }
        var coordinationError: NSError?
        var result: Result<Void, Error>?
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forMerging, error: &coordinationError) { _ in
            result = Result { try body() }
        }
        if let coordinationError { throw coordinationError }
        guard let result else { throw ConversationAccessError.storageUnavailable }
        try result.get()
    }

    private func refreshFocusGrants(_ state: inout ConversationGrantStore.State, now: Date) {
        guard let focus = state.focus else { state.activeGrants = []; return }
        let occurrences = focus.occurrences(at: now, apps: state.focusAppIDs)
        state.activeGrants = state.activeGrants.compactMap { grant in
            guard !grant.hasExpired(at: now) else { return nil }
            let ids = ConversationGrantStore.applicable(to: grant.token, in: state.snapshots).map(\.id)
            guard !occurrences.active.contains(where: { reason in ids.contains(where: reason.protects) })
            else { return nil }
            var updated = grant
            let next = occurrences.upcoming.first { reason in ids.contains(where: reason.protects) }?.startsAt
            updated.focusCutoff = next.flatMap { $0 < grant.plan.expiresAt ? $0 : nil }
            return updated
        }
    }

    func reconcileStored(now: Date = .now) {
        do {
            try withRevokedGrantCleanup { state in
                refreshFocusGrants(&state, now: now)
                _ = reconcile(&state, now: now)
            }
        } catch { try? restoreProtection() }
    }

    private func validateFocus(
        for token: ApplicationToken, through end: Date, in state: ConversationGrantStore.State, now: Date
    ) throws {
        guard let focus = state.focus else { throw ConversationAccessError.storageUnavailable }
        let ids = ConversationGrantStore.applicable(to: token, in: state.snapshots).map(\.id)
        let occurrences = focus.occurrences(at: now, apps: Set(ids))
        if !occurrences.active.isEmpty { throw ConversationAccessError.focusProtected }
        if let next = occurrences.upcoming.first, next.startsAt < end {
            throw ConversationAccessError.focusBoundary
        }
    }

    func sync(_ snapshots: [RuleSnapshotDTO], now: Date = .now) throws -> Set<UUID> {
        try withRevokedGrantCleanup { state in
            // Detached foreground operations can arrive out of order. Never
            // replace a newer mirror with an older captured rule configuration.
            if let synced = state.syncedAt, now < synced { return reconcile(&state, now: currentTime()) }
            let old = state.snapshots
            state.activeGrants = state.activeGrants.map { grant in
                guard grant.configurationFingerprint == nil, ConversationGrantStore.isValid(grant, in: old) else {
                    return grant
                }
                var migrated = grant
                migrated.configurationFingerprint = ConversationGrantStore.configurationFingerprint(
                    for: grant.token, in: old)
                return migrated
            }
            state.snapshots = snapshots
            state.syncedAt = now
            refreshFocusGrants(&state, now: now)
            state.activeGrants.removeAll { !ConversationGrantStore.isValid($0, in: snapshots) }
            for removed in old
            where removed.kind == .conversation && !snapshots.contains(where: { $0.id == removed.id }) {
                shields.clearShield(ruleID: removed.id)
            }
            return reconcile(&state, now: now)
        }
    }

    /// Register first, durably save second, then reconcile under a second lock.
    /// All covering stores are reconciled and checked before approval returns.
    /// A remaining configured blocker revokes the grant and stops its timer.
    /// Readback is configuration evidence, not proof of the OS-visible screen.
    /// Admission is revalidated inside both transactions, including consent
    /// revision checks supplied by alternate application shells.
    /// Explicit coach urgency/frustration relief may waive the exact current deal
    /// without replacement terms; consent/configuration/Focus and release checks remain.
    func approve(
        token: ApplicationToken, minutes: Int, fingerprint: String,
        now: Date = .now, timer: any ConversationTimerScheduling = DeviceConversationTimer(),
        blockMinutes: Int? = nil, overridingDealID: UUID? = nil, immediateRelief: Bool = false,
        activationAllowed: @Sendable () -> Bool = { true }
    ) throws -> ConversationGrantStore.Grant {
        if immediateRelief && blockMinutes != nil { throw ConversationAccessError.staleRequest }
        if let blockMinutes, !(1...1440).contains(blockMinutes) {
            throw ConversationUnlockPlan.ValidationError.invalidDuration
        }
        let plan = try ConversationUnlockPlan(
            grantID: UUID(), minutes: minutes,
            start: Date(timeIntervalSince1970: floor(now.timeIntervalSince1970)))
        do {
            try withRevokedGrantCleanup { state in
                guard activationAllowed() else { throw ConversationAccessError.staleRequest }
                guard !state.activeGrants.contains(where: { $0.token == token && !$0.hasExpired(at: now) }) else {
                    throw ConversationAccessError.alreadyUnlocked
                }
                try validateFocus(for: token, through: plan.expiresAt, in: state, now: currentTime())
                let commitment = state.dealCommitments.firstIndex { $0.token == token && $0.isBlocking(at: now) }
                if let commitment {
                    let deal = state.dealCommitments[commitment]
                    guard overridingDealID == deal.grantID else { throw ConversationAccessError.waiting }
                    if !immediateRelief {
                        guard (deal.pushbackCount ?? 0) >= 2, let blockMinutes,
                            blockMinutes >= Self.minimumReplacementBreakMinutes(for: deal, at: now)
                        else { throw ConversationAccessError.waiting }
                    }
                } else if overridingDealID != nil {
                    throw ConversationAccessError.staleRequest
                }
                guard fingerprint == ConversationGrantStore.fingerprint(state.snapshots) else {
                    throw ConversationAccessError.staleRequest
                }
                guard !ConversationGrantStore.applicable(to: token, in: state.snapshots).isEmpty else {
                    throw ConversationAccessError.noApplicableRule
                }
                state.activeGrants.removeAll { $0.hasExpired(at: now) }
                try timer.start(plan)
                state.activeGrants.append(
                    .init(
                        plan: plan, token: token, fingerprint: fingerprint,
                        configurationFingerprint: ConversationGrantStore.configurationFingerprint(
                            for: token, in: state.snapshots)))
                if let commitment {
                    state.dealCommitments[commitment].overriddenAt = now
                    state.dealCommitments[commitment].overrideGrantID = plan.grantID
                }
                if let blockMinutes {
                    state.dealCommitments.append(
                        .init(
                            grantID: plan.grantID, token: token,
                            blockedUntil: plan.expiresAt.addingTimeInterval(Double(blockMinutes * 60))))
                }
            }
        } catch {
            timer.stop(plan.activityName)
            throw error
        }
        do {
            return try store.transaction { state in
                guard activationAllowed() else { throw ConversationAccessError.staleRequest }
                guard let grant = state.activeGrants.first(where: { $0.plan.grantID == plan.grantID }),
                    ConversationGrantStore.isValid(grant, in: state.snapshots),
                    !plan.hasExpired(at: currentTime())
                else { throw ConversationAccessError.staleRequest }
                try validateFocus(for: token, through: plan.expiresAt, in: state, now: currentTime())
                // Retired/removed rules must not keep an independent restriction.
                let enabled = Set(state.snapshots.filter(\.isEnabled).map(\.id))
                for snapshot in state.snapshots where !snapshot.isEnabled { shields.clearShield(ruleID: snapshot.id) }
                shields.clearShields(except: enabled)
                _ = apply(state, now: currentTime())
                let blockers = shields.blockingRuleIDs(for: token, among: Set(state.snapshots.map(\.id)))
                Diag.log(
                    .conversation, .event,
                    "///CONVO-LOG grant.shields_checked id=\(plan.grantID.logTag) configured_blockers=\(blockers.count)"
                )
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

    /// Breaking an agreement replaces it atomically with an explicitly accepted,
    /// longer break: remaining time plus 15 minutes, at least 30, at most 24 hours.
    static func minimumReplacementBreakMinutes(for deal: ConversationGrantStore.DealCommitment, at now: Date) -> Int {
        min(1440, max(30, Int(ceil(max(0, deal.blockedUntil.timeIntervalSince(now)) / 60)) + 15))
    }

    /// Shared exception history cannot be reset by deleting the transcript.
    static func lastResolvedDealWasBroken(_ state: ConversationGrantStore.State, at now: Date) -> Bool {
        state.dealCommitments.filter { $0.resolutionDate <= now }
            .max { $0.resolutionDate < $1.resolutionDate }?.overriddenAt != nil
    }

    func recordDealPushback(token: ApplicationToken, now: Date = .now) throws {
        try store.transaction { state in
            guard !state.activeGrants.contains(where: { $0.token == token && !$0.hasExpired(at: now) }),
                let index = state.dealCommitments.firstIndex(where: { $0.token == token && $0.isBlocking(at: now) })
            else { return }
            state.dealCommitments[index].pushbackCount = min(
                1000, (state.dealCommitments[index].pushbackCount ?? 0) + 1)
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
                for index in state.dealCommitments.indices where state.dealCommitments[index].overrideGrantID == grantID
                {
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
                    grant.hasExpired(at: now)
                else { return nil }
                state.activeGrants.removeAll { $0.plan.grantID == grant.plan.grantID }
                _ = apply(state, now: now)
                return grant
            }
            guard let expired else { return }
            ConversationUnlockNotifications.cancel(grantIDs: [expired.plan.grantID])
            Diag.log(.session, .event, "conversation grant expired id=\(expired.plan.grantID)")
            DeviceActivityCenter().stopMonitoring([DeviceActivityName(activity)])
        } catch {
            do {
                try restoreProtection()
                DeviceActivityCenter().stopMonitoring([DeviceActivityName(activity)])
                Diag.error(.monitor, "conversation expiry recovered; grants invalidated")
            } catch { Diag.error(.monitor, "conversation expiry uncertain; configuration recovery unavailable") }
        }
    }

    func restoreProtection(using snapshots: [RuleSnapshotDTO]? = nil) throws {
        try store.recover(fallback: snapshots) { snapshots in
            for snapshot in snapshots where snapshot.kind == .conversation && snapshot.isEnabled {
                shields.applyShield(ruleID: snapshot.id, selectionData: snapshot.selectionData, mode: .block)
            }
        }
    }

    func invalidateGrants() throws {
        try withRevokedGrantCleanup { state in
            state.activeGrants = []
            _ = apply(state, now: currentTime())
        }
    }

    /// Commit revocations before notification/monitor IPC. Cleanup is per grant,
    /// preserving unrelated apps' reminders and keeping slow IPC outside the lock.
    private func withRevokedGrantCleanup<T>(_ operation: (inout ConversationGrantStore.State) throws -> T) throws -> T {
        var revoked: [ConversationGrantStore.Grant] = []
        let result = try store.transaction { state in
            let previous = state.activeGrants
            let result = try operation(&state)
            let retained = Set(state.activeGrants.map(\.plan.grantID))
            revoked = previous.filter { !retained.contains($0.plan.grantID) }
            return result
        }
        if !revoked.isEmpty {
            ConversationUnlockNotifications.cancel(grantIDs: revoked.map(\.plan.grantID))
            DeviceActivityCenter().stopMonitoring(revoked.map { DeviceActivityName($0.plan.activityName) })
        }
        return result
    }

    /// Re-check stored grants after foreground/storage recovery. A later failed
    /// shield write must not leave a valid-looking timer in the shared state.
    private func reconcile(_ state: inout ConversationGrantStore.State, now: Date) -> Set<UUID> {
        let enabled = Set(state.snapshots.filter(\.isEnabled).map(\.id))
        for snapshot in state.snapshots where !snapshot.isEnabled { shields.clearShield(ruleID: snapshot.id) }
        shields.clearShields(except: enabled)
        let blocking = apply(state, now: now)
        let blockedGrants = state.activeGrants.filter { grant in
            !grant.hasExpired(at: now)
                && !shields.blockingRuleIDs(for: grant.token, among: Set(state.snapshots.map(\.id))).isEmpty
        }
        guard !blockedGrants.isEmpty else { return blocking }
        for grant in blockedGrants {
            Diag.log(
                .conversation, .error, "///CONVO-LOG grant.revoked id=\(grant.plan.grantID.logTag) configured_blocker")
        }
        state.activeGrants.removeAll { grant in blockedGrants.contains { $0.plan.grantID == grant.plan.grantID } }
        return apply(state, now: now)
    }

    private func apply(_ state: ConversationGrantStore.State, now: Date) -> Set<UUID> {
        let activeFocus = state.focus?.occurrences(at: now, apps: state.focusAppIDs, includeUpcoming: false).active
        let valid = state.activeGrants.filter { grant in
            guard let activeFocus else { return false }
            return !grant.hasExpired(at: now) && ConversationGrantStore.isValid(grant, in: state.snapshots)
                && !ConversationGrantStore.applicable(to: grant.token, in: state.snapshots).contains {
                    let appID = $0.id
                    return activeFocus.contains { $0.protects(appID) }
                }
                && !state.dealCommitments.contains {
                    $0.token == grant.token && $0.grantID != grant.plan.grantID && $0.isBlocking(at: now)
                }
        }
        var blocking: Set<UUID> = []
        for snapshot in state.snapshots where snapshot.kind == .conversation {
            guard snapshot.isEnabled else { shields.clearShield(ruleID: snapshot.id); continue }
            var selection = AppSelectionCodec.decode(snapshot.selectionData)
            // Conversation rules never grant category/domain exceptions. Any
            // categories introduced through a shared list remain fully blocked.
            selection.applicationTokens.subtract(valid.map(\.token))
            if AppSelectionCodec.count(of: selection) == 0 {
                shields.clearShield(ruleID: snapshot.id)
            } else {
                shields.applyShield(
                    ruleID: snapshot.id, selectionData: AppSelectionCodec.encode(selection), mode: .block)
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
        try MonitoringCapacity.validate(existing: center.activities.map(\.rawValue), adding: [plan.activityName])
        let parts: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        let schedule = DeviceActivitySchedule(
            intervalStart: Calendar.current.dateComponents(parts, from: plan.start),
            intervalEnd: Calendar.current.dateComponents(parts, from: plan.monitoringEndsAt),
            repeats: false, warningTime: DateComponents(minute: plan.warningMinutes))
        try center.startMonitoring(DeviceActivityName(plan.activityName), during: schedule)
    }
    func stop(_ name: String) { DeviceActivityCenter().stopMonitoring([DeviceActivityName(name)]) }
}
