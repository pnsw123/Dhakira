import XCTest
@testable import Note_taking

// MARK: - RichEditorCommandsTests
// Verifies the public static methods on RichEditorCommands that back every
// slash command and toolbar action in the editor.

@MainActor
final class RichEditorCommandsTests: XCTestCase {

    // MARK: - applyBlockquote

    // #1 — Tracer bullet: quote inserts "│ " prefix (the visible left bar).
    func test_applyBlockquote_insertsBarPrefix() {
        var text = NSAttributedString(string: "Some quoted text")

        RichEditorCommands.applyBlockquote(attributedText: &text,
                                           selectedRange: NSRange(location: 0, length: text.length))

        XCTAssertTrue(text.string.hasPrefix("│ "),
                      "Quote should start with the '│ ' left-bar prefix")
    }

    // #2 — The "│" character is styled .clear (the visual bar comes from a UIView overlay,
    //       not the glyph color, so the character itself is intentionally invisible).
    func test_applyBlockquote_barCharHasAccentColor() {
        var text = NSAttributedString(string: "Quoted")

        RichEditorCommands.applyBlockquote(attributedText: &text,
                                           selectedRange: NSRange(location: 0, length: text.length))

        let barColor = text.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        XCTAssertEqual(barColor, UIColor.clear,
                       "The '│' bar character must be .clear — the visual bar is a UIView overlay")
    }

    // #3 — Quote paragraph has hanging indent so wrapped lines align under quoted text.
    func test_applyBlockquote_hasHangingIndent() {
        var text = NSAttributedString(string: "A longer quote that would wrap")

        RichEditorCommands.applyBlockquote(attributedText: &text,
                                           selectedRange: NSRange(location: 0, length: text.length))

        let style = text.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        XCTAssertEqual(style?.headIndent, 16,
                       "Quote headIndent should be 16pt so wrapped lines align under the text")
    }

    // #4 — Calling applyBlockquote a second time removes the "│ " prefix (toggle off).
    func test_applyBlockquote_secondCall_removesBarPrefix() {
        var text = NSAttributedString(string: "Quoted")
        let r = NSRange(location: 0, length: text.length)

        RichEditorCommands.applyBlockquote(attributedText: &text, selectedRange: r)
        // Range shifts by +2 after "│ " insertion.
        let r2 = NSRange(location: 0, length: text.length)
        RichEditorCommands.applyBlockquote(attributedText: &text, selectedRange: r2)

        XCTAssertFalse(text.string.hasPrefix("│ "),
                       "Second applyBlockquote should remove the bar prefix (toggle off)")
        XCTAssertEqual(text.string, "Quoted",
                       "Original text should be fully restored after toggle off")
    }

    // #5 — Empty string does NOT crash.
    func test_applyBlockquote_emptyString_doesNotCrash() {
        var empty = NSAttributedString()
        XCTAssertNoThrow(
            RichEditorCommands.applyBlockquote(attributedText: &empty,
                                               selectedRange: NSRange(location: 0, length: 0)),
            "applyBlockquote must not crash on an empty NSAttributedString"
        )
    }

    // MARK: - toggleBulletList

    // #6 — Applying a bullet list prepends "• " to the paragraph.
    func test_toggleBulletList_insertsBulletPrefix() {
        var text = NSAttributedString(string: "Buy milk")

        RichEditorCommands.toggleBulletList(attributedText: &text,
                                            selectedRange: NSRange(location: 0, length: text.length))

        XCTAssertTrue(text.string.hasPrefix("• "),
                      "toggleBulletList should prepend '• ' to the paragraph")
    }

    // #7 — Bullet character is adaptive (.label color), never hardcoded black.
    func test_toggleBulletList_bulletCharHasLabelColor() {
        var text = NSAttributedString(string: "Item")

        RichEditorCommands.toggleBulletList(attributedText: &text,
                                            selectedRange: NSRange(location: 0, length: text.length))

        let color = text.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        XCTAssertEqual(color, UIColor.label,
                       "Bullet '•' must use .label so it is visible in dark mode")
    }

    // #8 — Toggling again removes the "• " prefix (toggle off).
    func test_toggleBulletList_secondToggle_removesBulletPrefix() {
        var text = NSAttributedString(string: "Buy milk")
        let r = NSRange(location: 0, length: text.length)

        RichEditorCommands.toggleBulletList(attributedText: &text, selectedRange: r)
        let r2 = NSRange(location: 0, length: text.length)
        RichEditorCommands.toggleBulletList(attributedText: &text, selectedRange: r2)

        XCTAssertFalse(text.string.hasPrefix("• "),
                       "Second toggle should remove the bullet prefix")
        XCTAssertEqual(text.string, "Buy milk",
                       "Original text should be fully restored after toggle off")
    }

    // #9 — Empty string does NOT crash (guard mutable.length > 0).
    func test_toggleBulletList_emptyString_doesNotCrash() {
        var empty = NSAttributedString()
        XCTAssertNoThrow(
            RichEditorCommands.toggleBulletList(
                attributedText: &empty,
                selectedRange: NSRange(location: 0, length: 0)
            ),
            "toggleBulletList must not crash on an empty NSAttributedString"
        )
    }

    // MARK: - insertChecklist

    // #10 — insertChecklist places a CheckboxAttachment at the cursor position.
    func test_insertChecklist_insertsCheckboxAttachment() {
        var text = NSAttributedString(string: "Hello")

        RichEditorCommands.insertChecklist(attributedText: &text, cursorLocation: 5)

        // The character at position 5 should carry a CheckboxAttachment.
        let attachment = text.attribute(.attachment, at: 5, effectiveRange: nil)
        XCTAssertNotNil(attachment as? CheckboxAttachment,
                        "insertChecklist must place a CheckboxAttachment at the cursor position")
    }

