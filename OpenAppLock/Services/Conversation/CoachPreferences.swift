import Foundation
import Observation

nonisolated enum CoachTone: String, Codable, CaseIterable, Sendable {
    case warm, balanced, direct
    var title: String {
        switch self {
        case .warm: CopyKey.toneWarm.string
        case .balanced: CopyKey.toneBalanced.string
        case .direct: CopyKey.toneDirect.string
        }
    }
}

/// Versioned explicit consent is independent of Screen Time permission.
@Observable
final class CoachPreferences {
    private let defaults: UserDefaults
    private(set) var hasConsent: Bool
    var tone: CoachTone { didSet { defaults.set(tone.rawValue, forKey: "coachTone") } }
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        hasConsent = defaults.integer(forKey: "aiConsentVersion") == 1
        tone = CoachTone(rawValue: defaults.string(forKey: "coachTone") ?? "") ?? .balanced
    }
    func setConsent(_ granted: Bool) {
        defaults.set(granted ? 1 : 0, forKey: "aiConsentVersion")
        hasConsent = granted
    }
    static func testing() -> CoachPreferences {
        let preferences = CoachPreferences(defaults: UserDefaults(suiteName: "CoachTests-" + UUID().uuidString)!)
        preferences.setConsent(true)
        return preferences
    }
}
