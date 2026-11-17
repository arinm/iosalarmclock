import AppIntents

/// "Are you up?" (Pro): AlarmKit runs this when the user taps Stop on a ring
/// of an alarm with the check on (`AlarmConfiguration.stopIntent`). Snooze
/// doesn't run it, so only the final Stop starts a check.
///
/// A `LiveActivityIntent`, so the system runs it in the app's process
/// (launching it in the background if needed) and it reuses the app's live
/// store. Compiled into the widget extension too, only because
/// `AlarmKitManager`, which names it, is.
struct WakeCheckIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Are you up?"
    static var openAppWhenRun: Bool = false
    /// Only an alarm's Stop button runs it: not offered in Shortcuts or Siri.
    static var isDiscoverable: Bool = false

    @Parameter(title: "Alarm")
    var alarmID: String

    init() {}
    init(alarmID: UUID) { self.alarmID = alarmID.uuidString }

    @MainActor
    func perform() async throws -> some IntentResult {
        // The line a device test looks for: did this Stop (iPhone or Watch) reach us?
        WakeCheck.log.notice("Stop ran the check intent for alarm \(alarmID, privacy: .public)")
        guard let id = UUID(uuidString: alarmID) else { return .result() }
        await SkipTodayIntent.resolveStore().startWakeCheck(alarmID: id)
        return .result()
    }
}
