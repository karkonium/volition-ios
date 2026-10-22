import XCTest

final class ConversationUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func chooseApp(_ app: XCUIApplication) {
        app.buttons["conversationChooseAppButton"].waitToAppear().tap()
        app.buttons["conversationAppOption"].firstMatch.waitToAppear().tap()
    }
    private func send(_ text: String, _ app: XCUIApplication) {
        let field = app.element("conversationMessageField").waitToAppear()
        field.tap(); field.typeText(text)
        app.buttons["conversationSendButton"].tap()
    }
    func testSharedConversationFollowUpDenialAndApproval() {
        let app = XCUIApplication.launchOpenAppLock(seedScenario: "conversation")
        chooseApp(app)
        send("Hello", app)
        app.staticTexts["What would you like to accomplish in this app?"].waitToAppear()
        send("deny this request", app)
        app.staticTexts["This does not support your goal."].waitToAppear()
        send("approve a purposeful task", app)
        app.buttons["endConversationUnlockButton"].waitToAppear().tap()
        app.staticTexts["Unlock ended."].waitToAppear()
    }
    func testComposerFocusAndDraftAcrossPickerAndTabs() {
        let app = XCUIApplication.launchOpenAppLock(seedScenario: "conversation")
        chooseApp(app)
        let field = app.element("conversationMessageField").waitToAppear()
        field.tap(); field.typeText("approve a purposeful task")
        chooseApp(app)
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))
        app.goToAppsTab(); app.goToChatTab()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))
        XCTAssertEqual(field.value as? String, "approve a purposeful task")
        app.buttons["conversationSendButton"].tap()
        app.buttons["endConversationUnlockButton"].waitToAppear()
        XCTAssertTrue(field.isEnabled)
        XCTAssertFalse(app.element("conversationNicknameField").exists)
    }
    func testHistoryDeletion() {
        let app = XCUIApplication.launchOpenAppLock(seedScenario: "conversation")
        chooseApp(app); send("Hello", app)
        app.staticTexts["What would you like to accomplish in this app?"].waitToAppear()
        app.goToSettingsTab()
        app.element("conversationSettingsButton").waitToAppear().tap()
        app.buttons["clearConversationHistoryButton"].waitToAppear().tap()
        app.sheets.buttons["Clear conversation history"].waitToAppear().tap()
        app.goToChatTab()
        app.staticTexts["What would you like to make time for? Choose an app, then tell me what you have in mind."].waitToAppear()
    }
}
