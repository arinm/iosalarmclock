import Foundation

/// Pure rules for fitting heads-up notifications under iOS's limit.
///
/// iOS holds at most 64 pending local notifications per app. Punctual arms up
/// to a week of rings per alarm and each ring wants a heads-up (Pro adds more
/// for the next ring), so a busy install wants more than iOS will hold. Past
/// the cap iOS discards requests silently and on its own terms, so a calendar
/// notice could go too. Here every alarm shares one budget instead, with room
/// kept for the calendar notices: the soonest heads-ups are set now and the
/// rest wait for a later refresh, which runs every time the app opens.
public enum HeadsUpPlanner {

    /// iOS's cap on pending local notifications for one app.
    public static let systemLimit = 64
    /// Slots kept for calendar-skip notices while any alarm uses calendar
    /// auto-skip. They say an alarm WON'T ring and so come before any heads-up.
    /// There is at most one per run of days off inside their 10-day horizon,
    /// so 8 is room to spare.
    public static let calendarReserve = 8
    /// A heads-up that waits is worth a note to the user only this close to
    /// it. Every alarm is armed at least 3 days ahead, and any visit before
    /// then sets the heads-ups that were waiting.
    public static let noteHorizon: TimeInterval = 3 * 24 * 3600

    /// What one alarm wants heads-ups for.
    public struct Alarm: Sendable {
        public let id: UUID
        /// The rings armed for it.
        public let occurrences: [Date]
        public let minutesBefore: Int
        /// Pro extra heads-ups, for the next ring only.
        public let extraMinutesBefore: [Int]

        public init(id: UUID, occurrences: [Date], minutesBefore: Int, extraMinutesBefore: [Int] = []) {
            self.id = id
            self.occurrences = occurrences
            self.minutesBefore = minutesBefore
            self.extraMinutesBefore = extraMinutesBefore
        }
    }

    public struct HeadsUp: Hashable, Sendable {
        public let alarmID: UUID
        public let occurrence: Date
        public let minutesBefore: Int

        /// When the notification shows.
        public var fireDate: Date { occurrence.addingTimeInterval(-TimeInterval(minutesBefore * 60)) }
    }

    public struct Plan: Equatable, Sendable {
        /// Set now, soonest first.
        public let scheduled: [HeadsUp]
        /// Over the limit, soonest first; a later refresh sets them.
        public let waiting: [HeadsUp]
    }

    /// Every heads-up the alarms want that is still ahead, soonest first: each
    /// offset for an alarm's next ring, the main one only for the rings after
    /// it (all offsets on a week of rings could cost 28 per alarm).
    public static func wanted(_ alarms: [Alarm], now: Date) -> [HeadsUp] {
        var out: [HeadsUp] = []
        for alarm in alarms {
            let rings = alarm.occurrences.filter { $0 > now }.sorted()
            guard let next = rings.first else { continue }
            for minutes in Set([alarm.minutesBefore] + alarm.extraMinutesBefore) {
                out.append(HeadsUp(alarmID: alarm.id, occurrence: next, minutesBefore: minutes))
            }
            for ring in rings.dropFirst() {
                out.append(HeadsUp(alarmID: alarm.id, occurrence: ring, minutesBefore: alarm.minutesBefore))
            }
        }
        // Ties (two alarms at the same minute) break on the id, so a refresh
        // never swaps which one waits.
        return out.filter { $0.fireDate > now }.sorted {
            ($0.fireDate, $0.alarmID.uuidString, $0.minutesBefore) < ($1.fireDate, $1.alarmID.uuidString, $1.minutesBefore)
        }
    }

    /// The soonest `limit` heads-ups are set; the rest wait.
    public static func plan(_ alarms: [Alarm], now: Date, limit: Int) -> Plan {
        let all = wanted(alarms, now: now)
        let cut = min(max(0, limit), all.count)
        return Plan(scheduled: Array(all[..<cut]), waiting: Array(all[cut...]))
    }

    /// Slots heads-ups may use, given the other notifications pending:
    /// `calendarNotices` of ours, `others` of any other kind. `calendarInUse`:
    /// some alarm uses calendar auto-skip, so the reserve is kept; without it
    /// no notice can come and heads-ups get every slot.
    public static func limit(calendarNotices: Int, others: Int, calendarInUse: Bool) -> Int {
        max(0, systemLimit - max(calendarInUse ? calendarReserve : 0, calendarNotices) - others)
    }
}
