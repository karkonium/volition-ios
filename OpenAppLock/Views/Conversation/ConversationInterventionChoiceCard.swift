import SwiftUI

/// Each button chooses explicitly displayed terms. Selecting a delay starts it;
/// selecting a deal accepts it; Open skips both without accepting break terms.
/// All grants still use the shared activation checks.
struct ConversationInterventionChoiceCard: View {
    let reflection: ConversationReflection
    let snapshots: () -> [RuleSnapshotDTO]
    @Environment(ConversationCoordinator.self) private var conversation
    var body: some View {
        VolitionCard(accented: true) {
            Text(CopyKey.interventionChoiceTitle.resource).font(.headline)
            Button {
                conversation.chooseIntervention(reflection.id, deal: false)
            } label: {
                optionLabel(.interventionDelayTitle, detail: CopyKey.interventionDelayChoice.string(reflection.seconds, reflection.unlockMinutes))
            }.buttonStyle(VolitionButtonStyle()).accessibilityIdentifier("conversationChooseDelayButton")
            Button {
                Task {
                    conversation.chooseIntervention(reflection.id, deal: true)
                    await conversation.completeReflection(reflection.id, acceptDeal: true, snapshots: snapshots)
                }
            } label: {
                optionLabel(.interventionDealTitle, detail: CopyKey.interventionDealChoice.string(reflection.unlockMinutes, reflection.blockMinutes ?? 0))
            }.buttonStyle(VolitionButtonStyle()).accessibilityIdentifier("conversationChooseDealButton")
            Button {
                Task {
                    conversation.chooseIntervention(reflection.id, option: .open)
                    await conversation.completeReflection(reflection.id, snapshots: snapshots)
                }
            } label: {
                optionLabel(.interventionOpenTitle, detail: CopyKey.interventionOpenChoice.string(reflection.unlockMinutes))
            }.buttonStyle(VolitionButtonStyle(primary: false)).accessibilityIdentifier("conversationChooseOpenButton")
            Text(CopyKey.interventionChoiceHelp.resource).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func optionLabel(_ title: CopyKey, detail: String) -> some View {
        VStack(spacing: 4) {
            Text(title.resource)
            Text(detail).font(.caption)
        }
        .frame(maxWidth: .infinity)
        .fixedSize(horizontal: false, vertical: true)
    }
}
