import Foundation
import UserNotifications
import AlarmCore

/// The safety net for calendar auto-skip: a calendar-derived skip is never
/// silent. Ahead of the rings the calendar takes away, the user gets a notice.
///
/// It exists because calendars are noisy. Apple's own US and German holiday
/// calendars list working-day observances (Tax Day, Election Day, Rosenmontag)
/// exactly like real holidays, and without a notice the only symptom of a wrong
/// skip is waking up late. For an alarm app that is the one unacceptable
/// failure.
///
/// It must not become noise either, so notices are grouped and quiet:
///   • ONE notice per run of consecutive days off, across ALL alarms. A
///     holiday that silences three alarms is one notice, and a two-week
///     vacation is one notice before it starts, not one every evening.
///   • A single-day notice carries **Ring anyway**, which restores that day for
///     every alarm it lists. A multi-day one only opens the app, where each day
///     can be changed.
///   • No sound. It shows on screen and in Notification Center, but it doesn't
///     chime in the evening.
///
/// Compiled into the widget extension too (AlarmStore references it). Only the
/// app adds notices, because only the app has just read the calendars. See `sync`.
@MainActor
final class CalendarSkipNotifier {

    static let categoryID = "PUNCTUAL_CALENDAR_SKIP"              // one day: Ring anyway + Open
    static let rangeCategoryID = "PUNCTUAL_CALENDAR_SKIP_RANGE"   // several days: Open
    static let ringAnywayActionID = "RING_ANYWAY"
    static let dayKey = "skipDay"            // userInfo: "yyyy-mm-dd" Ring anyway applies to
    static let alarmIDsKey = "alarmIDs"      // userInfo: the alarms that notice covers
    /// Notices are scheduled for rings this close; every foreground re-syncs.
    static let horizonDays = 10
    /// How far ahead rings are always looked for. A run of days off that goes
    /// on longer is followed to its end (`CalendarSkipPlanner.lookaheadEnd`).
    private static let lookaheadDays = 60

    static let prefix = "calskip-"
    /// What each notice listed and when it shows, so a refresh tells the user
    /// only what they haven't been told (`CalendarSkipPlanner.noticeAction`).
    private static let shownKey = "calendarSkipNoticesShown"

    private struct Shown: Codable {
        var at: Date                                  // when this version shows, or showed
        var rings: Set<CalendarSkipPlanner.Ring>      // what it lists
        /// While this version waits to show: what the one already shown lists.
        /// Scheduling a newer version doesn't unsay the old one.
        var before: Set<CalendarSkipPlanner.Ring>? = nil

        /// What the user has been shown of this notice by `now`, or nil if nothing yet.
        func seen(by now: Date) -> Set<CalendarSkipPlanner.Ring>? { at <= now ? rings : before }
    }

    private let center = UNUserNotificationCenter.current()

    static var categories: [UNNotificationCategory] {
        let ring = UNNotificationAction(identifier: ringAnywayActionID, title: String(localized: "Ring anyway", bundle: AppLanguage.bundle),
                                        options: []) // handled in background, like Skip today
        let open = UNNotificationAction(identifier: PreAlertNotificationManager.openActionID,
                                        title: String(localized: "Open", bundle: AppLanguage.bundle), options: [.foreground])
        return [UNNotificationCategory(identifier: categoryID, actions: [ring, open], intentIdentifiers: [], options: []),
                UNNotificationCategory(identifier: rangeCategoryID, actions: [open], intentIdentifiers: [], options: [])]
    }

    static func day(from info: [AnyHashable: Any]) -> DateOnly? {
        guard let raw = info[dayKey] as? String else { return nil }
        let parts = raw.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return DateOnly(year: parts[0], month: parts[1], day: parts[2])
    }

    static func alarmIDs(from info: [AnyHashable: Any]) -> [UUID] {
        (info[alarmIDsKey] as? [String] ?? []).compactMap(UUID.init(uuidString:))
    }

    /// Bring all notices in line with what the calendar takes away now.
    /// `titles` = the chosen calendars' all-day events per day, for the copy.
    /// Empty `titles` means the caller didn't read the calendars, e.g. the
    /// widget's skip intent or a background launch for a notification action.
    /// Such a caller only REMOVES stale notices and never adds. It also has its
    /// own UserDefaults, so it can't see `shown` and would re-post delivered
    /// warnings. The next in-app refresh adds whatever is missing.
    func sync(items: [AlarmItem], titles: [DateOnly: [String]], now: Date = .now, calendar: Calendar = .current) async {
        var shown = Self.loadShown()
        let pending = Set(await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(Self.prefix) })
        let delivered = Set(await center.deliveredNotifications().map(\.request.identifier).filter { $0.hasPrefix(Self.prefix) })

