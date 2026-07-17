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

            // End (awaited) any LIVE activity that no longer matches the target.
            // ENDED activities are deliberately left alone: the skip intent ends
            // one with a "Today skipped — still active" farewell state and its
            // own dismissal policy — ending it again here would yank that card
            // off the Lock Screen instantly.
            for activity in Activity<PunctualActivityAttributes>.activities where
                activity.activityState == .active
                && !(inWindow && activity.attributes.alarmID == soonest?.id.uuidString) {
                await activity.end(nil, dismissalPolicy: .immediate)
            }

            guard inWindow, let soonest else { return }

            let state = PunctualActivityAttributes.ContentState(
                fireDate: soonest.fireDate, label: soonest.label,
                skippedToday: soonest.skippedToday, dayPhrase: soonest.dayPhrase
            )
            let content = ActivityContent(state: state, staleDate: soonest.fireDate)

            // Re-read after the awaited ends, then update or request exactly one.
            // Only a LIVE activity can be updated — updating an ended one is a
            // silent no-op (the Undo-after-skip trap: the alarm is imminent
            // again but the farewell card can't be revived).
            if let existing = Activity<PunctualActivityAttributes>.activities
                .first(where: { $0.activityState == .active && $0.attributes.alarmID == soonest.id.uuidString }) {
                await existing.update(content)
            } else {
                // Clear any lingering ENDED card for this alarm first (e.g. the
                // user skipped, then hit Undo inside the farewell window) so two
                // cards never stack.
                for ended in Activity<PunctualActivityAttributes>.activities where
                    ended.attributes.alarmID == soonest.id.uuidString && ended.activityState != .active {
                    await ended.end(nil, dismissalPolicy: .immediate)
                }
                let attributes = PunctualActivityAttributes(alarmID: soonest.id.uuidString)
                _ = try? Activity.request(attributes: attributes, content: content, pushType: nil)
            }
        }
    }
}
