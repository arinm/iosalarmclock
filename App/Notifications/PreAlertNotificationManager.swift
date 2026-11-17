import Foundation
import OSLog
import UserNotifications
import AlarmCore

private let notificationLog = Logger(subsystem: "com.punctual.app", category: "HeadsUp")

/// Schedules the pre-alert ("heads-up") local notification that fires N minutes
/// before an alarm and carries the **Skip today** / **Open** actions.
///
/// This is the ONLY legitimate use of `UserNotifications` in the app — it is a
/// heads-up, never the alarm itself. The real alarm is AlarmKit.
@MainActor
final class PreAlertNotificationManager {

    static let categoryID = "PUNCTUAL_PRE_ALERT"
    static let skipActionID = "SKIP_TODAY"
    static let openActionID = "OPEN_ALARM"
    /// userInfo keys
    static let alarmIDKey = "alarmID"
    static let occurrenceKey = "occurrence" // epoch seconds of the alarm fire

    private let center = UNUserNotificationCenter.current()

    /// Register the actionable category. Call once at launch.
    func registerCategories() {
        let skip = UNNotificationAction(
            identifier: Self.skipActionID,
            title: String(localized: "Skip today", bundle: AppLanguage.bundle),
            options: [] // handled in background; no need to unlock
        )
        let open = UNNotificationAction(
            identifier: Self.openActionID,
            title: String(localized: "Open", bundle: AppLanguage.bundle),
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: Self.categoryID,
            actions: [skip, open],
            intentIdentifiers: [],
            options: []
        )
        // setNotificationCategories REPLACES the whole set, so every category
        // the app uses must be registered in this one call.
        center.setNotificationCategories(Set([category, WakeCheck.category] + CalendarSkipNotifier.categories))
    }

