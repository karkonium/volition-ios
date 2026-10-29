import SwiftUI

/// Inline soft-pause countdown, visually separate from the top unlock timers.
/// Choices remain visible after expiry until answered. Sharing an emotion is
/// optional; Not sure / Skip answers the check-in, and Skip pause opens immediately.
struct ConversationReflectionCard: View {
    let reflection: ConversationReflection
    let snapshots: () -> [RuleSnapshotDTO]
    @Environment(ConversationCoordinator.self) private var conversation
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let elapsed = reflection.state == .counting && reflection.deadline.map { $0 <= timeline.date } == true
            let awaitingAnswer = elapsed && reflection.emotion == nil
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "leaf").accessibilityHidden(true)
                    Text((awaitingAnswer ? CopyKey.reflectionReady : reflection.state == .offered ? .reflectionOffer : .reflectionTaking).resource)
                        .font(.headline)
                    Spacer()
                    if reflection.state == .counting, !elapsed, let deadline = reflection.deadline {
                        let remaining = max(0, Int(ceil(deadline.timeIntervalSince(timeline.date))))
                        Text(String(format: "%d:%02d", remaining / 60, remaining % 60))
                            .monospacedDigit().accessibilityLabel("\(remaining) seconds remaining")

                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(reflection.state == .counting && !elapsed ? "reflectionCountdown" : "reflectionHeading")
                Text(CopyKey.reflectionPlan.string(reflection.appName, reflection.unlockMinutes)).font(.subheadline)
                if reflection.state == .activating {
                    ProgressView(CopyKey.reflectionOpening.resource)
                } else {
                    if reflection.state == .offered {
                        Text(CopyKey.reflectionLongPlan.string(Duration.seconds(reflection.seconds).formatted(.units(allowed: [.minutes, .seconds], width: .wide)))).font(.subheadline)
                        Button(CopyKey.reflectionStart.resource) { conversation.startReflection(reflection.id) }
                            .buttonStyle(.borderedProminent).accessibilityIdentifier("startReflectionButton")
                    }
                    Text(CopyKey.reflectionQuestion.resource).font(.subheadline)
                    if let emotion = reflection.emotion {
                        Text(emotion.copy.resource).foregroundStyle(.secondary)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 125))], alignment: .leading, spacing: 6) {
                            ForEach(ConversationReflection.Emotion.allCases, id: \.self) { emotion in
                                Button(emotion.copy.resource) { conversation.chooseEmotion(emotion, for: reflection.id) }
                                    .buttonStyle(.bordered).font(.caption)
                                    .accessibilityIdentifier("reflectionEmotion-\(emotion.rawValue)")
                            }
                        }
                    }
                    Text((awaitingAnswer ? CopyKey.reflectionAnswerHelp : .reflectionHelp).resource).font(.caption).foregroundStyle(.secondary)
                    ViewThatFits {
                        HStack { actions }
                        VStack(alignment: .leading) { actions }
                    }
                }
            }
            .padding(14)
            .background(Color.accentColor.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))

        }
    }

    @ViewBuilder private var actions: some View {
        Button(CopyKey.reflectionSkip.resource) {
            Task { await conversation.completeReflection(reflection.id, skip: true, snapshots: snapshots) }
        }.buttonStyle(.borderedProminent).accessibilityIdentifier("skipReflectionButton")
        Button(CopyKey.reflectionCancel.resource) { conversation.cancelReflection(reflection.id) }
            .font(.caption).accessibilityIdentifier("cancelReflectionButton")
    }
}
