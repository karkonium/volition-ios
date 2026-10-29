import Testing
@testable import OpenAppLock

@MainActor struct ConversationDraftTests {
    @Test func cancellationRestoresTextBeforeAnotherSend() {
        let draft = ConversationDraft()
        draft.text = "Message a friend"
        let first = draft.begin()
        #expect(draft.text.isEmpty)
        draft.cancel()
        #expect(draft.text == first.text)
        #expect(draft.wasCancelled)
        draft.text += " for five minutes"
        let second = draft.begin()
        draft.complete(first.id, restore: true)
        #expect(draft.text.isEmpty)
        draft.complete(second.id, restore: true)
        #expect(draft.text == "Message a friend for five minutes")
    }
    @Test func lateFailureNeverReplacesAnEditedDraft() {
        let draft = ConversationDraft()
        draft.text = "Original"
        let request = draft.begin()
        draft.text = "New draft"
        draft.complete(request.id, restore: true)
        #expect(draft.text == "New draft")
        draft.cancel()
        #expect(!draft.wasCancelled)
    }
}
