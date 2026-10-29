import XCTest

/// Layout evidence uses synthetic apps and mock decisions, never actual usage.
final class UILayoutPolishUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func capture(_ name: String, _ app: XCUIApplication) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
    private func launch(large: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-onboarding-completed", "-seed-scenario=conversation-stress"]
        if large { app.launchArguments += ["-dark-mode", "-large-text"] }
        app.launch(); return app
    }
    func testLongNamesAndKeyboardAtLargeText() {
        let app = launch(large: true)
        app.goToAppsTab()
        app.buttons["volitionApp-A deliberately long app name that needs several lines"].waitToAppear()
        capture("28 Many apps dark large text", app)
        app.goToChatTab()
        app.buttons["conversationChooseAppButton"].tap()
        let search = app.searchFields.firstMatch.waitToAppear()
        search.tap(); search.typeText("App 20")
        app.buttons["conversationAppOption"].firstMatch.waitToAppear().tap()
        let field = app.element("conversationMessageField").waitToAppear()
        field.tap(); field.typeText("I need to contact a friend and make a practical plan for tomorrow.")
        XCTAssertTrue(field.isHittable)
        let keyboard = app.keyboards.firstMatch.waitToAppear()
        XCTAssertLessThanOrEqual(field.frame.maxY, keyboard.frame.minY + 2)
        capture("29 Keyboard dark large text", app)
    }
    func testTwoGrantsRemainReadableAtLargeText() {
        let app = launch(large: true)
        for name in ["App 12", "App 13"] {
            app.buttons["conversationChooseAppButton"].waitToAppear().tap()
            let search = app.searchFields.firstMatch.waitToAppear()
            search.tap(); search.typeText(name)
            app.buttons["conversationAppOption"].firstMatch.waitToAppear().tap()
            let field = app.element("conversationMessageField").waitToAppear()
            field.tap(); field.typeText("approve for a purposeful task")
            app.buttons["conversationSendButton"].tap()
            app.buttons["endConversationUnlockButton"].firstMatch.waitToAppear()
        }
        let grants = app.buttons.matching(identifier: "endConversationUnlockButton")
        grants.element(boundBy: 1).waitToAppear()
        XCTAssertEqual(grants.count, 2)
        XCTAssertTrue(app.element("conversationMessageField").isHittable)
        capture("30 Independent grants dark large text", app)
    }
    func testPrivacyAndCoachDetailsHaveClearControls() {
        let app = launch(large: false)
        app.goToSettingsTab()
        app.element("conversationSettingsButton").waitToAppear().tap()
        app.element("coachTonePicker").waitToAppear()
        capture("31 Coach settings light", app)
        app.navigationBars.buttons.firstMatch.tap()
        app.element("privacyDataButton").waitToAppear().tap()
        app.switches["aiConsentToggle"].waitToAppear()
        capture("32 Privacy details light", app)
        app.swipeUp()
        app.buttons["eraseCoachingContentButton"].waitToAppear()
        capture("33 Data controls light", app)
    }
}
