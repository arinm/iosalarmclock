import Foundation

/// Pure rules for the Pro calendar auto-skip: which days an alarm skips because
/// of the user's chosen calendars, which rings that removes, and when to warn
/// about each one.
///
/// The warning exists because a calendar is a noisy source. Apple's own US and
/// German holiday calendars mark observances that are working days (Tax Day,
/// Election Day, Rosenmontag) exactly like real days off, so a calendar skip
/// must never be silent: the user is told ahead of time and can ring anyway.
public enum CalendarSkipPlanner {

    /// The days an opted-in alarm should skip: calendar days off from `today` on,
    /// minus the days the user chose to ring anyway.
    public static func skipDays(calendarDays: Set<DateOnly>,
                                ringAnyway: Set<DateOnly>,
                                today: DateOnly) -> Set<DateOnly> {
        Set(calendarDays.filter { $0 >= today && !ringAnyway.contains($0) })
    }

    /// The rings the calendar takes away within (`now`, `until`].
    ///
    /// `schedule` must be the alarm WITHOUT its calendar skips, i.e. manual skips
    /// and pauses only. A day the user already skipped or paused is suppressed
    /// regardless of the calendar, so it never needs a calendar warning.
    public static func suppressedOccurrences(schedule: AlarmSchedule,
                                             calendarSkips: Set<DateOnly>,
                                             after now: Date,
                                             until: Date,
                                             calendar: Calendar) -> [Date] {
        guard !calendarSkips.isEmpty else { return [] }
        let calc = NextOccurrenceCalculator()
        var out: [Date] = []
        var cursor = now
        while let next = calc.nextOccurrence(for: schedule, after: cursor, calendar: calendar), next <= until {
            if calendarSkips.contains(DateOnly(date: next, calendar: calendar)) { out.append(next) }
            cursor = next
        }
        return out
    }

    /// How far to look for the rings the calendar takes away: `minimumDays`
    /// ahead, or to the end of the last day off if that is later (at most
    /// `maximumDays`). A leave longer than the window would otherwise gain a
    /// "new" ring every day as the window moves, and be announced again every
    /// evening. Followed to its end, it is announced once, with its real last day.
    public static func lookaheadEnd(daysOff: Set<DateOnly>, now: Date, calendar: Calendar,
                                    minimumDays: Int = 60, maximumDays: Int = 400) -> Date? {
        guard let minimum = calendar.date(byAdding: .day, value: minimumDays, to: now) else { return nil }
        guard let lastStart = daysOff.max()?.startOfDay(in: calendar),
              let afterLast = calendar.date(byAdding: .day, value: 1, to: lastStart) else { return minimum }
        let maximum = calendar.date(byAdding: .day, value: maximumDays, to: now) ?? minimum
        return min(max(minimum, afterLast), maximum)
    }

    /// One notice's worth of calendar skips: a run of consecutive days off and
    /// every ring (from any alarm) the calendar takes away inside it.
    public struct Block: Equatable, Sendable {
        public let start: DateOnly                         // first day of the run of days off
        /// Last day of the run. Unlike `start`, it doesn't move as the days of a
        /// vacation pass (days off are counted from today), so it names the notice.
        public let end: DateOnly
        public let rings: [Ring]                           // sorted by date
        public var firstRing: Ring { rings[0] }
        public var lastRing: Ring { rings[rings.count - 1] }
        /// Rings fall on more than one day (a vacation, a long weekend).
        public func spansSeveralDays(_ calendar: Calendar) -> Bool {
            DateOnly(date: firstRing.date, calendar: calendar) != DateOnly(date: lastRing.date, calendar: calendar)
        }
    }

    public struct Ring: Hashable, Codable, Sendable {
        public let alarmID: UUID
        public let date: Date
        public init(alarmID: UUID, date: Date) { self.alarmID = alarmID; self.date = date }
    }

