import Foundation

/// Free vs Pro gating for the value ladder:
///   • FREE  — the core hero loop (countdown, pre-alert 15m, Skip today,
///             basic snooze, unlimited alarms, default theme, basic widget).
///   • PRO   — power & personalization, incl. vacation Pause (unlocked by ANY
///             paid tier: monthly, yearly, or lifetime). Gated by `isPro`.
///   • PRO+  — ongoing perks ONLY for active subscribers (not lifetime): iCloud
///             sync, seasonal packs, early features. Gated by `isSubscriber`.
///
/// `isPro` / `isSubscriber` are driven by `StoreManager`'s live StoreKit
/// entitlement (no shadow UserDefaults flag, so refunds can't leave stale state).
@MainActor
@Observable
final class ProFeatureManager {

    /// One-time-or-subscription Pro features (any paid tier unlocks these).
    enum Feature: String, CaseIterable {
        case vacationPause
        case customPreAlertTiming
        case multiplePreAlerts
        case preAlertMessages
        case advancedSnooze
        case alarmGroups
        case calendarAwareSkip
        case themes
        case widgetCustomization
        case appIcons
        case customSounds

        var title: String {
            switch self {
            case .vacationPause: "Vacation pause (date ranges)"
            case .customPreAlertTiming: "Custom heads-up timing"
            case .multiplePreAlerts: "Multiple heads-ups"
            case .preAlertMessages: "Custom heads-up messages"
            case .advancedSnooze: "Advanced snooze"
            case .alarmGroups: "Alarm groups"
            case .calendarAwareSkip: "Holiday & calendar auto-skip"
            case .themes: "Themes & accents"
            case .widgetCustomization: "Widget customization"
            case .appIcons: "Alternate app icons"
            case .customSounds: "Custom alarm sound"
            }
        }

        /// One-line benefit shown under the title in the paywall.
        var benefit: String {
            switch self {
            case .vacationPause: "Pause for trips & holidays"
            case .customPreAlertTiming: "Any lead time, not just 15 min"
            case .multiplePreAlerts: "Stack 60 + 15 + 5 min heads-ups"
            case .preAlertMessages: "Your own reminder text"
            case .advancedSnooze: "Custom snooze duration"
            case .alarmGroups: "Bulk skip / pause a whole set"
            case .calendarAwareSkip: "Skip on calendar days off"
            case .themes: "Accents & light/dark"
            case .widgetCustomization: "Dedicated Pro widget styles (coming soon)"
            case .appIcons: "Match your Home Screen"
            case .customSounds: "Your own audio for the heads-up and the alarm"
            }
        }

        /// Features that ACTUALLY WORK today — the only ones the paywall may
        /// advertise as included (App Store rule + honesty).
        static let live: [Feature] = [
            .vacationPause, .customPreAlertTiming, .multiplePreAlerts, .preAlertMessages,
            .advancedSnooze, .alarmGroups, .calendarAwareSkip, .themes, .appIcons,
            .customSounds
        ]

        /// Built later, shipped free to Pro owners. Shown only as a clearly-labeled
        /// roadmap, never claimed as currently included.
        ///
        /// `widgetCustomization`: the configurable widget technically works for
        /// everyone today (no real Pro gate), so we do NOT sell it as an included
        /// Pro feature — dedicated Pro widget styles are the roadmap item.
        static let planned: [Feature] = [.widgetCustomization]
    }

    /// Subscriber-only ongoing perks (active monthly/yearly only — not lifetime).
    /// These justify a recurring fee because they keep arriving / cost to run.
    enum SubscriberPerk: String, CaseIterable {
        case iCloudSync
        case seasonalPacks
        case earlyAccess

        var title: String {
            switch self {
            case .iCloudSync: "iCloud sync across devices"
            case .seasonalPacks: "New seasonal theme & sound packs"
            case .earlyAccess: "Early access to new features"
            }
        }
    }

    /// True for any paid tier (monthly, yearly, or lifetime).
    var isPro: Bool = false
    /// True only for an active auto-renewing subscription.
    var isSubscriber: Bool = false
    /// Mirrors `StoreManager.resolved` — false until entitlements are known.
    var entitlementsResolved: Bool = false

    /// Pro features are available to anyone who has paid.
    func isAvailable(_ feature: Feature) -> Bool { isPro }

    /// Subscriber perks require an active subscription.
    func isAvailable(_ perk: SubscriberPerk) -> Bool { isSubscriber }
}
