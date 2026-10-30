import SwiftUI

/// Delays never activate automatically. Ten seconds starts immediately; longer
/// offers require Start. End delay reveals Unlock/Keep locked. Optional emotion
/// logging never gates either action.
struct ConversationReflectionCard: View {
    let reflection: ConversationReflection
    let snapshots: () -> [RuleSnapshotDTO]
    @Environment(ConversationCoordinator.self) private var conversation
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let ready = reflection.isReady(at: timeline.date)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "hourglass").accessibilityHidden(true)
                    Text((ready ? CopyKey.reflectionReady : reflection.state == .offered ? .reflectionOffer : .reflectionTaking).resource)
                        .font(.headline)
                    Spacer()
                    if reflection.state == .counting, !ready, let deadline = reflection.deadline {
                        Text(deadline, style: .timer).monospacedDigit()
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(reflection.state == .counting && !ready ? "reflectionCountdown" : "reflectionHeading")
                Text(CopyKey.reflectionPlan.string(reflection.appName, reflection.unlockMinutes)).font(.subheadline)
                if reflection.state == .activating {
                    ProgressView(CopyKey.reflectionOpening.resource)
                } else {
                    if reflection.state == .offered {
                        Text(CopyKey.reflectionLongPlan.string(Duration.seconds(reflection.seconds).formatted(.units(allowed: [.minutes, .seconds], width: .wide))))
                            .font(.subheadline)
                        Button(CopyKey.reflectionStart.resource) { conversation.startReflection(reflection.id) }
                            .buttonStyle(VolitionButtonStyle()).accessibilityIdentifier("startReflectionButton")
                    } else if !ready {
                        Button(CopyKey.reflectionEndDelay.resource) { conversation.endReflectionDelay(reflection.id) }
                            .buttonStyle(.plain).font(.caption).foregroundStyle(Color.secondary)
                            .frame(minWidth: 44, minHeight: 44)
                            .accessibilityIdentifier("skipReflectionButton")
                    }
                    Text(CopyKey.reflectionDelayHelp.resource).font(.caption).foregroundStyle(.secondary)
                    if ready {
                        HStack {
                            Button(CopyKey.reflectionUnlock.string(reflection.unlockMinutes)) {
                                Task { await conversation.completeReflection(reflection.id, snapshots: snapshots) }
                            }
                            .buttonStyle(VolitionButtonStyle(primary: false))
                            .accessibilityIdentifier("unlockAfterReflectionButton")
                            Button(CopyKey.reflectionCancel.resource) { conversation.cancelReflection(reflection.id) }
                                .buttonStyle(VolitionButtonStyle()).accessibilityIdentifier("cancelReflectionButton")
                        }
                    } else {
                        Button(CopyKey.reflectionCancel.resource) { conversation.cancelReflection(reflection.id) }
                            .buttonStyle(VolitionButtonStyle(primary: false)).accessibilityIdentifier("cancelReflectionButton")
                    }
                }
            }
            .fixedSize(horizontal: false, vertical: true).padding(14)
            .background(VolitionStyle.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
        }
    }
}
