#if DEBUG
import FamilyControls
import SwiftUI

/// Device-only timer feasibility experiment. First block a single app, confirm
/// its shield, then unlock and leave this app. Only an extension callback can
/// restore this probe's shield. Reset always removes the probe restriction.
struct ConversationTimerProbeView: View {
    @State private var selection = FamilyActivitySelection()
    @State private var picking = false
    @State private var status = "Choose one individual app that no other rule blocks."
    @State private var minutes = 1
    @State private var failure: String?

    var body: some View {
        Form {
            Section("Short unlock device test") {
                Text("This experiment checks background expiry. Existing rules still apply. Reset removes only the test block.")
                Button("Choose app") { picking = true }
                    .accessibilityIdentifier("timerProbeChooseApp")
                Button("Block selected app") { perform { try ConversationTimerProbe.block(selection) } }
                    .accessibilityIdentifier("timerProbeBlock")
                Picker("Unlock minutes", selection: $minutes) {
                    ForEach([1, 5, 10], id: \.self) { Text("\($0)").tag($0) }
                }
                Button("Start unlock") { perform { try ConversationTimerProbe.unlock(minutes: minutes) } }
                    .accessibilityIdentifier("timerProbeUnlock")
                Button("Refresh result") { refresh() }
                Text(status).accessibilityIdentifier("timerProbeStatus")
                Button("Reset test", role: .destructive) { perform { try ConversationTimerProbe.reset() } }
                    .accessibilityIdentifier("timerProbeReset")
            }
        }
        .navigationTitle("Unlock Timer Test")
        .familyActivityPicker(isPresented: $picking, selection: $selection)
        .onAppear { refresh() }
        .alert("Timer test failed", isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
            Button("OK") { failure = nil }
        } message: { Text(failure ?? "") }
    }

    private func perform(_ operation: () throws -> Void) {
        do { try operation(); refresh() }
        catch { failure = String(describing: error) }
    }

    private func refresh() {
        do {
            guard let record = try ConversationTimerProbe.read() else {
                status = "No test block. Choose one individual app, then block it."
                return
            }
            guard let plan = record.plan else {
                status = "Test block applied. Confirm the selected app is blocked, then start an unlock."
                return
            }
            status = "Expiry: \(plan.expiresAt.formatted(date: .omitted, time: .standard)). "
            if let callback = record.callbackAt {
                status += "\(record.callbackKind ?? "unknown") callback: \(callback.formatted(date: .omitted, time: .standard)); delay \(Int(callback.timeIntervalSince(plan.expiresAt)))s. Confirm the app is blocked."
            } else {
                status += "No expiry callback recorded yet."
            }
        } catch { failure = String(describing: error) }
    }
}
#endif
