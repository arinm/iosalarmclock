import XCTest

/// Drives the app through its screens and attaches a screenshot of each, for
/// App Store marketing shots. Run via `xcodebuild test`; extract the attachments
/// from the .xcresult bundle.
final class ScreenshotTests: XCTestCase {

    func testCaptureScreens() {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLocale", "en_US", "--seed-demo", "--demo-free", "--skip-onboarding"]
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

        // 05 — Skip today in action (the hero feature + inline confirmation)
        let skip = app.buttons["Skip today"].firstMatch
        if skip.waitForExistence(timeout: 4) {
            skip.tap()
            snap("05-SkipToday", wait: 1.5)
        }
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
