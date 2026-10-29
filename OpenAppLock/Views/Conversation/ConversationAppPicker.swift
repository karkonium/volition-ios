import FamilyControls
import ManagedSettings
import SwiftData
import SwiftUI

/// Searches saved names/intentions locally. Switching targets preserves the draft;
/// status is informational and never overrides focus or grant enforcement.
struct ConversationAppPicker: View {
    var ruleID: UUID? = nil
    let onSelect: (ApplicationToken) -> Void
    @Environment(ConversationCoordinator.self) private var conversation
    @Environment(FocusController.self) private var focus
    @Query(sort: BlockingRule.displayOrder) private var rules: [BlockingRule]
    @State private var search = ""
    @State private var adding = false

    private var apps: [BlockingRule] {
        rules.filter { $0.kind == .conversation && $0.isEnabled && (ruleID == nil || $0.id == ruleID) }
    }
    private var results: [BlockingRule] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return apps.filter { query.isEmpty || $0.name.localizedStandardContains(query) || $0.conversationGoal.localizedStandardContains(query) }
    }

    var body: some View {
        VolitionScroll {
            Text(CopyKey.uiPickerIntro.resource).font(.subheadline).foregroundStyle(.secondary)
            VolitionSectionHeading(title: CopyKey.uiSavedApps.string, count: results.count)
            if results.isEmpty {
                VolitionCard {
                    VolitionIcon(symbol: apps.isEmpty ? "apps.iphone" : "magnifyingglass")
                    Text((apps.isEmpty ? CopyKey.uiPickerEmpty : .uiSearchEmpty).resource)
                        .font(.headline).accessibilityIdentifier("appSearchEmpty")
                    Text((apps.isEmpty ? CopyKey.uiPickerEmptyHelp : .uiSearchEmptyHelp).resource)
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            TimelineView(.periodic(from: .now, by: 30)) { timeline in
                VStack(spacing: 10) {
                    ForEach(results) { rule in
                        ForEach(Array(AppSelectionCodec.decode(rule.combinedSelectionData).applicationTokens), id: \.self) { token in
                            appRow(rule, token: token, date: timeline.date)
                        }
                    }
                }
            }
            Button(CopyKey.volitionAddApp.resource, systemImage: "plus") { adding = true }
                .buttonStyle(VolitionButtonStyle(primary: false))
                .accessibilityIdentifier("addAppFromChooserButton")
        }
        .volitionRoot(CopyKey.conversationChooseApp.string)
        .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: CopyKey.uiSearchApps.string)
        .sheet(isPresented: $adding) { VolitionAppEditor() }
    }

    private func appRow(_ rule: BlockingRule, token: ApplicationToken, date: Date) -> some View {
        let selected = conversation.target == token
        let protected = focus.state.protects(appID: rule.id, at: date)
        let open = conversation.grants.contains { $0.token == token && $0.plan.expiresAt > date }
        return Button { onSelect(token) } label: {
            VolitionCard(accented: selected) {
                HStack(alignment: .top, spacing: 12) {
                    VolitionAppIcon(token: token)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(rule.name).font(.subheadline.weight(.semibold)).foregroundStyle(Color.primary)
                        Text(rule.conversationGoal).font(.caption).foregroundStyle(Color.secondary).lineLimit(2)
                        Label((protected ? CopyKey.uiFocusStatus : open ? .appTemporarilyOpen : .appConversationProtected).resource,
                            systemImage: protected ? "moon" : open ? "lock.open" : "shield")
                            .font(.caption2.weight(.medium)).foregroundStyle(Color.secondary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .font(.title3).foregroundStyle(selected ? VolitionStyle.accent : Color.secondary.opacity(0.5))
                        .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("conversationAppOption")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityValue(selected ? CopyKey.uiSelected.string : "")
    }
}

/// Apple's token label renders the app icon without extracting its private identity.
struct VolitionAppIcon: View {
    let token: ApplicationToken
    var body: some View {
        Group {
            if LaunchConfiguration.current.isUITesting {
                VolitionIcon(symbol: "app.fill")
            } else {
                Label(token).labelStyle(.iconOnly).frame(width: 36, height: 36)
            }
        }.accessibilityHidden(true)
    }
}
