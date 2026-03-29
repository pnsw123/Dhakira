import XCTest
import SwiftData
@testable import Note_taking

// MARK: - NoteBodyBindingTests
// Tests NoteBodyBinding.load and NoteBodyBinding.save — the glue layer between
// the editor and SwiftData storage.

@MainActor
final class NoteBodyBindingTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        container = try AppSchemaBuilder.makeInMemoryContainer()
        context   = container.mainContext
    }

    override func tearDownWithError() throws {
        container = nil
        context   = nil
    }

    // MARK: - load

    // #1 — load with nil body leaves attributedText unchanged.
    func test_load_nilBody_leavesTextUnchanged() {
        let task = TaskItem(title: "Empty body task")
        context.insert(task)

        var text = NSAttributedString(string: "original")
        NoteBodyBinding.load(from: task, into: &text)

        XCTAssertEqual(text.string, "original",
                       "load() must not change attributedText when task.body is nil")
    }

    // #2 — load with valid RTF body populates attributedText.
    func test_load_validBody_populatesText() {
        let task = TaskItem(title: "Loaded task")
        context.insert(task)

        // Encode some text first, then store it in the task
        let original = NSAttributedString(string: "Hello from body")
        if case .success(let data) = NoteBodyCodec.encode(original) {
            task.body = data
        } else {
            XCTFail("Could not encode test body")
            return
        }

        var text = NSAttributedString()
        NoteBodyBinding.load(from: task, into: &text)

        XCTAssertEqual(text.string, "Hello from body",
                       "load() must populate attributedText with the stored body content")
    }

    // #3 — load does NOT call onLoadError for a valid body.
    func test_load_validBody_doesNotCallErrorCallback() {
        let task = TaskItem(title: "Valid body task")
        context.insert(task)

        let original = NSAttributedString(string: "Good data")
        if case .success(let data) = NoteBodyCodec.encode(original) {
            task.body = data
        } else {
            XCTFail("Encode failed")
            return
        }

        var text = NSAttributedString()
        var errorCalled = false
        NoteBodyBinding.load(from: task, into: &text, onLoadError: { _ in errorCalled = true })

        XCTAssertFalse(errorCalled, "onLoadError must NOT fire for a valid body")
    }

    // #4 — load with corrupt data calls onLoadError and does NOT clear attributedText.
    func test_load_corruptBody_callsErrorCallback_andPreservesText() {
        let task = TaskItem(title: "Corrupt body task")
        context.insert(task)
        task.body = Data([0xDE, 0xAD, 0xBE, 0xEF]) // garbage bytes

        var text = NSAttributedString(string: "preserved content")
        var errorFired = false
        NoteBodyBinding.load(from: task, into: &text, onLoadError: { _ in errorFired = true })

        XCTAssertTrue(errorFired, "onLoadError must fire for a corrupt body")
        XCTAssertEqual(text.string, "preserved content",
                       "load() must NOT overwrite attributedText on decode failure")
    }

    // #5 — load strips near-black RTF default color (dark-mode fix).
    func test_load_stripsNearBlackDefaultColor() {
        let task = TaskItem(title: "Dark mode task")
        context.insert(task)

        // Create RTF with explicit near-black color — simulating RTF default
        let nearBlack = UIColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 1.0)
        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: nearBlack,
            .font: UIFont.systemFont(ofSize: 16)
        ]
        let colored = NSAttributedString(string: "Dark text", attributes: attrs)
        if case .success(let data) = NoteBodyCodec.encode(colored) {
            task.body = data
        } else {
            XCTFail("Encode failed")
            return
        }

        var text = NSAttributedString()
        NoteBodyBinding.load(from: task, into: &text)

        let color = text.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        XCTAssertNil(color,
                     "Near-black foreground from RTF default must be stripped so .label color shows through")
    }

    // MARK: - save

    // #6 — save stores data in task.body.
    func test_save_populatesTaskBody() {
        let task = TaskItem(title: "Save test task")
        context.insert(task)

        let text = NSAttributedString(string: "Stored content")
        NoteBodyBinding.save(text, into: task)

        XCTAssertNotNil(task.body, "save() must populate task.body with encoded data")
    }

    // #7 — save with whitespace-only text clears task.body.
    func test_save_whitespaceOnly_clearsBody() {
        let task = TaskItem(title: "Whitespace task")
        context.insert(task)
        task.body = Data([0x01, 0x02]) // simulate existing data

        let whitespace = NSAttributedString(string: "   \n  ")
        NoteBodyBinding.save(whitespace, into: task)

        XCTAssertNil(task.body,
                     "Whitespace-only text must clear task.body (no orphan data)")
    }

    // #8 — save round-trip: what we save can be loaded back.
    func test_save_then_load_roundTrip() {
        let task = TaskItem(title: "Round trip task")
        context.insert(task)

        let original = NSAttributedString(string: "Round-trip content")
        NoteBodyBinding.save(original, into: task)

        var loaded = NSAttributedString()
        NoteBodyBinding.load(from: task, into: &loaded)

        XCTAssertEqual(loaded.string, original.string,
                       "save() → load() round-trip must preserve the string content")
    }

    // #9 — save does NOT call onSaveError for valid text.
    func test_save_validText_doesNotCallErrorCallback() {
        let task = TaskItem(title: "Valid save task")
        context.insert(task)

        var errorFired = false
        NoteBodyBinding.save(NSAttributedString(string: "Valid"), into: task,
                             onSaveError: { _ in errorFired = true })

        XCTAssertFalse(errorFired, "onSaveError must NOT fire for valid text")
    }

    // #10 — save with empty string also clears body (empty == whitespace only).
    func test_save_emptyString_clearsBody() {
        let task = TaskItem(title: "Empty save task")
        context.insert(task)
        task.body = Data([0xFF])

        NoteBodyBinding.save(NSAttributedString(string: ""), into: task)

        XCTAssertNil(task.body, "Empty string must clear task.body just like whitespace-only text")
    }
}
