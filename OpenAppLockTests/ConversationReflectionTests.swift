import Foundation
import Testing
@testable import OpenAppLock

@MainActor @Suite("Voluntary reflection contract")
struct ConversationReflectionTests {
    @Test func pauseRequiresSeparateValidatedSecondsAndUnlock() throws {
        let valid = Data(#"{"reply":"Let’s take a moment.","decision":"pause","unlock_minutes":5,"pause_seconds":10,"wait_minutes":null}"#.utf8)
        #expect(try ConversationDecision.parse(valid).pauseSeconds == 10)
        for seconds in [0, 9, 1801, 3600] {
            let json = "{\"reply\":\"Pause\",\"decision\":\"pause\",\"unlock_minutes\":5,\"pause_seconds\":\(seconds)}"
            #expect(throws: (any Error).self) { try ConversationDecision.parse(Data(json.utf8)) }
        }
        for json in [
            #"{"reply":"Pause","decision":"pause","unlock_minutes":null,"pause_seconds":10}"#,
            #"{"reply":"Pause","decision":"pause","unlock_minutes":61,"pause_seconds":10}"#,
            #"{"reply":"Yes","decision":"approve","unlock_minutes":5,"pause_seconds":10}"#,
            #"{"reply":"Pause","decision":"pause","unlock_minutes":5,"pause_seconds":10,"wait_minutes":1}"#
        ] { #expect(throws: (any Error).self) { try ConversationDecision.parse(Data(json.utf8)) } }
    }

    @Test func overrideRequiresReplacementDealTerms() throws {
        let valid = Data(#"{"reply":"Five minutes then a longer break?","decision":"override","unlock_minutes":5,"block_minutes":60}"#.utf8)
        #expect(try ConversationDecision.parse(valid).blockMinutes == 60)
        #expect(throws: (any Error).self) {
            try ConversationDecision.parse(Data(#"{"reply":"Exception","decision":"override","unlock_minutes":5}"#.utf8))
        }
    }

    @Test func emotionCooldownHasExactGlobalBoundaryAndPersists() throws {
        let now = Date(timeIntervalSince1970: 1000)
        var history = ConversationHistory()
        #expect(history.canAskEmotion(at: now))
        history.lastEmotionQuestionAt = now
        #expect(!history.canAskEmotion(at: now.addingTimeInterval(119.999)))
        #expect(history.canAskEmotion(at: now.addingTimeInterval(120)))
        let decoded = try JSONDecoder().decode(ConversationHistory.self, from: JSONEncoder().encode(history))
        #expect(!decoded.canAskEmotion(at: now.addingTimeInterval(30)))
    }

    @Test func oldArchivesHaveNoProfilesOrReflections() throws {
        let history = try JSONDecoder().decode(ConversationHistory.self,
            from: Data(#"{"messages":[],"memory":"old goal","summarizedCount":0}"#.utf8))
        #expect(history.usageProfiles.isEmpty)
        #expect(history.reflections.isEmpty)
    }

    @Test func reflectionDeadlineAndConsentSurviveEncoding() throws {
        let now = Date(timeIntervalSince1970: 1000)
        var pause = ConversationReflection(appID: UUID(), appName: "Game", reason: "Relax", reply: "A moment first?",
            unlockMinutes: 5, seconds: 10, fingerprint: "configuration", activityID: UUID(), now: now)
        #expect(pause.deadline == now.addingTimeInterval(10))
        #expect(pause.isReady(at: now.addingTimeInterval(10)))
        pause.emotion = .boredom
        #expect(pause.isReady(at: now.addingTimeInterval(10)))
        #expect(!pause.isReady(at: now.addingTimeInterval(9)))
        let longer = ConversationReflection(appID: UUID(), appName: "Browser", reason: "Read", reply: "Pause?",
            unlockMinutes: 3, seconds: 180, fingerprint: "configuration", activityID: UUID(), now: now)
        #expect(longer.state == .offered)
        #expect(longer.deadline == nil)
        #expect(!longer.isReady(at: now.addingTimeInterval(500)))
        let decoded = try JSONDecoder().decode(ConversationReflection.self, from: JSONEncoder().encode(pause))
        #expect(decoded == pause)
    }
    @Test func dealsRequireExclusiveBoundedTerms() throws {
        let data = Data(#"{"reply":"A deal?","decision":"deal","unlock_minutes":3,"block_minutes":10,"pause_seconds":null,"wait_minutes":null}"#.utf8)
        #expect(try ConversationDecision.parse(data).blockMinutes == 10)
        for minutes in [0, 1441] {
            let json = "{\"reply\":\"Deal\",\"decision\":\"deal\",\"unlock_minutes\":3,\"block_minutes\":\(minutes)}"
            #expect(throws: (any Error).self) { try ConversationDecision.parse(Data(json.utf8)) }
        }
        #expect(throws: (any Error).self) {
            try ConversationDecision.parse(Data(#"{"reply":"Yes","decision":"approve","unlock_minutes":3,"block_minutes":10}"#.utf8))
        }
    }

    @Test func interventionChoiceRequiresBothValidatedOptions() throws {
        let choice = Data(#"{"reply":"A delay or a deal?","decision":"choice","unlock_minutes":3,"pause_seconds":20,"block_minutes":30,"wait_minutes":null}"#.utf8)
        #expect(try ConversationDecision.parse(choice).decision == .choice)
        for field in ["pause_seconds", "block_minutes", "unlock_minutes"] {
            var object = try #require(JSONSerialization.jsonObject(with: choice) as? [String: Any])
            object[field] = NSNull()
            #expect(throws: (any Error).self) { try ConversationDecision.parse(JSONSerialization.data(withJSONObject: object)) }
        }
    }

    @Test func sessionCountsOnlyConfirmedGrantsToday() {
        let now = Date()
        let app = UUID(), other = UUID()
        let events: [ConversationAccessEvent] = [
            .init(date: now, appID: app, appName: "App", reason: "Task", decision: .approve, reply: "OK", grantID: UUID(), expiresAt: now.addingTimeInterval(300)),
            .init(date: now, appID: other, appName: "Other", reason: "Task", decision: .approve, reply: "OK", grantID: UUID(), expiresAt: now.addingTimeInterval(600)),
            .init(date: now, appID: app, appName: "App", reason: "Task", decision: .approve, reply: "Failed"),
            .init(date: now, appID: app, appName: "App", reason: "Task", decision: .deal, reply: "Offer")
        ]
        let summary = ConversationActivitySummary(events: events, appID: app, now: now)
        #expect(summary.sameAppGrantedMinutesToday == 5)
        #expect(summary.shortGrantsToday == 1)
        #expect(summary.longGrantsToday == 1)
        #expect(summary.sameAppShortGrantsToday == 1)
        #expect(summary.sameAppLongGrantsToday == 0)
    }

    @Test func recommendedShortPauseProgressesOnlyForStartedSameAppPauses() {
        let app = UUID(), now = Date()
        var history = ConversationHistory()
        #expect(history.recommendedPauseSeconds(for: app, now: now) == 10)
        let unstarted = ConversationReflection(appID: app, appName: "App", reason: "Bored", reply: "Pause?", unlockMinutes: 3,
            seconds: 20, fingerprint: "same", activityID: UUID(), now: now)
        history.reflections.append(unstarted)
        #expect(history.recommendedPauseSeconds(for: app, now: now) == 10)
        for count in 1...8 {
            var pause = ConversationReflection(appID: app, appName: "App", reason: "Bored", reply: "Pause", unlockMinutes: 3,
                seconds: 10, fingerprint: "same", activityID: UUID(), now: now)
            pause.state = .completed
            history.reflections.append(pause)
            #expect(history.recommendedPauseSeconds(for: app, now: now) == min(60, 10 + count * 10))
        }
        #expect(history.recommendedPauseSeconds(for: UUID(), now: now) == 10)
        #expect(history.recommendedPauseSeconds(for: app, now: now.addingTimeInterval(86401)) == 10)
    }

    @Test func twoRecentStartedPausesCountEvenIfEndedEarlyOrKeptLocked() {
        let app = UUID(), now = Date()
        var history = ConversationHistory()
        for skipped in [false, true] {
            var pause = ConversationReflection(appID: app, appName: "App", reason: "Bored", reply: "Delay",
                unlockMinutes: 3, seconds: 10, fingerprint: "same", activityID: UUID(), now: now)
            pause.state = .cancelled; pause.skipped = skipped
            history.reflections.append(pause)
        }
        #expect(history.recentPauseAttempts(for: app, now: now) == 2)
        #expect(history.recentPauseAttempts(for: UUID(), now: now) == 0)
        #expect(history.recentPauseAttempts(for: app, now: now.addingTimeInterval(86401)) == 0)
    }

}
