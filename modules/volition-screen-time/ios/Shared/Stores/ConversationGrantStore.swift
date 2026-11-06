import CryptoKit
import FamilyControls
@preconcurrency import ManagedSettings
import Foundation

/// Minimal cross-process grant state. A coordinated file serializes snapshots,
/// grant changes and shield writes. Missing/corrupt state grants no exceptions.
/// Transcripts and API keys never enter this store.
nonisolated struct ConversationGrantStore: Sendable {
    struct Grant: Codable, Equatable, Sendable {
        let plan: ConversationUnlockPlan
        let token: ApplicationToken
        let fingerprint: String
        var configurationFingerprint: String? = nil
        var focusCutoff: Date? = nil
        var effectiveExpiry: Date { min(plan.expiresAt, focusCutoff ?? plan.expiresAt) }
        func hasExpired(at now: Date) -> Bool { effectiveExpiry <= now }
    }
    /// Accepted terms survive chat clearing, relaunch, early ending and expiry.
    struct DealCommitment: Codable, Equatable, Sendable {
        let grantID: UUID
        let token: ApplicationToken
        let blockedUntil: Date
        var overriddenAt: Date? = nil
        var overrideGrantID: UUID? = nil
        var pushbackCount: Int? = nil
        var resolutionDate: Date { overriddenAt ?? blockedUntil }
        func isBlocking(at now: Date) -> Bool { overriddenAt == nil && blockedUntil > now }
    }
    struct State: Codable {
        var snapshots: [RuleSnapshotDTO] = []
        // Keep the first grant in the legacy field so old archives still decode.
        var grant: Grant?
        private var additionalGrants: [Grant]?
        var activeGrants: [Grant] {
            get { (grant.map { [$0] } ?? []) + (additionalGrants ?? []) }
            set { grant = newValue.first; additionalGrants = Array(newValue.dropFirst()) }
        }
        private var acceptedDeals: [DealCommitment]?
        var dealCommitments: [DealCommitment] {
            get { acceptedDeals ?? [] }
            set { acceptedDeals = newValue }
        }
        var pendingToken: ApplicationToken?
        var pendingAt: Date?
        var syncedAt: Date?
        var recoveredAt: Date?
        var focus: FocusProtectionState?

        var focusAppIDs: Set<UUID> {
            Set(snapshots.filter { $0.kind == .conversation && $0.isEnabled }.map(\.id))
        }
    }
    let fileURL: URL?

    init(
        fileURL: URL? = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppGroup.identifier)?
            .appendingPathComponent("conversation-access.json")
    ) {
        self.fileURL = fileURL
    }

    func transaction<T>(_ operation: (inout State) throws -> T) throws -> T {
        guard let fileURL else { throw ConversationAccessError.storageUnavailable }
        var error: NSError?
        var result: Result<T, Error>?
        NSFileCoordinator().coordinate(writingItemAt: fileURL, options: .forMerging, error: &error) { url in
            result = Result {
                var state = State()
                if FileManager.default.fileExists(atPath: url.path) {
                    state = try JSONDecoder().decode(State.self, from: Data(contentsOf: url))
                }
                let migrated = state.focus == nil
                if migrated { state.focus = try legacyFocus() }
                let previous = state
                let value = try operation(&state)
                if migrated || previous.focus != state.focus || previous.snapshots != state.snapshots {
                    try saveMirror(state)
                } else if !FileManager.default.fileExists(atPath: mirrorURL?.path ?? "") {
                    try saveMirror(state)
                }
                do {
                    try JSONEncoder().encode(state).write(
                        to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
                } catch {
                    try? saveMirror(previous)
                    throw error
                }
                if let focus = state.focus { try? FocusDisplayStore(base: fileURL).publish(focus) }
                return value
            }
        }
        if let error { throw error }
        guard let result else { throw ConversationAccessError.storageUnavailable }
        return try result.get()
    }

    private struct ConfigurationMirror: Codable {
        let payload: Data
        let checksum: String
    }
    private var mirrorURL: URL? { fileURL?.appendingPathExtension("configuration") }

    private struct RecoveryConfiguration: Codable {
        let snapshots: [RuleSnapshotDTO]
        let focus: FocusProtectionState?
    }

    private func legacyFocus() throws -> FocusProtectionState {
        guard let url = fileURL?.deletingLastPathComponent().appendingPathComponent("focus.json") else {
            throw ConversationAccessError.storageUnavailable
        }
        guard FileManager.default.fileExists(atPath: url.path) else { return FocusProtectionState(revision: 0) }
        var focus = try JSONDecoder().decode(FocusProtectionState.self, from: Data(contentsOf: url))
        guard focus.isValid else { throw ConversationAccessError.storageUnavailable }
        for index in focus.periods.indices {
            focus.periods[index].allApps = focus.periods[index].appIDs.isEmpty
        }
        if let session = focus.session {
            focus.session?.allApps = session.appIDs.isEmpty
        }
        focus.revision = 0
        return focus
    }

    private func saveMirror(_ state: State) throws {
        guard let mirrorURL else { throw ConversationAccessError.storageUnavailable }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let payload = try encoder.encode(RecoveryConfiguration(snapshots: state.snapshots, focus: state.focus))
        let mirror = ConfigurationMirror(
            payload: payload,
            checksum: SHA256.hash(data: payload).map { String(format: "%02x", $0) }.joined())
        let data = try encoder.encode(mirror)
        if (try? Data(contentsOf: mirrorURL)) != data {
            try data.write(to: mirrorURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        }
    }

    /// Recovery never trusts a partially decoded grant. The independent mirror
    /// is validated before any shield is changed and evidence is retained.
    func recover(fallback: [RuleSnapshotDTO]? = nil, _ restore: ([RuleSnapshotDTO]) -> Void) throws {
        guard let fileURL, let mirrorURL else { throw ConversationAccessError.storageUnavailable }
        var coordinationError: NSError?
        var result: Result<Void, Error>?
        NSFileCoordinator().coordinate(writingItemAt: fileURL, options: .forMerging, error: &coordinationError) { url in
            result = Result {
                // A concurrent process may already have repaired the file.
                if let data = try? Data(contentsOf: url), let state = try? JSONDecoder().decode(State.self, from: data)
                {
                    _ = state
                    return
                }
                let recovery: RecoveryConfiguration?
                if FileManager.default.fileExists(atPath: mirrorURL.path) {
                    let mirror = try JSONDecoder().decode(ConfigurationMirror.self, from: Data(contentsOf: mirrorURL))
                    let checksum = SHA256.hash(data: mirror.payload).map { String(format: "%02x", $0) }.joined()
                    guard checksum == mirror.checksum else { throw ConversationAccessError.storageUnavailable }
                    if let configuration = try? JSONDecoder().decode(RecoveryConfiguration.self, from: mirror.payload) {
                        recovery = configuration
                    } else {
                        recovery = RecoveryConfiguration(
                            snapshots: try JSONDecoder().decode([RuleSnapshotDTO].self, from: mirror.payload),
                            focus: nil)
                    }
                } else {
                    recovery = nil
                }
                guard let snapshots = fallback ?? recovery?.snapshots else {
                    throw ConversationAccessError.storageUnavailable
                }
                for snapshot in snapshots where snapshot.isEnabled && snapshot.kind == .conversation {
                    guard let data = snapshot.selectionData,
                        let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data),
                        !selection.applicationTokens.isEmpty
                    else { throw ConversationAccessError.storageUnavailable }
                }
                if FileManager.default.fileExists(atPath: url.path) {
                    try FileManager.default.copyItem(
                        at: url, to: url.appendingPathExtension("corrupt-" + UUID().uuidString))
                }
                restore(snapshots)
                var state = State(); state.snapshots = snapshots; state.recoveredAt = .now
                state.focus = try recovery?.focus ?? legacyFocus()
                try saveMirror(state)
                try JSONEncoder().encode(state).write(
                    to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            }
        }
        if let coordinationError { throw coordinationError }
        guard let result else { throw ConversationAccessError.storageUnavailable }
        try result.get()
    }

    static func configurationFingerprint(for token: ApplicationToken, in snapshots: [RuleSnapshotDTO]) -> String {
        fingerprint(applicable(to: token, in: snapshots))
    }

    static func isValid(_ grant: Grant, in snapshots: [RuleSnapshotDTO]) -> Bool {
        if let scoped = grant.configurationFingerprint {
            return !applicable(to: grant.token, in: snapshots).isEmpty
                && scoped == configurationFingerprint(for: grant.token, in: snapshots)
        }
        return grant.fingerprint == fingerprint(snapshots)
    }

    static func fingerprint(_ snapshots: [RuleSnapshotDTO]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        func sortedTokens<T: Encodable & Hashable>(_ tokens: Set<T>) throws -> [String] {
            try tokens.map { try encoder.encode($0).base64EncodedString() }.sorted()
        }
        do {
            let rules = try snapshots.filter { $0.kind == .conversation }
                .sorted { $0.id.uuidString < $1.id.uuidString }.map { snapshot in
                    var normalized = snapshot
                    let selection = AppSelectionCodec.decode(snapshot.selectionData)
                    // FamilyActivitySelection encodes sets as arrays; their order
                    // can change even when the selected apps remain identical.
                    normalized.selectionData = try encoder.encode([
                        "apps": sortedTokens(selection.applicationTokens),
                        "categories": sortedTokens(selection.categoryTokens),
                        "domains": sortedTokens(selection.webDomainTokens),
                    ])
                    normalized.dayNumbers.sort()
                    return normalized
                }
            let data = try encoder.encode(rules)
            return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        } catch { return "invalid" }
    }

    static func applicable(to token: ApplicationToken, in snapshots: [RuleSnapshotDTO]) -> [RuleSnapshotDTO] {
        snapshots.filter {
            $0.kind == .conversation && $0.isEnabled
                && AppSelectionCodec.decode($0.selectionData).applicationTokens.contains(token)
        }
    }

    func setPending(_ token: ApplicationToken, at now: Date = .now) throws {
        try transaction { state in
            state.pendingToken = token; state.pendingAt = now
        }
    }

    func consumePending(at now: Date = .now) throws -> ApplicationToken? {
        try transaction { state in
            defer { state.pendingToken = nil; state.pendingAt = nil }
            guard let date = state.pendingAt, now.timeIntervalSince(date) >= 0,
                now.timeIntervalSince(date) < 300
            else { return nil }
            return state.pendingToken
        }
    }
}

nonisolated enum ConversationAccessError: Error, Equatable {
    case storageUnavailable, alreadyUnlocked, staleRequest, noApplicableRule, monitoringUnavailable,
        shieldReleaseFailed, waiting, focusProtected, focusBoundary, focusNeedsApps, focusInvalid
}
