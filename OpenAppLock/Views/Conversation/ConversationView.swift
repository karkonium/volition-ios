import FamilyControls
import ManagedSettings
import SwiftData
import SwiftUI

/// Shared chat across all conversation rules. Selecting an app establishes a
/// local request target; model output cannot choose a different app. Full local
/// history is visible, including actual approval/expiry events. Independent per-app unlocks.
/// Saved app names replace nickname entry. The app selector sits above the chat.
/// Only active unlocks display timers; waiting stays in coach replies.
/// Clear app names in messages select their saved app; unresolved sends preserve
/// the draft and draw attention to the picker, respecting Reduce Motion.
/// The composer uses one focus binding. Opening the app picker, sending,
/// leaving Chat/backgrounding, or receiving a grant clears focus. Inputs are
/// disabled only while sending; returning to Chat never restores stale focus.
struct ConversationView: View {
    @Environment(ConversationCoordinator.self) private var conversation
    @Environment(FocusController.self) private var focus
    @Environment(RuleEnforcer.self) private var enforcer
    @Query(sort: BlockingRule.displayOrder) private var rules: [BlockingRule]
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private enum ComposerField: Hashable { case message }
    @FocusState private var focusedField: ComposerField?
    @State private var choosingApp = false
    @State private var followsLatest = true
    @State private var visibleMessages = 60

