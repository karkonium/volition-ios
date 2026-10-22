import FamilyControls
import ManagedSettings
import SwiftData
import SwiftUI

/// Shared chat across all conversation rules. Selecting an app establishes a
/// local request target; model output cannot choose a different app. Full local
/// history is visible, including actual approval/expiry events. Independent per-app unlocks.
/// Saved app names replace nickname entry. The app selector sits above the chat.
/// Per-app waiting periods explicitly say Still blocked; chat remains available.
/// The composer uses one focus binding. Opening the app picker, sending,
/// leaving Chat/backgrounding, or receiving a grant clears focus. Inputs are
/// disabled only while sending; returning to Chat never restores stale focus.
struct ConversationView: View {
    @Environment(ConversationCoordinator.self) private var conversation
    @Environment(RuleEnforcer.self) private var enforcer
    @Query(sort: BlockingRule.displayOrder) private var rules: [BlockingRule]
    @Environment(\.scenePhase) private var scenePhase
    private enum ComposerField: Hashable { case message }
    @FocusState private var focusedField: ComposerField?
    @State private var choosingApp = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            @Bindable var conversation = conversation
            NavigationStack {
                VStack(spacing: 0) {
                    HStack {
                        Button {
                            focusedField = nil
                            choosingApp = true
                        } label: {
                            if conversation.target != nil {
                                Label(conversation.nickname.isEmpty ? CopyKey.conversationTargetGeneric.string : conversation.nickname, systemImage: "app")
                            }
                            else { Label(CopyKey.conversationChooseApp.resource, systemImage: "apps.iphone") }
                        }
                        .accessibilityIdentifier("conversationChooseAppButton")
                        .disabled(conversation.isSending)
                        Spacer()
                    }.padding(.horizontal).padding(.vertical, 10)
                    if let until = conversation.cooldownUntil {
                        VStack(spacing: 6) {
                            Label(CopyKey.volitionWaiting.resource, systemImage: "leaf")
                                .font(.headline)
                            Text(until, style: .timer).monospacedDigit()
                            Text(CopyKey.volitionWaitHelp.resource).font(.footnote).foregroundStyle(.secondary)
                        }
                        .padding().frame(maxWidth: .infinity).background(.thinMaterial)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("conversationCooldown")
                    }
                    ForEach(conversation.grants, id: \.plan.grantID) { grant in
                        TimelineView(.periodic(from: .now, by: 1)) { timeline in
                            VStack {
                                Text(conversation.appName(for: grant)).font(.headline)
                                Text(CopyKey.conversationUnlockedUntil.string(grant.plan.expiresAt.formatted(date: .omitted, time: .shortened)))
                                if timeline.date < grant.plan.expiresAt {
                                    Text(grant.plan.expiresAt, style: .timer)
                                } else { Text(CopyKey.conversationGrantExpired.resource) }
                                Button(CopyKey.conversationEndUnlock.resource) {
                                    Task { await conversation.endUnlock(grantID: grant.plan.grantID); await enforcer.refresh(rules: rules) }
                                }.accessibilityIdentifier("endConversationUnlockButton")
                            }.padding()
                            .task(id: timeline.date >= grant.plan.expiresAt) {
                                if timeline.date >= grant.plan.expiresAt {
                                    await conversation.refresh(snapshots: rules.map(\.dto))
                                    await enforcer.refresh(rules: rules)
                                }
                            }
                        }
                    }
                    ScrollViewReader { proxy in
                        List {
                            if conversation.history.messages.isEmpty {
                                Text(CopyKey.volitionChatEmpty.resource)
                                    .foregroundStyle(.secondary)
                                    .listRowSeparator(.hidden)
                            }
                            ForEach(conversation.history.messages) { item in
                                HStack {
                                    if item.role == .user { Spacer(minLength: 24) }
                                    Text(item.text)
                                        .padding(item.role == .event ? 4 : 12)
                                        .background(item.role == .user ? Color.accentColor.opacity(0.10) : Color.clear, in: RoundedRectangle(cornerRadius: 16))
                                        .textSelection(.enabled)
                                        .foregroundStyle(item.role == .event ? Color.secondary : Color.primary)
                                    if item.role != .user { Spacer(minLength: 24) }
                                }
                                .listRowSeparator(.hidden)
                                .id(item.id)
                                .accessibilityIdentifier("conversationMessage-\(item.role.rawValue)")
                            }
                            if conversation.isSending { ProgressView(CopyKey.conversationWaiting.resource) }
                        }
                        .listStyle(.plain)
                        .scrollDismissesKeyboard(.interactively)
                        .onAppear {
                            if let last = conversation.history.messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                        .onChange(of: conversation.history.messages.count) {
                            if let last = conversation.history.messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                    VStack(alignment: .leading) {
                        HStack(alignment: .bottom) {
                            TextField(CopyKey.conversationMessagePrompt.resource, text: $conversation.draftMessage, axis: .vertical)
                                .lineLimit(1...5)
                                .focused($focusedField, equals: .message)
                                .disabled(composerDisabled)
                                .accessibilityIdentifier("conversationMessageField")
                            Button(CopyKey.conversationSend.resource, systemImage: "arrow.up.circle.fill") {
                                let text = conversation.draftMessage
                                focusedField = nil
                                conversation.draftMessage = ""
                                Task {
                                    await conversation.send(text, rules: rules)
                                    if conversation.errorMessage != nil && conversation.draftMessage.isEmpty { conversation.draftMessage = text }
                                    await enforcer.refresh(rules: rules)
                                }
                            }
                            .labelStyle(.iconOnly)
                            .disabled(conversation.draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || conversation.draftMessage.count > 4000 || conversation.target == nil || composerDisabled)
                            .accessibilityIdentifier("conversationSendButton")
                        }
                        if conversation.isSending {
                            Button(CopyKey.conversationCancel.resource) { conversation.cancelRequest() }
                        }
                        if let error = conversation.errorMessage {
                            Text(error).font(.callout).foregroundStyle(.red)
                                .accessibilityIdentifier("conversationErrorLabel")
                        }
                    }.padding().background(.bar)
                }
                .navigationTitle(CopyKey.conversationChatTitle.resource)
                .navigationBarTitleDisplayMode(.inline)
                .onChange(of: conversation.selectedSection) { _, section in
                    if section != .chat { focusedField = nil }
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase != .active { focusedField = nil }
                }
                .onChange(of: conversation.grants.map(\.plan.grantID)) { _, ids in
                    if !ids.isEmpty { focusedField = nil }
                }
                .onDisappear { focusedField = nil }
                .sheet(isPresented: $choosingApp) {
                    NavigationStack {
                        ConversationAppPicker { token in conversation.select(token); choosingApp = false }
                            .toolbar { ToolbarItem(placement: .cancellationAction) {
                                Button(CopyKey.conversationCancel.resource) { choosingApp = false }
                            } }
                    }
                }
            }
        }
    }

    private var composerDisabled: Bool { conversation.isSending }
}

struct ConversationAppPicker: View {
    var ruleID: UUID? = nil
    let onSelect: (ApplicationToken) -> Void
    @Query(sort: BlockingRule.displayOrder) private var rules: [BlockingRule]
    var body: some View {
        List {
            ForEach(rules.filter { $0.kind == .conversation && $0.isEnabled && (ruleID == nil || $0.id == ruleID) }) { rule in
                Section {
                    ForEach(Array(AppSelectionCodec.decode(rule.combinedSelectionData).applicationTokens), id: \.self) { token in
                        Button { onSelect(token) } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(rule.name)
                                Text(rule.conversationGoal).font(.caption).foregroundStyle(Color.secondary)
                            }
                        }
                            .accessibilityIdentifier("conversationAppOption")
                    }
                }
            }
        }
        .navigationTitle(CopyKey.conversationChooseApp.resource)
    }
}
