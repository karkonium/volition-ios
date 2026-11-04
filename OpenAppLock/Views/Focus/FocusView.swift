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
                                if let issue = FormValidation.focusSelectionError(allApps: allApps, selected: appIDs, available: availableAppIDs) {
                                    focus.errorMessage = issue.string; return
                                }
                                Task {
                                    conversation.cancelRequest()
                                    var state = focus.state
                                    state.session = FocusSession(appIDs: allApps ? [] : appIDs, start: .now, minutes: minutes)
                                    await update(state)
                                }
                            }
                            .buttonStyle(VolitionButtonStyle())
                            .disabled(focus.isSaving)
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
                                        if enabled, let issue = FormValidation.focusSelectionError(allApps: period.appIDs.isEmpty, selected: period.appIDs, available: availableAppIDs) {
                                            focus.errorMessage = issue.string; return
                                        }
                                        var state = focus.state
                                        if let index = state.periods.firstIndex(where: { $0.id == period.id }) { state.periods[index].isEnabled = enabled }
                                        Task { await update(state) }
                                    })).labelsHidden().tint(VolitionStyle.accent).accessibilityLabel(period.name)
                                }
                                if let issue = FormValidation.focusSelectionError(allApps: period.appIDs.isEmpty, selected: period.appIDs, available: availableAppIDs) {
                                    Text(issue.resource).font(.caption).foregroundStyle(.red)
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
            .volitionTabRoot()
            .sheet(item: $editingPeriod) { period in FocusPeriodEditor(original: period) }
            .confirmationDialog(CopyKey.focusEndCurrent.string, isPresented: $confirmingEnd, titleVisibility: .visible) {
                Button(CopyKey.focusEndCurrent.resource, role: .destructive) {
                    Task { conversation.cancelRequest(); await focus.endCurrent(); await refresh() }
                }
            } message: { Text(CopyKey.focusEndHelp.resource) }
            .task { await focus.refresh() }
        }
    }
    private var availableAppIDs: Set<UUID> { Set(rules.filter { $0.kind == .conversation && $0.isEnabled }.map(\.id)) }
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

/// Missing custom selections remain explicit; an empty selection never means all apps here.
struct FocusAppSelection: View {
    @Binding var allApps: Bool
    @Binding var appIDs: Set<UUID>
    @Query(sort: BlockingRule.displayOrder) private var rules: [BlockingRule]
    private var available: Set<UUID> { Set(rules.filter { $0.kind == .conversation && $0.isEnabled }.map(\.id)) }
    var body: some View {
        Toggle(CopyKey.focusAllApps.resource, isOn: $allApps).tint(VolitionStyle.accent).font(.subheadline).frame(minHeight: 44)
        if !allApps {
            ForEach(rules.filter { $0.kind == .conversation && $0.isEnabled }) { rule in
                Toggle(rule.name, isOn: Binding(get: { appIDs.contains(rule.id) }, set: { selected in
                    if selected { appIDs.insert(rule.id) } else { appIDs.remove(rule.id) }
                })).tint(VolitionStyle.accent)
            }
            if !appIDs.isSubset(of: available) {
                Button(CopyKey.uiChangeApp.resource) { appIDs.formIntersection(available) }
            }
        }
        if let issue = FormValidation.focusSelectionError(allApps: allApps, selected: appIDs, available: available) {
            Text(issue.resource).font(.caption).foregroundStyle(.red).accessibilityIdentifier("focusAppSelectionError")
        }
    }
}

