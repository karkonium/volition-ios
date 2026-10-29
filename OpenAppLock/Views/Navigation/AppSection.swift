//
//  AppSection.swift
//  OpenAppLock
//

import Foundation

/// Chat, Apps, Insights, Focus and Settings share adaptive navigation.
/// The app's top-level sections. Single source of truth for the post-onboarding
/// navigation, shared by the compact `TabView` (`MainTabView`) and the
/// regular-width sidebar (`MainSidebarView`) so the two layouts can't drift.
enum AppSection: String, CaseIterable, Identifiable {
    case chat
    case apps
    case insights
    case focus
    case settings

    var id: String { rawValue }

    /// User-facing label shown in the tab item and the sidebar row.
    var title: String {
        switch self {
        case .insights: CopyKey.insightsTitle.string
        case .focus: CopyKey.focusTitle.string
        case .apps: CopyKey.volitionApps.string
        case .chat: CopyKey.conversationChatTitle.string
        case .settings: CopyKey.navSettingsSectionTitle.string
        }
    }

    /// SF Symbol shown alongside the title in both layouts.
    var systemImage: String {
        switch self {
        case .insights: "chart.bar.xaxis"
        case .focus: "moon"
        case .apps: "apps.iphone"
        case .chat: "bubble.left.and.bubble.right"
        case .settings: "gearshape"
        }
    }
}
