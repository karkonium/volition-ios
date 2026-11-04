import SwiftData
import SwiftUI

/// Removal is always the user's choice. Feedback is recorded independently of
/// chat; the alternative submits an ordinary request and never bypasses a deal.
/// Sibling sheets present sequentially so keyboard dismissal completes first.
struct VolitionAppRemovalView: View {
    let rule: BlockingRule
    let onRequest: (String) -> Void
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(ConversationCoordinator.self) private var conversation
    @Environment(RuleEnforcer.self) private var enforcer
    @State private var attemptID: UUID?
    @State private var reason = ""
    @State private var offering = false
    @State private var minutes = 5
    @State private var saving = false
    @State private var error: String?
    @State private var attemptedContinue = false
    @State private var feedbackUnavailable = false
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Form {
                if offering {
                    Section {
                        Text(CopyKey.removalAlternative.resource).font(.headline)
                        Text(CopyKey.removalAlternativeHelp.resource).foregroundStyle(.secondary)
                        Stepper(CopyKey.removalMinutes.string(minutes), value: $minutes, in: 1...60)
                            .accessibilityIdentifier("removalMinutes")
                        Button(CopyKey.removalAsk.string(minutes)) { finish(.temporaryUnlockRequested) }
                            .disabled(conversation.isSending)
                            .accessibilityIdentifier("removalRequestUnlockButton")
                        Button(CopyKey.removalKeep.resource) { finish(.kept) }
                            .accessibilityIdentifier("removalKeepButton")
                    }
                    Section {
                        Button(CopyKey.removalAnyway.resource, role: .destructive) { finish(.removed) }
                            .accessibilityIdentifier("removalConfirmButton")
                    }
                } else {
                    Section {
                        Text(CopyKey.removalWhy.resource).font(.headline)
                        TextField(CopyKey.removalReason.string, text: $reason, axis: .vertical)
                            .lineLimit(3...6).focused($focused)
                            .accessibilityIdentifier("removalReasonField")
                        if let issue = FormValidation.removalError(reason), attemptedContinue || FormValidation.trim(reason).count > 2000 {
                            Text(issue.resource).font(.caption).foregroundStyle(.red).accessibilityIdentifier("removalReasonError")
                        }
                    } footer: { Text(CopyKey.removalWhyHelp.resource) }
                }
                if feedbackUnavailable {
                    Section {
                        Text(CopyKey.feedbackStorageWarning.resource).foregroundStyle(.red)
                        if !offering {
                            Button(CopyKey.removalAnyway.resource, role: .destructive) { finish(.removed) }
                                .accessibilityIdentifier("removalWithoutFeedbackButton")
                        }
                    }
                }
                if let error { Section { Text(error).foregroundStyle(.red) } }
            }
            .disabled(saving)
            .navigationTitle(rule.name)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(CopyKey.conversationCancel.resource) { finish(.kept) }.disabled(saving)
                }
                if !offering {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(CopyKey.removalContinue.resource) { advance() }
                            .disabled(saving)
                            .accessibilityIdentifier("removalContinueButton")
                    }
                }
            }
            .onAppear {
                guard attemptID == nil else { return }
                do { attemptID = try conversation.beginRemoval(appID: rule.id, appName: rule.name) }
                catch { feedbackUnavailable = true }
            }
            .onDisappear {
                guard let attemptID else { return }
                do { try conversation.finishRemoval(attemptID, outcome: rule.isEnabled ? .kept : .removed) }
                catch { ConversationDiagnostics.live.log("removal.feedback_save_failed") }
            }
        }
        .interactiveDismissDisabled(saving)
    }

    private func advance() {
        attemptedContinue = true
        guard FormValidation.removalError(reason) == nil else { focused = true; return }
        focused = false
        if let attemptID {
            do { try conversation.recordRemovalReason(attemptID, reason: reason) }
            catch { feedbackUnavailable = true }
        }
        offering = true
    }

    private func finish(_ outcome: ConversationRemovalAttempt.Outcome) {
        guard !saving else { return }
        focused = false; saving = true; error = nil
        do {
            if outcome == .removed {
                conversation.cancelRequest()
                rule.isEnabled = false
                do { try context.save() } catch { context.rollback(); throw error }
            }
            // Feedback is advisory; only a failed rule write may prevent removal.
            if let attemptID {
                do {
                    try conversation.finishRemoval(attemptID, outcome: outcome,
                        minutes: outcome == .temporaryUnlockRequested ? minutes : nil)
                } catch { feedbackUnavailable = true }
            }
            if outcome == .temporaryUnlockRequested {
                onRequest(CopyKey.removalRequestMessage.string(FormValidation.trim(reason), minutes))
            }
            Task {
                do {
                    if outcome == .removed {
                        let rules = try context.fetch(FetchDescriptor<BlockingRule>())
                        await enforcer.refresh(rules: rules)
                        await conversation.refresh(snapshots: rules.map(\.dto))
                    }
                    saving = false
                    dismiss()
                } catch { self.error = CopyKey.volitionSaveError.string; saving = false }
            }
        } catch { self.error = CopyKey.volitionSaveError.string; saving = false }
    }
}
