import SwiftUI

/// Shows whether this build contains a local env-file credential and how to
/// change it. No key entry or Keychain fallback. History deletion remains explicit.
struct ConversationSettingsView: View {
    @Environment(ConversationCoordinator.self) private var conversation
    @Environment(NotificationAuthorization.self) private var notifications
    @Environment(\.openURL) private var openURL
    @State private var confirmingClear = false
    var body: some View {
        Form {
            Group {
                Section {
                    Button((notifications.status == .notDetermined ? CopyKey.conversationEnableNotifications : .conversationNotificationSettings).resource) {
                        if notifications.status == .notDetermined { Task { await notifications.request() } }
                        else if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                    }.accessibilityIdentifier("conversationNotificationSettingsButton")
                } footer: {
                    Text(CopyKey.conversationNotificationHelp.resource).accessibilityIdentifier("conversationNotificationHelp")
                }
            }
            Section {
                Text((hasKey ? CopyKey.conversationEnvironmentConfigured : .conversationEnvironmentMissing).resource)
                    .accessibilityIdentifier("openAIKeyStatus")
                Text(CopyKey.conversationEnvironmentHelp.resource).foregroundStyle(.secondary)
            } footer: { Text(CopyKey.volitionPrivacy.resource) }
            Section {
                Text((ConversationEnvironment.bundled.logsEnabled ? CopyKey.conversationDiagnosticsEnabled : .conversationDiagnosticsDisabled).resource)
                Text(CopyKey.conversationDiagnosticsHelp.resource).foregroundStyle(.secondary)
            }
            Section {
                Button(CopyKey.conversationHistoryClear.resource, role: .destructive) { confirmingClear = true }
                    .accessibilityIdentifier("clearConversationHistoryButton")
            }
            Section { Text(CopyKey.volitionAccessHistory.resource).foregroundStyle(.secondary) }
        }
        .navigationTitle(CopyKey.volitionCoachSettings.resource)
        .confirmationDialog(CopyKey.conversationHistoryClear.string, isPresented: $confirmingClear, titleVisibility: .visible) {
            Button(CopyKey.conversationHistoryClear.resource, role: .destructive) { conversation.clearHistory() }
        } message: { Text(CopyKey.volitionClearHelp.resource) }
    }
    private var hasKey: Bool { (try? conversation.keys.read()) != nil }
}
