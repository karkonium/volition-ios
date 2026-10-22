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
            List {
                Section {
                    Text((onComplete == nil ? CopyKey.volitionAppsHelp : .volitionSetupHelp).resource)
                        .foregroundStyle(.secondary)
                }
                Section {
                    ForEach(apps) { rule in
                        Button { editing = rule } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(rule.name).foregroundStyle(Color.primary)
                                Text(rule.conversationGoal).font(.subheadline).foregroundStyle(Color.secondary).lineLimit(3)
                            }.padding(.vertical, 4)
                        }.accessibilityIdentifier("volitionApp-\(rule.name)")
                    }
                    Button(CopyKey.volitionAddApp.resource, systemImage: "plus") { adding = true }
                        .accessibilityIdentifier("addVolitionAppButton")
                }
                if let onComplete {
                    Section {
                        Button(CopyKey.volitionStartChat.resource, action: onComplete)
                            .disabled(apps.isEmpty)
                            .accessibilityIdentifier("finishVolitionSetupButton")
                    }
                }
            }
            .navigationTitle((onComplete == nil ? CopyKey.volitionApps : .volitionSetupTitle).resource)
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
            Form {
                Section {
                    Button {
                        focused = nil
                        pickerSelection = FamilyActivitySelection()
                        pickerError = nil
                        picking = true
                    } label: {
                        if let token = selection.applicationTokens.first, selection.applicationTokens.count == 1 {
                            if LaunchConfiguration.current.isUITesting { Text("Selected app") }
                            else { Label(token).frame(height: 32) }
                        } else { Label(CopyKey.conversationChooseApp.resource, systemImage: "apps.iphone") }
                    }.accessibilityIdentifier("pickVolitionAppButton")
                    TextField(CopyKey.volitionAppName.resource, text: $name)
                        .focused($focused, equals: .name).accessibilityIdentifier("volitionAppName")
                } footer: {
                    Text(CopyKey.volitionAppNameHelp.resource)
                        .accessibilityIdentifier("volitionAppNameHelp")
                }
                Section {
                    TextEditor(text: $intention)
                        .frame(minHeight: 120)
                        .focused($focused, equals: .intention)
                        .accessibilityLabel(CopyKey.volitionIntention.resource)
                        .accessibilityIdentifier("volitionAppIntention")
                } header: { Text(CopyKey.volitionIntention.resource).textCase(nil) }
                  footer: { Text(CopyKey.volitionIntentionHelp.resource) }
                if let error { Section { Text(error).foregroundStyle(.red) } }
                if rule != nil {
                    Section {
                        Button(CopyKey.volitionRemoveApp.resource, role: .destructive) { confirmingRemoval = true }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .disabled(saving)
            .navigationTitle((rule == nil ? CopyKey.volitionAddApp : .volitionEditApp).resource)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(CopyKey.conversationCancel.resource) { focused = nil; dismiss() }.disabled(saving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(CopyKey.volitionSaveApp.resource) { save() }
                        .disabled(saving).accessibilityIdentifier("saveVolitionAppButton")
                }
            }
            .onAppear {
                if let rule { name = rule.name; intention = rule.conversationGoal; selection = AppSelectionCodec.decode(rule.combinedSelectionData) }
            }
            .sheet(isPresented: $picking) {
                NavigationStack {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(CopyKey.volitionPickOneHelp.resource)
                            .font(.subheadline).foregroundStyle(.secondary).padding()
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
                    .navigationTitle(CopyKey.conversationChooseApp.resource)
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
