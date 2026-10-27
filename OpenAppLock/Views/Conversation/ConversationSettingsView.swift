import SwiftUI

/// Consumer coaching controls never expose credentials or provider diagnostics.
struct ConversationSettingsView: View {
    @Environment(ConversationCoordinator.self) private var conversation
    @Environment(NotificationAuthorization.self) private var notifications
    @Environment(\.openURL) private var openURL
    @State private var confirmingClear = false
    var body: some View {
        @Bindable var preferences = conversation.preferences
        Form {
            Section {
                Picker(CopyKey.coachTone.string, selection: $preferences.tone) {
                    ForEach(CoachTone.allCases, id: \.self) { tone in Text(tone.title).tag(tone) }
                }.accessibilityIdentifier("coachTonePicker")
            } footer: { Text(CopyKey.coachToneHelp.resource) }
            Section {
                Text((conversation.coachAvailable ? CopyKey.coachReady : .coachUnavailable).resource)
                    .accessibilityIdentifier("openAIKeyStatus")
            }
            if ConversationShieldRoute.current == .notification {
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
                Button(CopyKey.conversationHistoryClear.resource, role: .destructive) { confirmingClear = true }
                    .accessibilityIdentifier("clearConversationHistoryButton")
            } footer: { Text(CopyKey.volitionClearHelp.resource) }
        }
        .navigationTitle(CopyKey.volitionCoachSettings.resource)
        .confirmationDialog(CopyKey.conversationHistoryClear.string, isPresented: $confirmingClear, titleVisibility: .visible) {
            Button(CopyKey.conversationHistoryClear.resource, role: .destructive) { conversation.clearHistory() }
        } message: { Text(CopyKey.volitionClearHelp.resource) }
    }
}
