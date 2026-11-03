//
//  ShieldController.swift
//  OpenAppLock
//

import FamilyControls
import Foundation
import ManagedSettings

/// Applies and clears app shields for rules. One implementation talks to
/// ManagedSettings; the mock records calls for tests.
///
/// `nonisolated` + `Sendable` so the app's enforcement can call it off the main
/// thread (the shared `Shared/` code already runs nonisolated inside the
/// extensions); see `RuleEnforcementEngine`.
nonisolated protocol ShieldApplying: AnyObject, Sendable {
    func applyShield(ruleID: UUID, selectionData: Data?, mode: SelectionMode)
    /// Clears the shield of a single rule (used by the extensions for day
    /// resets and granted opens).
    func clearShield(ruleID: UUID)
    /// Clears every shield except those for the given rule IDs. Covers rules
    /// that were deleted or expired while the app was not running.
    func clearShields(except activeRuleIDs: Set<UUID>)
    /// Engages or relinquishes the device-wide app-removal denial used by
    /// Uninstall Protection. Independent of per-rule shields: it lives on its
    /// own store so clearing rule shields never disturbs it.
    func setAppRemovalDenied(_ denied: Bool)
    /// Reads this app's configured shield directives, not the OS-visible screen.
    func blockingRuleIDs(for token: ApplicationToken, among ruleIDs: Set<UUID>) -> Set<UUID>
}

/// Real shield enforcement via per-rule `ManagedSettingsStore`s. Store names
/// are tracked in the shared app-group defaults (ManagedSettings cannot
/// enumerate stores before iOS 26.5). Newer systems also enumerate configured
/// stores, repairing orphaned restrictions if bookkeeping was lost. Cleared stores
/// are deactivated and deleted on supported systems; later blocking recreates
/// the store. This relinquishes the rule's store rather than retaining an empty
/// store after an unlock. Configuration readback cannot verify the OS-visible UI.
nonisolated final class ManagedSettingsShieldController: ShieldApplying, @unchecked Sendable {
    private static let trackedIDsKey = "shieldedRuleIDs"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = AppGroup.defaults) {
        self.defaults = defaults
    }

    func applyShield(ruleID: UUID, selectionData: Data?, mode: SelectionMode) {
        let store = store(for: ruleID)
        let selection = AppSelectionCodec.decode(selectionData)
        switch mode {
        case .block:
            store.shield.webDomainCategories = nil
            store.shield.applications =
                selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
            store.shield.applicationCategories =
                selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
            store.shield.webDomains =
                selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
        case .allowOnly:
            store.shield.applications = nil
            store.shield.webDomains = nil
            // `.all(except:)` is itself a *shield* directive ("block everything
            // except these"), not a whitelist — it cannot lift another store's
            // shield on a shared app. So an Allow-Only rule never punches a hole
            // through a block another rule applies (strictest wins — see
            // `RuleEnforcer`).
            store.shield.applicationCategories = .all(except: selection.applicationTokens)
            store.shield.webDomainCategories = .all(except: selection.webDomainTokens)
        }
        if #available(iOS 26.5, *) { store.isActive = true }
        track(ruleID: ruleID)
        Diag.log(
            .shield, .event,
            "apply rule-\(ruleID.logTag) mode=\(mode) apps=\(selection.applicationTokens.count) cats=\(selection.categoryTokens.count) web=\(selection.webDomainTokens.count)")
    }

    func clearShield(ruleID: UUID) {
        Diag.log(.shield, .event, "clear rule-\(ruleID.logTag)")
        let store = store(for: ruleID)
        if #available(iOS 26.5, *) { store.isActive = false }
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
        store.shield.webDomainCategories = nil
        store.clearAllSettings()
        if #available(iOS 26.5, *) {
            store.deleteStore()
            Diag.log(.shield, .event, "release rule-\(ruleID.logTag) store_deleted")
        }
        untrack(ruleID: ruleID)
    }

    func clearShields(except activeRuleIDs: Set<UUID>) {
        let registeredNames: Set<String>
        if #available(iOS 26.5, *) { registeredNames = Set(ManagedSettingsStore.stores.map(\.rawValue)) }
        else { registeredNames = [] }
        let toClear = ShieldStoreInventory.staleRuleIDs(tracked: trackedIDs,
            registeredNames: registeredNames, keeping: activeRuleIDs)
        if !toClear.isEmpty {
            Diag.log(
                .shield,
                "clearShields: \(activeRuleIDs.count) active, clearing \(toClear.count) stray")
        }
        for ruleID in toClear {
            clearShield(ruleID: ruleID)
        }
    }

    func setAppRemovalDenied(_ denied: Bool) {
        // A dedicated store keeps this device-wide setting off the per-rule
        // stores, which get fully cleared when their shield lifts. Setting nil
        // (not false) relinquishes the constraint entirely when off.
        let store = ManagedSettingsStore(named: Self.uninstallProtectionStoreName)
        store.application.denyAppRemoval = denied ? true : nil
        if denied { Diag.log(.shield, "appRemovalDenied engaged (Uninstall Protection)") }
    }

    func blockingRuleIDs(for token: ApplicationToken, among ruleIDs: Set<UUID>) -> Set<UUID> {
        let registered: Set<UUID>
        if #available(iOS 26.5, *) {
            registered = ShieldStoreInventory.ruleIDs(in: Set(ManagedSettingsStore.stores.map(\.rawValue)))
        } else { registered = [] }
        return Set(ruleIDs.union(trackedIDs).union(registered).filter { id in
            let store = store(for: id)
            if #available(iOS 26.5, *), !store.isActive { return false }
            if store.shield.applications?.contains(token) == true { return true }
            switch store.shield.applicationCategories {
            case .all(let exceptions): return !exceptions.contains(token)
            case .specific(let categories, let exceptions): return !categories.isEmpty && !exceptions.contains(token)
            case nil, .some(.none): return false
            @unknown default: return true
            }
        })
    }

    private static var uninstallProtectionStoreName: ManagedSettingsStore.Name {
        .init("uninstall-protection")
    }

    private func store(for ruleID: UUID) -> ManagedSettingsStore {
        ManagedSettingsStore(named: ManagedSettingsStore.Name("rule-\(ruleID.uuidString)"))
    }

    private var trackedIDs: Set<UUID> {
        Set((defaults.stringArray(forKey: Self.trackedIDsKey) ?? []).compactMap(UUID.init))
    }

    private func track(ruleID: UUID) {
        let ids = trackedIDs.union([ruleID])
        defaults.set(ids.map(\.uuidString).sorted(), forKey: Self.trackedIDsKey)
    }

    private func untrack(ruleID: UUID) {
        let ids = trackedIDs.subtracting([ruleID])
        defaults.set(ids.map(\.uuidString).sorted(), forKey: Self.trackedIDsKey)
    }
}

