import XCTest

/// Drives the two takes of social clip 07 ("Are you up?") while
/// `simctl io recordVideo` films the simulator. The holds are long on purpose:
/// the clip is cut from the calm stretches, never from a swipe.
///
/// Japanese: `TEST_RUNNER_QA_LANG=ja xcodebuild test ...` (see `QALang`).
final class ClipCaptureTests: XCTestCase {

    private static let ja: [String: String] = ["Are you up?": "起きましたか？", "I'm up": "起きました", "Cancel": "キャンセル"]
    private func t(_ english: String) -> String { QALang.isJapanese ? (Self.ja[english] ?? QALang.t(english)) : english }

    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += QALang.launchArguments
        app.launchArguments += ["--seed-demo", "--demo-pro", "--skip-onboarding", "--app-store-screenshots"] + extra
        app.launch()
        return app
    }

    /// Take A: the "Wake up" editor, the Are you up? switch turned on.
    func testTakeEditor() {
        let app = launch()
        let card = app.staticTexts[t("Wake up")].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 2)
        card.tap()
        XCTAssertTrue(app.buttons[t("Cancel")].firstMatch.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1)
        let toggle = app.switches[t("Are you up?")]  // the form is lazy: it exists once scrolled near
        for _ in 0..<8 where !toggle.exists || !toggle.isHittable || toggle.frame.midY > app.frame.height * 0.55 { app.swipeUp() }
        XCTAssertTrue(toggle.isHittable)
        Thread.sleep(forTimeInterval: 3)
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()  // the switch itself, not the label
        Thread.sleep(forTimeInterval: 4)
        XCTAssertEqual(toggle.value as? String, "1")
        app.buttons[t("Cancel")].firstMatch.tap()
        Thread.sleep(forTimeInterval: 1)
    }

    /// Take B: the list with the check waiting (`--wakecheck-clip`), then I'm up.
    func testTakeList() {
        let app = launch(["--wakecheck-clip"])
        let imUp = app.buttons[t("I'm up")]
        XCTAssertTrue(imUp.waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 4)
        imUp.tap()
        Thread.sleep(forTimeInterval: 4)
        XCTAssertFalse(imUp.exists)
    }
}
