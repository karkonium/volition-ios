import FamilyControls
import ManagedSettings
import SwiftData
import SwiftUI

/// Shared chat and independent grants. Notices/grants scroll with messages, while
/// the selected-app control and keyboard-safe composer remain easy to reach.
/// Cancelling restores the session draft; late completions cannot alter a new one.
/// Waits are labeled within coach replies, never shown as unlock countdowns.
struct ConversationView: View {
    @Environment(ConversationCoordinator.self) private var conversation
    @Environment(FocusController.self) private var focus
    @Environment(RuleEnforcer.self) private var enforcer
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @Query(sort: BlockingRule.displayOrder) private var rules: [BlockingRule]
    @FocusState private var messageFocused: Bool
    @State private var choosingApp = false
    @State private var reviewingSharing = false
    @State private var followsLatest = true
    @State private var visibleMessages = 60

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                appSelector.padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 6)
                ScrollViewReader { proxy in
                    List {
                        if !conversation.preferences.hasConsent { consentPrompt.chatRow() }
                        if conversation.target == nil || conversation.appSelectionNeeded {
                            Text(conversation.appSelectionNeeded ? conversation.errorMessage ?? CopyKey.conversationSelectAppHelp.string : CopyKey.conversationSelectAppHelp.string)
                                .font(.footnote).foregroundStyle(conversation.appSelectionNeeded ? VolitionStyle.accent : Color.secondary)
                                .accessibilityIdentifier("conversationAppSelectionHint").chatRow()
                        }
                        TimelineView(.periodic(from: .now, by: 60)) { timeline in
                            if let appID = conversation.selectedAppID, focus.state.protects(appID: appID, at: timeline.date) {
                                Label(CopyKey.focusProtected.resource, systemImage: "moon.fill")
                                    .font(.footnote).foregroundStyle(.secondary)
                            }
                        }.chatRow()
                        if !conversation.grants.isEmpty { grantCards.chatRow() }
                        if conversation.history.messages.isEmpty { emptyConversation.chatRow() }
                        if conversation.history.messages.count > visibleMessages {
                            Button(CopyKey.chatLoadEarlier.resource) { visibleMessages += 60 }
                                .buttonStyle(VolitionButtonStyle(primary: false)).chatRow()
                        }
                        ForEach(Array(conversation.history.messages.suffix(visibleMessages))) { item in
                            message(item).id(item.id)
                                .accessibilityIdentifier("conversationMessage-\(item.role.rawValue)").chatRow()
                        }
                        if let error = conversation.errorMessage, !conversation.appSelectionNeeded {
                            failureNotice(error).chatRow()
                        }
                        Color.clear.frame(height: 1).id("latest")
                            .listRowInsets(EdgeInsets()).listRowSeparator(.hidden).listRowBackground(Color.clear)
                    }
                    .listStyle(.plain).scrollContentBackground(.hidden)
                    .environment(\.defaultMinListRowHeight, 0)
                    .scrollDismissesKeyboard(.interactively)
                    .onScrollGeometryChange(for: Bool.self) { geometry in
                        geometry.contentSize.height - geometry.contentOffset.y - geometry.containerSize.height < 120
                    } action: { _, nearBottom in followsLatest = nearBottom }
                    .onAppear {
                        if !conversation.history.messages.isEmpty { proxy.scrollTo("latest", anchor: .bottom) }
                    }
                    .onChange(of: conversation.history.messages.count) {
                        if followsLatest { proxy.scrollTo("latest", anchor: .bottom) }
                    }
                    .onChange(of: conversation.errorMessage) {
                        if followsLatest && !conversation.appSelectionNeeded { proxy.scrollTo("latest", anchor: .bottom) }
                    }
                    .overlay(alignment: .bottomTrailing) {
                        if !followsLatest && !conversation.history.messages.isEmpty {
                            Button {
                                followsLatest = true; proxy.scrollTo("latest", anchor: .bottom)
                            } label: {
                                Label(CopyKey.uiLatestMessages.resource, systemImage: "arrow.down")
                                    .font(.caption.weight(.semibold)).padding(12)
                                    .background(VolitionStyle.surface, in: Capsule())
                                    .overlay { Capsule().strokeBorder(VolitionStyle.border) }
                            }.buttonStyle(.plain).padding(12)
                        }
                    }
                }
                composer
            }
            .frame(maxWidth: 720).frame(maxWidth: .infinity)
            .background(VolitionStyle.background)
            .volitionRoot(CopyKey.conversationChatTitle.string)
            .onChange(of: conversation.selectedSection) { _, section in
                if section != .chat { messageFocused = false }
            }
            .onChange(of: scenePhase) { _, phase in if phase != .active { messageFocused = false } }
            .onChange(of: conversation.grants.map(\.plan.grantID)) { _, ids in if !ids.isEmpty { messageFocused = false } }
            .onDisappear { messageFocused = false }
            .sheet(isPresented: $reviewingSharing) { AIConsentReviewView() }
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

    private var appSelector: some View {
        let motionReduced = reduceMotion
        return Button { messageFocused = false; choosingApp = true } label: {
            VolitionCard(accented: conversation.appSelectionNeeded) {
                HStack(spacing: 12) {
                    if let token = conversation.target { VolitionAppIcon(token: token) }
                    else { VolitionIcon(symbol: "apps.iphone", accented: true) }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(CopyKey.uiRequestFor.resource).font(.caption).foregroundStyle(Color.secondary)
                        Text(conversation.target == nil ? CopyKey.conversationChooseApp.string :
                            conversation.nickname.isEmpty ? CopyKey.conversationTargetGeneric.string : conversation.nickname)
                            .font(.subheadline.weight(.semibold)).foregroundStyle(Color.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.up.chevron.down").font(.caption.weight(.semibold))
                        .foregroundStyle(Color.secondary).accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(.plain).accessibilityIdentifier("conversationChooseAppButton")
        .accessibilityValue(conversation.appSelectionNeeded ? CopyKey.activitySelectionRequired.string : "")
        .disabled(conversation.isSending)
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
    }

    private var consentPrompt: some View {
        VolitionCard {
            Label(CopyKey.uiAISharingOff.resource, systemImage: "hand.raised").font(.subheadline.weight(.semibold))
            Text(CopyKey.uiAISharingHelp.resource).font(.footnote).foregroundStyle(.secondary)
            Button(CopyKey.uiReviewSharing.resource) { messageFocused = false; reviewingSharing = true }
                .buttonStyle(VolitionButtonStyle(primary: false)).accessibilityIdentifier("reviewAIConsentButton")
        }
    }
    private var emptyConversation: some View {
        VolitionCard {
            HStack(spacing: 10) {
                VolitionIcon(symbol: "bubble.left.and.bubble.right", accented: true)
                Text(CopyKey.volitionChatEmpty.resource).font(.headline)
            }
            Text(CopyKey.uiChatIntro.resource).font(.subheadline).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var grantCards: some View {
        if typeSize.isAccessibilitySize {
            VStack(spacing: 10) { ForEach(conversation.grants, id: \.plan.grantID) { grant in grantCard(grant) } }
        } else {
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(conversation.grants, id: \.plan.grantID) { grant in grantCard(grant).frame(width: 260) }
                }
            }.scrollIndicators(.visible)
        }
    }
    private func grantCard(_ grant: ConversationGrantStore.Grant) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            VolitionCard(accented: true) {
                Label(conversation.appName(for: grant), systemImage: "lock.open").font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                if timeline.date < grant.plan.expiresAt {
                    Text(grant.plan.expiresAt, style: .timer).monospacedDigit().font(.title2.weight(.medium))
                        .accessibilityLabel(CopyKey.appTemporarilyOpen.string)
                } else { Text(CopyKey.conversationGrantExpired.resource).font(.footnote) }
                Button(CopyKey.conversationEndUnlock.resource) {
                    Task { await conversation.endUnlock(grantID: grant.plan.grantID); await enforcer.refresh(rules: rules) }
                }.buttonStyle(VolitionButtonStyle(primary: false)).accessibilityIdentifier("endConversationUnlockButton")
            }
            .task(id: timeline.date >= grant.plan.expiresAt) {
                if timeline.date >= grant.plan.expiresAt {
                    await enforcer.refresh(rules: rules)
                    await conversation.refresh(snapshots: rules.map(\.dto))
                }
            }
        }
    }

    private func message(_ item: ConversationMessage) -> some View {
        HStack(alignment: .top, spacing: 0) {
            if item.role == .user { Spacer(minLength: typeSize.isAccessibilitySize ? 8 : 32) }
            VStack(alignment: .leading, spacing: 5) {
                if item.role == .assistant { replyHeader(item) }
                Text(item.text).font(item.role == .event ? .caption : .body)
                    .lineSpacing(item.role == .event ? 0 : 2).padding(item.role == .event ? 4 : 12)
                    .background(item.role == .user ? VolitionStyle.accent.opacity(0.08) :
                        item.role == .assistant ? VolitionStyle.surface : Color.clear, in: RoundedRectangle(cornerRadius: 14))
                    .overlay {
                        if item.role == .assistant { RoundedRectangle(cornerRadius: 14).strokeBorder(VolitionStyle.border) }
                    }
                    .textSelection(.enabled).foregroundStyle(item.role == .event ? Color.secondary : Color.primary)
            }
            if item.role != .user { Spacer(minLength: typeSize.isAccessibilitySize ? 0 : 24) }
        }
    }
    @ViewBuilder private func replyHeader(_ message: ConversationMessage) -> some View {
        if let entry = conversation.history.activityLog.last,
           entry.date <= message.date, entry.coachResponse == message.text,
           conversation.history.messages.last(where: { $0.role == .assistant })?.id == message.id {
            switch entry.outcome {
            case .unlocked: replyLabel(.uiApproved, "checkmark.circle")
            case .denied: replyLabel(.uiDenied, "lock")
            case .wait: replyLabel(.uiWaiting, "hourglass")
            case .asked: replyLabel(.uiAsked, "bubble.left")
            default: replyLabel(.uiCoachName, "bubble.left")
            }
        } else { replyLabel(.uiCoachName, "bubble.left") }
    }
    private func replyLabel(_ title: CopyKey, _ symbol: String) -> some View {
        Label(title.resource, systemImage: symbol).font(.caption.weight(.medium)).foregroundStyle(.secondary)
    }

    private var composer: some View {
        @Bindable var conversation = conversation
        return VStack(alignment: .leading, spacing: 8) {
            if conversation.isSending {
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text(CopyKey.uiSending.resource).font(.footnote).foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Button(CopyKey.conversationCancel.resource) { conversation.cancelRequest() }
                        .font(.subheadline.weight(.semibold)).frame(minWidth: 44, minHeight: 44)
                        .accessibilityIdentifier("conversationCancelButton")
                }
            } else if conversation.composer.wasCancelled {
                Text(CopyKey.uiCancelledDraft.resource).font(.footnote).foregroundStyle(.secondary)
                    .accessibilityIdentifier("conversationCancelledNotice")
            }
            HStack(alignment: .bottom, spacing: 8) {
                TextField(CopyKey.conversationMessagePrompt.string, text: $conversation.draftMessage, axis: .vertical)
                    .lineLimit(1...(typeSize.isAccessibilitySize ? 3 : 5)).focused($messageFocused).disabled(conversation.isSending)
                    .accessibilityIdentifier("conversationMessageField")
                    .padding(.horizontal, 12).padding(.vertical, 10).frame(minHeight: 44)
                    .background(VolitionStyle.subtle, in: RoundedRectangle(cornerRadius: 12))
                    .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(VolitionStyle.border) }
                Button(action: submitDraft) {
                    Image(systemName: "arrow.up").font(.body.weight(.semibold))
                        .frame(width: 44, height: 44).foregroundStyle(VolitionStyle.background)
                        .background(Color.primary, in: RoundedRectangle(cornerRadius: 12)).opacity(canSend ? 1 : 0.3)
                }.buttonStyle(.plain).accessibilityLabel(CopyKey.conversationSend.string)
                    .disabled(!canSend).accessibilityIdentifier("conversationSendButton")
            }
        }.padding(.horizontal, 16).padding(.vertical, 10).background(VolitionStyle.background)
            .overlay(alignment: .top) { Divider() }
    }
    private func failureNotice(_ error: String) -> some View {
        VolitionCard {
            Label(CopyKey.uiRequestFailed.resource, systemImage: "exclamationmark.circle")
                .font(.subheadline.weight(.semibold)).foregroundStyle(.red)
            Text(error).font(.footnote).foregroundStyle(.secondary).accessibilityIdentifier("conversationErrorLabel")
            if conversation.preferences.hasConsent {
                Button(CopyKey.uiRetry.resource, systemImage: "arrow.clockwise", action: submitDraft)
                    .buttonStyle(VolitionButtonStyle(primary: false)).disabled(!canSend)
                    .accessibilityIdentifier("conversationRetryButton")
            }
        }
    }
    private var canSend: Bool {
        !conversation.draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            conversation.draftMessage.count <= 4000 && !conversation.isSending
    }
    private func submitDraft() {
        guard canSend else { return }
        messageFocused = false; followsLatest = true
        let submitted = conversation.composer.begin()
        Task {
            await conversation.send(submitted.text, rules: rules)
            conversation.composer.complete(submitted.id, restore: conversation.errorMessage != nil)
            await enforcer.refresh(rules: rules)
        }
    }
}

private extension View {
    func chatRow() -> some View {
        listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
            .listRowSeparator(.hidden).listRowBackground(Color.clear)
    }
}