    /// Groups skipped rings into notices, so a two-week vacation is ONE notice
    /// (not one every evening) and a holiday that silences three alarms is ONE
    /// notice (not three).
    ///
    /// A block is a run of consecutive `daysOff` (calendar days, so a weekend
    /// inside a vacation doesn't split it, even though a weekday alarm has no
    /// rings then). Runs without a single skipped ring produce no block.
    public static func noticeBlocks(rings: [Ring], daysOff: Set<DateOnly>, calendar: Calendar) -> [Block] {
        var runStart: [DateOnly: DateOnly] = [:]           // day -> first day of its run
        var runEnd: [DateOnly: DateOnly] = [:]             // first day -> last day of the run
        var current: DateOnly?
        var previous: DateOnly?
        for day in daysOff.sorted() {
            if let p = previous, let next = p.startOfDay(in: calendar)
                .flatMap({ calendar.date(byAdding: .day, value: 1, to: $0) })
                .map({ DateOnly(date: $0, calendar: calendar) }), next == day {
                // continues the run
            } else {
                current = day
            }
            runStart[day] = current
            runEnd[current ?? day] = day
            previous = day
        }
        var byStart: [DateOnly: [Ring]] = [:]
        for ring in rings {
            guard let start = runStart[DateOnly(date: ring.date, calendar: calendar)] else { continue }
            byStart[start, default: []].append(ring)
        }
        return byStart.keys.sorted().map { start in
            Block(start: start, end: runEnd[start] ?? start, rings: byStart[start]!.sorted { ($0.date, $0.alarmID.uuidString) < ($1.date, $1.alarmID.uuidString) })
        }
    }

    /// When to tell the user that `occurrence` won't ring.
    ///
    /// A morning alarm is announced the evening before at `eveningHour`, so
    /// there is still time to react before bed. An alarm from noon on is
    /// announced the same morning at `morningHour`. If that moment has already
    /// passed (the event was added late), the notice goes out now, as long as
    /// at least `minimumLead` remains before the ring. Otherwise it returns nil:
    /// a warning a few minutes ahead of a ring that won't happen is just noise.
    public static func noticeDate(for occurrence: Date, now: Date, calendar: Calendar,
                                  eveningHour: Int = 20, morningHour: Int = 9,
                                  minimumLead: TimeInterval = 15 * 60) -> Date? {
        guard occurrence > now else { return nil }
        let day = DateOnly(date: occurrence, calendar: calendar)
        let hour = calendar.component(.hour, from: occurrence)
        let planned: Date?
        if hour < 12 {
            let dayStart = day.startOfDay(in: calendar)
            let before = dayStart.flatMap { calendar.date(byAdding: .day, value: -1, to: $0) }
            planned = before.map { DateOnly(date: $0, calendar: calendar) }?
                .date(hour: eveningHour, minute: 0, in: calendar)
        } else {
            planned = day.date(hour: morningHour, minute: 0, in: calendar)
        }
        if let planned, planned > now, planned < occurrence { return planned }
        return occurrence.timeIntervalSince(now) >= minimumLead ? now : nil
    }

    /// What a block's notice needs now, given what the user has already been shown.
    public enum NoticeAction: Equatable, Sendable {
        case none
        /// Tell the user: at that moment, or right away if it is `now`.
        case announce(at: Date)
        /// Nothing new to tell, but the notice on screen claims rings that will
        /// now happen (Ring anyway on one alarm, an alarm deleted) or is missing
        /// (a run split in two). Replace it quietly, without a banner.
        case correct
    }

    /// - `rings`: the block's rings now (all after `now`).
    /// - `onScreen`: the rings this block's notice listed when it was shown, or
    ///   nil if it hasn't been shown yet.
    /// - `told`: every ring any shown notice has listed.
    ///
    /// A vacation is announced once: as its days pass, its notice lists fewer
    /// rings but nothing new, so it stays as it is. A ring nobody announced
    /// (an alarm added to the vacation, a new time, an undone Ring anyway) is
    /// announced again, on the usual schedule.
    public static func noticeAction(rings: Set<Ring>, onScreen: Set<Ring>?, told: Set<Ring>,
                                    now: Date, calendar: Calendar) -> NoticeAction {
        guard !rings.isEmpty else { return .none }
        if rings.isSubset(of: told) {
            return onScreen?.filter({ $0.date > now }) == rings ? .none : .correct
        }
        // Timed by the block's first ring, unless that one is minutes away:
        // then by the next ring that can still be warned about (a new 8:00
        // alarm on a holiday morning, while the 6:30 one is about to be skipped).
        let at = rings.map(\.date).sorted().lazy
            .compactMap { noticeDate(for: $0, now: now, calendar: calendar) }.first
        return at.map { .announce(at: $0) } ?? .none
    }
}
