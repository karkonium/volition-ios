import SwiftUI
import SwiftData
import FamilyControls
import ManagedSettings

/// Test host only. The shipped app starts at App.tsx. This host preserves the
/// original module identity for migration/enforcement regression tests without
/// retaining the replaced SwiftUI interface or starting real enforcement.
@main
struct OpenAppLockApp: App {
    init() {
        if ProcessInfo.processInfo.arguments.contains("-seed-expo-migration") {
            do { try Self.seedMigrationFixture() }
            catch { Diag.error(.migration, "synthetic migration fixture failed") }
        }
    }
    var body: some Scene {
        WindowGroup { Text("Volition native compatibility tests") }
    }
    private static func seedMigrationFixture() throws {
        let schema = Schema(versionedSchema: OpenAppLockSchemaV5.self)
        let container = try ModelContainer(for: schema, migrationPlan: OpenAppLockSchemaMigrationPlan.self,
            configurations: [ModelConfiguration(schema: schema)])
        let context = container.mainContext
        guard try context.fetchCount(FetchDescriptor<BlockingRule>()) == 0 else { return }
        let token = try JSONDecoder().decode(ApplicationToken.self,
            from: JSONSerialization.data(withJSONObject: ["data": Data([239]).base64EncodedString()]))
        var selection = FamilyActivitySelection(); selection.applicationTokens = [token]
        _ = try VolitionApps.save(name: "Expo migration fixture", intention: "Learn deliberately.", selection: selection, in: context)
        var history = ConversationHistory()
        history.messages = [.init(role: .user, text: "Synthetic migration history")]
        history.lastEmotionQuestionAt = Date()
        try ConversationHistoryStore(context: context).save(history)
        UserDefaults.standard.set(0, forKey: "aiConsentVersion")
    }
}
