import FamilyControls
import Foundation
import ManagedSettings
import Testing
@testable import OpenAppLock

@MainActor
@Suite("Conversation individual-app enforcement", .serialized)
struct ConversationAccessTests {
    private func token(_ byte: UInt8) throws -> ApplicationToken {
        // Opaque test tokens exercise set membership only, never OS enforcement.
        try JSONDecoder().decode(ApplicationToken.self, from: JSONSerialization.data(withJSONObject: ["data": Data([byte]).base64EncodedString()]))
    }
    private func makeAccess() throws -> (ConversationEnforcement, MockShieldController) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let shields = MockShieldController()
        return (.init(store: .init(fileURL: directory.appendingPathComponent("access.json")), shields: shields), shields)
    }
    private func snapshot(_ tokens: Set<ApplicationToken>, kind: RuleKind = .conversation) -> RuleSnapshotDTO {
        var selection = FamilyActivitySelection()
        selection.applicationTokens = tokens
        return .init(id: UUID(), name: "Coach", kindRaw: kind.rawValue, isEnabled: true,
            hardMode: false, selectionModeRaw: "block", selectionData: AppSelectionCodec.encode(selection),
            dayNumbers: [], startMinutes: 0, endMinutes: 0, dailyLimitMinutes: 45, maxOpens: 5,
            conversationGoal: "Use intentionally.")
    }

    @Test("Approval fails if the shield backend still reports a blocker")
    func failedReleaseDoesNotGrant() throws {
        let app = try token(1)
        let (normal, _) = try makeAccess()
        let shields = RefusingReleaseShields()
        let access = ConversationEnforcement(store: normal.store, shields: shields)
        let rule = snapshot([app])
        _ = try access.sync([rule])
        #expect(throws: ConversationAccessError.shieldReleaseFailed) {
            try access.approve(token: app, minutes: 1,
                fingerprint: ConversationGrantStore.fingerprint([rule]), timer: MockConversationTimer())
        }
        #expect(try access.store.transaction { $0.grant } == nil)
    }

    @Test("A persisted grant is revoked if reconciliation cannot release its shield")
    func reconciliationRevokesFalseGrant() throws {
        let app = try token(1)
        let (normal, _) = try makeAccess()
        let rule = snapshot([app])
        let access = ConversationEnforcement(store: normal.store, shields: RefusingReleaseShields())
        let plan = try ConversationUnlockPlan(grantID: UUID(), minutes: 5, start: .now)
        try access.store.transaction { state in
            state.snapshots = [rule]
            state.grant = .init(plan: plan, token: app, fingerprint: ConversationGrantStore.fingerprint([rule]))
        }
        _ = try access.sync([rule])
        #expect(try access.store.transaction { $0.grant } == nil)
    }

    @Test("Orphaned registered stores are discovered even if defaults lost their IDs")
    func orphanedStores() {
        let stale = UUID(), active = UUID(), tracked = UUID()
        let result = ShieldStoreInventory.staleRuleIDs(tracked: [tracked],
            registeredNames: ["rule-" + stale.uuidString, "rule-" + active.uuidString, "uninstall-protection", "rule-invalid"],
            keeping: [active])
        #expect(result == [stale, tracked])
    }

    @Test("Two app grants persist independently and expiry only restores its own app")
    func independentGrants() throws {
        let app = try token(1), other = try token(2)
        let (access, shields) = try makeAccess()
        let first = snapshot([app]), second = snapshot([other])
        let rules = [first, second]
        _ = try access.sync(rules)
        let fingerprint = ConversationGrantStore.fingerprint(rules)
        let one = try access.approve(token: app, minutes: 1, fingerprint: fingerprint, timer: MockConversationTimer())
        let two = try access.approve(token: other, minutes: 5, fingerprint: fingerprint, timer: MockConversationTimer())
        #expect(try access.store.transaction { $0.activeGrants.count } == 2)
        #expect(!shields.shieldedRuleIDs.contains(first.id))
        #expect(!shields.shieldedRuleIDs.contains(second.id))
        access.expire(activity: one.plan.activityName, now: one.plan.expiresAt)
        #expect(shields.shieldedRuleIDs.contains(first.id))
        #expect(!shields.shieldedRuleIDs.contains(second.id))
        #expect(try access.store.transaction { $0.activeGrants.map(\.plan.grantID) } == [two.plan.grantID])
        try access.end(grantID: one.plan.grantID)
        #expect(try access.store.transaction { $0.activeGrants.count } == 1)
        try access.end(grantID: two.plan.grantID)
        #expect(shields.shieldedRuleIDs.contains(second.id))
    }

    @Test("Only requested token is excluded and other rule stores survive")
    func individualGrant() throws {
        let app = try token(1), other = try token(2)
        let (access, shields) = try makeAccess()
        let first = snapshot([app, other]), second = snapshot([app])
        let independent = snapshot([try token(3)], kind: .schedule)
        shields.applyShield(ruleID: independent.id, selectionData: independent.selectionData, mode: .block)
        _ = try access.sync([first, second, independent])
        let grant = try access.approve(token: app, minutes: 5,
            fingerprint: ConversationGrantStore.fingerprint([first, second, independent]), timer: MockConversationTimer())
        let remaining = AppSelectionCodec.decode(shields.appliedSelectionData[first.id] ?? nil)
        #expect(remaining.applicationTokens == [other])
        #expect(!shields.shieldedRuleIDs.contains(second.id))
        #expect(shields.shieldedRuleIDs.contains(independent.id))
        access.expire(activity: grant.plan.activityName, now: grant.plan.expiresAt)
        #expect(AppSelectionCodec.decode(shields.appliedSelectionData[first.id] ?? nil).applicationTokens == [app, other])
        #expect(shields.shieldedRuleIDs.contains(second.id))
    }

    @Test("Another active rule cannot produce a false successful unlock")
    func overlappingBlockPreventsGrant() throws {
        let app = try token(1)
        let (access, shields) = try makeAccess()
        let chat = snapshot([app]), independent = snapshot([app], kind: .schedule)
        shields.applyShield(ruleID: independent.id, selectionData: independent.selectionData, mode: .block)
        _ = try access.sync([chat, independent])
        #expect(throws: ConversationAccessError.shieldReleaseFailed) {
            try access.approve(token: app, minutes: 1,
                fingerprint: ConversationGrantStore.fingerprint([chat, independent]), timer: MockConversationTimer())
        }
        #expect(try access.store.transaction { $0.grant } == nil)
        #expect(shields.shieldedRuleIDs.contains(independent.id))
    }

    @Test("Failed monitor registration keeps shields and creates no grant")
    func registrationFailure() throws {
        let app = try token(1)
        let (access, shields) = try makeAccess()
        let rule = snapshot([app])
        _ = try access.sync([rule])
        #expect(throws: (any Error).self) {
            try access.approve(token: app, minutes: 1, fingerprint: ConversationGrantStore.fingerprint([rule]), timer: FailingTimer())
        }
        #expect(try access.store.transaction { $0.grant } == nil)
        #expect(shields.shieldedRuleIDs.contains(rule.id))
    }

    @Test("Edits revoke grants and stale responses are rejected")
    func editsRevoke() throws {
        let app = try token(1)
        let (access, shields) = try makeAccess()
        var rule = snapshot([app])
        _ = try access.sync([rule])
        let fingerprint = ConversationGrantStore.fingerprint([rule])
        _ = try access.approve(token: app, minutes: 1, fingerprint: fingerprint, timer: MockConversationTimer())
        rule.conversationGoal = "Changed goal"
        _ = try access.sync([rule])
        #expect(shields.shieldedRuleIDs.contains(rule.id))
        #expect(try access.store.transaction { $0.grant } == nil)
        #expect(throws: ConversationAccessError.staleRequest) {
            try access.approve(token: app, minutes: 1, fingerprint: fingerprint, timer: MockConversationTimer())
        }
    }

    @Test("Duplicate and stale callbacks cannot end a newer grant")
    func staleCallback() throws {
        let app = try token(1)
        let (access, shields) = try makeAccess()
        let rule = snapshot([app])
        _ = try access.sync([rule])
        let fingerprint = ConversationGrantStore.fingerprint([rule])
        let first = try access.approve(token: app, minutes: 1, fingerprint: fingerprint, timer: MockConversationTimer())
        try access.end(grantID: first.plan.grantID)
        let second = try access.approve(token: app, minutes: 1, fingerprint: fingerprint, timer: MockConversationTimer())
        access.expire(activity: first.plan.activityName, now: .distantFuture)
        #expect(try access.store.transaction { $0.grant?.plan.grantID } == second.plan.grantID)
        #expect(!shields.shieldedRuleIDs.contains(rule.id))
        #expect(throws: ConversationAccessError.alreadyUnlocked) {
            try access.approve(token: app, minutes: 1, fingerprint: fingerprint, timer: MockConversationTimer())
        }
    }

    @Test("Pending target is consumed once and expires after five minutes")
    func pendingRouting() throws {
        let (access, _) = try makeAccess()
        let app = try token(1)
        let now = Date()
        try access.store.setPending(app, at: now)
        #expect(try access.store.consumePending(at: now) == app)
        #expect(try access.store.consumePending(at: now) == nil)
        try access.store.setPending(app, at: now)
        #expect(try access.store.consumePending(at: now.addingTimeInterval(301)) == nil)
    }

    @Test("Selection ordering does not invalidate an unchanged rule")
    func selectionOrderFingerprint() throws {
        let app = try token(1), other = try token(2)
        let first = snapshot([app, other])
        var second = first
        let data = try #require(first.selectionData)
        var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        for (key, value) in object {
            if let array = value as? [Any], array.count > 1 { object[key] = Array(array.reversed()) }
        }
        second.selectionData = try JSONSerialization.data(withJSONObject: object, options: .sortedKeys)
        #expect(first.selectionData != second.selectionData)
        #expect(ConversationGrantStore.fingerprint([first]) == ConversationGrantStore.fingerprint([second]))
    }

    @Test("Focus revokes covering grants, preserves another app and cannot be overridden")
    func focusPrecedence() throws {
        let app = try token(1), other = try token(2)
        let (access, shields) = try makeAccess()
        let first = snapshot([app]), second = snapshot([other]), rules = [first, second]
        _ = try access.sync(rules)
        let fingerprint = ConversationGrantStore.fingerprint(rules)
        _ = try access.approve(token: app, minutes: 1, fingerprint: fingerprint, timer: MockConversationTimer())
        let retained = try access.approve(token: other, minutes: 5, fingerprint: fingerprint, timer: MockConversationTimer())
        var focus = FocusProtectionState()
        focus.session = FocusSession(appIDs: [first.id], start: .now, minutes: 25)
        try access.updateFocus(focus, monitor: MockFocusMonitor())
        #expect(shields.shieldedRuleIDs.contains(first.id))
        #expect(!shields.shieldedRuleIDs.contains(second.id))
        #expect(try access.store.transaction { $0.activeGrants } == [retained])
        #expect(throws: ConversationAccessError.focusProtected) {
            try access.approve(token: app, minutes: 1, fingerprint: fingerprint, timer: MockConversationTimer())
        }
        try access.updateFocus(FocusProtectionState(), monitor: MockFocusMonitor())
        #expect(try access.store.transaction { $0.activeGrants } == [retained])
        #expect(shields.shieldedRuleIDs.contains(first.id))
    }

    @Test("Focus registration failure never publishes new protection")
    func focusRegistrationFailure() throws {
        let (access, _) = try makeAccess()
        _ = try access.sync([snapshot([try token(1)])])
        var focus = FocusProtectionState()
        focus.session = FocusSession(appIDs: [], start: .now, minutes: 25)
        #expect(throws: ConversationAccessError.monitoringUnavailable) {
            try access.updateFocus(focus, monitor: FailingFocusMonitor())
        }
        #expect(try access.focusStore.load() == FocusProtectionState())
    }

    @Test("Unrelated app edits preserve a grant and its original deadline")
    func unrelatedEditsPreserveGrant() throws {
        let app = try token(1), other = try token(2)
        let (access, _) = try makeAccess()
        let first = snapshot([app]); var second = snapshot([other])
        _ = try access.sync([first, second])
        let grant = try access.approve(token: app, minutes: 5,
            fingerprint: ConversationGrantStore.fingerprint([first, second]), timer: MockConversationTimer())
        second.conversationGoal = "Another intention"
        _ = try access.sync([first, second])
        #expect(try access.store.transaction { $0.activeGrants } == [grant])
    }

    @Test("Unreadable grant state at expiry restores shields from the independent mirror")
    func corruptExpiryRestoresProtection() throws {
        let app = try token(1)
        let (access, shields) = try makeAccess()
        let rule = snapshot([app])
        _ = try access.sync([rule])
        let grant = try access.approve(token: app, minutes: 1,
            fingerprint: ConversationGrantStore.fingerprint([rule]), timer: MockConversationTimer())
        let url = try #require(access.store.fileURL)
        try Data("corrupt".utf8).write(to: url)
        access.expire(activity: grant.plan.activityName, now: grant.plan.expiresAt)
        #expect(shields.shieldedRuleIDs.contains(rule.id))
        #expect(try access.store.transaction { $0.activeGrants.isEmpty })
    }

    nonisolated private struct FailingTimer: ConversationTimerScheduling {
        func start(_ plan: ConversationUnlockPlan) throws { throw ConversationAccessError.monitoringUnavailable }
        func stop(_ name: String) {}
    }
}

nonisolated private final class RefusingReleaseShields: ShieldApplying, @unchecked Sendable {
    func applyShield(ruleID: UUID, selectionData: Data?, mode: SelectionMode) {}
    func clearShield(ruleID: UUID) {}
    func clearShields(except activeRuleIDs: Set<UUID>) {}
    func setAppRemovalDenied(_ denied: Bool) {}
    func blockingRuleIDs(for token: ApplicationToken, among ruleIDs: Set<UUID>) -> Set<UUID> { ruleIDs }
}

nonisolated private struct FailingFocusMonitor: FocusMonitoring {
    func register(_ state: FocusProtectionState, now: Date) throws { throw ConversationAccessError.monitoringUnavailable }
    func keepOnly(_ names: Set<String>) {}
}
