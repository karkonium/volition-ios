import Foundation
import Testing
@testable import OpenAppLock

@MainActor
struct CoachPreferencesTests {
    @Test func sharingDefaultsOnWithoutOverridingAnExplicitChoice() throws {
        let name = "CoachPreferencesTests-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let preferences = CoachPreferences(defaults: defaults)
        #expect(preferences.hasConsent)
        preferences.setConsent(false)
        #expect(!CoachPreferences(defaults: defaults).hasConsent)
        preferences.setConsent(true)
        #expect(CoachPreferences(defaults: defaults).hasConsent)
    }
}
