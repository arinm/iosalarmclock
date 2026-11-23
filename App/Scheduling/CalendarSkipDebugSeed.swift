#if DEBUG
import Foundation
import EventKit
import UserNotifications
import AlarmKit
import AlarmCore

/// DEBUG only (`--seed-calendar-skip`): sets up a calendar auto-skip scenario in
/// the simulator so the whole path can be exercised end to end. Never ships.
///   • "Days Off (test)": all-day "Test Holiday" tomorrow → CHOSEN
///   • "Work (test)": all-day "Conference" tomorrow       → NOT chosen, must not skip
///   • every alarm gets auto-skip on
/// Then prints what the app decided, for the test log.
@MainActor
enum CalendarSkipDebugSeed {
    /// Lines of the report; also written to Documents/calskip-seed.txt so a test
    /// script can read it without attaching a console.
    private static var report: [String] = []
    private static func log(_ line: String) {
        print(line); report.append(line)
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            try? report.joined(separator: "\n").write(to: dir.appendingPathComponent("calskip-seed.txt"), atomically: true, encoding: .utf8)
        }
    }

    static func run(store: AlarmStore) async {
        log("[calskip-seed] start")
        let ek = EKEventStore()
        guard (try? await ek.requestFullAccessToEvents()) == true else { log("[calskip-seed] no calendar access"); return }
        log("[calskip-seed] calendar access ok")
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        log("[calskip-seed] notification auth: \(await UNUserNotificationCenter.current().notificationSettings().authorizationStatus.rawValue)")

        let cal = Calendar.current
        guard let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: .now)) else { return }
        let daysOff = calendar(named: "Days Off (test)", in: ek)
        let work = calendar(named: "Work (test)", in: ek)
        addAllDay("Test Holiday", on: tomorrow, to: daysOff, in: ek)
        addAllDay("Conference", on: tomorrow, to: work, in: ek)
        // A 5-day vacation starting in 3 days: must be ONE notice, not five.
        if let start = cal.date(byAdding: .day, value: 3, to: tomorrow) {
            addAllDay("Vacation", on: start, days: 5, to: daysOff, in: ek)
        }

        for item in store.allAlarms() where !item.autoSkipOnCalendarEvents {
            await store.update(item) { $0.autoSkipOnCalendarEvents = true }
        }
        log("[calskip-seed] auto-skip on for all alarms")
        if let id = daysOff?.calendarIdentifier { await store.setAutoSkipCalendars([id]) }
        log("[calskip-seed] selected \(store.autoSkipCalendarIDs)")

        // Report: calendars offered, skips applied, notices pending.
        log("[calskip-seed] offered: \(store.calendarAutoSkip.availableCalendars().map(\.title))")
        log("[calskip-seed] all calendars: \(ek.calendars(for: .event).map { "\($0.title)[\($0.type.rawValue)]" })")
        for item in store.allAlarms() {
            log("[calskip-seed] \(item.label) \(item.hour):\(item.minute) skips=\(item.autoSkippedDates) next=\(String(describing: item.nextOccurrence))")
        }
        for r in await UNUserNotificationCenter.current().pendingNotificationRequests() where r.identifier.hasPrefix("calskip-") {
            let at = (r.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate()
            log("[calskip-seed] pending \(r.identifier) at=\(String(describing: at)) | \(r.content.title) | \(r.content.body)")
        }
        log("[calskip-seed] titles=\(store.calendarDayTitles)")
    }

    // MARK: - QA hooks (DEBUG only)

    /// `--calskip-dump`: full state report to Documents/qa-dump.txt (overwritten
    /// each launch): alarms with their skips, every pending notification, the
    /// delivered calendar notices.
    static func dump(store: AlarmStore) async {
        var lines: [String] = ["[dump] selected=\(store.autoSkipCalendarIDs.count) titles=\(store.calendarDayTitles.keys.sorted())"]
        for item in store.allAlarms() {
            lines.append("[dump] \(item.label) \(item.hour):\(item.minute) enabled=\(item.isEnabled) autoSkip=\(item.autoSkipOnCalendarEvents) skips=\(item.autoSkippedDates) manual=\(item.skippedOccurrenceDates) ringAnyway=\(item.calendarSkipOverrides) next=\(String(describing: item.nextOccurrence)) armed=\(item.armedOccurrences.count) armFailed=\(item.lastArmFailed)")
        }
        let center = UNUserNotificationCenter.current()
        for r in await center.pendingNotificationRequests().sorted(by: { $0.identifier < $1.identifier }) {
            let at = (r.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate()
            lines.append("[dump] pending \(r.identifier) at=\(String(describing: at)) sound=\(r.content.sound != nil) cat=\(r.content.categoryIdentifier) | \(r.content.title) | \(r.content.body)")
        }
        for n in await center.deliveredNotifications() where n.request.identifier.hasPrefix("calskip-") || n.request.identifier.hasPrefix("qa-now-") {
            lines.append("[dump] delivered \(n.request.identifier) | \(n.request.content.title)")
        }
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            try? lines.joined(separator: "\n").write(to: dir.appendingPathComponent("qa-dump.txt"), atomically: true, encoding: .utf8)
        }
    }

    /// `--calskip-notice-now`: deliver a copy of every pending calendar notice
    /// right away, so a UI test can use its actions without waiting for 20:00.
    static func deliverNoticesNow() async {
        let center = UNUserNotificationCenter.current()
        for r in await center.pendingNotificationRequests() where r.identifier.hasPrefix("calskip-") {
            try? await center.add(UNNotificationRequest(identifier: "qa-now-" + r.identifier, content: r.content, trigger: nil))
        }
    }

    /// `--calskip-remove-holiday`: delete tomorrow's "Test Holiday", then refresh,
    /// as if the user had removed the event from their calendar.
    static func removeHoliday(store: AlarmStore) async {
        let ek = EKEventStore()
        guard let cal = ek.calendars(for: .event).first(where: { $0.title == "Days Off (test)" }),
              let end = Calendar.current.date(byAdding: .day, value: 30, to: .now) else { return }
        for e in ek.events(matching: ek.predicateForEvents(withStart: Calendar.current.startOfDay(for: .now), end: end, calendars: [cal]))
        where e.title == "Test Holiday" { try? ek.remove(e, span: .thisEvent, commit: true) }
        await store.refreshAllSchedules()
    }

    /// `--calskip-remove-calendar`: delete the whole "Days Off (test)" calendar,
    /// then refresh. The saved choice keeps its id (it may be an iCloud calendar
    /// not synced yet), so this checks that its days stop counting anyway.
    static func removeDaysOffCalendar(store: AlarmStore) async {
        let ek = EKEventStore()
        guard let cal = ek.calendars(for: .event).first(where: { $0.title == "Days Off (test)" }) else { return }
        try? ek.removeCalendar(cal, commit: true)
        await store.refreshAllSchedules()
    }

    /// `--seed-ring-test`: a one-time alarm two minutes from now, to watch a
    /// real AlarmKit ring in the simulator.
    static func seedRingTest(store: AlarmStore) async {
        let at = Date.now.addingTimeInterval(120)
        let c = Calendar.current.dateComponents([.hour, .minute], from: at)
        let item = AlarmItem(hour: c.hour ?? 0, minute: c.minute ?? 0, label: "QA ring", mode: .oneTimeDate,
                             oneTimeDate: DateOnly(date: at, calendar: .current))
        await store.create(item)
    }

    /// `--wakecheck-qa` ("Are you up?"): an alarm with the check on (so AlarmKit
    /// must accept its stopIntent), then a check started as its Stop would;
    /// with `--wakecheck-qa-race` two more Stops at once (one check, one alarm
    /// and one notice must remain); with `--wakecheck-qa-imup` also the I'm up
    /// answer. Writes Documents/wakecheck-qa.txt. The Stop -> intent hop itself
    /// needs a device.
    static func wakeCheckQA(store: AlarmStore, imUp: Bool, race: Bool) async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        let at = Date.now.addingTimeInterval(180)
        let c = Calendar.current.dateComponents([.hour, .minute], from: at)
        let item = AlarmItem(hour: c.hour ?? 0, minute: c.minute ?? 0, label: "QA wake", mode: .oneTimeDate,
                             oneTimeDate: DateOnly(date: at, calendar: .current))
        item.wakeCheckEnabled = true
        await store.create(item)
        var lines = ["[wake] alarm armed=\(item.armedOccurrences.count) armFailed=\(item.lastArmFailed)"]
        await store.startWakeCheck(alarmID: item.id)
        lines += await wakeCheckState(store: store, step: "started")
        if race {
            let before = ((try? AlarmManager.shared.alarms) ?? []).count
            async let first: Void = store.startWakeCheck(alarmID: item.id)
            async let second: Void = store.startWakeCheck(alarmID: item.id)
            _ = await (first, second)
            let after = ((try? AlarmManager.shared.alarms) ?? []).count
            let records = TransientAlarms.records().filter { $0.kind == .wakeCheck }.count
            let notices = await UNUserNotificationCenter.current().pendingNotificationRequests()
                .filter { $0.identifier.hasPrefix(WakeCheck.prefix) }.count
            lines.append("[wake] race: alarms before=\(before) after=\(after) records=\(records) notices=\(notices)")
            lines += await wakeCheckState(store: store, step: "race")
        }
        if imUp {
            await store.endWakeCheck()
            lines += await wakeCheckState(store: store, step: "imUp")
        }
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            try? lines.joined(separator: "\n").write(to: dir.appendingPathComponent("wakecheck-qa.txt"), atomically: true, encoding: .utf8)
        }
    }

    /// `--wakecheck-clip` (with `--seed-demo`): the list for the social clip.
    /// Only the demo "Wake up" alarm stays (so the hero reads 6:30 AM too), with
    /// the check on and started as if its Stop came at the next 6:30, so the
    /// card reads "rings again at 6:37" whatever the clock says. I'm up on the
    /// card cancels it as usual.
    static func wakeCheckClip(store: AlarmStore) async {
        guard let item = store.allAlarms().first(where: { $0.hour == 6 && $0.minute == 30 }),
              let stop = Calendar.current.nextDate(after: .now, matching: DateComponents(hour: 6, minute: 30),
                                                   matchingPolicy: .nextTime) else { return }
        for other in store.allAlarms() where other.id != item.id { await store.delete(other) }
        _ = await store.update(item) { $0.wakeCheckEnabled = true }
        await store.startWakeCheck(alarmID: item.id, now: stop)
    }

    private static func wakeCheckState(store: AlarmStore, step: String) async -> [String] {
        var lines = ["[wake] \(step): store=\(String(describing: store.wakeCheck?.fireDate))"]
        for r in TransientAlarms.records() { lines.append("[wake] \(step): record \(r.id) \(r.kind) \(r.fireDate)") }
        let ids = Set(TransientAlarms.records().map(\.id))
        for a in (try? AlarmManager.shared.alarms) ?? [] where ids.contains(a.id) {
            lines.append("[wake] \(step): alarmkit \(a.id) \(a.state)")
        }
        for r in await UNUserNotificationCenter.current().pendingNotificationRequests() where r.identifier.hasPrefix(WakeCheck.prefix) {
            let fires = (r.trigger as? UNTimeIntervalNotificationTrigger)?.nextTriggerDate()
            lines.append("[wake] \(step): notice \(r.identifier) at=\(String(describing: fires)) sound=\(r.content.sound != nil) cat=\(r.content.categoryIdentifier) | \(r.content.title) | \(r.content.body)")
        }
        return lines
    }

    private static func calendar(named name: String, in ek: EKEventStore) -> EKCalendar? {
        if let existing = ek.calendars(for: .event).first(where: { $0.title == name }) { return existing }
        let c = EKCalendar(for: .event, eventStore: ek)
        c.title = name
        c.source = ek.defaultCalendarForNewEvents?.source
            ?? ek.sources.first(where: { $0.sourceType == .local })
        do { try ek.saveCalendar(c, commit: true); return c } catch { log("[calskip-seed] calendar \(name): \(error)"); return nil }
    }

    private static func addAllDay(_ title: String, on day: Date, days: Int = 1, to calendar: EKCalendar?, in ek: EKEventStore) {
        guard let calendar else { return }
        let end = Calendar.current.date(byAdding: .day, value: 1, to: day) ?? day
        let last = Calendar.current.date(byAdding: .day, value: days - 1, to: day) ?? day
        let existing = ek.events(matching: ek.predicateForEvents(withStart: day, end: end, calendars: [calendar]))
        if existing.contains(where: { $0.title == title }) { return }
        let e = EKEvent(eventStore: ek)
        e.title = title; e.isAllDay = true; e.startDate = day; e.endDate = last; e.calendar = calendar
        do { try ek.save(e, span: .thisEvent, commit: true) } catch { log("[calskip-seed] event \(title): \(error)") }
    }
}
#endif
