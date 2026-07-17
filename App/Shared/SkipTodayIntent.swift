import AppIntents
import SwiftData
import WidgetKit
import ActivityKit
import AlarmCore

/// First-class "Skip today" as a LIVE ACTIVITY intent so it works from the
/// widget, the Lock Screen Live Activity, Shortcuts, and Siri — not just inside
/// the app. Compiled into both the app and the widget extension targets.
///
/// `LiveActivityIntent` (not plain AppIntent) is load-bearing: the system runs
/// it IN THE APP'S PROCESS (launching it in the background if needed), which is
/// the only process allowed to mutate the app's Live Activity. That's what lets
/// the tap give IMMEDIATE visual feedback — with a plain AppIntent the skip
/// executed in the extension process and the countdown kept ticking untouched,
/// which read as "the button doesn't work".
struct SkipTodayIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Skip today's alarm"
    static var description = IntentDescription("Skip only today's occurrence; the alarm stays active for the next day.")
    /// We do the work ourselves; no need to foreground the app.
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Alarm")
    var alarmID: String

    init() {}
    init(alarmID: UUID) { self.alarmID = alarmID.uuidString }
    init(alarmIDString: String) { self.alarmID = alarmIDString }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: alarmID) else { return .result() }

        let store = Self.resolveStore()
        if let alarm = store.alarm(with: id), alarm.isEnabled {
            // Conclude the Live Activity FIRST: the skip below fires the app's
            // own save/observer reconcile, which must find this activity already
            // ended (and therefore leave it to its own dismissal) — concluding
            // after would race that reconcile.
            await Self.concludeActivity(alarmID: alarmID, for: alarm)
            // Awaited so the cancel-today + re-arm-next work completes before the
            // intent process is torn down.
            await store.skipNextOccurrence(alarm)
        }

        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }

    /// The running app's live store when we execute in-process (LiveActivityIntent
    /// does); a fresh shared-container store only when the app was dead-launched
    /// or we're in the extension. See LiveAppContext for why this matters.
    @MainActor
    static func resolveStore() -> AlarmStore {
        if let live = LiveAppContext.store { return live }
        let context = ModelContext(SharedModelContainer.make())
        let scheduler = AlarmScheduler(alarmKit: AlarmKitManager(), preAlerts: PreAlertNotificationManager())
        return AlarmStore(context: context, scheduler: scheduler)
    }

    /// End the alarm's Live Activity with an honest final state: "Today skipped
    /// — still active" counting to the NEXT real ring (computed as the first
    /// occurrence after the one currently shown — the skip that follows will
    /// suppress the shown one). One-time alarms have no next ring: the card
    /// simply vanishes, which is the honest feedback.
    @MainActor
    static func concludeActivity(alarmID: String, for alarm: AlarmItem) async {
        for activity in Activity<PunctualActivityAttributes>.activities
        where activity.attributes.alarmID == alarmID && activity.activityState == .active {
            var state = activity.content.state
            state.skippedToday = true
            let next = NextOccurrenceCalculator().nextOccurrence(
                for: alarm.schedule, after: state.fireDate, calendar: .current
            )
            if let next {
                state.fireDate = next
                state.dayPhrase = Self.dayPhrase(next)
                await activity.end(ActivityContent(state: state, staleDate: nil),
                                   dismissalPolicy: .after(.now.addingTimeInterval(180)))
            } else {
                await activity.end(ActivityContent(state: state, staleDate: nil),
                                   dismissalPolicy: .immediate)
            }
        }
    }

    /// Minimal local dayPhrase (NotificationActionHandler is app-target-only,
    /// and this file compiles into the widget target too).
    private static func dayPhrase(_ date: Date, calendar: Calendar = .current) -> String {
        if calendar.isDateInToday(date) { return "today" }
        if calendar.isDateInTomorrow(date) { return "tomorrow" }
        let f = DateFormatter(); f.calendar = calendar; f.dateFormat = "EEEE"
        return f.string(from: date)
    }
}
