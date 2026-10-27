import SwiftUI
import SwiftData

struct FocusView: View {
    @Environment(FocusController.self) private var focus
    @Environment(ConversationCoordinator.self) private var conversation
    @Environment(RuleEnforcer.self) private var enforcer
    @Query(sort: BlockingRule.displayOrder) private var rules: [BlockingRule]
    @State private var minutes = 25
    @State private var allApps = true
    @State private var appIDs = Set<UUID>()
    @State private var editingPeriod: FocusPeriod?
    @State private var confirmingEnd = false
    var body: some View {
        NavigationStack {
            Form {
                Section { Text(CopyKey.focusHelp.resource).foregroundStyle(.secondary) }
                TimelineView(.periodic(from: .now, by: 1)) { timeline in
                    if let session = focus.state.session, session.isActive(at: timeline.date) {
                        Section(CopyKey.focusActiveSession.string) {
                            Label(CopyKey.focusProtected.string, systemImage: "moon.fill").font(.headline)
                            Text(session.expiresAt, style: .timer).monospacedDigit()
                        }
                    }
                }
                Section(CopyKey.focusStartSession.string) {
                    Picker(CopyKey.focusDuration.string, selection: $minutes) {
                        ForEach([15, 25, 50], id: \.self) { value in Text("\(value) min").tag(value) }
                        if ![15, 25, 50].contains(minutes) { Text("\(minutes) min").tag(minutes) }
                    }.pickerStyle(.segmented)
                    Stepper(value: $minutes, in: 15...180, step: 5) {
                        LabeledContent(CopyKey.focusCustomDuration.string, value: "\(minutes) min")
                    }
                    FocusAppSelection(allApps: $allApps, appIDs: $appIDs)
                    Button(CopyKey.focusStart.string, systemImage: "moon") {
                        Task {
                            conversation.cancelRequest()
                            var state = focus.state
                            state.session = FocusSession(appIDs: allApps ? [] : appIDs, start: .now, minutes: minutes)
                            await update(state)
                        }
                    }.disabled(focus.isSaving || (!allApps && appIDs.isEmpty) || rules.filter { $0.kind == .conversation && $0.isEnabled }.isEmpty)
                        .accessibilityIdentifier("startFocusSessionButton")
                }
                Section(CopyKey.focusSchedules.string) {
                    ForEach(focus.state.periods) { period in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Button { editingPeriod = period } label: { Text(period.name).font(.headline) }
                                Spacer()
                                Toggle(CopyKey.focusEnabled.string, isOn: Binding(get: { period.isEnabled }, set: { enabled in
                                    var state = focus.state
                                    if let index = state.periods.firstIndex(where: { $0.id == period.id }) { state.periods[index].isEnabled = enabled }
                                    Task { await update(state) }
                                })).labelsHidden().accessibilityLabel(period.name)
                            }
                            Text(scheduleDescription(period)).font(.subheadline).foregroundStyle(.secondary)
                            Button(CopyKey.focusRemoveSchedule.resource, role: .destructive) {
                                var state = focus.state; state.periods.removeAll { $0.id == period.id }
                                Task { await update(state) }
                            }.font(.footnote)
                        }.padding(.vertical, 5)
                    }
                    Button(CopyKey.focusAddSchedule.resource, systemImage: "plus") { editingPeriod = FocusPeriod(name: "", appIDs: [], weekdays: [2, 3, 4, 5, 6], startMinutes: 540, endMinutes: 1020) }
                        .accessibilityIdentifier("addFocusScheduleButton")
                }
                if focus.state.session != nil || focus.state.periods.contains(where: { $0.isActive(at: .now) }) {
                    Section {
                        Button(CopyKey.focusEndCurrent.resource, role: .destructive) { confirmingEnd = true }
                            .accessibilityIdentifier("endFocusButton")
                    }
                }
                if let error = focus.errorMessage {
                    Section { Text(error).foregroundStyle(.red) }
                }
            }
            .disabled(focus.isSaving)
            .navigationTitle(CopyKey.focusTitle.resource)
            .sheet(item: $editingPeriod) { period in FocusPeriodEditor(original: period) }
            .confirmationDialog(CopyKey.focusEndCurrent.string, isPresented: $confirmingEnd, titleVisibility: .visible) {
                Button(CopyKey.focusEndCurrent.resource, role: .destructive) {
                    Task { conversation.cancelRequest(); await focus.endCurrent(); await refresh() }
                }
            } message: { Text(CopyKey.focusEndHelp.resource) }
            .task { await focus.refresh() }
        }
    }
    private func update(_ state: FocusProtectionState) async { await focus.save(state); await refresh() }
    private func refresh() async {
        await enforcer.refresh(rules: rules)
        await conversation.refresh(snapshots: rules.map(\.dto))
    }
    private func scheduleDescription(_ period: FocusPeriod) -> String {
        let calendar = Calendar.current
        let days = period.weekdays.sorted().map { calendar.shortWeekdaySymbols[$0 - 1] }.joined(separator: ", ")
        func time(_ minutes: Int) -> String {
            calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: .now)!.formatted(date: .omitted, time: .shortened)
        }
        return "\(days) · \(time(period.startMinutes))–\(time(period.endMinutes))"
    }
}