        // Every ring the calendar removes, from every opted-in alarm.
        var rings: [CalendarSkipPlanner.Ring] = []
        var daysOff = Set<DateOnly>()
        var byID: [UUID: AlarmItem] = [:]
        let opted = items.filter { $0.isEnabled && $0.autoSkipOnCalendarEvents && !$0.autoSkippedDates.isEmpty }
        for item in opted {
            byID[item.id] = item
            daysOff.formUnion(item.autoSkippedDates)
        }
        if let until = CalendarSkipPlanner.lookaheadEnd(daysOff: daysOff, now: now, calendar: calendar,
                                                         minimumDays: Self.lookaheadDays) {
            for item in opted {
                rings += CalendarSkipPlanner.suppressedOccurrences(
                    schedule: item.scheduleIgnoringCalendar, calendarSkips: Set(item.autoSkippedDates),
                    after: now, until: until, calendar: calendar)
                    .map { CalendarSkipPlanner.Ring(alarmID: item.id, date: $0) }
            }
        }
        let horizon = calendar.date(byAdding: .day, value: Self.horizonDays, to: now) ?? now
        // Every ring a notice already shown has listed, swiped away or not.
        let told = shown.values.reduce(into: Set<CalendarSkipPlanner.Ring>()) { $0.formUnion($1.seen(by: now) ?? []) }

        var valid: Set<String> = []
        var toAdd: [(request: UNNotificationRequest, shown: Shown)] = []
        for block in CalendarSkipPlanner.noticeBlocks(rings: rings, daysOff: daysOff, calendar: calendar) {
            guard block.firstRing.date <= horizon else { continue }
            // Named after the run's LAST day: the first one moves as a vacation's days pass.
            let id = Self.prefix + block.end.description
            valid.insert(id)
            guard !titles.isEmpty else { continue }          // see the doc comment
            let blockRings = Set(block.rings)
            let onScreen = shown[id]?.seen(by: now)
            switch CalendarSkipPlanner.noticeAction(rings: blockRings, onScreen: onScreen, told: told,
                                                    now: now, calendar: calendar) {
            case .none:
                // A newer version still waiting to show that adds nothing any
                // more (the alarm it added was deleted): the one shown says it all.
                if let entry = shown[id], entry.at > now, let before = entry.before, blockRings.isSubset(of: told) {
                    center.removePendingNotificationRequests(withIdentifiers: [id])
                    shown[id] = Shown(at: now, rings: before)
                }
                continue
            case .announce(let at):
                let later = at > now
                toAdd.append((request(id: id, block: block, alarms: byID, at: later ? at : nil, quiet: false,
                                      titles: titles, calendar: calendar),
                              Shown(at: at, rings: blockRings, before: later ? onScreen : nil)))
            case .correct:
                // Only a notice still in Notification Center is corrected. One
                // swiped away was read, so it doesn't come back, not even as part
                // of a run that split in two. It now covers only these rings, so
                // one that returns is announced.
                let inCenter = onScreen != nil
                    ? delivered.contains(id)
                    : shown.contains { delivered.contains($0.key) && !($0.value.seen(by: now) ?? []).isDisjoint(with: blockRings) }
                if !inCenter {
                    if pending.contains(id) { center.removePendingNotificationRequests(withIdentifiers: [id]) }
                    shown[id] = Shown(at: now, rings: blockRings)
                    continue
                }
                toAdd.append((request(id: id, block: block, alarms: byID, at: nil, quiet: true,
                                      titles: titles, calendar: calendar),
                              Shown(at: now, rings: blockRings)))
            }
        }

        // Drop what no longer applies (Ring anyway, event removed, alarm edited):
        // pending ones so they never fire, delivered ones so Notification Center
        // doesn't keep claiming an alarm won't ring when it will.
        let stalePending = pending.filter { !valid.contains($0) }
        if !stalePending.isEmpty { center.removePendingNotificationRequests(withIdentifiers: Array(stalePending)) }
        let staleDelivered = delivered.filter { !valid.contains($0) }
        if !staleDelivered.isEmpty { center.removeDeliveredNotifications(withIdentifiers: Array(staleDelivered)) }

