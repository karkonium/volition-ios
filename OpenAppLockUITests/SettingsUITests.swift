import XCTest

final class SettingsUITests: XCTestCase {
    func testChatNotificationSettingsMatchOS() {
        let app = XCUIApplication.launchOpenAppLock(seedScenario: "conversation")
        app.goToSettingsTab()
        app.element("conversationSettingsButton").waitToAppear().tap()
        app.element("openAIKeyStatus").waitToAppear()
        if #available(iOS 26.5, *) {
            XCTAssertFalse(app.buttons["conversationNotificationSettingsButton"].exists)
            XCTAssertFalse(app.staticTexts["conversationNotificationHelp"].exists)
        } else {
            app.buttons["conversationNotificationSettingsButton"].waitToAppear()
            app.staticTexts["conversationNotificationHelp"].waitToAppear()
        }
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
