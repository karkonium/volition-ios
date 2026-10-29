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
    }
    let fileURL: URL?

    init(fileURL: URL? = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: AppGroup.identifier)?
        .appendingPathComponent("conversation-access.json")) {
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
                let value = try operation(&state)
                try JSONEncoder().encode(state).write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
                return value
            }
        }
        if let error { throw error }
        guard let result else { throw ConversationAccessError.storageUnavailable }
        return try result.get()
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
                        "domains": sortedTokens(selection.webDomainTokens)
                    ])
                    normalized.dayNumbers.sort()
                    return normalized
                }
            let data = try encoder.encode(rules)
            return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        } catch { return "invalid" }
    }

    static func applicable(to token: ApplicationToken, in snapshots: [RuleSnapshotDTO]) -> [RuleSnapshotDTO] {
        snapshots.filter { $0.kind == .conversation && $0.isEnabled &&
            AppSelectionCodec.decode($0.selectionData).applicationTokens.contains(token) }
    }

    func setPending(_ token: ApplicationToken, at now: Date = .now) throws {
        try transaction { state in state.pendingToken = token; state.pendingAt = now }
    }

    func consumePending(at now: Date = .now) throws -> ApplicationToken? {
        try transaction { state in
            defer { state.pendingToken = nil; state.pendingAt = nil }
            guard let date = state.pendingAt, now.timeIntervalSince(date) >= 0,
                  now.timeIntervalSince(date) < 300 else { return nil }
            return state.pendingToken
        }
    }
}

nonisolated enum ConversationAccessError: Error, Equatable {
    case storageUnavailable, alreadyUnlocked, staleRequest, noApplicableRule, monitoringUnavailable, shieldReleaseFailed, waiting
}
