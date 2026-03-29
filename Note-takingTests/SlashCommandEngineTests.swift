import XCTest
@testable import Note_taking

// MARK: - SlashCommandEngineTests
// Tests the stateless parser that decides: is a slash command active?
// What filter text does the user want? Which commands match?

final class SlashCommandEngineTests: XCTestCase {

    // MARK: - Basic activation

    // #1 — Typing "/" with cursor right after it activates the engine.
    func test_singleSlash_isActive() {
        let state = SlashCommandEngine.evaluate(text: "/", cursorLocation: 1)
        XCTAssertTrue(state.isActive, "A bare '/' should activate the slash menu")
        XCTAssertEqual(state.filterText, "")
    }

    // #2 — "/" at start of line with no filter returns ALL commands.
    func test_singleSlash_returnsAllCommands() {
        let state = SlashCommandEngine.evaluate(text: "/", cursorLocation: 1)
        XCTAssertEqual(state.filteredCommands.count, SlashCommand.all.count,
                       "No filter text should return every registered command")
    }

    // #3 — Empty text at cursor 0 is inactive.
    func test_emptyText_cursorZero_isInactive() {
        let state = SlashCommandEngine.evaluate(text: "", cursorLocation: 0)
        XCTAssertFalse(state.isActive)
        XCTAssertTrue(state.filteredCommands.isEmpty)
    }

    // #4 — Normal text with no slash is inactive.
    func test_normalText_noSlash_isInactive() {
        let state = SlashCommandEngine.evaluate(text: "Hello world", cursorLocation: 11)
        XCTAssertFalse(state.isActive)
    }

    // MARK: - Filter text

    // #5 — "/bul" produces filterText "bul".
    func test_filterText_extractedCorrectly() {
        let state = SlashCommandEngine.evaluate(text: "/bul", cursorLocation: 4)
        XCTAssertEqual(state.filterText, "bul")
    }

    // #6 — "/bul" filters to bullet-only commands (all returned contain "bul").
    func test_filterBul_returnsBulletCommand() {
        let state = SlashCommandEngine.evaluate(text: "/bul", cursorLocation: 4)
        XCTAssertTrue(state.isActive)
        XCTAssertFalse(state.filteredCommands.isEmpty)
        let allMatchBul = state.filteredCommands.allSatisfy {
            $0.label.lowercased().contains("bul") || $0.section.lowercased().contains("bul")
        }
        XCTAssertTrue(allMatchBul, "All returned commands should match the filter 'bul'")
    }

    // #7 — "/heading" narrows to heading commands only.
    func test_filterHeading_returnsHeadingCommands() {
        let state = SlashCommandEngine.evaluate(text: "/heading", cursorLocation: 8)
        XCTAssertTrue(state.isActive)
        let allHeadings = state.filteredCommands.allSatisfy {
            $0.label.lowercased().contains("heading") || $0.id.hasPrefix("heading")
        }
        XCTAssertTrue(allHeadings, "Filtering '/heading' should only return heading commands")
    }

    // #8 — "/QUOTE" is case-insensitive (returns Quote command).
    func test_filterIsCaseInsensitive() {
        let state = SlashCommandEngine.evaluate(text: "/QUOTE", cursorLocation: 6)
        XCTAssertTrue(state.isActive)
        let hasQuote = state.filteredCommands.contains { $0.id == "quote" }
        XCTAssertTrue(hasQuote, "Filter should be case-insensitive — 'QUOTE' should match 'quote'")
    }

    // #9 — Filter that matches nothing → isActive = false.
    func test_filterWithNoMatch_isInactive() {
        let state = SlashCommandEngine.evaluate(text: "/xyzzy", cursorLocation: 6)
        XCTAssertFalse(state.isActive,
                       "A filter matching zero commands should set isActive = false")
        XCTAssertTrue(state.filteredCommands.isEmpty)
    }

    // MARK: - slashLocation

    // #10 — slashLocation is correct for mid-line slash.
    func test_slashLocation_midLine() {
        let state = SlashCommandEngine.evaluate(text: "Hello /b", cursorLocation: 8)
        XCTAssertEqual(state.slashLocation, 6,
                       "slashLocation should point to the '/' character at index 6")
    }

    // #11 — slashLocation is -1 when not active.
    func test_slashLocation_inactive_isMinusOne() {
        let state = SlashCommandEngine.evaluate(text: "No slash here", cursorLocation: 13)
        XCTAssertEqual(state.slashLocation, -1)
    }

    // MARK: - Newline boundary

    // #12 — Slash on a previous line does NOT activate the menu for a cursor on a new line.
    func test_newlineBoundary_slashOnPreviousLine_doesNotActivate() {
        // "/" on line 1, cursor on line 2 — engine must not cross the newline
        let state = SlashCommandEngine.evaluate(text: "/heading\nnew line", cursorLocation: 17)
        XCTAssertFalse(state.isActive,
                       "Slash on a previous line must NOT activate the menu for a cursor on the next line")
    }

    // #13 — Slash immediately before a newline is valid on its own line.
    func test_slashBeforeNewline_isActive() {
        // Text: "First\n/" — cursor at position 7 (right after '/')
        let state = SlashCommandEngine.evaluate(text: "First\n/", cursorLocation: 7)
        XCTAssertTrue(state.isActive, "Slash at start of second line should activate the menu")
        XCTAssertEqual(state.slashLocation, 6)
    }

    // MARK: - SlashCommand.all catalogue

    // #14 — The global command list includes the 6 built-in block/heading commands.
    func test_allCommands_containsBuiltIns() {
        let ids = SlashCommand.all.map { $0.id }
        let builtIns = ["bulletList", "todoList", "quote", "heading1", "heading2", "heading3"]
        for expected in builtIns {
            XCTAssertTrue(ids.contains(expected), "SlashCommand.all must include '\(expected)'")
        }
    }

    // #15 — Every command has a non-empty id, label, and section.
    func test_allCommands_haveNonEmptyFields() {
        for cmd in SlashCommand.all {
            XCTAssertFalse(cmd.id.isEmpty,      "Command id must not be empty")
            XCTAssertFalse(cmd.label.isEmpty,   "Command label must not be empty")
            XCTAssertFalse(cmd.section.isEmpty, "Command section must not be empty")
        }
    }

    // #16 — Command ids are unique (no duplicates in the catalog).
    func test_allCommands_idsAreUnique() {
        let ids = SlashCommand.all.map { $0.id }
        let unique = Set(ids)
        XCTAssertEqual(ids.count, unique.count, "SlashCommand ids must all be unique")
    }
}
