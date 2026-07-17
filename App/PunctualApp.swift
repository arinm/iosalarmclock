import SwiftUI
import SwiftData
import UserNotifications
import UIKit
import WidgetKit
import AlarmCore

/// App entry. Wires the dependency graph (SwiftData ➜ store ➜ scheduler ➜
/// AlarmKit + notifications), drives onboarding, and re-arms schedules whenever
/// the app foregrounds — the resilience step AlarmKit's lack of native skip
/// requires.
@main
struct PunctualApp: App {
    @State private var container: ModelContainer
    @State private var store: AlarmStore
    @State private var alarmKit: AlarmKitManager
    @State private var permissions: PermissionManager
    @State private var pro = ProFeatureManager()
    @State private var store_kit = StoreManager()
    @State private var banners: BannerCenter
    @State private var actionHandler: NotificationActionHandler
    @State private var bgRefresh: BackgroundRefreshManager
    @State private var liveActivity = LiveActivityManager()
    @State private var theme = ThemeManager.shared
    @State private var soundManager = SoundManager()

    @Environment(\.scenePhase) private var scenePhase

    init() {
        // SwiftData (App Group container shared with the widget extension).
        // Use the container's MAIN context — the same one @Query uses — so store
        // mutations/fetches and the list stay in sync in real time (a separate
        // ModelContext would lag the hero/“next alarm” until the next refresh).
        let container = SharedModelContainer.make()
        let context = container.mainContext

        // Services
        let alarmKit = AlarmKitManager()
        let preAlerts = PreAlertNotificationManager()
        let scheduler = AlarmScheduler(alarmKit: alarmKit, preAlerts: preAlerts)
        let store = AlarmStore(context: context, scheduler: scheduler)

        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--seed-demo") { store.seedDemoData() }
        #endif

        let banners = BannerCenter()
        let handler = NotificationActionHandler(store: store, banners: banners)
        UNUserNotificationCenter.current().delegate = handler
        preAlerts.registerCategories()

        let bgRefresh = BackgroundRefreshManager { await store.refreshAllSchedules() }
        bgRefresh.register()

        _container = State(initialValue: container)
        _store = State(initialValue: store)
        _alarmKit = State(initialValue: alarmKit)
        _permissions = State(initialValue: PermissionManager(alarmKit: alarmKit))
        _banners = State(initialValue: banners)
        _actionHandler = State(initialValue: handler)
        _bgRefresh = State(initialValue: bgRefresh)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(permissions)
                .environment(pro)
                .environment(store_kit)
                .environment(banners)
                .environment(theme)
                .environment(soundManager)
                .task {
                    // Every persisted change pushes the outside surfaces: the
                    // widget re-renders from the shared store and the Live
                    // Activity reconciles (new/changed alarm shows immediately;
                    // a stale activity ends instead of lingering).
                    store.onDidSave = {
                        WidgetCenter.shared.reloadAllTimelines()
                        refreshLiveActivity()
                    }
                    await permissions.refresh()
                    await store_kit.start()
                    // Re-arm the look-ahead window when AlarmKit reports a
                    // fire/stop/cancel while the app is alive (complements the
                    // foreground re-arm). The live id set lets the scheduler heal
                    // occurrences cancelled outside the app.
                    alarmKit.observeAlarmUpdates { [store, alarmKit] liveIDs in
                        await store.refreshAllSchedules(liveAlarmIDs: liveIDs)
                        // After the refresh (which captures just-fired occurrences),
                        // confirm any newly-snoozing alarm with a local notification
                        // and surface the in-app "Snoozing" state.
                        store.reconcileSnoozes(snoozingIDs: alarmKit.snoozingAlarmIDs(), announce: true)
                        refreshLiveActivity()
                    }
                }
                .onChange(of: store_kit.isPro) { _, newValue in
                    #if DEBUG
                    // Screenshot mode: stay Free so the paywall shows purchase tiers.
                    if ProcessInfo.processInfo.arguments.contains("--demo-free") { return }
                    #endif
                    pro.isPro = newValue
                    // Only reset Pro themes on a CONFIRMED lapse (entitlements known),
                    // never during the transient false before/while loading.
                    if store_kit.resolved && !newValue { theme.resetToDefault() }
                }
                .onChange(of: store_kit.isSubscriber) { _, newValue in
                    #if DEBUG
                    if ProcessInfo.processInfo.arguments.contains("--demo-free") { return }
                    #endif
                    pro.isSubscriber = newValue
                }
                .onChange(of: store_kit.resolved) { _, newValue in
                    pro.entitlementsResolved = newValue
                    // Lapse across a relaunch: isPro goes false→false (no change,
                    // so the isPro onChange never fires) — reset the Pro theme
                    // here once entitlements are confirmed. No-op for free users
                    // already on the default theme.
                    if newValue && !store_kit.isPro { theme.resetToDefault() }
                }
                .tint(theme.accentColor)
                // Apply appearance directly on the window so it also covers sheets
                // (preferredColorScheme on the root doesn't reach presented sheets).
                .onChange(of: theme.appearance) { _, newValue in applyAppearance(newValue) }
                .onAppear { applyAppearance(theme.appearance) }
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                applyAppearance(theme.appearance) // ensure window style is set once shown
                Task {
                    await permissions.refresh()
                    await store.refreshAllSchedules() // re-arm look-ahead window
                    // Surface a snooze that happened while we weren't running
                    // (no notification — the moment has passed; UI state only).
                    store.reconcileSnoozes(snoozingIDs: alarmKit.snoozingAlarmIDs(), announce: false)
                    refreshLiveActivity()
                }
            case .background:
                bgRefresh.schedule() // ask iOS to top us up later
            default:
                break
            }
        }
    }
}

