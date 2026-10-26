import XCTest
@testable import AlarmCore

final class CalendarSkipPlannerTests: XCTestCase {

    func calendar(_ identifier: String = "America/New_York") -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: identifier)!
        return c
    }
    func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int, cal: Calendar) -> Date {
        cal.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi))!
    }
    func day(_ y: Int, _ mo: Int, _ d: Int) -> DateOnly { DateOnly(year: y, month: mo, day: d) }

    // 2026-11-03 (Election Day) is a Tuesday.

    // MARK: skipDays

    func testSkipDaysDropsPastDaysAndRingAnywayDays() {
        let days: Set = [day(2026, 11, 2), day(2026, 11, 3), day(2026, 11, 26)]
        let result = CalendarSkipPlanner.skipDays(calendarDays: days,
                                                  ringAnyway: [day(2026, 11, 3)],
                                                  today: day(2026, 11, 3))
        XCTAssertEqual(result, [day(2026, 11, 26)])
    }

    func testSkipDaysKeepsToday() {
        let result = CalendarSkipPlanner.skipDays(calendarDays: [day(2026, 11, 3)], ringAnyway: [],
                                                  today: day(2026, 11, 3))
        XCTAssertEqual(result, [day(2026, 11, 3)])
    }

    // MARK: suppressedOccurrences

    func testOnlyDaysTheAlarmWouldRingAreSuppressed() {
        let cal = calendar()
        let now = date(2026, 10, 31, 12, 0, cal: cal)            // Saturday
        let weekdays = AlarmSchedule(hour: 6, minute: 30, repeatWeekdays: Weekday.weekdays)
        // Sunday 1 Nov is a calendar day off, but a weekday alarm doesn't ring
        // then anyway: only Tuesday 3 Nov is a ring the calendar takes away.
        let out = CalendarSkipPlanner.suppressedOccurrences(
            schedule: weekdays, calendarSkips: [day(2026, 11, 1), day(2026, 11, 3)],
            after: now, until: date(2026, 11, 10, 0, 0, cal: cal), calendar: cal)
        XCTAssertEqual(out, [date(2026, 11, 3, 6, 30, cal: cal)])
    }

    func testManuallySkippedOrPausedDaysNeedNoCalendarWarning() {
        let cal = calendar()
        let now = date(2026, 11, 1, 12, 0, cal: cal)
        var s = AlarmSchedule(hour: 6, minute: 30, repeatWeekdays: Weekday.weekdays)
        s.skippedOccurrenceDates = [day(2026, 11, 3)]               // user skipped it by hand
        s.pausedDateRanges = [DateRange(start: day(2026, 11, 4), end: day(2026, 11, 5))]
        let out = CalendarSkipPlanner.suppressedOccurrences(
            schedule: s, calendarSkips: [day(2026, 11, 3), day(2026, 11, 4), day(2026, 11, 6)],
            after: now, until: date(2026, 11, 10, 0, 0, cal: cal), calendar: cal)
        XCTAssertEqual(out, [date(2026, 11, 6, 6, 30, cal: cal)])
    }

    func testHorizonIsRespected() {
        let cal = calendar()
        let s = AlarmSchedule(hour: 6, minute: 30, repeatWeekdays: Set(Weekday.allCases))
        let out = CalendarSkipPlanner.suppressedOccurrences(
            schedule: s, calendarSkips: [day(2026, 11, 3), day(2026, 12, 25)],
            after: date(2026, 11, 1, 0, 0, cal: cal), until: date(2026, 11, 30, 0, 0, cal: cal), calendar: cal)
        XCTAssertEqual(out, [date(2026, 11, 3, 6, 30, cal: cal)])
    }

    func testNoCalendarSkipsMeansNothingSuppressed() {
        let cal = calendar()
        let s = AlarmSchedule(hour: 6, minute: 30, repeatWeekdays: Set(Weekday.allCases))
        XCTAssertEqual(CalendarSkipPlanner.suppressedOccurrences(
            schedule: s, calendarSkips: [], after: .now, until: .now.addingTimeInterval(86_400 * 30),
            calendar: cal), [])
    }

    // MARK: noticeBlocks

    func testVacationAcrossAWeekendIsOneBlock() {
        let cal = calendar()
        let wake = UUID()
        // Vacation Mon 3 - Fri 14 Aug 2026 as one all-day event: the weekend in
        // the middle is a day off too, so the run is unbroken.
        var off: Set<DateOnly> = []
        for d in 3...14 { off.insert(day(2026, 8, d)) }
        let rings = [3, 4, 5, 6, 7, 10, 11, 12, 13, 14].map {
            CalendarSkipPlanner.Ring(alarmID: wake, date: date(2026, 8, $0, 6, 30, cal: cal)) }
        let blocks = CalendarSkipPlanner.noticeBlocks(rings: rings, daysOff: off, calendar: cal)
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].start, day(2026, 8, 3))
        XCTAssertEqual(blocks[0].end, day(2026, 8, 14))
        XCTAssertEqual(blocks[0].rings.count, 10)
        XCTAssertTrue(blocks[0].spansSeveralDays(cal))
    }

    func testSeveralAlarmsOnOneHolidayAreOneBlock() {
        let cal = calendar()
        let wake = UUID(), meds = UUID()
        let rings = [CalendarSkipPlanner.Ring(alarmID: meds, date: date(2026, 12, 1, 8, 0, cal: cal)),
                     CalendarSkipPlanner.Ring(alarmID: wake, date: date(2026, 12, 1, 6, 30, cal: cal))]
        let blocks = CalendarSkipPlanner.noticeBlocks(rings: rings, daysOff: [day(2026, 12, 1)], calendar: cal)
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].firstRing.alarmID, wake)       // sorted by time
        XCTAssertFalse(blocks[0].spansSeveralDays(cal))
    }

    func testSeparateHolidaysAreSeparateBlocks() {
        let cal = calendar()
        let wake = UUID()
        let rings = [CalendarSkipPlanner.Ring(alarmID: wake, date: date(2026, 11, 30, 6, 30, cal: cal)),
                     CalendarSkipPlanner.Ring(alarmID: wake, date: date(2026, 12, 1, 6, 30, cal: cal)),
                     CalendarSkipPlanner.Ring(alarmID: wake, date: date(2026, 12, 25, 6, 30, cal: cal))]
        let blocks = CalendarSkipPlanner.noticeBlocks(
            rings: rings, daysOff: [day(2026, 11, 30), day(2026, 12, 1), day(2026, 12, 25)], calendar: cal)
        // 30 Nov + 1 Dec are back to back (one notice); Christmas is its own.
        XCTAssertEqual(blocks.map(\.start), [day(2026, 11, 30), day(2026, 12, 25)])
        XCTAssertEqual(blocks.map(\.end), [day(2026, 12, 1), day(2026, 12, 25)])
        XCTAssertEqual(blocks.map(\.rings.count), [2, 1])
    }

    func testDaysOffWithoutRingsMakeNoBlock() {
        let cal = calendar()
        // A Saturday holiday for a weekday alarm: nothing is taken away.
        XCTAssertEqual(CalendarSkipPlanner.noticeBlocks(rings: [], daysOff: [day(2026, 8, 15)], calendar: cal), [])
    }

    func testRunAcrossMonthAndYearEnd() {
        let cal = calendar()
        let wake = UUID()
        let rings = [CalendarSkipPlanner.Ring(alarmID: wake, date: date(2026, 12, 31, 6, 30, cal: cal)),
                     CalendarSkipPlanner.Ring(alarmID: wake, date: date(2027, 1, 1, 6, 30, cal: cal))]
        let blocks = CalendarSkipPlanner.noticeBlocks(rings: rings, daysOff: [day(2026, 12, 31), day(2027, 1, 1)], calendar: cal)
        XCTAssertEqual(blocks.count, 1)
    }

    // MARK: noticeAction

    /// Weekday 6:30 rings of `alarm` on the given August 2026 days.
    func rings(_ alarm: UUID, _ days: [Int], cal: Calendar) -> Set<CalendarSkipPlanner.Ring> {
        Set(days.map { CalendarSkipPlanner.Ring(alarmID: alarm, date: date(2026, 8, $0, 6, 30, cal: cal)) })
    }

    func testVacationIsAnnouncedOnceAsItsDaysPass() {
        // Vacation Mon 3 - Fri 7 Aug, announced Sun 2 Aug at 20:00.
        let cal = calendar()
        let wake = UUID()
        let shown = rings(wake, [3, 4, 5, 6, 7], cal: cal)
        // Tue 4 Aug, after the ring: days off now start today, the run's end doesn't move.
        let now = date(2026, 8, 4, 9, 0, cal: cal)
        let off = Set((4...7).map { day(2026, 8, $0) })
        let left = rings(wake, [5, 6, 7], cal: cal)
        let blocks = CalendarSkipPlanner.noticeBlocks(rings: Array(left), daysOff: off, calendar: cal)
        XCTAssertEqual(blocks.map(\.end), [day(2026, 8, 7)])
        XCTAssertEqual(CalendarSkipPlanner.noticeAction(rings: left, onScreen: shown, told: shown,
                                                        now: now, calendar: cal), .none)
    }

    func testNotYetShownIsAnnouncedOnSchedule() {
        let cal = calendar()
        let wake = UUID()
        let now = date(2026, 8, 1, 12, 0, cal: cal)
        XCTAssertEqual(CalendarSkipPlanner.noticeAction(rings: rings(wake, [3, 4], cal: cal), onScreen: nil, told: [],
                                                        now: now, calendar: cal),
                       .announce(at: date(2026, 8, 2, 20, 0, cal: cal)))
    }

    func testRingAnywayOnOneAlarmCorrectsTheNoticeQuietly() {
        // "2 alarms are off" was shown; one of them now rings after all.
        let cal = calendar()
        let wake = UUID(), meds = UUID()
        let shown = rings(wake, [3, 4], cal: cal).union(rings(meds, [3, 4], cal: cal))
        let now = date(2026, 8, 2, 21, 0, cal: cal)
        XCTAssertEqual(CalendarSkipPlanner.noticeAction(rings: rings(wake, [3, 4], cal: cal), onScreen: shown, told: shown,
                                                        now: now, calendar: cal), .correct)
    }

    func testRunSplitByRingAnywayGetsNoNewBanner() {
        // Mon-Fri was shown; Ring anyway on Wed splits it into Mon-Tue and Thu-Fri.
        let cal = calendar()
        let wake = UUID()
        let shown = rings(wake, [3, 4, 5, 6, 7], cal: cal)
        let now = date(2026, 8, 2, 21, 0, cal: cal)
        XCTAssertEqual(CalendarSkipPlanner.noticeAction(rings: rings(wake, [3, 4], cal: cal), onScreen: nil, told: shown,
                                                        now: now, calendar: cal), .correct)
        XCTAssertEqual(CalendarSkipPlanner.noticeAction(rings: rings(wake, [6, 7], cal: cal), onScreen: shown, told: shown,
                                                        now: now, calendar: cal), .correct)
    }

    func testRingNobodyAnnouncedIsAnnouncedAgain() {
        // A second alarm joins a vacation that was announced for the first one
        // (a new alarm, or an undone Ring anyway).
        let cal = calendar()
        let wake = UUID(), meds = UUID()
        let shown = rings(wake, [3, 4, 5, 6, 7], cal: cal)
        let now = date(2026, 8, 3, 9, 0, cal: cal)
        let current = rings(wake, [4, 5, 6, 7], cal: cal).union(rings(meds, [4, 5], cal: cal))
        XCTAssertEqual(CalendarSkipPlanner.noticeAction(rings: current, onScreen: shown, told: shown,
                                                        now: now, calendar: cal),
                       .announce(at: date(2026, 8, 3, 20, 0, cal: cal)))
    }

    func testNewRingIsAnnouncedWhenTheFirstIsMinutesAway() {
        // Holiday morning, 6:20: the 6:30 ring was announced last night, an
        // 8:00 alarm was just added. The 6:30 one is too close to warn about,
        // the 8:00 one isn't.
        let cal = calendar()
        let wake = UUID(), work = UUID()
        let now = date(2026, 11, 3, 6, 20, cal: cal)
        let early = CalendarSkipPlanner.Ring(alarmID: wake, date: date(2026, 11, 3, 6, 30, cal: cal))
        let late = CalendarSkipPlanner.Ring(alarmID: work, date: date(2026, 11, 3, 8, 0, cal: cal))
        XCTAssertEqual(CalendarSkipPlanner.noticeAction(rings: [early, late], onScreen: [early], told: [early],
                                                        now: now, calendar: cal), .announce(at: now))
        // Same when nothing was announced yet.
        XCTAssertEqual(CalendarSkipPlanner.noticeAction(rings: [early, late], onScreen: nil, told: [],
                                                        now: now, calendar: cal), .announce(at: now))
        // Only rings minutes away: nothing to announce.
        XCTAssertEqual(CalendarSkipPlanner.noticeAction(rings: [early], onScreen: nil, told: [],
                                                        now: now, calendar: cal), .none)
    }

    func testLongLeaveIsAnnouncedOnceAsTheWindowMoves() {
        // Leave from Mon 1 Jun to Mon 31 Aug 2026, longer than the 60-day window.
        let cal = calendar()
        let wake = UUID()
        let schedule = AlarmSchedule(hour: 6, minute: 30, repeatWeekdays: Weekday.weekdays)
        var off = Set<DateOnly>()
        var d = date(2026, 6, 1, 12, 0, cal: cal)
        while d < date(2026, 9, 1, 0, 0, cal: cal) {
            off.insert(DateOnly(date: d, calendar: cal))
            d = cal.date(byAdding: .day, value: 1, to: d)!
        }
        func rings(at now: Date) -> Set<CalendarSkipPlanner.Ring> {
            let until = CalendarSkipPlanner.lookaheadEnd(daysOff: off, now: now, calendar: cal)!
            return Set(CalendarSkipPlanner.suppressedOccurrences(schedule: schedule, calendarSkips: off,
                                                                 after: now, until: until, calendar: cal)
                .map { CalendarSkipPlanner.Ring(alarmID: wake, date: $0) })
        }
        // Announced Sun 31 May at 20:00, then the next evening: nothing new.
        let shown = rings(at: date(2026, 5, 31, 20, 0, cal: cal))
        XCTAssertTrue(shown.contains(CalendarSkipPlanner.Ring(alarmID: wake, date: date(2026, 8, 31, 6, 30, cal: cal))))
        let now = date(2026, 6, 1, 20, 0, cal: cal)
        XCTAssertEqual(CalendarSkipPlanner.noticeAction(rings: rings(at: now), onScreen: shown, told: shown,
                                                        now: now, calendar: cal), .none)
    }

    func testLookaheadEnd() {
        let cal = calendar()
        let now = date(2026, 6, 1, 12, 0, cal: cal)
        // No day off, or only near ones: the 60-day window.
        XCTAssertEqual(CalendarSkipPlanner.lookaheadEnd(daysOff: [], now: now, calendar: cal),
                       date(2026, 7, 31, 12, 0, cal: cal))
        XCTAssertEqual(CalendarSkipPlanner.lookaheadEnd(daysOff: [day(2026, 6, 5)], now: now, calendar: cal),
                       date(2026, 7, 31, 12, 0, cal: cal))
        // A later day off: through the end of that day.
        XCTAssertEqual(CalendarSkipPlanner.lookaheadEnd(daysOff: [day(2026, 6, 5), day(2026, 8, 31)], now: now, calendar: cal),
                       date(2026, 9, 1, 0, 0, cal: cal))
        // Never past the cap.
        XCTAssertEqual(CalendarSkipPlanner.lookaheadEnd(daysOff: [day(2028, 1, 1)], now: now, calendar: cal),
                       cal.date(byAdding: .day, value: 400, to: now))
    }

    // MARK: noticeDate

    func testMorningAlarmIsAnnouncedTheEveningBefore() {
        let cal = calendar()
        let ring = date(2026, 11, 3, 6, 30, cal: cal)
        let now = date(2026, 11, 1, 10, 0, cal: cal)
        XCTAssertEqual(CalendarSkipPlanner.noticeDate(for: ring, now: now, calendar: cal),
                       date(2026, 11, 2, 20, 0, cal: cal))
    }

    func testAfternoonAlarmIsAnnouncedThatMorning() {
        let cal = calendar()
        let ring = date(2026, 11, 3, 15, 0, cal: cal)
        let now = date(2026, 11, 2, 22, 0, cal: cal)
        XCTAssertEqual(CalendarSkipPlanner.noticeDate(for: ring, now: now, calendar: cal),
                       date(2026, 11, 3, 9, 0, cal: cal))
    }

    func testLateDiscoveryIsAnnouncedNow() {
        let cal = calendar()
        let ring = date(2026, 11, 3, 6, 30, cal: cal)
        let now = date(2026, 11, 2, 23, 15, cal: cal)               // past 20:00 already
        XCTAssertEqual(CalendarSkipPlanner.noticeDate(for: ring, now: now, calendar: cal), now)
    }

    func testTooCloseToTheRingIsNotAnnounced() {
        let cal = calendar()
        let ring = date(2026, 11, 3, 6, 30, cal: cal)
        let now = date(2026, 11, 3, 6, 20, cal: cal)                // 10 min before
        XCTAssertNil(CalendarSkipPlanner.noticeDate(for: ring, now: now, calendar: cal))
    }

    func testPastOccurrenceIsNotAnnounced() {
        let cal = calendar()
        let ring = date(2026, 11, 3, 6, 30, cal: cal)
        XCTAssertNil(CalendarSkipPlanner.noticeDate(for: ring, now: date(2026, 11, 3, 7, 0, cal: cal), calendar: cal))
    }

    func testMidnightAlarmStillGetsTheEveningBefore() {
        let cal = calendar()
        let ring = date(2026, 11, 3, 0, 15, cal: cal)
        let now = date(2026, 11, 2, 8, 0, cal: cal)
        XCTAssertEqual(CalendarSkipPlanner.noticeDate(for: ring, now: now, calendar: cal),
                       date(2026, 11, 2, 20, 0, cal: cal))
    }

    func testEveningBeforeAcrossDSTEnd() {
        // US DST ends Sunday 1 Nov 2026: the evening before still lands at 20:00.
        let cal = calendar()
        let ring = date(2026, 11, 2, 6, 30, cal: cal)
        let now = date(2026, 10, 31, 12, 0, cal: cal)
        XCTAssertEqual(CalendarSkipPlanner.noticeDate(for: ring, now: now, calendar: cal),
                       date(2026, 11, 1, 20, 0, cal: cal))
    }
}
