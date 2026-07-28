import ActivityKit
import WidgetKit
import SwiftUI
#if canImport(AlarmKit)
import AlarmKit
#endif

#if canImport(AlarmKit)
/// The Live Activity that ALARMKIT ITSELF drives, for `AlarmAttributes`.
///
/// This is REQUIRED, not decorative. Apple's docs state: "AlarmKit expects a
/// widget extension if an app supports a countdown presentation. Otherwise, the
/// system may unexpectedly dismiss alarms and FAIL TO ALERT." WWDC25 puts it
/// stronger: an alarm supporting countdown *must* implement it as a Live
/// Activity in the widget extension. Punctual supplies
/// `AlarmPresentation(alert:countdown:)` for every snooze-enabled alarm (snooze
/// is ON by default), so this configuration must exist or the system is entitled
/// to drop those alarms — the suspected cause of "the alarm didn't ring until I
/// woke the screen".
///
/// NOTE: distinct from `AlarmLiveActivity` (our own `PunctualActivityAttributes`
/// card with the Skip button, which we start ourselves to preview the next
/// alarm). This one is owned by AlarmKit and shows the live alarm's real state:
/// counting down (snooze), alerting, or paused.
struct AlarmKitLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<PunctualMetadata>.self) { context in
            AlarmKitLockScreenView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.35))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("Alarm", systemImage: "alarm.fill")
                        .font(.caption)
                        .foregroundStyle(context.attributes.tintColor)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    alarmKitStatus(context)
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .monospacedDigit()
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(alarmKitTitle(context))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } compactLeading: {
                Image(systemName: "alarm.fill").foregroundStyle(context.attributes.tintColor)
            } compactTrailing: {
                alarmKitStatus(context).monospacedDigit().frame(maxWidth: 56)
            } minimal: {
                Image(systemName: "alarm.fill").foregroundStyle(context.attributes.tintColor)
            }
            .keylineTint(context.attributes.tintColor)
        }
    }
}

/// The alarm's label, from the metadata we attach when scheduling.
private func alarmKitTitle(_ context: ActivityViewContext<AlarmAttributes<PunctualMetadata>>) -> String {
    let label = context.attributes.metadata?.label ?? ""
    return label.isEmpty ? "Alarm" : label
}

/// Live state text. `.countdown` is the snooze timer (fireDate = the re-ring),
/// `.alert` means it is ringing right now, `.paused` a held countdown.
private func alarmKitStatus(_ context: ActivityViewContext<AlarmAttributes<PunctualMetadata>>) -> Text {
    switch context.state.mode {
    case .countdown(let countdown):
        // Guard the range: `Date.now...past` traps, and the system can re-render
        // this view after the fire date (luminance change, island expand). Read
        // the clock ONCE — checking and then re-reading could straddle the fire
        // date and build an inverted range, crashing the widget extension.
        let now = Date.now
        guard countdown.fireDate > now else { return Text("Now") }
        return Text(timerInterval: now...countdown.fireDate, countsDown: true)
    case .alert:
        return Text("Now")
    case .paused:
        return Text("Paused")
    @unknown default:
        return Text("-")
    }
}

private struct AlarmKitLockScreenView: View {
    let context: ActivityViewContext<AlarmAttributes<PunctualMetadata>>

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "alarm.fill")
                .font(.title2)
                .foregroundStyle(context.attributes.tintColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(alarmKitTitle(context))
                    .font(.headline)
                    .lineLimit(1)
                subtitle
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
    }

    @ViewBuilder private var subtitle: some View {
        switch context.state.mode {
        case .countdown:
            HStack(spacing: 4) {
                Text("Snoozed - rings in")
                alarmKitStatus(context).monospacedDigit().fontWeight(.semibold)
            }
        case .alert:
            Text("Ringing now")
        case .paused:
            Text("Paused")
        @unknown default:
            Text("Alarm")
        }
    }
}
#endif
