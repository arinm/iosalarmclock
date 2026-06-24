import Foundation
import EventKit
import AlarmCore

/// Pro: reads the user's calendars and reports days that carry an **all-day
/// event** (holidays, vacation, OOO) within a look-ahead window. Alarms with
/// auto-skip enabled have those days added to their skip set so they don't ring
/// on days off.
///
/// NOTE: needs calendar permission + actual all-day events to exercise; build is
/// verifiable but behavior needs a real device/calendar.
@MainActor
final class CalendarAutoSkip {
    private let store = EKEventStore()

    /// Session cache so a batch reschedule doesn't re-query per alarm.
    private var cache: (expiry: Date, days: Set<DateOnly>)?

    var isAuthorized: Bool {
        EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }

    @discardableResult
    func requestAccess() async -> Bool {
        (try? await store.requestFullAccessToEvents()) ?? false
    }

    /// Days within the next `days` that have at least one all-day event.
    func skipDays(within days: Int = 60, calendar: Calendar, now: Date = .now) async -> Set<DateOnly> {
        guard isAuthorized else { return [] }
        if let cache, cache.expiry > now { return cache.days }
        guard let end = calendar.date(byAdding: .day, value: days, to: now) else { return [] }

        // Run the (potentially slow) EventKit query OFF the main actor. A fresh
        // store is used inside the task because authorization is per-process.
        let result = await Task.detached(priority: .utility) { () -> Set<DateOnly> in
            let store = EKEventStore()
            let predicate = store.predicateForEvents(withStart: now, end: end, calendars: nil)
            let events = store.events(matching: predicate)
            var days: Set<DateOnly> = []
            for event in events where event.isAllDay {
                let start = event.startDate ?? now
                // All-day `endDate` is exclusive (start of the day AFTER the last
                // covered day), so iterate while cursor < end and always include start.
                let endExclusive = event.endDate ?? calendar.date(byAdding: .day, value: 1, to: start) ?? start
                var cursor = start
                repeat {
                    days.insert(DateOnly(date: cursor, calendar: calendar))
                    guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
                    cursor = next
                } while cursor < endExclusive
            }
            return days
        }.value

        cache = (now.addingTimeInterval(30 * 60), result)
        return result
    }

    func invalidateCache() { cache = nil }
}
