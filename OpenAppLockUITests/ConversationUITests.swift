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
    private func capture(_ name: String, _ app: XCUIApplication) {
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = name; image.lifetime = .keepAlways; add(image)
    }
    func testMissingAppGuidanceAndReadableActivityLog() {
        let app = XCUIApplication.launchOpenAppLock(seedScenario: "conversation")
        send("Hello", app)
        let attention = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "App selection needed"),
            object: app.buttons["conversationChooseAppButton"])
        XCTAssertEqual(XCTWaiter.wait(for: [attention], timeout: 5), .completed)
        app.staticTexts["conversationAppSelectionHint"].waitToAppear()
        XCTAssertFalse(app.staticTexts["conversationErrorLabel"].exists)
        XCTAssertEqual(app.element("conversationMessageField").value as? String, "Hello")
        capture("Choose an app guidance", app)
        chooseApp(app)
        app.buttons["conversationSendButton"].tap()
        app.staticTexts["What would you like to accomplish in this app?"].waitToAppear()
        app.goToSettingsTab()
        app.element("conversationActivityLogButton").waitToAppear().tap()
        app.staticTexts["App selection needed"].waitToAppear()
        app.staticTexts["Question asked"].waitToAppear()
        capture("Readable activity log", app)
        app.buttons["exportActivityLogButton"].waitToAppear().tap()
        app.buttons["Readable text (.txt)"].waitToAppear()
        app.buttons["JSON Lines (.jsonl)"].waitToAppear()
        app.buttons["Readable text (.txt)"].tap()
        XCTAssertTrue(app.buttons["Close"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.otherElements["LP.CaptionBar.TopCaption"].waitToAppear().label, "Volition-activity")
        capture("Activity log export share sheet", app)
    }
    func testNamedAppRoutesWithoutOpeningThePicker() {
        let app = XCUIApplication.launchOpenAppLock(seedScenario: "conversation-multiple")
        send("approve App 12 for one minute", app)
        app.buttons["endConversationUnlockButton"].waitToAppear()
        XCTAssertTrue(app.buttons["conversationChooseAppButton"].label.contains("App 12"))
        XCTAssertFalse(app.element("conversationAppSelectionHint").exists)
        capture("Named app selected automatically", app)
        app.goToSettingsTab()
        app.element("conversationActivityLogButton").waitToAppear().tap()
        app.staticTexts["Unlocked"].waitToAppear()
        app.staticTexts["approve App 12 for one minute"].waitToAppear()
        capture("Actual unlock in activity log", app)
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
        app.staticTexts["What would you like to make time for?"].waitToAppear()
    }
}