    var body: some View {
        let motionReduced = reduceMotion
        Group {
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
                        .accessibilityValue(conversation.appSelectionNeeded ? CopyKey.activitySelectionRequired.string : "")
                        .disabled(conversation.isSending)
                        .padding(8)
                        .background(conversation.appSelectionNeeded ? Color.accentColor.opacity(0.12) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 10))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10).stroke(conversation.appSelectionNeeded ? Color.accentColor : Color.clear, lineWidth: 2)
                        }
                        .keyframeAnimator(initialValue: CGFloat.zero, trigger: conversation.selectionAttention) { content, offset in
                            content.offset(x: motionReduced ? 0 : offset)
                        } keyframes: { _ in
                            LinearKeyframe(CGFloat(-7), duration: 0.06)
                            LinearKeyframe(CGFloat(7), duration: 0.08)
                            LinearKeyframe(CGFloat(-4), duration: 0.08)
                            LinearKeyframe(CGFloat(4), duration: 0.08)
                            LinearKeyframe(CGFloat.zero, duration: 0.08)
                        }
                        .sensoryFeedback(.warning, trigger: conversation.selectionAttention)
                        Spacer()
                    }.padding(.horizontal).padding(.vertical, 10)
                    if !conversation.preferences.hasConsent {
                        VStack(alignment: .leading, spacing: 10) {
                            Label(CopyKey.aiConsentTitle.resource, systemImage: "hand.raised").font(.headline)
                            Text(CopyKey.aiConsentDisclosure.resource).font(.footnote).foregroundStyle(.secondary)
                            Button(CopyKey.aiConsentAccept.resource) { conversation.setAIConsent(true) }
                                .buttonStyle(.borderedProminent).accessibilityIdentifier("acceptAIConsentButton")
                        }.padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16)).padding(.horizontal)
                    }
                    if conversation.target == nil || conversation.appSelectionNeeded {
                        Text(conversation.appSelectionNeeded ? conversation.errorMessage ?? CopyKey.conversationSelectAppHelp.string : CopyKey.conversationSelectAppHelp.string)
                            .font(.footnote).foregroundStyle(conversation.appSelectionNeeded ? Color.accentColor : Color.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal).padding(.bottom, 8)
                            .accessibilityIdentifier("conversationAppSelectionHint")
                    }
                    TimelineView(.periodic(from: .now, by: 60)) { timeline in
                        if let appID = conversation.selectedAppID, focus.state.protects(appID: appID, at: timeline.date) {
                            Label(CopyKey.focusProtected.resource, systemImage: "moon.fill")
                                .font(.footnote).foregroundStyle(.secondary).padding(.horizontal).padding(.bottom, 8)
                        }
                    }
                    if !conversation.grants.isEmpty {
                        ScrollView(.horizontal) {
                            HStack(spacing: 12) {
                                ForEach(conversation.grants, id: \.plan.grantID) { grant in
                                    TimelineView(.periodic(from: .now, by: 1)) { timeline in
                                        VStack(alignment: .leading, spacing: 8) {
                                            Label(conversation.appName(for: grant), systemImage: "lock.open").font(.headline)
                                            HStack {
                                                if timeline.date < grant.plan.expiresAt {
                                                    Text(grant.plan.expiresAt, style: .timer).monospacedDigit().font(.title3)
                                                } else { Text(CopyKey.conversationGrantExpired.resource).font(.footnote) }
                                                Spacer()
                                                Button(CopyKey.conversationEndUnlock.resource) {
                                                    Task { await conversation.endUnlock(grantID: grant.plan.grantID); await enforcer.refresh(rules: rules) }
                                                }.font(.footnote).buttonStyle(.bordered)
                                                    .accessibilityIdentifier("endConversationUnlockButton")
                                            }
                                        }
                                        .padding(12).frame(minWidth: 230)
                                        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                                        .task(id: timeline.date >= grant.plan.expiresAt) {
                                            if timeline.date >= grant.plan.expiresAt {
                                                await enforcer.refresh(rules: rules)
                                                await conversation.refresh(snapshots: rules.map(\.dto))
                                            }
                                        }
                                    }
                                }
                            }.padding(.horizontal).padding(.bottom, 8)
                        }.scrollIndicators(.hidden)
                    }
                    ScrollViewReader { proxy in
                        List {
                            if conversation.history.messages.isEmpty {
                                Text(CopyKey.volitionChatEmpty.resource)
                                    .foregroundStyle(.secondary)
                                    .listRowSeparator(.hidden)
                            }
                            if conversation.history.messages.count > visibleMessages {
                                Button(CopyKey.chatLoadEarlier.resource) { visibleMessages += 60 }
                            }
                            ForEach(Array(conversation.history.messages.suffix(visibleMessages))) { item in
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
                        .onScrollGeometryChange(for: Bool.self) { geometry in
                            geometry.contentSize.height - geometry.contentOffset.y - geometry.containerSize.height < 120
                        } action: { _, nearBottom in followsLatest = nearBottom }
                        .onAppear {
                            if let last = conversation.history.messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                        .onChange(of: conversation.history.messages.count) {
                            if followsLatest, let last = conversation.history.messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                    VStack(alignment: .leading) {
                        HStack(alignment: .bottom) {
                            TextField(CopyKey.conversationMessagePrompt.string, text: $conversation.draftMessage, axis: .vertical)
                                .lineLimit(1...5)
                                .focused($focusedField, equals: .message)
                                .disabled(composerDisabled)
                                .accessibilityIdentifier("conversationMessageField")
                            Button(CopyKey.conversationSend.resource, systemImage: "arrow.up.circle.fill") {
                                let text = conversation.draftMessage
                                focusedField = nil
                                conversation.draftMessage = ""
                                followsLatest = true
                                Task {
                                    await conversation.send(text, rules: rules)
                                    if conversation.errorMessage != nil && conversation.draftMessage.isEmpty { conversation.draftMessage = text }
                                    await enforcer.refresh(rules: rules)
                                }
                            }
                            .labelStyle(.iconOnly)
                            .disabled(conversation.draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || conversation.draftMessage.count > 4000 || composerDisabled)
                            .accessibilityIdentifier("conversationSendButton")
                        }
                        if conversation.isSending {
                            Button(CopyKey.conversationCancel.resource) { conversation.cancelRequest() }
                        }
                        if let error = conversation.errorMessage, !conversation.appSelectionNeeded {
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
