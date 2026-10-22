import Foundation

/// Temporary conversation tracing. Disable with CONVO_LOG_ENABLED=0 in the local
/// env file and rebuild. Only pass controlled metadata, never chat or credentials.
nonisolated struct ConversationDiagnostics: Sendable {
    let enabled: Bool
    let sink: @Sendable (String) -> Void
    static let live = ConversationDiagnostics(enabled: ConversationEnvironment.bundled.logsEnabled) {
        Diag.log(.conversation, .event, $0)
    }
    init(enabled: Bool, sink: @escaping @Sendable (String) -> Void) {
        self.enabled = enabled
        self.sink = sink
    }
    func log(_ metadata: String) {
        if enabled { sink("///CONVO-LOG " + metadata) }
    }
}

/// Safe error categories retain debugging information without retaining the
/// server's free-form message (401 messages may contain part of the API key).
nonisolated enum ConversationClientError: Error, Equatable {
    case http(status: Int, code: String)
    case transport(code: Int)
    case response(reason: String)

    var diagnosticSummary: String {
        switch self {
        case let .http(status, code): return "http status=\(status) code=\(code)"
        case let .transport(code): return "transport code=\(code)"
        case let .response(reason): return "response reason=\(reason)"
        }
    }

    var copyKey: CopyKey {
        switch self {
        case .http(status: 401, code: _): return .conversationAuthenticationError
        case .http(status: 403, code: _): return .conversationPermissionError
        case .http(status: 429, code: "insufficient_quota"), .http(status: 429, code: "billing_hard_limit_reached"):
            return .conversationQuotaError
        case .http(status: 429, code: _): return .conversationRateLimitError
        case .http(status: 400, code: _), .http(status: 404, code: _): return .conversationRequestError
        case .http: return .conversationServiceError
        case .transport: return .conversationNetworkError
        case .response: return .conversationResponseError
        }
    }
}
