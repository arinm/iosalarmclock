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
            case .vacationPause: String(localized: "Vacation pause (date ranges)")
            case .customPreAlertTiming: String(localized: "Custom heads-up timing")
            case .multiplePreAlerts: String(localized: "Multiple heads-ups")
            case .preAlertMessages: String(localized: "Custom heads-up messages")
            case .advancedSnooze: String(localized: "Longer snooze")
            case .alarmGroups: String(localized: "Alarm groups")
            case .calendarAwareSkip: String(localized: "Holiday & calendar auto-skip")
            case .themes: String(localized: "Themes & accents")
            case .widgetCustomization: String(localized: "Widget customization")
            case .appIcons: String(localized: "Alternate app icons")
            case .customSounds: String(localized: "Custom alarm sound")
            }
        }

        /// One-line benefit shown under the title in the paywall.
        var benefit: String {
            switch self {
            case .vacationPause: String(localized: "Pause for trips & holidays")
            case .customPreAlertTiming: String(localized: "Any lead time, not just 15 min")
            case .multiplePreAlerts: String(localized: "Stack 60 + 15 + 5 min heads-ups")
            case .preAlertMessages: String(localized: "Your own reminder text")
            // iOS 26's Clock added custom snooze capped at 15 min, so the
            // duration itself is no longer sellable — only the range past it is.
            case .advancedSnooze: String(localized: "Snooze up to 60 min, past the system's 15")
            case .alarmGroups: String(localized: "Bulk skip / pause a whole set")
            case .calendarAwareSkip: String(localized: "Skip on calendar days off")
            case .themes: String(localized: "Accents & light/dark")
            case .widgetCustomization: String(localized: "Dedicated Pro widget styles (coming soon)")
            case .appIcons: String(localized: "Match your Home Screen")
            case .customSounds: String(localized: "Your own audio for the heads-up and the alarm")
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
            case .iCloudSync: String(localized: "iCloud sync across devices")
            case .seasonalPacks: String(localized: "New seasonal theme & sound packs")
            case .earlyAccess: String(localized: "Early access to new features")
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
