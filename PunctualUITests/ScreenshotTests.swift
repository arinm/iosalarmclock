import XCTest

/// Drives the app through its screens and attaches a screenshot of each, for
/// App Store marketing shots. Run via `xcodebuild test`; extract the attachments
/// from the .xcresult bundle.
///
/// Language: English by default. For another one, run with
/// `TEST_RUNNER_SCREENSHOT_LANG=ja xcodebuild test ...` (ja, de, fr, es, pt-BR,
/// or es-MX for the Latin American es-419; xcodebuild hands
/// TEST_RUNNER_-prefixed variables to the test process without the prefix).
final class ScreenshotTests: XCTestCase {

    private static let lang = ProcessInfo.processInfo.environment["SCREENSHOT_LANG"] ?? "en"

    /// `-AppleLanguages` / `-AppleLocale` per language.
    private static let locales: [String: (language: String, locale: String)] = [
        "en": ("en", "en_US"), "ja": ("ja", "ja_JP"), "de": ("de", "de_DE"), "fr": ("fr", "fr_FR"),
        "es": ("es", "es_ES"), "es-MX": ("es-MX", "es_MX"), "pt-BR": ("pt-BR", "pt_BR"),
    ]

    /// Button labels the test taps, per language (they must match the catalog).
    /// "Skip %@" is the card's inline Skip button.
    private static let labels: [String: [String: String]] = [
        "ja": ["Add alarm": "アラームを追加", "Cancel": "キャンセル", "Settings": "設定",
               "Upgrade to Pro": "Proにアップグレード", "Close": "閉じる", "Done": "完了", "Details": "詳細",
               "Skip %@": "%@をスキップ"],
        "de": ["Add alarm": "Wecker hinzufügen", "Cancel": "Abbrechen", "Settings": "Einstellungen",
               "Upgrade to Pro": "Auf Pro umsteigen", "Close": "Schließen", "Done": "Fertig", "Details": "Details",
               "Skip %@": "Nur %@ überspringen"],
        "fr": ["Add alarm": "Ajouter une alarme", "Cancel": "Annuler", "Settings": "Réglages",
               "Upgrade to Pro": "Passer à Pro", "Close": "Fermer", "Done": "OK", "Details": "Détails",
               "Skip %@": "Ignorer %@"],
        "es": ["Add alarm": "Añadir alarma", "Cancel": "Cancelar", "Settings": "Ajustes",
               "Upgrade to Pro": "Hazte Pro", "Close": "Cerrar", "Done": "OK", "Details": "Detalles",
               "Skip %@": "Omitir %@"],
        // es-419 is es with "Configuración" for Settings.
        "es-MX": ["Add alarm": "Añadir alarma", "Cancel": "Cancelar", "Settings": "Configuración",
                  "Upgrade to Pro": "Hazte Pro", "Close": "Cerrar", "Done": "OK", "Details": "Detalles",
                  "Skip %@": "Omitir %@"],
        "pt-BR": ["Add alarm": "Adicionar alarme", "Cancel": "Cancelar", "Settings": "Ajustes",
                  "Upgrade to Pro": "Obter o Pro", "Close": "Fechar", "Done": "OK", "Details": "Detalhes",
                  "Skip %@": "Pular %@"],
    ]

    private func t(_ english: String) -> String { Self.labels[Self.lang]?[english] ?? english }

