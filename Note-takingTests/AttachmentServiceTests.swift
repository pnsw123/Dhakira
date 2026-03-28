import XCTest
@testable import Note_taking

@MainActor
final class AttachmentServiceTests: XCTestCase {

    private var service: AttachmentService!

    override func setUp() {
        super.setUp()
        service = AttachmentService()
    }

    // MARK: - #1 appendImage with invalid data sets alertItem (was: silent return)

    func test_appendImage_invalidData_setsAlertItem() {
        var text = NSAttributedString(string: "Start")
        let badData = Data("not an image".utf8)

        service.appendImage(badData, to: &text)

        XCTAssertNotNil(service.alertItem,
                        "appendImage with bad data must set alertItem — no more silent failures")

        if case .imageDecodeFailed(let bytes) = service.alertItem {
            XCTAssertEqual(bytes, badData.count, "Error should carry the byte count")
        } else {
            XCTFail("Expected .imageDecodeFailed, got: \(String(describing: service.alertItem))")
        }
    }

    // MARK: - #2 appendImage with invalid data does NOT modify the text

    func test_appendImage_invalidData_doesNotMutateText() {
        var text = NSAttributedString(string: "Unchanged")
        let badData = Data("garbage".utf8)

        service.appendImage(badData, to: &text)

        XCTAssertEqual(text.string, "Unchanged",
                       "Text should not change when image decode fails")
    }

    // MARK: - #3 appendFile appends a tappable link

    func test_appendFile_addsLinkAttribute() {
        var text = NSAttributedString(string: "Before")
        let url = URL(string: "file:///tmp/report.pdf")!

        service.appendFile(url: url, to: &text)

        XCTAssertTrue(text.string.contains("report.pdf"),
                      "File name should appear in the attributed string")

        // The filename portion should carry a .link attribute
        let range = (text.string as NSString).range(of: "report.pdf")
        let linkAttr = text.attribute(.link, at: range.location, effectiveRange: nil) as? URL
        XCTAssertEqual(linkAttr, url, "File attachment should carry a tappable .link attribute")
    }

    // MARK: - #4 appendAudio stores a link, not dead text

    func test_appendAudio_addsLinkNotDeadText() {
        var text = NSAttributedString(string: "")
        let audioURL = URL(string: "file:///tmp/recording.m4a")!

        service.appendAudio(url: audioURL, to: &text)

        XCTAssertTrue(text.string.contains("recording.m4a"),
                      "Audio filename should appear in the text")

        // Must have a .link attribute (unlike the old "\n[Audio: filename]" dead-text)
        let range = (text.string as NSString).range(of: "recording.m4a")
        XCTAssertGreaterThan(range.length, 0)
        let linkAttr = text.attribute(.link, at: range.location, effectiveRange: nil)
        XCTAssertNotNil(linkAttr, "Audio attachment must be a tappable link, not dead text")
    }

    // MARK: - #5 Only one activeSheet can be set at a time (mutual exclusion)

    func test_activeSheet_mutualExclusion() {
        service.scanText()
        XCTAssertEqual(service.activeSheet?.id, AttachmentSheet.dataScanner.id)

        // Switching to another type replaces the previous one
        service.recordAudio()
        XCTAssertEqual(service.activeSheet?.id, AttachmentSheet.audioRecorder.id,
                       "Setting a new activeSheet should replace the previous one")
    }

    // MARK: - #6 appendScannedText appends text inline

    func test_appendScannedText_appendsToExistingContent() {
        var text = NSAttributedString(string: "Original")

        service.appendScannedText("Scanned content here", to: &text)

        XCTAssertTrue(text.string.contains("Original"),
                      "Original content should be preserved")
        XCTAssertTrue(text.string.contains("Scanned content here"),
                      "Scanned text should be appended")
    }
}
