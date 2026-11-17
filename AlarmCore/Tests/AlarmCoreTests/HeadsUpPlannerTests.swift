import XCTest
@testable import AlarmCore

final class HeadsUpPlannerTests: XCTestCase {

    let now = Date(timeIntervalSince1970: 1_800_000_000)
    func at(hours: Double) -> Date { now.addingTimeInterval(hours * 3600) }
    func id(_ n: Int) -> UUID { UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", n))! }

    /// An alarm ringing once a day for `days` days, the first in `firstIn` hours.
    func daily(_ n: Int, firstIn: Double, days: Int = 7, minutes: Int = 15, extra: [Int] = []) -> HeadsUpPlanner.Alarm {
        HeadsUpPlanner.Alarm(id: id(n), occurrences: (0..<days).map { at(hours: firstIn + Double($0) * 24) },
                             minutesBefore: minutes, extraMinutesBefore: extra)
    }

    // MARK: wanted

    func testExtraHeadsUpsOnlyForTheNextRing() {
        let wanted = HeadsUpPlanner.wanted([daily(1, firstIn: 2, days: 3, extra: [60, 15])], now: now)
        // 60 and 15 for the next ring (the duplicate 15 is one request), 15 for the other two.
        XCTAssertEqual(wanted.count, 4)
        XCTAssertEqual(wanted.filter { $0.occurrence == at(hours: 2) }.map(\.minutesBefore), [60, 15])
        XCTAssertEqual(Set(wanted.dropFirst(2).map(\.minutesBefore)), [15])
    }

    func testPastRingsAndPastHeadsUpsAreLeftOut() {
        // A ring in 10 minutes: its 15-minute heads-up is already past; the 5-minute one isn't.
        let alarm = HeadsUpPlanner.Alarm(id: id(1), occurrences: [at(hours: -1), at(hours: 10.0 / 60)],
                                         minutesBefore: 15, extraMinutesBefore: [5])
        let wanted = HeadsUpPlanner.wanted([alarm], now: now)
        XCTAssertEqual(wanted.map(\.minutesBefore), [5])
    }

    func testSoonestFirstAcrossAlarms() {
        let wanted = HeadsUpPlanner.wanted([daily(1, firstIn: 9, days: 2), daily(2, firstIn: 3, days: 2)], now: now)
        XCTAssertEqual(wanted.map(\.fireDate), wanted.map(\.fireDate).sorted())
        XCTAssertEqual(wanted.first?.alarmID, id(2))
    }

    func testTiesBreakTheSameWayEveryTime() {
        let a = daily(1, firstIn: 5, days: 1), b = daily(2, firstIn: 5, days: 1)
        XCTAssertEqual(HeadsUpPlanner.wanted([a, b], now: now), HeadsUpPlanner.wanted([b, a], now: now))
    }

    // MARK: plan

    func testUnderTheLimitNothingWaits() {
        let plan = HeadsUpPlanner.plan([daily(1, firstIn: 2), daily(2, firstIn: 3)], now: now, limit: 56)
        XCTAssertEqual(plan.scheduled.count, 14)
        XCTAssertTrue(plan.waiting.isEmpty)
    }

    func testOverTheLimitTheLatestWait() {
        // Ten daily alarms over a week want 70 heads-ups; 56 fit.
        let alarms = (1...10).map { daily($0, firstIn: Double($0)) }
        let plan = HeadsUpPlanner.plan(alarms, now: now, limit: 56)
        XCTAssertEqual(plan.scheduled.count, 56)
        XCTAssertEqual(plan.waiting.count, 14)
        let lastSet = plan.scheduled.last!.fireDate, firstWaiting = plan.waiting.first!.fireDate
        XCTAssertLessThanOrEqual(lastSet, firstWaiting)
        // Every alarm still gets its next few rings covered.
        for n in 1...10 {
            XCTAssertGreaterThanOrEqual(plan.scheduled.filter { $0.alarmID == id(n) }.count, 5)
        }
    }

    func testNonPositiveLimitSetsNothing() {
        let plan = HeadsUpPlanner.plan([daily(1, firstIn: 2, days: 2)], now: now, limit: -3)
        XCTAssertTrue(plan.scheduled.isEmpty)
        XCTAssertEqual(plan.waiting.count, 2)
    }

    // MARK: limit

    func testLimitKeepsTheCalendarReserve() {
        XCTAssertEqual(HeadsUpPlanner.limit(calendarNotices: 0, others: 0, calendarInUse: true), 56)
        XCTAssertEqual(HeadsUpPlanner.limit(calendarNotices: 3, others: 0, calendarInUse: true), 56)
    }

    func testLimitKeepsTheWakeCheckSlot() {
        XCTAssertEqual(HeadsUpPlanner.limit(calendarNotices: 0, others: 0, calendarInUse: false, wakeCheckInUse: true), 63)
        // The pending notice fills the slot it was kept for, not one more.
        XCTAssertEqual(HeadsUpPlanner.limit(calendarNotices: 0, wakeChecks: 1, others: 0, calendarInUse: false, wakeCheckInUse: true), 63)
        XCTAssertEqual(HeadsUpPlanner.limit(calendarNotices: 0, others: 0, calendarInUse: true, wakeCheckInUse: true), 55)
        // Switched off while one is still pending: it keeps its slot until it shows.
        XCTAssertEqual(HeadsUpPlanner.limit(calendarNotices: 0, wakeChecks: 1, others: 0, calendarInUse: false), 63)
    }

    func testNoReserveWhenNoAlarmUsesTheCalendar() {
        // Ten alarms armed 6 deep want 60 heads-ups: they all fit.
        XCTAssertEqual(HeadsUpPlanner.limit(calendarNotices: 0, others: 0, calendarInUse: false), 64)
        XCTAssertEqual(HeadsUpPlanner.limit(calendarNotices: 0, others: 2, calendarInUse: false), 62)
        // Notices still pending from before auto-skip was switched off keep their slots.
        XCTAssertEqual(HeadsUpPlanner.limit(calendarNotices: 2, others: 0, calendarInUse: false), 62)
    }

    func testLimitMakesRoomForMoreCalendarNotices() {
        XCTAssertEqual(HeadsUpPlanner.limit(calendarNotices: 12, others: 2, calendarInUse: true), 50)
        XCTAssertEqual(HeadsUpPlanner.limit(calendarNotices: 70, others: 0, calendarInUse: true), 0)
    }
}
