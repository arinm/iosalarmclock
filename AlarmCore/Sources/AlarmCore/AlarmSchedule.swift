import Foundation

/// The *pure* scheduling input. This is a value-type projection of the app's
/// SwiftData `AlarmItem`, containing only what `NextOccurrenceCalculator` needs.
/// Keeping it free of persistence/UI/AlarmKit types is what makes the engine
/// trivially unit-testable.
public struct AlarmSchedule: Codable, Hashable, Sendable, Identifiable {
    public let id: UUID
    public var hour: Int
    public var minute: Int
    public var isEnabled: Bool
    public var mode: AlarmMode
    public var repeatWeekdays: Set<Weekday>
    public var oneTimeDate: DateOnly?
    public var skippedOccurrenceDates: Set<DateOnly>
    public var pausedDateRanges: [DateRange]

    public init(
        id: UUID = UUID(),
        hour: Int,
        minute: Int,
        isEnabled: Bool = true,
        mode: AlarmMode = .recurring,
        repeatWeekdays: Set<Weekday> = [],
        oneTimeDate: DateOnly? = nil,
        skippedOccurrenceDates: Set<DateOnly> = [],
        pausedDateRanges: [DateRange] = []
    ) {
        self.id = id
        self.hour = hour
        self.minute = minute
        self.isEnabled = isEnabled
        self.mode = mode
        self.repeatWeekdays = repeatWeekdays
        self.oneTimeDate = oneTimeDate
        self.skippedOccurrenceDates = skippedOccurrenceDates
        self.pausedDateRanges = pausedDateRanges
    }

    /// True if `day` is suppressed by a skip mark or an active pause range.
    public func isSuppressed(_ day: DateOnly) -> Bool {
        if skippedOccurrenceDates.contains(day) { return true }
        return pausedDateRanges.contains { $0.contains(day) }
    }
}

/// A derived, display-ready description of what an alarm is currently doing.
/// Computed from the schedule + the next occurrence; never persisted.
public enum AlarmStatus: Equatable, Sendable {
    case off                       // toggle is off
    case completed                 // one-time alarm whose date has passed
    case noUpcoming                // enabled but nothing resolves (e.g. all paused)
    case scheduled(next: Date)     // normal: will ring at `next`
    case skippedToday(next: Date)  // today suppressed, still active for `next`
    case paused(until: DateOnly, next: Date?) // inside a pause range
}
