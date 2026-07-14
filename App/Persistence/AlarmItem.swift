import Foundation
import SwiftData
import AlarmCore

/// The persisted alarm. SwiftData owns this; everything scheduling-related is
/// derived by projecting it into a pure `AlarmSchedule` (see `schedule`). Keeping
/// the projection one-way means the engine never depends on SwiftData.
@Model
final class AlarmItem {
    @Attribute(.unique) var id: UUID
    var hour: Int
    var minute: Int
    var label: String
    var isEnabled: Bool

    /// Stored as raw string so SwiftData stays happy across schema migrations.
    var modeRaw: String
    /// Weekday raw values (Calendar weekday: 1=Sun ... 7=Sat).
    var repeatWeekdaysRaw: [Int]
    var oneTimeDate: DateOnly?

    var soundName: String?
    var vibrationEnabled: Bool
    /// Pro: optional group name for bulk actions ("" = ungrouped).
    var groupName: String = ""
    /// Pro: auto-skip on days that have an all-day calendar event (holidays/OOO).
    var autoSkipOnCalendarEvents: Bool = false

    // Snooze
    var snoozeEnabled: Bool
    var snoozeDurationMinutes: Int
    var snoozeMaxCount: Int

    // Pre-alert
    var preAlertEnabled: Bool
    var preAlertMinutesBefore: Int
    /// Pro: custom body text for the pre-alert notification (empty = default copy).
    var preAlertMessage: String = ""
    /// Pro: additional pre-alert lead times (minutes), each fires its own heads-up.
    var additionalPreAlertMinutes: [Int] = []

    // Exceptions / holds
    var skippedOccurrenceDates: [DateOnly]
    /// Auto-skip days derived from the calendar (Pro). Kept SEPARATE from manual
    /// skips: recomputed/reconciled each refresh so removed events stop skipping,
    /// and never shown as manual skips. Unioned into `schedule` at read time.
    var autoSkippedDates: [DateOnly] = []
    var pausedDateRanges: [DateRange]

    // Bookkeeping
    var lastScheduledOccurrence: Date?
    var nextOccurrence: Date?
    /// The exact fire dates currently armed in AlarmKit for this alarm. Persisted
    /// so any process/launch can cancel precisely what was armed (deterministic
    /// ids derive cancel targets from these). The source of truth for cancel.
    var armedOccurrences: [Date]
    /// Occurrences that have already fired but may still be alive in AlarmKit as
    /// a running SNOOZE (AlarmKit re-alerts the same occurrence id after the
    /// snooze interval). They drop out of `armedOccurrences` on the first refresh
    /// after firing, so we remember them separately — otherwise disabling or
    /// deleting the alarm can't cancel the pending snooze and it rings anyway.
    /// Pruned to a short recent window; only meaningful while snooze is enabled.
    var recentlyFiredOccurrences: [Date] = []
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        hour: Int,
        minute: Int,
        label: String = "",
        isEnabled: Bool = true,
        mode: AlarmMode = .recurring,
        repeatWeekdays: Set<Weekday> = [],
        oneTimeDate: DateOnly? = nil,
        soundName: String? = nil,
        vibrationEnabled: Bool = true,
        snooze: SnoozeSettings = .default,
        preAlert: PreAlertSettings = .default,
        skippedOccurrenceDates: [DateOnly] = [],
        pausedDateRanges: [DateRange] = [],
        createdAt: Date = .now
    ) {
        self.id = id
        self.hour = hour
        self.minute = minute
        self.label = label
        self.isEnabled = isEnabled
        self.modeRaw = mode.rawValue
        self.repeatWeekdaysRaw = repeatWeekdays.map(\.rawValue).sorted()
        self.oneTimeDate = oneTimeDate
        self.soundName = soundName
        self.vibrationEnabled = vibrationEnabled
        self.snoozeEnabled = snooze.isEnabled
        self.snoozeDurationMinutes = snooze.durationMinutes
        self.snoozeMaxCount = snooze.maxCount
        self.preAlertEnabled = preAlert.isEnabled
        self.preAlertMinutesBefore = preAlert.minutesBefore
        self.skippedOccurrenceDates = skippedOccurrenceDates
        self.pausedDateRanges = pausedDateRanges
        self.armedOccurrences = []
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }
}

extension AlarmItem {
    var mode: AlarmMode {
        get { AlarmMode(rawValue: modeRaw) ?? .recurring }
        set { modeRaw = newValue.rawValue }
    }

    var repeatWeekdays: Set<Weekday> {
        get { Set(repeatWeekdaysRaw.compactMap(Weekday.init(rawValue:))) }
        set { repeatWeekdaysRaw = newValue.map(\.rawValue).sorted() }
    }

    var snooze: SnoozeSettings {
        get { SnoozeSettings(isEnabled: snoozeEnabled, durationMinutes: snoozeDurationMinutes, maxCount: snoozeMaxCount) }
        set {
            snoozeEnabled = newValue.isEnabled
            snoozeDurationMinutes = newValue.durationMinutes
            snoozeMaxCount = newValue.maxCount
        }
    }

    var preAlert: PreAlertSettings {
        get { PreAlertSettings(isEnabled: preAlertEnabled, minutesBefore: preAlertMinutesBefore) }
        set {
            preAlertEnabled = newValue.isEnabled
            preAlertMinutesBefore = newValue.minutesBefore
        }
    }

    /// One-way projection into the pure engine input.
    var schedule: AlarmSchedule {
        AlarmSchedule(
            id: id,
            hour: hour,
            minute: minute,
            isEnabled: isEnabled,
            mode: mode,
            repeatWeekdays: repeatWeekdays,
            oneTimeDate: oneTimeDate,
            skippedOccurrenceDates: Set(skippedOccurrenceDates).union(autoSkippedDates),
            pausedDateRanges: pausedDateRanges
        )
    }

    /// Display-ready status for the current moment.
    func status(now: Date = .now, calendar: Calendar = .current) -> AlarmStatus {
        NextOccurrenceCalculator().status(for: schedule, now: now, calendar: calendar)
    }

    func touch() { updatedAt = .now }
}
