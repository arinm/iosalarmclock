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
        // Only the AlarmKit reschedule (which reads/writes armedOccurrences) needs
        // serializing against other reschedules — the insert above is instant.
        await serialized {
            await self.scheduler.reschedule(item, force: true)
            self.save()
        }
    }

    /// Returns `true` if this edit stopped a snooze that was counting down — so
    /// the caller can tell the user (a moved alarm supersedes the old snooze).
    @discardableResult
    func update(_ item: AlarmItem, _ mutate: (AlarmItem) -> Void) async -> Bool {
        // Snapshot the fields that define WHEN the alarm rings, so we can tell a
        // genuine reschedule from a label/sound-only edit (see below).
        let (h0, m0, mode0, days0, date0) =
            (item.hour, item.minute, item.mode, item.repeatWeekdays, item.oneTimeDate)

        // Apply the semantic change (skip mark, new label, isEnabled…) and commit
        // it SYNCHRONOUSLY: the UI (e.g. a toggle bound to isEnabled) reflects it
        // in the same runloop turn instead of snapping back while a refresh ahead
        // of us in the serial chain runs, and a sibling process reconciling never
        // sees an uncommitted change. Only the AlarmKit reschedule — which
        // read-modify-writes armedOccurrences — must be serialized against other
        // reschedules, so just that part enters the chain.
        mutate(item)
        item.touch()
        save()

        // Did the user actually MOVE the alarm (time / mode / repeat days / date)?
        let rescheduled = item.hour != h0 || item.minute != m0 || item.mode != mode0
            || item.repeatWeekdays != days0 || item.oneTimeDate != date0
        // Was a snooze actually counting down at that moment? (Only then do we
        // tell the user we stopped it — reflects the "Snoozing" state they see.)
        let stoppedSnooze = rescheduled && snoozingItemIDs.contains(item.id)

        // Force the slow path: armed alarms bake in configuration (label, snooze,
        // tint) that the scheduler's date-window comparison can't see.
        await serialized {
            // Moving the alarm supersedes any snooze still counting down from a
            // PRIOR firing: without this, the reschedule arms the new time but the
            // old snooze also re-rings (reschedule keeps past-dated snoozes so a
            // passive refresh can't silence a live one). Cancel it ONLY on a real
            // reschedule — label/sound edits, skip, pause and passive refreshes
            // leave a running snooze untouched.
            if rescheduled {
                await self.scheduler.cancelRunningSnooze(item)
                self.snoozingItemIDs.remove(item.id)   // drop the "Snoozing" pill
            }
            await self.scheduler.reschedule(item, force: true)
            self.save()
        }
        return stoppedSnooze
    }

    func delete(_ item: AlarmItem) async {
        // Silence immediately, ahead of the serial chain, so a delete lands even if
        // a refresh is in flight; the serialized cancel then clears state for real.
        await scheduler.eagerSilence(item)
        await serialized {
            await self.scheduler.cancel(item)
            self.context.delete(item)
            self.save()
        }
    }

    func setEnabled(_ item: AlarmItem, _ enabled: Bool) async {
        guard !enabled else {
            await update(item) { $0.isEnabled = true }
            return
        }
        // Turning an alarm OFF must be honoured instantly. Persist the disabled
        // state first (so any in-flight/subsequent refresh recomputes it as
        // disabled and won't re-arm), silence AlarmKit eagerly outside the serial
        // chain (so the ring stops now, not after a queued refresh drains), then
        // run the authoritative reschedule to clear armedOccurrences.
        item.isEnabled = false
        item.touch()
        save()
        await scheduler.eagerSilence(item)
        await serialized {
            await self.scheduler.reschedule(item, force: true)
            self.save()
        }
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

    // MARK: - Serialization

    /// Tail of the scheduling operation chain. EVERY mutation + reschedule + save
    /// runs as one link that first awaits the previous link. MainActor already
    /// rules out data races, but MainActor tasks INTERLEAVE at `await` points, so
    /// without this two reschedules for the same alarm (e.g. an `update` and the
    /// fire-observer's `refreshAllSchedules`) could interleave across the
    /// `await cancel`/`await schedule` inside `AlarmScheduler.reschedule` and the
    /// last writer would persist an `armedOccurrences` that omits an occurrence
    /// still armed in AlarmKit — an un-cancellable "phantom" alarm. Serializing
    /// the whole critical section closes that window.
    ///
    /// INVARIANT: code already inside a `serialized` block must call the private
    /// cores / `scheduler` directly, NEVER another public method that serializes,
    /// or the chain self-deadlocks. (Composite ops like groups/duplicate stay
    /// OUTSIDE and drive the public leaves, so each leaf is its own link.)
    private var scheduleTail: Task<Void, Never>?

    /// True only for the duration of a `serialized` op's own `work()`, propagated
    /// down its task tree (a TaskLocal, so a CONCURRENT enqueue from a different
    /// task during our `await` doesn't see it — only a genuinely NESTED call
    /// does). This turns the "never call a serializing method from inside a
    /// serialized block" invariant into a loud DEBUG crash instead of a silent
    /// permanent deadlock of the whole scheduling chain.
    @TaskLocal private static var inSchedulingSection = false

    private func serialized<T>(_ work: @escaping @MainActor () async -> T) async -> T {
        // Re-entrancy would deadlock the chain (a nested op awaits the tail that
        // already contains its own parent). It must never happen by construction;
        // if a future edit breaks that, crash LOUDLY in DEBUG and DEGRADE SAFELY
        // in release by running inline (unserialized) rather than permanently
        // bricking all scheduling. `assertionFailure` is a no-op in release, so
        // control falls through to the inline run there.
        if Self.inSchedulingSection {
            assertionFailure("Re-entrant serialized(): a scheduling leaf called another method that serializes. Running inline to avoid a permanent deadlock — fix the call to use the private cores / scheduler directly.")
            return await work()
        }
        let prior = scheduleTail
        let op = Task { @MainActor () -> T in
            await prior?.value
            return await Self.$inSchedulingSection.withValue(true) { await work() }
        }
        scheduleTail = Task { @MainActor in _ = await op.value }
        return await op.value
    }

    // MARK: - Lifecycle

    /// Recompute & re-arm everything. Called on launch and on `scenePhase` active
    /// to compensate for AlarmKit having no native skip/recurrence-with-exceptions.
    /// Serialized against all mutations (see `serialized`) so a refresh pass can't
    /// interleave with an edit and leak an armed occurrence.
    ///
    /// `liveAlarmIDs` is the authoritative current alarm set (forwarded by the
    /// AlarmKit fire observer). When `nil` (launch/foreground/BG paths) it is
    /// read directly from the system, so persisted-vs-reality drift — including
    /// arms that silently failed or were cancelled externally — heals on every
    /// pass, not just observer-driven ones.
    func refreshAllSchedules(liveAlarmIDs: Set<UUID>? = nil) async {
        // Resolve the Pro calendar auto-skip days OUTSIDE the serial lock: it's a
        // potentially slow EventKit query, and holding it inside the serialized
        // refresh would make a user's disable/skip (queued behind this pass) wait
        // it out — long enough that a just-disabled alarm could still fire. The
        // result is a plain value set; only APPLYING it needs the lock.
        let calendarDays = await calendarSkipDaysIfNeeded()
        await serialized {
            await self.refreshPass(liveAlarmIDs: liveAlarmIDs ?? self.scheduler.currentLiveAlarmIDs(),
                                   calendarDays: calendarDays)
        }
    }

    /// The EventKit-derived skip days, or empty when no alarm opts in (so we never
    /// pay for the query needlessly). Read-only; safe to run outside the lock.
    private func calendarSkipDaysIfNeeded() async -> Set<DateOnly> {
        guard allAlarms().contains(where: { $0.autoSkipOnCalendarEvents }) else { return [] }
        return await calendarAutoSkip.skipDays(within: 60, calendar: .current)
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
            let now = Date.now
            for item in allAlarms() where item.snooze.isEnabled {
                // Only occurrences that already FIRED (past-dated) count as a
                // snooze. A future-dated occurrence in `.countdown` is the
                // PRE-ALERT countdown (CountdownDuration.preAlert), not a snooze
                // — without this filter it would falsely announce "Snoozed" and
                // show the stop-snooze button 15 min before every alarm.
                let fired = item.recentlyFiredOccurrences + item.armedOccurrences.filter { $0 <= now }
                for date in fired {
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
        await serialized {
            await self.scheduler.cancelRunningSnooze(item)
            self.snoozingItemIDs.remove(item.id)
            self.save()
        }
    }

    /// How long an id must look like an orphan before it's purged — a grace
    /// window so a sibling process's just-armed occurrence (not yet visible in
    /// this context's fetch) isn't cancelled before we observe its save.
    private let orphanGrace: TimeInterval = 30
    private let orphanSeenKey = "orphanFirstSeen.v1"
    /// The "first seen as an orphan" timestamps, PERSISTED in the app group so
    /// the grace clock survives relaunch: a real legacy orphan sighted in one
    /// short session is still purgeable in the next (in-memory it would reset
    /// every launch and might never clear). A deterministically re-armed
    /// occurrence simply stops being a suspect and drops out of the map.
    private var orphanFirstSeenCache: [UUID: Date]?
    private var orphanDefaults: UserDefaults? { UserDefaults(suiteName: SharedModelContainer.appGroupID) }

    private func loadOrphanFirstSeen() -> [UUID: Date] {
        if let cached = orphanFirstSeenCache { return cached }
        var map: [UUID: Date] = [:]
        if let raw = orphanDefaults?.dictionary(forKey: orphanSeenKey) as? [String: Double] {
            for (key, epoch) in raw {
                if let id = UUID(uuidString: key) { map[id] = Date(timeIntervalSince1970: epoch) }
            }
        }
        orphanFirstSeenCache = map
        return map
    }

    private func saveOrphanFirstSeen(_ map: [UUID: Date]) {
        orphanFirstSeenCache = map
        let raw = Dictionary(uniqueKeysWithValues: map.map { ($0.key.uuidString, $0.value.timeIntervalSince1970) })
        orphanDefaults?.set(raw, forKey: orphanSeenKey)
    }

    private func refreshPass(liveAlarmIDs: Set<UUID>?, calendarDays: Set<DateOnly>) async {
        let items = allAlarms()

        // Calendar auto-skip (Pro): REPLACE each opted-in alarm's derived
        // auto-skip set each refresh (so removed/changed events reconcile and the
        // set never grows unbounded). Disabled alarms get it cleared. `calendarDays`
        // was resolved by the caller OUTSIDE the lock (EventKit query) — here we
        // only apply it.
        let today = DateOnly(date: .now, calendar: .current)
        for item in items {
            let desired = item.autoSkipOnCalendarEvents
                ? Array(calendarDays.filter { $0 >= today })
                : []
            if Set(item.autoSkippedDates) != Set(desired) { item.autoSkippedDates = desired }
        }

        for item in items { await scheduler.reschedule(item, liveAlarmIDs: liveAlarmIDs) }
        save()

        // Second direction of reconciliation: cancel alarms the SYSTEM still holds
        // that no alarm legitimately wants. Runs AFTER the re-arm loop so the just-
        // armed window is already in `armedOccurrences` and in the live read below.
        await purgeOrphans(items)
    }

    /// Cancel AlarmKit alarms the system holds that belong to no tracked
    /// occurrence — "orphans". Reschedule only ever RE-ARMS missing occurrences and
    /// never removes extra ones, so an occurrence armed in AlarmKit but later
    /// dropped from `armedOccurrences` (a cross-process clobber, a crash mid-arm,
    /// or an id-derivation change across app versions) would ring forever with
    /// nothing able to cancel it. This closes that gap.
    ///
    /// Safety, in order of importance:
    ///  - FAIL CLOSED: if the live set is unreadable, purge nothing (never cancel
    ///    real alarms on a bad read).
    ///  - PRESERVE ACTIVE: never touch an alarm that is alerting / snoozing /
    ///    paused right now (its occurrence may already have left the tracked set).
    ///  - PRESERVE TRACKED: keep every occurrence any alarm currently wants.
    ///  - GRACE WINDOW: only purge an id that has looked like an orphan for
    ///    `orphanGrace`, so a sibling process's freshly-armed occurrence (not yet
    ///    merged into this context) survives until we can see it.
    private func purgeOrphans(_ items: [AlarmItem], now: Date = .now) async {
        // ONE snapshot → both the full live set and the active (non-.scheduled)
        // subset. Fail CLOSED: an unreadable snapshot decides nothing and, crucially,
        // does NOT touch the persisted grace timers (a transient bad read must not
        // reset an orphan's clock).
        guard let snapshot = scheduler.alarmSnapshot() else { return }

        var legit = Set<UUID>()
        for item in items {
            for date in Set(item.armedOccurrences + item.recentlyFiredOccurrences) {
                legit.insert(AlarmKitManager.occurrenceID(item: item.id, date: date))
            }
        }
        // Preserve everything we legitimately track PLUS everything alerting /
        // snoozing / paused right now (its occurrence may already have left the
        // tracked dates — this is the sole guard for a live ring).
        let preserve = legit.union(snapshot.active)
        let suspects = snapshot.all.subtracting(preserve)

        var seen = loadOrphanFirstSeen()
        var toPurge = Set<UUID>()
        var stillPending: [UUID: Date] = [:]
        for id in suspects {
            let firstSeen = seen[id] ?? now
            if now.timeIntervalSince(firstSeen) >= orphanGrace {
                toPurge.insert(id)
            } else {
                stillPending[id] = firstSeen   // keep waiting out the grace window
            }
        }
        // Persist only the ids still on the clock — purged ones and no-longer-
        // suspect ones drop out.
        seen = stillPending
        saveOrphanFirstSeen(seen)

        if !toPurge.isEmpty { await scheduler.purgeAlarmIDs(toPurge) }

        // If any suspect is still within its grace window, purge only re-runs on
        // the next external event (foreground/observer/fire) — which, for an
        // orphan whose sole upcoming event is its OWN firing, could be too late
        // (it rings once). Arm a single delayed re-check so a sighted orphan is
        // swept ~grace seconds later even in an otherwise idle session.
        if !stillPending.isEmpty { scheduleOrphanRecheck() }
    }

    /// One pending delayed orphan re-check at a time (deduped). Best-effort: if the
    /// app is suspended the sleep won't fire, but the next foreground refresh covers
    /// it. Terminates: once nothing is pending, no new check is armed.
    private var orphanRecheckArmed = false
    private func scheduleOrphanRecheck() {
        guard !orphanRecheckArmed else { return }
        orphanRecheckArmed = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(orphanGrace + 1))
            orphanRecheckArmed = false
            // This Task was born INSIDE a `serialized` op's `withValue(true)` scope
            // (purgeOrphans runs there), and unstructured Tasks inherit task-locals
            // — so without rebinding, the reentrancy guard would see `true` and run
            // refreshPass INLINE (unserialized), defeating the whole chain. Rebind
            // to false so the refresh enqueues normally.
            await Self.$inSchedulingSection.withValue(false) {
                await self.refreshAllSchedules()
            }
        }
    }

    /// Fired after every successful save. The app wires this to push the OUTSIDE
    /// surfaces (widget timeline, Live Activity) so they update the moment data
    /// changes — without it they only refresh on foreground/observer events and
    /// a widget can sit on a stale "No alarms" for hours. Nil in the widget /
    /// intent processes (intents reload timelines themselves).
    var onDidSave: (() -> Void)?

    private func save() {
        do {
            try context.save()
            onDidSave?()
        } catch { print("AlarmStore save failed: \(error)") }
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
