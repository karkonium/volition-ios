import Foundation

/// Grants and focus share a finite monitor budget. Registration remains
/// authoritative; no caller may evict another monitor to make room.
nonisolated enum MonitoringCapacity {
    static let maximum = 20
    static func validate(existing: [String], adding: [String]) throws {
        guard Set(existing).union(adding).count <= maximum else {
            throw ConversationAccessError.monitoringUnavailable
        }
    }
}
