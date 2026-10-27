import SwiftUI

struct PrivacyDataView: View {
    @Environment(ConversationCoordinator.self) private var conversation
    @State private var confirmingErase = false
    @State private var eraseFailed = false
    var body: some View {
        Form {
            Section {
                Text(CopyKey.aiConsentDisclosure.resource)
                Toggle(CopyKey.aiConsentToggle.resource, isOn: Binding(get: { conversation.preferences.hasConsent }, set: { conversation.setAIConsent($0) }))
                    .accessibilityIdentifier("aiConsentToggle")
            } header: { Text(CopyKey.aiConsentTitle.resource) } footer: { Text(CopyKey.aiConsentWithdrawal.resource) }
            Section {
                if let url = privacyPolicyURL {
                    Link(CopyKey.privacyPolicy.resource, destination: url)
                } else {
                    Text(CopyKey.privacyPolicyPending.resource).foregroundStyle(.secondary)
                }
            }
            Section {
                Button(CopyKey.eraseCoachingContent.resource, role: .destructive) { confirmingErase = true }
                    .accessibilityIdentifier("eraseCoachingContentButton")
            } footer: { Text(CopyKey.eraseCoachingHelp.resource) }
            if eraseFailed { Text(CopyKey.conversationStorageError.resource).foregroundStyle(.red) }
        }
        .navigationTitle(CopyKey.privacyTitle.resource)
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
