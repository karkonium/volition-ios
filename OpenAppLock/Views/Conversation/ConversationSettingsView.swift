import SwiftUI

/// Consumer coaching controls never expose credentials or provider diagnostics.
struct ConversationSettingsView: View {
    @Environment(ConversationCoordinator.self) private var conversation
    @Environment(NotificationAuthorization.self) private var notifications
    @Environment(\.openURL) private var openURL
    @State private var confirmingClear = false
    var body: some View {
        @Bindable var preferences = conversation.preferences
        VolitionScroll {
            VolitionCard {
                Picker(CopyKey.coachTone.string, selection: $preferences.tone) {
                    ForEach(CoachTone.allCases, id: \.self) { tone in Text(tone.title).tag(tone) }
                }.pickerStyle(.menu).frame(minHeight: 44)
                    .accessibilityIdentifier("coachTonePicker")
                Text(CopyKey.coachToneHelp.resource).font(.footnote).foregroundStyle(.secondary)
            }
            VolitionCard {
                Label(CopyKey.uiServiceStatus.resource, systemImage: "bubble.left.and.bubble.right")
                    .font(.subheadline.weight(.semibold))
                Text((conversation.coachAvailable ? CopyKey.coachReady : .coachUnavailable).resource)
                    .font(.footnote).foregroundStyle(.secondary)
                    .accessibilityIdentifier("openAIKeyStatus")
            }
            Group {
                VolitionCard {
                    Button((notifications.status == .notDetermined ? CopyKey.conversationEnableNotifications : .conversationNotificationSettings).resource) {
                        if notifications.status == .notDetermined { Task { await notifications.request() } }
                        else if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                    }.buttonStyle(VolitionButtonStyle(primary: false))
                        .accessibilityIdentifier("conversationNotificationSettingsButton")
                    Text(CopyKey.conversationNotificationHelp.resource).font(.footnote).foregroundStyle(.secondary)
                        .accessibilityIdentifier("conversationNotificationHelp")
                }
            }
            VolitionCard {
                VolitionSectionHeading(title: CopyKey.uiConversationHistory.string)
                Text(CopyKey.volitionClearHelp.resource).font(.footnote).foregroundStyle(.secondary)
                Button(CopyKey.conversationHistoryClear.resource, role: .destructive) { confirmingClear = true }
                    .buttonStyle(VolitionButtonStyle(primary: false))
                    .accessibilityIdentifier("clearConversationHistoryButton")
            }
        }
        .tint(VolitionStyle.accent)
        .volitionRoot(CopyKey.volitionCoachSettings.string)
        .confirmationDialog(CopyKey.conversationHistoryClear.string, isPresented: $confirmingClear, titleVisibility: .visible) {
            Button(CopyKey.conversationHistoryClear.resource, role: .destructive) { conversation.clearHistory() }
        } message: { Text(CopyKey.volitionClearHelp.resource) }
    }
}
