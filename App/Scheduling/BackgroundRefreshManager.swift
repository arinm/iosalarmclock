import Foundation
import BackgroundTasks

/// Periodically re-arms the alarm look-ahead window in the background so
/// far-future alarms stay scheduled even if the user doesn't open the app for a
/// while. This compensates for our app-managed recurrence (AlarmKit has no
/// native skip/exception support — see README). It is a *best-effort* top-up;
/// the alarms themselves are still real AlarmKit alarms that ring regardless.
@MainActor
final class BackgroundRefreshManager {
    static let taskIdentifier = "com.punctual.app.refresh"

    private let refresh: @MainActor () async -> Void

    init(refresh: @escaping @MainActor () async -> Void) {
        self.refresh = refresh
    }

    /// Register the launch handler. Call once, early, before app finishes launching.
    /// NOTE: BGTaskScheduler invokes this handler on a background queue, so we must
    /// hop to the main actor explicitly (using `assumeIsolated` here would trap).
    func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.taskIdentifier, using: nil) { task in
            guard let task = task as? BGAppRefreshTask else { return }
            task.expirationHandler = { task.setTaskCompleted(success: false) }
            Task { @MainActor in await self.handle(task) }
        }
    }

    /// Ask the system to run us again later. iOS decides the actual timing.
    func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
        // Earliest in ~6 hours; iOS coalesces/limits in practice.
        request.earliestBeginDate = Date(timeIntervalSinceNow: 6 * 60 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    private func handle(_ task: BGAppRefreshTask) async {
        schedule()           // chain the next request so the loop continues
        await refresh()
        task.setTaskCompleted(success: true)
    }
}
