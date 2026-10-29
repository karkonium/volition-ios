import FamilyControls
import ManagedSettings
import SwiftData
import SwiftUI

/// First-run setup and the Apps tab share one library. Each entry stores one app,
/// its name and its intention. Setup requires at least one app before Chat.
struct VolitionAppsView: View {
    var onComplete: (() -> Void)? = nil
    @Environment(\.modelContext) private var context
    @Environment(RuleEnforcer.self) private var enforcer
    @Environment(ConversationCoordinator.self) private var conversation
    @Query(sort: \BlockingRule.createdAt) private var rules: [BlockingRule]
    @State private var adding = false
    @State private var editing: BlockingRule?
    private var apps: [BlockingRule] { rules.filter { $0.kind == .conversation && $0.isEnabled } }

    var body: some View {
        NavigationStack {
            VolitionScroll {
                Text((onComplete == nil ? CopyKey.uiAppsIntro : .volitionSetupHelp).resource)
                    .font(.subheadline).foregroundStyle(.secondary)
                VStack(spacing: 10) {
                    VolitionSectionHeading(title: CopyKey.uiSavedApps.string, count: apps.count)
                        .accessibilityIdentifier("compactAppsHeader")
                    ForEach(apps) { rule in
                        let unlocked = conversation.grants.contains { grant in
                            ConversationGrantStore.applicable(to: grant.token, in: [rule.dto]).contains { $0.id == rule.id }
                        }
                        Button { editing = rule } label: {
                            VolitionCard(accented: unlocked) {
                                HStack(alignment: .top, spacing: 12) {
                                    if let token = AppSelectionCodec.decode(rule.combinedSelectionData).applicationTokens.first {
                                        VolitionAppIcon(token: token)
                                    } else { VolitionIcon(symbol: "app") }
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(rule.name).font(.subheadline.weight(.semibold)).foregroundStyle(Color.primary)
                                        Text(rule.conversationGoal).font(.caption).foregroundStyle(Color.secondary).lineLimit(3)
                                        Label((unlocked ? CopyKey.appTemporarilyOpen : .appConversationProtected).resource,
                                            systemImage: unlocked ? "lock.open" : "shield")
                                            .font(.caption2.weight(.medium)).foregroundStyle(Color.secondary)
                                    }
                                    Spacer(minLength: 4)
                                    Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Color.secondary)
                                        .padding(.top, 10)
                                }
                            }
                        }.buttonStyle(.plain).accessibilityIdentifier("volitionApp-\(rule.name)")
                    }
                    Button(CopyKey.volitionAddApp.resource, systemImage: "plus") { adding = true }
                        .buttonStyle(VolitionButtonStyle(primary: false))
                        .accessibilityIdentifier("addVolitionAppButton")
                }
                if let onComplete {
                    Button(CopyKey.volitionStartChat.resource, action: onComplete)
                        .buttonStyle(VolitionButtonStyle())
                        .disabled(apps.isEmpty).accessibilityIdentifier("finishVolitionSetupButton")
                }
            }
            .volitionRoot((onComplete == nil ? CopyKey.volitionApps : .volitionSetupTitle).string)
            .sheet(isPresented: $adding) { VolitionAppEditor() }
            .sheet(item: $editing) { rule in VolitionAppEditor(rule: rule) }
        }
    }
}

/// Choose exactly one app, then name it and write an intention. Categories and
/// websites are rejected. The picker starts empty and closes on one valid app;
/// cancellation preserves the original selection. Bulk/category/website choices
/// stay in the picker with guidance. Name help asks users to match the selected app.
/// Saving immediately reconciles shields and chat context.
struct VolitionAppEditor: View {
    var rule: BlockingRule? = nil
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(RuleEnforcer.self) private var enforcer
    @Environment(ConversationCoordinator.self) private var conversation
    @State private var selection = FamilyActivitySelection()
    @State private var name = ""
    @State private var intention = ""
    @State private var picking = false
    @State private var pickerSelection = FamilyActivitySelection()
    @State private var pickerError: String?
    @State private var saving = false
    @State private var confirmingRemoval = false
    @State private var error: String?
    private enum Field: Hashable { case name, intention }
    @FocusState private var focused: Field?

