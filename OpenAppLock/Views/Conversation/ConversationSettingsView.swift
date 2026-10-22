import SwiftUI

/// Shows whether this build contains a local env-file credential and how to
/// change it. No key entry or Keychain fallback. History deletion remains explicit.
struct ConversationSettingsView: View {
    @Environment(ConversationCoordinator.self) private var conversation
    @State private var confirmingClear = false
    var body: some View {
        Form {
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
