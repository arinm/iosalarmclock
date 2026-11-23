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
    @State private var language: LanguageManager

    @Environment(\.scenePhase) private var scenePhase

    init() {
        // First, so the words made below (demo seed, notification buttons)
        // come in this launch's language: as a `@State` default it would only
        // be made once `body` reads it, and a background launch may never.
        _language = State(initialValue: LanguageManager())

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
        // Intents running in-process (LiveActivityIntent, Siri) must reuse THIS
        // store — a sibling container's writes can lag the mainContext and let
        // the observer re-arm a just-skipped occurrence.
        LiveAppContext.store = store
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
                .environment(language)
                // Text keys and formats follow a language picked in Settings
                // at once (see AppLanguage).
                .environment(\.locale, language.locale)
                .task {
                    // Every persisted change pushes the outside surfaces: the
                    // widget re-renders from the shared store and the Live
                    // Activity reconciles (new/changed alarm shows immediately;
                    // a stale activity ends instead of lingering).
                    store.onDidSave = {
                        WidgetCenter.shared.reloadAllTimelines()
                        refreshLiveActivity()
                    }
                    // Alarms armed in another language get the new words.
                    Task { await syncAlarmLanguage() }
                    #if DEBUG
                    // Own task: StoreKit's start() can hang outside Xcode (no
                    // local StoreKit config when launched by simctl).
                    let qa = ProcessInfo.processInfo.arguments
                    if qa.contains("--demo-pro") { pro.isPro = true; pro.entitlementsResolved = true }
                    if let i = qa.firstIndex(of: "--pick-language"), i + 1 < qa.count {
                        Task { // a live pick, as from Settings ("auto" = Automatic)
                            try? await Task.sleep(for: .seconds(3))
                            language.select(qa[i + 1] == "auto" ? nil : qa[i + 1])
                            // A second pick while the first one's re-arm still runs.
                            if let j = qa.firstIndex(of: "--then-pick-language"), j + 1 < qa.count {
                                try? await Task.sleep(for: .milliseconds(200))
                                language.select(qa[j + 1] == "auto" ? nil : qa[j + 1])
                            }
                        }
                    }
                    Task {
                        if qa.contains("--seed-calendar-skip") { await CalendarSkipDebugSeed.run(store: store) }
                        if qa.contains("--calskip-remove-holiday") { await CalendarSkipDebugSeed.removeHoliday(store: store) }
                        if qa.contains("--calskip-remove-calendar") { await CalendarSkipDebugSeed.removeDaysOffCalendar(store: store) }
                        if qa.contains("--seed-ring-test") { await CalendarSkipDebugSeed.seedRingTest(store: store) }
                        if qa.contains("--wakecheck-qa") {
                            await CalendarSkipDebugSeed.wakeCheckQA(store: store, imUp: qa.contains("--wakecheck-qa-imup"),
                                                                    race: qa.contains("--wakecheck-qa-race"))
                            if qa.contains("--wakecheck-qa-focus") { // a tap on the notice, 15 s later
                                try? await Task.sleep(for: .seconds(15))
                                store.focusWakeCheck()
                            }
                        }
                        if qa.contains("--wakecheck-clip") { await CalendarSkipDebugSeed.wakeCheckClip(store: store) }
                        if qa.contains("--calskip-notice-now") { await CalendarSkipDebugSeed.deliverNoticesNow() }
                        if qa.contains("--calskip-qa-ring-anyway") {
                            // The single-day notice's own userInfo, through the action handler.
                            for r in await UNUserNotificationCenter.current().pendingNotificationRequests()
                            where r.content.categoryIdentifier == CalendarSkipNotifier.categoryID {
                                await actionHandler.qaRingAnyway(info: r.content.userInfo)
                            }
                        }
                        if qa.contains("--calskip-dump") {
                            try? await Task.sleep(for: .seconds(4)) // let the launch refresh settle
                            await CalendarSkipDebugSeed.dump(store: store)
                        }
                    }
                    #endif
                    await permissions.refresh()
                    await store_kit.start()
                    // Re-arm the look-ahead window when AlarmKit reports a
                    // fire/stop/cancel while the app is alive (complements the
                    // foreground re-arm). The live id set lets the scheduler heal
                    // occurrences cancelled outside the app.
                    alarmKit.observeAlarmUpdates { [store, alarmKit] liveIDs in
                        // Count the ring BEFORE the refresh clears past-dated
                        // occurrences. Lives here, not in AlarmStore, because the
                        // store is also compiled into the widget extension.
                        AppReviewPrompt.noteFired(store.firedOccurrences())
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
                .onChange(of: language.code) {
                    Task { await syncAlarmLanguage() }
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
                // Re-read entitlements on every foreground: a single empty read at
                // launch (StoreKit not synced, flaky sandbox) used to leave a
                // paying user on Free for the whole session with nothing retrying.
                // Deliberately a SEPARATE task — re-arming alarms is the app's
                // core resilience step and must never queue behind a StoreKit
                // round-trip that can hang or be cut short by a quick app switch.
                Task { await store_kit.refreshEntitlements() }
                Task {
                    await permissions.refresh()
                    AppReviewPrompt.noteFired(store.firedOccurrences()) // before the refresh clears them
                    await store.refreshAllSchedules() // re-arm look-ahead window
                    store.reloadWakeCheck() // a check started or answered while we were away
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

    /// The alarm screen keeps the title, Stop and Snooze an alarm was armed
    /// with, and the notification buttons are registered once, so both are
    /// redone when the app's language moves on: a pick in Settings, iOS's
    /// per-app language, or a new phone language under Automatic. The first
    /// launch of 1.0.5 only records the language: older alarms carry words
    /// iOS translates itself.
    func syncAlarmLanguage() async {
        // One sync at a time: a pick made while it runs is caught by its loop.
        guard !language.isSyncingAlarms else { return }
        language.isSyncingAlarms = true
        defer { language.isSyncingAlarms = false }
        guard language.alarmsLanguage != nil else {
            language.alarmsLanguage = language.code
            return
        }
        guard language.alarmsLanguage != language.code else { return }
        var target: String
        var picks: Int
        // Each alarm takes the language current when it is re-armed, so any pick
        // during a pass (even one back to the same language) redoes the pass.
        repeat {
            target = language.code
            picks = language.pickCount
            PreAlertNotificationManager().registerCategories()
            await store.rearmAll()
        } while target != language.code || picks != language.pickCount
        // Recorded only once all alarms are re-armed: a process cut short
        // mid-way re-arms them again at the next launch.
        language.alarmsLanguage = target
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
