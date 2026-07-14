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
        save()
        await scheduler.reschedule(item, force: true)
        save()
    }

    func update(_ item: AlarmItem, _ mutate: (AlarmItem) -> Void) async {
        mutate(item)
        item.touch()
        // Commit the semantic change (skip mark, new label…) BEFORE touching
        // AlarmKit: the cancel/schedule below emits `alarmUpdates` in every
        // process, and a sibling process reconciling against an *uncommitted*
        // change would re-arm the very occurrence we're removing.
        save()
        // Force the slow path: armed alarms bake in configuration (label,
        // snooze, tint) that the scheduler's date-window comparison can't see.
        await scheduler.reschedule(item, force: true)
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

    /// Remove one specific pause range (used by the pause-confirmation Undo).
    func unpause(_ item: AlarmItem, range: DateRange) async {
        await update(item) { $0.pausedDateRanges.removeAll { $0 == range } }
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

    func unpauseGroup(_ name: String, range: DateRange) async {
        for item in alarms(inGroup: name) { await unpause(item, range: range) }
    }

    // MARK: - Lifecycle

    /// Guards against overlapping runs. `refreshAllSchedules` is triggered from
    /// several places (launch, foreground, background refresh, and the AlarmKit
    /// fire observer) that can fire nearly simultaneously; two concurrent passes
    /// would race on the same SwiftData + AlarmKit state. A request arriving
    /// mid-pass is COALESCED (queued and run once the pass ends), never dropped —
    /// an observer-driven reconcile carries drift information the in-flight pass
    /// didn't have.
    private var isRefreshing = false
    private var queuedRefresh = false

    /// Recompute & re-arm everything. Called on launch and on `scenePhase` active
    /// to compensate for AlarmKit having no native skip/recurrence-with-exceptions.
    ///
    /// `liveAlarmIDs` is the authoritative current alarm set (forwarded by the
    /// AlarmKit fire observer). When `nil` (launch/foreground/BG paths) it is
    /// read directly from the system, so persisted-vs-reality drift — including
    /// arms that silently failed or were cancelled externally — heals on every
    /// pass, not just observer-driven ones.
    func refreshAllSchedules(liveAlarmIDs: Set<UUID>? = nil) async {
        guard !isRefreshing else { queuedRefresh = true; return }
        isRefreshing = true
        defer { isRefreshing = false }

        // Caller's snapshot is valid only for the first pass; any coalesced
        // re-run re-reads the live truth (the queued caller's state is newer).
        var ids = liveAlarmIDs
        repeat {
            queuedRefresh = false
            await refreshPass(liveAlarmIDs: ids ?? scheduler.currentLiveAlarmIDs())
            ids = nil
        } while queuedRefresh
    }

    /// Occurrence ids we've already posted a "Snoozed" note for (in-memory; the
    /// notification id also dedupes visually across relaunches).
    private var announcedSnoozes: Set<UUID> = []

    /// Alarm items that currently have a running snooze — drives the inline
    /// "Snoozing · Stop snooze" affordance on the card. Observable state,
    /// refreshed by `reconcileSnoozes` on every observer event and foreground.
    private(set) var snoozingItemIDs: Set<UUID> = []

    /// Reconcile which of our alarms are snoozing (AlarmKit `.countdown` state),
    /// matched via the deterministic occurrence id against each item's tracked
    /// occurrences. Called AFTER a refresh pass, so a just-fired occurrence is
    /// already captured in `recentlyFiredOccurrences`.
    ///
    /// `announce` — post the "Snoozed" confirmation notification for NEW snoozes.
    /// True only on the observer path (timing is fresh); the foreground path
    /// passes false so reopening the app minutes later doesn't fire a stale note.
    func reconcileSnoozes(snoozingIDs: Set<UUID>, announce: Bool) {
        // Forget past announcements that are no longer snoozing, so the next
        // snooze of a future occurrence gets its own note.
        announcedSnoozes.formIntersection(snoozingIDs)

        var snoozingItems: Set<UUID> = []
        if !snoozingIDs.isEmpty {
            for item in allAlarms() where item.snooze.isEnabled {
                for date in item.recentlyFiredOccurrences + item.armedOccurrences {
                    let oid = AlarmKitManager.occurrenceID(item: item.id, date: date)
                    guard snoozingIDs.contains(oid) else { continue }
                    snoozingItems.insert(item.id)
                    if announce, !announcedSnoozes.contains(oid) {
                        announcedSnoozes.insert(oid)
                        scheduler.announceSnooze(for: item)
                    }
                }
            }
        }
        if snoozingItemIDs != snoozingItems { snoozingItemIDs = snoozingItems }
    }

    /// Stop ONLY the running snooze — the alarm stays enabled and armed for its
    /// next occurrence. This is "silence it for today" without the off/on dance.
    func stopSnooze(_ item: AlarmItem) async {
        await scheduler.cancelRunningSnooze(item)
        snoozingItemIDs.remove(item.id)
        save()
    }

    private func refreshPass(liveAlarmIDs: Set<UUID>?) async {
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

        for item in items { await scheduler.reschedule(item, liveAlarmIDs: liveAlarmIDs) }
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
