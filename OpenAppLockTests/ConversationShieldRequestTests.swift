import FamilyControls
import Foundation
import ManagedSettings
import Synchronization
import Testing
@testable import OpenAppLock

@MainActor struct ConversationShieldRequestTests {
    private func token(_ byte: UInt8 = 1) throws -> ApplicationToken {
        try JSONDecoder().decode(ApplicationToken.self, from: JSONSerialization.data(withJSONObject: ["data": Data([byte]).base64EncodedString()]))
    }
    private func defaults() -> UserDefaults {
        UserDefaults(suiteName: "ConversationRequestTests-\(UUID().uuidString)")!
    }
    @Test func repeatsHaveFreshIdentityAndConsumptionDoesNotEraseNewerRequest() throws {
        let store = ConversationRequestStore(defaults: defaults())
        let app = try token(), id = UUID(), now = Date()
        let first = store.begin(token: app, appID: id, at: now)
        #expect(store.pending(at: now)?.id == first.id)
        let second = store.begin(token: app, appID: id, at: now)
        store.acknowledge(first)
        #expect(store.pending(at: now)?.id == second.id)
        #expect(first.notificationIdentifier != second.notificationIdentifier)
        store.acknowledge(second)
        #expect(store.pending(at: now) == nil)
        store.acknowledge(first)
        #expect(store.pending(at: now) == nil)
        _ = store.begin(token: app, appID: id, at: now)
        #expect(store.pending(at: now.addingTimeInterval(301)) == nil)
        #expect(store.pending(at: now.addingTimeInterval(-1)) == nil)
    }
    @Test func notificationLinksRemainBoundToTheirAppWithoutExposingToken() throws {
        let store = ConversationRequestStore(defaults: defaults())
        let first = store.begin(token: try token(), appID: UUID())
        _ = store.begin(token: try token(2), appID: UUID())
        let url = try #require(first.url)
        #expect(ConversationShieldRequest.appID(from: url) == first.appID)
        #expect(!url.absoluteString.contains("token"))
        #expect(ConversationShieldRequest.appID(from: URL(string: "https://conversation?app=\(first.appID)")!) == nil)
        #expect(ConversationShieldRequest.appID(from: URL(string: "openapplock://conversation?app=bad")!) == nil)
    }
    @Test func shieldShowsFallbackAndAllowsRetryWithoutClaimingDelivery() {
        let presentation = ShieldPresentation.conversation(route: .notification, requestPending: true)
        #expect(presentation.subtitle.contains("notification"))
        #expect(presentation.subtitle.contains("enable"))
        #expect(presentation.subtitle.contains("Volition directly"))
        #expect(presentation.secondaryButton != nil)
        #expect(!presentation.title.contains("sent"))
    }
    @Test func directRoutePublishesTargetImmediatelyWithoutSchedulingNotifications() throws {
        guard #available(iOS 26.5, *) else { return }
        let store = ConversationRequestStore(defaults: defaults())
        let notifications = Mutex(0)
        let responses = Mutex<[ShieldActionResponse]>([])
        let handler = ConversationShieldRequestHandler(store: store, route: .direct) { _ in
            notifications.withLock { $0 += 1 }
        }
        let app = try token(), id = UUID()
        handler.request(token: app, appID: id) { response in
            #expect(store.pending()?.appID == id)
            #expect(store.pending()?.token == app)
            responses.withLock { $0.append(response) }
        }
        #expect(responses.withLock { $0 } == [.openParentalControlsApp])
        #expect(notifications.withLock { $0 } == 0)
        let first = try #require(store.pending())
        store.acknowledge(first)
        handler.request(token: app, appID: id) { response in responses.withLock { $0.append(response) } }
        #expect(store.pending()?.id != first.id)
        #expect(responses.withLock { $0.count } == 2)
    }
    @Test func notificationRoutePublishesTargetAndDefersAfterScheduling() async throws {
        let store = ConversationRequestStore(defaults: defaults())
        let notified = Mutex<[UUID]>([])
        let handler = ConversationShieldRequestHandler(store: store, route: .notification) { request in
            #expect(store.pending()?.id == request.id)
            notified.withLock { $0.append(request.id) }
        }
        let app = try token(), id = UUID()
        let response = await withCheckedContinuation { continuation in
            handler.request(token: app, appID: id) { continuation.resume(returning: $0) }
        }
        #expect(response == .defer)
        #expect(notified.withLock { $0 } == [try #require(store.pending()).id])
    }
    @Test func directShieldGuidanceDoesNotTellUsersToWaitForNotifications() {
        for pending in [true, false] {
            let presentation = ShieldPresentation.conversation(route: .direct, requestPending: pending)
            #expect(!presentation.subtitle.lowercased().contains("notification"))
            #expect(presentation.subtitle.contains("Volition directly"))
            #expect(presentation.secondaryButton != nil)
        }
    }
    @Test func completionIsBoundedAndOnlyRunsOnce() async {
        let calls = Mutex(0)
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let completion = ConversationShieldCompletion(timeout: 0.02) {
                calls.withLock { $0 += 1 }
                continuation.resume()
            }
            completion.armTimeout()
        }
        #expect(calls.withLock { $0 } == 1)
        let single = ConversationShieldCompletion { calls.withLock { $0 += 1 } }
        DispatchQueue.concurrentPerform(iterations: 20) { _ in single.finish() }
        #expect(calls.withLock { $0 } == 2)
    }
}
