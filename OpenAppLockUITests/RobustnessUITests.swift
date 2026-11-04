import XCTest

@MainActor
final class RobustnessUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    func testAppValidationAndDiscardKeepDraft() {
        let app = XCUIApplication.launchOpenAppLock()
        app.buttons["addVolitionAppButton"].waitToAppear().tap()
        app.buttons["saveVolitionAppButton"].waitToAppear().tap()
        app.buttons["pickVolitionAppButton"].tap()
        app.buttons["mockVolitionAppOption"].waitToAppear().tap()
        app.buttons["saveVolitionAppButton"].waitToAppear().tap()
        app.staticTexts["volitionAppNameRequired"].waitToAppear()
        let name = app.textFields["volitionAppName"]
        name.tap(); name.typeText(String(repeating: "a", count: 101))
        app.buttons["saveVolitionAppButton"].tap()
        app.staticTexts["volitionAppNameError"].waitToAppear()
        capture("App name limit highlighted", app)
        app.buttons["Cancel"].firstMatch.tap()
        app.buttons["Keep editing"].waitToAppear().tap()
        XCTAssertEqual(name.value as? String, String(repeating: "a", count: 101))
        app.buttons["Cancel"].firstMatch.tap()
        app.buttons["Discard changes"].waitToAppear().tap()
        app.buttons["addVolitionAppButton"].waitToAppear()
    }
    func testFocusValidationAndDirtyDraft() {
        let app = XCUIApplication.launchOpenAppLock(seedScenario: "conversation")
        if app.tabBars.buttons["Focus"].waitForExistence(timeout: 2) { app.tabBars.buttons["Focus"].tap() }
        else { app.element("sidebarItem-focus").waitToAppear().tap() }
        app.buttons["addFocusScheduleButton"].waitToAppear().tap()
        app.buttons["saveFocusScheduleButton"].waitToAppear().tap()
        app.staticTexts["focusNameError"].waitToAppear()
        let name = app.textFields["focusScheduleName"]
        name.tap(); name.typeText("Work")
        capture("Focus validation and editable draft", app)
        app.buttons["Cancel"].firstMatch.tap()
        app.buttons["Keep editing"].waitToAppear().tap()
        XCTAssertEqual(name.value as? String, "Work")
        app.buttons["saveFocusScheduleButton"].tap()
        app.staticTexts["Work"].waitToAppear()
    }
    func testRemovalStillWorksWhenHistoryStorageFails() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-onboarding-completed", "-seed-scenario=conversation", "-unavailable-history"]
        app.launch()
        app.goToAppsTab()
        app.buttons["volitionApp-Intentional Access"].waitToAppear().tap()
        app.swipeUp()
        app.buttons["removeVolitionAppButton"].waitToAppear().tap()
        app.buttons["removalWithoutFeedbackButton"].waitToAppear()
        capture("Removal remains available after feedback failure", app)
        app.buttons["removalWithoutFeedbackButton"].tap()
        XCTAssertTrue(app.buttons["volitionApp-Intentional Access"].waitForNonExistence(timeout: 5))
    }
}
