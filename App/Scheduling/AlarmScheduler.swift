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

    /// How long a just-fired occurrence may still be alive as a running snooze in
    /// AlarmKit (native snooze can be repeated). We remember fired occurrences for
    /// this window so disable/delete can cancel a pending snooze even after the
    /// occurrence has dropped out of `armedOccurrences`. Cancelling a stale/stopped
    /// id is a harmless no-op, so we err generous.
    private let snoozeTrackingWindow: TimeInterval = 12 * 3600

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

        // Remember occurrences that just fired (dropped out of the window into the
        // recent past). AlarmKit re-alerts a snoozed occurrence under its own id,
        // which is no longer in `armedOccurrences` after this refresh — so without
        // this record, disabling/deleting the alarm couldn't cancel the pending
        // snooze and it would ring anyway. Only meaningful while snooze is on.
        if item.snooze.isEnabled {
            let horizon = now.addingTimeInterval(-snoozeTrackingWindow)
            let justFired = item.armedOccurrences.filter { $0 <= now && $0 > horizon }
            item.recentlyFiredOccurrences = Array(Set(item.recentlyFiredOccurrences + justFired))
                .filter { $0 > horizon }
        } else if !item.recentlyFiredOccurrences.isEmpty {
            // Snooze was just turned OFF while an occurrence may still be
            // snoozing — cancel it before dropping the record, or the pending
            // re-ring survives as an orphan we can no longer target.
            await alarmKit.cancelOccurrences(item.recentlyFiredOccurrences, for: item)
            item.recentlyFiredOccurrences = []
        }

        // 1. Cancel what is armed. While the alarm STAYS enabled, only cancel
        //    still-future occurrences — a passive resync (foreground/observer)
        //    must never silence an occurrence that's alerting or snoozing right
        //    now just because its fire date has passed. But when the user is
        //    explicitly DISABLING the alarm, that protection must not apply: an
        //    alarm currently snoozing (fire date already in the past) also needs
        //    to be cancelled — including the fired occurrence we tracked above —
        //    or turning it off in the app does nothing and it rings again.
        let toCancel = item.isEnabled
            ? item.armedOccurrences.filter { $0 > now }
            : item.armedOccurrences + item.recentlyFiredOccurrences
        await alarmKit.cancelOccurrences(toCancel, for: item)
        await preAlerts.cancelPreAlert(for: item)

        guard item.isEnabled, let first = desired.first else {
            item.armedOccurrences = []
            item.recentlyFiredOccurrences = []
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

    /// Post the "Snoozed" confirmation notification for an item (see
    /// PreAlertNotificationManager.announceSnooze).
    func announceSnooze(for item: AlarmItem) { preAlerts.announceSnooze(for: item) }

    /// Cancel ONLY the running snooze (the recently fired occurrence AlarmKit is
    /// counting down to re-ring) without touching the future window — the alarm
    /// stays armed for its next occurrence. "Stop today, keep tomorrow."
    ///
    /// Cancels the SAME set the snooze detection matches on (recentlyFired +
    /// already-past armed): right after a fire, the post-fire refresh may not
    /// have captured the occurrence into `recentlyFiredOccurrences` yet — it's
    /// still sitting in `armedOccurrences` with a past date. Cancelling only
    /// `recentlyFired` in that window would silently no-op while the UI says
    /// "Snooze stopped". Future occurrences stay untouched.
    func cancelRunningSnooze(_ item: AlarmItem, now: Date = .now) async {
        let pastArmed = item.armedOccurrences.filter { $0 <= now }
        await alarmKit.cancelOccurrences(item.recentlyFiredOccurrences + pastArmed, for: item)
        item.recentlyFiredOccurrences = []
    }

    /// Whether the system still holds every one of `occurrences` for `item`.
    /// `nil` liveAlarmIDs means we couldn't observe the real state, so we trust
    /// the persisted record and allow the no-op.
    private func systemStillHolds(_ occurrences: [Date], for item: AlarmItem, liveAlarmIDs: Set<UUID>?) -> Bool {
        guard let liveAlarmIDs else { return true }
        return occurrences.allSatisfy {
            liveAlarmIDs.contains(AlarmKitManager.occurrenceID(item: item.id, date: $0))
        }
    }

    /// Tear down all arming for an alarm (used on delete). Includes any recently
    /// fired occurrence that may still be snoozing, so deleting a snoozing alarm
    /// actually silences it.
    func cancel(_ item: AlarmItem) async {
        await alarmKit.cancelOccurrences(item.armedOccurrences + item.recentlyFiredOccurrences, for: item)
        item.armedOccurrences = []
        item.recentlyFiredOccurrences = []
        await preAlerts.cancelPreAlert(for: item)
    }
}
