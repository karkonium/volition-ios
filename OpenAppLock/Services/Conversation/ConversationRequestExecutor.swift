import Foundation

/// Owns the task lifetime independently of presentation state. A cancelled job
/// may finish late, but it cannot clear or replace the task for a newer send.
final class ConversationRequestExecutor {
    private var task: Task<Void, Never>?
    private var identity: UUID?
    func run(_ operation: @escaping () async -> Void) async {
        guard task == nil else { return }
        let id = UUID(); identity = id
        let pending = Task { await operation() }
        task = pending
        await pending.value
        if identity == id { task = nil; identity = nil }
    }
    func cancel() {
        task?.cancel(); task = nil; identity = nil
    }
}
