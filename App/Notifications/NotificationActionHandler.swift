import Foundation
import UserNotifications
import SwiftData
import AlarmCore

/// Receives notification responses (foreground delegate) and applies the
/// **Skip today** action — the most important interaction in the app.
///
/// Skip today =
///   • add the imminent occurrence's day to `skippedOccurrenceDates`
///   • keep the alarm enabled
///   • cancel the armed real alarm for today and re-arm the next valid one
///   • surface a confirmation so the UI can say "Skipped today, still active".
@MainActor
final class NotificationActionHandler: NSObject, @preconcurrency UNUserNotificationCenterDelegate {

    private let store: AlarmStore
    private let banners: BannerCenter
    private let calendar: Calendar

    init(store: AlarmStore, banners: BannerCenter, calendar: Calendar = .current) {
        self.store = store
        self.banners = banners
        self.calendar = calendar
    }

    // Show pre-alert banners even while the app is in the foreground. A quiet
    // correction of a calendar notice (passive) goes only to the list.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        notification.request.content.interruptionLevel == .passive ? [.list] : [.banner, .sound, .list]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let info = response.notification.request.content.userInfo
        // A calendar-skip notice can cover several alarms, so it carries a list
        // of ids rather than the single one the heads-up uses.
        if response.actionIdentifier == CalendarSkipNotifier.ringAnywayActionID {
            await applyRingAnyway(info: info)
            return
        }
        guard
            let idString = info[PreAlertNotificationManager.alarmIDKey] as? String,
            let id = UUID(uuidString: idString),
            let alarm = store.alarm(with: id)
        else { return }

        switch response.actionIdentifier {
        case PreAlertNotificationManager.skipActionID:
            await applySkipToday(to: alarm, info: info)
        default:
            break // "Open"/default tap simply launches the app onto the alarm
        }
    }

    private func applySkipToday(to alarm: AlarmItem, info: [AnyHashable: Any]) async {
        // Resolve the occurrence the pre-alert was for so we skip the right day,
        // even if "now" has drifted slightly.
        let occurrenceDate: Date
        if let epoch = info[PreAlertNotificationManager.occurrenceKey] as? TimeInterval {
            occurrenceDate = Date(timeIntervalSince1970: epoch)
        } else {
            occurrenceDate = alarm.nextOccurrence ?? .now
        }
        let day = DateOnly(date: occurrenceDate, calendar: calendar)

        await store.update(alarm) {
            if !$0.skippedOccurrenceDates.contains(day) {
                $0.skippedOccurrenceDates.append(day)
            }
        }
        // store.update already re-armed via the scheduler; report the new next.
        let next = Self.describe(alarm.nextOccurrence, calendar: calendar)
        banners.show(.skip,
                     title: Self.skippedTitle(day, calendar: calendar),
                     subtitle: String(localized: "Next alarm: \(next)"),
                     alarmID: alarm.id,
                     undo: { [store] in await store.unskip(alarm, day: day) })
    }

    /// "Ring anyway" on a calendar-skip notice: the calendar said day off, the
    /// user says they need the alarm. Re-arms that ring right away.
    /// It applies to every alarm the notice listed ("Tomorrow, 2 alarms won't ring").
    private func applyRingAnyway(info: [AnyHashable: Any]) async {
        guard let day = CalendarSkipNotifier.day(from: info) else { return }
        let alarms = CalendarSkipNotifier.alarmIDs(from: info).compactMap { store.alarm(with: $0) }
        guard !alarms.isEmpty else { return }
        for alarm in alarms { await store.ringAnyway(alarm, day: day) }
        let phrase = Self.dayPhrase(day, calendar: calendar)
        banners.show(.neutral,
                     title: alarms.count == 1
                        ? String(localized: "Will ring \(phrase)")
                        : String(localized: "\(alarms.count) alarms will ring \(phrase)"),
                     subtitle: alarms.count == 1
                        ? Self.describe(day.date(hour: alarms[0].hour, minute: alarms[0].minute, in: calendar), calendar: calendar)
                        : nil,
                     alarmID: alarms.count == 1 ? alarms[0].id : nil,
                     undo: { [store] in for alarm in alarms { await store.skipForCalendarAgain(alarm, day: day) } })
    }

    #if DEBUG
    /// QA: run the same code the notification's Ring anyway button runs.
    func qaRingAnyway(info: [AnyHashable: Any]) async { await applyRingAnyway(info: info) }
    #endif

    /// "today" / "tomorrow" / weekday name for friendly, accurate copy.
    static func dayPhrase(_ day: DateOnly, calendar: Calendar) -> String {
        guard let date = day.startOfDay(in: calendar) else { return String(localized: "today") }
        return DayText.phrase(date, calendar: calendar)
    }

    /// The confirmation every skip surface shows: "Skipped today - still active".
    static func skippedTitle(_ day: DateOnly, calendar: Calendar = .current) -> String {
        String(localized: "Skipped \(dayPhrase(day, calendar: calendar)) - still active")
    }

    static func describe(_ date: Date?, calendar: Calendar) -> String {
        guard let date else { return String(localized: "No further alarms") }
        let f = DateFormatter()
        f.calendar = calendar
        f.doesRelativeDateFormatting = true
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }
}
