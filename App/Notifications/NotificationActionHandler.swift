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

    // Show pre-alert banners even while the app is in the foreground.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let info = response.notification.request.content.userInfo
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
                     title: "Skipped \(Self.dayPhrase(day, calendar: calendar)) — still active",
                     subtitle: "Next alarm: \(next)",
                     undo: { [store] in await store.unskip(alarm, day: day) })
    }

    /// "today" / "tomorrow" / weekday name for friendly, accurate copy.
    static func dayPhrase(_ day: DateOnly, calendar: Calendar) -> String {
        guard let date = day.startOfDay(in: calendar) else { return "today" }
        if calendar.isDateInToday(date) { return "today" }
        if calendar.isDateInTomorrow(date) { return "tomorrow" }
        let f = DateFormatter(); f.calendar = calendar; f.dateFormat = "EEEE"
        return f.string(from: date)
    }

    static func describe(_ date: Date?, calendar: Calendar) -> String {
        guard let date else { return "No further alarms" }
        let f = DateFormatter()
        f.calendar = calendar
        f.doesRelativeDateFormatting = true
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }
}