struct FocusAppSelection: View {
    @Binding var allApps: Bool
    @Binding var appIDs: Set<UUID>
    @Query(sort: BlockingRule.displayOrder) private var rules: [BlockingRule]
    var body: some View {
        Toggle(CopyKey.focusAllApps.resource, isOn: $allApps)
        if !allApps {
            ForEach(rules.filter { $0.kind == .conversation && $0.isEnabled }) { rule in
                Toggle(rule.name, isOn: Binding(get: { appIDs.contains(rule.id) }, set: { selected in
                    if selected { appIDs.insert(rule.id) } else { appIDs.remove(rule.id) }
                }))
            }
        }
    }
}

private struct FocusPeriodEditor: View {
    let original: FocusPeriod
    @Environment(FocusController.self) private var focus
    @Environment(ConversationCoordinator.self) private var conversation
    @Environment(RuleEnforcer.self) private var enforcer
    @Environment(\.dismiss) private var dismiss
    @Query private var rules: [BlockingRule]
    @State private var name = ""
    @State private var weekdays: Set<Int> = [2, 3, 4, 5, 6]
    @State private var start = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: .now)!
    @State private var end = Calendar.current.date(bySettingHour: 17, minute: 0, second: 0, of: .now)!
    @State private var allApps = true
    @State private var appIDs = Set<UUID>()
    private var period: FocusPeriod {
        let calendar = Calendar.current
        var period = FocusPeriod(name: name.trimmingCharacters(in: .whitespacesAndNewlines), appIDs: allApps ? [] : appIDs,
            weekdays: weekdays, startMinutes: calendar.component(.hour, from: start) * 60 + calendar.component(.minute, from: start),
            endMinutes: calendar.component(.hour, from: end) * 60 + calendar.component(.minute, from: end))
        period.id = original.id; period.isEnabled = original.isEnabled; period.skippedUntil = original.skippedUntil
        return period
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(CopyKey.focusScheduleName.string, text: $name).accessibilityIdentifier("focusScheduleName")
                    DatePicker(CopyKey.focusStarts.string, selection: $start, displayedComponents: .hourAndMinute)
                    DatePicker(CopyKey.focusEnds.string, selection: $end, displayedComponents: .hourAndMinute)
                } footer: { Text(CopyKey.focusScheduleHelp.resource) }
                Section(CopyKey.focusDays.string) {
                    ForEach(1...7, id: \.self) { day in
                        Toggle(Calendar.current.weekdaySymbols[day - 1], isOn: Binding(get: { weekdays.contains(day) }, set: { enabled in
                            if enabled { weekdays.insert(day) } else { weekdays.remove(day) }
                        }))
                    }
                }
                Section { FocusAppSelection(allApps: $allApps, appIDs: $appIDs) }
                if let error = focus.errorMessage { Text(error).foregroundStyle(.red) }
            }
            .navigationTitle(CopyKey.focusAddSchedule.resource)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(CopyKey.conversationCancel.resource) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(CopyKey.volitionSaveApp.resource) {
                        Task {
                            conversation.cancelRequest()
                            var state = focus.state
                            if let index = state.periods.firstIndex(where: { $0.id == period.id }) { state.periods[index] = period }
                            else { state.periods.append(period) }
                            await focus.save(state)
                            await enforcer.refresh(rules: rules)
                            await conversation.refresh(snapshots: rules.map(\.dto))
                            if focus.errorMessage == nil { dismiss() }
                        }
                    }.disabled(!period.isValid || (!allApps && appIDs.isEmpty) || focus.isSaving)
                    .accessibilityIdentifier("saveFocusScheduleButton")
                }
            }.interactiveDismissDisabled(focus.isSaving)
            .onAppear {
                name = original.name; weekdays = original.weekdays; appIDs = original.appIDs; allApps = original.appIDs.isEmpty
                start = Calendar.current.date(bySettingHour: original.startMinutes / 60, minute: original.startMinutes % 60, second: 0, of: .now)!
                end = Calendar.current.date(bySettingHour: original.endMinutes / 60, minute: original.endMinutes % 60, second: 0, of: .now)!
            }
        }
    }
}
