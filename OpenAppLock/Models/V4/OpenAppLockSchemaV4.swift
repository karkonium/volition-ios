import Foundation
import SwiftData

struct OpenAppLockSchemaV4: VersionedSchema {
    static var versionIdentifier = Schema.Version(4, 0, 0)
    static var models: [any PersistentModel.Type] {
        [Self.BlockingRule.self, Self.AppList.self, ConversationArchive.self]
    }
}

/// One local archive stores the full transcript and its compacted model memory.
/// Credentials and Screen Time grants are stored separately.
@Model
final class ConversationArchive {
    @Attribute(.unique) var id: String = "shared"
    var payload: Data = Data()
    init() {}
}