    var body: some View {
        NavigationStack {
            VolitionScroll {
                VStack(alignment: .leading, spacing: 10) {
                    VolitionSectionHeading(title: CopyKey.uiSelectStep.string)
                        .accessibilityIdentifier("appSelectionStep")
                    Button {
                        focused = nil
                        pickerSelection = FamilyActivitySelection()
                        pickerError = nil
                        picking = true
                    } label: {
                        VolitionCard(accented: selection.applicationTokens.count == 1) {
                            HStack(spacing: 12) {
                                if let token = selection.applicationTokens.first, selection.applicationTokens.count == 1 {
                                    VolitionAppIcon(token: token)
                                    VStack(alignment: .leading, spacing: 4) {
                                        if LaunchConfiguration.current.isUITesting {
                                            Text(CopyKey.uiSelectedApp.resource).font(.subheadline.weight(.semibold))
                                        } else { Label(token).labelStyle(.titleOnly).font(.subheadline.weight(.semibold)) }
                                        Text(CopyKey.uiChangeApp.resource).font(.caption).foregroundStyle(VolitionStyle.accent)
                                    }
                                    Spacer(minLength: 4)
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(VolitionStyle.accent)
                                } else {
                                    VolitionIcon(symbol: "apps.iphone", accented: true)
                                    Text(CopyKey.conversationChooseApp.resource).font(.subheadline.weight(.semibold))
                                    Spacer(minLength: 4)
                                    Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                                }
                            }.foregroundStyle(Color.primary)
                        }
                    }
                    .buttonStyle(.plain).accessibilityIdentifier("pickVolitionAppButton")
                }
                VolitionCard {
                    VolitionSectionHeading(title: CopyKey.uiNameStep.string)
                    TextField(CopyKey.volitionAppName.string, text: $name)
                        .textFieldStyle(.roundedBorder).submitLabel(.next)
                        .onSubmit { focused = .intention }
                        .focused($focused, equals: .name).accessibilityIdentifier("volitionAppName")
                    Text(CopyKey.volitionAppNameHelp.resource).font(.caption).foregroundStyle(.secondary)
                        .accessibilityIdentifier("volitionAppNameHelp")
                }
                VolitionCard {
                    VolitionSectionHeading(title: CopyKey.uiIntentionStep.string)
                    Text(CopyKey.volitionIntentionHelp.resource).font(.caption).foregroundStyle(.secondary)
                    TextEditor(text: $intention)
                        .frame(minHeight: 100)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(VolitionStyle.background, in: RoundedRectangle(cornerRadius: 12))
                        .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(VolitionStyle.border, lineWidth: 1) }
                        .focused($focused, equals: .intention)
                        .accessibilityLabel(CopyKey.volitionIntention.resource)
                        .accessibilityIdentifier("volitionAppIntention")
                }
                if let error { Text(error).font(.subheadline).foregroundStyle(.red) }
                if rule != nil {
                    Button(CopyKey.volitionRemoveApp.resource, role: .destructive) { confirmingRemoval = true }
                        .buttonStyle(VolitionButtonStyle(primary: false))
                }
            }
            .tint(VolitionStyle.accent)
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .disabled(saving)
            .navigationTitle((rule == nil ? CopyKey.volitionAddApp : .volitionEditApp).resource)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(CopyKey.conversationCancel.resource) { focused = nil; dismiss() }.disabled(saving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(CopyKey.volitionSaveApp.resource) { save() }
                        .disabled(saving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || name.count > 100 || intention.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || intention.count > 2000 || selection.applicationTokens.count != 1)
                        .accessibilityIdentifier("saveVolitionAppButton")
                }
            }
            .onAppear {
                if let rule { name = rule.name; intention = rule.conversationGoal; selection = AppSelectionCodec.decode(rule.combinedSelectionData) }
            }
            .sheet(isPresented: $picking) {
                NavigationStack {
                    VStack(alignment: .leading, spacing: 0) {
                        VolitionCard(accented: true) {
                            Label(CopyKey.uiPickerGuidanceTitle.resource, systemImage: "hand.tap")
                                .font(.subheadline.weight(.semibold))
                            Text(CopyKey.uiPickerGuidanceDetail.resource).font(.caption).foregroundStyle(.secondary)
                        }.padding(.horizontal, 16).padding(.vertical, 10)
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier("nativePickerGuidance")
                        if let pickerError {
                            Text(pickerError).foregroundStyle(.red).padding(.horizontal)
                                .accessibilityIdentifier("volitionPickerError")
                        }
                        if LaunchConfiguration.current.isUITesting {
                            List {
                                Button("Test app") { pickTestApps([99]) }
                                    .accessibilityIdentifier("mockVolitionAppOption")
                                Button("Test multiple apps") { pickTestApps([98, 99]) }
                                    .accessibilityIdentifier("mockVolitionMultipleAppsOption")
                            }
                        } else {
                            FamilyActivityPicker(selection: $pickerSelection)
                        }
                    }
                    .volitionRoot(CopyKey.conversationChooseApp.string)
                    .tint(VolitionStyle.accent)
                    .toolbar { ToolbarItem(placement: .cancellationAction) {
                        Button(CopyKey.conversationCancel.resource) { picking = false }
                            .accessibilityIdentifier("cancelVolitionAppPickerButton")
                    } }
                    .onChange(of: pickerSelection) { _, proposed in
                        guard picking else { return }
                        guard AppSelectionCodec.count(of: proposed) > 0 else { pickerError = nil; return }
                        do {
                            _ = try VolitionApps.selectedApp(in: proposed)
                            selection = proposed
                            pickerError = nil
                            picking = false
                        } catch { pickerError = CopyKey.volitionSingleAppError.string }
                    }
                }
            }
            .confirmationDialog(CopyKey.volitionRemoveApp.string, isPresented: $confirmingRemoval) {
                Button(CopyKey.volitionRemoveApp.resource, role: .destructive) { remove() }
            } message: { Text(CopyKey.volitionRemoveMessage.resource) }
        }
        .interactiveDismissDisabled(saving)
    }

    private func pickTestApps(_ bytes: [UInt8]) {
        var proposed = FamilyActivitySelection()
        proposed.applicationTokens = Set(bytes.compactMap { byte in
            guard let data = try? JSONSerialization.data(withJSONObject: ["data": Data([byte]).base64EncodedString()]) else { return nil }
            return try? JSONDecoder().decode(ApplicationToken.self, from: data)
        })
        pickerSelection = proposed
    }

    private func save() {
        focused = nil
        do {
            _ = try VolitionApps.save(name: name, intention: intention, selection: selection, editing: rule, in: context)
            reconcile()
        } catch { self.error = (error as? VolitionApps.ValidationError)?.errorDescription ?? CopyKey.volitionSaveError.string }
    }
    private func remove() {
        guard let rule else { return }
        focused = nil
        do {
            rule.isEnabled = false
            try context.save()
            reconcile()
        } catch { context.rollback(); self.error = CopyKey.volitionSaveError.string }
    }
    private func reconcile() {
        saving = true
        conversation.cancelRequest()
        Task {
            do {
                let rules = try context.fetch(FetchDescriptor<BlockingRule>())
                await enforcer.refresh(rules: rules)
                await conversation.refresh(snapshots: rules.map(\.dto))
                dismiss()
            } catch { self.error = CopyKey.volitionSaveError.string }
            saving = false
        }
    }
}
