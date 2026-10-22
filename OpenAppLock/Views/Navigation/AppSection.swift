//
//  AppSection.swift
//  OpenAppLock
//

import Foundation

/// The app's top-level sections. Single source of truth for the post-onboarding
/// navigation, shared by the compact `TabView` (`MainTabView`) and the
/// regular-width sidebar (`MainSidebarView`) so the two layouts can't drift.
enum AppSection: String, CaseIterable, Identifiable {
    // Retained for source compatibility with archived legacy screens.
    case home
    case rules
    case apps
    case chat
    case settings

    static let allCases: [AppSection] = [.chat, .apps, .settings]

    var id: String { rawValue }

    /// User-facing label shown in the tab item and the sidebar row.
    var title: String {
        switch self {
        case .apps: CopyKey.volitionApps.string
        case .home: CopyKey.navHomeSectionTitle.string
        case .rules: CopyKey.navRulesSectionTitle.string
        case .chat: CopyKey.conversationChatTitle.string
        case .settings: CopyKey.navSettingsSectionTitle.string
        }
    }

    /// SF Symbol shown alongside the title in both layouts.
    var systemImage: String {
        switch self {
        case .apps: "apps.iphone"
        case .home: "house"
        case .rules: "shield.lefthalf.filled"
        case .chat: "bubble.left.and.bubble.right"
        case .settings: "gearshape"
        }
    }
}
