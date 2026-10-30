//
//  NavigationChromeUITests.swift
//  OpenAppLockUITests
//

import XCTest

/// The post-onboarding shell adapts its navigation chrome to the available width:
/// a bottom tab bar on iPhone (compact), a left sidebar on full-screen iPad
/// (regular). These flows run on whatever destination the suite is launched
/// against and branch on the device idiom, so the same test validates both legs
/// of the CI matrix.
@MainActor
final class NavigationChromeUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// iPad shows a sidebar and no tab bar; iPhone shows a tab bar and no sidebar.
    func testNavigationChromeMatchesIdiom() throws {
        let app = XCUIApplication.launchOpenAppLock(seedScenario: "conversation")

        if UIDevice.current.userInterfaceIdiom == .pad {
            app.element("sidebarItem-chat").waitToAppear()
            app.element("sidebarItem-apps").waitToAppear()
            app.element("sidebarItem-settings").waitToAppear()
            XCTAssertFalse(
                app.tabBars.firstMatch.exists,
                "Full-screen iPad should use a sidebar, not a bottom tab bar"
            )
        } else {
            app.tabBars.buttons["Chat"].waitToAppear()
            XCTAssertFalse(
                app.element("sidebarItem-chat").exists,
                "iPhone should use a bottom tab bar, not a sidebar"
            )
        }
    }

    func testTabRootsHaveNoTopTitleAndSettingsDetailsCanGoBack() {
        let app = XCUIApplication.launchOpenAppLock(seedScenario: "conversation")
        let sections = [("Chat", "conversationChooseAppButton"), ("Apps", "addVolitionAppButton"),
            ("Insights", "insightsRangePicker"), ("Focus", "startFocusSessionButton"), ("Settings", "conversationSettingsButton")]
        for (title, marker) in sections {
            if app.tabBars.buttons[title].exists { app.tabBars.buttons[title].tap() }
            else { app.element("sidebarItem-\(title.lowercased())").waitToAppear().tap() }
            app.element(marker).waitToAppear()
            XCTAssertFalse(app.navigationBars[title].exists)
            let shot = XCTAttachment(screenshot: app.screenshot())
            shot.name = "Title-free \(title)"; shot.lifetime = .keepAlways; add(shot)
        }
        app.buttons["privacyDataButton"].tap()
        app.switches["aiConsentToggle"].waitToAppear()
        let bar = app.navigationBars["Privacy & Data"]
        XCTAssertTrue(bar.waitForExistence(timeout: 5))
        bar.buttons.firstMatch.tap()
        app.buttons["conversationSettingsButton"].waitToAppear()
        XCTAssertFalse(app.navigationBars["Settings"].exists)
    }

    /// Every section is reachable through whichever chrome is presented, proving
    /// the shared `goTo…` helpers drive both the tab bar and the sidebar.
    func testEverySectionIsReachable() throws {
        let app = XCUIApplication.launchOpenAppLock(seedScenario: "conversation")

        app.goToAppsTab()
        app.element("addVolitionAppButton").waitToAppear()

        app.goToSettingsTab()
        app.element("conversationSettingsButton").waitToAppear()

        app.goToChatTab()
        app.element("conversationChooseAppButton").waitToAppear()
    }
}
