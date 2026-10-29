import XCTest

final class VolitionUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func section(_ name: String, _ app: XCUIApplication) {
        let tab = app.tabBars.buttons[name]
        if tab.waitForExistence(timeout: 2) { tab.tap() }
        else { app.element("sidebarItem-\(name.lowercased())").waitToAppear().tap() }
    }
    private func capture(_ name: String, _ app: XCUIApplication) {
        let image = XCTAttachment(screenshot: app.screenshot()); image.name = name
        image.lifetime = .keepAlways; add(image)
    }
    func testSetupNamesAppAndKeepsIntentionInChat() {
        let app = XCUIApplication.launchOpenAppLock()
        app.buttons["addVolitionAppButton"].waitToAppear().tap()
        XCTAssertEqual(app.staticTexts["volitionAppNameHelp"].waitToAppear().label,
            "Enter the same name as the app you selected above—for example, SoundCloud.")
        app.buttons["pickVolitionAppButton"].waitToAppear().tap()
        app.buttons["mockVolitionMultipleAppsOption"].waitToAppear().tap()
        app.staticTexts["volitionPickerError"].waitToAppear()
        XCTAssertTrue(app.buttons["mockVolitionAppOption"].exists)
        capture("Choose only one app", app)
        app.buttons["mockVolitionAppOption"].waitToAppear().tap()
        XCTAssertTrue(app.buttons["mockVolitionAppOption"].waitForNonExistence(timeout: 5))
        app.textFields["volitionAppName"].waitToAppear().tap()
        app.textFields["volitionAppName"].typeText("Instagram")
        app.textViews["volitionAppIntention"].tap()
        app.textViews["volitionAppIntention"].typeText("Message close friends, without scrolling the feed.")
        app.buttons["saveVolitionAppButton"].tap()
        app.buttons["finishVolitionSetupButton"].waitToAppear()
        capture("Volition setup", app)
        app.buttons["finishVolitionSetupButton"].tap()
        app.buttons["conversationChooseAppButton"].waitToAppear().tap()
        app.buttons["conversationAppOption"].firstMatch.waitToAppear().tap()
        XCTAssertTrue(app.buttons["conversationChooseAppButton"].label.contains("Instagram"))
        XCTAssertFalse(app.textFields["conversationNicknameField"].exists)
        XCTAssertFalse(app.tabBars.buttons["Rules"].exists)
        capture("Volition clean chat", app)
        section("Apps", app)
        app.buttons["volitionApp-Instagram"].waitToAppear().tap()
        XCTAssertEqual(app.textFields["volitionAppName"].value as? String, "Instagram")
        XCTAssertEqual(app.textViews["volitionAppIntention"].value as? String, "Message close friends, without scrolling the feed.")
        capture("Volition saved intention", app)
        app.buttons["pickVolitionAppButton"].tap()
        app.buttons["cancelVolitionAppPickerButton"].waitToAppear().tap()
        XCTAssertEqual(app.textFields["volitionAppName"].value as? String, "Instagram")
        XCTAssertTrue(app.buttons["pickVolitionAppButton"].label.contains("Selected app"))
    }
    func testWaitAndApprovalHaveClearStates() {
        let app = XCUIApplication.launchOpenAppLock(seedScenario: "conversation")
        app.buttons["conversationChooseAppButton"].waitToAppear().tap()
        app.buttons["conversationAppOption"].firstMatch.waitToAppear().tap()
        let field = app.element("conversationMessageField").waitToAppear()
        field.tap(); field.typeText("approve to message a friend")
        app.buttons["conversationSendButton"].tap()
        app.buttons["endConversationUnlockButton"].waitToAppear()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))
        capture("Volition approved", app)
        app.buttons["endConversationUnlockButton"].tap()
        field.tap(); field.typeText("wait before more time")
        app.buttons["conversationSendButton"].tap()
        app.staticTexts["Let’s leave this app closed for now. What were you hoping to do?"].waitToAppear()
        XCTAssertFalse(app.element("conversationCooldown").exists)
        XCTAssertFalse(app.buttons["endConversationUnlockButton"].exists)
        XCTAssertTrue(field.isEnabled)
        field.tap(); field.typeText("Could we discuss my intention?")
        XCTAssertTrue(app.buttons["conversationSendButton"].isEnabled)
        app.buttons["conversationSendButton"].tap()
        app.staticTexts["What would you like to accomplish in this app?"].waitToAppear()
        section("Apps", app); section("Chat", app)
        XCTAssertFalse(app.element("conversationCooldown").exists)
        XCTAssertFalse(app.buttons["endConversationUnlockButton"].exists)
        capture("Declined access without a countdown", app)
    }
    func testRequestAnotherAppWhileFirstTimerRuns() {
        let app = XCUIApplication.launchOpenAppLock(seedScenario: "conversation-multiple")
        func choose(_ index: Int) {
            app.buttons["conversationChooseAppButton"].waitToAppear().tap()
            app.buttons.matching(identifier: "conversationAppOption").element(boundBy: index).waitToAppear().tap()
        }
        func send(_ text: String) {
            let field = app.element("conversationMessageField").waitToAppear()
            field.tap(); field.typeText(text)
            app.buttons["conversationSendButton"].tap()
        }
        choose(0); send("approve for one minute")
        app.buttons["endConversationUnlockButton"].firstMatch.waitToAppear()
        choose(1); send("approve a different task for one minute")
        let timers = app.buttons.matching(identifier: "endConversationUnlockButton")
        XCTAssertTrue(timers.element(boundBy: 1).waitForExistence(timeout: 10))
        XCTAssertTrue(app.element("conversationMessageField").isEnabled)
        capture("Independent app unlock timers", app)
        timers.firstMatch.tap()
        XCTAssertTrue(timers.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(timers.count, 1)
    }

}
