import XCTest
@testable import Note_taking

@MainActor
final class SlashCommandCoordinatorTests: XCTestCase {

    private var coordinator: SlashCommandCoordinator!

    override func setUp() {
        super.setUp()
        coordinator = SlashCommandCoordinator()
    }

    // MARK: - #1 Typing "/" makes the menu visible

    func test_typingSlash_showsMenu() {
        let text = NSAttributedString(string: "Hello /")

        coordinator.textDidChange(text: text, cursorLocation: 7)

        XCTAssertTrue(coordinator.isMenuVisible, "Menu should be visible after typing '/'")
        XCTAssertFalse(coordinator.filteredCommands.isEmpty,
                       "filteredCommands should be non-empty when menu is active")
    }

    // MARK: - #2 Typing "/bul" filters to bullet-related commands

    func test_filterText_narrowsCommands() {
        let text = NSAttributedString(string: "/bul")
        coordinator.textDidChange(text: text, cursorLocation: 4)

        XCTAssertTrue(coordinator.isMenuVisible)
        // All returned commands should match "bul" in their label or id
        let allMatch = coordinator.filteredCommands.allSatisfy {
            $0.label.lowercased().contains("bul") || $0.id.lowercased().contains("bul")
        }
        XCTAssertTrue(allMatch, "Filtered commands should all match the filter text 'bul'")
    }

    // MARK: - #3 Dismiss clears menu state

    func test_dismiss_hidesMenuAndClearsCommands() {
        coordinator.textDidChange(text: NSAttributedString(string: "/"), cursorLocation: 1)
        XCTAssertTrue(coordinator.isMenuVisible)

        coordinator.dismiss()

        XCTAssertFalse(coordinator.isMenuVisible, "Menu should be hidden after dismiss()")
        XCTAssertTrue(coordinator.filteredCommands.isEmpty,
                      "filteredCommands should be cleared after dismiss()")
    }

    // MARK: - #4 commandSelected deletes the slash trigger text (frozen-state fix)

    func test_commandSelected_deletesSlashTriggerText() {
        // Simulate: user typed "Hello /bul", cursor at position 10
        // "/bul" matches "Bulleted List" so filteredCommands will be non-empty.
        var text = NSAttributedString(string: "Hello /bul")
        coordinator.textDidChange(text: text, cursorLocation: 10)

        guard let cmd = coordinator.filteredCommands.first else {
            XCTFail("Expected at least one command to be available for filter 'bul'")
            return
        }

        // Apply the command — should delete "/bul" (positions 6-10)
        coordinator.commandSelected(cmd, applyTo: &text, cursorLocation: 10)

        // The attributed string should now be "Hello " (slash + filter removed)
        XCTAssertEqual(text.string, "Hello ",
                       "commandSelected should delete the slash trigger text from the document")
    }

    // MARK: - #5 Suppression: text change immediately after commandSelected is ignored

    func test_commandSelected_suppressesNextEvaluation() {
        var text = NSAttributedString(string: "/")
        coordinator.textDidChange(text: text, cursorLocation: 1)

        guard let cmd = coordinator.filteredCommands.first else {
            XCTFail("Need at least one command")
            return
        }

        coordinator.commandSelected(cmd, applyTo: &text, cursorLocation: 1)

        // Simulate the attributedText mutation firing onChange immediately
        // The coordinator should suppress this evaluation
        coordinator.textDidChange(text: text, cursorLocation: 0)

        XCTAssertFalse(coordinator.isMenuVisible,
                       "Menu should stay hidden — suppression must block the post-apply evaluation")
    }

    // MARK: - #6 Non-slash text does not show menu

    func test_normalText_doesNotShowMenu() {
        coordinator.textDidChange(text: NSAttributedString(string: "Hello world"), cursorLocation: 11)

        XCTAssertFalse(coordinator.isMenuVisible, "Menu should not appear for regular text")
        XCTAssertTrue(coordinator.filteredCommands.isEmpty)
    }
}
