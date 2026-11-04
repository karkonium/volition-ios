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
                optionLabel(.interventionDelayTitle, detail: CopyKey.delayDuration.string(pauseDuration), next: CopyKey.thenUnlockedDuration.string(unlockDuration))
            }.buttonStyle(VolitionButtonStyle()).accessibilityIdentifier("conversationChooseDelayButton")
            Button {
                Task {
                    conversation.chooseIntervention(reflection.id, deal: true)
                    await conversation.completeReflection(reflection.id, acceptDeal: true, snapshots: snapshots)
                }
            } label: {
                optionLabel(.interventionDealTitle, detail: CopyKey.unlockedDuration.string(unlockDuration), next: CopyKey.thenBlockedDuration.string(blockDuration))
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

    private var pauseDuration: String {
        CopyKey.pauseDuration(seconds: reflection.seconds)
    }
    private var unlockDuration: String {
        Duration.seconds(reflection.unlockMinutes * 60).formatted(.units(allowed: [.hours, .minutes], width: .wide))
    }
    private var blockDuration: String {
        Duration.seconds((reflection.blockMinutes ?? 0) * 60).formatted(.units(allowed: [.hours, .minutes], width: .wide))
    }

    private func optionLabel(_ title: CopyKey, detail: String, next: String? = nil) -> some View {
        VStack(spacing: 4) {
            Text(title.resource)
            Text(detail).font(.caption)
            Text(next ?? " ").font(.caption).opacity(next == nil ? 0 : 1).accessibilityHidden(next == nil)
        }
        .frame(maxWidth: .infinity)
        .fixedSize(horizontal: false, vertical: true)
    }
}
