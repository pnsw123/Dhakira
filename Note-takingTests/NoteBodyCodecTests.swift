import XCTest
@testable import Note_taking

final class NoteBodyCodecTests: XCTestCase {

    // MARK: - #1 Round-trip: encode then decode preserves text content

    func test_encode_then_decode_preservesTextContent() {
        let original = NSAttributedString(string: "Hello, world!")

        let encoded = NoteBodyCodec.encode(original)
        guard case .success(let data) = encoded else {
            XCTFail("encode should succeed for plain text")
            return
        }

        let decoded = NoteBodyCodec.decode(data)
        guard case .success(let result) = decoded else {
            XCTFail("decode should succeed for valid encoded data")
            return
        }

        XCTAssertEqual(result.string, original.string)
    }

    // MARK: - #2 Empty data returns .failure(.emptyData)

    func test_decode_emptyData_returnsEmptyDataFailure() {
        let result = NoteBodyCodec.decode(Data())

        guard case .failure(let error) = result else {
            XCTFail("decode of empty Data should fail")
            return
        }
        guard case .emptyData = error else {
            XCTFail("expected .emptyData, got \(error)")
            return
        }
    }

    // MARK: - #3 Legacy bare-RTF (no version prefix) decodes successfully

    func test_decode_legacyBareRTF_succeeds() {
        // Simulate a blob stored before the version prefix was introduced
        let original = NSAttributedString(string: "Legacy note content")
        let range = NSRange(location: 0, length: original.length)
        guard let legacyRTF = try? original.data(
            from: range,
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        ) else {
            XCTFail("Failed to create legacy RTF data for test setup")
            return
        }

        // Decode without version prefix — should fallback gracefully
        let result = NoteBodyCodec.decode(legacyRTF)
        guard case .success(let decoded) = result else {
            XCTFail("decode of legacy bare-RTF should succeed, got: \(result)")
            return
        }

        XCTAssertEqual(decoded.string, "Legacy note content")
    }

    // MARK: - #4 Encoded data carries the v1 version byte prefix

    func test_encode_producesVersionedBlob() {
        let text = NSAttributedString(string: "Versioned")
        guard case .success(let data) = NoteBodyCodec.encode(text) else {
            XCTFail("encode should succeed")
            return
        }

        // First byte should be 0x01 (NoteBodyVersion.v1)
        XCTAssertFalse(data.isEmpty)
        XCTAssertEqual(data[data.startIndex], 0x01, "First byte should be v1 marker (0x01)")
    }

    // MARK: - #5 Encode then decode preserves attributed formatting (bold)

    func test_encode_then_decode_preservesBoldAttribute() {
        let mutable = NSMutableAttributedString(string: "Bold text")
        mutable.addAttribute(.font,
                             value: UIFont.boldSystemFont(ofSize: 17),
                             range: NSRange(location: 0, length: 4))

        guard case .success(let data) = NoteBodyCodec.encode(mutable),
              case .success(let decoded) = NoteBodyCodec.decode(data) else {
            XCTFail("round-trip should succeed")
            return
        }

        // The first 4 characters should have a bold font
        let font = decoded.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertNotNil(font)
        XCTAssertTrue(font?.fontDescriptor.symbolicTraits.contains(.traitBold) ?? false,
                      "Bold attribute should survive encode/decode round-trip")
    }
}
