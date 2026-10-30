import SwiftUI

/// Separate awareness message shown before delay, deal, choice or replacement terms.
/// Custom entries are bounded to 160 trimmed characters. Answering only records
/// context and reveals the next step; it never unlocks or accepts deal terms.
struct ConversationEmotionCheckIn: View {
    let reflection: ConversationReflection
    @Environment(ConversationCoordinator.self) private var conversation
    @State private var customEmotion = ""
    @FocusState private var customFocused: Bool
    private var customValid: Bool {
        let text = customEmotion.trimmingCharacters(in: .whitespacesAndNewlines)
        return !text.isEmpty && text.count <= 160
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !reflection.awaitingCheckIn {
                Text(CopyKey.reflectionQuestion.resource).font(.subheadline.weight(.semibold))
            }
            if let emotion = reflection.emotion {
                Text(reflection.customEmotion ?? emotion.copy.string).font(.caption).foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 125))], alignment: .leading, spacing: 6) {
                    ForEach(ConversationReflection.Emotion.allCases.filter { $0 != .other }, id: \.self) { emotion in
                        Button {
                            customFocused = false
                            conversation.chooseEmotion(emotion, for: reflection.id)
                        } label: {
                            Text(emotion.copy.resource)
                                .font(.caption).frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("reflectionEmotion-\(emotion.rawValue)")
                    }
                }
                Text(CopyKey.customEmotionAction.resource).font(.caption.weight(.semibold))
                TextField(CopyKey.customEmotionPlaceholder.string, text: $customEmotion)
                    .textFieldStyle(.roundedBorder).focused($customFocused).submitLabel(.done)
                    .accessibilityIdentifier("customEmotionField")
                    .onSubmit { submitCustomEmotion() }
                Text(CopyKey.customEmotionHelp.resource).font(.caption).foregroundStyle(.secondary)
                Button(CopyKey.customEmotionSubmit.resource) { submitCustomEmotion() }
                    .buttonStyle(VolitionButtonStyle()).disabled(!customValid)
                    .accessibilityIdentifier("customEmotionSubmitButton")
            }
        }
        .padding(12).background(VolitionStyle.subtle, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("conversationEmotionCheckIn")
    }
    private func submitCustomEmotion() {
        guard customValid else { return }
        customFocused = false
        conversation.chooseCustomEmotion(customEmotion, for: reflection.id)
    }
}
