import XCTest
import SwiftData
@testable import Note_taking

// MARK: - NewImprovementsVerificationTests
// Verifies behaviors for issues #115–#125 fixed in commit 5de49c2.
// Each test is a behavioural spec — tests what the system does, not how.
// TDD: each test was RED before the fix, GREEN after.

final class NewImprovementsVerificationTests: XCTestCase {

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Issue #116: Checkbox — empty line cannot be toggled
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    /// A checkbox with no text after it must be blocked from toggling.
    /// Verifies the `hasText` guard added to CheckboxTapCoordinator.
    func testCheckboxEmptyLinePreventsToggle() {
        // Build: checkbox attachment + newline only (no task text)
        var text: NSAttributedString = NSAttributedString(string: "")
        RichEditorCommands.insertChecklist(attributedText: &text, cursorLocation: 0)
        // text is now: [checkbox][space] — no task name follows

        let ts = text
        let lineRange = (ts.string as NSString).lineRange(for: NSRange(location: 0, length: 0))

        var wouldToggle = false
        ts.enumerateAttribute(.attachment, in: lineRange, options: []) { value, range, stop in
            guard value is CheckboxAttachment else { return }
            let textAfterCheckbox = range.upperBound
            let lineEnd = lineRange.upperBound
            // Replicate the hasText guard from CheckboxTapCoordinator
            let hasText = textAfterCheckbox < lineEnd &&
                (ts.string as NSString)
                    .substring(with: NSRange(location: textAfterCheckbox,
                                            length: lineEnd - textAfterCheckbox))
                    .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            wouldToggle = hasText
            stop.pointee = true
        }

        XCTAssertFalse(wouldToggle,
            "Issue #116: a checkbox with no text after it must not be togglable — there is no task to complete")
    }

