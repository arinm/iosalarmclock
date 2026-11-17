import Foundation
import OSLog
import UserNotifications

/// "Are you up?" (Pro): after the final Stop of a ring, a quiet check-in at
/// +5 min and one Stop-only alarm at +7 min, unless the user taps I'm up.
/// This is the timing and the notice; the alarm half is
/// `AlarmStore.startWakeCheck`, run by `WakeCheckIntent`.
///
/// It fails quiet: when anything is refused there is no check, never an
/// extra ring.
enum WakeCheck {
    /// The quiet notice, after Stop.
    static let noticeAfter: TimeInterval = 5 * 60
    /// The ring, after Stop: two minutes to answer the notice.
    static let ringAfter: TimeInterval = 7 * 60

    static let categoryID = "PUNCTUAL_WAKE_CHECK"
    static let imUpActionID = "WAKE_CHECK_IM_UP"
    /// Request ids start with this, so the heads-up budget can count them.
    static let prefix = "wakecheck-"

    /// Console.app: subsystem "com.punctual.app", category "WakeCheck".
    static let log = Logger(subsystem: "com.punctual.app", category: "WakeCheck")

    static var category: UNNotificationCategory {
        // Handled in the background: the tap is the answer, no unlock needed.
        let imUp = UNNotificationAction(identifier: imUpActionID, title: String(localized: "I'm up", bundle: AppLanguage.bundle), options: [])
        return UNNotificationCategory(identifier: categoryID, actions: [imUp], intentIdentifiers: [], options: [])
    }

    /// The notice for one check. Silent: the ring two minutes later is the
    /// loud part, and someone already up shouldn't be startled.
    static func postNotice(checkID: UUID, at date: Date, ringsAt: Date) async {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Are you up?", bundle: AppLanguage.bundle)
        let time = TimeText.string(ringsAt)
        content.body = TimeText.isHourOne(ringsAt)
            ? String(localized: "Tap I'm up, or the alarm rings again at \(time). (hour 1)", bundle: AppLanguage.bundle)
            : String(localized: "Tap I'm up, or the alarm rings again at \(time).", bundle: AppLanguage.bundle)
        content.categoryIdentifier = categoryID
        content.sound = nil
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, date.timeIntervalSinceNow), repeats: false)
        let request = UNNotificationRequest(identifier: prefix + checkID.uuidString, content: content, trigger: trigger)
        do {
            try await UNUserNotificationCenter.current().add(request)
            log.notice("Notice set @ \(date, privacy: .public)")
        } catch {
            // Notifications off: the ring still comes, and the in-app card can cancel it.
            log.error("Notice not set: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Pending or already shown, the notice goes.
    static func removeNotice(checkID: UUID) {
        let ids = [prefix + checkID.uuidString]
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }
}
