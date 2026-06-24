import AppIntents
import SwiftData
import WidgetKit
import AlarmCore

/// First-class "Skip today" as an App Intent so it works from the widget, the
/// Lock Screen Live Activity, Shortcuts, and Siri — not just inside the app.
/// Compiled into both the app and the widget extension targets.
///
/// It writes the authoritative skip to the shared App Group store and re-arms the
/// schedule (the deterministic AlarmKit cancel makes this safe cross-process).
struct SkipTodayIntent: AppIntent {
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

        let container = SharedModelContainer.make()
        let context = ModelContext(container)
        let scheduler = AlarmScheduler(alarmKit: AlarmKitManager(), preAlerts: PreAlertNotificationManager())
        let store = AlarmStore(context: context, scheduler: scheduler)

        if let alarm = store.alarm(with: id) {
            // Awaited so the cancel-today + re-arm-next work completes before the
            // intent process is torn down.
            await store.skipNextOccurrence(alarm)
        }

        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
