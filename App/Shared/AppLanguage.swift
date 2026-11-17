import Foundation

/// The language Punctual shows its own words in: the one picked in Settings,
/// or the phone's ("Automatic"). Compiled into the app and the widget
/// extension, so the pick lives in the App Group.
///
/// A pick shows at once, without a relaunch: every `String(localized:)` takes
/// `bundle: AppLanguage.bundle`, and the views get `.environment(\.locale, …)`
/// for their `Text` keys and formats. A key with plural forms also takes
/// `locale: AppLanguage.locale`: the locale picks the form, not the bundle.
/// From the next launch on the process runs in that language itself
/// (`AppleLanguages`), and both fall back to `.main` and the current locale.
enum AppLanguage {
    /// The localizations Punctual ships, English first: it is the one used when
    /// none of the phone's languages is among them.
    static let supported = ["en", "ja", "de", "fr", "es", "es-419", "pt-BR"]

    /// Each language in its own name, as the picker lists it.
    static func name(_ code: String) -> String {
        switch code {
        case "ja": "日本語"
        case "de": "Deutsch"
        case "fr": "Français"
        case "es": "Español (España)"
        case "es-419": "Español (Latinoamérica)"
        case "pt-BR": "Português (Brasil)"
        default: "English"
        }
    }

    /// The pick; nil = Automatic. Read on every call: the widget process
    /// outlives timeline reloads and must see a new pick.
    static var choice: String? {
        defaults.string(forKey: choiceKey).flatMap { supported.contains($0) ? $0 : nil }
    }

    static func setChoice(_ code: String?) {
        defaults.set(code, forKey: choiceKey)
    }

    /// The language the words come from: the pick, else the phone's first
    /// language that Punctual has (English when none is).
    static var code: String {
        choice ?? Bundle.preferredLocalizations(
            from: supported, forPreferences: UserDefaults.standard.stringArray(forKey: "AppleLanguages")).first ?? "en"
    }

    /// Where `String(localized:)` finds the words: `.main` while the process
    /// runs in that language, else the language's own .lproj.
    static var bundle: Bundle {
        let code = code
        guard code != launchLanguage,
              let path = Bundle.main.path(forResource: code, ofType: "lproj"),
              let lproj = Bundle(path: path) else { return .main }
        return lproj
    }

    /// For dates, times and lists: the language with the phone's region and
    /// 12/24-hour setting kept ("午後6:30" on a US phone, "18:30" on a 24-hour one).
    static var locale: Locale {
        let code = code
        guard code != launchLanguage else { return .autoupdatingCurrent }
        var parts = Locale.Components(locale: .current)
        parts.languageComponents = Locale.Language.Components(identifier: code)
        parts.region = Locale.current.region
        parts.hourCycle = Locale.current.hourCycle
        return Locale(components: parts)
    }

    /// The language this process started in.
    private static var launchLanguage: String? { Bundle.main.preferredLocalizations.first }

    private static let choiceKey = "appLanguage"
    private static var defaults: UserDefaults {
        UserDefaults(suiteName: SharedModelContainer.appGroupID) ?? .standard
    }
}
