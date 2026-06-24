import Foundation
import ActivityKit
import AlarmCore

/// Starts / updates / ends the "next alarm" Live Activity for the soonest
/// upcoming alarm. ActivityKit caps a running activity at ~8h, so we only show
/// it once an alarm is within `windowHours` — which is also exactly when a
/// Lock Screen countdown is most useful.
@MainActor
final class LiveActivityManager {
    private let windowHours: Double = 8
    /// Guards against overlapping reconciles (refresh fires on every foreground),
    /// which could otherwise request two activities for the same alarm.
    private var isReconciling = false

    /// Reconcile live activities with the soonest alarm. Pass `nil` if there is
    /// no upcoming alarm.
    func refresh(soonest: (id: UUID, fireDate: Date, label: String, skippedToday: Bool)?) {
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
                fireDate: soonest.fireDate, label: soonest.label, skippedToday: soonest.skippedToday
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
