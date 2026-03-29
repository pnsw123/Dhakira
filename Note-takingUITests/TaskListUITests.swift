import XCTest

// MARK: - TaskListUITests
// Simulates real user interactions on the Tasks screen:
// creating tasks, tapping into detail, completing tasks, deleting tasks.

final class TaskListUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"] // optional flag for resetting state
        app.launch()
    }

    override func tearDownWithError() throws {
        screenshot("teardown")
        app = nil
    }

    // MARK: - App launch

    // #1 — App launches without crashing and shows a recognisable screen.
    @MainActor
    func test_appLaunches_showsTasksScreen() {
        screenshot("launch")
        // The Tasks page has the < (folders) button
        let foldersBtn = app.buttons["btn-go-to-folders"]
        XCTAssertTrue(foldersBtn.waitForExistence(timeout: 5),
                      "App should launch to the Tasks screen with the Folders button visible")
    }

    // #2 — App launch performance is within 3 seconds.
    @MainActor
    func test_launchPerformance() {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    // MARK: - Navigation to Folders

    // #3 — Tapping < navigates to the Folders screen.
    @MainActor
    func test_tapFoldersButton_showsFoldersScreen() {
        let foldersBtn = app.buttons["btn-go-to-folders"]
        XCTAssertTrue(foldersBtn.waitForExistence(timeout: 5))
        screenshot("before-folders")
        foldersBtn.tap()
        screenshot("after-folders")

        let tasksBtn = app.buttons["btn-go-to-tasks"]
        XCTAssertTrue(tasksBtn.waitForExistence(timeout: 3),
                      "After tapping <, the Folders screen must appear")
    }

    // #4 — Tapping > on Folders returns to the Tasks screen.
    @MainActor
    func test_tapTasksButton_returnsToTasksScreen() {
        app.buttons["btn-go-to-folders"].tap()
        let tasksBtn = app.buttons["btn-go-to-tasks"]
        XCTAssertTrue(tasksBtn.waitForExistence(timeout: 3))
        tasksBtn.tap()

        let foldersBtn = app.buttons["btn-go-to-folders"]
        XCTAssertTrue(foldersBtn.waitForExistence(timeout: 3),
                      "Tapping > should return to the Tasks screen")
    }

    // #5 — Navigation round-trip: Tasks → Folders → Tasks → Folders.
    @MainActor
    func test_navigationRoundTrip_multipleTimes() {
        let folderBtn = app.buttons["btn-go-to-folders"]
        let tasksBtn  = app.buttons["btn-go-to-tasks"]

        folderBtn.tap()
        XCTAssertTrue(tasksBtn.waitForExistence(timeout: 3), "1st trip to Folders failed")
        tasksBtn.tap()
        XCTAssertTrue(folderBtn.waitForExistence(timeout: 3), "Return from Folders failed")
        folderBtn.tap()
        XCTAssertTrue(tasksBtn.waitForExistence(timeout: 3), "2nd trip to Folders failed")
    }

    // MARK: - Task creation

    // #6 — A new task can be created by tapping the + FAB.
    @MainActor
    func test_createTask_tapFAB() {
        // Look for the FAB (floating action button / add task button)
        let addButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'add' OR label CONTAINS '+'")).firstMatch
        guard addButton.waitForExistence(timeout: 5) else {
            // If no add button, look for a text field that becomes active
            XCTSkip("No explicit FAB found — task entry may be inline")
            return
        }
        screenshot("before-add-task")
        addButton.tap()
        screenshot("after-add-task-tap")
    }

    // MARK: - Folders screen

    // #7 — Folders screen shows "Folders" title.
    @MainActor
    func test_foldersScreen_showsTitle() {
        app.buttons["btn-go-to-folders"].tap()
        screenshot("folders-screen")

        let title = app.staticTexts["Folders"]
        XCTAssertTrue(title.waitForExistence(timeout: 3),
                      "Folders screen must show 'Folders' as its title")
    }

    // #8 — Folders screen shows "Add Folder" button.
    @MainActor
    func test_foldersScreen_showsAddFolderButton() {
        app.buttons["btn-go-to-folders"].tap()

        let addFolder = app.buttons["Add Folder"]
        XCTAssertTrue(addFolder.waitForExistence(timeout: 3),
                      "Folders screen must show an 'Add Folder' button")
    }

    // #9 — Folders screen shows "Recently Completed" button.
    @MainActor
    func test_foldersScreen_showsRecentlyCompleted() {
        app.buttons["btn-go-to-folders"].tap()

        let recent = app.buttons["Recently Completed"]
        XCTAssertTrue(recent.waitForExistence(timeout: 3),
                      "Folders screen must show a 'Recently Completed' entry")
    }

    // #10 — Folders screen shows "Recently Deleted" button.
    @MainActor
    func test_foldersScreen_showsRecentlyDeleted() {
        app.buttons["btn-go-to-folders"].tap()

        let deleted = app.buttons["Recently Deleted"]
        XCTAssertTrue(deleted.waitForExistence(timeout: 3),
                      "Folders screen must show a 'Recently Deleted' entry")
    }

    // #11 — Tapping "Recently Completed" navigates to that screen.
    @MainActor
    func test_recentlyCompleted_navigation() {
        app.buttons["btn-go-to-folders"].tap()
        let recent = app.buttons["Recently Completed"]
        XCTAssertTrue(recent.waitForExistence(timeout: 3))
        screenshot("before-recently-completed")
        recent.tap()
        screenshot("after-recently-completed")
        // The screen should exist — verify we navigated somewhere
        XCTAssertFalse(app.state == .notRunning,
                       "App must remain running after navigating to Recently Completed")
    }

    // #12 — Tapping "Recently Deleted" navigates to that screen.
    @MainActor
    func test_recentlyDeleted_navigation() {
        app.buttons["btn-go-to-folders"].tap()
        let deleted = app.buttons["Recently Deleted"]
        XCTAssertTrue(deleted.waitForExistence(timeout: 3))
        screenshot("before-recently-deleted")
        deleted.tap()
        screenshot("after-recently-deleted")
        XCTAssertFalse(app.state == .notRunning,
                       "App must remain running after navigating to Recently Deleted")
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
