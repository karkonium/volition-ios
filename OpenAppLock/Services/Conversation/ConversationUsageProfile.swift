import Foundation

/// Optional structured intentions live in the existing private JSON archive,
/// keyed by saved rule ID. Frozen V1–V4 schemas and legacy free text stay intact.
nonisolated struct ConversationUsageProfile: Codable, Equatable, Sendable {
    enum Purpose: String, Codable, CaseIterable, Sendable {
        case communication, productivity, learning, relaxation, other
        var copy: CopyKey {
            switch self {
            case .communication: .profileCommunication
            case .productivity: .profileProductivity
            case .learning: .profileLearning
            case .relaxation: .profileRelaxation
            case .other: .profileOther
            }
        }
    }
    enum Change: String, Codable, CaseIterable, Sendable {
        case habit, duration, frequency, distraction, timing, intention, unsure
        var copy: CopyKey {
            switch self {
            case .habit: .profileHabit
            case .duration: .profileDuration
            case .frequency: .profileFrequency
            case .distraction: .profileDistraction
            case .timing: .profileTiming
            case .intention: .profileIntentional
            case .unsure: .profileUnsure
            }
        }
    }
    enum SessionStyle: String, Codable, CaseIterable, Sendable {
        case shortVisits, longerSessions, both, unsure
        var copy: CopyKey {
            switch self {
            case .shortVisits: .profileShort
            case .longerSessions: .profileLong
            case .both: .profileBoth
            case .unsure: .profileUnsure
            }
        }
    }
    var purposes: Set<Purpose> = []
    var changes: Set<Change> = []
    var sessionStyle: SessionStyle = .unsure
}
