import XCTest

final class WelcomeAndSelectionUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func capture(_ name: String, _ app: XCUIApplication) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }

    func testWelcomeExplainsAccessAndSupportsBackNavigation() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-onboarding-required", "-ai-consent-required"]
        app.launch()
        app.staticTexts["welcomeHowItWorks"].waitToAppear()
        capture("14 Welcome light", app)
        app.buttons["onboardingContinueButton"].tap()
        app.buttons["acceptAIConsentButton"].waitToAppear()
        capture("15 Consent light", app)
        app.buttons["onboardingBackButton"].tap()
        app.buttons["onboardingContinueButton"].waitToAppear().tap()
        app.buttons["deferAIConsentButton"].tap()
        app.buttons["allowScreenTimeButton"].waitToAppear()
        capture("16 Permission light", app)
        app.buttons["allowScreenTimeButton"].tap()
        app.buttons["addVolitionAppButton"].waitToAppear()
    }

    func testSearchSwitchesAppAndPreservesDraft() {
        let app = XCUIApplication.launchOpenAppLock(seedScenario: "conversation-multiple")
        let field = app.element("conversationMessageField").waitToAppear()
        field.tap(); field.typeText("My unfinished request")
        app.buttons["conversationChooseAppButton"].tap()
        let search = app.searchFields.firstMatch.waitToAppear()
        capture("17 App chooser light", app)
        search.tap(); search.typeText("App 12")
        let options = app.buttons.matching(identifier: "conversationAppOption")
        XCTAssertEqual(options.count, 1)
        options.firstMatch.tap()
        XCTAssertTrue(app.buttons["conversationChooseAppButton"].label.contains("App 12"))
        XCTAssertEqual(field.value as? String, "My unfinished request")
        app.buttons["conversationChooseAppButton"].tap()
        XCTAssertTrue(app.buttons.matching(identifier: "conversationAppOption").allElementsBoundByIndex.contains { $0.isSelected })
        search.tap(); search.typeText("does not exist")
        app.staticTexts["appSearchEmpty"].waitToAppear()
        capture("18 App search empty", app)
    }

    func testAddAppHasGuidedSelectionAndKeepsChoiceOnCancel() {
        let app = XCUIApplication.launchOpenAppLock()
        app.buttons["addVolitionAppButton"].waitToAppear().tap()
        app.element("appSelectionStep").waitToAppear()
        capture("19 Add app light", app)
        app.buttons["pickVolitionAppButton"].tap()
        app.element("nativePickerGuidance").waitToAppear()
        capture("20 Selection guidance", app)
        app.buttons["mockVolitionAppOption"].tap()
        app.buttons["pickVolitionAppButton"].waitToAppear()
        app.buttons["pickVolitionAppButton"].tap()
        app.buttons["cancelVolitionAppPickerButton"].waitToAppear().tap()
        XCTAssertTrue(app.buttons["pickVolitionAppButton"].label.contains("Selected app"))
        XCTAssertFalse(app.buttons["saveVolitionAppButton"].isEnabled)
    }
    func testChooserAtLargeTextInDarkMode() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-onboarding-completed", "-seed-scenario=conversation-multiple", "-dark-mode", "-large-text"]
        app.launch()
        app.buttons["conversationChooseAppButton"].waitToAppear().tap()
        app.searchFields.firstMatch.waitToAppear()
        XCTAssertEqual(app.buttons.matching(identifier: "conversationAppOption").count, 2)
        capture("21 App chooser dark large text", app)
    }

    func testDeferringAfterReturningWithdrawsConsent() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-onboarding-required", "-ai-consent-required", "-seed-scenario=conversation"]
        app.launch()
        app.buttons["onboardingContinueButton"].waitToAppear().tap()
        app.buttons["acceptAIConsentButton"].waitToAppear().tap()
        app.buttons["allowScreenTimeButton"].waitToAppear()
        app.buttons["onboardingBackButton"].tap()
        app.buttons["deferAIConsentButton"].waitToAppear().tap()
        app.buttons["allowScreenTimeButton"].waitToAppear().tap()
        app.buttons["conversationChooseAppButton"].waitToAppear()
        app.goToSettingsTab()
        app.element("privacyDataButton").waitToAppear().tap()
        XCTAssertEqual(app.switches["aiConsentToggle"].waitToAppear().value as? String, "0")
    }

}
