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
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                let session = focus.state.session.flatMap { $0.isActive(at: timeline.date) ? $0 : nil }
                VolitionScroll {
                    Text(CopyKey.uiFocusIntro.resource).font(.subheadline).foregroundStyle(.secondary)
                    if let session {
                        VStack(alignment: .leading, spacing: 10) {
                            VolitionSectionHeading(title: CopyKey.focusActiveSession.string)
                            VolitionCard(accented: true) {
                                HStack(alignment: .top, spacing: 12) {
                                    VolitionIcon(symbol: "moon.fill", accented: true)
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(session.expiresAt, style: .timer)
                                            .font(.system(.largeTitle, design: .rounded, weight: .semibold)).monospacedDigit()
                                        Text(CopyKey.focusProtected.resource).font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer(minLength: 0)
                                }
                            }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            VolitionSectionHeading(title: CopyKey.focusStartSession.string)
                            VolitionCard {
                                Picker(CopyKey.focusDuration.string, selection: $minutes) {
                                    ForEach([15, 25, 50], id: \.self) { value in Text(CopyKey.uiMinutes.string(value)).tag(value) }
                                    if ![15, 25, 50].contains(minutes) { Text(CopyKey.uiMinutes.string(minutes)).tag(minutes) }
                                }.pickerStyle(.segmented)
                                Stepper(value: $minutes, in: 15...180, step: 5) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(CopyKey.focusCustomDuration.resource).font(.caption).foregroundStyle(.secondary)
                                        Text(CopyKey.uiMinutes.string(minutes)).font(.subheadline.weight(.semibold)).monospacedDigit()
                                    }
                                }.frame(minHeight: 44)
                                Divider()
                                FocusAppSelection(allApps: $allApps, appIDs: $appIDs)
                            }
                            Button(CopyKey.focusStart.string, systemImage: "moon") {
                                Task {
                                    conversation.cancelRequest()
                                    var state = focus.state
                                    state.session = FocusSession(appIDs: allApps ? [] : appIDs, start: .now, minutes: minutes)
                                    await update(state)
                                }
                            }
                            .buttonStyle(VolitionButtonStyle())
                            .disabled(focus.isSaving || (!allApps && appIDs.isEmpty) || rules.filter { $0.kind == .conversation && $0.isEnabled }.isEmpty)
                            .accessibilityIdentifier("startFocusSessionButton")
                        }
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        VolitionSectionHeading(title: CopyKey.focusSchedules.string, count: focus.state.periods.count)
                        ForEach(focus.state.periods) { period in
                            VolitionCard {
                                HStack(spacing: 12) {
                                    Button { editingPeriod = period } label: {
                                        HStack(spacing: 10) {
                                            VolitionIcon(symbol: "calendar")
                                            VStack(alignment: .leading, spacing: 5) {
                                                Text(period.name).font(.subheadline.weight(.semibold)).foregroundStyle(Color.primary)
                                                Text(scheduleDescription(period)).font(.caption).foregroundStyle(Color.secondary)
                                            }
                                            Spacer(minLength: 4)
                                            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Color.secondary)
                                        }.frame(minHeight: 44).contentShape(Rectangle())
                                    }.buttonStyle(.plain)
                                    Toggle(CopyKey.focusEnabled.string, isOn: Binding(get: { period.isEnabled }, set: { enabled in
                                        var state = focus.state
                                        if let index = state.periods.firstIndex(where: { $0.id == period.id }) { state.periods[index].isEnabled = enabled }
                                        Task { await update(state) }
                                    })).labelsHidden().tint(VolitionStyle.accent).accessibilityLabel(period.name)
                                }
                                Button(CopyKey.focusRemoveSchedule.resource, role: .destructive) {
                                    var state = focus.state; state.periods.removeAll { $0.id == period.id }
                                    Task { await update(state) }
                                }.buttonStyle(VolitionButtonStyle(primary: false))
                            }
                        }
                        if focus.state.periods.isEmpty {
                            Text(CopyKey.uiFocusScheduleEmpty.resource).font(.caption).foregroundStyle(.secondary)
                        }
                        Button(CopyKey.focusAddSchedule.resource, systemImage: "plus") {
                            editingPeriod = FocusPeriod(name: "", appIDs: [], weekdays: [2, 3, 4, 5, 6], startMinutes: 540, endMinutes: 1020)
                        }
                        .buttonStyle(VolitionButtonStyle(primary: false))
                        .accessibilityIdentifier("addFocusScheduleButton")
                    }
                    if session != nil || focus.state.periods.contains(where: { $0.isActive(at: timeline.date) }) {
                        Button(CopyKey.focusEndCurrent.resource, role: .destructive) { confirmingEnd = true }
                            .buttonStyle(VolitionButtonStyle(primary: false))
                            .accessibilityIdentifier("endFocusButton")
                    }
                    if let error = focus.errorMessage { Text(error).font(.footnote).foregroundStyle(.red) }
                    Text(CopyKey.focusHelp.resource).font(.caption).foregroundStyle(.secondary)
                }
            }
            .disabled(focus.isSaving)
            .volitionRoot(CopyKey.focusTitle.string)
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
        Toggle(CopyKey.focusAllApps.resource, isOn: $allApps).tint(VolitionStyle.accent).font(.subheadline).frame(minHeight: 44)
        if !allApps {
            ForEach(rules.filter { $0.kind == .conversation && $0.isEnabled }) { rule in
                Toggle(rule.name, isOn: Binding(get: { appIDs.contains(rule.id) }, set: { selected in
                    if selected { appIDs.insert(rule.id) } else { appIDs.remove(rule.id) }
                })).tint(VolitionStyle.accent)
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
                    TextField(CopyKey.focusScheduleName.string, text: $name).textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("focusScheduleName")
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
            .volitionForm()
            .navigationTitle(CopyKey.uiPeriodEditorTitle.resource)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(CopyKey.conversationCancel.resource) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(CopyKey.uiSave.resource) {
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
