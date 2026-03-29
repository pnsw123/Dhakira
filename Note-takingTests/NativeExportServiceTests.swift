import XCTest
@testable import Note_taking

// MARK: - NativeExportServiceTests
// Tests the logic inside NativeExportService that does NOT require a live UIViewController.
// We test: RTF generation, PDF data size, and filename sanitization (via the public API).
// Note: presentShareSheet is a UIViewController side-effect — tested via UI tests only.

final class NativeExportServiceTests: XCTestCase {

    // MARK: - RTF export helpers (NSAttributedString.rtfData)

    // #1 — A plain attributed string produces non-nil RTF data.
    func test_rtfData_nonNilForPlainText() {
        let attrStr = NSAttributedString(string: "Hello, RTF world!")
        let data = attrStr.rtfData()
        XCTAssertNotNil(data, "rtfData() must return non-nil for a plain attributed string")
    }

    // #2 — RTF data starts with the '{' byte (valid RTF header).
    func test_rtfData_startsWithRTFHeader() {
        let attrStr = NSAttributedString(string: "Title content")
        guard let data = attrStr.rtfData() else {
            XCTFail("rtfData() returned nil")
            return
        }
        let firstChar = String(data: data.prefix(1), encoding: .ascii)
        XCTAssertEqual(firstChar, "{", "Valid RTF must begin with '{'")
    }

    // #3 — An empty attributed string still produces RTF data (no crash).
    func test_rtfData_emptyString_doesNotCrash() {
        let attrStr = NSAttributedString()
        XCTAssertNoThrow(_ = attrStr.rtfData(),
                         "rtfData() on an empty attributed string must not throw")
    }

    // #4 — Bold text survives the RTF round-trip.
    func test_rtfData_boldTextRoundTrip() {
        let bold = UIFont.boldSystemFont(ofSize: 17)
        let attrStr = NSAttributedString(string: "Bold text", attributes: [.font: bold])
        guard let data = attrStr.rtfData() else {
            XCTFail("rtfData() returned nil for bold text")
            return
        }
        // Decode back and verify the string is preserved
        guard let decoded = try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        ) else {
            XCTFail("Failed to decode RTF data back to NSAttributedString")
            return
        }
        XCTAssertEqual(decoded.string, "Bold text",
                       "String content must survive RTF encode → decode round-trip")
    }

    // MARK: - PDF generation

    // #5 — exportAsPDF writes a valid file into the tmp directory.
    @MainActor
    func test_exportAsPDF_writesFileToTemp() {
        let title = "Test_PDF_\(UUID().uuidString)"
        let content = NSAttributedString(string: "This is the body of the PDF export test.")
        let vc = UIViewController()

        // We're not testing the share sheet — we just verify the file lands on disk.
        NativeExportService.exportAsPDF(title: title, content: content, from: vc)

        let expectedURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(title).pdf")
        XCTAssertTrue(FileManager.default.fileExists(atPath: expectedURL.path),
                      "exportAsPDF must write a .pdf file into the tmp directory")

        // Clean up
        try? FileManager.default.removeItem(at: expectedURL)
    }

    // #6 — exportAsPDF file has non-zero size.
    @MainActor
    func test_exportAsPDF_fileIsNonEmpty() {
        let title = "SizeCheck_\(UUID().uuidString)"
        let content = NSAttributedString(string: "Non-empty PDF body")
        let vc = UIViewController()

        NativeExportService.exportAsPDF(title: title, content: content, from: vc)

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(title).pdf")
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        let size = attrs?[.size] as? Int ?? 0
        XCTAssertGreaterThan(size, 0, "PDF file must not be empty")
        try? FileManager.default.removeItem(at: url)
    }

    // #7 — exportAsPDF with an empty title writes "Note.pdf".
    @MainActor
    func test_exportAsPDF_emptyTitle_usesDefaultFilename() {
        let content = NSAttributedString(string: "Some content")
        let vc = UIViewController()

        NativeExportService.exportAsPDF(title: "", content: content, from: vc)

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Note.pdf")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path),
                      "Empty title should produce 'Note.pdf'")
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - RTF export file

    // #8 — exportAsRTF writes a valid file into tmp.
    @MainActor
    func test_exportAsRTF_writesFileToTemp() {
        let title = "Test_RTF_\(UUID().uuidString)"
        let content = NSAttributedString(string: "RTF body content.")
        let vc = UIViewController()

        NativeExportService.exportAsRTF(title: title, content: content, from: vc)

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(title).rtf")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path),
                      "exportAsRTF must write a .rtf file into the tmp directory")
        try? FileManager.default.removeItem(at: url)
    }

    // #9 — exportAsRTF with title prepends it in the document.
    @MainActor
    func test_exportAsRTF_prependsTitle() {
        let title = "MyTitle_\(UUID().uuidString)"
        let content = NSAttributedString(string: "Body goes here")
        let vc = UIViewController()

        NativeExportService.exportAsRTF(title: title, content: content, from: vc)

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(title).rtf")
        guard let data = try? Data(contentsOf: url),
              let decoded = try? NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
              ) else {
            XCTFail("Could not read back the RTF file")
            return
        }
        XCTAssertTrue(decoded.string.contains(title.components(separatedBy: "_").first!),
                      "RTF document should start with the note title")
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Filename sanitization (via PDF path)

    // #10 — Slashes in title are replaced (file must still be created).
    @MainActor
    func test_sanitizeFilename_slashesReplaced() {
        let title = "My/Note/Name_\(UUID().uuidString)"
        let content = NSAttributedString(string: "Content")
        let vc = UIViewController()

        NativeExportService.exportAsPDF(title: title, content: content, from: vc)

        let sanitized = title.replacingOccurrences(of: "/", with: "_")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(sanitized).pdf")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path),
                      "Slashes in the title must be replaced with underscores in the filename")
        try? FileManager.default.removeItem(at: url)
    }

    // #11 — Colons in title are replaced.
    @MainActor
    func test_sanitizeFilename_colonReplaced() {
        let title = "Note:Title_\(UUID().uuidString)"
        let content = NSAttributedString(string: "Body")
        let vc = UIViewController()

        NativeExportService.exportAsPDF(title: title, content: content, from: vc)

        let sanitized = title.replacingOccurrences(of: ":", with: "_")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(sanitized).pdf")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path),
                      "Colons in title must be sanitized to '_'")
        try? FileManager.default.removeItem(at: url)
    }
}
