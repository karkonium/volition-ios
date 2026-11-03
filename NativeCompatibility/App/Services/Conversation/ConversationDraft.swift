import Foundation
import Observation

/// Session-only composer state survives navigation. A completion owns one identity
/// and may restore only its own untouched draft. It never changes access policy.
@Observable
final class ConversationDraft {
    struct Submission { let id = UUID(); let text: String }
    var text = ""
    private(set) var wasCancelled = false
    private var pending: Submission?
    func begin() -> Submission {
        let submission = Submission(text: text)
        pending = submission; text = ""; wasCancelled = false
        return submission
    }
    func complete(_ id: UUID, restore: Bool) {
        guard let pending, pending.id == id else { return }
        if restore && text.isEmpty { text = pending.text }
        self.pending = nil
    }
    func cancel() {
        guard let pending else { return }
        if text.isEmpty { text = pending.text }
        self.pending = nil; wasCancelled = true
    }
}
