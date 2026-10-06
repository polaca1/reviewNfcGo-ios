import WidgetKit
import SwiftUI
import ActivityKit

@main
struct ReviewNfcGoLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        ReviewNfcGoLiveActivity()
    }
}

struct ReviewNfcGoLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ReminderActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.title3).foregroundStyle(.teal)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("PRÓXIMA VISITA").font(.caption2.bold()).foregroundStyle(.secondary)
                        Text(context.attributes.placeName).font(.headline).lineLimit(1)
                    }
                    Spacer()
                }
                Text(timerInterval: min(Date(), context.state.visitDate)...context.state.visitDate, countsDown: true)
                    .font(.system(.title, design: .rounded, weight: .semibold)).monospacedDigit()
                Text(context.attributes.address).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            .padding(20)
            .activityBackgroundTint(Color(uiColor: .secondarySystemBackground))
            .activitySystemActionForegroundColor(.primary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "building.2.fill")
                        .foregroundStyle(.teal)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: min(Date(), context.state.visitDate)...context.state.visitDate, countsDown: true)
                        .monospacedDigit().font(.headline)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(context.attributes.placeName).font(.headline).lineLimit(1)
                        Text(context.attributes.address).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                Image(systemName: "building.2.fill")
                    .foregroundStyle(.teal)
            } compactTrailing: {
                Text(timerInterval: min(Date(), context.state.visitDate)...context.state.visitDate, countsDown: true)
                    .monospacedDigit().frame(width: 54)
            } minimal: {
                Image(systemName: "timer")
                    .foregroundStyle(.teal)
            }
        }
    }
}
