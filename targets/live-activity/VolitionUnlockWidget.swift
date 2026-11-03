import ActivityKit
import SwiftUI
import WidgetKit

@main
struct VolitionLiveActivityBundle: WidgetBundle {
    var body: some Widget { VolitionUnlockWidget() }
}

struct VolitionUnlockWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ConversationUnlockActivityAttributes.self) { context in
            HStack(spacing: 14) {
                Image(systemName: "sun.max.fill").foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 4) {
                    Text(context.attributes.appName).font(.headline).lineLimit(1)
                    Text((context.isStale ? CopyKey.unlockActivityExpired : .unlockActivityWindow).resource)
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                countdown(context).font(.title2.bold()).frame(maxWidth: 110)
            }.padding().foregroundStyle(.white).widgetURL(context.attributes.url)
                .activityBackgroundTint(.black.opacity(0.85)).activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.attributes.appName, systemImage: "sun.max.fill").font(.headline)
                }
                DynamicIslandExpandedRegion(.trailing) { countdown(context).frame(width: 90) }
                DynamicIslandExpandedRegion(.bottom) {
                    Text((context.isStale ? CopyKey.unlockActivityExpired : .unlockActivityWindow).resource)
                        .font(.caption).foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: "sun.max.fill").foregroundStyle(.orange)
            } compactTrailing: {
                countdown(context).frame(width: 54)
            } minimal: {
                Image(systemName: "hourglass.bottomhalf.filled").foregroundStyle(.orange)
            }.widgetURL(context.attributes.url).keylineTint(.orange)
        }
    }
    private func countdown(_ context: ActivityViewContext<ConversationUnlockActivityAttributes>) -> some View {
        Text(timerInterval: context.state.start...context.state.expiresAt, countsDown: true, showsHours: false)
            .monospacedDigit().contentTransition(.numericText(countsDown: true))
    }
}
