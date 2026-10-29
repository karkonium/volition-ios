import SwiftUI

/// Compact, explicit navigation rows separate preferences, private content and support.
struct SettingsView: View {
    @Environment(ScreenTimeAuthorization.self) private var authorization
    @Environment(\.openURL) private var openURL
    var body: some View {
        NavigationStack {
            VolitionScroll {
                VStack(spacing: 10) {
                    VolitionSectionHeading(title: CopyKey.uiPreferences.string)
                    NavigationLink { ConversationSettingsView() } label: {
                        VolitionCard {
                            VolitionSettingsLabel(title: CopyKey.volitionCoachSettings.string,
                                subtitle: CopyKey.uiCoachSubtitle.string, symbol: "bubble.left.and.bubble.right")
                        }
                    }.buttonStyle(.plain).accessibilityIdentifier("conversationSettingsButton")
                    NavigationLink { PrivacyDataView() } label: {
                        VolitionCard {
                            VolitionSettingsLabel(title: CopyKey.privacyTitle.string,
                                subtitle: CopyKey.uiPrivacySubtitle.string, symbol: "hand.raised")
                        }
                    }.buttonStyle(.plain).accessibilityIdentifier("privacyDataButton")
                }
                VStack(spacing: 10) {
                    VolitionSectionHeading(title: CopyKey.uiHistorySupport.string)
                    NavigationLink { ConversationActivityLogView() } label: {
                        VolitionCard {
                            VolitionSettingsLabel(title: CopyKey.activityLogTitle.string,
                                subtitle: CopyKey.uiActivitySubtitle.string, symbol: "clock.arrow.circlepath")
                        }
                    }.buttonStyle(.plain).accessibilityIdentifier("conversationActivityLogButton")
                    NavigationLink { DiagnosticLogsView() } label: {
                        VolitionCard {
                            VolitionSettingsLabel(title: CopyKey.settingsLogsRowLabel.string,
                                subtitle: CopyKey.uiDiagnosticsSubtitle.string, symbol: "doc.text.magnifyingglass")
                        }
                    }.buttonStyle(.plain).accessibilityIdentifier("diagnosticsLogsRow")
                }
                VolitionCard {
                    VolitionSectionHeading(title: CopyKey.uiPermissions.string)
                    Label((authorization.status == .approved ? CopyKey.uiScreenTimeOn : .uiScreenTimeOff).resource,
                        systemImage: authorization.status == .approved ? "checkmark.shield" : "exclamationmark.shield")
                        .font(.subheadline.weight(.medium))
                    Text(CopyKey.uiPermissionsHelp.resource).font(.caption).foregroundStyle(.secondary)
                    Button(CopyKey.uiSystemSettings.resource, systemImage: "arrow.up.right") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }.buttonStyle(VolitionButtonStyle(primary: false))
                        .accessibilityIdentifier("systemPermissionSettingsButton")
                }
                Label(CopyKey.volitionPrivacy.resource, systemImage: "lock")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .volitionRoot(CopyKey.settingsNavigationTitle.string)
        }
    }
}
