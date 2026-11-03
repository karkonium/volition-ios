//
//  SampleRules.swift
//  OpenAppLock
//

import FamilyControls
import ManagedSettings
import Foundation
import SwiftData

/// Builds deterministic rules for UI-test scenarios, positioned relative to
/// "now" so an active window is genuinely active whenever the test runs.
enum SampleRules {
    static var minutesInterval: Int { 5 }
    
    static func seed(
        _ scenario: LaunchConfiguration.SeedScenario,
        into context: ModelContext,
        usage: MockUsageLedger? = nil,
        now: Date = .now,
        calendar: Calendar = .current
    ) {
        // Shared list so seeded rules demonstrate the app-list UI. The count
        // is display-only; UI tests never decode real tokens.
        let distractions = AppList(name: "Distractions", selectionCount: 3)
        context.insert(distractions)
        let focus = AppList(name: "Focus Apps", selectionCount: 2)
        context.insert(focus)

        let rules: [BlockingRule]
        switch scenario {
        case .conversationMultiple, .conversationStress:
            let stress = scenario == .conversationStress
            for byte: UInt8 in stress ? Array(11...20) : [11, 12] {
                guard let data = try? JSONSerialization.data(withJSONObject: ["data": Data([byte]).base64EncodedString()]),
                      let token = try? JSONDecoder().decode(ApplicationToken.self, from: data) else { continue }
                var selection = FamilyActivitySelection(); selection.applicationTokens = [token]
                let name = stress && byte == 11 ? "A deliberately long app name that needs several lines" : "App \(byte)"
                let list = AppList(name: name, selectionData: AppSelectionCodec.encode(selection), selectionCount: 1)
                let goal = stress ? "Keep in touch with the people I care about, then close the app without getting drawn into an endless feed." : "Contact friends with purpose."
                let rule = BlockingRule(name: name, configuration: .conversation(.init(goal: goal)))
                context.insert(list); context.insert(rule); rule.appLists = [list]
            }
            try? context.save()
            return
        case .conversation, .conversationLong:
            // Synthetic tokens are strictly UI harness data; no real picker authorization is needed.
            var selection = FamilyActivitySelection()
            if let data = try? JSONSerialization.data(withJSONObject: ["data": Data([1]).base64EncodedString()]),
               let token = try? JSONDecoder().decode(ApplicationToken.self, from: data) {
                selection.applicationTokens = [token]
            }
            distractions.selectionData = AppSelectionCodec.encode(selection)
            distractions.selectionCount = 1
            rules = [BlockingRule(name: "Intentional Access", configuration: .conversation(
                ConversationConfig(goal: "Open this app for a specific useful task.")))]
        case .standard:
            rules = [
                activeRule(named: "Work Time", hardMode: false, now: now, calendar: calendar),
                upcomingRule(named: "Sleep", now: now, calendar: calendar),
            ]
        case .hardModeActive:
            rules = [
                activeRule(named: "Locked In", hardMode: true, now: now, calendar: calendar),
                upcomingRule(named: "Sleep", now: now, calendar: calendar),
            ]
        case .limits:
            let timeKeeper = BlockingRule(
                name: "Time Keeper",
                configuration: .timeLimit(TimeLimitConfig(dailyLimitMinutes: 45)),
                days: Weekday.everyDay)
            let gateKeeper = BlockingRule(
                name: "Gate Keeper",
                configuration: .openLimit(OpenLimitConfig(maxOpens: 5)),
                days: Weekday.everyDay)
            let doomScroll = BlockingRule(
                name: "Doom Scroll",
                configuration: .timeLimit(TimeLimitConfig(dailyLimitMinutes: 30)),
                days: Weekday.everyDay)
            usage?.usageByRule[timeKeeper.id] = RuleUsageDTO(minutesUsed: 18)
            usage?.usageByRule[gateKeeper.id] = RuleUsageDTO(opensUsed: 2)
            usage?.usageByRule[doomScroll.id] = RuleUsageDTO(minutesUsed: 30)
            rules = [timeKeeper, gateKeeper, doomScroll]
        case .atRuleCap:
            rules = (1...RuleCreationPolicy.maxRuleCount).map { index in
                BlockingRule(
                    name: String(format: "Rule %02d", index),
                    configuration: .schedule(
                        ScheduleConfig(startMinutes: 9 * 60, endMinutes: 17 * 60)),
                    days: Weekday.everyDay)
            }
        }
        // Relationships are wired only after both sides are managed
        // (see BlockingRule.appLists).
        for rule in rules {
            context.insert(rule)
            rule.appLists = [distractions]
        }
        if scenario == .conversationLong {
            var history = ConversationHistory()
            history.messages = (0..<40).map { index in
                .init(role: index.isMultiple(of: 2) ? .user : .assistant,
                    text: "Earlier message \(index). A saved conversation about making room for a thoughtful, intentional activity.")
            }
            try? ConversationHistoryStore(context: context).save(history)
        }
    }

    /// A schedule rule whose window started ~an hour ago and always has ~6 hours
    /// remaining, wrapping past midnight when needed. Schedules support an end at
    /// or before the start to mean "crosses midnight" (see `RuleSchedule`), so the
    /// window stays a genuine ~6-hour active block regardless of the time of day.
    /// The previous clamp to 23:59 left under 15 minutes remaining in the last
    /// stretch before midnight, which dropped `RulePolicy.canPause` below its floor
    /// (`MonitoringPlan.temporaryPauseMinutes`) — the pause button then vanished
    /// and the CI pause UI tests flaked in the pre-UTC-midnight window.
    static func activeRule(
        named name: String, hardMode: Bool, now: Date, calendar: Calendar = .current
    ) -> BlockingRule {
        let nowMinutes = minutesIntoDay(of: now, calendar: calendar)
        let start = clampToMinutesInterval(minutes: (nowMinutes + 24 * 60 - 60) % (24 * 60))
        let end = clampToMinutesInterval(minutes: (nowMinutes + 6 * 60) % (24 * 60))
        return BlockingRule(
            name: name,
            configuration: .schedule(ScheduleConfig(startMinutes: start, endMinutes: end)),
            hardMode: hardMode,
            days: Weekday.everyDay
        )
    }

    /// A schedule rule starting a couple of hours from now (possibly wrapping
    /// past midnight, which simply makes it start tomorrow).
    static func upcomingRule(
        named name: String, now: Date, calendar: Calendar = .current
    ) -> BlockingRule {
        let nowMinutes = minutesIntoDay(of: now, calendar: calendar)
        let start = clampToMinutesInterval(minutes: (nowMinutes + 2 * 60) % (24 * 60))
        let end = clampToMinutesInterval(minutes: (start + 8 * 60) % (24 * 60))
        return BlockingRule(
            name: name,
            configuration: .schedule(ScheduleConfig(startMinutes: start, endMinutes: end)),
            days: Weekday.everyDay
        )
    }

    private static func minutesIntoDay(of date: Date, calendar: Calendar) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }
    
    private static func clampToMinutesInterval(minutes: Int) -> Int {
        return minutes - (minutes % minutesInterval)
    }
}
