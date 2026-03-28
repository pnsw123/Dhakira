import XCTest

final class NavigationUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        takeScreenshot("test-ended")
        app = nil
    }

    @MainActor
    func testTasksToFoldersNavigation() throws {
        let goToFoldersBtn = app.buttons["btn-go-to-folders"]
        XCTAssertTrue(goToFoldersBtn.waitForExistence(timeout: 3),
                      "❌ < button not found on Tasks page")
        takeScreenshot("before-tap")
        goToFoldersBtn.tap()
        takeScreenshot("after-tap")
        let goToTasksBtn = app.buttons["btn-go-to-tasks"]
        XCTAssertTrue(goToTasksBtn.waitForExistence(timeout: 3),
                      "❌ Folders page never appeared after tapping <")
    }

    @MainActor
    func testFoldersToTasksNavigation() throws {
        let goToFoldersBtn = app.buttons["btn-go-to-folders"]
        XCTAssertTrue(goToFoldersBtn.waitForExistence(timeout: 3))
        goToFoldersBtn.tap()

        let goToTasksBtn = app.buttons["btn-go-to-tasks"]
        XCTAssertTrue(goToTasksBtn.waitForExistence(timeout: 3),
                      "❌ Folders page never appeared")
        takeScreenshot("on-folders-page")
        goToTasksBtn.tap()
        takeScreenshot("after-tapping-back")

        XCTAssertTrue(goToFoldersBtn.waitForExistence(timeout: 3),
                      "❌ Tasks page never came back after tapping >")
    }

    @MainActor
    func testRoundTrip() throws {
        let goToFolders = app.buttons["btn-go-to-folders"]
        let goToTasks   = app.buttons["btn-go-to-tasks"]

        goToFolders.tap()
        XCTAssertTrue(goToTasks.waitForExistence(timeout: 3),   "❌ Tasks → Folders failed")
        goToTasks.tap()
        XCTAssertTrue(goToFolders.waitForExistence(timeout: 3), "❌ Folders → Tasks failed")
        goToFolders.tap()
        XCTAssertTrue(goToTasks.waitForExistence(timeout: 3),   "❌ Second visit to Folders failed")
    }

    private func takeScreenshot(_ name: String) {
        let shot = app.screenshot()
        let att  = XCTAttachment(screenshot: shot)
        att.name = name
        att.lifetime = .keepAlways
        add(att)
    }
}
