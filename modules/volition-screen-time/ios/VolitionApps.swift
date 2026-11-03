import FamilyControls
import ManagedSettings
import Foundation
import SwiftData

/// Volition stores one named application and intention per conversation rule.
/// Saves reject categories, domains, duplicate apps and blank/oversized names.
/// Structured setup may omit free text; a neutral intention keeps legacy rules valid.
/// Legacy rules are disabled, never silently left enforcing behind the new UI.
/// Multi-app conversation rules are split once; legacy data remains recoverable.
enum VolitionApps {
    enum ValidationError: LocalizedError {
        case singleApp, name, intention, duplicate
        var errorDescription: String? {
            switch self {
            case .singleApp: CopyKey.volitionSingleAppError.string
            case .name: CopyKey.volitionNameError.string
            case .intention: CopyKey.volitionIntentionError.string
            case .duplicate: CopyKey.volitionDuplicateError.string
            }
        }
    }

    static func selectedApp(in selection: FamilyActivitySelection) throws -> ApplicationToken {
        guard selection.applicationTokens.count == 1, selection.categoryTokens.isEmpty,
              selection.webDomainTokens.isEmpty, let token = selection.applicationTokens.first
        else { throw ValidationError.singleApp }
        return token
    }

    static func save(name: String, intention: String, selection: FamilyActivitySelection,
                     editing: BlockingRule? = nil, profile: ConversationUsageProfile? = nil, in context: ModelContext) throws -> BlockingRule {
        _ = try selectedApp(in: selection)
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        var intention = intention.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 100 else { throw ValidationError.name }
        if intention.isEmpty, profile != nil { intention = CopyKey.profileDefaultGoal.string }
        guard !intention.isEmpty, intention.count <= 2000 else { throw ValidationError.intention }
        let rules = try context.fetch(FetchDescriptor<BlockingRule>())
        guard !rules.contains(where: {
            $0.id != editing?.id && $0.kind == .conversation && $0.isEnabled &&
            !AppSelectionCodec.decode($0.combinedSelectionData).applicationTokens.isDisjoint(with: selection.applicationTokens)
        }) else { throw ValidationError.duplicate }
        let rule = editing ?? BlockingRule(name: name, configuration: .conversation(.init(goal: intention)))
        if editing == nil { context.insert(rule) }
        let list = AppList(name: name, selectionData: AppSelectionCodec.encode(selection), selectionCount: 1)
        context.insert(list)
        let previousLists = rule.appLists
        rule.name = name
        rule.configuration = .conversation(.init(goal: intention))
        rule.isEnabled = true
        rule.appLists = [list]
        for previous in previousLists where previous.rules.allSatisfy({ $0.id == rule.id }) { context.delete(previous) }
        do {
            if let profile {
                let store = ConversationHistoryStore(context: context)
                var history = try store.load()
                history.usageProfiles[rule.id] = profile
                try store.save(history)
            } else { try context.save() }
        }
        catch { context.rollback(); throw error }
        return rule
    }

    static func prepare(in context: ModelContext) throws {
        let rules = try context.fetch(FetchDescriptor<BlockingRule>(sortBy: [SortDescriptor(\.createdAt)]))
        var seen = Set<ApplicationToken>()
        for rule in rules {
            guard rule.kind == .conversation else {
                rule.isEnabled = false; rule.pausedUntil = nil
                continue
            }
            guard rule.isEnabled else { continue }
            let selection = AppSelectionCodec.decode(rule.combinedSelectionData)
            let tokens = selection.applicationTokens.subtracting(seen)
            seen.formUnion(tokens)
            if tokens.count == 1 && tokens == selection.applicationTokens && selection.categoryTokens.isEmpty && selection.webDomainTokens.isEmpty { continue }
            rule.isEnabled = false
            for (index, token) in tokens.enumerated() {
                var individual = FamilyActivitySelection(); individual.applicationTokens = [token]
                let replacement = BlockingRule(name: "\(rule.name) \(index + 1)", configuration: .conversation(.init(goal: rule.conversationGoal)))
                let list = AppList(name: replacement.name, selectionData: AppSelectionCodec.encode(individual), selectionCount: 1)
                context.insert(replacement); context.insert(list); replacement.appLists = [list]
            }
        }
        do { if context.hasChanges { try context.save() } }
        catch { context.rollback(); throw error }
    }
}
