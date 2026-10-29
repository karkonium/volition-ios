import ActivityKit
import Foundation

/// Date-based rendering keeps the countdown moving without background app ticks.
/// The window describes approved access, never proof of OS shield presentation.
nonisolated struct ConversationUnlockActivityAttributes: ActivityAttributes, Sendable {
    struct ContentState: Codable, Hashable, Sendable {
        let start: Date
        let expiresAt: Date
    }
    let grantID: UUID
    let appName: String
    let appID: UUID?
    var url: URL? { appID.flatMap { URL(string: "openapplock://conversation?app=\($0.uuidString)") } }
}
