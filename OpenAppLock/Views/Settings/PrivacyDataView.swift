import SwiftUI

/// Sharing, local storage and erasure are distinct controls. Withdrawal cancels
/// pending work; erasure preserves only the minimal active enforcement state.
struct PrivacyDataView: View {
    @Environment(ConversationCoordinator.self) private var conversation
    @State private var confirmingErase = false
    @State private var eraseFailed = false
    var body: some View {
        VolitionScroll {
            VolitionCard {
                Toggle(CopyKey.aiConsentToggle.resource, isOn: Binding(
                    get: { conversation.preferences.hasConsent },
                    set: { conversation.setAIConsent($0) }))
                    .font(.subheadline.weight(.semibold))
                    .accessibilityIdentifier("aiConsentToggle")
                Text(CopyKey.aiConsentWithdrawal.resource).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            AISharingDetails()
            VolitionCard {
                if let url = privacyPolicyURL {
                    Link(destination: url) {
                        Label(CopyKey.privacyPolicy.resource, systemImage: "arrow.up.right")
                    }.buttonStyle(VolitionButtonStyle(primary: false))
                } else {
                    Text(CopyKey.privacyPolicyPending.resource).font(.footnote).foregroundStyle(.secondary)
                }
            }
            VolitionCard {
                VolitionSectionHeading(title: CopyKey.uiDataControls.string)
                DisclosureGroup(CopyKey.uiErasureDetails.string) {
                    Text(CopyKey.eraseCoachingHelp.resource).font(.footnote).foregroundStyle(.secondary)
                        .padding(.top, 8)
                }.font(.subheadline)
                Button(CopyKey.eraseCoachingContent.resource, role: .destructive) { confirmingErase = true }
                    .buttonStyle(VolitionButtonStyle(primary: false))
                    .accessibilityIdentifier("eraseCoachingContentButton")
                if eraseFailed { Text(CopyKey.conversationStorageError.resource).font(.footnote).foregroundStyle(.red) }
            }
        }
        .tint(VolitionStyle.accent)
        .volitionRoot(CopyKey.privacyTitle.string)
        .confirmationDialog(CopyKey.eraseCoachingContent.string, isPresented: $confirmingErase, titleVisibility: .visible) {
            Button(CopyKey.eraseCoachingContent.resource, role: .destructive) { eraseFailed = !conversation.eraseCoachingContent() }
        } message: { Text(CopyKey.eraseCoachingHelp.resource) }
    }
    private var privacyPolicyURL: URL? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "OALPrivacyPolicyURL") as? String,
              let url = URL(string: raw), url.scheme == "https", url.host != nil else { return nil }
        return url
    }
}
