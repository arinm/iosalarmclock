import Foundation
import Observation
import WidgetKit

/// The language picked in Settings, for the views to follow (`AppLanguage` says
/// how a pick shows at once). It is also written as `AppleLanguages`, so from
/// the next launch on the app starts in it, iOS's own text included. iOS's
/// per-app language (Settings › Apps › Punctual) writes that same key and
/// relaunches the app.
@MainActor @Observable final class LanguageManager {
    /// nil = Automatic (the phone's language).
    private(set) var choice: String?
    /// The language the words come from now.
    private(set) var code: String
    /// What the views get as `\.locale`, for their `Text` keys and formats.
    private(set) var locale: Locale

    init() {
        // A pick sits in the app's own defaults (ours or iOS Settings'): mirror
        // the language this launch runs in to the App Group, for the widget.
        let picked = Bundle.main.bundleIdentifier
            .flatMap { UserDefaults.standard.persistentDomain(forName: $0) }?["AppleLanguages"] != nil
        let launch = picked ? Bundle.main.preferredLocalizations.first : nil
        if launch != AppLanguage.choice {
            AppLanguage.setChoice(launch)
            WidgetCenter.shared.reloadAllTimelines()
        }
        choice = AppLanguage.choice
        code = AppLanguage.code
        locale = AppLanguage.locale
        // A picked language's locale carries the phone's 12/24-hour setting
        // as it was: rebuild it when that (or the region) changes.
        Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: NSLocale.currentLocaleDidChangeNotification) {
                self?.locale = AppLanguage.locale
            }
        }
    }

    func select(_ newChoice: String?) {
        guard newChoice != choice else { return }
        if let newChoice {
            UserDefaults.standard.set([newChoice], forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        }
        AppLanguage.setChoice(newChoice)
        pickCount += 1
        choice = newChoice
        code = AppLanguage.code
        locale = AppLanguage.locale
    }

    /// True while `syncAlarmLanguage` re-arms the alarms.
    @ObservationIgnored var isSyncingAlarms = false
    /// Bumped by every pick, so a re-arm can tell it was overtaken even when
    /// the language ends where it started.
    @ObservationIgnored private(set) var pickCount = 0

    /// The language the armed alarms show their title, Stop and Snooze in: the
    /// alarm screen keeps the words an alarm was armed with.
    var alarmsLanguage: String? {
        get { UserDefaults.standard.string(forKey: "alarmsLanguage") }
        set { UserDefaults.standard.set(newValue, forKey: "alarmsLanguage") }
    }
}
