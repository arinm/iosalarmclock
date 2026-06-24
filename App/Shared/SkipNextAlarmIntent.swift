import AppIntents
import SwiftData
import WidgetKit
import AlarmCore

/// Parameterless "skip my next alarm" — the friendly form for Siri / Spotlight /
/// the Action button, where picking a specific alarm would be awkward. Finds the
/// soonest upcoming alarm and skips just today's occurrence.
struct SkipNextAlarmIntent: AppIntent {
    static var title: LocalizedStringResource = "Skip my next alarm"
    static var description = IntentDescription("Skip only the next occurrence; the alarm stays active afterwards.")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let calc = NextOccurrenceCalculator()
        let context = ModelContext(SharedModelContainer.make())
        let alarms = (try? context.fetch(FetchDescriptor<AlarmItem>())) ?? []

        let soonest = alarms
            .compactMap { item -> (AlarmItem, Date)? in
                guard let next = calc.nextOccurrence(for: item.schedule, after: .now, calendar: .current) else { return nil }
                return (item, next)
            }
            .min { $0.1 < $1.1 }

        guard let (alarm, _) = soonest else {
            return .result(dialog: "You have no upcoming alarms.")
        }

        let scheduler = AlarmScheduler(alarmKit: AlarmKitManager(), preAlerts: PreAlertNotificationManager())
        let store = AlarmStore(context: context, scheduler: scheduler)
        let skippedDay = await store.skipNextOccurrence(alarm)
        WidgetCenter.shared.reloadAllTimelines()

        let next = alarm.nextOccurrence
        let when = NotificationActionHandler.describe(next, calendar: .current)
        // Name the actual day skipped — it may not be "today" (e.g. a weekday
        // alarm skipped on a Saturday skips Monday).
        let dayText = Self.dayPhrase(skippedDay)
        return .result(dialog: "Skipped \(dayText). Your alarm is still active — next at \(when).")
    }

    private static func dayPhrase(_ day: DateOnly?) -> String {
        guard let day, let date = day.startOfDay(in: .current) else { return "the next alarm" }
        if Calendar.current.isDateInToday(date) { return "today" }
        if Calendar.current.isDateInTomorrow(date) { return "tomorrow" }
        let f = DateFormatter(); f.dateFormat = "EEEE"  // e.g. "Monday"
        return f.string(from: date)
    }
}

/// Surfaces the skip intents to Siri, Spotlight and the Shortcuts app.
struct PunctualShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SkipNextAlarmIntent(),
            phrases: [
                "Skip my next alarm in \(.applicationName)",
                "Skip today's alarm in \(.applicationName)",
                "\(.applicationName) skip today"
            ],
            shortTitle: "Skip next alarm",
            systemImageName: "forward.end.fill"
        )
    }
}
