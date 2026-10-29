import SwiftUI

/// The same disclosure appears in onboarding, chat review and privacy settings.
/// The accept action belongs to the caller; displaying details never grants consent.
struct AISharingDetails: View {
    var body: some View {
        VStack(spacing: 16) {
            VolitionCard {
                VolitionSectionHeading(title: CopyKey.uiSharedWithAI.string)
                detail("bubble.left", .uiSharedMessages, .uiSharedMessagesDetail)
                Divider()
                detail("apps.iphone", .uiSharedApps, .uiSharedAppsDetail)
                Divider()
                detail("clock.arrow.circlepath", .uiSharedOutcomes, .uiSharedOutcomesDetail)
            }
            VolitionCard {
                Label(CopyKey.uiLocalDataTitle.resource, systemImage: "iphone")
                    .font(.subheadline.weight(.semibold))
                Text(CopyKey.uiLocalDataDetail.resource).font(.footnote).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }.accessibilityElement(children: .contain).accessibilityIdentifier("aiSharingDetails")
    }
    private func detail(_ symbol: String, _ title: CopyKey, _ text: CopyKey) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol).font(.subheadline).foregroundStyle(.secondary)
                .frame(width: 22).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title.resource).font(.subheadline.weight(.medium))
                Text(text.resource).font(.footnote).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }.padding(.vertical, 2)
    }
}

struct AIConsentReviewView: View {
    @Environment(ConversationCoordinator.self) private var conversation
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            VolitionScroll {
                Text(CopyKey.aiConsentTitle.resource).font(.title2.bold())
                AISharingDetails()
                Text(CopyKey.aiConsentWithdrawal.resource).font(.footnote).foregroundStyle(.secondary)
            }
            .safeAreaInset(edge: .bottom) {
                Button(CopyKey.aiConsentAccept.resource) {
                    conversation.setAIConsent(true)
                    dismiss()
                }.buttonStyle(VolitionButtonStyle())
                    .accessibilityIdentifier("acceptAIConsentButton")
                    .padding(16).background(VolitionStyle.background)
            }
            .volitionRoot(CopyKey.uiSharingDetails.string)
            .toolbar { ToolbarItem(placement: .cancellationAction) {
                Button(CopyKey.conversationCancel.resource) { dismiss() }
            } }
        }
    }
}
