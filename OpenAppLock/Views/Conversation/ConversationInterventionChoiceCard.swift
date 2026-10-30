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
            Button(CopyKey.interventionDelayChoice.string(reflection.seconds, reflection.unlockMinutes)) {
                conversation.chooseIntervention(reflection.id, deal: false)
            }.buttonStyle(VolitionButtonStyle()).accessibilityIdentifier("conversationChooseDelayButton")
            Button(CopyKey.interventionDealChoice.string(reflection.unlockMinutes, reflection.blockMinutes ?? 0)) {
                Task {
                    conversation.chooseIntervention(reflection.id, deal: true)
                    await conversation.completeReflection(reflection.id, acceptDeal: true, snapshots: snapshots)
                }
            }.buttonStyle(VolitionButtonStyle()).accessibilityIdentifier("conversationChooseDealButton")
            Button(CopyKey.interventionOpenChoice.string(reflection.unlockMinutes)) {
                Task {
                    conversation.chooseIntervention(reflection.id, option: .open)
                    await conversation.completeReflection(reflection.id, snapshots: snapshots)
                }
            }.buttonStyle(VolitionButtonStyle(primary: false)).accessibilityIdentifier("conversationChooseOpenButton")
            Text(CopyKey.interventionChoiceHelp.resource).font(.caption).foregroundStyle(.secondary)
        }
    }
}
