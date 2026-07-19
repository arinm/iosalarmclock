import Foundation
import UserNotifications

/// Centralises the two permission gates (AlarmKit + notifications) and exposes
/// observable state to the UI so banners/onboarding can react.
@MainActor
@Observable
final class PermissionManager {
    enum State: Sendable { case notDetermined, authorized, denied }

    private(set) var alarmKitState: State = .notDetermined
    private(set) var notificationState: State = .notDetermined
    /// False until the first `refresh()` completes, so the UI doesn't flash the
    /// onboarding screen before we know the real permission state.
    private(set) var hasResolved = false

    private let alarmKit: AlarmKitManaging

    init(alarmKit: AlarmKitManaging) { self.alarmKit = alarmKit }

    /// True when alarms can actually ring. Pre-alerts are a bonus, not required.
    var canRing: Bool { alarmKitState == .authorized }
    var canPreAlert: Bool { notificationState == .authorized }
    var needsOnboarding: Bool { alarmKitState == .notDetermined }

    func refresh() async {
        #if DEBUG
        // Screenshot mode: the simulator reports AlarmKit as denied, which puts
        // the orange "Alarms can't ring" warning in every App Store shot.
        // Present as fully authorized instead — DEBUG-only, never ships.
        if ProcessInfo.processInfo.arguments.contains("--app-store-screenshots") {
            alarmKitState = .authorized
            notificationState = .authorized
            hasResolved = true
            return
        }
        #endif
        switch await alarmKit.authorizationState() {
        case .authorized: alarmKitState = .authorized
        case .denied: alarmKitState = .denied
        case .notDetermined: alarmKitState = .notDetermined
        }

        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: notificationState = .authorized
        case .denied: notificationState = .denied
        default: notificationState = .notDetermined
        }

        hasResolved = true
    }

    @discardableResult
    func requestAlarmKit() async -> Bool {
        let granted = await alarmKit.requestAuthorization()
        alarmKitState = granted ? .authorized : .denied
        return granted
    }

    @discardableResult
    func requestNotifications() async -> Bool {
        let granted = (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        notificationState = granted ? .authorized : .denied
        return granted
    }
}
