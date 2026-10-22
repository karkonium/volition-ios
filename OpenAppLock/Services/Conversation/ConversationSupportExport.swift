#if DEBUG
import Foundation
import FamilyControls
import ManagedSettings

/// Development-only approval snapshots and an explicit launch export. Copies diagnostic logs and enforcement
/// state into Documents, where Apple's device transfer tool allows access. Never
/// exports the app bundle, API key, SwiftData archive or conversation transcript.
nonisolated enum ConversationSupportExport {
    static func recordApproval(requestID: UUID) {
        guard let group = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier),
              let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        do {
            let destination = documents.appendingPathComponent("VolitionSupport/LatestApproval", isDirectory: true)
            try export(group: group, destination: destination)
            ConversationDiagnostics.live.log("approval.snapshot_saved request=\(requestID.logTag)")
        } catch {
            ConversationDiagnostics.live.log("approval.snapshot_failed request=\(requestID.logTag)")
        }
    }

    static func export(group: URL, destination: URL) throws {
        let manager = FileManager.default
        try manager.createDirectory(at: destination, withIntermediateDirectories: true)
        let names = ["conversation-access.json", "conversation-timer-probe.json"]
        for name in names {
            let source = group.appendingPathComponent(name)
            guard manager.fileExists(atPath: source.path) else {
                let stale = destination.appendingPathComponent(name)
                if manager.fileExists(atPath: stale.path) { try manager.removeItem(at: stale) }
                continue
            }
            try Data(contentsOf: source).write(to: destination.appendingPathComponent(name),
                options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        }
        let logs = group.appendingPathComponent("Logs", isDirectory: true)
        let exportedLogs = destination.appendingPathComponent("Logs", isDirectory: true)
        try manager.createDirectory(at: exportedLogs, withIntermediateDirectories: true)
        if manager.fileExists(atPath: logs.path) {
            for source in try manager.contentsOfDirectory(at: logs, includingPropertiesForKeys: nil)
                where LogFilename.parse(source.lastPathComponent) != nil {
                try Data(contentsOf: source).write(to: exportedLogs.appendingPathComponent(source.lastPathComponent),
                    options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            }
        }
        if #available(iOS 26.5, *) {
            let accessURL = group.appendingPathComponent("conversation-access.json")
            let access = (try? Data(contentsOf: accessURL)).flatMap { try? JSONDecoder().decode(ConversationGrantStore.State.self, from: $0) }
            let stores = ManagedSettingsStore.stores.union([.default]).sorted { $0.rawValue < $1.rawValue }
            let records: [[String: Any]] = stores.map { name in
                let store = ManagedSettingsStore(named: name)
                let applications = store.shield.applications ?? []
                let matched = (access?.snapshots ?? []).filter {
                    !applications.isDisjoint(with: AppSelectionCodec.decode($0.selectionData).applicationTokens)
                }.map { $0.id.uuidString }
                return ["name": name.rawValue, "active": store.isActive,
                    "applicationsCount": applications.count, "matchedRuleIDs": matched,
                    "containsGrantToken": access?.activeGrants.contains { applications.contains($0.token) } ?? false,
                    "hasCategoryPolicy": store.shield.applicationCategories != nil,
                    "hasWebCategoryPolicy": store.shield.webDomainCategories != nil]
            }
            try JSONSerialization.data(withJSONObject: records, options: [.prettyPrinted, .sortedKeys])
                .write(to: destination.appendingPathComponent("shield-configuration.json"),
                    options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        }
        try JSONEncoder().encode(["capturedAt": ISO8601DateFormatter().string(from: Date())])
            .write(to: destination.appendingPathComponent("capture.json"),
                options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}
#endif
