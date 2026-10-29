import FamilyControls
import ManagedSettings
import SwiftData
import SwiftUI

/// Shared chat across all conversation rules. Selecting an app establishes a
/// local request target; model output cannot choose a different app. Full local
/// history is visible, including actual approval/expiry events. Independent per-app unlocks.
/// Saved app names replace nickname entry. The app selector sits above the chat.
/// Only unlocks display top timers. Soft reflection lives inline above the composer.
/// A stable bottom target follows sends/loading/layout changes only while following
/// latest content; user-driven scrolling suspends following until bottom or Send.
/// Clear app names in messages select their saved app; unresolved sends preserve
/// the draft and draw attention to the picker, respecting Reduce Motion.
/// The composer uses one focus binding. Opening the app picker, sending,
/// leaving Chat/backgrounding, or receiving a grant clears focus. Inputs are
/// disabled only while sending; returning to Chat never restores stale focus.
struct ConversationView: View {
    @Environment(ConversationCoordinator.self) private var conversation
    @Environment(RuleEnforcer.self) private var enforcer
    @Query(sort: BlockingRule.displayOrder) private var rules: [BlockingRule]
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private enum ComposerField: Hashable { case message }
    @FocusState private var focusedField: ComposerField?
    @State private var choosingApp = false
    @State private var followingLatest = true
    @State private var userScrolling = false
    @State private var nearBottom = true

    var body: some View {
        let motionReduced = reduceMotion
        Group {
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
                    if conversation.target == nil || conversation.appSelectionNeeded {
                        Text(conversation.appSelectionNeeded ? conversation.errorMessage ?? CopyKey.conversationSelectAppHelp.string : CopyKey.conversationSelectAppHelp.string)
                            .font(.footnote).foregroundStyle(conversation.appSelectionNeeded ? Color.accentColor : Color.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal).padding(.bottom, 8)
                            .accessibilityIdentifier("conversationAppSelectionHint")
                    }
                    if let summary = conversation.selectedActivitySummary {
                        Text(CopyKey.sessionCounts.string(summary.sameAppShortGrantsToday, summary.sameAppLongGrantsToday))
                            .font(.caption).foregroundStyle(.secondary)
                            .accessibilityHint(CopyKey.sessionCountsHelp.string)
                            .accessibilityIdentifier("conversationSessionCounts")
                    }
                    if let until = conversation.cooldownUntil {
                        Text(CopyKey.dealBlockedUntil.string(until.formatted(date: Calendar.current.isDateInToday(until) ? .omitted : .abbreviated, time: .shortened)))
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    ForEach(conversation.displayedGrants, id: \.plan.grantID) { grant in
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
                    transcript
                        .safeAreaInset(edge: .bottom, spacing: 0) { composer }
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

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if conversation.history.messages.isEmpty {
                        Text(CopyKey.volitionChatEmpty.resource).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    ForEach(conversation.history.messages) { item in
                        HStack {
                            if item.role == .user { Spacer(minLength: 24) }
                            Text(item.text)
                                .padding(item.role == .event ? 4 : 12)
                                .background(item.role == .user ? Color.accentColor.opacity(0.10) : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 16))
                                .textSelection(.enabled)
                                .foregroundStyle(item.role == .event ? Color.secondary : Color.primary)
                            if item.role != .user { Spacer(minLength: 24) }
                        }
                        .id(item.id)
                        .accessibilityIdentifier("conversationMessage-\(item.role.rawValue)")
                    }
                    if conversation.isSending {
                        ProgressView(CopyKey.conversationWaiting.resource)
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier("conversationThinking")
                    }
                    ForEach(conversation.pendingReflections) { reflection in
                        if reflection.isDeal {
                            ConversationDealCard(reflection: reflection, snapshots: { rules.filter { !$0.isDeleted }.map(\.dto) })
                        } else {
                            ConversationReflectionCard(reflection: reflection, snapshots: { rules.filter { !$0.isDeleted }.map(\.dto) })
                        }
                    }
                }.padding(.horizontal).padding(.top, 12)
                Color.clear.frame(height: 12).id("conversationBottom")
            }
            .accessibilityIdentifier("conversationTranscript")
            .defaultScrollAnchor(.bottom, for: .initialOffset)
            .scrollDismissesKeyboard(.interactively)
            .onScrollPhaseChange { _, phase in
                userScrolling = phase == .interacting || phase == .decelerating
                if userScrolling { followingLatest = nearBottom }
            }
            .onScrollGeometryChange(for: ConversationScrollMetrics.self) { geometry in
                .init(height: geometry.contentSize.height, viewport: geometry.containerSize.height,
                    nearBottom: geometry.contentOffset.y + geometry.containerSize.height >= geometry.contentSize.height + geometry.contentInsets.bottom - 80)
            } action: { old, new in
                nearBottom = new.nearBottom
                if userScrolling { followingLatest = new.nearBottom }
                if followingLatest && (old.height != new.height || old.viewport != new.viewport) {
                    proxy.scrollTo("conversationBottom", anchor: .bottom)
                }
            }
            .onChange(of: conversation.isSending) { _, sending in
                if sending { followingLatest = true }
                if followingLatest { proxy.scrollTo("conversationBottom", anchor: .bottom) }
            }
            .onChange(of: conversation.history.messages.count) {
                if followingLatest { proxy.scrollTo("conversationBottom", anchor: .bottom) }
            }
            .overlay(alignment: .bottomTrailing) {
                if !followingLatest {
                    Button(CopyKey.conversationJumpLatest.resource, systemImage: "arrow.down") {
                        followingLatest = true
                        proxy.scrollTo("conversationBottom", anchor: .bottom)
                    }.buttonStyle(.borderedProminent).padding()
                        .accessibilityIdentifier("conversationJumpLatest")
                }
            }
        }
    }

    private var composer: some View {
        @Bindable var conversation = conversation
        return VStack(alignment: .leading) {
            HStack(alignment: .bottom) {
                TextField(CopyKey.conversationMessagePrompt.string, text: $conversation.draftMessage, axis: .vertical)
                    .lineLimit(1...5)
                    .focused($focusedField, equals: .message)
                    .disabled(composerDisabled)
                    .accessibilityIdentifier("conversationMessageField")
                Button(CopyKey.conversationSend.resource, systemImage: "arrow.up.circle.fill") {
                    followingLatest = true
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

private struct ConversationScrollMetrics: Equatable {
    let height: CGFloat
    let viewport: CGFloat
    let nearBottom: Bool
}
