import SwiftUI

/// Optional disclosures keep per-app setup compact. No usage statistics or
/// numeric limits are required. The same controls edit existing profiles.
struct VolitionUsageProfileFields: View {
    @Binding var profile: ConversationUsageProfile
    var onExpand: () -> Void = {}
    @State private var purposesExpanded = false
    @State private var changesExpanded = false
    var body: some View {
        Section {
            DisclosureGroup(isExpanded: $purposesExpanded) {
                ForEach(ConversationUsageProfile.Purpose.allCases, id: \.self) { purpose in
                    choice(purpose.copy, selected: profile.purposes.contains(purpose)) {
                        if !profile.purposes.insert(purpose).inserted { profile.purposes.remove(purpose) }
                    }.accessibilityIdentifier("profilePurpose-\(purpose.rawValue)")
                }
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(CopyKey.profilePurpose.resource).foregroundStyle(Color.primary)
                    if !profile.purposes.isEmpty {
                        Text(ConversationUsageProfile.Purpose.allCases.filter { profile.purposes.contains($0) }
                            .map { $0.copy.string }.joined(separator: ", "))
                            .font(.caption).foregroundStyle(Color.secondary)
                    }
                }.accessibilityElement(children: .combine).accessibilityIdentifier("profilePurposes")
            }
            DisclosureGroup(isExpanded: $changesExpanded) {
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
                    if !profile.changes.isEmpty {
                        Text(ConversationUsageProfile.Change.allCases.filter { profile.changes.contains($0) }
                            .map { $0.copy.string }.joined(separator: ", "))
                            .font(.caption).foregroundStyle(Color.secondary)
                    }
                }.accessibilityElement(children: .combine).accessibilityIdentifier("profileChanges")
            }
            Picker(selection: $profile.sessionStyle) {
                ForEach(ConversationUsageProfile.SessionStyle.allCases, id: \.self) { style in
                    Text(style.copy.resource).tag(style)
                }
            } label: { Text(CopyKey.profileStyle.resource) }
                .accessibilityIdentifier("profileSessionStyle")
        } footer: { Text(CopyKey.profileOptional.resource) }
        .onChange(of: purposesExpanded) { _, expanded in if expanded { onExpand() } }
        .onChange(of: changesExpanded) { _, expanded in if expanded { onExpand() } }
    }

    private func choice(_ copy: CopyKey, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(copy.resource).foregroundStyle(Color.primary)
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? Color.accentColor : Color.secondary)
            }
        }
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityValue(selected ? "Selected" : "")
    }
}
