import XCTest
@testable import AlarmCore

final class NextOccurrenceCalculatorTests: XCTestCase {

    let calc = NextOccurrenceCalculator()

    // A fixed Gregorian calendar in a known timezone for deterministic tests.
    func calendar(_ identifier: String = "America/New_York") -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: identifier)!
        return c
    }

    /// Build a `Date` from wall-clock components in a calendar.
    func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int, cal: Calendar) -> Date {
        cal.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi))!
    }

    func dateOnly(_ y: Int, _ mo: Int, _ d: Int) -> DateOnly { DateOnly(year: y, month: mo, day: d) }

    // 2026-06-23 is a Tuesday.

    func testDailyAlarmLaterToday() {
        let cal = calendar()
        let now = date(2026, 6, 23, 6, 0, cal: cal)
        let s = AlarmSchedule(hour: 8, minute: 0, repeatWeekdays: Set(Weekday.allCases))
        let next = calc.nextOccurrence(for: s, after: now, calendar: cal)
        XCTAssertEqual(next, date(2026, 6, 23, 8, 0, cal: cal))
    }

    func testDailyAlarmTimeAlreadyPassedSchedulesTomorrow() {
        let cal = calendar()
        let now = date(2026, 6, 23, 9, 0, cal: cal) // past 08:00
        let s = AlarmSchedule(hour: 8, minute: 0, repeatWeekdays: Set(Weekday.allCases))
        let next = calc.nextOccurrence(for: s, after: now, calendar: cal)
        XCTAssertEqual(next, date(2026, 6, 24, 8, 0, cal: cal))
    }

    func testWeekdayAlarmSkipsWeekend() {
        let cal = calendar()
        // Friday 2026-06-26 at 09:00, after the alarm -> next is Monday.
        let now = date(2026, 6, 26, 9, 0, cal: cal)
        let s = AlarmSchedule(hour: 8, minute: 0, repeatWeekdays: Weekday.weekdays)
        let next = calc.nextOccurrence(for: s, after: now, calendar: cal)
        XCTAssertEqual(next, date(2026, 6, 29, 8, 0, cal: cal)) // Monday
    }

    func testSkipToday() {
        let cal = calendar()
        let now = date(2026, 6, 23, 6, 0, cal: cal) // Tuesday
        var s = AlarmSchedule(hour: 8, minute: 0, repeatWeekdays: Set(Weekday.allCases))
        s.skippedOccurrenceDates = [dateOnly(2026, 6, 23)]
        let next = calc.nextOccurrence(for: s, after: now, calendar: cal)
        XCTAssertEqual(next, date(2026, 6, 24, 8, 0, cal: cal)) // tomorrow, still active
    }

    func testStatusReportsSkippedTodayButStillActive() {
        let cal = calendar()
        let now = date(2026, 6, 23, 6, 0, cal: cal)
        var s = AlarmSchedule(hour: 8, minute: 0, repeatWeekdays: Set(Weekday.allCases))
        s.skippedOccurrenceDates = [dateOnly(2026, 6, 23)]
        let status = calc.status(for: s, now: now, calendar: cal)
        XCTAssertEqual(status, .skippedToday(next: date(2026, 6, 24, 8, 0, cal: cal)))
    }

    func testPauseDateRangeSuppressesUntilAfterRange() {
        let cal = calendar()
        let now = date(2026, 6, 23, 6, 0, cal: cal)
        var s = AlarmSchedule(hour: 8, minute: 0, repeatWeekdays: Set(Weekday.allCases))
        s.pausedDateRanges = [DateRange(start: dateOnly(2026, 6, 23), end: dateOnly(2026, 6, 27))]
        let next = calc.nextOccurrence(for: s, after: now, calendar: cal)
        XCTAssertEqual(next, date(2026, 6, 28, 8, 0, cal: cal)) // first day after pause
    }

    func testStatusReportsPaused() {
        let cal = calendar()
        let now = date(2026, 6, 23, 6, 0, cal: cal)
        var s = AlarmSchedule(hour: 8, minute: 0, repeatWeekdays: Set(Weekday.allCases))
        s.pausedDateRanges = [DateRange(start: dateOnly(2026, 6, 23), end: dateOnly(2026, 6, 27))]
        let status = calc.status(for: s, now: now, calendar: cal)
        XCTAssertEqual(status, .paused(until: dateOnly(2026, 6, 27), next: date(2026, 6, 28, 8, 0, cal: cal)))
    }

    func testOneTimeAlarmInFuture() {
        let cal = calendar()
        let now = date(2026, 6, 23, 6, 0, cal: cal)
        let s = AlarmSchedule(hour: 8, minute: 0, mode: .oneTimeDate, oneTimeDate: dateOnly(2026, 7, 1))
        let next = calc.nextOccurrence(for: s, after: now, calendar: cal)
        XCTAssertEqual(next, date(2026, 7, 1, 8, 0, cal: cal))
    }

    func testOneTimeAlarmInPastReturnsNil() {
        let cal = calendar()
        let now = date(2026, 6, 23, 6, 0, cal: cal)
        let s = AlarmSchedule(hour: 8, minute: 0, mode: .oneTimeDate, oneTimeDate: dateOnly(2026, 6, 1))
        XCTAssertNil(calc.nextOccurrence(for: s, after: now, calendar: cal))
        XCTAssertEqual(calc.status(for: s, now: now, calendar: cal), .completed)
    }

    func testOneTimeAlarmLaterTodayStillFires() {
        let cal = calendar()
        let now = date(2026, 6, 23, 6, 0, cal: cal)
        let s = AlarmSchedule(hour: 8, minute: 0, mode: .oneTimeDate, oneTimeDate: dateOnly(2026, 6, 23))
        XCTAssertEqual(calc.nextOccurrence(for: s, after: now, calendar: cal), date(2026, 6, 23, 8, 0, cal: cal))
    }

    func testDSTSpringForwardTransition() {
        // US DST 2026: clocks spring forward on Sunday 2026-03-08 at 02:00.
        let cal = calendar()
        // An alarm at 07:00 the morning of the transition should still resolve to
        // a valid instant 07:00 local (after the skipped 02:00–03:00 window).
        let now = date(2026, 3, 8, 0, 30, cal: cal)
        let s = AlarmSchedule(hour: 7, minute: 0, repeatWeekdays: Set(Weekday.allCases))
        let next = calc.nextOccurrence(for: s, after: now, calendar: cal)
        XCTAssertNotNil(next)
        let comps = cal.dateComponents([.hour, .minute], from: next!)
        XCTAssertEqual(comps.hour, 7)
        XCTAssertEqual(comps.minute, 0)
    }

    func testTimezoneChangeRecomputesWallClock() {
        // Same schedule, two calendars: the fire time tracks the local wall clock.
        let ny = calendar("America/New_York")
        let la = calendar("America/Los_Angeles")
        let s = AlarmSchedule(hour: 8, minute: 0, repeatWeekdays: Set(Weekday.allCases))

        let nowNY = date(2026, 6, 23, 6, 0, cal: ny)
        let nextNY = calc.nextOccurrence(for: s, after: nowNY, calendar: ny)!
        XCTAssertEqual(ny.dateComponents([.hour], from: nextNY).hour, 8)

        let nowLA = date(2026, 6, 23, 6, 0, cal: la)
        let nextLA = calc.nextOccurrence(for: s, after: nowLA, calendar: la)!
        XCTAssertEqual(la.dateComponents([.hour], from: nextLA).hour, 8)
    }

    func testMultipleRepeatDays() {
        let cal = calendar()
        // Mon/Wed/Fri, now Tuesday -> next is Wednesday.
        let now = date(2026, 6, 23, 10, 0, cal: cal)
        let s = AlarmSchedule(hour: 8, minute: 0, repeatWeekdays: [.monday, .wednesday, .friday])
        let next = calc.nextOccurrence(for: s, after: now, calendar: cal)
        XCTAssertEqual(next, date(2026, 6, 24, 8, 0, cal: cal)) // Wednesday
    }

    func testNoRepeatDaysFiresNextSingleSlot() {
        let cal = calendar()
        let now = date(2026, 6, 23, 9, 0, cal: cal) // past 08:00 today
        let s = AlarmSchedule(hour: 8, minute: 0, repeatWeekdays: []) // empty -> once
        let next = calc.nextOccurrence(for: s, after: now, calendar: cal)
        XCTAssertEqual(next, date(2026, 6, 24, 8, 0, cal: cal))
    }

    func testDisabledAlarmReturnsNil() {
        let cal = calendar()
        let now = date(2026, 6, 23, 6, 0, cal: cal)
        let s = AlarmSchedule(hour: 8, minute: 0, isEnabled: false, repeatWeekdays: Set(Weekday.allCases))
        XCTAssertNil(calc.nextOccurrence(for: s, after: now, calendar: cal))
        XCTAssertEqual(calc.status(for: s, now: now, calendar: cal), .off)
    }

    func testSkippedOccurrenceDateOnlyAffectsThatDay() {
        let cal = calendar()
        let now = date(2026, 6, 23, 6, 0, cal: cal)
        var s = AlarmSchedule(hour: 8, minute: 0, repeatWeekdays: Set(Weekday.allCases))
        s.skippedOccurrenceDates = [dateOnly(2026, 6, 24)] // skip tomorrow specifically
        // Today still fires.
        XCTAssertEqual(calc.nextOccurrence(for: s, after: now, calendar: cal), date(2026, 6, 23, 8, 0, cal: cal))
        // After today, it jumps over the 24th to the 25th.
        let afterToday = date(2026, 6, 23, 9, 0, cal: cal)
        XCTAssertEqual(calc.nextOccurrence(for: s, after: afterToday, calendar: cal), date(2026, 6, 25, 8, 0, cal: cal))
    }

    func testLookaheadWindowReturnsStrictlyIncreasing() {
        let cal = calendar()
        let now = date(2026, 6, 23, 6, 0, cal: cal)
        let s = AlarmSchedule(hour: 8, minute: 0, repeatWeekdays: Weekday.weekdays)
        let next3 = calc.nextOccurrences(for: s, after: now, calendar: cal, count: 3)
        XCTAssertEqual(next3, [
            date(2026, 6, 23, 8, 0, cal: cal), // Tue
            date(2026, 6, 24, 8, 0, cal: cal), // Wed
            date(2026, 6, 25, 8, 0, cal: cal)  // Thu
        ])
    }

    func testFullyPausedRangeAroundOneTimeYieldsNoUpcoming() {
        let cal = calendar()
        let now = date(2026, 6, 23, 6, 0, cal: cal)
        var s = AlarmSchedule(hour: 8, minute: 0, mode: .oneTimeDate, oneTimeDate: dateOnly(2026, 6, 25))
        s.pausedDateRanges = [DateRange(start: dateOnly(2026, 6, 24), end: dateOnly(2026, 6, 26))]
        XCTAssertNil(calc.nextOccurrence(for: s, after: now, calendar: cal))
    }
}
