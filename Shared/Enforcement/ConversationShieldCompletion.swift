import Foundation

/// Finishes a shield action once, including when notification APIs never call
/// back. The lock protects only this small callback, never system/store I/O.
nonisolated final class ConversationShieldCompletion: @unchecked Sendable {
    private let lock = NSLock()
    private var callback: (() -> Void)?
    private let timeout: TimeInterval
    init(timeout: TimeInterval = 1, _ callback: @escaping () -> Void) {
        self.timeout = timeout; self.callback = callback
    }
    func armTimeout() {
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + timeout) { self.finish() }
    }
    func finish() {
        lock.lock(); let callback = callback; self.callback = nil; lock.unlock()
        callback?()
    }
}
