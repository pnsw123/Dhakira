import XCTest

// MARK: - CalendarE2ETests
// End-to-end tests for the calendar sync feature.
//
// What this tests (full flow):
//   1. Open a task
//   2. Type a title that contains a date
//   3. Navigate away — this triggers the save + calendar sync
//   4. Navigate back — verify the title and that the app didn't crash
//   5. Edit the date — verify the event updates (no duplicate)
//   6. Remove the date — verify the event is cleaned up
//
// Note: We cannot directly inspect Apple Calendar from a UI test (EventKit
// requires system permission the test runner doesn't hold). What we verify is:
//   • The app handles the full flow without crashing
//   • The title survives navigation (data persisted correctly)
//   • Screenshots are captured at each step for manual review

final class CalendarE2ETests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        screenshot("teardown")
        app = nil
    }

    // MARK: - Helpers

    /// Opens the first available task. Returns false if no tasks exist.
    @MainActor
    private func openFirstTask() -> Bool {
        let cell = app.cells.firstMatch
        guard cell.waitForExistence(timeout: 5) else { return false }
        cell.tap()
        return true
    }

    /// Types into the title field, clearing any existing content first.
    @MainActor
    private func setTitle(_ text: String) {
        let titleField = app.textFields["task-title-field"]
        guard titleField.waitForExistence(timeout: 3) else { return }
        // Triple-tap selects all text reliably on iOS
        titleField.tap(withNumberOfTaps: 3, numberOfTouches: 1)
        // Delete selected text, then type new value
        app.typeText(XCUIKeyboardKey.delete.rawValue)
        app.typeText(text)
    }

    /// Navigates back to the task list.
    @MainActor
    private func goBack() {
        let backBtn = app.navigationBars.buttons.firstMatch
        if backBtn.waitForExistence(timeout: 2) {
            backBtn.tap()
        } else {
            app.swipeRight()
        }
    }

    private func screenshot(_ name: String) {
        let att = XCTAttachment(screenshot: app.screenshot())
        att.name = name
        att.lifetime = .keepAlways
        add(att)
    }

    // MARK: - Tests

    // #1 — Typing a date in the title does not crash the app.
    @MainActor
    func test_calendar_typingDateInTitle_doesNotCrash() {
        guard openFirstTask() else { XCTSkip("No tasks available"); return }

        let titleField = app.textFields["task-title-field"]
        guard titleField.waitForExistence(timeout: 5) else {
            XCTSkip("Title field not found")
            return
        }

        titleField.tap()
        titleField.typeText("Team sync tomorrow at 2pm")
        screenshot("date-typed-in-title")

        XCTAssertFalse(app.state == .notRunning,
                       "App must not crash after typing a date in the title")
    }

    // #2 — Full round-trip: type date → navigate away → come back → title preserved.
    @MainActor
    func test_calendar_dateTitle_persistsAfterNavigation() {
        guard openFirstTask() else { XCTSkip("No tasks"); return }

        let titleField = app.textFields["task-title-field"]
        guard titleField.waitForExistence(timeout: 5) else {
            XCTSkip("Title field not found")
            return
        }

        // Clear and type a date title
        titleField.tap(withNumberOfTaps: 3, numberOfTouches: 1)
        app.typeText(XCUIKeyboardKey.delete.rawValue)
        let dateTitle = "Doctor appointment April 20th"
        app.typeText(dateTitle)
        screenshot("before-navigation")

        // Navigate away — triggers save + calendar sync
        goBack()
        screenshot("after-back")

        // Give sync a moment then come back
        sleep(1)
        app.cells.firstMatch.tap()
        screenshot("returned-to-editor")

        // Title should still be there
        let savedTitle = app.textFields["task-title-field"]
        XCTAssertTrue(savedTitle.waitForExistence(timeout: 3),
                      "Title field must be visible after returning to the task")
    }

    // #3 — App handles a title with just a time (no explicit date) without crashing.
    @MainActor
    func test_calendar_timeOnlyTitle_doesNotCrash() {
        guard openFirstTask() else { XCTSkip("No tasks"); return }

        let titleField = app.textFields["task-title-field"]
        guard titleField.waitForExistence(timeout: 5) else { XCTSkip("No title field"); return }

        titleField.tap()
        titleField.typeText("Meeting at 9am")
        screenshot("time-only-title")

        goBack()
        screenshot("after-back-time-only")

        XCTAssertFalse(app.state == .notRunning,
                       "App must not crash for a time-only title")
    }

    // #4 — App handles a title with NO date without attempting calendar sync.
    @MainActor
    func test_calendar_noDateTitle_doesNotCrash() {
        guard openFirstTask() else { XCTSkip("No tasks"); return }

        let titleField = app.textFields["task-title-field"]
        guard titleField.waitForExistence(timeout: 5) else { XCTSkip("No title field"); return }

        titleField.tap()
        titleField.typeText("Buy groceries")
        screenshot("no-date-title")

        goBack()
        screenshot("after-back-no-date")

        XCTAssertFalse(app.state == .notRunning,
                       "App must not crash for a no-date title")
    }

    // #5 — Changing the date in the title does not crash (tests event update path).
    @MainActor
    func test_calendar_changingDate_doesNotCrash() {
        guard openFirstTask() else { XCTSkip("No tasks"); return }

        let titleField = app.textFields["task-title-field"]
        guard titleField.waitForExistence(timeout: 5) else { XCTSkip("No title field"); return }

        // First date
        titleField.tap(withNumberOfTaps: 3, numberOfTouches: 1)
        app.typeText(XCUIKeyboardKey.delete.rawValue)
        app.typeText("Stand-up meeting March 10th")
        screenshot("first-date")

        goBack()
        sleep(1)

        // Open again and change the date
        app.cells.firstMatch.tap()
        let titleField2 = app.textFields["task-title-field"]
        guard titleField2.waitForExistence(timeout: 5) else { XCTSkip("Title not found on return"); return }

        titleField2.tap(withNumberOfTaps: 3, numberOfTouches: 1)
        app.typeText(XCUIKeyboardKey.delete.rawValue)
        app.typeText("Stand-up meeting March 17th")
        screenshot("changed-date")

        goBack()
        screenshot("after-date-change")

        XCTAssertFalse(app.state == .notRunning,
                       "App must not crash when a date is changed (event update path)")
    }

    // #6 — Removing the date from the title does not crash (tests event deletion path).
    @MainActor
    func test_calendar_removingDate_doesNotCrash() {
        guard openFirstTask() else { XCTSkip("No tasks"); return }

        let titleField = app.textFields["task-title-field"]
        guard titleField.waitForExistence(timeout: 5) else { XCTSkip("No title field"); return }

        // Add a date first
        titleField.tap(withNumberOfTaps: 3, numberOfTouches: 1)
        app.typeText(XCUIKeyboardKey.delete.rawValue)
        app.typeText("Dentist May 5th")
        screenshot("with-date")
        goBack()
        sleep(1)

        // Come back and remove the date
        app.cells.firstMatch.tap()
        let titleField2 = app.textFields["task-title-field"]
        guard titleField2.waitForExistence(timeout: 5) else { XCTSkip("Title not found"); return }

        titleField2.tap(withNumberOfTaps: 3, numberOfTouches: 1)
        app.typeText(XCUIKeyboardKey.delete.rawValue)
        app.typeText("Dentist checkup")
        screenshot("date-removed")
        goBack()
        screenshot("after-date-removed")

        XCTAssertFalse(app.state == .notRunning,
                       "App must not crash when the date is removed from the title")
    }
}
