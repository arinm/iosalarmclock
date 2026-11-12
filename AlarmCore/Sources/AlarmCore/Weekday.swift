import Foundation

/// A day of the week. Raw values intentionally match `Calendar`'s `weekday`
/// component for the Gregorian calendar (Sunday = 1 ... Saturday = 7) so we can
/// convert without a lookup table.
public enum Weekday: Int, CaseIterable, Codable, Sendable, Comparable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday

    public static func < (lhs: Weekday, rhs: Weekday) -> Bool { lhs.rawValue < rhs.rawValue }

    /// The weekday of a given date in the supplied calendar.
    public init(date: Date, calendar: Calendar) {
        let value = calendar.component(.weekday, from: date)
        self = Weekday(rawValue: value) ?? .sunday
    }

    /// Mon–Fri.
    public static let weekdays: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]
    /// Sat–Sun.
    public static let weekend: Set<Weekday> = [.saturday, .sunday]
}

