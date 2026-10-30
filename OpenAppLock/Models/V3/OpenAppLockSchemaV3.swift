//
//  OpenAppLockSchemaV3.swift
//  OpenAppLock
//

import SwiftData

struct OpenAppLockSchemaV3: VersionedSchema {
    static let versionIdentifier = Schema.Version(3, 0, 0)
    static var models: [any PersistentModel.Type] {
        return [Self.BlockingRule.self, Self.AppList.self]
    }
}