/// Records shield operations without touching the system. Used by tests and
/// UI-test launches. `@unchecked Sendable`: a test double whose mutations are
/// ordered behind the `await` in `RuleEnforcer.refresh` before assertions read them.
nonisolated final class MockShieldController: ShieldApplying, @unchecked Sendable {
    private(set) var shieldedRuleIDs: Set<UUID> = []
    private(set) var appliedModes: [UUID: SelectionMode] = [:]
    private(set) var appliedSelectionData: [UUID: Data?] = [:]
    /// The device-wide app-removal denial. Deliberately separate from the
    /// per-rule shield bookkeeping, mirroring the dedicated store in the real
    /// controller — `clearShields(except:)` must not disturb it.
    private(set) var appRemovalDenied = false

    func applyShield(ruleID: UUID, selectionData: Data?, mode: SelectionMode) {
        shieldedRuleIDs.insert(ruleID)
        appliedModes[ruleID] = mode
        appliedSelectionData[ruleID] = selectionData
    }

    func clearShield(ruleID: UUID) {
        shieldedRuleIDs.remove(ruleID)
        appliedModes[ruleID] = nil
        appliedSelectionData[ruleID] = nil
    }

    func clearShields(except activeRuleIDs: Set<UUID>) {
        shieldedRuleIDs.formIntersection(activeRuleIDs)
        appliedModes = appliedModes.filter { activeRuleIDs.contains($0.key) }
        appliedSelectionData = appliedSelectionData.filter { activeRuleIDs.contains($0.key) }
        // Note: appRemovalDenied is intentionally left untouched here.
    }

    func blockingRuleIDs(for token: ApplicationToken, among ruleIDs: Set<UUID>) -> Set<UUID> {
        Set(shieldedRuleIDs.filter { id in
            let selection = AppSelectionCodec.decode(appliedSelectionData[id] ?? nil)
            return selection.applicationTokens.contains(token) || !selection.categoryTokens.isEmpty ||
                (appliedModes[id] == .allowOnly && !selection.applicationTokens.contains(token))
        })
    }

    func setAppRemovalDenied(_ denied: Bool) {
        appRemovalDenied = denied
    }
}

/// Encodes/decodes `FamilyActivitySelection` for persistence on the rule model.
nonisolated enum AppSelectionCodec {
    static func encode(_ selection: FamilyActivitySelection) -> Data? {
        try? JSONEncoder().encode(selection)
    }

    static func decode(_ data: Data?) -> FamilyActivitySelection {
        guard let data,
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        else { return FamilyActivitySelection() }
        return selection
    }

    static func count(of selection: FamilyActivitySelection) -> Int {
        selection.applicationTokens.count
            + selection.categoryTokens.count
            + selection.webDomainTokens.count
    }
}

/// The system inventory repairs lost defaults bookkeeping after cross-process
/// writes or upgrades. Unrelated named stores are never parsed as rule stores.
nonisolated enum ShieldStoreInventory {
    static func ruleIDs(in names: Set<String>) -> Set<UUID> {
        Set(names.compactMap { name in
            guard name.hasPrefix("rule-") else { return nil }
            return UUID(uuidString: String(name.dropFirst(5)))
        })
    }
    static func staleRuleIDs(tracked: Set<UUID>, registeredNames: Set<String>, keeping: Set<UUID>) -> Set<UUID> {
        tracked.union(ruleIDs(in: registeredNames)).subtracting(keeping)
    }
}
