import XCTest

final class SettingsUITests: XCTestCase {
    func testSettingsContainsOnlyCoachAndDiagnostics() {
        let app = XCUIApplication.launchOpenAppLock(seedScenario: "conversation")
        app.goToSettingsTab()
        app.element("conversationSettingsButton").waitToAppear()
        app.element("diagnosticsLogsRow").waitToAppear()
        XCTAssertFalse(app.element("notificationSettingsButton").exists)
        XCTAssertFalse(app.element("manageAppListsButton").exists)
        XCTAssertFalse(app.element("uninstallProtectionToggle").exists)
    }
}
