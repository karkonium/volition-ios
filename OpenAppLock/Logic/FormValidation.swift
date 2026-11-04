import Foundation

/// UI and persistence share normalized limits. Invalid submissions retain their draft.
nonisolated enum FormValidation {
    static func trim(_ text: String) -> String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    static func nameError(_ text: String) -> CopyKey? {
        if trim(text).isEmpty { return .appNameRequired }
        return trim(text).count > 100 ? .volitionNameError : nil
    }
    static func notesError(_ text: String) -> CopyKey? { trim(text).count > 2000 ? .validationNotesLimit : nil }
    static func messageError(_ text: String) -> CopyKey? { trim(text).count > 4000 ? .validationMessageLimit : nil }
    static func removalError(_ text: String) -> CopyKey? {
        let count = trim(text).count
        return count == 0 || count > 2000 ? .validationRemovalReason : nil
    }
    static func focusSelectionError(allApps: Bool, selected: Set<UUID>, available: Set<UUID>) -> CopyKey? {
        guard !available.isEmpty else { return .validationNoApps }
        guard !allApps else { return nil }
        guard !selected.isEmpty else { return .validationFocusApps }
        return selected.isSubset(of: available) ? nil : .validationFocusMissingApps
    }
}
