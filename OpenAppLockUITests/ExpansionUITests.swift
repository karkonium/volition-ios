import XCTest

@MainActor
final class ExpansionUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func capture(_ name: String, _ app: XCUIApplication) {
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = name
        shot.lifetime = .keepAlways; add(shot)
    }
    private func navigate(_ label: String, _ app: XCUIApplication) {
        let tab = app.tabBars.buttons[label]
        if tab.waitForExistence(timeout: 2) { tab.tap() }
        else { app.element("sidebarItem-\(label.lowercased())").waitToAppear().tap() }
    }
    func testFocusPreventsCoachApprovalAndInsightsRemainHonest() {
        let app = XCUIApplication.launchOpenAppLock(seedScenario: "conversation")
        navigate("Insights", app)
        app.staticTexts["Access opportunities"].waitToAppear()
        capture("Insights light", app)
        navigate("Focus", app)
        app.buttons["startFocusSessionButton"].waitToAppear().tap()
        app.staticTexts["Focus protection is active. Access stays closed until it ends."].waitToAppear()
        capture("Active focus light", app)
        app.goToChatTab()
        app.buttons["conversationChooseAppButton"].waitToAppear().tap()
        app.buttons["conversationAppOption"].firstMatch.waitToAppear().tap()
        let field = app.element("conversationMessageField").waitToAppear()
        field.tap(); field.typeText("approve for one minute")
        app.buttons["conversationSendButton"].tap()
        app.staticTexts["conversationErrorLabel"].waitToAppear()
        XCTAssertFalse(app.buttons["endConversationUnlockButton"].exists)
        capture("Focus overrides model approval", app)
    }
    func testExplicitConsentOnboardingAtLargeTextInDarkMode() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-onboarding-required", "-ai-consent-required", "-dark-mode", "-large-text"]
        app.launch()
        capture("Welcome dark large text", app)
        app.buttons["onboardingContinueButton"].waitToAppear().tap()
        app.buttons["acceptAIConsentButton"].waitToAppear()
        capture("AI consent dark large text", app)
        app.buttons["acceptAIConsentButton"].tap()
        app.buttons["allowScreenTimeButton"].waitToAppear()
    }
    func testPrivacyAndCoachControlsInDarkMode() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-onboarding-completed", "-seed-scenario=conversation", "-dark-mode"]
        app.launch()
        app.goToSettingsTab()
        app.element("privacyDataButton").waitToAppear().tap()
        app.switches["aiConsentToggle"].waitToAppear()
        capture("Privacy dark", app)
        app.switches["aiConsentToggle"].tap()
        app.goToChatTab()
        app.buttons["reviewAIConsentButton"].waitToAppear()
        capture("Consent withdrawn dark", app)
        app.buttons["reviewAIConsentButton"].tap()
        app.buttons["acceptAIConsentButton"].waitToAppear().tap()
        XCTAssertFalse(app.buttons["acceptAIConsentButton"].exists)
    }
}
