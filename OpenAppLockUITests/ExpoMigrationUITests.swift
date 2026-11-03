import XCTest

/// Opt-in presentation acceptance for the Expo development preview. The runner
/// installs the separately built Expo simulator app at the existing test host
/// path; ordinary native runs skip these checks and retain their own harness.
@MainActor
final class ExpoMigrationUITests: XCTestCase {
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    private func control(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }
    func testScreensAndExplicitDelayUnlock() throws {
        guard ProcessInfo.processInfo.environment["VOLITION_EXPO_UI_TESTS"] == "1" else {
            throw XCTSkip("Requires the separately installed Expo development preview")
        }
        let app = XCUIApplication(bundleIdentifier: "com.a5karki.volition")
        app.launch()
        XCTAssertTrue(control(app, "conversationChooseAppButton").waitForExistence(timeout: 90))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Preview mode")).firstMatch.waitForExistence(timeout: 10))
        capture(app, "Expo Chat")
        for name in ["apps", "insights", "focus", "settings", "chat"] {
            let tab = control(app, "sidebarItem-\(name)")
            XCTAssertTrue(tab.waitForExistence(timeout: 10))
            tab.tap()
            capture(app, "Expo \(name)")
        }
        control(app, "conversationChooseAppButton").tap()
        let option = control(app, "conversationAppOption")
        XCTAssertTrue(option.waitForExistence(timeout: 10)); option.tap()
        let field = app.textViews["conversationMessageField"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap(); field.typeText("YouTube to learn for five minutes")
        control(app, "conversationSendButton").tap()
        let skip = control(app, "skipReflectionButton")
        if skip.waitForExistence(timeout: 5) { skip.tap() }
        let delay = control(app, "startReflectionButton")
        XCTAssertTrue(delay.waitForExistence(timeout: 15))
        capture(app, "Expo Choice")
        delay.tap()
        XCTAssertTrue(control(app, "reflectionCountdown").waitForExistence(timeout: 10))
        XCTAssertFalse(control(app, "endConversationUnlockButton").exists)
        capture(app, "Expo Delay")
        let unlock = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Unlock for")).firstMatch
        XCTAssertTrue(unlock.waitForExistence(timeout: 20))
        XCTAssertFalse(control(app, "endConversationUnlockButton").exists)
        capture(app, "Expo Explicit Unlock Required")
        unlock.tap()
        XCTAssertTrue(control(app, "endConversationUnlockButton").waitForExistence(timeout: 15))
        capture(app, "Expo Confirmed Grant")
        control(app, "endConversationUnlockButton").tap()
        XCTAssertTrue(control(app, "conversationMessageField").waitForExistence(timeout: 10))
        capture(app, "Expo Outcome Feedback")
    }
}
