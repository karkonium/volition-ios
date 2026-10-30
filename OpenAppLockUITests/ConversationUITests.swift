import XCTest

@MainActor
final class ConversationUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func chooseApp(_ app: XCUIApplication) {
        app.buttons["conversationChooseAppButton"].waitToAppear().tap()
        app.buttons["conversationAppOption"].firstMatch.waitToAppear().tap()
    }
    private func send(_ text: String, _ app: XCUIApplication, answerCheckIn: Bool = true) {
        let field = app.element("conversationMessageField").waitToAppear()
        field.tap(); field.typeText(text)
        app.buttons["conversationSendButton"].tap()
        if answerCheckIn, app.buttons["reflectionEmotion-skip"].waitForExistence(timeout: 2) {
            app.buttons["reflectionEmotion-skip"].tap()
        }
    }
    private func capture(_ name: String, _ app: XCUIApplication) {
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = name; image.lifetime = .keepAlways; add(image)
    }
    func testDealAcceptanceEarlyEndAndDecline() {
        let app = XCUIApplication.launchOpenAppLock(seedScenario: "conversation")
        chooseApp(app)
        send("reflect", app)
        app.staticTexts["Ready when you are"].waitToAppear(timeout: 20)
        app.buttons["unlockAfterReflectionButton"].waitToAppear().tap()
        app.buttons["endConversationUnlockButton"].waitToAppear().tap()
        send("deal please", app)
        app.element("conversationDealTerms").waitToAppear()
        XCTAssertFalse(app.buttons["endConversationUnlockButton"].exists)
        capture("Explicit deal offer", app)
        app.buttons["conversationDealDecline"].tap()
        XCTAssertTrue(app.buttons["conversationDealAccept"].waitForNonExistence(timeout: 5))
        send("deal please", app)
        app.buttons["conversationDealAccept"].waitToAppear().tap()
        let end = app.buttons["endConversationUnlockButton"].waitToAppear()
        capture("Accepted deal unlock", app)
        end.tap()
        XCTAssertTrue(end.waitForNonExistence(timeout: 5))
        XCTAssertFalse(app.buttons["conversationDealAccept"].exists)
        capture("Early end retains agreed break without countdown", app)
    }

    func testUserChosenPauseAndThirtyMinuteUnlock() {
        let app = XCUIApplication.launchOpenAppLock(seedScenario: "conversation")
        chooseApp(app)
        send("pause 30", app)
        app.buttons["startReflectionButton"].waitToAppear()
        XCTAssertFalse(app.buttons["skipReflectionButton"].exists)
        capture("User-chosen pause before a thirty-minute session", app)
        app.buttons["startReflectionButton"].tap()
        app.buttons["skipReflectionButton"].waitToAppear().tap()
        XCTAssertFalse(app.buttons["endConversationUnlockButton"].exists)
        app.buttons["unlockAfterReflectionButton"].waitToAppear().tap()
        app.buttons["endConversationUnlockButton"].waitToAppear()
        capture("Thirty-minute unlock", app)
        app.buttons["endConversationUnlockButton"].tap()
        XCTAssertTrue(app.buttons["endConversationUnlockButton"].waitForNonExistence(timeout: 5))
    }

    func testNativeLiveActivityAndCleanup() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-onboarding-completed", "-seed-scenario=conversation", "-ui-testing-live-activity"]
        addUIInterruptionMonitor(withDescription: "Notification permission") { alert in
            if alert.buttons["Allow"].exists { alert.buttons["Allow"].tap(); return true }
            return false
        }
        app.launch()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        if springboard.alerts.buttons["Allow"].waitForExistence(timeout: 5) { springboard.alerts.buttons["Allow"].tap() }
        chooseApp(app)
        send("approve for a purpose", app)
        app.buttons["endConversationUnlockButton"].waitToAppear()
        XCUIDevice.shared.press(.home)
        let top = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.01))
        top.press(forDuration: 0.1, thenDragTo: springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85)))
        let window = springboard.staticTexts["Access window · finish before the timer ends"]
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        capture("Native live countdown on Notification Center", springboard)
        app.activate()
        app.buttons["endConversationUnlockButton"].waitToAppear().tap()
        XCUIDevice.shared.press(.home)
        top.press(forDuration: 0.1, thenDragTo: springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85)))
        XCTAssertTrue(window.waitForNonExistence(timeout: 10))
        capture("Native live countdown removed after ending", springboard)
    }

    func testNativeReminderMilestones() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-onboarding-completed", "-seed-scenario=conversation", "-ui-testing-live-activity"]
        app.launch()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        if springboard.alerts.buttons["Allow"].waitForExistence(timeout: 3) { springboard.alerts.buttons["Allow"].tap() }
        chooseApp(app)
        send("approve 2 for a specific task", app)
        app.buttons["endConversationUnlockButton"].waitToAppear()
        XCUIDevice.shared.press(.home)
        springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.01)).press(forDuration: 0.1,
            thenDragTo: springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85)))
        if springboard.buttons["Allow"].waitForExistence(timeout: 3) { springboard.buttons["Allow"].tap() }
        let minute = springboard.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "1 minute left in your access window")).firstMatch
        XCTAssertTrue(minute.waitForExistence(timeout: 70))
        capture("Native one-minute reminder beside countdown", springboard)
        let thirty = springboard.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "30 seconds left in your access window")).firstMatch
        XCTAssertTrue(thirty.waitForExistence(timeout: 35))
        capture("Native thirty-second reminder", springboard)
        let ten = springboard.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "10 seconds left in your access window")).firstMatch
        XCTAssertTrue(ten.waitForExistence(timeout: 25))
        capture("Native ten-second reminder", springboard)
        app.activate()
        if app.buttons["endConversationUnlockButton"].exists { app.buttons["endConversationUnlockButton"].tap() }
    }

    func testThinkingAndReplyStayVisibleAtBottom() {
        let app = XCUIApplication.launchOpenAppLock(seedScenario: "conversation-long")
        chooseApp(app)
        send("test-loading", app)
        let thinking = app.element("conversationThinking").waitToAppear()
        XCTAssertTrue(thinking.isHittable)
        capture("Thinking visible above composer", app)
        let reply = app.staticTexts["What would you like to accomplish in this app?"].waitToAppear()
        XCTAssertTrue(reply.isHittable)
        XCTAssertFalse(thinking.exists)
        capture("Reply replaces thinking at bottom", app)
    }

    func testReadingOlderMessagesAndSendingReturnsToLatest() {
        let app = XCUIApplication.launchOpenAppLock(seedScenario: "conversation-long")
        chooseApp(app)
        let transcript = app.element("conversationTranscript").waitToAppear()
        transcript.swipeDown()
        transcript.swipeDown()
        app.buttons["conversationJumpLatest"].waitToAppear()
        capture("Reading earlier conversation", app)
        send("Hello from the bottom", app)
        let reply = app.staticTexts["What would you like to accomplish in this app?"].waitToAppear()
        XCTAssertTrue(reply.isHittable)
        XCTAssertFalse(app.buttons["conversationJumpLatest"].exists)
        capture("New reply scrolled above composer", app)
    }

    func testInlineReflectionCanBeSkippedWithoutDisclosure() {
        let app = XCUIApplication.launchOpenAppLock(seedScenario: "conversation")
        chooseApp(app)
        send("reflect before relaxing", app)
        capture("Reflection immediately after send", app)
        app.element("reflectionCountdown").waitToAppear(timeout: 3)
        XCTAssertFalse(app.buttons["endConversationUnlockButton"].exists)
        capture("Inline optional reflection", app)
        app.buttons["skipReflectionButton"].waitToAppear().tap()
        XCTAssertFalse(app.buttons["endConversationUnlockButton"].exists)
        app.buttons["unlockAfterReflectionButton"].waitToAppear().tap()
        app.buttons["endConversationUnlockButton"].waitToAppear()
        XCTAssertFalse(app.buttons["skipReflectionButton"].exists)
        XCTAssertTrue(app.element("conversationMessageField").isEnabled)
        capture("Reflection completed unlock", app)
    }

    func testElapsedReflectionKeepsChoicesUntilAnswered() {
        let app = XCUIApplication.launchOpenAppLock(seedScenario: "conversation")
        chooseApp(app)
        send("reflect", app, answerCheckIn: false)
        XCTAssertFalse(app.element("reflectionCountdown").exists)
        XCTAssertFalse(app.buttons["unlockAfterReflectionButton"].exists)
        XCTAssertFalse(app.buttons["endConversationUnlockButton"].exists)
        let choice = app.buttons["reflectionEmotion-skip"].waitToAppear()
        XCTAssertTrue(choice.isHittable)
        capture("Elapsed pause waits for a check-in", app)
        choice.tap()
        XCTAssertFalse(app.buttons["endConversationUnlockButton"].exists)
        app.buttons["unlockAfterReflectionButton"].waitToAppear(timeout: 20).tap()
        app.buttons["endConversationUnlockButton"].waitToAppear()
        capture("Explicit unlock after optional check-in", app)
    }

    func testOptionalEmotionAndExplicitReflectionUnlock() {
        let app = XCUIApplication.launchOpenAppLock(seedScenario: "conversation")
        chooseApp(app)
        send("reflect", app, answerCheckIn: false)
        app.buttons["reflectionEmotion-boredom"].waitToAppear().tap()
        XCTAssertFalse(app.buttons["endConversationUnlockButton"].exists)
        app.buttons["unlockAfterReflectionButton"].waitToAppear(timeout: 20).tap()
        app.buttons["endConversationUnlockButton"].waitToAppear()
        capture("Reflection explicitly completed", app)
    }

    func testKeepingLockedAndDelayOrDealChoice() {
        let app = XCUIApplication.launchOpenAppLock(seedScenario: "conversation")
        chooseApp(app)
        send("reflect", app)
        app.buttons["skipReflectionButton"].waitToAppear().tap()
        app.buttons["unlockAfterReflectionButton"].waitToAppear()
        capture("Delay ended without unlocking", app)
        app.buttons["cancelReflectionButton"].tap()
        XCTAssertFalse(app.buttons["endConversationUnlockButton"].exists)
        send("choice", app)
        app.buttons["conversationChooseDelayButton"].waitToAppear()
        capture("Optional check-in with delay or deal", app)
        app.buttons["conversationChooseDelayButton"].tap()
        app.buttons["skipReflectionButton"].waitToAppear().tap()
        app.buttons["cancelReflectionButton"].tap()
        send("choice", app)
        app.buttons["conversationChooseDealButton"].waitToAppear().tap()
        app.buttons["endConversationUnlockButton"].waitToAppear()
        capture("Pinned compact unlock banner", app)
        let before = app.buttons["endConversationUnlockButton"].frame
        app.element("conversationTranscript").swipeDown()
        XCTAssertEqual(app.buttons["endConversationUnlockButton"].frame, before)
        app.buttons["endConversationUnlockButton"].tap()
        XCTAssertTrue(app.buttons["endConversationUnlockButton"].waitForNonExistence(timeout: 5))
    }

    func testCustomEmotionFeedbackAndThreeWayOpen() {
        let app = XCUIApplication.launchOpenAppLock(seedScenario: "conversation")
        chooseApp(app)
        send("reflect", app, answerCheckIn: false)
        app.buttons["reflectionEmotion-other"].waitToAppear().tap()
        let field = app.textFields["customEmotionField"].waitToAppear()
        field.tap(); field.typeText("Restless")
        capture("Custom emotion entry", app)
        app.buttons["customEmotionSubmitButton"].waitToAppear().tap()
        app.buttons["skipReflectionButton"].waitToAppear().tap()
        app.buttons["cancelReflectionButton"].waitToAppear().tap()
        app.buttons["experienceRating-annoying"].waitToAppear().tap()
        capture("Optional experience feedback", app)
        send("choice", app, answerCheckIn: false)
        XCTAssertFalse(app.buttons["reflectionEmotion-skip"].exists)
        app.buttons["conversationChooseDelayButton"].waitToAppear()
        app.buttons["conversationChooseDealButton"].waitToAppear()
        let open = app.buttons["conversationChooseOpenButton"].waitToAppear()
        if !open.isHittable { app.element("conversationTranscript").swipeUp() }
        capture("Three intervention choices", app)
        open.tap()
        app.buttons["endConversationUnlockButton"].waitToAppear().tap()
    }

    func testFeedbackRatingsStayInOneRow() {
        verifyFeedbackRow(largeText: false)
    }

    func testFeedbackRatingsScrollAtAccessibilityTextSize() {
        verifyFeedbackRow(largeText: true)
    }

    private func verifyFeedbackRow(largeText: Bool) {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-onboarding-completed", "-seed-scenario=conversation"]
        if largeText { app.launchArguments += ["-large-text", "-dark-mode"] }
        app.launch()
        chooseApp(app)
        send("deny", app)
        let helpful = app.buttons["experienceRating-helpful"].waitToAppear()
        let neutral = app.buttons["experienceRating-neutral"].waitToAppear()
        let annoying = app.buttons["experienceRating-annoying"].waitToAppear()
        XCTAssertEqual(helpful.frame.minY, neutral.frame.minY, accuracy: 1)
        XCTAssertEqual(neutral.frame.minY, annoying.frame.minY, accuracy: 1)
        for button in [helpful, neutral, annoying] { XCTAssertGreaterThanOrEqual(button.frame.height, 43.5) }
        let row = app.scrollViews["conversationFeedbackOptions"].waitToAppear()
        capture(largeText ? "Feedback row at accessibility text size" : "Helpful neutral annoying in one row", app)
        if !annoying.isHittable { row.swipeLeft() }
        if !annoying.isHittable { row.swipeLeft() }
        annoying.tap()
        XCTAssertTrue(app.buttons["experienceRating-annoying"].waitToAppear().isSelected)
        capture("Feedback selection remains visible", app)
        XCTAssertFalse(app.buttons["endConversationUnlockButton"].exists)
    }

    func testMinimalRepliesAndNoRedundantStatusMessages() {
        let app = XCUIApplication.launchOpenAppLock(seedScenario: "conversation")
        chooseApp(app)
        send("approve", app)
        app.buttons["endConversationUnlockButton"].waitToAppear()
        app.buttons["experienceRating-helpful"].waitToAppear().tap()
        let transcript = app.element("conversationTranscript")
        XCTAssertFalse(transcript.staticTexts["Volition"].exists)
        XCTAssertFalse(transcript.staticTexts["Access approved"].exists)
        XCTAssertFalse(transcript.staticTexts["Thanks for the feedback."].exists)
        XCTAssertFalse(app.element("conversationMessage-event").exists)
        XCTAssertTrue(app.staticTexts["Take one minute for that purpose."].exists)
        capture("Minimal reply with unlock banner and feedback", app)
        app.buttons["endConversationUnlockButton"].tap()
        send("deal", app)
        app.buttons["conversationDealAccept"].waitToAppear().tap()
        app.buttons["endConversationUnlockButton"].waitToAppear()
        XCTAssertFalse(app.element("conversationMessage-event").exists)
        capture("Accepted deal without duplicate notices", app)
        app.buttons["endConversationUnlockButton"].tap()
    }

    func testOneHourAccessForPlannedWork() {
        let app = XCUIApplication.launchOpenAppLock(seedScenario: "conversation")
        chooseApp(app)
        send("approve 60 for a planned work session", app)
        app.buttons["endConversationUnlockButton"].waitToAppear()
        capture("One-hour access with optional feedback", app)
        app.buttons["experienceRating-helpful"].waitToAppear().tap()
        app.buttons["endConversationUnlockButton"].tap()
    }

    func testEmotionPrecedesDealOffer() {
        let app = XCUIApplication.launchOpenAppLock(seedScenario: "conversation")
        chooseApp(app)
        send("deal", app, answerCheckIn: false)
        app.buttons["reflectionEmotion-boredom"].waitToAppear()
        XCTAssertFalse(app.element("conversationDealTerms").exists)
        XCTAssertFalse(app.buttons["conversationDealAccept"].exists)
        capture("Emotion message before any deal terms", app)
        app.buttons["reflectionEmotion-boredom"].tap()
        app.buttons["conversationDealAccept"].waitToAppear()
        XCTAssertFalse(app.buttons["reflectionEmotion-boredom"].exists)
        capture("Separate deal message after emotion answer", app)
        app.buttons["conversationDealAccept"].tap()
        app.buttons["endConversationUnlockButton"].waitToAppear()
    }

    func testDealChoiceCanBeAcceptedDirectly() {
        let app = XCUIApplication.launchOpenAppLock(seedScenario: "conversation")
        chooseApp(app)
        send("choice", app)
        app.buttons["conversationChooseDealButton"].waitToAppear()
        capture("Direct deal choice with optional emotion check-in", app)
        app.buttons["conversationChooseDealButton"].tap()
        app.buttons["endConversationUnlockButton"].waitToAppear()
        capture("Direct deal accepted with pinned banner", app)
        app.buttons["endConversationUnlockButton"].tap()
        XCTAssertTrue(app.buttons["endConversationUnlockButton"].waitForNonExistence(timeout: 5))
    }

    func testMissingAppGuidanceAndReadableActivityLog() {
        let app = XCUIApplication.launchOpenAppLock(seedScenario: "conversation")
        XCTAssertEqual(app.buttons["conversationSendButton"].waitToAppear().value as? String,
            "Choose an app above, or type its saved name in your message.")
        send("Hello", app)
        let attention = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "App selection needed"),
            object: app.buttons["conversationChooseAppButton"])
        XCTAssertEqual(XCTWaiter.wait(for: [attention], timeout: 5), .completed)
        app.staticTexts["conversationAppSelectionHint"].waitToAppear()
        XCTAssertFalse(app.staticTexts["conversationErrorLabel"].exists)
        XCTAssertEqual(app.element("conversationMessageField").value as? String, "Hello")
        capture("Choose an app guidance", app)
        chooseApp(app)
        XCTAssertEqual(app.buttons["conversationSendButton"].value as? String, "")
        app.buttons["conversationSendButton"].tap()
        app.staticTexts["What would you like to accomplish in this app?"].waitToAppear()
        app.goToSettingsTab()
        app.element("conversationActivityLogButton").waitToAppear().tap()
        app.staticTexts["App selection needed"].waitToAppear()
        app.staticTexts["Question asked"].waitToAppear()
        capture("Readable activity log", app)
        app.buttons["exportActivityLogButton"].waitToAppear().tap()
        app.buttons["Readable text (.txt)"].waitToAppear()
        app.buttons["JSON Lines (.jsonl)"].waitToAppear()
        app.buttons["Readable text (.txt)"].tap()
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Volition-activity"))
            .firstMatch.waitToAppear()
        capture("Activity log export share sheet", app)
    }

    func testPinnedUnlockBannersAtLargeText() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-onboarding-completed", "-seed-scenario=conversation-multiple", "-dark-mode", "-large-text"]
        app.launch()
        chooseApp(app)
        send("approve 2", app)
        app.buttons["endConversationUnlockButton"].waitToAppear()
        app.buttons["conversationChooseAppButton"].tap()
        app.buttons.matching(identifier: "conversationAppOption").element(boundBy: 1).waitToAppear().tap()
        send("approve 2", app)
        let ends = app.buttons.matching(identifier: "endConversationUnlockButton")
        let both = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in ends.count == 2 }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [both], timeout: 10), .completed)
        XCTAssertTrue(ends.element(boundBy: 0).isHittable)
        XCTAssertTrue(ends.element(boundBy: 1).isHittable)
        capture("Independent pinned banners dark large text", app)
        ends.element(boundBy: 0).tap()
        let one = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in ends.count == 1 }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [one], timeout: 10), .completed)
        XCTAssertTrue(ends.firstMatch.isHittable)
        capture("Ending one banner retains the other", app)
    }
    func testNamedAppRoutesWithoutOpeningThePicker() {
        let app = XCUIApplication.launchOpenAppLock(seedScenario: "conversation-multiple")
        send("approve App 12 for one minute", app)
        app.buttons["endConversationUnlockButton"].waitToAppear()
        XCTAssertTrue(app.buttons["conversationChooseAppButton"].label.contains("App 12"))
        XCTAssertFalse(app.element("conversationAppSelectionHint").exists)
        capture("Named app selected automatically", app)
        app.goToSettingsTab()
        app.element("conversationActivityLogButton").waitToAppear().tap()
        app.staticTexts["Unlocked"].waitToAppear()
        app.staticTexts["approve App 12 for one minute"].waitToAppear()
        capture("Actual unlock in activity log", app)
    }
    func testSharedConversationFollowUpDenialAndApproval() {
        let app = XCUIApplication.launchOpenAppLock(seedScenario: "conversation")
        chooseApp(app)
        send("Hello", app)
        app.staticTexts["What would you like to accomplish in this app?"].waitToAppear()
        send("deny this request", app)
        app.staticTexts["This does not support your goal."].waitToAppear()
        send("approve a purposeful task", app)
        app.buttons["endConversationUnlockButton"].waitToAppear().tap()
        app.staticTexts["Unlock ended."].waitToAppear()
    }
    func testComposerFocusAndDraftAcrossPickerAndTabs() {
        let app = XCUIApplication.launchOpenAppLock(seedScenario: "conversation")
        chooseApp(app)
        let field = app.element("conversationMessageField").waitToAppear()
        field.tap(); field.typeText("approve a purposeful task")
        chooseApp(app)
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))
        app.goToAppsTab(); app.goToChatTab()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))
        XCTAssertEqual(field.value as? String, "approve a purposeful task")
        app.buttons["conversationSendButton"].tap()
        app.buttons["endConversationUnlockButton"].waitToAppear()
        XCTAssertTrue(field.isEnabled)
        XCTAssertFalse(app.element("conversationNicknameField").exists)
    }
    func testHistoryDeletion() {
        let app = XCUIApplication.launchOpenAppLock(seedScenario: "conversation")
        chooseApp(app); send("Hello", app)
        app.staticTexts["What would you like to accomplish in this app?"].waitToAppear()
        app.goToSettingsTab()
        app.element("conversationSettingsButton").waitToAppear().tap()
        app.buttons["clearConversationHistoryButton"].waitToAppear().tap()
        app.sheets.buttons["Clear conversation history"].waitToAppear().tap()
        app.goToChatTab()
        app.staticTexts["What would you like to make time for?"].waitToAppear()
    }
}
