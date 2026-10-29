import Foundation
import SwiftData

/// V5 adds independent records while retaining the V4 model identities. Legacy
/// archive conversion is atomic and restartable in ConversationHistoryStore.
struct OpenAppLockSchemaV5: VersionedSchema {
    static var versionIdentifier = Schema.Version(5, 0, 0)
    static var models: [any PersistentModel.Type] {
        OpenAppLockSchemaV4.models + [ConversationRecord.self]
    }
}

@Model
final class ConversationRecord {
    @Attribute(.unique) var id: String
    var category: String
    var position: Int
    var payload: Data
    init(id: String, category: String, position: Int, payload: Data) {
        self.id = id; self.category = category; self.position = position; self.payload = payload
    }
}
