import Foundation
import FamilyControls
import ManagedSettings

/// Routes only unambiguous saved names to locally held tokens. Longer exact names
/// win over contained names; unrelated or duplicate matches require user selection.
nonisolated enum ConversationAppResolver {
    enum Resolution: Equatable { case selected(ApplicationToken), ambiguous, none }

    static func resolve(_ text: String, in snapshots: [RuleSnapshotDTO]) -> Resolution {
        let words = tokens(text)
        let candidates = snapshots.flatMap { snapshot -> [(ApplicationToken, Range<Int>)] in
            guard snapshot.isEnabled, snapshot.kind == .conversation else { return [] }
            let selection = AppSelectionCodec.decode(snapshot.selectionData)
            guard selection.applicationTokens.count == 1, selection.categoryTokens.isEmpty,
                  selection.webDomainTokens.isEmpty, let app = selection.applicationTokens.first else { return [] }
            let name = tokens(snapshot.name).joined()
            guard !name.isEmpty else { return [] }
            var found: [(ApplicationToken, Range<Int>)] = []
            for start in words.indices {
                var phrase = ""
                for end in start..<words.count {
                    phrase += words[end]
                    if phrase == name { found.append((app, start..<(end + 1))); break }
                    if phrase.count >= name.count { break }
                }
            }
            return found
        }
        let specific = candidates.filter { item in
            !candidates.contains { other in
                other.1 != item.1 && other.1.lowerBound <= item.1.lowerBound && other.1.upperBound >= item.1.upperBound
            }
        }
        let matches = Set(specific.map(\.0))
        if matches.count > 1 { return .ambiguous }
        return matches.first.map(Resolution.selected) ?? .none
    }
    private static func tokens(_ value: String) -> [String] {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: Locale(identifier: "en_US_POSIX"))
            .components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
    }
}
