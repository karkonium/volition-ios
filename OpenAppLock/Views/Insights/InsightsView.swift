import SwiftUI
import Charts

struct InsightsView: View {
    @Environment(ConversationCoordinator.self) private var conversation
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
                List {
                    Section {
                        Picker(CopyKey.insightsRange.string, selection: $days) {
                            Text(CopyKey.insightsToday.resource).tag(1)
                            Text(CopyKey.insightsWeek.resource).tag(7)
                        }.pickerStyle(.segmented).accessibilityIdentifier("insightsRangePicker")
                        Text(CopyKey.insightsHelp.resource).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Section(CopyKey.insightsOpportunities.string) {
                        metric(.insightsRequests, summary.requests)
                        metric(.insightsGrants, summary.grants)
                        metric(.insightsMinutes, summary.grantedMinutes)
                        metric(.insightsDenials, summary.denials)
                        metric(.insightsWaits, summary.waits)
                        metric(.insightsEarlyEndings, summary.earlyEndings)
                    }
                    if days == 7 {
                        Section(CopyKey.insightsDailyRequests.string) {
                            Chart(0..<7, id: \.self) { index in
                                let day = calendar.date(byAdding: .day, value: index, to: start)!
                                let next = calendar.date(byAdding: .day, value: 1, to: day)!
                                let count = entries.filter { $0.date >= day && $0.date < next }.count
                                BarMark(x: .value(CopyKey.insightsDay.string, day, unit: .day),
                                        y: .value(CopyKey.insightsRequests.string, count))
                                    .foregroundStyle(Color.accentColor)
                            }.frame(height: 150)
                        }
                    }
                    Section(CopyKey.insightsByApp.string) {
                        let ids = Set(entries.compactMap(\.appID)).sorted { $0.uuidString < $1.uuidString }
                        if ids.isEmpty { Text(CopyKey.insightsEmpty.resource).foregroundStyle(.secondary) }
                        ForEach(ids, id: \.self) { id in
                            let appEntries = entries.filter { $0.appID == id }
                            let appSummary = AccessInsights(entries: appEntries, start: start, end: end)
                            VStack(alignment: .leading, spacing: 8) {
                                Text(appEntries.last?.appName ?? CopyKey.conversationTargetGeneric.string).font(.headline)
                                HStack {
                                    metric(.insightsGrants, appSummary.grants)
                                    metric(.insightsMinutes, appSummary.grantedMinutes)
                                }.font(.subheadline).foregroundStyle(.secondary)
                            }.padding(.vertical, 4)
                        }
                    }
                }.navigationTitle(CopyKey.insightsTitle.resource)
            }
        }
    }
    private func metric(_ key: CopyKey, _ value: Int) -> some View {
        LabeledContent(key.string, value: value.formatted())
    }
}
