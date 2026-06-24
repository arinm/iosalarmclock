import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents

/// The bespoke "next alarm" Live Activity: a live countdown on the Lock Screen
/// and in the Dynamic Island, with a first-class **Skip today** button.
struct AlarmLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PunctualActivityAttributes.self) { context in
            // Lock Screen / banner presentation.
            LockScreenLiveActivityView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.35))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("Alarm", systemImage: "alarm.fill").font(.caption).foregroundStyle(.tint)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    countdown(context).font(.system(.title3, design: .rounded).weight(.bold)).monospacedDigit()
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.label.isEmpty ? "Alarm" : context.state.label)
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if context.state.skippedToday {
                        Label("Skipped today — still active", systemImage: "checkmark.circle.fill")
                            .font(.caption2).foregroundStyle(BrandColor.skip)
                    } else {
                        Button(intent: SkipTodayIntent(alarmIDString: context.attributes.alarmID)) {
                            Label("Skip today", systemImage: "forward.end.fill").font(.caption.weight(.semibold))
                        }
                        .tint(BrandColor.skip)
                    }
                }
            } compactLeading: {
                Image(systemName: "alarm.fill").foregroundStyle(.tint)
            } compactTrailing: {
                countdown(context).monospacedDigit().frame(maxWidth: 56)
            } minimal: {
                Image(systemName: "alarm.fill").foregroundStyle(.tint)
            }
            .keylineTint(BrandColor.accent)
        }
    }

    private func countdown(_ context: ActivityViewContext<PunctualActivityAttributes>) -> Text {
        if context.state.skippedToday { return Text("—") }
        return Text(timerInterval: Date.now...context.state.fireDate, countsDown: true)
    }
}

private struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<PunctualActivityAttributes>

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "alarm.fill").font(.title2).foregroundStyle(BrandColor.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(context.state.label.isEmpty ? "Next alarm" : context.state.label)
                    .font(.headline).lineLimit(1)
                if context.state.skippedToday {
                    Label("Skipped today — still active", systemImage: "checkmark.circle.fill")
                        .font(.caption).foregroundStyle(BrandColor.skip)
                } else {
                    HStack(spacing: 4) {
                        Text("Rings in")
                        Text(timerInterval: Date.now...context.state.fireDate, countsDown: true)
                            .monospacedDigit().fontWeight(.semibold)
                    }
                    .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if !context.state.skippedToday {
                Button(intent: SkipTodayIntent(alarmIDString: context.attributes.alarmID)) {
                    Image(systemName: "forward.end.fill")
                        .font(.title3).padding(10)
                        .background(BrandColor.skip.opacity(0.2), in: Circle())
                }
                .tint(BrandColor.skip)
            }
        }
        .padding()
    }
}