        // Same id: a correction replaces the delivered notice, a reschedule the pending one.
        for (req, record) in toAdd {
            do { try await center.add(req); shown[req.identifier] = record } catch {}
        }
        // Forget ids that no longer apply, so a skip that comes BACK later
        // (Ring anyway undone, event re-added) is announced again.
        Self.saveShown(shown.filter { valid.contains($0.key) })
    }

    private static func loadShown() -> [String: Shown] {
        guard let data = UserDefaults.standard.data(forKey: shownKey) else { return [:] }
        return (try? JSONDecoder().decode([String: Shown].self, from: data)) ?? [:]
    }

    private static func saveShown(_ shown: [String: Shown]) {
        guard let data = try? JSONEncoder().encode(shown) else { return }
        UserDefaults.standard.set(data, forKey: shownKey)
    }

    /// `quiet`: a correction of a notice the user has already seen. It goes
    /// straight to Notification Center, without a banner.
    private func request(id: String, block: CalendarSkipPlanner.Block, alarms: [UUID: AlarmItem], at: Date?,
                         quiet: Bool, titles: [DateOnly: [String]], calendar: Calendar) -> UNNotificationRequest {
        let seenAt = at ?? .now
        let firstDay = DateOnly(date: block.firstRing.date, calendar: calendar)
        let lastDay = DateOnly(date: block.lastRing.date, calendar: calendar)
        let ids = block.rings.map(\.alarmID).reduce(into: [UUID]()) { if !$0.contains($1) { $0.append($1) } }

        // Why: the events behind these days, without repeats ("Concediu", not
        // "Concediu, Concediu, …").
        var reasons: [String] = []
        var d = firstDay
        while d <= lastDay {
            for t in titles[d] ?? [] where !reasons.contains(t) { reasons.append(t) }
            guard let next = d.startOfDay(in: calendar).flatMap({ calendar.date(byAdding: .day, value: 1, to: $0) }) else { break }
            d = DateOnly(date: next, calendar: calendar)
        }
        let reason = reasons.isEmpty ? String(localized: "an all-day event", bundle: AppLanguage.bundle)
            : ListText.joined(Array(reasons.prefix(2))
                + (reasons.count > 2 ? [String(localized: "more", bundle: AppLanguage.bundle, comment: "Last item of a list of event names: A, B and more")] : []))

        let content = UNMutableNotificationContent()
        content.sound = nil // seen, not heard: no chime in the evening
        if quiet { content.interruptionLevel = .passive }
        if block.spansSeveralDays(calendar) {
            // A vacation or long weekend: one notice before it starts.
            let range = Self.rangeFormatter.string(from: block.firstRing.date, to: block.lastRing.date)
            if ids.count == 1, let item = alarms[ids[0]] {
                content.title = String(localized: "Your \(Self.time(item)) alarm is off \(range)", bundle: AppLanguage.bundle)
                content.body = String(localized: "\(Self.name(item)) · skipped for \(reason), from your calendar. Open Punctual to ring on any of these days.", bundle: AppLanguage.bundle)
            } else {
                content.title = String(localized: "\(ids.count) alarms are off \(range)", bundle: AppLanguage.bundle)
                content.body = String(localized: "\(Self.list(ids, alarms)) · skipped for \(reason), from your calendar. Open Punctual to ring on any of these days.", bundle: AppLanguage.bundle)
            }
            content.categoryIdentifier = Self.rangeCategoryID
        } else {
            let when = Self.relativeDay(block.firstRing.date, seenAt: seenAt, calendar: calendar)
            if ids.count == 1, let item = alarms[ids[0]] {
                content.title = String(localized: "\(when)'s \(Self.time(item)) alarm won't ring", bundle: AppLanguage.bundle)
                content.body = String(localized: "\(Self.name(item)) · skipped for \(reason), from your calendar. Need it? Tap Ring anyway.", bundle: AppLanguage.bundle)
            } else {
                content.title = String(localized: "\(when), \(ids.count) alarms won't ring", bundle: AppLanguage.bundle)
                content.body = String(localized: "\(Self.list(ids, alarms)) · skipped for \(reason), from your calendar. Need them? Tap Ring anyway.", bundle: AppLanguage.bundle)
            }
            content.categoryIdentifier = Self.categoryID
        }
        content.userInfo = [
            Self.dayKey: firstDay.description,
            Self.alarmIDsKey: ids.map(\.uuidString)
        ]
        let trigger = at.map {
            UNCalendarNotificationTrigger(
                dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: $0),
                repeats: false)
        }
        return UNNotificationRequest(identifier: id, content: content, trigger: trigger)
    }

    // MARK: Copy helpers

    private static func name(_ item: AlarmItem) -> String { item.label.isEmpty ? String(localized: "Alarm", bundle: AppLanguage.bundle) : item.label }

    private static func time(_ item: AlarmItem) -> String {
        TimeText.string(hour: item.hour, minute: item.minute)
    }

    /// "6:30 AM Wake up, 8:00 AM Meds" (three at most, then "and N more").
    private static func list(_ ids: [UUID], _ alarms: [UUID: AlarmItem]) -> String {
        let named = ids.compactMap { alarms[$0] }.map { "\(time($0)) \(name($0))" }
        let shown = Array(named.prefix(3)) + (named.count > 3 ? [String(localized: "\(named.count - 3) more", bundle: AppLanguage.bundle, locale: AppLanguage.locale)] : [])
        return ListText.joined(shown)
    }

    /// "Today" / "Tomorrow" / "Tuesday", relative to when the notice is READ.
    private static func relativeDay(_ ring: Date, seenAt: Date, calendar: Calendar) -> String {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: seenAt),
                                           to: calendar.startOfDay(for: ring)).day ?? 0
        switch days {
        case 0: return String(localized: "Today", bundle: AppLanguage.bundle)
        case 1: return String(localized: "Tomorrow", bundle: AppLanguage.bundle)
        default: return DayText.weekdayName(ring, calendar: calendar, context: .beginningOfSentence)
        }
    }

    /// "Mon, Dec 22 – Fri, Dec 26" / "12月22日(月)～26日(金)", in the region's order.
    private static var rangeFormatter: DateIntervalFormatter {
        let f = DateIntervalFormatter(); f.locale = AppLanguage.locale; f.dateTemplate = "EEEdMMM"; return f
    }
}
