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

    /// How many upcoming occurrences to arm ahead. AlarmKit has no
    /// recurrence-with-exceptions, so we pre-arm a window of concrete one-shots:
    /// the app can go this many fires without being opened and alarms still ring.
    /// Seven covers roughly a week of a daily alarm — a safe buffer that stays
    /// well clear of any per-app alarm ceiling for a handful of alarms.
    private let lookahead = 7

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
    /// `liveAlarmIDs` — the set of alarm ids the system *actually* has scheduled
    /// right now (from the fire observer or a direct `AlarmManager` read). Used
    /// to detect drift: if a future occurrence was cancelled outside the app
    /// (system UI), it's missing here even though our persisted state still
    /// lists it, so we must re-arm. `nil` = truth unavailable → trust persisted.
    ///
    /// `force` — skip the fast path entirely. Mutations (edit/toggle/skip) MUST
    /// re-arm even when the occurrence *dates* are unchanged, because the armed
    /// alarms bake in configuration (label, snooze, tint) the date comparison
    /// can't see. Only the refresh passes (launch/foreground/observer) may
    /// fast-path — that's also what keeps the observer feedback loop terminal.
    func reschedule(_ item: AlarmItem, now: Date = .now,
                    liveAlarmIDs: Set<UUID>? = nil, force: Bool = false) async {
        // The window we WANT armed for the current state ([] when disabled).
        let desired = item.isEnabled
            ? calculator.nextOccurrences(for: item.schedule, after: now, calendar: calendar, count: lookahead)
            : []

        // Fast path — the armed AlarmKit window is already exactly right, so DON'T
        // cancel+reschedule. This avoids needless churn on every foreground AND,
        // critically, breaks the AlarmKit `alarmUpdates` → refresh → `alarmUpdates`
        // feedback loop: our own writes emit updates, so re-arming only when the
        // window actually changed makes the one corrective re-arm terminal.
        //
        // BUT only no-op if the system genuinely still holds these alarms — an
        // externally-cancelled future occurrence looks unchanged in our persisted
        // state, so we honour the observer's "cancelled" event by re-arming it.
        // (`armedOccurrences` records only occurrences that actually armed, so a
        // failed arm — e.g. permission denied — can never satisfy this check.)
        if !force, item.isEnabled, desired == item.armedOccurrences, item.nextOccurrence == desired.first,
           systemStillHolds(desired, for: item, liveAlarmIDs: liveAlarmIDs) {
            // Keep the pre-alert in sync — touches only local notifications, never
            // AlarmKit, so it can't feed the observer loop.
            if item.preAlert.isEnabled {
                await preAlerts.schedulePreAlerts(for: item, fireDates: desired, calendar: calendar)
            } else {
                await preAlerts.cancelPreAlert(for: item)
            }
            return
        }

        // 1. Cancel what is armed — but ONLY still-future occurrences. Never cancel
        //    an occurrence at/​before `now`: it has already fired or is alerting
        //    right now, and cancelling a firing AlarmKit alarm would silence it.
        let toCancel = item.armedOccurrences.filter { $0 > now }
        await alarmKit.cancelOccurrences(toCancel, for: item)
        await preAlerts.cancelPreAlert(for: item)

        guard item.isEnabled, let first = desired.first else {
            item.armedOccurrences = []
            item.nextOccurrence = nil
            return
        }

        // 2. Record the intended window before arming so a crash mid-arm still
        //    leaves a cancelable record. `nextOccurrence` is the engine's truth
        //    (drives the UI countdown) regardless of arming outcome — the
        //    permission banner explains the "can't ring" case to the user.
        item.nextOccurrence = first
        item.lastScheduledOccurrence = desired.last
        item.armedOccurrences = desired

        // 3. Arm the real alarms (awaited), then persist what ACTUALLY armed.
        //    On failure (e.g. authorization denied) `armedOccurrences` ends up
        //    short of `desired`, so every subsequent refresh takes the slow path
        //    and retries — the arm self-heals the moment permission is granted.
        item.armedOccurrences = await alarmKit.scheduleOccurrences(desired, for: item)

        // 4. Pre-alert heads-ups for the whole armed window, so occurrences the
        //    user hits without reopening the app still get their warning.
        if item.preAlert.isEnabled {
            await preAlerts.schedulePreAlerts(for: item, fireDates: desired, calendar: calendar)
        }
    }

    /// Authoritative read of the system's current alarm ids (nil = unreadable).
    func currentLiveAlarmIDs() -> Set<UUID>? { alarmKit.liveAlarmIDs() }

    /// Whether the system still holds every one of `occurrences` for `item`.
    /// `nil` liveAlarmIDs means we couldn't observe the real state, so we trust
    /// the persisted record and allow the no-op.
    private func systemStillHolds(_ occurrences: [Date], for item: AlarmItem, liveAlarmIDs: Set<UUID>?) -> Bool {
        guard let liveAlarmIDs else { return true }
        return occurrences.allSatisfy {
            liveAlarmIDs.contains(AlarmKitManager.occurrenceID(item: item.id, date: $0))
        }
    }

    /// Tear down all arming for an alarm (used on delete).
    func cancel(_ item: AlarmItem) async {
        await alarmKit.cancelOccurrences(item.armedOccurrences, for: item)
        item.armedOccurrences = []
        await preAlerts.cancelPreAlert(for: item)
    }
}
