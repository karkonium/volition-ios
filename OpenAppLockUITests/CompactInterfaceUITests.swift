import XCTest

/// Captures the compact presentation using mock apps, authorization and coach.
/// Screenshots are real renders; no Screen Time or live-model claim is implied.
final class CompactInterfaceUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func capture(_ name: String, _ app: XCUIApplication) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
    private func navigate(_ name: String, _ app: XCUIApplication) {
        let tab = app.tabBars.buttons[name]
        if tab.waitForExistence(timeout: 2) { tab.tap() }
        else { app.element("sidebarItem-\(name.lowercased())").waitToAppear().tap() }
    }
    func testCompactLightScreenTour() {
        let app = XCUIApplication.launchOpenAppLock(seedScenario: "conversation-multiple")
        app.buttons["conversationChooseAppButton"].waitToAppear()
        capture("01 Chat light", app)
        app.goToAppsTab()
        let header = app.element("compactAppsHeader").waitToAppear()
        XCTAssertLessThan(header.frame.minY, 220, "The app library should begin near the navigation bar.")
        capture("02 Apps light", app)
        navigate("Insights", app)
        app.segmentedControls.firstMatch.waitToAppear()
        capture("03 Insights light", app)
        navigate("Focus", app)
        app.buttons["startFocusSessionButton"].waitToAppear()
        capture("04 Focus light", app)
        app.buttons["startFocusSessionButton"].tap()
        app.buttons["endFocusButton"].waitToAppear()
        capture("05 Focus active light", app)
        app.goToSettingsTab()
        app.element("conversationSettingsButton").waitToAppear()
        capture("06 Settings light", app)
        app.element("privacyDataButton").tap()
        app.switches["aiConsentToggle"].waitToAppear()
        capture("07 Privacy light", app)
    }
    func testEditorsHaveDistinctControls() {
        let app = XCUIApplication.launchOpenAppLock(seedScenario: "conversation-multiple")
        app.goToAppsTab()
        app.buttons["volitionApp-App 11"].waitToAppear().tap()
        app.textFields["volitionAppName"].waitToAppear()
        app.textViews["volitionAppIntention"].waitToAppear()
        capture("12 App editor light", app)
        app.buttons["Cancel"].firstMatch.tap()
        app.buttons["addVolitionAppButton"].waitToAppear()
        navigate("Focus", app)
        app.buttons["addFocusScheduleButton"].waitToAppear().tap()
        app.textFields["focusScheduleName"].waitToAppear()
        XCTAssertFalse(app.buttons["saveFocusScheduleButton"].isEnabled)
        XCTAssertEqual(app.buttons["saveFocusScheduleButton"].label, "Save")
        capture("13 Protected period editor light", app)
        app.buttons["Cancel"].firstMatch.tap()
        app.buttons["addFocusScheduleButton"].waitToAppear()
    }

    func testDarkLargeTextScreenTour() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-onboarding-completed", "-seed-scenario=conversation-multiple", "-dark-mode", "-large-text"]
        app.launch()
        app.buttons["conversationChooseAppButton"].waitToAppear()
        capture("08 Chat dark large text", app)
        app.goToAppsTab()
        app.buttons["addVolitionAppButton"].waitToAppear()
        capture("09 Apps dark large text", app)
        navigate("Insights", app)
        app.segmentedControls.firstMatch.waitToAppear()
        capture("10 Insights dark large text", app)
        navigate("Focus", app)
        app.buttons["startFocusSessionButton"].waitToAppear()
        capture("11 Focus dark large text", app)
    }
}
