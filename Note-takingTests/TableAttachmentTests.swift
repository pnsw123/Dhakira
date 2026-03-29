import XCTest
@testable import Note_taking

final class TableAttachmentTests: XCTestCase {

    // MARK: - TableAttachmentCodec

    // #1 Encoding and decoding preserves rows, cols, and cells
    func test_codec_roundTrip_preservesModel() {
        var data = TableData(rows: 3, cols: 4)
        data.cells[0] = "Hello"
        data.cells[1] = "World"
        data.cells[11] = "Last"

        guard case .success(let encoded) = TableAttachmentCodec.encode(data) else {
            XCTFail("encode should succeed")
            return
        }
        guard case .success(let decoded) = TableAttachmentCodec.decode(encoded) else {
            XCTFail("decode should succeed")
            return
        }

        XCTAssertEqual(decoded.rows, 3)
        XCTAssertEqual(decoded.cols, 4)
        XCTAssertEqual(decoded.cells[0], "Hello")
        XCTAssertEqual(decoded.cells[1], "World")
        XCTAssertEqual(decoded.cells[11], "Last")
    }

    // #2 Empty cells round-trip correctly
    func test_codec_roundTrip_emptyCells() {
        let data = TableData(rows: 2, cols: 2)

        guard case .success(let encoded) = TableAttachmentCodec.encode(data),
              case .success(let decoded) = TableAttachmentCodec.decode(encoded) else {
            XCTFail("round-trip should succeed")
            return
        }

        XCTAssertTrue(decoded.cells.allSatisfy { $0.isEmpty })
    }

    // #3 Unicode cell content round-trips correctly
    func test_codec_roundTrip_unicodeContent() {
        var data = TableData(rows: 2, cols: 2)
        data.cells[0] = "مرحبا"       // Arabic
        data.cells[1] = "你好"          // Chinese
        data.cells[2] = "こんにちは"    // Japanese
        data.cells[3] = "🎉🍎✅"        // Emoji

        guard case .success(let encoded) = TableAttachmentCodec.encode(data),
              case .success(let decoded) = TableAttachmentCodec.decode(encoded) else {
            XCTFail("round-trip should succeed for unicode content")
            return
        }

        XCTAssertEqual(decoded.cells[0], "مرحبا")
        XCTAssertEqual(decoded.cells[1], "你好")
        XCTAssertEqual(decoded.cells[2], "こんにちは")
        XCTAssertEqual(decoded.cells[3], "🎉🍎✅")
    }

    // #4 Maximum size 6×6 round-trips correctly
    func test_codec_roundTrip_maxSize6x6() {
        var data = TableData(rows: 6, cols: 6)
        for i in 0..<36 {
            data.cells[i] = "cell_\(i)"
        }

        guard case .success(let encoded) = TableAttachmentCodec.encode(data),
              case .success(let decoded) = TableAttachmentCodec.decode(encoded) else {
            XCTFail("round-trip should succeed for 6×6 table")
            return
        }

        XCTAssertEqual(decoded.rows, 6)
        XCTAssertEqual(decoded.cols, 6)
        XCTAssertEqual(decoded.cells.count, 36)
        for i in 0..<36 {
            XCTAssertEqual(decoded.cells[i], "cell_\(i)")
        }
    }

    // #5 Decoding empty data returns failure
    func test_codec_decode_emptyData_returnsFailure() {
        guard case .failure(let error) = TableAttachmentCodec.decode(Data()) else {
            XCTFail("decoding empty data should fail")
            return
        }
        guard case .emptyData = error else {
            XCTFail("expected .emptyData, got \(error)")
            return
        }
    }

    // #6 TableAttachment initializes with correct row/col counts
    func test_attachment_init_hasCorrectDimensions() {
        let attachment = TableAttachment(rows: 3, cols: 5)
        XCTAssertEqual(attachment.tableData.rows, 3)
        XCTAssertEqual(attachment.tableData.cols, 5)
        XCTAssertEqual(attachment.tableData.cells.count, 15)
    }

    // #7 TableAttachment contents is valid JSON after init
    func test_attachment_contents_isValidJSON() {
        let attachment = TableAttachment(rows: 2, cols: 3)
        XCTAssertNotNil(attachment.contents, "contents should not be nil after init")
        guard let data = attachment.contents else { return }
        XCTAssertGreaterThan(data.count, 0)
        guard case .success = TableAttachmentCodec.decode(data) else {
            XCTFail("attachment.contents should be valid JSON")
            return
        }
    }

    // #8 updateCell persists value into attachment contents
    func test_attachment_updateCell_persistsValue() {
        let attachment = TableAttachment(rows: 3, cols: 3)
        attachment.updateCell(row: 1, col: 2, value: "updated")

        guard let data = attachment.contents,
              case .success(let decoded) = TableAttachmentCodec.decode(data) else {
            XCTFail("contents should decode after updateCell")
            return
        }
        XCTAssertEqual(decoded[1, 2], "updated")
    }