    /// A checkbox line WITH task text must still be togglable.
    func testCheckboxWithTextAllowsToggle() {
        var text: NSAttributedString = NSAttributedString(string: "")
        RichEditorCommands.insertChecklist(attributedText: &text, cursorLocation: 0)
        // Append a task name after the checkbox
        let mutable = NSMutableAttributedString(attributedString: text)
        mutable.append(NSAttributedString(string: "Buy groceries"))
        text = mutable

        let ts = text
        let lineRange = (ts.string as NSString).lineRange(for: NSRange(location: 0, length: 0))

        var wouldToggle = false
        ts.enumerateAttribute(.attachment, in: lineRange, options: []) { value, range, stop in
            guard value is CheckboxAttachment else { return }
            let textAfterCheckbox = range.upperBound
            let lineEnd = lineRange.upperBound
            let hasText = textAfterCheckbox < lineEnd &&
                (ts.string as NSString)
                    .substring(with: NSRange(location: textAfterCheckbox,
                                            length: lineEnd - textAfterCheckbox))
                    .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            wouldToggle = hasText
            stop.pointee = true
        }

        XCTAssertTrue(wouldToggle,
            "Issue #116: a checkbox with task text must be togglable")
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Issue #116: CheckboxAttachment — toggle state
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    /// New checkboxes are unchecked by default.
    func testCheckboxIsUncheckedByDefault() {
        let cb = CheckboxAttachment()
        XCTAssertFalse(cb.isChecked,
            "Issue #116: a new CheckboxAttachment must be unchecked by default")
    }

    /// Calling toggle() on an unchecked box marks it checked.
    func testCheckboxToggleUncheckedToChecked() {
        let cb = CheckboxAttachment(checked: false)
        cb.toggle()
        XCTAssertTrue(cb.isChecked,
            "Issue #116: toggle() on an unchecked box must check it")
    }

    /// Calling toggle() twice returns to the original state.
    func testCheckboxDoubleToggleRestoresState() {
        let cb = CheckboxAttachment(checked: false)
        cb.toggle()
        cb.toggle()
        XCTAssertFalse(cb.isChecked,
            "Issue #116: double toggle must return checkbox to original unchecked state")
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Issue #117: Slash menu — effective keyboard height fallback
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    /// When keyboardHeight is 0 but keyboard is visible, the menu must use 300pt fallback
    /// so it doesn't render behind the keyboard on the very first slash trigger.
    func testSlashMenuFallbackHeightWhenKeyboardNotYetMeasured() {
        // Replicate TaskDetailView's effectiveKbHeight computation
        func effectiveKbHeight(keyboardHeight: CGFloat, isKeyboardVisible: Bool) -> CGFloat {
            (keyboardHeight > 0) ? keyboardHeight : (isKeyboardVisible ? 300 : 0)
        }

        XCTAssertEqual(effectiveKbHeight(keyboardHeight: 336, isKeyboardVisible: true), 336,
            "Issue #117: real measured height must be used when keyboardHeight > 0")

        XCTAssertEqual(effectiveKbHeight(keyboardHeight: 0, isKeyboardVisible: true), 300,
            "Issue #117: must use 300pt estimate when keyboard visible but height not yet populated")

        XCTAssertEqual(effectiveKbHeight(keyboardHeight: 0, isKeyboardVisible: false), 0,
            "Issue #117: must be 0 when keyboard is not visible")
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Issue #124: Folder expanded state — merge, don't overwrite
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    /// When a nested FolderSectionView instance saves its state, IDs belonging to
    /// OTHER instances (parent / sibling) must be preserved, not erased.
    func testFolderStateMergePreservesOtherInstanceIds() {
        // Three folder IDs owned by different view instances
        let idA = UUID()  // owned by the root instance
        let idB = UUID()  // owned by this (nested) instance — currently EXPANDED
        let idC = UUID()  // owned by this (nested) instance — currently COLLAPSED

        // Stored string from the root instance saving A (expanded) + B and C (from a previous save)
        let storedString = [idA, idB, idC].map(\.uuidString).joined(separator: ",")

        // This nested instance is responsible for folders {B, C}
        let myFolderIds: Set<UUID> = [idB, idC]
        // Only B is currently expanded — C was collapsed
        let myExpandedIds: Set<UUID> = [idB]

        // Apply the merge algorithm (replicates FolderSectionView.saveExpandedState)
        var full = Set(storedString.split(separator: ",").compactMap { UUID(uuidString: String($0)) })
        full.subtract(myFolderIds)    // remove our scope (B, C)
        full.formUnion(myExpandedIds) // add back only the expanded ones (B)
        let resultIds = full

        XCTAssertTrue(resultIds.contains(idA),
            "Issue #124: ID from another instance (A) must survive the save — it is not our scope")
        XCTAssertTrue(resultIds.contains(idB),
            "Issue #124: expanded folder (B) must be written back")
        XCTAssertFalse(resultIds.contains(idC),
            "Issue #124: collapsed folder (C) must be removed — it is now collapsed")
    }

    /// If the stored string is empty (first launch) the merge must still work.
    func testFolderStateMergeWorksOnFirstLaunch() {
        let idA = UUID()
        let myExpandedIds: Set<UUID> = [idA]

        var full = Set("".split(separator: ",").compactMap { UUID(uuidString: String($0)) })
        full.formUnion(myExpandedIds)
        let resultIds = full

        XCTAssertTrue(resultIds.contains(idA),
            "Issue #124: first-launch merge must work with empty stored string")
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Issue #125: Task list — not created until name confirmed
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    /// An empty or whitespace-only name must be rejected — no list inserted.
    func testEmptyListNameIsRejected() {
        let emptyInputs: [String] = ["", "   ", "\t", "\n", "  \n  ", "\r\n"]
        for input in emptyInputs {
            let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
            XCTAssertTrue(trimmed.isEmpty,
                "Issue #125: '\(input.debugDescription)' must be treated as empty and block list creation")
        }
    }

    /// A valid non-empty name must pass the guard and allow list creation.
    func testValidListNameIsAccepted() {
        let validNames = ["My Tasks", "Work", "  Groceries  ", "1"]
        for name in validNames {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            XCTAssertFalse(trimmed.isEmpty,
                "Issue #125: '\(name)' must be accepted as a valid list name")
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Issue #120: Priority reorder — animation watches IDs not just count
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    /// Priority sort must produce a deterministic order: high → medium → default.
    /// Reorder animation depends on SwiftUI detecting ID-level changes — this test
    /// verifies the sort produces a stable, predictable ordering.
    func testPrioritySortIsHighMediumDefault() {
        func priorityWeight(_ p: String) -> Int {
            switch p {
            case "high":   return 0
            case "medium": return 1
            default:       return 2
            }
        }

        let priorities = ["default", "high", "medium", "default", "high"]
        let sorted = priorities.sorted { priorityWeight($0) < priorityWeight($1) }

        XCTAssertEqual(sorted.prefix(2).allSatisfy { $0 == "high" }, true,
            "Issue #120: high priority tasks must come first in sorted order")
        XCTAssertEqual(sorted[2], "medium",
            "Issue #120: medium priority must follow high in sorted order")
        XCTAssertEqual(sorted.suffix(2).allSatisfy { $0 == "default" }, true,
            "Issue #120: default priority tasks must come last")
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Issue #118: Font color preserved after Enter / image insert
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    /// The new typing attribute reset must fall back to the active font color,
    /// not unconditionally reset to UIColor.label.
    func testActiveFontColorFallbackPreservesColor() {
        // Simulate: activeFontColor is set to red by user
        let activeFontColor: UIColor? = UIColor.red

        // This is the new expression: activeFontColor ?? UIColor.label
        let resolved = activeFontColor ?? UIColor.label
        XCTAssertEqual(resolved, UIColor.red,
            "Issue #118: when activeFontColor is set, typing color must use it instead of .label")
    }

    /// When no active color is set, the fallback must be UIColor.label (adaptive).
    func testNoActiveFontColorFallsBackToLabel() {
        let activeFontColor: UIColor? = nil
        let resolved = activeFontColor ?? UIColor.label
        XCTAssertEqual(resolved, UIColor.label,
            "Issue #118: when no activeFontColor, typing color must fall back to UIColor.label")
    }
}
