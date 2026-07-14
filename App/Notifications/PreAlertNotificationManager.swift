import Foundation
import UserNotifications
import AlarmCore

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
            title: "Skip today",
            options: [] // handled in background; no need to unlock
        )
        let open = UNNotificationAction(
            identifier: Self.openActionID,
            title: "Open",
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: Self.categoryID,
            actions: [skip, open],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([category])
    }

    /// Arm pre-alerts for the whole look-ahead window, so occurrences reached
    /// without reopening the app still get their heads-up.
    ///
    /// Budget: iOS keeps at most 64 pending local notifications app-wide, so we
    /// spend carefully — every offset (main + Pro extras) for the FIRST
    /// occurrence, main offset only for the rest. A 7-deep window costs ~7-10
    /// requests per alarm instead of up to 28.
    func schedulePreAlerts(for item: AlarmItem, fireDates: [Date], calendar: Calendar) async {
        await cancelPreAlert(for: item) // fully await cancel so it can't remove the new requests
        guard item.preAlert.isEnabled, let first = fireDates.first else { return }

        // Main offset + any Pro "additional" offsets, de-duplicated & sorted.
        let offsets = Set([item.preAlert.minutesBefore] + item.additionalPreAlertMinutes).sorted(by: >)
        for minutes in offsets {
            scheduleOne(for: item, fireDate: first, minutesBefore: minutes, calendar: calendar)
        }
        for fireDate in fireDates.dropFirst() {
            scheduleOne(for: item, fireDate: fireDate, minutesBefore: item.preAlert.minutesBefore, calendar: calendar)
        }
    }

    private func scheduleOne(for item: AlarmItem, fireDate: Date, minutesBefore: Int, calendar: Calendar) {
        let preAlertDate = fireDate.addingTimeInterval(-TimeInterval(minutesBefore * 60))
        guard preAlertDate > .now else { return } // skip if already in the past

        let timeString = Self.timeFormatter.string(from: fireDate)
        let label = item.label.isEmpty ? "Alarm" : item.label

        let content = UNMutableNotificationContent()
        content.title = "Alarm in \(minutesBefore) minutes"
        // Pro custom message overrides the default body when set.
        content.body = item.preAlertMessage.isEmpty
            ? "\(label) rings at \(timeString)"
            : item.preAlertMessage
        content.categoryIdentifier = Self.categoryID
        // Custom sound (Pro) lives in Library/Sounds; falls back to default.
        if let sound = item.soundName, !sound.isEmpty {
            content.sound = UNNotificationSound(named: UNNotificationSoundName(sound))
        } else {
            content.sound = .default
        }
        content.userInfo = [
            Self.alarmIDKey: item.id.uuidString,
            Self.occurrenceKey: fireDate.timeIntervalSince1970
        ]

        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: preAlertDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(
            identifier: requestID(for: item, minutes: minutesBefore, occurrence: fireDate),
            content: content, trigger: trigger
        )
        center.add(request)
    }

    /// Immediate "Snoozed" confirmation so the user knows the snooze registered
    /// (AlarmKit shows no persistent surface while snoozing — matching the system
    /// Clock — so this notification is the visible acknowledgement). Silent: the
    /// user literally just silenced an alarm. Body states the snooze SETTING
    /// (always true) rather than a live countdown (we can't know the exact
    /// re-ring time from outside AlarmKit).
    func announceSnooze(for item: AlarmItem) {
        let label = item.label.isEmpty ? "Alarm" : item.label
        let content = UNMutableNotificationContent()
        content.title = "Snoozed"
        content.body = "\(label) — snoozed for \(item.snooze.durationMinutes) min. It'll ring again."
        content.sound = nil
        // Same id per alarm → a repeat snooze replaces the old note, no pile-up.
        center.add(UNNotificationRequest(identifier: "snoozed-\(item.id.uuidString)",
                                         content: content, trigger: nil))
    }

    func cancelPreAlert(for item: AlarmItem) async {
        // Remove every pending pre-alert for this alarm regardless of offset.
        // Awaited so it fully completes before any re-schedule adds new requests.
        let prefix = "prealert-\(item.id.uuidString)"
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
        if !ids.isEmpty { center.removePendingNotificationRequests(withIdentifiers: ids) }
    }

    /// Unique per (alarm, offset, occurrence) — the window arms several dates at
    /// the same offset, and identical ids would silently replace one another.
    /// Keeps the `prealert-<uuid>` prefix that `cancelPreAlert` matches on.
    private func requestID(for item: AlarmItem, minutes: Int, occurrence: Date) -> String {
        "prealert-\(item.id.uuidString)-\(minutes)-\(Int(occurrence.timeIntervalSince1970))"
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }()
}
