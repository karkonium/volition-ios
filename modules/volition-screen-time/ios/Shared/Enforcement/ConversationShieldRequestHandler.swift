import Foundation
import ManagedSettings

/// One build selects the supported route at runtime. Presentation and the action
/// handler share this decision; older systems never execute the direct-open API.
nonisolated enum ConversationShieldRoute: Sendable {
    case direct, notification

    static var current: Self {
        if #available(iOS 26.5, *) { return .direct }
        return .notification
    }

    var response: ShieldActionResponse {
        if #available(iOS 26.5, *), self == .direct { return .openParentalControlsApp }
        return .defer
    }
}

/// Publish a fresh target without the grant file coordinator before opening
/// Volition. Direct routing never schedules a notification or waits for its APIs.
/// Older systems defer/redraw after scheduling, with a once-only timeout fallback.
nonisolated struct ConversationShieldRequestHandler: Sendable {
    let store: ConversationRequestStore
    let route: ConversationShieldRoute
    let notify: @Sendable (ConversationShieldRequest) async -> Void

    init(store: ConversationRequestStore = .init(), route: ConversationShieldRoute = .current,
         notify: @escaping @Sendable (ConversationShieldRequest) async -> Void = { await ConversationRequestNotification.send($0) }) {
        self.store = store
        self.route = route
        self.notify = notify
    }

    func request(token: ApplicationToken, appID: UUID, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        let started = Date()
        let completion = ConversationShieldCompletion {
            Diag.log(.session, "conversation shield route=\(route == .direct ? "direct" : "notification") elapsed_ms=\(Int(Date().timeIntervalSince(started) * 1000))")
            completionHandler(route.response)
        }
        completion.armTimeout()
        let request = store.begin(token: token, appID: appID)
        Diag.log(.session, "conversation request published id=\(request.id.logTag)")
        switch route {
        case .direct:
            completion.finish()
        case .notification:
            Task {
                await notify(request)
                completion.finish()
            }
        }
    }
}
