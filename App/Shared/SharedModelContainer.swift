import Foundation
import SwiftData

/// The RUNNING app's live services, when this code executes in the app process.
/// LiveActivityIntents (and app-bundle intents like Siri's skip) run IN the app
/// process — building a second container there would write through a sibling
/// context the app's mainContext may not merge in time: the AlarmKit observer
/// could then recompute from stale data and RE-ARM the occurrence just skipped.
/// Set once at app launch; stays nil in the widget process (fresh container is
/// the correct fallback there and when the app was dead-launched in background).
@MainActor
enum LiveAppContext {
    static weak var store: AlarmStore?
}

/// Builds the SwiftData container in a shared App Group so the app **and** the
/// widget extension read/write the same alarms. Compiled into both targets.
enum SharedModelContainer {
    static let appGroupID = "group.com.arinitsolutions.punctual"

    static func make() -> ModelContainer {
        do {
            let config = ModelConfiguration(groupContainer: .identifier(appGroupID))
            return try ModelContainer(for: AlarmItem.self, configurations: config)
        } catch {
            // The App Group store is the contract between app and widget. If it's
            // unavailable the two processes would silently diverge, so fail loudly
            // in development; in release fall back to a local store (degraded:
            // widget/Siri skip won't reflect in-app) rather than crash on launch.
            assertionFailure("Shared App Group container unavailable — check the 'group.com.arinitsolutions.punctual' entitlement on BOTH targets. Error: \(error)")
            print("⚠️ Shared container unavailable (\(error)); using NON-SHARED local store. Widget/Siri will not stay in sync.")
            return try! ModelContainer(for: AlarmItem.self)
        }
    }
}
