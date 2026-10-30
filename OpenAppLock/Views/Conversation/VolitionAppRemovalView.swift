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
                    } footer: { Text(CopyKey.removalWhyHelp.resource) }
                }
                if let error { Section { Text(error).foregroundStyle(.red) } }
            }
            .disabled(saving || attemptID == nil)
            .navigationTitle(rule.name)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(CopyKey.conversationCancel.resource) { finish(.kept) }.disabled(saving)
                }
                if !offering {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(CopyKey.removalContinue.resource) { advance() }
                            .disabled(saving || attemptID == nil || reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || reason.count > 2000)
                            .accessibilityIdentifier("removalContinueButton")
                    }
                }
            }
            .onAppear {
                guard attemptID == nil else { return }
                do { attemptID = try conversation.beginRemoval(appID: rule.id, appName: rule.name) }
                catch { self.error = CopyKey.volitionSaveError.string }
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
        focused = false
        do {
            guard let attemptID else { return }
            try conversation.recordRemovalReason(attemptID, reason: reason)
            offering = true
        } catch { self.error = CopyKey.volitionSaveError.string }
    }

    private func finish(_ outcome: ConversationRemovalAttempt.Outcome) {
        focused = false
        guard let attemptID else { dismiss(); return }
        saving = true
        do {
            if outcome == .removed {
                conversation.cancelRequest()
                rule.isEnabled = false
                do { try context.save() } catch { context.rollback(); throw error }
            }
            try conversation.finishRemoval(attemptID, outcome: outcome,
                minutes: outcome == .temporaryUnlockRequested ? minutes : nil)
            if outcome == .temporaryUnlockRequested {
                onRequest(CopyKey.removalRequestMessage.string(reason.trimmingCharacters(in: .whitespacesAndNewlines), minutes))
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
                } catch {
                    self.error = CopyKey.volitionSaveError.string
                    saving = false
                }
            }
        } catch {
            self.error = CopyKey.volitionSaveError.string
            // A profile save may have succeeded before feedback persistence failed.
            // Reconcile that durable removal even while offering a feedback retry.
            if !rule.isEnabled {
                Task {
                    if let rules = try? context.fetch(FetchDescriptor<BlockingRule>()) {
                        await enforcer.refresh(rules: rules)
                        await conversation.refresh(snapshots: rules.map(\.dto))
                    }
                    saving = false
                }
            } else { saving = false }
        }
    }
}
