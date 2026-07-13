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
        /// True once the shown occurrence has been skipped (UI flips to confirmation).
        var skippedToday: Bool
        /// Resolved relative day of the shown occurrence ("today", "tomorrow",
        /// "Friday") so the Skip button never says "today" for a tomorrow alarm.
        var dayPhrase: String

        init(fireDate: Date, label: String, skippedToday: Bool, dayPhrase: String = "today") {
            self.fireDate = fireDate
            self.label = label
            self.skippedToday = skippedToday
            self.dayPhrase = dayPhrase
        }

        /// Custom decode: synthesized `Decodable` ignores property defaults, so a
        /// state payload written by an older build (no `dayPhrase` key) would
        /// throw `keyNotFound` — leaving that Live Activity impossible to render,
        /// update, or even end after an app update. Tolerate the missing key.
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            fireDate = try c.decode(Date.self, forKey: .fireDate)
            label = try c.decode(String.self, forKey: .label)
            skippedToday = try c.decode(Bool.self, forKey: .skippedToday)
            dayPhrase = try c.decodeIfPresent(String.self, forKey: .dayPhrase) ?? "today"
        }
    }

    /// Stable id so we can find & update/end the right activity, and so the
    /// Skip Today button knows which alarm to act on.
    var alarmID: String
}
