import Foundation

/// A calendar day with no time component — the unit we use for skip dates,
/// pause ranges and one-time alarm dates. Storing day-granularity avoids the
/// timezone/DST pitfalls of comparing raw `Date`s for "is this the same day".
public struct DateOnly: Codable, Hashable, Comparable, Sendable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year; self.month = month; self.day = day
    }

    /// The calendar day that `date` falls on, in the supplied calendar's timezone.
    public init(date: Date, calendar: Calendar) {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: c.year ?? 0, month: c.month ?? 0, day: c.day ?? 0)
    }

    /// Midnight at the start of this day in the supplied calendar.
    public func startOfDay(in calendar: Calendar) -> Date? {
        calendar.date(from: DateComponents(year: year, month: month, day: day))
    }

    /// This day combined with a wall-clock hour/minute. Returns `nil` only for
    /// impossible components. DST gaps are resolved by `Calendar` itself.
    public func date(hour: Int, minute: Int, in calendar: Calendar) -> Date? {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))
    }

    public static func < (lhs: DateOnly, rhs: DateOnly) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    public var description: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }
}
