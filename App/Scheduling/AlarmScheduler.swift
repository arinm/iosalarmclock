import Foundation
import AlarmCore

/// Coordinates the three sides of scheduling for one alarm:
///   1. recompute next occurrence(s) via the pure engine,
///   2. arm the real alarm(s) through `AlarmKitManager`,
///   3. arm the pre-alert local notification through `PreAlertNotificationManager`.
///
/// Because AlarmKit has no "skip one occurrence" primitive, we arm a small
/// look-ahead window of concrete one-time alarms and re-arm on every mutation,
/// foreground, and fire. This type holds no UI and no SwiftData.
@MainActor
final class AlarmScheduler {
    private let calculator = NextOccurrenceCalculator()
    private let alarmKit: AlarmKitManaging
    private let preAlerts: PreAlertNotificationManager
    private let calendar: Calendar

    /// How many upcoming occurrences to arm. >1 buys resilience if the app isn't
    /// opened between two consecutive fires.
    private let lookahead = 2

    init(alarmKit: AlarmKitManaging, preAlerts: PreAlertNotificationManager, calendar: Calendar = .current) {
        self.alarmKit = alarmKit
        self.preAlerts = preAlerts
        self.calendar = calendar
    }

    /// Cancel the currently-armed window, then arm the next one — as a single
    /// awaited sequence so cancel always completes before schedule (no
    /// cancel-after-schedule race). Cancellation targets the *persisted*
    /// `armedOccurrences`, i.e. exactly what was last armed (incl. today when
    /// skipping), not a recomputed post-mutation window.
    func reschedule(_ item: AlarmItem, now: Date = .now) async {
        // 1. Cancel what is actually armed right now.
        await alarmKit.cancelOccurrences(item.armedOccurrences, for: item)
        await preAlerts.cancelPreAlert(for: item)

        guard item.isEnabled else {
            item.armedOccurrences = []
            item.nextOccurrence = nil
            return
        }

        let occurrences = calculator.nextOccurrences(
            for: item.schedule, after: now, calendar: calendar, count: lookahead
        )

        guard let first = occurrences.first else {
            item.armedOccurrences = []
            item.nextOccurrence = nil
            return
        }

        // 2. Record the new armed set before arming so a crash mid-arm still
        //    leaves a cancelable record.
        item.nextOccurrence = first
        item.lastScheduledOccurrence = occurrences.last
        item.armedOccurrences = occurrences

        // 3. Arm the real alarms (awaited).
        await alarmKit.scheduleOccurrences(occurrences, for: item)

        // 4. Pre-alert heads-up for the imminent occurrence.
        if item.preAlert.isEnabled {
            await preAlerts.schedulePreAlert(for: item, fireDate: first, calendar: calendar)
        }
    }

    /// Tear down all arming for an alarm (used on delete).
    func cancel(_ item: AlarmItem) async {
        await alarmKit.cancelOccurrences(item.armedOccurrences, for: item)
        item.armedOccurrences = []
        await preAlerts.cancelPreAlert(for: item)
    }
}
