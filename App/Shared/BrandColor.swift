import SwiftUI
import UIKit

/// Brand palette as code (light/dark adaptive via dynamic `UIColor`). Defined in
/// a shared file so the app, the widget, and the Live Activity all draw from the
/// SAME low-chroma, harmonized colors — no more raw system green/orange that
/// clashed with the warm accent. Compiled into both targets.
enum BrandColor {
    private static func dynamic(light: (CGFloat, CGFloat, CGFloat), dark: (CGFloat, CGFloat, CGFloat)) -> Color {
        Color(uiColor: UIColor { trait in
            let c = trait.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: c.0, green: c.1, blue: c.2, alpha: 1)
        })
    }

    /// Warm peach — the default brand accent.
    static let accent = dynamic(light: (0.96, 0.55, 0.42), dark: (1.00, 0.66, 0.52))
    /// Muted sage — "skip / still active".
    static let skip = dynamic(light: (0.33, 0.58, 0.44), dark: (0.56, 0.78, 0.62))
    /// Muted amber — "paused".
    static let pause = dynamic(light: (0.78, 0.58, 0.28), dark: (0.91, 0.75, 0.46))

    /// The accent palette by name — single source of truth shared by the app's
    /// ThemeManager AND the widget (which can't see ThemeManager).
    static func accent(named name: String) -> Color {
        switch name {
        case "ocean":    dynamic(light: (0.16, 0.48, 0.90), dark: (0.40, 0.68, 1.00))
        case "forest":   dynamic(light: (0.20, 0.56, 0.40), dark: (0.40, 0.78, 0.58))
        case "grape":    dynamic(light: (0.52, 0.36, 0.82), dark: (0.70, 0.55, 0.98))
        case "sunset":   dynamic(light: (0.90, 0.34, 0.42), dark: (1.00, 0.52, 0.56))
        case "graphite": dynamic(light: (0.36, 0.40, 0.46), dark: (0.66, 0.70, 0.76))
        case "teal":     dynamic(light: (0.10, 0.60, 0.62), dark: (0.36, 0.82, 0.84))
        case "rose":     dynamic(light: (0.85, 0.30, 0.55), dark: (1.00, 0.55, 0.74))
        case "indigo":   dynamic(light: (0.30, 0.34, 0.78), dark: (0.56, 0.58, 0.99))
        case "gold":     dynamic(light: (0.72, 0.55, 0.10), dark: (0.93, 0.78, 0.36))
        case "mint":     dynamic(light: (0.10, 0.62, 0.50), dark: (0.40, 0.88, 0.72))
        case "custom":   customAccent()
        default:         accent // peach
        }
    }

    /// User-picked custom accent, stored as RGB in the shared App Group.
    static func customAccent() -> Color {
        let d = UserDefaults(suiteName: SharedModelContainer.appGroupID) ?? .standard
        let r = d.object(forKey: "themeCustomR") as? Double ?? 0.98
        let g = d.object(forKey: "themeCustomG") as? Double ?? 0.58
        let b = d.object(forKey: "themeCustomB") as? Double ?? 0.45
        return Color(red: r, green: g, blue: b)
    }

    /// The user's currently-chosen accent, read from the shared App Group so the
    /// widget matches the in-app theme.
    static func currentAccent() -> Color {
        let defaults = UserDefaults(suiteName: SharedModelContainer.appGroupID) ?? .standard
        return accent(named: defaults.string(forKey: "themeAccent") ?? "peach")
    }
}
