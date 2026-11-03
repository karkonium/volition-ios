import Foundation
import Observation

/// User changes register monitoring before publication. Failure leaves a visible
/// error and keeps restrictions conservative. The grant lock serializes policy
/// changes with approvals across the app and its extensions.
@Observable
final class FocusController {
    private(set) var state = FocusProtectionState()
    private(set) var isSaving = false
    var errorMessage: String?
    private let access: ConversationEnforcement
    private let monitor: any FocusMonitoring
    init(access: ConversationEnforcement, monitor: any FocusMonitoring = DeviceFocusMonitor()) {
        self.access = access; self.monitor = monitor
        do { state = try access.focusStore.load() }
        catch { errorMessage = CopyKey.enforcementUncertain.string }
    }
    func save(_ state: FocusProtectionState) async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            let access = access; let monitor = monitor
            try await Task.detached { try access.updateFocus(state, monitor: monitor) }.value
            self.state = state; errorMessage = nil
        } catch { errorMessage = CopyKey.focusSaveError.string }
    }
    func endCurrent(now: Date = .now) async {
        var updated = state
        updated.session = nil
        for index in updated.periods.indices {
            if let interval = updated.periods[index].activeInterval(at: now) { updated.periods[index].skippedUntil = interval.end }
        }
        await save(updated)
    }
    func refresh() async {
        do {
            state = try access.focusStore.load()
            let access = access; let monitor = monitor; let state = state
            try await Task.detached {
                try access.store.transaction { _ in try monitor.register(state, now: .now) }
                monitor.keepOnly(state.activityNames(at: .now))
            }.value
            errorMessage = nil
        } catch { errorMessage = CopyKey.focusSaveError.string }
    }
}
