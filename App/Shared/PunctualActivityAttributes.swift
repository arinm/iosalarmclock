import Foundation
import ActivityKit

/// Live Activity payload for the "next alarm" countdown shown on the Lock Screen
/// and Dynamic Island. Shared between the app (which starts/updates/ends the
/// activity) and the widget extension (which renders it).
struct PunctualActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// When the alarm will ring; the UI renders a live countdown to this.
        var fireDate: Date
        var label: String
        /// True once today's occurrence has been skipped (UI flips to confirmation).
        var skippedToday: Bool
    }

    /// Stable id so we can find & update/end the right activity, and so the
    /// Skip Today button knows which alarm to act on.
    var alarmID: String
}