    // #11 — The checkbox starts unchecked.
    func test_insertChecklist_checkboxStartsUnchecked() {
        var text = NSAttributedString(string: "")

        RichEditorCommands.insertChecklist(attributedText: &text, cursorLocation: 0)

        let cb = text.attribute(.attachment, at: 0, effectiveRange: nil) as? CheckboxAttachment
        XCTAssertEqual(cb?.isChecked, false,
                       "Newly inserted checkbox must start unchecked")
    }

    // #12 — Returns cursorLocation + 2 (attachment char + space).
    func test_insertChecklist_returnsUpdatedCursorLocation() {
        var text = NSAttributedString(string: "Hello")

        let newCursor = RichEditorCommands.insertChecklist(attributedText: &text, cursorLocation: 5)

        XCTAssertEqual(newCursor, 7,
                       "Returned cursor should be original location + 2 (attachment + space)")
    }

    // #13 — Attachment character has .label foreground so template rendering adapts to dark mode.
    func test_insertChecklist_attachmentCharHasLabelColor() {
        var text = NSAttributedString(string: "")

        RichEditorCommands.insertChecklist(attributedText: &text, cursorLocation: 0)

        let color = text.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        XCTAssertEqual(color, UIColor.label,
                       "Attachment char must have .label foreground for adaptive dark-mode tinting")
    }

    // #14 — Empty string does NOT crash; clamping protects the insert.
    func test_insertChecklist_emptyString_doesNotCrash() {
        var empty = NSAttributedString()
        XCTAssertNoThrow(
            RichEditorCommands.insertChecklist(attributedText: &empty, cursorLocation: 0),
            "insertChecklist must not crash on empty string with cursorLocation 0"
        )
    }

    // #15 — Out-of-bounds cursor is clamped, not crashed.
    func test_insertChecklist_outOfBoundsCursor_isClamped() {
        var text = NSAttributedString(string: "Hi")
        XCTAssertNoThrow(
            RichEditorCommands.insertChecklist(attributedText: &text, cursorLocation: 999),
            "Out-of-bounds cursorLocation must be clamped silently"
        )
        // Attachment should still appear (clamped to end of string).
        let attachment = text.attribute(.attachment, at: text.length - 2, effectiveRange: nil)
        XCTAssertNotNil(attachment as? CheckboxAttachment,
                        "Checkbox attachment should be inserted after cursor clamping")
    }

    // MARK: - toggleCheckbox

    // #16 — toggleCheckbox flips an unchecked box to checked.
    func test_toggleCheckbox_uncheckedBecomesChecked() {
        var text = NSAttributedString(string: "")
        RichEditorCommands.insertChecklist(attributedText: &text, cursorLocation: 0)

        RichEditorCommands.toggleCheckbox(at: 0, attributedText: &text)

        let cb = text.attribute(.attachment, at: 0, effectiveRange: nil) as? CheckboxAttachment
        XCTAssertEqual(cb?.isChecked, true,
                       "toggleCheckbox must flip an unchecked attachment to checked")
    }

    // #17 — toggleCheckbox flips a checked box back to unchecked.
    func test_toggleCheckbox_checkedBecomesUnchecked() {
        var text = NSAttributedString(string: "")
        RichEditorCommands.insertChecklist(attributedText: &text, cursorLocation: 0)
        RichEditorCommands.toggleCheckbox(at: 0, attributedText: &text)   // → checked

        RichEditorCommands.toggleCheckbox(at: 0, attributedText: &text)   // → unchecked

        let cb = text.attribute(.attachment, at: 0, effectiveRange: nil) as? CheckboxAttachment
        XCTAssertEqual(cb?.isChecked, false,
                       "Double-toggleCheckbox should return the checkbox to unchecked")
    }

    // MARK: - applyHeading

    // #18 — applyHeading(.h1) on empty string does NOT crash.
    func test_applyHeading_emptyString_doesNotCrash() {
        var empty = NSAttributedString()
        XCTAssertNoThrow(
            RichEditorCommands.applyHeading(
                .h1, attributedText: &empty,
                selectedRange: NSRange(location: 0, length: 0)
            ),
            "applyHeading must not crash on empty NSAttributedString"
        )
    }

    // #19 — applyHeading(.h1) sets 22pt bold font.
    func test_applyHeading_h1_appliesCorrectFont() {
        var text = NSAttributedString(string: "Title")

        RichEditorCommands.applyHeading(.h1, attributedText: &text,
                                        selectedRange: NSRange(location: 0, length: text.length))

        let font = text.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertEqual(font?.pointSize, 22, "H1 should be 22pt")
        XCTAssertTrue(font?.fontDescriptor.symbolicTraits.contains(.traitBold) ?? false,
                      "H1 should be bold")
    }

    // #20 — Applying the same heading level twice reverts to body text.
    func test_applyHeading_sameLevel_twice_revertsToBody() {
        var text = NSAttributedString(string: "Title")
        let range    = NSRange(location: 0, length: text.length)
        let bodySize = UIFont.preferredFont(forTextStyle: .body).pointSize

        RichEditorCommands.applyHeading(.h1, attributedText: &text, selectedRange: range)
        RichEditorCommands.applyHeading(.h1, attributedText: &text,
                                        selectedRange: NSRange(location: 0, length: text.length))

        let font = text.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertEqual(font?.pointSize, bodySize,
                       "Applying the same heading twice should revert to body text size")
    }
}
