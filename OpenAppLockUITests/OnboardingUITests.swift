//
//  OnboardingUITests.swift
//  OpenAppLockUITests
//

import XCTest

final class OnboardingUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testOnboardingWalksThroughPermissionToAppSetup() throws {
        let app = XCUIApplication.launchOpenAppLock(onboardingCompleted: false)

        // Welcome step.
        app.staticTexts["Welcome to Volition"].waitToAppear()
        let branding = XCTAttachment(screenshot: app.screenshot())
        branding.name = "Volition sunlit V welcome"
        branding.lifetime = .keepAlways
        add(branding)
        app.buttons["onboardingContinueButton"].waitToAppear().tap()

        // Permission step: granting (mocked) lands on the main app, in whichever
        // navigation chrome the device uses (tab bar on iPhone, sidebar on iPad).
        app.buttons["allowScreenTimeButton"].waitToAppear().tap()
        app.buttons["addVolitionAppButton"].waitToAppear()
        XCTAssertFalse(app.buttons["finishVolitionSetupButton"].isEnabled)
    }

    func testCompletedOnboardingIsSkipped() throws {
        let app = XCUIApplication.launchOpenAppLock(onboardingCompleted: true, seedScenario: "conversation")
        app.waitForMainUI()
        XCTAssertFalse(app.buttons["onboardingContinueButton"].exists)
    }
}
