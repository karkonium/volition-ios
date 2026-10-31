import SwiftUI

/// Left-aligned form rows share spacing and dividers. Multiple-choice questions
/// use checkboxes; the session-style question uses one selected radio option.
struct VolitionUsageProfileFields: View {
    @Binding var profile: ConversationUsageProfile
    var onExpand: () -> Void = {}
    @State private var purposesExpanded = false
    @State private var changesExpanded = false
    @State private var styleExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            question(.profilePurpose, expanded: $purposesExpanded, id: "profilePurposes")
            if purposesExpanded {
                options(hint: .profileSelectMultiple, id: "profilePurposesSelectMultiple") {
                    ForEach(ConversationUsageProfile.Purpose.allCases, id: \.self) { purpose in
                        choice(purpose.copy, selected: profile.purposes.contains(purpose)) {
                            if !profile.purposes.insert(purpose).inserted { profile.purposes.remove(purpose) }
                        }.accessibilityIdentifier("profilePurpose-\(purpose.rawValue)")
                    }
                }
            }
            Divider()
            question(.profileChange, expanded: $changesExpanded, id: "profileChanges")
            if changesExpanded {
                options(hint: .profileSelectMultiple, id: "profileChangesSelectMultiple") {
                    ForEach(ConversationUsageProfile.Change.allCases, id: \.self) { change in
                        choice(change.copy, selected: profile.changes.contains(change)) {
                            if change == .unsure {
                                profile.changes = profile.changes.contains(.unsure) ? [] : [.unsure]
                            } else {
                                profile.changes.remove(.unsure)
                                if !profile.changes.insert(change).inserted { profile.changes.remove(change) }
                            }
                        }.accessibilityIdentifier("profileChange-\(change.rawValue)")
                    }
                }
            }
            Divider()
            question(.profileStyle, expanded: $styleExpanded, id: "profileSessionStyle")
            if styleExpanded {
                options(hint: .uiSelectOne, id: "profileStyleSelectOne") {
                    ForEach(ConversationUsageProfile.SessionStyle.allCases, id: \.self) { style in
                        choice(style.copy, selected: profile.sessionStyle == style, multiple: false) {
                            profile.sessionStyle = style
                        }.accessibilityIdentifier("profileStyle-\(style.rawValue)")
                    }
                }
            }
            Text(CopyKey.profileOptional.resource).font(.caption).foregroundStyle(Color.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func question(_ copy: CopyKey, expanded: Binding<Bool>, id: String) -> some View {
        Button {
            if !expanded.wrappedValue { onExpand() }
            withAnimation(.easeInOut(duration: 0.2)) { expanded.wrappedValue.toggle() }
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Text(copy.resource).font(.subheadline).foregroundStyle(Color.primary)
                    .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: expanded.wrappedValue ? "chevron.up" : "chevron.down")
                    .font(.caption).foregroundStyle(Color.secondary).accessibilityHidden(true)
            }.padding(.vertical, 4).frame(minHeight: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain).accessibilityIdentifier(id)
        .accessibilityValue(expanded.wrappedValue ? "Expanded" : "Collapsed")
    }

    private func options<Content: View>(hint: CopyKey, id: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(hint.resource).font(.caption).foregroundStyle(Color.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal, 4).padding(.bottom, 8)
                .accessibilityIdentifier(id)
            content()
        }
        .padding(12)
        .background(VolitionStyle.subtle, in: RoundedRectangle(cornerRadius: 12))
    }

    private func choice(_ copy: CopyKey, selected: Bool, multiple: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                Text(copy.resource).font(.subheadline).foregroundStyle(Color.primary)
                    .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Image(systemName: multiple ? (selected ? "checkmark.square.fill" : "square") :
                    (selected ? "largecircle.fill.circle" : "circle"))
                    .foregroundStyle(selected ? VolitionStyle.accent : Color.secondary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 4).padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityValue(selected ? "Selected" : "")
    }
}