    /// Arm heads-ups for every alarm's armed window at once, so occurrences
    /// reached without reopening the app still get theirs, and remove every
    /// other pending heads-up (deleted or disabled alarms, skipped days).
    ///
    /// Budget: iOS keeps at most 64 pending local notifications app-wide, so
    /// all alarms share one allowance with the calendar notices and the
    /// "Are you up?" notice (see `HeadsUpPlanner`): the soonest heads-ups are set, the rest wait for a
    /// later sync. Only ARMED occurrences get one, so a heads-up never
    /// announces a ring the system doesn't hold. Run it after the calendar
    /// notices are synced, so their count is current.
    ///
    /// Returns when the first heads-up that didn't fit would have shown, or
    /// nil when they all fit (or notifications are off, so none is set).
    func sync(items: [AlarmItem], now: Date = .now, calendar: Calendar) async -> Date? {
        let byID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let alarms = items.filter { $0.isEnabled && $0.preAlert.isEnabled }.map {
            HeadsUpPlanner.Alarm(id: $0.id, occurrences: $0.armedOccurrences,
                                 minutesBefore: $0.preAlert.minutesBefore,
                                 extraMinutesBefore: $0.additionalPreAlertMinutes)
        }

        let pending = await center.pendingNotificationRequests()
        let ours = pending.filter { $0.identifier.hasPrefix(Self.prefix) }
        let calendarNotices = pending.filter { $0.identifier.hasPrefix(CalendarSkipNotifier.prefix) }.count
        let wakeChecks = pending.filter { $0.identifier.hasPrefix(WakeCheck.prefix) }.count
        let limit = HeadsUpPlanner.limit(calendarNotices: calendarNotices, wakeChecks: wakeChecks,
                                         others: pending.count - ours.count - calendarNotices - wakeChecks,
                                         calendarInUse: items.contains(where: \.autoSkipOnCalendarEvents),
                                         wakeCheckInUse: items.contains(where: \.wakeCheckEnabled))
        let plan = HeadsUpPlanner.plan(alarms, now: now, limit: limit)

        let keep = Set(plan.scheduled.map { requestID(alarmID: $0.alarmID, minutes: $0.minutesBefore, occurrence: $0.occurrence) })
        let stale = ours.map(\.identifier).filter { !keep.contains($0) }
        if !stale.isEmpty { center.removePendingNotificationRequests(withIdentifiers: stale) }
        // Only new or changed heads-ups are sent. Re-adding a pending id
        // replaces it, so an edited label or message still reaches the ones
        // already set; the unchanged rest (most of them, on every sync) cost
        // no round trip, and a skip or a toggle doesn't wait on them.
        let stamps = Dictionary(ours.compactMap { request in
            (request.content.userInfo[Self.stampKey] as? String).map { (request.identifier, $0) }
        }, uniquingKeysWith: { first, _ in first })
        for headsUp in plan.scheduled {
            guard let item = byID[headsUp.alarmID],
                  let request = makeRequest(for: item, fireDate: headsUp.occurrence,
                                            minutesBefore: headsUp.minutesBefore, calendar: calendar) else { continue }
            if let stamp = stamps[request.identifier], stamp == request.content.userInfo[Self.stampKey] as? String { continue }
            // Awaited, so the next sync counts what is really pending.
            do { try await center.add(request) } catch let error as UNError where error.code == .notificationsNotAllowed {
                // Notifications are off: nothing is set, so nothing waits either.
                return nil
            } catch {
                notificationLog.error("Heads-up add failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        if let first = plan.waiting.first {
            notificationLog.notice("Heads-ups: \(plan.scheduled.count, privacy: .public) set, \(plan.waiting.count, privacy: .public) waiting from \(first.fireDate, privacy: .public) (limit \(limit, privacy: .public))")
        }
        return plan.waiting.first?.fireDate
    }

    /// The request for one heads-up, or nil when its time has passed.
    private func makeRequest(for item: AlarmItem, fireDate: Date, minutesBefore: Int, calendar: Calendar) -> UNNotificationRequest? {
        let preAlertDate = fireDate.addingTimeInterval(-TimeInterval(minutesBefore * 60))
        guard preAlertDate > .now else { return nil } // skip if already in the past

        let timeString = TimeText.string(fireDate)
        let label = item.label.isEmpty ? String(localized: "Alarm", bundle: AppLanguage.bundle) : item.label

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Alarm in \(minutesBefore) minutes", bundle: AppLanguage.bundle, locale: AppLanguage.locale)
        // Pro custom message overrides the default body when set.
        if !item.preAlertMessage.isEmpty {
            content.body = item.preAlertMessage
        } else if TimeText.isHourOne(fireDate) {
            content.body = String(localized: "\(label) rings at \(timeString) (hour 1)", bundle: AppLanguage.bundle)
        } else {
            content.body = String(localized: "\(label) rings at \(timeString)", bundle: AppLanguage.bundle)
        }
        content.categoryIdentifier = Self.categoryID
        // Custom sound (Pro) lives in Library/Sounds; falls back to default.
        if let sound = item.soundName, !sound.isEmpty {
            content.sound = UNNotificationSound(named: UNNotificationSoundName(sound))
        } else {
            content.sound = .default
        }
        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: preAlertDate)
        // Everything the user would see or hear, and when (wall-clock, so a
        // new time zone re-sends it): `sync` re-sends a pending heads-up only
        // when this differs.
        let when = [comps.year, comps.month, comps.day, comps.hour, comps.minute, comps.second].map { String($0 ?? 0) }
        let stamp = ([content.title, content.body, item.soundName ?? ""] + when).joined(separator: "\u{1F}")
        content.userInfo = [
            Self.alarmIDKey: item.id.uuidString,
            Self.occurrenceKey: fireDate.timeIntervalSince1970,
            Self.stampKey: stamp
        ]

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        return UNNotificationRequest(
            identifier: requestID(alarmID: item.id, minutes: minutesBefore, occurrence: fireDate),
            content: content, trigger: trigger
        )
    }

    /// Immediate "Snoozed" confirmation so the user knows the snooze registered
    /// (AlarmKit shows no persistent surface while snoozing — matching the system
    /// Clock — so this notification is the visible acknowledgement). Silent: the
    /// user literally just silenced an alarm. Body states the snooze SETTING
    /// (always true) rather than a live countdown (we can't know the exact
    /// re-ring time from outside AlarmKit).
    func announceSnooze(for item: AlarmItem) {
        let label = item.label.isEmpty ? String(localized: "Alarm", bundle: AppLanguage.bundle) : item.label
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Snoozed", bundle: AppLanguage.bundle)
        content.body = String(localized: "\(label) - snoozed for \(item.snooze.durationMinutes) min. It'll ring again.", bundle: AppLanguage.bundle)
        content.sound = nil
        // Same id per alarm → a repeat snooze replaces the old note, no pile-up.
        center.add(UNNotificationRequest(identifier: "snoozed-\(item.id.uuidString)",
                                         content: content, trigger: nil))
    }

    /// Remove this alarm's heads-ups right away (disable, delete), ahead of
    /// the sync that follows.
    func cancelPreAlert(for item: AlarmItem) async {
        // Remove every pending pre-alert for this alarm regardless of offset.
        let prefix = "\(Self.prefix)\(item.id.uuidString)"
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
        if !ids.isEmpty { center.removePendingNotificationRequests(withIdentifiers: ids) }
    }

    private static let prefix = "prealert-"
    private static let stampKey = "stamp"

    /// Unique per (alarm, offset, occurrence) — the window arms several dates at
    /// the same offset, and identical ids would silently replace one another.
    /// Keeps the `prealert-<uuid>` prefix that `cancelPreAlert` matches on.
    private func requestID(alarmID: UUID, minutes: Int, occurrence: Date) -> String {
        "\(Self.prefix)\(alarmID.uuidString)-\(minutes)-\(Int(occurrence.timeIntervalSince1970))"
    }
}
