import Foundation

/// Formats the "Rings in 7h 42m" copy that is central to the product. Pure and
/// timezone-agnostic (operates on a time interval).
public enum CountdownFormatter {

    /// e.g. "7h 42m", "12h 18m", "3d 2h", "in under a minute".
    public static func string(until target: Date, from now: Date) -> String {
        let seconds = Int(target.timeIntervalSince(now))
        guard seconds > 0 else { return "now" }
        if seconds < 60 { return "under a minute" }

        let minutes = seconds / 60
        let days = minutes / (60 * 24)
        let hours = (minutes % (60 * 24)) / 60
        let mins = minutes % 60

        if days > 0 { return "\(days)d \(hours)h" }
        if hours > 0 { return "\(hours)h \(mins)m" }
        return "\(mins)m"
    }

    /// Full sentence used under the time picker and on the summary card.
    public static func ringsIn(_ target: Date, from now: Date) -> String {
        "Rings in \(string(until: target, from: now))"
    }
}
