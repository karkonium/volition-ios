import Foundation
import FamilyControls
@preconcurrency import ManagedSettings

/// Routing metadata only: never authorizes access. Tokens stay in the App Group;
/// notification links contain a saved profile ID, not the opaque Apple token.
nonisolated struct ConversationShieldRequest: Codable, Equatable, Sendable {
    let id: UUID
    let token: ApplicationToken
    let appID: UUID
    let date: Date
    var notificationIdentifier: String { "conversation-request-\(id.uuidString)" }
    var url: URL? {
        var parts = URLComponents()
        parts.scheme = "openapplock"; parts.host = "conversation"
        parts.queryItems = [.init(name: "app", value: appID.uuidString), .init(name: "request", value: id.uuidString)]
        return parts.url
    }
    static func appID(from url: URL) -> UUID? {
        guard url.scheme == "openapplock", url.host == "conversation", url.path.isEmpty,
              let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let value = parts.queryItems?.first(where: { $0.name == "app" })?.value else { return nil }
        return UUID(uuidString: value)
    }
}

/// Lightweight preferences keep shield callbacks/rendering out of the grant-file
/// coordinator, whose transactions can include system shield writes. Each request
/// is one atomic Data value. Acknowledging an ID never deletes a newer request.
/// UserDefaults is thread-safe; this state is advisory and cannot lift a shield.
nonisolated struct ConversationRequestStore: @unchecked Sendable {
    let defaults: UserDefaults
    private let requestKey = "conversationShieldRequest"
    private let acknowledgementPrefix = "conversationShieldAcknowledged."
    init(defaults: UserDefaults = AppGroup.defaults) { self.defaults = defaults }
    @discardableResult
    func begin(token: ApplicationToken, appID: UUID, at date: Date = .now) -> ConversationShieldRequest {
        let request = ConversationShieldRequest(id: UUID(), token: token, appID: appID, date: date)
        if let data = try? JSONEncoder().encode(request) {
            let staleAcknowledgements = defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix(acknowledgementPrefix) }
            defaults.set(data, forKey: requestKey)
            // Never sweep an acknowledgement created after this publication.
            for key in staleAcknowledgements { defaults.removeObject(forKey: key) }
        }
        return request
    }
    func pending(at now: Date = .now) -> ConversationShieldRequest? {
        guard let data = defaults.data(forKey: requestKey),
              let request = try? JSONDecoder().decode(ConversationShieldRequest.self, from: data),
              !defaults.bool(forKey: acknowledgementPrefix + request.id.uuidString),
              (0..<300).contains(now.timeIntervalSince(request.date)) else { return nil }
        return request
    }
    func acknowledge(_ request: ConversationShieldRequest) {
        defaults.set(true, forKey: acknowledgementPrefix + request.id.uuidString)
    }
}
