import SwiftUI

/// Volition keeps only coach/privacy settings and exportable diagnostics.
/// Scheduling, hard mode, app lists and time/open budgets are no longer exposed.
struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink { ConversationSettingsView() } label: {
                        Label(CopyKey.volitionCoachSettings.resource, systemImage: "bubble.left.and.bubble.right")
                    }.accessibilityIdentifier("conversationSettingsButton")
                    NavigationLink { DiagnosticLogsView() } label: {
                        Label(CopyKey.settingsLogsRowLabel.resource, systemImage: "doc.text.magnifyingglass")
                    }.accessibilityIdentifier("diagnosticsLogsRow")
                }
                Section { Text(CopyKey.volitionPrivacy.resource).foregroundStyle(.secondary) }
            }
            .navigationTitle(CopyKey.settingsNavigationTitle.resource)
        }
    }
}
