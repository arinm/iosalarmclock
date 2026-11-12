import Foundation

/// Language for the QA UI tests. English by default; for Japanese run with
/// `TEST_RUNNER_QA_LANG=ja xcodebuild test ...` (xcodebuild hands
/// TEST_RUNNER_-prefixed variables to the test process without the prefix).
enum QALang {
    static let code = ProcessInfo.processInfo.environment["QA_LANG"] ?? "en"
    static var isJapanese: Bool { code == "ja" }

    static var launchArguments: [String] {
        isJapanese ? ["-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
                   : ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
    }

    /// Labels and label fragments the tests look for, per language (they must
    /// match the catalog). Calendar and event names come from the DEBUG seed
    /// and stay English.
    private static let ja: [String: String] = [
        "Wake up": "起床", "Meds": "薬", "Wind down": "おやすみ準備",
        "Details": "詳細", "Done": "完了", "Save": "保存", "Undo": "取り消す",
        "Continue": "続ける", "Stop": "停止", "None": "なし",
        "Ring anyway": "それでも鳴らす", "Rings anyway": "鳴らします",
        "Days-off calendars": "休日カレンダー",
        "Choose your days-off calendars": "休日カレンダーを選択",
        "Nothing is skipped": "何もスキップされません",
        "alarms won't ring": "件のアラームが鳴りません",
        "alarms are off": "件のアラームがオフです",
        "Rings in": "鳴るまであと", "Rings in 1d": "鳴るまであと1日", "1d": "1日",
        "Auto-skip on calendar days off": "カレンダーの休日に自動スキップ",
        "1 calendar": "1件を選択中",
        "Calendar days off": "カレンダーの休日",
        "still active": "有効のまま",
        "can't ring until you allow": "許可するまで、アラームは鳴りません",
        "won't ring": "鳴りません",
    ]

    static func t(_ english: String) -> String { isJapanese ? (ja[english] ?? english) : english }

    /// The card's Skip button: "Skip today" / "今日をスキップ".
    static var skipButton: NSPredicate {
        isJapanese ? NSPredicate(format: "label ENDSWITH 'スキップ'") : NSPredicate(format: "label BEGINSWITH 'Skip'")
    }

    /// System prompt buttons, in either system language.
    static let allow = ["Allow Full Access", "Allow", "フルアクセスを許可", "許可"]
}
