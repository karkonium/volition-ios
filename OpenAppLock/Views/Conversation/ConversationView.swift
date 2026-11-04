import FamilyControls
import ManagedSettings
import SwiftData
import SwiftUI

/// Shared chat and independent grants. Compact unlock banners stay above the
/// transcript; the selected-app control and keyboard-safe composer remain reachable.
/// Cancelling restores the session draft; late completions cannot alter a new one.
/// Transcript resizing anchors the latest content above the keyboard. The empty
/// conversation is a button that focuses the same composer as direct input.
/// Waits are labeled within coach replies, never shown as unlock countdowns.
/// Send looks inactive without a selected app but accepts draft submissions to
/// resolve saved names or draw attention to the chooser without losing the draft.
struct ConversationView: View {
    @Environment(ConversationCoordinator.self) private var conversation
    @Environment(FocusController.self) private var focus
    @Environment(RuleEnforcer.self) private var enforcer
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var typeSize
    @Query(sort: BlockingRule.displayOrder) private var rules: [BlockingRule]
    @FocusState private var messageFocused: Bool
    @State private var choosingApp = false
    @State private var followsLatest = true
    @State private var visibleMessages = 60

    /// Presentation omits redundant system notices while the full event history
    /// remains available to coaching, enforcement and the private activity log.
    private var transcriptMessages: [ConversationMessage] {
        conversation.history.messages.filter { $0.role != .event }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TimelineView(.periodic(from: .now, by: 30)) { _ in appSelector }.padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 6)
                if !conversation.displayedGrants.isEmpty {
                    grantCards.padding(.horizontal, 16).padding(.bottom, 8)
                        .accessibilityIdentifier("conversationUnlockBanners")
                }
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
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
                            if transcriptMessages.isEmpty { emptyConversation.chatRow() }
                            if transcriptMessages.count > visibleMessages {
                                Button(CopyKey.chatLoadEarlier.resource) { visibleMessages += 60 }
                                    .buttonStyle(VolitionButtonStyle(primary: false)).chatRow()
                            }
                            ForEach(Array(transcriptMessages.suffix(visibleMessages))) { item in
                                message(item).id(item.id)
                                    .accessibilityIdentifier("conversationMessage-\(item.role.rawValue)").chatRow()
                            }
                            if let error = conversation.errorMessage, !conversation.appSelectionNeeded {
                                failureNotice(error).chatRow()
                            }
                            ForEach(conversation.pendingReflections) { reflection in
                                Group {
                                    if reflection.state == .activating {
                                        ProgressView(CopyKey.reflectionOpening.resource)
                                            .padding(16).accessibilityIdentifier("conversationInterventionActivating")
                                    } else if reflection.awaitingCheckIn {
                                        ConversationEmotionCheckIn(reflection: reflection)
                                    } else if reflection.isChoice {
                                        ConversationInterventionChoiceCard(reflection: reflection, snapshots: { rules.filter { !$0.isDeleted }.map(\.dto) })
                                    } else if reflection.isDeal {
                                        ConversationDealCard(reflection: reflection, snapshots: { rules.filter { !$0.isDeleted }.map(\.dto) })
                                    } else {
                                        ConversationReflectionCard(reflection: reflection, snapshots: { rules.filter { !$0.isDeleted }.map(\.dto) })
                                    }
                                }.disabled(conversation.isSending).chatRow()
                            }
                            if let entry = conversation.feedbackEntry {
                                ConversationExperienceFeedback(entry: entry).id(entry.id).chatRow()
                            }
                            Color.clear.frame(height: 1).id("latest")
                        }
                        .padding(.horizontal, 16)
                    }
                    .defaultScrollAnchor(.bottom, for: .sizeChanges)
                    .accessibilityIdentifier("conversationTranscript")
                    .scrollDismissesKeyboard(.interactively)
                    .onScrollGeometryChange(for: Bool.self) { geometry in
                        geometry.contentSize.height - geometry.contentOffset.y - geometry.containerSize.height < 120
                    } action: { _, nearBottom in followsLatest = nearBottom }
                    .onChange(of: messageFocused) { _, focused in
                        guard focused else { return }
                        followsLatest = true
                        withAnimation(.easeOut(duration: 0.25)) {
                            proxy.scrollTo("latest", anchor: .bottom)
                        }
                    }
                    .onAppear {
                        if !transcriptMessages.isEmpty { proxy.scrollTo("latest", anchor: .bottom) }
                    }
                    .onChange(of: transcriptMessages.count) {
                        if followsLatest { proxy.scrollTo("latest", anchor: .bottom) }
                    }
                    .onChange(of: conversation.isSending) { _, sending in
                        if sending { followsLatest = true }
                        if followsLatest { proxy.scrollTo("latest", anchor: .bottom) }
                    }
                    .task(id: conversation.feedbackEntry?.id) {
                        guard let entry = conversation.feedbackEntry else { return }
                        followsLatest = true
                        await Task.yield()
                        withAnimation { proxy.scrollTo(entry.id, anchor: .bottom) }
                    }
                    .task(id: conversation.reflectionScheduleID) {
                        guard !conversation.pendingReflections.isEmpty else { return }
                        followsLatest = true
                        await Task.yield()
                        proxy.scrollTo("latest", anchor: .bottom)
                    }
                    .onChange(of: conversation.errorMessage) {
                        if followsLatest && !conversation.appSelectionNeeded { proxy.scrollTo("latest", anchor: .bottom) }
                    }
                    .overlay(alignment: .bottomTrailing) {
                        if !followsLatest && !transcriptMessages.isEmpty {
                            Button {
                                followsLatest = true; proxy.scrollTo("latest", anchor: .bottom)
                            } label: {
                                Label(CopyKey.uiLatestMessages.resource, systemImage: "arrow.down")
                                    .font(.caption.weight(.semibold)).padding(12)
                                    .background(VolitionStyle.surface, in: Capsule())
                                    .overlay { Capsule().strokeBorder(VolitionStyle.border) }
                            }.buttonStyle(.plain).padding(12).accessibilityIdentifier("conversationJumpLatest")
                        }
                    }
                }
                composer
            }
            .frame(maxWidth: 720).frame(maxWidth: .infinity)
            .background(VolitionStyle.background)
            .volitionTabRoot()
            .onChange(of: conversation.selectedSection) { _, section in
                if section != .chat { messageFocused = false }
            }
            .onChange(of: scenePhase) { _, phase in if phase != .active { messageFocused = false } }
            .onChange(of: conversation.displayedGrants.map(\.plan.grantID)) { _, ids in if !ids.isEmpty { messageFocused = false } }
            .onDisappear { messageFocused = false }
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
                if let summary = conversation.selectedActivitySummary {
                    Text(selectedAppStatus(summary))
                        .font(.caption).foregroundStyle(Color.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityHint(CopyKey.uiSelectedAppUsageHelp.string)
                        .accessibilityIdentifier("conversationSessionCounts")
                }

            }
        }
        .buttonStyle(.plain).accessibilityIdentifier("conversationChooseAppButton")
        .accessibilityValue(conversation.appSelectionNeeded ? CopyKey.activitySelectionRequired.string : "")
        .disabled(conversation.isSending)
        .volitionAttention(trigger: conversation.selectionAttention)
    }

    private func selectedAppStatus(_ summary: ConversationActivitySummary) -> String {
        let unlocks = summary.sameAppShortGrantsToday + summary.sameAppLongGrantsToday
        let minutes = summary.sameAppGrantedMinutesToday
        let count = (unlocks == 1 ? CopyKey.uiUnlockOne : .uiUnlockMany).string(unlocks)
        let timeGranted = (minutes == 1 ? CopyKey.uiMinuteOne : .uiMinuteMany).string(minutes)
        let usage = CopyKey.uiSelectedAppUsage.string(count, timeGranted)
        guard let until = conversation.cooldownUntil else { return usage }
        let time = until.formatted(date: Calendar.current.isDateInToday(until) ? .omitted : .abbreviated, time: .shortened)
        return usage + ", " + CopyKey.dealBlockedUntil.string(time)
    }

    private var emptyConversation: some View {
        Button {
            messageFocused = true
        } label: {
            VolitionCard {
                HStack(spacing: 10) {
                    VolitionIcon(symbol: "bubble.left.and.bubble.right", accented: true)
                    Text(CopyKey.volitionChatEmpty.resource).font(.headline)
                }
                Text(CopyKey.uiChatIntro.resource).font(.subheadline).foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("conversationStartChattingButton")
    }

    @ViewBuilder private var grantCards: some View {
        ScrollView {
            VStack(spacing: 6) {
                ForEach(conversation.displayedGrants, id: \.plan.grantID) { grant in grantCard(grant) }
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(height: min(CGFloat(conversation.displayedGrants.count), 2) * (typeSize.isAccessibilitySize ? 116 : 52))
    }
    private func grantCard(_ grant: ConversationGrantStore.Grant) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0)) : AnyLayout(HStackLayout(spacing: 8))
            layout {
                HStack(spacing: 6) {
                    Image(systemName: "lock.open").accessibilityHidden(true)
                    Text(conversation.appName(for: grant)).fontWeight(.semibold).lineLimit(1)
                    Spacer(minLength: 4)
                    if timeline.date < grant.plan.expiresAt {
                        Text(grant.plan.expiresAt, style: .timer).monospacedDigit().fixedSize()
                            .accessibilityLabel(CopyKey.appTemporarilyOpen.string)
                    } else { Text(CopyKey.conversationGrantExpired.resource) }
                }
                Button(CopyKey.conversationEndUnlock.resource) {
                    Task { await conversation.endUnlock(grantID: grant.plan.grantID); await enforcer.refresh(rules: rules) }
                }
                .fontWeight(.semibold).frame(minWidth: 44, minHeight: 44)
                .buttonStyle(.plain).foregroundStyle(VolitionStyle.accent)
                .accessibilityIdentifier("endConversationUnlockButton")
            }
            .font(.subheadline).padding(.horizontal, 12)
            .background(VolitionStyle.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
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
            Text(item.text).font(.body).lineSpacing(2).padding(12)
                .background(item.role == .user ? VolitionStyle.accent.opacity(0.08) : VolitionStyle.surface,
                    in: RoundedRectangle(cornerRadius: 14))
                .overlay {
                    if item.role == .assistant { RoundedRectangle(cornerRadius: 14).strokeBorder(VolitionStyle.border) }
                }
                .textSelection(.enabled).foregroundStyle(Color.primary)
            if item.role != .user { Spacer(minLength: typeSize.isAccessibilitySize ? 0 : 24) }
        }
    }

    private var composer: some View {
        @Bindable var conversation = conversation
        return VStack(alignment: .leading, spacing: 8) {
            if conversation.isSending {
                HStack(spacing: 10) {
                    ProgressView(CopyKey.uiSending.resource).controlSize(.small)
                        .font(.footnote).foregroundStyle(.secondary)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("conversationThinking")
                    Spacer(minLength: 0)
                    Button(CopyKey.conversationCancel.resource) { conversation.cancelRequest() }
                        .font(.subheadline.weight(.semibold)).frame(minWidth: 44, minHeight: 44)
                        .accessibilityIdentifier("conversationCancelButton")
                }
            } else if conversation.composer.wasCancelled {
                Text(CopyKey.uiCancelledDraft.resource).font(.footnote).foregroundStyle(.secondary)
                    .accessibilityIdentifier("conversationCancelledNotice")
            }
            if let issue = FormValidation.messageError(conversation.draftMessage) {
                Text(issue.resource).font(.caption).foregroundStyle(.red).accessibilityIdentifier("conversationLengthError")
            }
            HStack(alignment: .bottom, spacing: 8) {
                TextField(CopyKey.conversationMessagePrompt.string, text: $conversation.draftMessage, axis: .vertical)
                    .lineLimit(1...(typeSize.isAccessibilitySize ? 3 : 5)).focused($messageFocused).disabled(conversation.isSending)
                    .accessibilityIdentifier("conversationMessageField")
                    .padding(.horizontal, 12).padding(.vertical, 10).frame(minHeight: 44)
                    .background(VolitionStyle.subtle, in: RoundedRectangle(cornerRadius: 12))
                    .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(VolitionStyle.border) }
                Button(action: submitDraft) {
                    Image(systemName: "arrow.up").font(.body.weight(.bold))
                        .frame(width: 44, height: 44).foregroundStyle(Color.white)
                        .background(conversation.target == nil ? Color.gray : VolitionStyle.accent,
                            in: RoundedRectangle(cornerRadius: 12))
                        .opacity(canSend && conversation.target != nil ? 1 : 0.3)
                }.buttonStyle(.plain).accessibilityLabel(CopyKey.conversationSend.string)
                    .accessibilityValue(conversation.target == nil ? CopyKey.conversationSelectAppHelp.string : "")
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
            if conversation.loadFailed {
                Button(CopyKey.historyRetryLoad.resource) { conversation.retryLoadingHistory() }
                    .buttonStyle(VolitionButtonStyle(primary: false))
            } else if conversation.preferences.hasConsent {
                Button(CopyKey.uiRetry.resource, systemImage: "arrow.clockwise", action: submitDraft)
                    .buttonStyle(VolitionButtonStyle(primary: false)).disabled(!canSend)
                    .accessibilityIdentifier("conversationRetryButton")
            }
        }
    }
    private var canSend: Bool {
        !conversation.draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            FormValidation.messageError(conversation.draftMessage) == nil && !conversation.isSending
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
        padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
