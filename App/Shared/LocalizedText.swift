import Foundation
import AlarmCore

// User-facing words for days, weekdays, times and countdowns, in the app's
// language. Compiled into both the app and the widget extension: each target
// has its own string catalog. Words come from `AppLanguage.bundle` and dates
// format with `AppLanguage.locale`, so both follow a language picked in
// Settings at once, not from the next launch only.

/// "today" / "tomorrow" / "Monday", and short dates.
enum DayText {
    /// Lowercase, for the middle of a sentence: "Skip today", "Skip Monday"
    /// (de "am Montag", es "el lunes": the form that follows a verb).
    static func phrase(_ date: Date, calendar: Calendar = .current) -> String {
        if calendar.isDateInToday(date) { return String(localized: "today", bundle: AppLanguage.bundle) }
        if calendar.isDateInTomorrow(date) { return String(localized: "tomorrow", bundle: AppLanguage.bundle) }
        return onWeekday(date, calendar: calendar)
    }

    /// Capitalized, for the start of a line: "Today", "Tomorrow", "Monday".
    static func title(_ date: Date, calendar: Calendar = .current) -> String {
        if calendar.isDateInToday(date) { return String(localized: "Today", bundle: AppLanguage.bundle) }
        if calendar.isDateInTomorrow(date) { return String(localized: "Tomorrow", bundle: AppLanguage.bundle) }
        return weekdayName(date, calendar: calendar, context: .beginningOfSentence)
    }

    /// "Monday" / "月曜日". Pass `.beginningOfSentence` at the start of a line:
    /// languages that write weekdays in lowercase get "Lundi", not "lundi".
    static func weekdayName(_ date: Date, calendar: Calendar = .current,
                            context: Formatter.Context = .unknown) -> String {
        let f = DateFormatter()
        f.locale = AppLanguage.locale
        f.calendar = calendar
        f.formattingContext = context
        f.setLocalizedDateFormatFromTemplate("EEEE")
        return f.string(from: date)
    }

    /// One key per day, because the article can change with the day
    /// (pt "no domingo" / "na segunda-feira"). English shows the bare name.
    private static func onWeekday(_ date: Date, calendar: Calendar) -> String {
        switch calendar.component(.weekday, from: date) {
        case 1: String(localized: "on Sunday", bundle: AppLanguage.bundle)
        case 2: String(localized: "on Monday", bundle: AppLanguage.bundle)
        case 3: String(localized: "on Tuesday", bundle: AppLanguage.bundle)
        case 4: String(localized: "on Wednesday", bundle: AppLanguage.bundle)
        case 5: String(localized: "on Thursday", bundle: AppLanguage.bundle)
        case 6: String(localized: "on Friday", bundle: AppLanguage.bundle)
        default: String(localized: "on Saturday", bundle: AppLanguage.bundle)
        }
    }

    /// "Mon, Jun 24" (en_US) / "Mon 24 Jun" (en_GB) / "6月24日(月)": the region's order.
    static func short(_ date: Date, calendar: Calendar = .current) -> String {
        let f = DateFormatter()
        f.locale = AppLanguage.locale
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
        f.locale = AppLanguage.locale
        f.setLocalizedDateFormatFromTemplate("jmm")
        return f.string(from: date)
    }

    /// True when the clock shows hour 1: 1:05 AM or PM on a 12-hour clock,
    /// 01:05 on a 24-hour one. Spanish and Portuguese say "a la 1:05" / "à 1:05"
    /// but "a las 6:30" / "às 6:30", so each sentence that puts a time after
    /// "at" has an "(hour 1)" twin key; the other languages give both the same text.
    /// Digits of any script count ("١ م" is hour 1 too).
    static func isHourOne(_ date: Date) -> Bool {
        let f = DateFormatter()
        f.locale = AppLanguage.locale
        f.setLocalizedDateFormatFromTemplate("j")
        return f.string(from: date).compactMap(\.wholeNumberValue).reduce(0) { $0 * 10 + $1 } == 1
    }

    /// The time and its AM/PM marker apart, so the marker can be drawn smaller.
    /// `periodFirst` is true where the marker leads ("午前6:30").
    static func parts(_ date: Date) -> (time: String, period: String?, periodFirst: Bool) {
        let f = DateFormatter()
        f.locale = AppLanguage.locale
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
        guard seconds > 0 else { return String(localized: "now", bundle: AppLanguage.bundle, comment: "Countdown once the alarm time is reached") }
        if seconds < 60 { return String(localized: "under a minute", bundle: AppLanguage.bundle) }

        let minutes = seconds / 60
        let days = minutes / (60 * 24)
        let hours = (minutes % (60 * 24)) / 60
        let mins = minutes % 60

        if days > 0 { return String(localized: "\(days)d \(hours)h", bundle: AppLanguage.bundle, comment: "Countdown: days and hours") }
        if hours > 0 { return String(localized: "\(hours)h \(mins)m", bundle: AppLanguage.bundle, comment: "Countdown: hours and minutes") }
        return String(localized: "\(mins)m", bundle: AppLanguage.bundle, comment: "Minutes, short")
    }

    /// Full sentence used under the time picker, on the cards and the widget.
    static func ringsIn(_ target: Date, from now: Date) -> String {
        let seconds = Int(target.timeIntervalSince(now))
        if seconds <= 0 { return String(localized: "Rings in now", bundle: AppLanguage.bundle) }
        if seconds < 60 { return String(localized: "Rings in under a minute", bundle: AppLanguage.bundle) }
        return String(localized: "Rings in \(string(until: target, from: now))", bundle: AppLanguage.bundle, comment: "Argument is a countdown such as 7h 42m")
    }
}

extension Weekday {
    /// "Mon" / "月".
    var shortLabel: String { Self.names.shortWeekdaySymbols[rawValue - 1] }
    /// "M" / "月", used on the day pills. Uppercased: es-MX's are "l m m j v".
    var minimalLabel: String {
        Self.names.veryShortWeekdaySymbols[rawValue - 1].uppercased(with: AppLanguage.locale)
    }

    /// The weekday names come from the calendar's locale.
    private static var names: Calendar {
        var calendar = Calendar.current
        calendar.locale = AppLanguage.locale
        return calendar
    }
}

/// "Work, Holidays and Family" / "仕事、祝日、家族": items joined the language's way.
enum ListText {
    static func joined(_ items: [String]) -> String {
        let f = ListFormatter()
        f.locale = AppLanguage.locale
        return f.string(from: items) ?? items.joined(separator: ", ")
    }
}

extension Set where Element == Weekday {
    /// "Every day" (all seven or empty: the engine treats an empty set as
    /// daily), "Weekdays", "Weekends", or "Mon Wed Fri".
    var humanSummary: String {
        if isEmpty || count == 7 { return String(localized: "Every day", bundle: AppLanguage.bundle) }
        if self == Weekday.weekdays { return String(localized: "Weekdays", bundle: AppLanguage.bundle) }
        if self == Weekday.weekend { return String(localized: "Weekends", bundle: AppLanguage.bundle) }
        return Weekday.allCases.filter { contains($0) }.map(\.shortLabel).joined(separator: " ")
    }
}
