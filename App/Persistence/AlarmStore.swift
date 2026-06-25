import Foundation
import SwiftData
import AlarmCore

/// Owns SwiftData CRUD for alarms and delegates (re)scheduling to `AlarmScheduler`
/// after every mutation. Views talk to this; they never schedule directly.
@MainActor
@Observable
final class AlarmStore {
    private let context: ModelContext
    private let scheduler: AlarmScheduler
    let calendarAutoSkip = CalendarAutoSkip()

    init(context: ModelContext, scheduler: AlarmScheduler) {
        self.context = context
        self.scheduler = scheduler
    }

    // MARK: - Reads

    func allAlarms() -> [AlarmItem] {
        let descriptor = FetchDescriptor<AlarmItem>(
            sortBy: [SortDescriptor(\.hour), SortDescriptor(\.minute)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func alarm(with id: UUID) -> AlarmItem? {
        let descriptor = FetchDescriptor<AlarmItem>(predicate: #Predicate { $0.id == id })
        return try? context.fetch(descriptor).first
    }

    /// The soonest upcoming occurrence across all enabled alarms — powers the
    /// big "Next alarm" summary card. Computed *live* via the engine (the cached
    /// `nextOccurrence` field can be stale if time has crossed an occurrence
    /// without a reschedule).
    func nextUpAlarm(now: Date = .now, calendar: Calendar = .current) -> (alarm: AlarmItem, fireDate: Date)? {
        let calc = NextOccurrenceCalculator()
        return allAlarms()
            .compactMap { item -> (AlarmItem, Date)? in
                guard let next = calc.nextOccurrence(for: item.schedule, after: now, calendar: calendar) else { return nil }
                return (item, next)
            }
            .min { $0.1 < $1.1 }
    }

    // MARK: - Writes

    func create(_ item: AlarmItem) async {
        context.insert(item)
        await scheduler.reschedule(item)
        save()
    }

    func update(_ item: AlarmItem, _ mutate: (AlarmItem) -> Void) async {
        mutate(item)
        item.touch()
        await scheduler.reschedule(item)
        save()
    }

    func delete(_ item: AlarmItem) async {
        await scheduler.cancel(item)
        context.delete(item)
        save()
    }

    func setEnabled(_ item: AlarmItem, _ enabled: Bool) async {
        await update(item) { $0.isEnabled = enabled }
    }

    func duplicate(_ item: AlarmItem) async {
        let copy = AlarmItem(
            hour: item.hour,
            minute: item.minute,
            label: item.label.isEmpty ? "" : "\(item.label) copy",
            isEnabled: item.isEnabled,
            mode: item.mode,
            repeatWeekdays: item.repeatWeekdays,
            oneTimeDate: item.oneTimeDate,
            soundName: item.soundName,
            vibrationEnabled: item.vibrationEnabled,
            snooze: item.snooze,
            preAlert: item.preAlert
        )
        // Preserve Pro configuration on duplicate.
        copy.preAlertMessage = item.preAlertMessage
        copy.additionalPreAlertMinutes = item.additionalPreAlertMinutes
        copy.groupName = item.groupName
        copy.autoSkipOnCalendarEvents = item.autoSkipOnCalendarEvents
        await create(copy)
    }

    // MARK: - Skip / Pause (the hero actions)

    /// Skip *only* the next natural occurrence, keeping the alarm enabled. This is
    /// the core "Skip today" behaviour, callable from card, detail, or the
    /// notification action handler. Returns the day that was skipped (for copy).
    @discardableResult
    func skipNextOccurrence(_ item: AlarmItem, now: Date = .now, calendar: Calendar = .current) async -> DateOnly? {
        // Resolve the day from a fresh computation, never the cached field.
        guard let next = NextOccurrenceCalculator()
            .nextOccurrence(for: item.schedule, after: now, calendar: calendar) else { return nil }
        let day = DateOnly(date: next, calendar: calendar)
        await update(item) {
            if !$0.skippedOccurrenceDates.contains(day) {
                $0.skippedOccurrenceDates.append(day)
            }
        }
        return day
    }

    /// Undo a skip for a specific day (used by the "Undo" affordance).
    func unskip(_ item: AlarmItem, day: DateOnly) async {
        await update(item) { $0.skippedOccurrenceDates.removeAll { $0 == day } }
    }

    func pause(_ item: AlarmItem, range: DateRange) async {
        await update(item) { $0.pausedDateRanges.append(range) }
    }

    func clearPauses(_ item: AlarmItem) async {
        await update(item) { $0.pausedDateRanges.removeAll() }
    }

    // MARK: - Groups (Pro bulk actions)

    /// Distinct non-empty group names currently in use.
    func groupNames() -> [String] {
        Array(Set(allAlarms().map(\.groupName).filter { !$0.isEmpty })).sorted()
    }

    func alarms(inGroup name: String) -> [AlarmItem] {
        allAlarms().filter { $0.groupName == name }
    }

    func skipNextInGroup(_ name: String) async {
        for item in alarms(inGroup: name) where item.isEnabled { await skipNextOccurrence(item) }
    }

    func setEnabledGroup(_ name: String, _ enabled: Bool) async {
        for item in alarms(inGroup: name) { await setEnabled(item, enabled) }
    }

    func pauseGroup(_ name: String, range: DateRange) async {
        for item in alarms(inGroup: name) { await pause(item, range: range) }
    }

    // MARK: - Lifecycle

    /// Recompute & re-arm everything. Called on launch and on `scenePhase` active
    /// to compensate for AlarmKit having no native skip/recurrence-with-exceptions.
    func refreshAllSchedules() async {
        let items = allAlarms()

        // Calendar auto-skip (Pro): REPLACE each opted-in alarm's derived
        // auto-skip set each refresh (so removed/changed events reconcile and the
        // set never grows unbounded). Disabled alarms get it cleared.
        let calendarDays = items.contains(where: { $0.autoSkipOnCalendarEvents })
            ? await calendarAutoSkip.skipDays(within: 60, calendar: .current)
            : []
        let today = DateOnly(date: .now, calendar: .current)
        for item in items {
            let desired = item.autoSkipOnCalendarEvents
                ? Array(calendarDays.filter { $0 >= today })
                : []
            if Set(item.autoSkippedDates) != Set(desired) { item.autoSkippedDates = desired }
        }

        for item in items { await scheduler.reschedule(item) }
        save()
    }

    private func save() {
        do { try context.save() }
        catch { print("AlarmStore save failed: \(error)") }
    }

    #if DEBUG
    /// Replace all alarms with a curated set for App Store screenshots
    /// (triggered by the `--seed-demo` launch argument; never ships in release).
    func seedDemoData() {
        for a in allAlarms() { context.delete(a) }
        func make(_ h: Int, _ m: Int, _ label: String, _ days: Set<Weekday>) -> AlarmItem {
            AlarmItem(hour: h, minute: m, label: label, isEnabled: true, mode: .recurring,
                      repeatWeekdays: days, preAlert: PreAlertSettings(isEnabled: true, minutesBefore: 15))
        }
        context.insert(make(6, 30, "Wake up", Weekday.weekdays))
        context.insert(make(7, 15, "Gym", [.monday, .wednesday, .friday]))
        context.insert(make(8, 0, "Meds", Set(Weekday.allCases)))
        context.insert(make(22, 30, "Wind down", Weekday.weekdays))
        save()
    }
    #endif
}
