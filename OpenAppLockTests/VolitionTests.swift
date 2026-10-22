import FamilyControls
import ManagedSettings
import SwiftData
import Testing
import Foundation
@testable import OpenAppLock

@MainActor @Suite(.serialized)
struct VolitionTests {
    private func selection(_ bytes: [UInt8]) throws -> FamilyActivitySelection {
        var result = FamilyActivitySelection()
        result.applicationTokens = try Set(bytes.map {
            try JSONDecoder().decode(ApplicationToken.self, from: JSONSerialization.data(withJSONObject: ["data": Data([$0]).base64EncodedString()]))
        })
        return result
    }

    @Test func pickerAcceptsOnlyOneIndividualApp() throws {
        let selected = try selection([20])
        #expect(try VolitionApps.selectedApp(in: selected) == selected.applicationTokens.first)
        #expect(throws: VolitionApps.ValidationError.self) { try VolitionApps.selectedApp(in: self.selection([])) }
        #expect(throws: VolitionApps.ValidationError.self) { try VolitionApps.selectedApp(in: self.selection([20,21])) }
        var category = selected
        category.categoryTokens = [try JSONDecoder().decode(ActivityCategoryToken.self,
            from: JSONSerialization.data(withJSONObject: ["data": Data([1]).base64EncodedString()]))]
        #expect(throws: VolitionApps.ValidationError.self) { try VolitionApps.selectedApp(in: category) }
        var website = selected
        website.webDomainTokens = [try JSONDecoder().decode(WebDomainToken.self,
            from: JSONSerialization.data(withJSONObject: ["data": Data([2]).base64EncodedString()]))]
        #expect(throws: VolitionApps.ValidationError.self) { try VolitionApps.selectedApp(in: website) }
    }

    @Test func profilesValidateAndPersist() throws {
        let context = try makeInMemoryContext()
        let selected = try selection([20])
        let rule = try VolitionApps.save(name: "  Instagram  ", intention: "  Message friends  ", selection: selected, in: context)
        #expect(rule.name == "Instagram")
        #expect(rule.conversationGoal == "Message friends")
        #expect(rule.kind == .conversation)
        #expect(AppSelectionCodec.decode(rule.combinedSelectionData).applicationTokens == selected.applicationTokens)
        #expect(throws: (any Error).self) { try VolitionApps.save(name: "Again", intention: "Purpose", selection: selected, in: context) }
        #expect(throws: (any Error).self) { try VolitionApps.save(name: "", intention: "Purpose", selection: self.selection([21]), in: context) }
        #expect(throws: (any Error).self) { try VolitionApps.save(name: "Apps", intention: "Purpose", selection: self.selection([22,23]), in: context) }
    }

    @Test func migrationRetiresLegacyAndSplitsAppsIdempotently() throws {
        let context = try makeInMemoryContext()
        let old = BlockingRule(name: "Old schedule", hardMode: true)
        context.insert(old)
        let list = AppList(name: "Old apps", selectionData: AppSelectionCodec.encode(try selection([30,31])), selectionCount: 2)
        let chat = BlockingRule(name: "Social", configuration: .conversation(.init(goal: "Connect")))
        context.insert(list); context.insert(chat); chat.appLists = [list]
        try context.save()
        try VolitionApps.prepare(in: context)
        try VolitionApps.prepare(in: context)
        let rules = try context.fetch(FetchDescriptor<BlockingRule>())
        #expect(!old.isEnabled)
        let active = rules.filter { $0.isEnabled }
        #expect(active.count == 2)
        #expect(active.allSatisfy { $0.kind == .conversation && AppSelectionCodec.decode($0.combinedSelectionData).applicationTokens.count == 1 })
        #expect(active.allSatisfy { $0.conversationGoal == "Connect" })
    }

    @Test func waitDecisionRequiresExclusiveBoundedDuration() throws {
        let valid = Data(#"{"reply":"Let's take a breath.","decision":"wait","unlock_minutes":null,"wait_minutes":3}"#.utf8)
        #expect(try ConversationDecision.parse(valid).waitMinutes == 3)
        for json in [
            #"{"reply":"Wait","decision":"wait","unlock_minutes":null,"wait_minutes":0}"#,
            #"{"reply":"Wait","decision":"wait","unlock_minutes":null,"wait_minutes":6}"#,
            #"{"reply":"Wait","decision":"wait","unlock_minutes":2,"wait_minutes":1}"#,
            #"{"reply":"Yes","decision":"approve","unlock_minutes":2,"wait_minutes":1}"#
        ] { #expect(throws: (any Error).self) { try ConversationDecision.parse(Data(json.utf8)) } }
    }

    @Test func oldHistoryDecodesWithoutNewFields() throws {
        let data = Data(#"{"messages":[],"memory":"old","summarizedCount":0}"#.utf8)
        let history = try JSONDecoder().decode(ConversationHistory.self, from: data)
        #expect(history.cooldownUntil == nil)
        #expect(history.accessEvents.isEmpty)
    }
}
