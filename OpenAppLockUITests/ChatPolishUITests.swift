import XCTest

@MainActor
final class ChatPolishUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func launch(_ mode: String = "") -> XCUIApplication {
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
    func testEmptyConversationFocusesComposer() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-onboarding-completed", "-seed-scenario=conversation"]
        app.launch()
        app.buttons["conversationStartChattingButton"].waitToAppear().tap()
        app.keyboards.keys["space"].waitToAppear()
        app.element("conversationMessageField").typeText("My first request")
        XCTAssertEqual(app.element("conversationMessageField").value as? String, "My first request")
        capture("Empty conversation opens keyboard", app)
    }

    func testKeyboardKeepsLatestResponseVisible() throws {
        let app = launch()
        app.element("conversationMessageField").tap()
        let initialKeyboard = app.keyboards.firstMatch.waitToAppear()
        guard initialKeyboard.frame.maxY <= app.frame.maxY + 2 else {
            throw XCTSkip("The simulator has its software keyboard offscreen; run with a visible software keyboard to verify transcript resizing.")
        }
        for index in 1...6 {
            send("Request \(index): I want to decide how to use this app", app)
            app.staticTexts.matching(identifier: "conversationMessage-assistant")
                .element(boundBy: index - 1).waitToAppear()
        }
        let field = app.element("conversationMessageField")
        field.tap()
        let keyboard = app.keyboards.firstMatch.waitToAppear()
        keyboard.keys["space"].waitToAppear()
        XCTAssertGreaterThan(keyboard.frame.height, 200)
        XCTAssertLessThanOrEqual(keyboard.frame.maxY, app.frame.maxY + 2)
        let latest = app.staticTexts.matching(identifier: "conversationMessage-assistant").element(boundBy: 5)
        let visible = NSPredicate { _, _ in
            latest.isHittable && latest.frame.maxY <= field.frame.minY && field.frame.maxY <= keyboard.frame.minY + 2
        }
        expectation(for: visible, evaluatedWith: app)
        waitForExpectations(timeout: 5)
        capture("Latest response above keyboard", app)
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
    func testRequiredCoachingHasInformationWithoutDisableControl() {
        let app = launch()
        XCTAssertFalse(app.buttons["reviewAIConsentButton"].exists)
        send("Hello", app)
        app.staticTexts["What would you like to accomplish in this app?"].waitToAppear()
        app.goToSettingsTab()
        app.element("privacyDataButton").waitToAppear().tap()
        app.element("aiSharingDetails").waitToAppear()
        XCTAssertFalse(app.switches["aiConsentToggle"].exists)
        capture("Required AI coaching information", app)
    }
}
