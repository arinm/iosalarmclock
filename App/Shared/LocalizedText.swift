import Foundation
import AlarmCore

// User-facing words for days, weekdays, times and countdowns, in the app's
// language. Compiled into both the app and the widget extension: each target
// has its own string catalog, and `Locale.current` already follows the
// language the bundle runs in (English or Japanese), so dates format to match.

/// "today" / "tomorrow" / "Monday", and short dates.
enum DayText {
    /// Lowercase, for the middle of a sentence: "Skip today", "Skip Monday".
    static func phrase(_ date: Date, calendar: Calendar = .current) -> String {
        if calendar.isDateInToday(date) { return String(localized: "today") }
        if calendar.isDateInTomorrow(date) { return String(localized: "tomorrow") }
        return weekdayName(date, calendar: calendar)
    }

    /// Capitalized, for the start of a line: "Today", "Tomorrow", "Monday".
    static func title(_ date: Date, calendar: Calendar = .current) -> String {
        if calendar.isDateInToday(date) { return String(localized: "Today") }
        if calendar.isDateInTomorrow(date) { return String(localized: "Tomorrow") }
        return weekdayName(date, calendar: calendar)
    }

    /// "Monday" / "月曜日".
    static func weekdayName(_ date: Date, calendar: Calendar = .current) -> String {
        let f = DateFormatter()
        f.calendar = calendar
        f.setLocalizedDateFormatFromTemplate("EEEE")
        return f.string(from: date)
    }

    /// "Mon, Jun 24" (en_US) / "Mon 24 Jun" (en_GB) / "6月24日(月)": the region's order.
    static func short(_ date: Date, calendar: Calendar = .current) -> String {
        let f = DateFormatter()
        f.calendar = calendar
        f.setLocalizedDateFormatFromTemplate("EEEdMMM")
        return f.string(from: date)
    }

    static func short(_ day: DateOnly, calendar: Calendar = .current) -> String {
        guard let date = day.startOfDay(in: calendar) else { return day.description }
        return short(date, calendar: calendar)
    }
}

/// An alarm's clock time in the user's 12/24-hour style: "6:30 AM", "06:30",
/// "午前6:30", "6:30".
enum TimeText {
    static func string(hour: Int, minute: Int, calendar: Calendar = .current) -> String {
        let date = calendar.date(from: DateComponents(hour: hour, minute: minute)) ?? .now
        return string(date)
    }

    static func string(_ date: Date) -> String {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("jmm")
        return f.string(from: date)
    }

    /// The time and its AM/PM marker apart, so the marker can be drawn smaller.
    /// `periodFirst` is true where the marker leads ("午前6:30").
    static func parts(_ date: Date) -> (time: String, period: String?, periodFirst: Bool) {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("jmm")
        let full = f.string(from: date)
        let period = Calendar.current.component(.hour, from: date) < 12 ? f.amSymbol : f.pmSymbol
        guard let period, !period.isEmpty, let range = full.range(of: period) else {
            return (full, nil, false)
        }
        let time = full.replacingCharacters(in: range, with: "").trimmingCharacters(in: .whitespaces)
        return (time, period, range.lowerBound == full.startIndex)
    }
}

/// The "Rings in 7h 42m" copy that is central to the product.
enum CountdownText {
    /// "7h 42m", "3d 2h", "under a minute" / "7時間42分", "3日2時間", "1分未満".
    static func string(until target: Date, from now: Date) -> String {
        let seconds = Int(target.timeIntervalSince(now))
        guard seconds > 0 else { return String(localized: "now", comment: "Countdown once the alarm time is reached") }
        if seconds < 60 { return String(localized: "under a minute") }

        let minutes = seconds / 60
        let days = minutes / (60 * 24)
        let hours = (minutes % (60 * 24)) / 60
        let mins = minutes % 60

        if days > 0 { return String(localized: "\(days)d \(hours)h", comment: "Countdown: days and hours") }
        if hours > 0 { return String(localized: "\(hours)h \(mins)m", comment: "Countdown: hours and minutes") }
        return String(localized: "\(mins)m", comment: "Minutes, short")
    }

    /// Full sentence used under the time picker, on the cards and the widget.
    static func ringsIn(_ target: Date, from now: Date) -> String {
        let seconds = Int(target.timeIntervalSince(now))
        if seconds <= 0 { return String(localized: "Rings in now") }
        if seconds < 60 { return String(localized: "Rings in under a minute") }
        return String(localized: "Rings in \(string(until: target, from: now))", comment: "Argument is a countdown such as 7h 42m")
    }
}

extension Weekday {
    /// "Mon" / "月".
    var shortLabel: String { Calendar.current.shortWeekdaySymbols[rawValue - 1] }
    /// "M" / "月", used on the day pills.
    var minimalLabel: String { Calendar.current.veryShortWeekdaySymbols[rawValue - 1] }
}

extension Set where Element == Weekday {
    /// "Every day" (all seven or empty: the engine treats an empty set as
    /// daily), "Weekdays", "Weekends", or "Mon Wed Fri".
    var humanSummary: String {
        if isEmpty || count == 7 { return String(localized: "Every day") }
        if self == Weekday.weekdays { return String(localized: "Weekdays") }
        if self == Weekday.weekend { return String(localized: "Weekends") }
        return Weekday.allCases.filter { contains($0) }.map(\.shortLabel).joined(separator: " ")
    }
}
