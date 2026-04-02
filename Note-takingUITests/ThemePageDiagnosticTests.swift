import XCTest

// MARK: - ThemePageDiagnosticTests
// Single focused test suite for diagnosing the theme page crash.
// Every step is logged + screenshotted so we can pinpoint exactly which
// view/action triggers the EXC_BREAKPOINT in EnvironmentValues.subscript.getter.
//
// HOW TO READ THE OUTPUT:
//   • Look for the last 🎨 [THEME-DIAG] print in the app console before the crash.
//   • That tells you which view body was being evaluated when the crash happened.
//   • Match it against the crash frame "EnvironmentValues.subscript.getter".

final class ThemePageDiagnosticTests: XCTestCase {

    var app: XCUIApplication!

    // ─────────────────────────────────────────────
    // MARK: Setup / Teardown
    // ─────────────────────────────────────────────

    override func setUpWithError() throws {
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchArguments += ["UITESTING"]
        app.launch()

        log("App launched. State: \(app.state.rawValue)")
        XCTAssertEqual(app.state, .runningForeground, "App must be in foreground before tests start")
    }

    override func tearDownWithError() throws {
        log("Test ended — taking final screenshot")
        attach(screenshot: app.screenshot(), name: "Final State (pass or fail)")
    }

    // ─────────────────────────────────────────────
    // MARK: Test 1 — App survives launch
    // ─────────────────────────────────────────────

    func test_01_appLaunchesWithoutCrash() {
        log("=== TEST 1: App launch ===")
        XCTAssertEqual(app.state, .runningForeground, "App should still be running after launch")
        attach(screenshot: app.screenshot(), name: "1 — Launch")
        log("✅ App is alive after launch")
    }

    // ─────────────────────────────────────────────
    // MARK: Test 2 — Open settings menu
    // ─────────────────────────────────────────────

    func test_02_settingsMenuOpens() throws {
        log("=== TEST 2: Settings menu ===")

        let ellipsisButton = findEllipsisButton()
        log("Ellipsis button exists: \(ellipsisButton.exists), hittable: \(ellipsisButton.isHittable)")

        XCTAssertTrue(
            ellipsisButton.waitForExistence(timeout: 5),
            "❌ Ellipsis (···) settings button not found in the toolbar after 5 s"
        )

        attach(screenshot: app.screenshot(), name: "2a — Before tapping ellipsis")
        log("Tapping ellipsis button…")
        ellipsisButton.tap()

        attach(screenshot: app.screenshot(), name: "2b — After tapping ellipsis (menu should be open)")
        XCTAssertEqual(app.state, .runningForeground, "App crashed when opening settings menu")
        log("✅ Settings menu opened without crash")
    }

    // ─────────────────────────────────────────────
    // MARK: Test 3 — Tap Theme to open ThemeView
    // ─────────────────────────────────────────────

    func test_03_themeViewOpens() throws {
        log("=== TEST 3: Navigate to ThemeView ===")

        try navigateToThemeView()

        attach(screenshot: app.screenshot(), name: "3 — ThemeView open")
        XCTAssertEqual(app.state, .runningForeground, "❌ App CRASHED when opening ThemeView")

        let navTitle = app.navigationBars["Themes"]
        let themeViewVisible = navTitle.waitForExistence(timeout: 4)

        if themeViewVisible {
            log("✅ ThemeView is visible — 'Themes' nav bar found")
        } else {
            log("⚠️ 'Themes' nav bar not found — app may have crashed or navigation failed")
            attach(screenshot: app.screenshot(), name: "3 — FAILED to see Themes nav bar")
        }

        XCTAssertTrue(themeViewVisible, "ThemeView did not appear (no 'Themes' navigation title)")
    }

    // ─────────────────────────────────────────────
    // MARK: Test 4 — Tap first theme card → ThemeDetailView
    // ─────────────────────────────────────────────

    func test_04_themeDetailViewOpens() throws {
        log("=== TEST 4: Tap first theme card → ThemeDetailView ===")

        try navigateToThemeView()

        // Wait for at least one theme card to appear
        log("Waiting for theme cards to render…")
        let firstCard = app.buttons.firstMatch
        let cardAppeared = firstCard.waitForExistence(timeout: 5)

        attach(screenshot: app.screenshot(), name: "4a — ThemeView with cards")
        log("First tappable element exists: \(cardAppeared), label: '\(firstCard.label)'")

        guard cardAppeared else {
            XCTFail("❌ No theme cards found in ThemeView after 5 s")
            return
        }

        log("Tapping first theme card: '\(firstCard.label)'")
        attach(screenshot: app.screenshot(), name: "4b — About to tap card")
        firstCard.tap()

        log("Tapped card — checking if app survived…")
        // Give SwiftUI time to either show the detail view or crash
        let survived = app.wait(for: .runningForeground, timeout: 4)

        attach(screenshot: app.screenshot(), name: "4c — After tapping card (detail should open)")

        if !survived {
            log("❌ App CRASHED after tapping theme card — check console for last 🎨 [THEME-DIAG] print")
        } else {
            log("✅ App alive after tapping card")
        }

        XCTAssertTrue(survived, "❌ App crashed when navigating to ThemeDetailView — see console for [THEME-DIAG] logs")
    }

