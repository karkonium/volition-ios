import Foundation

/// Persisted offers are not unlocks. Soft pauses are skippable; deals require
/// explicit acceptance and enforce their agreed break in the shared grant store. Only a
/// foreground activation through ConversationEnforcement can create a grant.
/// Elapsing or ending a delay reveals explicit Unlock/Keep locked actions.
/// Sampled check-ins appear alone first; answer/Skip reveals the separate offer.
/// This step never accepts terms or opens an app. Ten seconds starts after reveal.
/// Claiming activation is persisted before I/O; relaunch never replays a claim.
nonisolated struct ConversationReflection: Codable, Equatable, Identifiable, Sendable {
    enum State: String, Codable, Sendable { case offered, counting, activating, completed, cancelled, declined, failed, interrupted }
    enum Emotion: String, Codable, CaseIterable, Sendable {
        case boredom, stress, anxiety, loneliness, avoidance, relaxation, other, skip
        var copy: CopyKey {
            switch self {
            case .boredom: .reflectionBoredom
            case .stress: .reflectionStress
            case .anxiety: .reflectionAnxiety
            case .loneliness: .reflectionLoneliness
            case .avoidance: .reflectionAvoidance
            case .relaxation: .reflectionRelaxation
            case .other: .reflectionOther
            case .skip: .reflectionNotSure
            }
        }
    }
    var id = UUID()
    var appID: UUID
    var appName: String
    var reason: String
    var reply: String
    var unlockMinutes: Int
    var seconds: Int
    var fingerprint: String
    var activityID: UUID
    var createdAt: Date
    var deadline: Date?
    var state: State
    var emotion: Emotion?
    var customEmotion: String? = nil
    var skipped: Bool = false
    var finishedAt: Date?
    var blockMinutes: Int?
    var offersChoice: Bool? = nil
    var checkInRequested: Bool? = nil
    var overridingDealID: UUID? = nil
    var openedWithoutIntervention: Bool? = nil
    enum InterventionOption { case delay, deal, open }
    /// A skipped check-in is an answer too; this presentation step never accepts terms.
    var awaitingCheckIn: Bool { checkInRequested == true && emotion == nil }
    var isChoice: Bool { offersChoice == true }
    var isDeal: Bool { blockMinutes != nil && !isChoice }
    var usageProfile: ConversationUsageProfile?
    var isPending: Bool { state == .offered || state == .counting }
    var validUntil: Date { (deadline ?? createdAt).addingTimeInterval(30 * 60) }
    func isReady(at now: Date) -> Bool { !isDeal && !isChoice && state == .counting && deadline.map { $0 <= now } == true && now < validUntil }

    init(appID: UUID, appName: String, reason: String, reply: String, unlockMinutes: Int,
         seconds: Int, fingerprint: String, activityID: UUID, now: Date = .now) {
        self.appID = appID; self.appName = appName; self.reason = reason; self.reply = reply
        self.unlockMinutes = unlockMinutes; self.seconds = seconds; self.fingerprint = fingerprint
        self.activityID = activityID; self.createdAt = now
        state = seconds == 10 ? .counting : .offered
        deadline = seconds == 10 ? now.addingTimeInterval(10) : nil
    }

    /// Bounded, recent awareness context: custom emotion is limited to 160 characters; no token,
    /// request text, or configuration fingerprints are transmitted here.
    struct Context: Codable, Sendable {
        let appID: UUID
        let date: Date
        let state: State
        let emotion: Emotion?
        var customEmotion: String? = nil
        let seconds: Int
        let skipped: Bool
        var blockMinutes: Int? = nil
        var unlockMinutes: Int? = nil
        var offersChoice: Bool? = nil
        var checkInRequested: Bool? = nil
        var openedWithoutIntervention: Bool? = nil
    }
    var context: Context { .init(appID: appID, date: createdAt, state: state, emotion: emotion, customEmotion: customEmotion, seconds: seconds, skipped: skipped, blockMinutes: blockMinutes, unlockMinutes: unlockMinutes, offersChoice: offersChoice, checkInRequested: checkInRequested, openedWithoutIntervention: openedWithoutIntervention) }
}
