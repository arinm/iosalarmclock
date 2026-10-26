import Foundation
import EventKit
import AlarmCore

/// Pro: reads the calendars the user CHOSE and reports the days that carry an
/// **all-day event** (holidays, vacation, OOO) within a look-ahead window,
/// with the event titles. Alarms with auto-skip enabled skip those days.
///
/// Only explicitly chosen calendars count. The first version read every
/// calendar, which turned birthdays, deadlines, conferences and family
/// calendars into silent no-ring days. Even Apple's own US and German holiday
/// calendars list working-day observances (Tax Day, Election Day, Rosenmontag)
/// exactly like real holidays. Nothing in the data tells them apart, so the
/// choice is the user's, with a preview of what it will skip. Every skip is
/// also announced ahead of time (`CalendarSkipNotifier`).
///
/// NOTE: needs calendar permission + actual all-day events to exercise; build is
/// verifiable but behavior needs a real device/calendar.
@MainActor
final class CalendarAutoSkip {
    private let store = EKEventStore()

    /// One calendar the user can choose, for the picker.
    struct Choice: Identifiable {
        let id: String          // EKCalendar.calendarIdentifier
        let title: String
        let source: String
        let cgColor: CGColor?
    }

    // MARK: - Chosen calendars (shared by every alarm)

    private static let selectionKey = "autoSkipCalendarIDs"

    /// Identifiers of the calendars whose all-day events mean "day off". Empty
    /// until the user picks, and empty means auto-skip skips nothing. An alarm
    /// app must fail toward ringing.
    var selectedCalendarIDs: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: Self.selectionKey) ?? []) }
        set { UserDefaults.standard.set(Array(newValue).sorted(), forKey: Self.selectionKey) }
    }

    /// The chosen calendars that still exist. A missing one stays in the saved
    /// choice (an iCloud calendar may just not have synced yet), it only stops
    /// counting. Without access nothing can be checked, so the choice is returned as is.
    /// Checked off the main actor: a fresh EKEventStore is slow to create.
    func existingSelectedCalendarIDs() async -> Set<String> {
        let ids = selectedCalendarIDs
        guard isAuthorized, !ids.isEmpty else { return ids }
        let existing = await Task.detached(priority: .utility) { () -> Set<String> in
            Set(EKEventStore().calendars(for: .event).filter { $0.type != .birthday }.map(\.calendarIdentifier))
        }.value
        // The choice as it is NOW: a picker tap during the check isn't undone.
        return selectedCalendarIDs.intersection(existing)
    }

    var isAuthorized: Bool {
        EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }

    @discardableResult
    func requestAccess() async -> Bool {
        (try? await store.requestFullAccessToEvents()) ?? false
    }

    /// Every event calendar the user could choose. Birthdays are never offered:
    /// a contact's birthday is not your day off.
    func availableCalendars() -> [Choice] {
        guard isAuthorized else { return [] }
        let fresh = EKEventStore() // picks up calendars added since launch
        return fresh.calendars(for: .event)
            .filter { $0.type != .birthday }
            .map { Choice(id: $0.calendarIdentifier, title: $0.title, source: $0.source.title, cgColor: $0.cgColor) }
            .sorted { ($0.source, $0.title) < ($1.source, $1.title) }
    }

    /// Days within the next `days` that have at least one all-day event in the
    /// chosen calendars, mapped to those events' titles.
    ///
    /// Read fresh on every refresh, never cached: a cache keyed on the saved
    /// choice outlived a deleted event or calendar, so the alarm stayed skipped
    /// after the user had removed the day off. The query runs once per refresh,
    /// off the main actor, and only when an alarm opts in.
    func skipDays(within days: Int = 60, calendar: Calendar, now: Date = .now) async -> [DateOnly: [String]] {
        await query(ids: selectedCalendarIDs, within: days, calendar: calendar, now: now)
    }

    /// The same query for an arbitrary selection: drives the picker's
    /// live "what this will skip" preview while the user is still choosing.
    func preview(ids: Set<String>, within days: Int = 60, calendar: Calendar, now: Date = .now) async -> [DateOnly: [String]] {
        await query(ids: ids, within: days, calendar: calendar, now: now)
    }

    private func query(ids: Set<String>, within days: Int, calendar: Calendar, now: Date) async -> [DateOnly: [String]] {
        guard isAuthorized, !ids.isEmpty,
              let end = calendar.date(byAdding: .day, value: days, to: now) else { return [:] }

        // Run the (potentially slow) EventKit query OFF the main actor. A fresh
        // store is used inside the task because authorization is per-process.
        return await Task.detached(priority: .utility) { () -> [DateOnly: [String]] in
            let store = EKEventStore()
            // Never `calendars: nil` (= every calendar). A chosen calendar that
            // no longer exists simply drops out; birthdays are excluded even if
            // an old selection somehow contains them.
            let chosen = store.calendars(for: .event).filter { ids.contains($0.calendarIdentifier) && $0.type != .birthday }
            guard !chosen.isEmpty else { return [:] }
            let predicate = store.predicateForEvents(withStart: now, end: end, calendars: chosen)
            var days: [DateOnly: [String]] = [:]
            for event in store.events(matching: predicate) where event.isAllDay {
                // A cancelled event, or an invitation the user declined, is not a day off.
                if event.status == .canceled { continue }
                if event.attendees?.contains(where: { $0.isCurrentUser && $0.participantStatus == .declined }) == true { continue }
                let title = (event.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let start = event.startDate ?? now
                // All-day `endDate` is exclusive (start of the day AFTER the last
                // covered day), so iterate while cursor < end and always include start.
                let endExclusive = event.endDate ?? calendar.date(byAdding: .day, value: 1, to: start) ?? start
                var cursor = start
                repeat {
                    let day = DateOnly(date: cursor, calendar: calendar)
                    var titles = days[day] ?? []
                    if !title.isEmpty, !titles.contains(title) { titles.append(title) }
                    days[day] = titles
                    guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
                    cursor = next
                } while cursor < endExclusive
            }
            return days
        }.value
    }
}
