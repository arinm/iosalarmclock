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
                    VStack(spacing: 4) {
                        // Today's occurrence was skipped, but the alarm is still
                        // armed for the NEXT day — reassure without hiding it.
                        if context.state.skippedToday {
                            Label("Today skipped — still active", systemImage: "checkmark.circle.fill")
                                .font(.caption2).foregroundStyle(BrandColor.skip)
                        }
                        if isPast(context) {
                            Label("Alarm time has passed", systemImage: "checkmark.circle")
                                .font(.caption2).foregroundStyle(.secondary)
                        } else if !context.state.skippedToday {
                            // Offer to skip the shown (next) occurrence. Hidden
                            // once skipped — see the Lock Screen button note.
                            Button(intent: SkipTodayIntent(alarmIDString: context.attributes.alarmID)) {
                                Label("Skip \(context.state.dayPhrase)", systemImage: "forward.end.fill").font(.caption.weight(.semibold))
                            }
                            .tint(BrandColor.skip)
                        }
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
        // Always count down to the next real ring (fireDate is already the next
        // NON-skipped occurrence), even when today was skipped. After the fire
        // time passes, don't show a dead 00:00.
        isPast(context) ? Text("—") : countdownText(to: context.state.fireDate)
    }
}

/// Countdown text that cannot trap: `Date.now...past` crashes on range
/// construction, and the system may re-render this view AFTER `staleDate`
/// (luminance change, island expand) with the app dead and the state stale.
private func countdownText(to fireDate: Date) -> Text {
    guard fireDate > .now else { return Text("Now") }
    return Text(timerInterval: Date.now...fireDate, countsDown: true)
}

/// Once the shown fire time has passed (`staleDate = fireDate`, so
/// `context.isStale` flips), the live timer would just sit at a dead
/// "Rings in 00:00" until the app next runs and ends the activity — the alarm
/// has already rung and been handled on the AlarmKit side. Render a terminal
/// state instead.
private func isPast(_ context: ActivityViewContext<PunctualActivityAttributes>) -> Bool {
    context.isStale || context.state.fireDate <= .now
}

private struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<PunctualActivityAttributes>

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "alarm.fill").font(.title2).foregroundStyle(BrandColor.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(context.state.label.isEmpty ? "Next alarm" : context.state.label)
                    .font(.headline).lineLimit(1)
                if isPast(context) {
                    // Fire time passed while the app wasn't running to end this
                    // activity — show a terminal state, not a dead 00:00 timer.
                    Text("Alarm time has passed")
                        .font(.subheadline).foregroundStyle(.secondary)
                } else {
                    // Live countdown to the next real ring.
                    HStack(spacing: 4) {
                        Text("Rings in")
                        countdownText(to: context.state.fireDate)
                            .monospacedDigit().fontWeight(.semibold)
                    }
                    .font(.subheadline).foregroundStyle(.secondary)
                }
                // Today's occurrence was skipped — reassure it's still armed for
                // the next day (the countdown above is to that next ring).
                if context.state.skippedToday {
                    Label("Today skipped — still active", systemImage: "checkmark.circle.fill")
                        .font(.caption).foregroundStyle(BrandColor.skip)
                }
            }
            Spacer()
            // Text pill, not a bare icon: the old forward.end.fill circle read
            // as a play/stop control. Hidden once skipped — the tap already got
            // its feedback (state flipped by the LiveActivityIntent) and an
            // ended activity's buttons would be inert anyway.
            if !isPast(context), !context.state.skippedToday {
                Button(intent: SkipTodayIntent(alarmIDString: context.attributes.alarmID)) {
                    Label("Skip", systemImage: "forward.end.fill")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .background(BrandColor.skip.opacity(0.2), in: Capsule())
                }
                .tint(BrandColor.skip)
                .accessibilityLabel("Skip \(context.state.dayPhrase)")
            }
        }
        .padding()
    }
}