/// Invalid Save attempts reveal the first field; dirty drafts require explicit discard.
private struct FocusPeriodEditor: View {
    let original: FocusPeriod
    @Environment(FocusController.self) private var focus
    @Environment(ConversationCoordinator.self) private var conversation
    @Environment(RuleEnforcer.self) private var enforcer
    @Environment(\.dismiss) private var dismiss
    @Query private var rules: [BlockingRule]
    @State private var name = ""
    @State private var weekdays: Set<Int> = [2, 3, 4, 5, 6]
    @State private var start = Date()
    @State private var end = Date()
    @State private var allApps = true
    @State private var appIDs = Set<UUID>()
    @State private var initial: FocusPeriod?
    @State private var attempted = false
    @State private var attention: [String: Int] = [:]
    @State private var confirmingDiscard = false
    @FocusState private var nameFocused: Bool
    private var period: FocusPeriod {
        let calendar = Calendar.current
        var value = FocusPeriod(name: FormValidation.trim(name), appIDs: allApps ? [] : appIDs,
            weekdays: weekdays, startMinutes: calendar.component(.hour, from: start) * 60 + calendar.component(.minute, from: start),
            endMinutes: calendar.component(.hour, from: end) * 60 + calendar.component(.minute, from: end))
        value.id = original.id; value.isEnabled = original.isEnabled; value.skippedUntil = original.skippedUntil
        return value
    }
    private var isDirty: Bool { initial.map { $0 != period || name != $0.name || allApps != $0.appIDs.isEmpty } ?? false }
    private var selectionError: CopyKey? {
        FormValidation.focusSelectionError(allApps: allApps, selected: appIDs,
            available: Set(rules.filter { $0.kind == .conversation && $0.isEnabled }.map(\.id)))
    }
    private var invalidField: String? {
        if FormValidation.nameError(name) != nil { return "name" }
        if (period.endMinutes - period.startMinutes + 1440) % 1440 < 15 { return "time" }
        if weekdays.isEmpty { return "days" }
        if selectionError != nil { return "apps" }
        return nil
    }
    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                Form {
                    Section {
                        TextField(CopyKey.focusScheduleName.string, text: $name).textFieldStyle(.roundedBorder)
                            .focused($nameFocused).accessibilityIdentifier("focusScheduleName")
                        if attempted, FormValidation.nameError(name) != nil {
                            Text(CopyKey.validationFocusName.resource).foregroundStyle(.red).accessibilityIdentifier("focusNameError")
                        }
                    }.id("name").volitionAttention(trigger: attention["name", default: 0])
                    Section {
                        DatePicker(CopyKey.focusStarts.string, selection: $start, displayedComponents: .hourAndMinute)
                        DatePicker(CopyKey.focusEnds.string, selection: $end, displayedComponents: .hourAndMinute)
                        if attempted, (period.endMinutes - period.startMinutes + 1440) % 1440 < 15 {
                            Text(CopyKey.focusScheduleHelp.resource).foregroundStyle(.red)
                        }
                    } footer: { Text(CopyKey.focusScheduleHelp.resource) }
                    .id("time").volitionAttention(trigger: attention["time", default: 0])
                    Section(CopyKey.focusDays.string) {
                        ForEach(1...7, id: \.self) { day in
                            Toggle(Calendar.current.weekdaySymbols[day - 1], isOn: Binding(get: { weekdays.contains(day) }, set: { enabled in
                                if enabled { weekdays.insert(day) } else { weekdays.remove(day) }
                            }))
                        }
                        if attempted, weekdays.isEmpty { Text(CopyKey.validationFocusDays.resource).foregroundStyle(.red) }
                    }.id("days").volitionAttention(trigger: attention["days", default: 0])
                    Section { FocusAppSelection(allApps: $allApps, appIDs: $appIDs) }.id("apps").volitionAttention(trigger: attention["apps", default: 0])
                    if let error = focus.errorMessage { Text(error).foregroundStyle(.red) }
                }
                .disabled(focus.isSaving)
                .volitionForm()
                .navigationTitle(CopyKey.uiPeriodEditorTitle.resource)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(CopyKey.conversationCancel.resource) { if isDirty { confirmingDiscard = true } else { dismiss() } }
                            .disabled(focus.isSaving)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(CopyKey.uiSave.resource) {
                            attempted = true
                            if let invalidField {
                                attention[invalidField, default: 0] += 1; nameFocused = invalidField == "name"
                                withAnimation { proxy.scrollTo(invalidField, anchor: .center) }
                                return
                            }
                            let submitted = period
                            Task {
                                conversation.cancelRequest()
                                var state = focus.state
                                if let index = state.periods.firstIndex(where: { $0.id == submitted.id }) { state.periods[index] = submitted }
                                else { state.periods.append(submitted) }
                                await focus.save(state)
                                guard focus.errorMessage == nil else { return }
                                await enforcer.refresh(rules: rules)
                                await conversation.refresh(snapshots: rules.map(\.dto))
                                dismiss()
                            }
                        }.disabled(focus.isSaving).accessibilityIdentifier("saveFocusScheduleButton")
                    }
                }
                .alert(CopyKey.discardChangesTitle.string, isPresented: $confirmingDiscard) {
                    Button(CopyKey.discardChangesAction.resource, role: .destructive) { dismiss() }
                    Button(CopyKey.keepEditing.resource, role: .cancel) {}
                }
                .interactiveDismissDisabled(focus.isSaving || isDirty)
                .onAppear {
                    guard initial == nil else { return }
                    name = original.name; weekdays = original.weekdays; appIDs = original.appIDs; allApps = original.appIDs.isEmpty
                    start = Calendar.current.date(bySettingHour: original.startMinutes / 60, minute: original.startMinutes % 60, second: 0, of: .now) ?? .now
                    end = Calendar.current.date(bySettingHour: original.endMinutes / 60, minute: original.endMinutes % 60, second: 0, of: .now) ?? .now
                    initial = period
                }
            }
        }
    }
}
