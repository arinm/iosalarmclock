import Foundation

/// Pure scheduling logic. No UI, no persistence, no AlarmKit. Given an alarm
/// schedule and "now", it computes the next concrete fire `Date`(s), honouring
/// repeat days, one-time dates, skip marks, pause ranges, timezone and DST.
///
/// Design note: because AlarmKit has no "skip one occurrence" primitive, the app
/// schedules the dates this engine returns as individual one-time AlarmKit
/// alarms and re-arms after each fire / on foreground. That makes this type the
/// single source of truth for *when* an alarm rings.
public struct NextOccurrenceCalculator {

    /// Safety bound on how many days ahead we scan. Two years comfortably covers
    /// long pauses and sparse weekday sets while guaranteeing termination.
    private let maxLookaheadDays: Int

    public init(maxLookaheadDays: Int = 366 * 2) {
        self.maxLookaheadDays = maxLookaheadDays
    }

    /// The single next moment the alarm will ring strictly after `now`, or `nil`
    /// if it never will (disabled, completed one-time, fully paused, etc.).
    public func nextOccurrence(
        for schedule: AlarmSchedule,
        after now: Date,
        calendar: Calendar
    ) -> Date? {
        guard schedule.isEnabled else { return nil }
        guard (0...23).contains(schedule.hour), (0...59).contains(schedule.minute) else { return nil }

        switch schedule.mode {
        case .oneTimeDate:
            return nextOneTime(schedule, after: now, calendar: calendar)
        case .recurring:
            return nextRecurring(schedule, after: now, calendar: calendar)
        }
    }

    /// Up to `count` upcoming occurrences (used to arm a small look-ahead window
    /// for resilience). Strictly increasing.
    public func nextOccurrences(
        for schedule: AlarmSchedule,
        after now: Date,
        calendar: Calendar,
        count: Int
    ) -> [Date] {
        guard count > 0 else { return [] }
        var results: [Date] = []
        var cursor = now
        while results.count < count, let next = nextOccurrence(for: schedule, after: cursor, calendar: calendar) {
            results.append(next)
            cursor = next // strictly-greater search continues past it
        }
        return results
    }

    /// A display-ready status combining the schedule with its next occurrence.
    public func status(
        for schedule: AlarmSchedule,
        now: Date,
        calendar: Calendar
    ) -> AlarmStatus {
        guard schedule.isEnabled else { return .off }

        let today = DateOnly(date: now, calendar: calendar)
        let next = nextOccurrence(for: schedule, after: now, calendar: calendar)

        // Inside an active pause range?
        if let range = schedule.pausedDateRanges.first(where: { $0.contains(today) }) {
            return .paused(until: range.end, next: next)
        }

        // One-time alarm that has already passed.
        if schedule.mode == .oneTimeDate, next == nil {
            return .completed
        }

        guard let next else { return .noUpcoming }

        // Today's natural occurrence exists but is suppressed by a skip mark.
        if schedule.skippedOccurrenceDates.contains(today),
           wouldNaturallyFire(schedule, on: today, calendar: calendar) {
            return .skippedToday(next: next)
        }

        return .scheduled(next: next)
    }

    // MARK: - One-time

    private func nextOneTime(_ s: AlarmSchedule, after now: Date, calendar: Calendar) -> Date? {
        guard let day = s.oneTimeDate, !s.isSuppressed(day) else { return nil }
        guard let fire = day.date(hour: s.hour, minute: s.minute, in: calendar) else { return nil }
        return fire > now ? fire : nil
    }

    // MARK: - Recurring

    private func nextRecurring(_ s: AlarmSchedule, after now: Date, calendar: Calendar) -> Date? {
        let startDay = DateOnly(date: now, calendar: calendar)
        guard let startMidnight = startDay.startOfDay(in: calendar) else { return nil }

        for offset in 0...maxLookaheadDays {
            guard let dayDate = calendar.date(byAdding: .day, value: offset, to: startMidnight) else { continue }
            let day = DateOnly(date: dayDate, calendar: calendar)

            // Repeat-day filter. Empty set == every day (fires at the next valid slot each day).
            if !s.repeatWeekdays.isEmpty {
                let weekday = Weekday(date: dayDate, calendar: calendar)
                guard s.repeatWeekdays.contains(weekday) else { continue }
            }

            guard !s.isSuppressed(day) else { continue }
            guard let fire = day.date(hour: s.hour, minute: s.minute, in: calendar) else { continue }
            if fire > now { return fire }
        }
        return nil
    }

    /// Would this alarm fire on `day` ignoring skip marks (used to distinguish
    /// "skipped today" from "just not scheduled today")?
    private func wouldNaturallyFire(_ s: AlarmSchedule, on day: DateOnly, calendar: Calendar) -> Bool {
        guard let dayDate = day.startOfDay(in: calendar) else { return false }
        switch s.mode {
        case .oneTimeDate:
            return s.oneTimeDate == day
        case .recurring:
            if s.repeatWeekdays.isEmpty { return true }
            return s.repeatWeekdays.contains(Weekday(date: dayDate, calendar: calendar))
        }
    }
}
