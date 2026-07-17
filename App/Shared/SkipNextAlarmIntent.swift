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
        // Reuse the running app's store when in-process — a sibling container's
        // writes can lag the mainContext and let the AlarmKit observer re-arm
        // the just-skipped occurrence (same rationale as SkipTodayIntent).
        let store = SkipTodayIntent.resolveStore()

        guard let (alarm, _) = store.nextUpAlarm() else {
            return .result(dialog: "You have no upcoming alarms.")
        }

        // Conclude the Live Activity BEFORE the skip (see SkipTodayIntent) so
        // a Siri skip doesn't leave a card counting to a cancelled occurrence.
        await SkipTodayIntent.concludeActivity(alarmID: alarm.id.uuidString, for: alarm)
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