    // ─────────────────────────────────────────────
    // MARK: Test 5 — Tap every theme card in sequence
    // ─────────────────────────────────────────────

    func test_05_allThemeCardsOpenWithoutCrash() throws {
        log("=== TEST 5: Cycle through all theme cards ===")

        try navigateToThemeView()

        let allCards = app.buttons.allElementsBoundByIndex
        log("Total tappable buttons in ThemeView: \(allCards.count)")

        var crashedOnCard: String? = nil

        for (index, card) in allCards.enumerated() {
            guard card.exists, card.isHittable else {
                log("Card \(index) not hittable — skipping")
                continue
            }

            log("Tapping card \(index): '\(card.label)'")
            card.tap()

            let alive = app.wait(for: .runningForeground, timeout: 3)
            if !alive {
                crashedOnCard = "Card \(index): '\(card.label)'"
                log("❌ CRASH on \(crashedOnCard!)")
                attach(screenshot: app.screenshot(), name: "CRASH — card \(index)")
                break
            }

            attach(screenshot: app.screenshot(), name: "Card \(index) — '\(card.label)' opened OK")
            log("✅ Card \(index) OK — navigating back")

            // Navigate back to ThemeView for next card
            let backButton = app.navigationBars.buttons.firstMatch
            if backButton.exists {
                backButton.tap()
                _ = app.navigationBars["Themes"].waitForExistence(timeout: 2)
            }
        }

        if let crashed = crashedOnCard {
            XCTFail("App crashed on: \(crashed) — see [THEME-DIAG] logs in console for the last view evaluated")
        } else {
            log("✅ All theme cards opened without crash")
        }
    }

    // ─────────────────────────────────────────────
    // MARK: Helpers
    // ─────────────────────────────────────────────

    /// Tap the ellipsis menu → tap "Theme" → wait for ThemeView
    private func navigateToThemeView() throws {
        let ellipsis = findEllipsisButton()
        guard ellipsis.waitForExistence(timeout: 5) else {
            XCTFail("❌ Ellipsis button not found — is a TaskList visible on screen?")
            return
        }
        log("Tapping ellipsis to open menu…")
        ellipsis.tap()

        let themeMenuItem = app.buttons["Theme"]
        let menuAppeared = themeMenuItem.waitForExistence(timeout: 3)
        log("'Theme' menu item exists: \(menuAppeared)")

        guard menuAppeared else {
            attach(screenshot: app.screenshot(), name: "Menu did not show Theme item")
            XCTFail("❌ 'Theme' button not found in settings menu")
            return
        }

        log("Tapping 'Theme' menu item…")
        themeMenuItem.tap()

        _ = app.navigationBars["Themes"].waitForExistence(timeout: 4)
        log("Navigated — app state: \(app.state.rawValue)")
    }

    /// Finds the ellipsis (···) toolbar button regardless of exact position
    private func findEllipsisButton() -> XCUIElement {
        // Try by accessibility label first, then fall back to image search
        let byLabel = app.buttons["ellipsis"]
        if byLabel.exists { return byLabel }

        let byImage = app.buttons.matching(NSPredicate(format: "label CONTAINS '…' OR label CONTAINS 'more' OR label CONTAINS 'ellipsis'")).firstMatch
        if byImage.exists { return byImage }

        // Last resort: any button in a toolbar/nav area
        return app.toolbars.buttons.lastMatch ?? app.navigationBars.buttons.lastMatch ?? app.buttons["ellipsis"]
    }

    /// Prints with a consistent prefix so log lines are easy to grep
    private func log(_ message: String) {
        let timestamp = String(format: "%.3f", Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 10000))
        print("🧪 [THEME-TEST \(timestamp)] \(message)")
    }

    /// Attaches a screenshot to the test report with a given name
    private func attach(screenshot: XCUIScreenshot, name: String) {
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

// MARK: - XCUIElementQuery helper

private extension XCUIElementQuery {
    var lastMatch: XCUIElement? {
        let all = allElementsBoundByIndex
        return all.isEmpty ? nil : all[all.count - 1]
    }
}
