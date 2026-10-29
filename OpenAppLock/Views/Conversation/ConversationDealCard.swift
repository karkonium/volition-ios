import SwiftUI

/// Offers never grant access. Only explicit acceptance activates the durable deal.
struct ConversationDealCard: View {
    @Environment(ConversationCoordinator.self) private var conversation
    let reflection: ConversationReflection
    let snapshots: () -> [RuleSnapshotDTO]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(CopyKey.dealTerms.string(reflection.appName,
                Duration.seconds(reflection.unlockMinutes * 60).formatted(.units(allowed: [.minutes], width: .wide)),
                Duration.seconds((reflection.blockMinutes ?? 0) * 60).formatted(.units(allowed: [.hours, .minutes], width: .wide))))
                .font(.headline).accessibilityIdentifier("conversationDealTerms")
            Text(CopyKey.dealHelp.resource).font(.caption).foregroundStyle(.secondary)
            HStack {
                Button(CopyKey.dealAccept.resource) {
                    Task { await conversation.completeReflection(reflection.id, acceptDeal: true, snapshots: snapshots) }
                }.buttonStyle(.borderedProminent).accessibilityIdentifier("conversationDealAccept")
                Button(CopyKey.dealDecline.resource) { conversation.declineDeal(reflection.id) }
                    .buttonStyle(.bordered).accessibilityIdentifier("conversationDealDecline")
            }.disabled(reflection.state == .activating)
        }.padding().background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }
}
