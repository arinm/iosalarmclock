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

    /// Short label used on day pills, e.g. "Mon".
    public var shortLabel: String {
        switch self {
        case .sunday: "Sun"; case .monday: "Mon"; case .tuesday: "Tue"
        case .wednesday: "Wed"; case .thursday: "Thu"; case .friday: "Fri"
        case .saturday: "Sat"
        }
    }

    /// Single-letter label, e.g. "M".
    public var minimalLabel: String { String(shortLabel.prefix(1)) }
}

public extension Set where Element == Weekday {
    /// Human summary for a set of repeat days: "Every day", "Weekdays",
    /// "Weekends", "Mon Wed Fri", or "Once".
    var humanSummary: String {
        if isEmpty { return "Once" }
        if count == 7 { return "Every day" }
        if self == Weekday.weekdays { return "Weekdays" }
        if self == Weekday.weekend { return "Weekends" }
        return Weekday.allCases.filter { contains($0) }.map(\.shortLabel).joined(separator: " ")
    }
}
