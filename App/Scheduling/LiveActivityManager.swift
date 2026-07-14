import Foundation
import ActivityKit
import AlarmCore

/// Starts / updates / ends the "next alarm" Live Activity for the soonest
/// upcoming alarm. Shown only once an alarm is within `windowHours` — kept
/// short so the Lock Screen surface appears when it's genuinely imminent
/// (a countdown to tonight's 7:00 shown since noon is noise, not signal).
/// ActivityKit's own cap is ~8h; this is a product choice within that.
@MainActor
final class LiveActivityManager {
    private let windowHours: Double = 1
    /// Guards against overlapping reconciles (refresh fires on every foreground),
    /// which could otherwise request two activities for the same alarm.
    private var isReconciling = false

    /// Reconcile live activities with the soonest alarm. Pass `nil` if there is
    /// no upcoming alarm.
    func refresh(soonest: (id: UUID, fireDate: Date, label: String, skippedToday: Bool, dayPhrase: String)?) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled, !isReconciling else { return }
        isReconciling = true

        Task {
            defer { isReconciling = false }

            let now = Date.now
            let inWindow = soonest.map { $0.fireDate > now && $0.fireDate.timeIntervalSince(now) <= windowHours * 3600 } ?? false

            // End (awaited) any activity that no longer matches the target.
            for activity in Activity<PunctualActivityAttributes>.activities where
                !(inWindow && activity.attributes.alarmID == soonest?.id.uuidString) {
                await activity.end(nil, dismissalPolicy: .immediate)
            }

            guard inWindow, let soonest else { return }

            let state = PunctualActivityAttributes.ContentState(
                fireDate: soonest.fireDate, label: soonest.label,
                skippedToday: soonest.skippedToday, dayPhrase: soonest.dayPhrase
            )
            let content = ActivityContent(state: state, staleDate: soonest.fireDate)

            // Re-read after the awaited ends, then update or request exactly one.
            if let existing = Activity<PunctualActivityAttributes>.activities
                .first(where: { $0.attributes.alarmID == soonest.id.uuidString }) {
                await existing.update(content)
            } else {
                let attributes = PunctualActivityAttributes(alarmID: soonest.id.uuidString)
                _ = try? Activity.request(attributes: attributes, content: content, pushType: nil)
            }
        }
    }
}
