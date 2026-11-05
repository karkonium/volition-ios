import Foundation
import SwiftData
import FamilyControls

/// Reads the original V1–V5 store without replacing it. Preparation disables
/// legacy rules and splits selections through the same migration used by SwiftUI.
@MainActor
final class LegacyImport {
    static let shared = LegacyImport()
    private var container: ModelContainer?
    func waitUntil(appIDs: Set<UUID>) throws -> Date? {
        guard let container else { return nil }
        let history = try ConversationHistoryStore(context: container.mainContext).load()
        let waits = history.accessEvents.filter { appIDs.contains($0.appID) }.compactMap(\.waitUntil)
        return (waits + [history.cooldownUntil].compactMap { $0 }).max()
    }
    func export() throws -> String {
        if container == nil {
            let schema = Schema(versionedSchema: OpenAppLockSchemaV5.self)
            container = try ModelContainer(
                for: schema, migrationPlan: OpenAppLockSchemaMigrationPlan.self,
                configurations: [ModelConfiguration(schema: schema)])
        }
        guard let container else { throw ConversationAccessError.storageUnavailable }
        let context = container.mainContext
        try VolitionApps.prepare(in: context)
        let history = try ConversationHistoryStore(context: context).load()
        let rules = try context.fetch(FetchDescriptor<BlockingRule>()).filter {
            $0.kind == .conversation && $0.isEnabled
        }
        let apps: [[String: Any]] = try rules.compactMap { rule in
            let selection = AppSelectionCodec.decode(rule.combinedSelectionData)
            guard selection.applicationTokens.count == 1, let token = selection.applicationTokens.first else {
                return nil
            }
            let profile = history.usageProfiles[rule.id] ?? ConversationUsageProfile()
            return [
                "id": rule.id.uuidString.lowercased(), "name": rule.name, "goal": rule.conversationGoal,
                "notes": rule.conversationGoal, "tokenBase64": try JSONEncoder().encode(token).base64EncodedString(),
                "isEnabled": rule.isEnabled, "createdAt": ISO8601DateFormatter().string(from: rule.createdAt),
                "purposes": profile.purposes.map(\.rawValue), "changes": profile.changes.map(\.rawValue),
                "sessionStyle": profile.sessionStyle.rawValue,
            ]
        }
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        let encodedHistory = try JSONSerialization.jsonObject(with: encoder.encode(history))
        let preferences = UserDefaults.standard
        let consent =
            preferences.object(forKey: "aiConsentVersion") == nil
            || preferences.integer(forKey: "aiConsentVersion") == 1
        let data = try JSONSerialization.data(withJSONObject: [
            "apps": apps, "history": encodedHistory,
            "aiConsent": consent, "tone": preferences.string(forKey: "coachTone") ?? "balanced",
        ])
        return String(decoding: data, as: UTF8.self)
    }
}