    func testCaptureScreens() {
        let app = XCUIApplication()
        let locale = Self.locales[Self.lang] ?? Self.locales["en"]!
        app.launchArguments += ["-AppleLanguages", "(\(locale.language))", "-AppleLocale", locale.locale]
        app.launchArguments += ["--seed-demo", "--demo-free", "--skip-onboarding", "--app-store-screenshots"]
        app.launch()

        // 01 — Home (hero + alarm cards)
        snap("01-Home", wait: 5)

        // 02 — Create / edit alarm
        let add = app.buttons[t("Add alarm")]
        if add.waitForExistence(timeout: 8) {
            add.tap()
            snap("02-Editor", wait: 2)
            tapIfExists(app.buttons[t("Cancel")])
        }

        // 03 — Settings, 04 — Paywall
        let settings = app.buttons[t("Settings")]
        if settings.waitForExistence(timeout: 5) {
            settings.tap()
            snap("03-Settings", wait: 2)

            // The paywall shot shows prices, so it can NEVER go in the App Store
            // screenshot set - guideline 2.3.7 counts prices, discounts and even
            // the word "free" as price references, and build 20 was rejected for
            // exactly this image. It IS the right image for the App Review
            // screenshot each In-App Purchase requires, which is internal to
            // review and never shown to users. Hence the filename.
            let upgrade = app.buttons[t("Upgrade to Pro")]
            if upgrade.waitForExistence(timeout: 3) {
                upgrade.tap()
                snap("NOT-FOR-STORE-iap-review-Paywall", wait: 3)
                tapIfExists(app.buttons[t("Close")])
            }
            tapIfExists(app.buttons[t("Done")])
        }

        // List rows surface as cells: row 0 is the hero summary, alarm cards
        // follow. (The combined card element doesn't reliably appear in the
        // buttons query, but the cell always exists.)
        let card = app.cells.element(boundBy: 1)

        // 05 — Alarm detail (skipped days, pauses, snooze)
        if card.waitForExistence(timeout: 5) {
            card.press(forDuration: 1.5)
            // Context-menu items surface as buttons or menuItems depending on
            // the host container — try both.
            let details = menuElement(app, t("Details"))
            if details.waitForExistence(timeout: 3) {
                details.tap()
                snap("05-Detail", wait: 2)
                tapIfExists(app.buttons[t("Done")])
            } else {
                app.swipeDown() // dismiss any partial menu state
            }
        }

        // 06 — the Skip BUTTON visible on a card (pre-tap marketing shot), then
        // 07 — the confirmation banner after tapping (the hero feature).
        // Scroll until a within-24h card exposes its inline Skip button; this is
        // much less flaky than a List full-swipe in screenshots.
        if let skip = findInlineSkipButton(app) {
            snap("06-SkipButton", wait: 1)
            skip.tap()
            snap("07-SkipConfirmation", wait: 2)
        }

        // 08 — bottom of the list at rest: verifies the floating + never covers
        // the LAST card's action button (safeAreaInset clearance).
        for _ in 0..<5 { app.swipeUp() }
        snap("08-BottomOfList", wait: 1.5)
    }

    private func menuElement(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        app.buttons[name].exists ? app.buttons[name] : app.menuItems[name]
    }

    private func findInlineSkipButton(_ app: XCUIApplication) -> XCUIElement? {
        // "Skip today" / "今日をスキップ" / "Nur heute überspringen": match the
        // text around the day word, wherever the language puts it.
        // NSPredicate is false for BEGINSWITH/ENDSWITH "", so test only the non-empty parts.
        let parts = t("Skip %@").components(separatedBy: "%@")
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            parts[0].isEmpty ? nil : NSPredicate(format: "label BEGINSWITH %@", parts[0]),
            parts[1].isEmpty ? nil : NSPredicate(format: "label ENDSWITH %@", parts[1]),
        ].compactMap { $0 })
        for _ in 0..<6 {
            let skip = app.buttons.matching(predicate).firstMatch
            if skip.waitForExistence(timeout: 1), skip.isHittable {
                return skip
            }
            app.swipeUp()
        }
        return nil
    }

    private func tapIfExists(_ el: XCUIElement) {
        if el.waitForExistence(timeout: 2) { el.tap() }
    }

    private func snap(_ name: String, wait: TimeInterval) {
        Thread.sleep(forTimeInterval: wait)
        let att = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        att.name = name
        att.lifetime = .keepAlways
        add(att)
    }
}
