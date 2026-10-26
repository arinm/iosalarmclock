import XCTest

/// End-to-end check of calendar auto-skip (Pro) in the simulator, driven by the
/// DEBUG `--seed-calendar-skip` scenario:
///   • "Days Off (test)" (chosen) has an all-day "Test Holiday" tomorrow and a
///     5-day "Vacation" starting three days later
///   • "Work (test)" (not chosen) has an all-day "Conference" tomorrow
///   • the simulator has a contact with a birthday tomorrow (added beforehand)
/// Verifies: the skip is visible with its reason, Ring anyway re-arms it, and the
/// picker offers real calendars but never Birthdays.
final class CalendarAutoSkipTests: XCTestCase {

    func testCalendarSkipIsVisibleAndRingAnywayWorks() {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLocale", "en_US", "--skip-onboarding", "--seed-demo", "--seed-calendar-skip"] // --seed-demo: fresh alarms, no Ring anyway left from a previous run
        app.launch()

        // System prompts the seed triggers (notifications; calendar if not pre-granted).
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        // Prompts can appear late on a cold simulator: keep tapping until quiet.
        var quietSince = Date(); let deadline = Date().addingTimeInterval(15)
        while Date() < deadline, Date().timeIntervalSince(quietSince) < 4 {
            if let b = ["Allow Full Access", "Allow"].map({ springboard.buttons[$0] }).first(where: { $0.exists }) {
                b.tap(); quietSince = Date()
            }
            Thread.sleep(forTimeInterval: 0.5)
        }
        Thread.sleep(forTimeInterval: 5) // seed + refresh pass
        snap("01-list")

        // Wake up (6:30, weekdays). Located by its label: banners (e.g. alarm
        // permission off in a fresh simulator) shift the cell indexes.
        let card = text(app, "Wake up")
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.press(forDuration: 1.5)
        let details = app.buttons["Details"].exists ? app.buttons["Details"] : app.menuItems["Details"]
        XCTAssertTrue(details.waitForExistence(timeout: 3))
        details.tap()

        // One Ring anyway per skipped day; tomorrow's (the holiday) is first.
        let ring = app.buttons["Ring anyway"].firstMatch
        XCTAssertTrue(ring.waitForExistence(timeout: 5), "tomorrow's calendar skip should offer Ring anyway")
        let before = app.buttons.matching(identifier: "Ring anyway").count
        XCTAssertTrue(text(app, "Vacation").exists, "the vacation days should be listed too")
        XCTAssertTrue(text(app, "Test Holiday").exists, "the skip should name the calendar event")
        XCTAssertFalse(text(app, "Conference").exists, "an event in a calendar that wasn't chosen must not skip")
        snap("02-detail-skipped")

        ring.tap()
        XCTAssertTrue(text(app, "Rings anyway").waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(identifier: "Ring anyway").count, before - 1,
                       "only the tapped day comes back")
        snap("03-detail-ring-anyway")

        let picker = app.buttons["Days-off calendars"]
        XCTAssertTrue(picker.waitForExistence(timeout: 3))
        picker.tap()
        // Calendar rows are buttons (tap to tick); the explanation text mentions
        // "Birthdays", so check for a ROW of that name, not any text.
        XCTAssertTrue(app.buttons["Days Off (test)"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Work (test)"].exists)
        XCTAssertFalse(app.buttons["Birthdays"].exists, "Birthdays must never be offered")
        XCTAssertTrue(text(app, "Test Holiday").exists, "the preview should list what the choice skips")
        snap("04-picker")

        // Untick the only calendar: nothing is skipped any more, and the alarm
        // says so (fail-safe: no calendar chosen = everything rings).
        app.buttons["Days Off (test)"].tap()
        XCTAssertTrue(text(app, "Nothing is skipped").waitForExistence(timeout: 5))
        snap("05-picker-none")
        app.navigationBars["Days-off calendars"].buttons.element(boundBy: 0).tap()
        XCTAssertTrue(text(app, "Choose your days-off calendars").waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Ring anyway"].exists, "no calendar = no skipped days")
        snap("06-detail-no-calendar")
    }

    /// A static text whose label contains `s` (rows join several labels).
    private func text(_ app: XCUIApplication, _ s: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", s)).firstMatch
    }

    private func snap(_ name: String) {
        Thread.sleep(forTimeInterval: 1)
        let att = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        att.name = name
        att.lifetime = .keepAlways
        add(att)
    }
}
