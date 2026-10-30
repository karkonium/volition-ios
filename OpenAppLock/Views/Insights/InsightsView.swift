import SwiftUI
import Charts

struct InsightsView: View {
    @Environment(ConversationCoordinator.self) private var conversation
    @Environment(\.dynamicTypeSize) private var textSize
    @State private var days = 1
    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 60)) { timeline in
                let calendar = Calendar.current
                let today = calendar.startOfDay(for: timeline.date)
                let start = calendar.date(byAdding: .day, value: 1 - days, to: today)!
                let end = calendar.date(byAdding: .day, value: 1, to: today)!
                let entries = conversation.history.activityLog.filter { $0.date >= start && $0.date < end }
                let summary = AccessInsights(entries: entries, start: start, end: end)
                VolitionScroll {
                    Picker(CopyKey.insightsRange.string, selection: $days) {
                        Text(CopyKey.insightsToday.resource).tag(1)
                        Text(CopyKey.insightsWeek.resource).tag(7)
                    }.pickerStyle(.segmented).accessibilityIdentifier("insightsRangePicker")
                    VStack(alignment: .leading, spacing: 10) {
                        VolitionSectionHeading(title: CopyKey.insightsOpportunities.string)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: textSize.isAccessibilitySize ? 1 : 2), spacing: 10) {
                            stat(.insightsGrants, summary.grants, accented: true)
                            stat(.insightsMinutes, summary.grantedMinutes, accented: true)
                            stat(.insightsRequests, summary.requests)
                            stat(.insightsEarlyEndings, summary.earlyEndings)
                        }
                        HStack(spacing: 20) {
                            Label("\(summary.denials) " + CopyKey.insightsDenials.string, systemImage: "hand.raised")
                            Label("\(summary.waits) " + CopyKey.insightsWaits.string, systemImage: "pause")
                        }.font(.caption).foregroundStyle(.secondary)
                    }
                    if days == 7 {
                        VStack(alignment: .leading, spacing: 10) {
                            VolitionSectionHeading(title: CopyKey.insightsDailyRequests.string)
                            VolitionCard {
                                Chart(0..<7, id: \.self) { index in
                                    let day = calendar.date(byAdding: .day, value: index, to: start)!
                                    let next = calendar.date(byAdding: .day, value: 1, to: day)!
                                    let count = entries.filter { $0.date >= day && $0.date < next }.count
                                    BarMark(x: .value(CopyKey.insightsDay.string, day, unit: .day),
                                            y: .value(CopyKey.insightsRequests.string, count))
                                        .foregroundStyle(VolitionStyle.accent.opacity(0.75)).cornerRadius(4)
                                }
                                .chartYScale(domain: 0...max(1, entries.count))
                                .frame(height: 140)
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        VolitionSectionHeading(title: CopyKey.insightsByApp.string)
                        let ids = Set(entries.compactMap(\.appID)).sorted { $0.uuidString < $1.uuidString }
                        if ids.isEmpty {
                            VolitionCard {
                                Label(CopyKey.insightsEmpty.resource, systemImage: "chart.bar")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                        ForEach(ids, id: \.self) { id in
                            let appEntries = entries.filter { $0.appID == id }
                            let totals = AccessInsights(entries: appEntries, start: start, end: end)
                            VolitionCard {
                                HStack(alignment: .top, spacing: 12) {
                                    VolitionIcon(symbol: "app")
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(appEntries.last?.appName ?? CopyKey.conversationTargetGeneric.string).font(.subheadline.weight(.semibold))
                                        Text(CopyKey.uiAppInsights.string(totals.grants, totals.grantedMinutes))
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    Text(CopyKey.insightsHelp.resource).font(.caption).foregroundStyle(.secondary)
                }.volitionTabRoot()
            }
        }
    }
    private func stat(_ key: CopyKey, _ value: Int, accented: Bool = false) -> some View {
        VolitionCard(accented: accented) {
            Text(value.formatted()).font(.system(.title, design: .rounded, weight: .semibold)).monospacedDigit()
            Text(key.resource).font(.caption).foregroundStyle(.secondary)
        }.accessibilityElement(children: .combine)
    }
}
