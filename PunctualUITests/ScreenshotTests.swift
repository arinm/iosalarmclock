import XCTest

/// Drives the app through its screens and attaches a screenshot of each, for
/// App Store marketing shots. Run via `xcodebuild test`; extract the attachments
/// from the .xcresult bundle.
final class ScreenshotTests: XCTestCase {

    func testCaptureScreens() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-AppleLocale", "en_US",
            "--seed-demo", "--demo-free", "--skip-onboarding", "--app-store-screenshots"
        ]
        app.launch()

        // 01 — Home (hero + alarm cards)
        snap("01-Home", wait: 5)

        // 02 — Create / edit alarm
        let add = app.buttons["Add alarm"]
        if add.waitForExistence(timeout: 8) {
            add.tap()
            snap("02-Editor", wait: 2)
            tapIfExists(app.buttons["Cancel"])
        }

        // 03 — Settings, 04 — Paywall
        let settings = app.buttons["Settings"]
        if settings.waitForExistence(timeout: 5) {
            settings.tap()
            snap("03-Settings", wait: 2)

            let upgrade = app.buttons["Upgrade to Pro"]
            if upgrade.waitForExistence(timeout: 3) {
                upgrade.tap()
                snap("04-Paywall", wait: 3)
                tapIfExists(app.buttons["Close"])
            }
            tapIfExists(app.buttons["Done"])
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
            let details = menuElement(app, "Details")
            if details.waitForExistence(timeout: 3) {
                details.tap()
                snap("05-Detail", wait: 2)
                tapIfExists(app.buttons["Done"])
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
        for _ in 0..<6 {
            let skip = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Skip")).firstMatch
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
