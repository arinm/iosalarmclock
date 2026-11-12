import XCTest

/// QA pass for calendar auto-skip plus a regression sweep of the core flows,
/// driven by DEBUG-only launch arguments (see CalendarSkipDebugSeed):
///   --seed-demo            fresh demo alarms (Wake up 6:30 weekdays, Gym 7:15 MWF,
///                          Meds 8:00 daily, Wind down 22:30 weekdays)
///   --seed-calendar-skip   "Days Off (test)" chosen: holiday tomorrow + 5-day vacation
///   --calskip-notice-now   deliver the pending calendar notices right away
///   --demo-pro             Pro unlocked without a purchase
///   --seed-ring-test       one-time alarm two minutes from now
final class CalendarAutoSkipQATests: XCTestCase {

    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    override func setUp() { continueAfterFailure = false }

    // MARK: Calendar auto-skip

    /// The grouped notices reach Notification Center (one per holiday, one per
    /// vacation). Visual check; the action itself is covered below.
    func testNoticesShowInNotificationCenter() {
        _ = launch(["--seed-demo", "--seed-calendar-skip", "--calskip-notice-now"])
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 2)
        let from = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.0))
        from.press(forDuration: 0.2, thenDragTo: springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.75)))
        Thread.sleep(forTimeInterval: 2)
        snap("qa-01-notification-center")
        XCTAssertTrue(any(springboard, t("alarms won't ring")).waitForExistence(timeout: 8), "grouped holiday notice")
        XCTAssertTrue(any(springboard, t("alarms are off")).exists, "one vacation notice")
    }

    /// Ring anyway (the notification action's own code path, fed the notice's
    /// own userInfo) restores tomorrow for every alarm listed, and only tomorrow.
    func testRingAnywayFromTheNotice() {
        let app = launch(["--seed-demo", "--seed-calendar-skip", "--calskip-qa-ring-anyway"])
        for label in [t("Wake up"), t("Meds"), t("Wind down")] {
            openDetails(app, label)
            XCTAssertTrue(any(app, t("Rings anyway")).waitForExistence(timeout: 5), "\(label): tomorrow should ring anyway")
            XCTAssertTrue(app.buttons[t("Ring anyway")].firstMatch.exists, "\(label): the vacation days must stay skipped")
            snap("qa-03-detail-\(label)")
            app.buttons[t("Done")].tap()
        }
    }

    /// Switching auto-skip OFF in the editor brings tomorrow's ring back at once
    /// (it used to wait for the next app launch).
    func testTurningAutoSkipOffInTheEditorIsImmediate() {
        let app = launch(["--seed-demo", "--seed-calendar-skip", "--demo-pro"])
        XCTAssertTrue(any(app, t("Rings in 1d")).waitForExistence(timeout: 5), "Wake up should be skipped tomorrow first")
        any(app, t("Wake up")).tap()                                 // card tap opens the editor
        let toggle = app.switches[t("Auto-skip on calendar days off")]
        for _ in 0..<6 where !toggle.isHittable { app.swipeUp() }
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        app.swipeUp()                                             // the calendars row sits under the toggle
        XCTAssertTrue(any(app, t("1 calendar")).waitForExistence(timeout: 3), "the editor should show the chosen calendar")
        snap("qa-04-editor-on")
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()  // the switch itself, not the label
        XCTAssertEqual(toggle.value as? String, "0", "auto-skip should now be off")
        snap("qa-05-editor-off")
        app.buttons[t("Save")].tap()
        Thread.sleep(forTimeInterval: 2)
        openDetails(app, t("Wake up"))
        XCTAssertFalse(any(app, t("Calendar days off")).exists, "no calendar section once auto-skip is off")
        let status = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", t("Rings in"))).firstMatch
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        XCTAssertFalse(status.label.contains(t("1d")), "tomorrow must ring again right away, got: \(status.label)")
        snap("qa-06-detail-after-off")
    }

    // MARK: Core regression (no calendar involved)

    /// Skip from the card, then Undo: the hero action still works.
    func testSkipFromTheCardAndUndo() {
        let app = launch(["--seed-demo"])
        let skip = app.buttons.matching(QALang.skipButton).firstMatch
        for _ in 0..<4 where !skip.exists { app.swipeUp() }
        XCTAssertTrue(skip.waitForExistence(timeout: 5))
        skip.tap()
        XCTAssertTrue(any(app, t("still active")).waitForExistence(timeout: 5), "confirmation banner")
        snap("qa-07-skipped")
        let undo = app.buttons[t("Undo")]
        XCTAssertTrue(undo.waitForExistence(timeout: 3))
        undo.tap()
        Thread.sleep(forTimeInterval: 2)
        openDetails(app, t("Wake up"))
        XCTAssertTrue(any(app, t("None")).exists, "Undo should leave no skipped days")
        snap("qa-08-undone")
    }

    /// Fresh install: onboarding grants alarms + notifications, then a real
    /// AlarmKit alarm two minutes out actually rings in the simulator.
    func testOnboardingAndARealRing() {
        let app = XCUIApplication()
        app.launchArguments += QALang.launchArguments
        app.launch()
        let cont = app.buttons[t("Continue")]
        XCTAssertTrue(cont.waitForExistence(timeout: 40))         // first launch on a fresh simulator is slow
        cont.tap()
        allow(QALang.allow)                                          // AlarmKit
        XCTAssertFalse(any(app, t("can't ring until you allow")).exists, "alarm permission should be granted")
        XCTAssertTrue(cont.waitForExistence(timeout: 10))
        cont.tap()
        allow(QALang.allow)                                          // notifications
        Thread.sleep(forTimeInterval: 2)
        snap("qa-09-after-onboarding")
        app.terminate()

        app.launchArguments = QALang.launchArguments + ["--skip-onboarding", "--seed-ring-test"]
        app.launch()
        XCTAssertTrue(any(app, "QA ring").waitForExistence(timeout: 8))
        XCTAssertFalse(any(app, t("won't ring")).exists, "the alarm must arm (no 'won't ring' warning)")
        snap("qa-10-ring-armed")
        XCUIDevice.shared.press(.home)
        // The alert can take the whole two minutes plus a little.
        let alert = any(springboard, "QA ring")
        XCTAssertTrue(alert.waitForExistence(timeout: 200), "the AlarmKit alarm should ring")
        snap("qa-11-ringing")
        let stop = springboard.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", t("Stop"))).firstMatch
        if stop.exists { stop.tap() }
    }

    // MARK: Helpers

    private func t(_ english: String) -> String { QALang.t(english) }

    private func launch(_ args: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += QALang.launchArguments + ["--skip-onboarding"] + args
        app.launch()
        allow(QALang.allow)
        Thread.sleep(forTimeInterval: 5)                          // seed + refresh
        return app
    }

    /// Tap system permission prompts as they come (they can appear late on a
    /// cold simulator); stop once none has shown up for a few seconds.
    private func allow(_ labels: [String], within seconds: TimeInterval = 15) {
        let deadline = Date().addingTimeInterval(seconds)
        var quietSince = Date()
        while Date() < deadline, Date().timeIntervalSince(quietSince) < 4 {
            if let b = labels.map({ springboard.buttons[$0] }).first(where: { $0.exists }) {
                b.tap(); quietSince = Date()
            }
            Thread.sleep(forTimeInterval: 0.5)
        }
    }

    private func openDetails(_ app: XCUIApplication, _ label: String) {
        let card = any(app, label)
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        // A card low on screen sits under the + button: scroll it up first.
        if card.frame.midY > app.frame.height * 0.6 { app.swipeUp(); Thread.sleep(forTimeInterval: 1) }
        card.press(forDuration: 1.5)
        let details = app.buttons[t("Details")].exists ? app.buttons[t("Details")] : app.menuItems[t("Details")]
        XCTAssertTrue(details.waitForExistence(timeout: 3))
        details.tap()
    }

    private func any(_ app: XCUIApplication, _ s: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] %@", s)).firstMatch
    }

    private func snap(_ name: String) {
        Thread.sleep(forTimeInterval: 1)
        let att = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        att.name = name
        att.lifetime = .keepAlways
        add(att)
    }
}
