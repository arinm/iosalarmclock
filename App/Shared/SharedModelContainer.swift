import Foundation
import SwiftData

/// Builds the SwiftData container in a shared App Group so the app **and** the
/// widget extension read/write the same alarms. Compiled into both targets.
enum SharedModelContainer {
    static let appGroupID = "group.com.punctual.app"

    static func make() -> ModelContainer {
        do {
            let config = ModelConfiguration(groupContainer: .identifier(appGroupID))
            return try ModelContainer(for: AlarmItem.self, configurations: config)
        } catch {
            // The App Group store is the contract between app and widget. If it's
            // unavailable the two processes would silently diverge, so fail loudly
            // in development; in release fall back to a local store (degraded:
            // widget/Siri skip won't reflect in-app) rather than crash on launch.
            assertionFailure("Shared App Group container unavailable — check the 'group.com.punctual.app' entitlement on BOTH targets. Error: \(error)")
            print("⚠️ Shared container unavailable (\(error)); using NON-SHARED local store. Widget/Siri will not stay in sync.")
            return try! ModelContainer(for: AlarmItem.self)
        }
    }
}
