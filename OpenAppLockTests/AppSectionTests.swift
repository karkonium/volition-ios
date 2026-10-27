//
//  AppSectionTests.swift
//  OpenAppLockTests
//

import Testing
@testable import OpenAppLock

/// `AppSection` is the single source of truth for the top-level sections, shared
/// by the compact `TabView` (`MainTabView`) and the regular-width sidebar
/// (`MainSidebarView`). These tests pin its order, labels, and icons so the two
/// layouts can never drift.
@MainActor
struct AppSectionTests {
    @Test("Retired screens cannot become navigation destinations")
    func retiredDestinations() {
        #expect(AppSection(rawValue: "home") == nil)
        #expect(AppSection(rawValue: "rules") == nil)
    }

    @Test("Sections are ordered Chat, Apps, Insights, Focus, Settings")
    func ordering() {
        #expect(AppSection.allCases == [.chat, .apps, .insights, .focus, .settings])
    }

    @Test("There are exactly five top-level sections")
    func count() {
        #expect(AppSection.allCases.count == 5)
    }

    @Test("Each section exposes its display title")
    func titles() {
        #expect(AppSection.chat.title == "Chat")
        #expect(AppSection.apps.title == "Apps")
        #expect(AppSection.settings.title == "Settings")
    }

    @Test("Each section exposes its SF Symbol")
    func symbols() {
        #expect(AppSection.chat.systemImage == "bubble.left.and.bubble.right")
        #expect(AppSection.apps.systemImage == "apps.iphone")
        #expect(AppSection.settings.systemImage == "gearshape")
    }

    @Test("Identifiers are the stable raw values")
    func identifiers() {
        #expect(AppSection.chat.id == "chat")
        #expect(AppSection.apps.id == "apps")
        #expect(AppSection.settings.id == "settings")
    }
}
