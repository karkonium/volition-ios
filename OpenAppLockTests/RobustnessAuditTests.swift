import FamilyControls
import Foundation
import ManagedSettings
import SwiftData
import Testing
@testable import OpenAppLock

@MainActor @Suite(.serialized)
struct RobustnessAuditTests {
    @Test func unchangedProfileStillCommitsRuleEdit() throws {
        let context = try makeInMemoryContext()
        context.autosaveEnabled = false
        let token = try JSONDecoder().decode(ApplicationToken.self,
            from: JSONSerialization.data(withJSONObject: ["data": Data([81]).base64EncodedString()]))
        var selection = FamilyActivitySelection(); selection.applicationTokens = [token]
        let profile = ConversationUsageProfile()
        let rule = try VolitionApps.save(name: "Original", intention: "Purpose", selection: selection, profile: profile, in: context)
        #expect(!context.hasChanges)
        _ = try VolitionApps.save(name: "Edited", intention: "Changed", selection: selection, editing: rule, profile: profile, in: context)
        #expect(!context.hasChanges, "Successful Save must commit the rule even when the usage profile is unchanged")
        context.rollback()
        #expect(rule.name == "Edited")
    }

    @Test func refreshPreservesUnreadableHistory() async throws {
        let context = try makeInMemoryContext()
        let archive = ConversationArchive()
        let original = Data("unreadable archive to preserve".utf8)
        archive.payload = original
        context.insert(archive); try context.save()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let coordinator = ConversationCoordinator(historyStore: ConversationHistoryStore(context: context),
            preferences: .testing(), client: MockConversationClient(), keys: MockConversationKeyStore(),
            access: .init(store: .init(fileURL: directory.appendingPathComponent("access.json")), shields: MockShieldController()),
            timer: MockConversationTimer())
        #expect(coordinator.errorMessage != nil)
        await coordinator.refresh(snapshots: [], consumeRequests: false)
        #expect(archive.payload == original, "Normal refresh must not replace data that failed to load")
    }
}

@MainActor @Suite(.serialized)
struct RobustnessValidationTests {
    @Test func trimmedBoundaries() {
        #expect(FormValidation.nameError("  " ) == .appNameRequired)
        #expect(FormValidation.nameError("  " + String(repeating: "a", count: 100) + "  ") == nil)
        #expect(FormValidation.nameError(String(repeating: "a", count: 101)) == .volitionNameError)
        #expect(FormValidation.notesError("") == nil)
        #expect(FormValidation.notesError(String(repeating: "x", count: 2001)) != nil)
        #expect(FormValidation.messageError(" " + String(repeating: "x", count: 4000) + " ") == nil)
        #expect(FormValidation.messageError(String(repeating: "x", count: 4001)) != nil)
        #expect(FormValidation.removalError("  ") != nil)
    }
    @Test func missingFocusAppsNeverBecomeAllApps() {
        let removed = UUID(), current = UUID()
        #expect(FormValidation.focusSelectionError(allApps: false, selected: [removed], available: [current]) != nil)
        #expect(FormValidation.focusSelectionError(allApps: false, selected: [removed, current], available: [current]) != nil)
        #expect(FormValidation.focusSelectionError(allApps: true, selected: [], available: [current]) == nil)
        #expect(FormValidation.focusSelectionError(allApps: true, selected: [], available: []) != nil)
    }
    @Test func unreadableDiagnosticsDoNotExportEmptySuccess() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data([0xff, 0xfe, 0xff]).write(to: directory.appendingPathComponent("app-2026-10-31.log"))
        let store = LogStore(directory: directory)
        #expect(throws: (any Error).self) { try store.exportFile(for: "2026-10-31") }
    }
}

@MainActor @Suite(.serialized)
struct RobustnessHistoryTests {
    private func coordinator(_ history: AuditHistoryStore) throws -> ConversationCoordinator {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return ConversationCoordinator(historyStore: history, preferences: .testing(), client: MockConversationClient(),
            keys: MockConversationKeyStore(), access: .init(store: .init(fileURL: directory.appendingPathComponent("access.json")), shields: MockShieldController()),
            timer: MockConversationTimer())
    }
    @Test func allOrdinaryWritesPreserveFailedLoadUntilRetry() async throws {
        let store = AuditHistoryStore()
        store.value.messages = [.init(role: .user, text: "Keep me")]
        store.failLoad = true
        let coach = try coordinator(store)
        await coach.refresh(snapshots: [], consumeRequests: false)
        coach.cancelRequest()
        coach.setAIConsent(false)
        #expect(!coach.clearHistory())
        #expect(!coach.eraseCoachingContent())
        #expect(store.writes == 0)
        #expect(store.value.messages.first?.text == "Keep me")
        store.failLoad = false
        coach.retryLoadingHistory()
        #expect(!coach.loadFailed)
        #expect(coach.history.messages.first?.text == "Keep me")
        #expect(store.writes == 1)
    }
    @Test func erasureRetainsSavedStructuredIntentions() throws {
        let store = AuditHistoryStore()
        let id = UUID()
        let profile = ConversationUsageProfile(purposes: [.learning], changes: [.duration], sessionStyle: .shortVisits)
        store.value.usageProfiles[id] = profile
        store.value.messages = [.init(role: .user, text: "Private conversation")]
        let coach = try coordinator(store)
        #expect(coach.eraseCoachingContent())
        #expect(store.value.messages.isEmpty)
        #expect(store.value.usageProfiles[id] == profile)
    }
    @Test func failedClearReportsFailureAndRetainsMessages() throws {
        let store = AuditHistoryStore()
        store.value.messages = [.init(role: .user, text: "Keep me")]
        let coach = try coordinator(store)
        store.failSave = true
        #expect(!coach.clearHistory())
        #expect(coach.errorMessage != nil)
        #expect(coach.history.messages.first?.text == "Keep me")
        #expect(store.value.messages.first?.text == "Keep me")
    }
}
@MainActor private final class AuditHistoryStore: ConversationHistoryStoring {
    var value = ConversationHistory()
    var failLoad = false
    var failSave = false
    var writes = 0
    func load() throws -> ConversationHistory {
        if failLoad { throw CocoaError(.fileReadCorruptFile) }
        return value
    }
    func save(_ history: ConversationHistory) throws {
        if failSave { throw CocoaError(.fileWriteUnknown) }
        value = history; writes += 1
    }
}
