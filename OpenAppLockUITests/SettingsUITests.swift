import XCTest

@MainActor
final class SettingsUITests: XCTestCase {
    func testChatNotificationSettingsMatchOS() {
        let app = XCUIApplication.launchOpenAppLock(seedScenario: "conversation")
        app.goToSettingsTab()
        app.element("conversationSettingsButton").waitToAppear().tap()
        app.element("openAIKeyStatus").waitToAppear()
        // Shield routing is direct on newer iOS, but unlock reminders still
        // require a notification-permission/settings entry on every version.
        app.buttons["conversationNotificationSettingsButton"].waitToAppear()
        app.staticTexts["conversationNotificationHelp"].waitToAppear()
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "Coach settings for this iOS version"; shot.lifetime = .keepAlways; add(shot)
    }
    func testSettingsContainsCoachActivityAndDiagnostics() {
        let app = XCUIApplication.launchOpenAppLock(seedScenario: "conversation")
        app.goToSettingsTab()
        app.element("conversationSettingsButton").waitToAppear()
        app.element("conversationActivityLogButton").waitToAppear()
        app.element("diagnosticsLogsRow").waitToAppear()
        XCTAssertFalse(app.element("notificationSettingsButton").exists)
        XCTAssertFalse(app.element("manageAppListsButton").exists)
        XCTAssertFalse(app.element("uninstallProtectionToggle").exists)
    }
}