extension PunctualApp {
    /// Apply the chosen light/dark/system appearance to every window so it also
    /// covers presented sheets (which `.preferredColorScheme` on the root misses).
    func applyAppearance(_ appearance: ThemeManager.Appearance) {
        let style: UIUserInterfaceStyle
        switch appearance {
        case .light: style = .light
        case .dark: style = .dark
        case .system: style = .unspecified
        }
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows { window.overrideUserInterfaceStyle = style }
        }
    }

    /// Reflect the soonest upcoming alarm into the Live Activity.
    func refreshLiveActivity() {
        if let up = store.nextUpAlarm() {
            let skipped: Bool = { if case .skippedToday = up.alarm.status() { return true }; return false }()
            let day = DateOnly(date: up.fireDate, calendar: .current)
            let phrase = NotificationActionHandler.dayPhrase(day, calendar: .current)
            liveActivity.refresh(soonest: (up.alarm.id, up.fireDate, up.alarm.label, skipped, phrase))
        } else {
            liveActivity.refresh(soonest: nil)
        }
    }
}

/// Decides between onboarding and the main list.
struct RootView: View {
    @Environment(PermissionManager.self) private var permissions
    /// Once onboarding is on screen it stays until IT says it's done —
    /// `needsOnboarding` flips as soon as the first permission resolves, and
    /// switching on that alone used to tear the screen down mid-flow (the
    /// second system dialog then floated over an unexplained alarm list).
    @State private var startedOnboarding = false
    @State private var onboardingDone = false

    var body: some View {
        if skipOnboarding {
            AlarmListView()
        } else if !permissions.hasResolved {
            // Brief neutral splash until the real permission state is known, so we
            // never flash the onboarding screen to users who already granted access.
            LaunchSplashView()
        } else if (permissions.needsOnboarding || startedOnboarding) && !onboardingDone {
            OnboardingView(onDone: { onboardingDone = true })
                .onAppear { startedOnboarding = true }
        } else {
            AlarmListView()
        }
    }

    private var skipOnboarding: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--skip-onboarding")
        #else
        false
        #endif
    }
}

/// Minimal launch placeholder shown only while permissions resolve.
struct LaunchSplashView: View {
    var body: some View {
        ZStack {
            Theme.screenBackground
            BrandMark(size: 72)
        }
    }
}
