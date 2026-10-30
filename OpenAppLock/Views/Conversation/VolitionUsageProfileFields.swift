import SwiftUI

/// Multi-choice disclosures use checkboxes and an expanded selection hint,
/// without collapsed answer summaries. Questions precede their controls.
/// No usage statistics or numeric limits are required; editing uses the same UI.
struct VolitionUsageProfileFields: View {
    @Binding var profile: ConversationUsageProfile
    var onExpand: () -> Void = {}
    @State private var purposesExpanded = false
    @State private var changesExpanded = false
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            DisclosureGroup(isExpanded: $purposesExpanded) {
                Text(CopyKey.profileSelectMultiple.resource)
                    .font(.caption).foregroundStyle(Color.secondary)
                    .accessibilityIdentifier("profilePurposesSelectMultiple")
                ForEach(ConversationUsageProfile.Purpose.allCases, id: \.self) { purpose in
                    choice(purpose.copy, selected: profile.purposes.contains(purpose)) {
                        if !profile.purposes.insert(purpose).inserted { profile.purposes.remove(purpose) }
                    }.accessibilityIdentifier("profilePurpose-\(purpose.rawValue)")
                }
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(CopyKey.profilePurpose.resource).foregroundStyle(Color.primary)
                }.frame(minHeight: 44).accessibilityElement(children: .combine).accessibilityIdentifier("profilePurposes")
            }
            DisclosureGroup(isExpanded: $changesExpanded) {
                Text(CopyKey.profileSelectMultiple.resource)
                    .font(.caption).foregroundStyle(Color.secondary)
                    .accessibilityIdentifier("profileChangesSelectMultiple")
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
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(CopyKey.profileChange.resource).foregroundStyle(Color.primary)
                }.frame(minHeight: 44).accessibilityElement(children: .combine).accessibilityIdentifier("profileChanges")
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(CopyKey.profileStyle.resource).foregroundStyle(Color.primary)
                    .accessibilityIdentifier("profileSessionStyleQuestion")
                Picker(CopyKey.profileStyle.string, selection: $profile.sessionStyle) {
                    ForEach(ConversationUsageProfile.SessionStyle.allCases, id: \.self) { style in
                        Text(style.copy.resource).tag(style)
                    }
                }
                .pickerStyle(.menu).labelsHidden()
                .frame(minHeight: 44).accessibilityIdentifier("profileSessionStyle")
            }
            Text(CopyKey.profileOptional.resource).font(.caption).foregroundStyle(Color.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .onChange(of: purposesExpanded) { _, expanded in if expanded { onExpand() } }
        .onChange(of: changesExpanded) { _, expanded in if expanded { onExpand() } }
    }

    private func choice(_ copy: CopyKey, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(copy.resource).foregroundStyle(Color.primary)
                Spacer()
                Image(systemName: selected ? "checkmark.square.fill" : "square")
                    .foregroundStyle(selected ? Color.accentColor : Color.secondary)
            }.frame(minHeight: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityValue(selected ? "Selected" : "")
    }
}
