import SwiftUI
import UIKit

/// User-selectable appearance + accent (the real "Themes" Pro feature). Persists
/// to UserDefaults and is applied at the app root. Free users stay on the default
/// (peach accent, system appearance); Pro unlocks the picker.
@MainActor
@Observable
final class ThemeManager {
    /// Shared instance so the static `Theme.accent` can resolve the current
    /// accent without threading the environment through every call site.
    static let shared = ThemeManager()

    enum Accent: String, CaseIterable, Identifiable {
        case peach, ocean, teal, mint, forest, gold, sunset, rose, grape, indigo, graphite, custom
        var id: String { rawValue }
        /// Selectable preset swatches (everything except the custom picker).
        static var presets: [Accent] { allCases.filter { $0 != .custom } }
        var title: String {
            switch self {
            case .peach: String(localized: "Peach", bundle: AppLanguage.bundle); case .ocean: String(localized: "Ocean", bundle: AppLanguage.bundle)
            case .teal: String(localized: "Teal", bundle: AppLanguage.bundle); case .mint: String(localized: "Mint", bundle: AppLanguage.bundle)
            case .forest: String(localized: "Forest", bundle: AppLanguage.bundle); case .gold: String(localized: "Gold", bundle: AppLanguage.bundle)
            case .sunset: String(localized: "Sunset", bundle: AppLanguage.bundle); case .rose: String(localized: "Rose", bundle: AppLanguage.bundle)
            case .grape: String(localized: "Grape", bundle: AppLanguage.bundle); case .indigo: String(localized: "Indigo", bundle: AppLanguage.bundle)
            case .graphite: String(localized: "Graphite", bundle: AppLanguage.bundle); case .custom: String(localized: "Custom", bundle: AppLanguage.bundle)
            }
        }
        /// Light/dark adaptive accent color (single source of truth in BrandColor,
        /// shared with the widget). `.custom` resolves the user-picked color.
        var color: Color { BrandColor.accent(named: rawValue) }
    }

    enum Appearance: String, CaseIterable, Identifiable {
        case system, light, dark
        var id: String { rawValue }
        var title: String {
            switch self {
            case .system: String(localized: "System", bundle: AppLanguage.bundle, comment: "Appearance: follow the system light/dark setting")
            case .light: String(localized: "Light", bundle: AppLanguage.bundle)
            case .dark: String(localized: "Dark", bundle: AppLanguage.bundle)
            }
        }
        var colorScheme: ColorScheme? {
            switch self { case .system: nil; case .light: .light; case .dark: .dark }
        }
    }

    /// Stored in the shared App Group so the widget reads the same choice.
    private static var defaults: UserDefaults {
        UserDefaults(suiteName: SharedModelContainer.appGroupID) ?? .standard
    }

    var accent: Accent {
        didSet { Self.defaults.set(accent.rawValue, forKey: "themeAccent") }
    }
    var appearance: Appearance {
        didSet { Self.defaults.set(appearance.rawValue, forKey: "themeAppearance") }
    }

    init() {
        let d = Self.defaults
        accent = Accent(rawValue: d.string(forKey: "themeAccent") ?? "") ?? .peach
        appearance = Appearance(rawValue: d.string(forKey: "themeAppearance") ?? "") ?? .system
    }

    var accentColor: Color { accent.color }
    var colorScheme: ColorScheme? { appearance.colorScheme }

    /// The user's custom accent (for the ColorPicker). Setting it persists the
    /// RGB to the App Group and selects the custom accent.
    var customColor: Color {
        get { BrandColor.customAccent() }
        set {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            UIColor(newValue).getRed(&r, green: &g, blue: &b, alpha: &a)
            let d = Self.defaults
            d.set(Double(r), forKey: "themeCustomR")
            d.set(Double(g), forKey: "themeCustomG")
            d.set(Double(b), forKey: "themeCustomB")
            accent = .custom // triggers observation + persists "themeAccent"
        }
    }

    /// Nonisolated read of the persisted accent so the static `Theme.accent` can
    /// resolve it from any context.
    nonisolated static func persistedAccentColor() -> Color { BrandColor.currentAccent() }

    /// Revert to defaults (e.g. when Pro lapses).
    func resetToDefault() { accent = .peach; appearance = .system }
}
