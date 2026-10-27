//
//  MainTabView.swift
//  OpenAppLock
//

import SwiftUI

/// The compact-width layout: the top-level sections as a bottom `TabView`.
/// Used on iPhone and in iPad multitasking / Slide Over (anywhere the horizontal
/// size class is compact). The app-level enforcement lifecycle lives on the
/// adaptive shell `MainView`, not here, so it runs regardless of layout.
///
/// Tab labels and icons come from `AppSection`, the same source the regular-width
/// sidebar (`MainSidebarView`) uses, so the two layouts can never drift.
struct MainTabView: View {
    @Environment(ConversationCoordinator.self) private var conversation
    var body: some View {
        @Bindable var conversation = conversation
        TabView(selection: $conversation.selectedSection) {
            ConversationView()
                .tag(AppSection.chat)
                .tabItem { Label(AppSection.chat.title, systemImage: AppSection.chat.systemImage) }
            VolitionAppsView()
                .tag(AppSection.apps)
                .tabItem { Label(AppSection.apps.title, systemImage: AppSection.apps.systemImage) }
            InsightsView()
                .tag(AppSection.insights)
                .tabItem { Label(AppSection.insights.title, systemImage: AppSection.insights.systemImage) }
            FocusView()
                .tag(AppSection.focus)
                .tabItem { Label(AppSection.focus.title, systemImage: AppSection.focus.systemImage) }
            SettingsView()
                .tag(AppSection.settings)
                .tabItem { Label(AppSection.settings.title, systemImage: AppSection.settings.systemImage) }
        }
    }
}
