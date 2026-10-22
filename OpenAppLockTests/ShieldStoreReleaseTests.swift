import Foundation
import ManagedSettings
import Testing
@testable import OpenAppLock

@MainActor @Suite(.serialized)
struct ShieldStoreReleaseTests {
    @Test("Releasing a rule removes its named store, leaving no stale directives")
    func removesReleasedStore() async throws {
        guard #available(iOS 26.5, *) else { return }
        let id = UUID(), name = ManagedSettingsStore.Name("rule-" + UUID().uuidString)
        let ruleName = ManagedSettingsStore.Name("rule-" + id.uuidString)
        let store = ManagedSettingsStore(named: ruleName)
        let unrelated = ManagedSettingsStore(named: name)
        defer { store.deleteStore() }
        defer { unrelated.deleteStore() }
        // A no-op category policy registers a store without blocking any app.
        store.shield.applicationCategories = .some(.none)
        store.isActive = true
        unrelated.shield.applicationCategories = .some(.none)
        unrelated.isActive = true
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(2))
        while !ManagedSettingsStore.stores.contains(ruleName), clock.now < deadline { await Task.yield() }
        #expect(ManagedSettingsStore.stores.contains(ruleName))
        let defaults = try #require(UserDefaults(suiteName: name.rawValue))
        defer { defaults.removePersistentDomain(forName: name.rawValue) }
        ManagedSettingsShieldController(defaults: defaults).clearShield(ruleID: id)
        let token = try JSONDecoder().decode(ApplicationToken.self,
            from: JSONSerialization.data(withJSONObject: ["data": Data([1]).base64EncodedString()]))
        #expect(ManagedSettingsShieldController(defaults: defaults).blockingRuleIDs(for: token, among: [id]).isEmpty)
        let released = clock.now.advanced(by: .seconds(2))
        while ManagedSettingsStore.stores.contains(ruleName), clock.now < released { await Task.yield() }
        #expect(!ManagedSettingsStore.stores.contains(ruleName))
        #expect(ManagedSettingsStore.stores.contains(name))
    }
}
