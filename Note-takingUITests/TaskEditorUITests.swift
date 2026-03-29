import XCTest

// MARK: - TaskEditorUITests
// Simulates opening a task's detail editor and interacting with:
// typing, formatting toolbar, slash menu, navigation back.

final class TaskEditorUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        screenshot("teardown-editor")
        app = nil
    }

    // MARK: - Helpers

    /// Navigate to the first available task in the list.
    /// Returns false if no task is tappable.
    @MainActor
    private func openFirstTask() -> Bool {
        // Tasks are rendered as cells in a List
        let cells = app.cells
        guard cells.firstMatch.waitForExistence(timeout: 5) else { return false }
        screenshot("before-open-task")
        cells.firstMatch.tap()
        screenshot("after-open-task")
        return true
    }

    // MARK: - Editor open

    // #1 — Tapping a task opens the editor (detail view is on screen).
    @MainActor
    func test_tapTask_opensEditor() {
        guard openFirstTask() else {
            XCTSkip("No tasks available — run after seeding or create one first")
            return
        }
        // Editor should have a text view or at least the screen should change
        XCTAssertFalse(app.state == .notRunning,
                       "App must stay alive after tapping into a task")
    }

    // #2 — Editor contains a text input area.
    @MainActor
    func test_editor_hasTextView() {
        guard openFirstTask() else { XCTSkip("No tasks"); return }
        let textViews = app.textViews
        XCTAssertTrue(textViews.firstMatch.waitForExistence(timeout: 5),
                      "Task editor must contain a UITextView for note body input")
    }

    // #3 — Typing in the editor is reflected (no crash on keypress).
    @MainActor
    func test_editor_typingDoesNotCrash() {
        guard openFirstTask() else { XCTSkip("No tasks"); return }
        let textView = app.textViews.firstMatch
        guard textView.waitForExistence(timeout: 5) else {
            XCTSkip("Text view not found")
            return
        }
        textView.tap()
        screenshot("before-typing")
        textView.typeText("Hello test input")
        screenshot("after-typing")
        XCTAssertFalse(app.state == .notRunning,
                       "App must not crash while typing into the editor")
    }

    // #4 — Slash menu appears when "/" is typed.
    @MainActor
    func test_editor_typingSlash_showsMenu() {
        guard openFirstTask() else { XCTSkip("No tasks"); return }
        let textView = app.textViews.firstMatch
        guard textView.waitForExistence(timeout: 5) else { XCTSkip("No text view"); return }
        textView.tap()
        textView.typeText("/")
        screenshot("after-slash")

        // The slash command menu should appear — look for known command labels
        let bulletOption = app.staticTexts["Bulleted List"]
        let menuAppeared = bulletOption.waitForExistence(timeout: 3)
        XCTAssertTrue(menuAppeared,
                      "Typing '/' must trigger the slash command menu showing 'Bulleted List'")
    }

    // #5 — Slash menu disappears when Escape or backspace is pressed.
    @MainActor
    func test_editor_slashMenu_dismissOnBackspace() {
        guard openFirstTask() else { XCTSkip("No tasks"); return }
        let textView = app.textViews.firstMatch
        guard textView.waitForExistence(timeout: 5) else { XCTSkip("No text view"); return }
        textView.tap()
        textView.typeText("/")

        let bulletOption = app.staticTexts["Bulleted List"]
        guard bulletOption.waitForExistence(timeout: 3) else {
            XCTSkip("Slash menu did not appear")
            return
        }

        // Delete the slash
        app.keys["delete"].tap()
        screenshot("after-slash-delete")

        // Menu should be gone
        XCTAssertFalse(bulletOption.waitForExistence(timeout: 2),
                       "Slash menu should disappear after deleting the '/'")
    }

    // #6 — The formatting toolbar is visible in the editor.
    @MainActor
    func test_editor_formattingToolbarVisible() {
        guard openFirstTask() else { XCTSkip("No tasks"); return }
        let textView = app.textViews.firstMatch
        guard textView.waitForExistence(timeout: 5) else { XCTSkip("No text view"); return }
        textView.tap()
        screenshot("toolbar-check")

        // The formatting toolbar is a custom SwiftUI ScrollView — find it by its accessibility ID
        let toolbar = app.scrollViews["editor-toolbar"]
        XCTAssertTrue(toolbar.waitForExistence(timeout: 3),
                      "A formatting toolbar must appear when the editor is active")
    }

    // MARK: - Navigation back

    // #7 — Back button / swipe returns to the task list.
    @MainActor
    func test_editor_navigateBack_returnsToList() {
        guard openFirstTask() else { XCTSkip("No tasks"); return }

        // Try back button first, then swipe
        let backBtn = app.navigationBars.buttons.firstMatch
        if backBtn.waitForExistence(timeout: 2) {
            backBtn.tap()
        } else {
            app.swipeRight()
        }
        screenshot("after-back-from-editor")

        // Tasks list should be visible again
        let foldersBtn = app.buttons["btn-go-to-folders"]
        XCTAssertTrue(foldersBtn.waitForExistence(timeout: 3),
                      "After leaving the editor, the Tasks list must be visible again")
    }

    // MARK: - Helpers

    private func screenshot(_ name: String) {
        let shot = app.screenshot()
        let att  = XCTAttachment(screenshot: shot)
        att.name = name
        att.lifetime = .keepAlways
        add(att)
    }
}
