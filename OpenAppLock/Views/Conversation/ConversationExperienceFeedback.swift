import SwiftUI

/// Optional feedback describes an actual local decision, never an access condition.
/// The three ratings stay in a single horizontal row. Labels never wrap; larger
/// reading sizes scroll horizontally instead of switching to a vertical layout.
struct ConversationExperienceFeedback: View {
    let entry: ConversationActivityEntry
    @Environment(ConversationCoordinator.self) private var conversation
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(CopyKey.feedbackQuestion.resource).font(.caption).foregroundStyle(.secondary)
            ScrollView(.horizontal) {
                HStack(spacing: 8) { ratingButtons }
            }
            .scrollIndicators(.visible)
            .accessibilityIdentifier("conversationFeedbackOptions")
        }.accessibilityElement(children: .contain).accessibilityIdentifier("conversationExperienceFeedback")
    }
    private var ratingButtons: some View {
        ForEach(ConversationActivityEntry.ExperienceRating.allCases, id: \.self) { rating in
            let selected = entry.experienceRating == rating
            Button {
                conversation.rateExperience(rating, activityID: entry.id)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: rating.symbol).accessibilityHidden(true)
                    Text(rating.copy.resource).lineLimit(1).fixedSize(horizontal: true, vertical: false)
                }
                .font(.caption.weight(selected ? .semibold : .regular))
                .foregroundStyle(Color.primary)
                .padding(.horizontal, 10).frame(minHeight: 44)
                .background(selected ? VolitionStyle.accent.opacity(0.12) : VolitionStyle.subtle, in: Capsule())
                .overlay { Capsule().strokeBorder(selected ? VolitionStyle.accent : VolitionStyle.border) }
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(rating.copy.resource)
            .accessibilityAddTraits(selected ? .isSelected : [])
            .accessibilityIdentifier("experienceRating-\(rating.rawValue)")
        }
    }
}
