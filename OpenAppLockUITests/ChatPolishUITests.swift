import XCTest

final class ChatPolishUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func launch(_ mode: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-onboarding-completed", "-seed-scenario=conversation", mode]
        app.launch()
        app.buttons["conversationChooseAppButton"].waitToAppear().tap()
        app.buttons["conversationAppOption"].firstMatch.waitToAppear().tap()
        return app
    }
    private func send(_ text: String, _ app: XCUIApplication) {
        let field = app.element("conversationMessageField").waitToAppear()
        field.tap(); field.typeText(text)
        app.buttons["conversationSendButton"].tap()
    }
    private func capture(_ name: String, _ app: XCUIApplication) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
    func testCancellationRestoresDraftAndAllowsImmediateResend() {
        let app = launch("-slow-coach")
        send("A purposeful request", app)
        app.buttons["conversationCancelButton"].waitToAppear()
        capture("24 Chat sending", app)
        app.buttons["conversationCancelButton"].tap()
        let field = app.element("conversationMessageField")
        XCTAssertTrue(field.isEnabled)
        XCTAssertEqual(field.value as? String, "A purposeful request")
        app.staticTexts["conversationCancelledNotice"].waitToAppear()
        capture("25 Chat cancelled", app)
        field.tap(); field.typeText(" with a stopping point")
        let revisedDraft = field.value as? String
        app.buttons["conversationSendButton"].tap()
        app.buttons["conversationCancelButton"].waitToAppear().tap()
        XCTAssertEqual(field.value as? String, revisedDraft)
        XCTAssertFalse(app.buttons["endConversationUnlockButton"].exists)
    }
    func testFailurePreservesDraftAndOffersExplicitRetry() {
        let app = launch("-failing-coach")
        send("Message a friend for five minutes", app)
        app.staticTexts["conversationErrorLabel"].waitToAppear()
        XCTAssertEqual(app.element("conversationMessageField").value as? String, "Message a friend for five minutes")
        XCTAssertFalse(app.buttons["endConversationUnlockButton"].exists)
        capture("26 Chat service failure", app)
        app.buttons["conversationRetryButton"].waitToAppear().tap()
        app.staticTexts["conversationErrorLabel"].waitToAppear()
        XCTAssertEqual(app.element("conversationMessageField").value as? String, "Message a friend for five minutes")
    }
    func testPrivacyReviewBeforeReenablingChat() {
        let app = launch("-ai-consent-required")
        app.buttons["reviewAIConsentButton"].waitToAppear().tap()
        app.element("aiSharingDetails").waitToAppear()
        capture("27 AI sharing review", app)
        app.buttons["acceptAIConsentButton"].tap()
        XCTAssertTrue(app.buttons["reviewAIConsentButton"].waitForNonExistence(timeout: 5))
        send("Hello", app)
        app.staticTexts["What would you like to accomplish in this app?"].waitToAppear()
    }
}