    // #9 from(contents:) reconstructs attachment
    func test_attachment_fromContents_reconstructs() {
        let original = TableAttachment(rows: 2, cols: 2)
        original.updateCell(row: 0, col: 1, value: "test")

        let restored = TableAttachment.from(contents: original.contents)
        XCTAssertNotNil(restored)
        XCTAssertEqual(restored?.tableData.rows, 2)
        XCTAssertEqual(restored?.tableData.cols, 2)
        XCTAssertEqual(restored?.tableData[0, 1], "test")
    }

    // #10 from(contents: nil) returns nil
    func test_attachment_fromNilContents_returnsNil() {
        let result = TableAttachment.from(contents: nil)
        XCTAssertNil(result)
    }

    // MARK: - TableData subscript

    // #11 Subscript get/set works correctly
    func test_tableData_subscript_getSet() {
        var data = TableData(rows: 3, cols: 3)
        data[2, 1] = "value"
        XCTAssertEqual(data[2, 1], "value")
        XCTAssertEqual(data.cells[2 * 3 + 1], "value")
    }

    // MARK: - RichEditorCommands.insertTableAttachment (Issue #56)

    // #12 insertTableAttachment places attachment at correct position
    func test_insertTableAttachment_atCursor_placesAttachmentAtExpectedOffset() {
        var attributed = NSAttributedString(string: "Hello World")
        // Insert at offset 5 (between "Hello" and " World")
        let newCursor = RichEditorCommands.insertTableAttachment(
            rows: 2,
            cols: 3,
            attributedText: &attributed,
            cursorLocation: 5
        )

        // The resulting string should have length = original(11) + 1 attachment char = 12
        XCTAssertEqual(attributed.length, 12)
        // New cursor is right after the inserted attachment character
        XCTAssertEqual(newCursor, 6)
    }

    // #13 insertTableAttachment stores correct rows and cols in attachment contents
    func test_insertTableAttachment_storesCorrectRowsAndCols() {
        var attributed = NSAttributedString(string: "")
        RichEditorCommands.insertTableAttachment(
            rows: 3,
            cols: 4,
            attributedText: &attributed,
            cursorLocation: 0
        )

        XCTAssertEqual(attributed.length, 1, "Should have exactly 1 character (the attachment)")
        let attachment = attributed.attribute(.attachment, at: 0, effectiveRange: nil) as? TableAttachment
        XCTAssertNotNil(attachment, "Attachment should be a TableAttachment")
        XCTAssertEqual(attachment?.tableData.rows, 3)
        XCTAssertEqual(attachment?.tableData.cols, 4)
    }

    // #14 insertTableAttachment at end of string works (no crash)
    func test_insertTableAttachment_atEndOfString_works() {
        var attributed = NSAttributedString(string: "End")
        XCTAssertNoThrow(
            RichEditorCommands.insertTableAttachment(
                rows: 2,
                cols: 2,
                attributedText: &attributed,
                cursorLocation: 3
            )
        )
        XCTAssertEqual(attributed.length, 4)
    }

    // #15 insertTableAttachment at location beyond end clamps safely
    func test_insertTableAttachment_beyondEnd_clampsToEnd() {
        var attributed = NSAttributedString(string: "Hi")
        XCTAssertNoThrow(
            RichEditorCommands.insertTableAttachment(
                rows: 1,
                cols: 1,
                attributedText: &attributed,
                cursorLocation: 999
            )
        )
        XCTAssertEqual(attributed.length, 3)
    }

    // MARK: - NoteBodyCodec round-trip with TableAttachment (Issue #58)

    // #16 RTF round-trip preserves attachment contents
    func test_noteBodyCodec_roundTrip_preservesTableAttachmentContents() {
        let attachment = TableAttachment(rows: 2, cols: 2)
        attachment.updateCell(row: 0, col: 0, value: "A")
        attachment.updateCell(row: 1, col: 1, value: "D")
        let originalContents = attachment.contents

        let mutable = NSMutableAttributedString(string: "Before ")
        mutable.append(NSAttributedString(attachment: attachment))
        mutable.append(NSAttributedString(string: " After"))

        guard case .success(let encoded) = NoteBodyCodec.encode(mutable) else {
            XCTFail("encode should succeed")
            return
        }
        guard case .success(let decoded) = NoteBodyCodec.decode(encoded) else {
            XCTFail("decode should succeed")
            return
        }

        // Find the attachment in the decoded attributed string
        var foundAttachment: NSTextAttachment?
        decoded.enumerateAttribute(.attachment, in: NSRange(location: 0, length: decoded.length)) { value, _, _ in
            if let att = value as? NSTextAttachment {
                foundAttachment = att
            }
        }
        XCTAssertNotNil(foundAttachment, "Decoded string should contain the attachment")
        XCTAssertEqual(foundAttachment?.contents, originalContents,
                       "Attachment contents should survive RTF round-trip")
    }
}
