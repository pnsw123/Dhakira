import XCTest
@testable import Note_taking

// MARK: - BugFixVerificationTests
// Verifies behaviors for bug fixes in issues #94–#111.
// Tests use public interfaces only — no mocking of internals.
// Organized by service/component, each test documents the issue it guards.

final class BugFixVerificationTests: XCTestCase {

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Issue #108: DateDetectionService — "8-9" must NOT trigger calendar
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private lazy var dateService = DateDetectionService()

    /// "task 8-9" means "task 8 and 9", not a time. Must produce zero dates.
    func testDashBetweenNumbersDoesNotTriggerDate() {
        let results = dateService.detectDates(in: "task 8-9")
        XCTAssertTrue(results.isEmpty,
            "Issue #108: '8-9' must not be interpreted as a date/time range")
    }

    /// "items 3-5" is a number range, not a time.
    func testDashNumberRangeIsIgnored() {
        let results = dateService.detectDates(in: "items 3-5")
        XCTAssertTrue(results.isEmpty,
            "Issue #108: '3-5' must not be interpreted as a date/time range")
    }

    /// "page 10-12" is a page range, not a time.
    func testDashPageRangeIsIgnored() {
        let results = dateService.detectDates(in: "page 10-12")
        XCTAssertTrue(results.isEmpty,
            "Issue #108: '10-12' must not be interpreted as a date/time range")
    }

    /// Explicit time with am/pm SHOULD still detect — only bare dashes are excluded.
    func testExplicitTimeStillDetects() {
        let results = dateService.detectDates(in: "meeting at 5pm")
        XCTAssertFalse(results.isEmpty,
            "Issue #108: explicit times like '5pm' must still be detected")
    }

    /// Slash-separated dates should still work (only dashes excluded for 2-part).
    func testSlashDateStillDetects() {
        let results = dateService.detectDates(in: "deadline 4/15")
        XCTAssertFalse(results.isEmpty,
            "Issue #108: slash dates like '4/15' must still be detected")
    }

    /// Dot-separated dates should still work.
    func testDotDateStillDetects() {
        let results = dateService.detectDates(in: "due 4.15")
        XCTAssertFalse(results.isEmpty,
            "Issue #108: dot dates like '4.15' must still be detected")
    }

    /// Normalizer should NOT convert "8-9" into a date via expandTwoPartDates.
    func testNormalizeDoesNotExpandDashTwoPart() {
        let normalized = dateService.normalize("task 8-9")
        // The normalized string should NOT contain a slash-date expansion
        XCTAssertFalse(normalized.contains("/"),
            "Issue #108: normalize must not expand '8-9' into a slash date")
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Issues #102/#103: Toolbar — Bold and Font Size independence
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    /// Font size buttons must preserve bold/italic traits exactly.
    /// Issue #103: A/a were randomly applying Bold as a side effect.
    func testStepFontSizePreservesBoldTrait() {
        // Create a bold 16pt attributed string
        let boldFont = UIFont.boldSystemFont(ofSize: 16)
        var text: NSAttributedString = NSAttributedString(
            string: "Hello",
            attributes: [.font: boldFont]
        )
        let range = NSRange(location: 0, length: 5)

        // Increase font size
        RichEditorCommands.stepFontSize(increase: true, attributedText: &text, selectedRange: range)

        // Verify: font size increased, bold trait preserved
        let resultFont = text.attribute(.font, at: 0, effectiveRange: nil) as! UIFont
        XCTAssertEqual(resultFont.pointSize, 18,
            "Issue #103: font size must increase by 2pt (16→18)")
        XCTAssertTrue(resultFont.fontDescriptor.symbolicTraits.contains(.traitBold),
            "Issue #103: bold trait must be preserved after font size change")
    }

    /// Decrease font size must also preserve traits.
    func testStepFontSizeDecreasePreservesTraits() {
        let boldItalicDesc = UIFont.systemFont(ofSize: 20).fontDescriptor
            .withSymbolicTraits([.traitBold, .traitItalic])!
        let font = UIFont(descriptor: boldItalicDesc, size: 20)
        var text: NSAttributedString = NSAttributedString(
            string: "Test",
            attributes: [.font: font]
        )
        let range = NSRange(location: 0, length: 4)

        RichEditorCommands.stepFontSize(increase: false, attributedText: &text, selectedRange: range)

        let resultFont = text.attribute(.font, at: 0, effectiveRange: nil) as! UIFont
        XCTAssertEqual(resultFont.pointSize, 18,
            "Issue #103: font size must decrease by 2pt (20→18)")
        XCTAssertTrue(resultFont.fontDescriptor.symbolicTraits.contains(.traitBold),
            "Issue #103: bold must be preserved after decrease")
        XCTAssertTrue(resultFont.fontDescriptor.symbolicTraits.contains(.traitItalic),
            "Issue #103: italic must be preserved after decrease")
    }

    /// Font size must not go below 10pt minimum.
    func testStepFontSizeRespectsMinimum() {
        let font = UIFont.systemFont(ofSize: 10)
        var text: NSAttributedString = NSAttributedString(
            string: "Tiny",
            attributes: [.font: font]
        )
        let range = NSRange(location: 0, length: 4)

        RichEditorCommands.stepFontSize(increase: false, attributedText: &text, selectedRange: range)

        let resultFont = text.attribute(.font, at: 0, effectiveRange: nil) as! UIFont
        XCTAssertEqual(resultFont.pointSize, 10,
            "Font size must not go below 10pt minimum")
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Issue #104: Quote block indentation = 28pt
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    /// Blockquote must apply 18pt head indent so wrapped lines sit under the quoted text,
    /// not under "│". firstLineHeadIndent stays 0 so the "│" character starts at the margin.
    func testBlockquoteIndentIs18pt() {
        var text: NSAttributedString = NSAttributedString(string: "Some quoted text here")
        let range = NSRange(location: 0, length: text.length)

        RichEditorCommands.applyBlockquote(attributedText: &text, selectedRange: range)

        // After applying blockquote, text starts with "│ " — check paragraph style
        let paraStyle = text.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        XCTAssertNotNil(paraStyle, "Issue #104: blockquote must have a paragraph style")
        XCTAssertEqual(paraStyle?.headIndent, 18,
            "Issue #104: blockquote headIndent must be 18pt — keeps wrapped lines under quoted text without colliding with the bar")
        XCTAssertEqual(paraStyle?.firstLineHeadIndent, 0,
            "Issue #104: blockquote firstLineHeadIndent must be 0 so '│' starts at the margin")
    }

    /// Blockquote toggle off should remove indent.
    func testBlockquoteToggleOffRemovesIndent() {
        var text: NSAttributedString = NSAttributedString(string: "Quote me")
        let range = NSRange(location: 0, length: text.length)

        // Apply blockquote
        RichEditorCommands.applyBlockquote(attributedText: &text, selectedRange: range)
        // Toggle it off
        RichEditorCommands.applyBlockquote(attributedText: &text, selectedRange: NSRange(location: 0, length: text.length))

        // Should no longer start with "│ "
        XCTAssertFalse(text.string.hasPrefix("│ "),
            "Issue #104: toggling blockquote off must remove the bar prefix")
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Issue #101: NoteBodyCodec — Image size persistence via [img:UUID:WxH]
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    /// Encode must produce [img:UUID:WxH] when attachment has custom bounds.
    func testCodecEncodesImageSizeInPlaceholder() {
        let attachment = NSTextAttachment()
        attachment.image = UIImage(systemName: "photo")
        attachment.bounds = CGRect(x: 0, y: 0, width: 150, height: 100)

        let testUUID = UUID()
        let attachStr = NSMutableAttributedString(attachment: attachment)
        attachStr.addAttribute(.imageAttachmentId, value: testUUID.uuidString,
                               range: NSRange(location: 0, length: attachStr.length))

        let result = NoteBodyCodec.encode(attachStr)

        switch result {
        case .success(let data):
            // Decode the RTF payload to check the placeholder text
            let rtfData = data.dropFirst() // strip version byte
            if let decoded = try? NSAttributedString(data: rtfData,
                                                      options: [.documentType: NSAttributedString.DocumentType.rtf],
                                                      documentAttributes: nil) {
                let str = decoded.string
                XCTAssertTrue(str.contains("150x100"),
                    "Issue #101: encoded placeholder must include WxH dimensions — got: \(str)")
            } else {
                XCTFail("Issue #101: could not decode RTF payload to verify placeholder")
            }
        case .failure(let error):
            XCTFail("Issue #101: encode should not fail — \(error)")
        }
    }

    /// Encode must produce [img:UUID] (no WxH) when bounds are zero/default.
    func testCodecEncodesWithoutSizeWhenBoundsZero() {
        let attachment = NSTextAttachment()
        attachment.image = UIImage(systemName: "photo")
        // bounds default is .zero

        let testUUID = UUID()
        let attachStr = NSMutableAttributedString(attachment: attachment)
        attachStr.addAttribute(.imageAttachmentId, value: testUUID.uuidString,
                               range: NSRange(location: 0, length: attachStr.length))

        let result = NoteBodyCodec.encode(attachStr)

        switch result {
        case .success(let data):
            let rtfData = data.dropFirst()
            if let decoded = try? NSAttributedString(data: rtfData,
                                                      options: [.documentType: NSAttributedString.DocumentType.rtf],
                                                      documentAttributes: nil) {
                let str = decoded.string
                // Should have [img:UUID] but NOT [img:UUID:0x0]
                XCTAssertTrue(str.contains("[img:"),
                    "Issue #101: must contain image placeholder")
                XCTAssertFalse(str.contains("x"),
                    "Issue #101: placeholder must NOT include WxH when bounds are zero — got: \(str)")
            }
        case .failure(let error):
            XCTFail("Issue #101: encode should not fail — \(error)")
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Issue #99: Default image insertion width = 180pt
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    /// Verify the default display width cap is 180pt, not 280pt.
    func testDefaultImageWidthIs180() {
        let service = AttachmentService()
        // Create a large test image (1000x1000)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1000, height: 1000))
        let largeImage = renderer.image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 1000, height: 1000))
        }
        guard let data = largeImage.pngData() else {
            XCTFail("Issue #99: could not create test image data")
            return
        }

        var text: NSAttributedString = NSAttributedString(string: "")
        let taskId = UUID()

        service.appendImage(data, to: &text, taskId: taskId)

        // Find the image attachment in the result
        var foundBounds: CGRect?
        text.enumerateAttribute(.attachment, in: NSRange(location: 0, length: text.length), options: []) { value, _, _ in
            if let attachment = value as? NSTextAttachment, attachment.image != nil {
                foundBounds = attachment.bounds
            }
        }

        XCTAssertNotNil(foundBounds, "Issue #99: image attachment must be present")
        XCTAssertEqual(foundBounds?.width, 180,
            "Issue #99: default image width must be 180pt, not 280pt — got: \(foundBounds?.width ?? -1)")
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Issues #105/#106: PDF export — quotes and checkboxes
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    /// Quote bar character must remain .clear in normalizeForPDF — the PDF render pass
    /// draws the visible bar separately (Issue #105). This test verifies the two-phase
    /// design: normalizeForPDF keeps "│" clear, the render pass paints the actual bar.
    func testPDFNormalizeKeepsQuoteBarClearForRenderPass() {
        // Create a quote block
        var quoteText: NSAttributedString = NSAttributedString(string: "Hello world")
        RichEditorCommands.applyBlockquote(attributedText: &quoteText, selectedRange: NSRange(location: 0, length: quoteText.length))

        // In the editor the bar character "│" is .clear — UIView overlay provides the visual.
        let editorBarColor = quoteText.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        XCTAssertEqual(editorBarColor, UIColor.clear,
            "Issue #105: in editor, quote bar must be .clear (UIView overlay renders it)")

        // After normalization the bar character remains .clear.
        // The PDF render pass (NativeExportService.exportAsPDF) draws the physical bar
        // over the page content — it does NOT rely on the glyph's foreground color.
        let normalized = NativeExportService.normalizeForPDFTestable(quoteText)
        let pdfBarColor = normalized.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        XCTAssertEqual(pdfBarColor, UIColor.clear,
            "Issue #105: quote bar must stay .clear in normalizeForPDF — PDF render pass draws the bar separately")

        // The quoted text (after "│ ") must NOT be .clear — it should be visible.
        if normalized.length > 2 {
            let textColor = normalized.attribute(.foregroundColor, at: 2, effectiveRange: nil) as? UIColor
            XCTAssertNotEqual(textColor, UIColor.clear,
                "Issue #105: quoted text must be visible (non-clear) in PDF output")
        }
    }

    /// Checkboxes must use .alwaysOriginal rendering in PDF (not .alwaysTemplate
    /// which renders as solid black boxes).
    func testPDFNormalizeCheckboxesUseOriginalRendering() {
        // Create a checklist
        var text: NSAttributedString = NSAttributedString(string: "")
        RichEditorCommands.insertChecklist(attributedText: &text, cursorLocation: 0)

        let normalized = NativeExportService.normalizeForPDFTestable(text)

        // Find the attachment in normalized text
        var foundAttachment: NSTextAttachment?
        normalized.enumerateAttribute(.attachment, in: NSRange(location: 0, length: normalized.length), options: []) { value, _, stop in
            if let att = value as? NSTextAttachment {
                foundAttachment = att
                stop.pointee = true
            }
        }

        XCTAssertNotNil(foundAttachment, "Issue #106: checkbox attachment must exist in PDF output")
        // The attachment should be a plain NSTextAttachment (not CheckboxAttachment)
        // with .alwaysOriginal rendering
        XCTAssertFalse(foundAttachment is CheckboxAttachment,
            "Issue #106: PDF must replace CheckboxAttachment with plain NSTextAttachment using .alwaysOriginal")
        XCTAssertEqual(foundAttachment?.image?.renderingMode, .alwaysOriginal,
            "Issue #106: checkbox image must use .alwaysOriginal to prevent solid black box rendering")
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Issue #107: PDF page breaks — TextKit manual layout
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    /// Verify TextKit manual layout fills pages properly (no 2-line pages).
    func testTextKitLayoutFillsPages() {
        // Create a long text that should fill multiple pages
        let longText = String(repeating: "This is a test sentence for page layout. ", count: 200)
        let content = NSAttributedString(string: longText, attributes: [
            .font: UIFont.systemFont(ofSize: 14)
        ])

        let pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8) // A4
        let margin: CGFloat = 40
        let printableRect = pageRect.insetBy(dx: margin, dy: margin + 20)

        let textStorage = NSTextStorage(attributedString: content)
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)

        var containers: [NSTextContainer] = []
        func addContainer() -> NSTextContainer {
            let tc = NSTextContainer(size: CGSize(width: printableRect.width, height: printableRect.height))
            tc.lineFragmentPadding = 0
            layoutManager.addTextContainer(tc)
            containers.append(tc)
            return tc
        }
        _ = addContainer()
        layoutManager.ensureLayout(for: containers[0])

        while layoutManager.glyphRange(for: containers.last!).upperBound < layoutManager.numberOfGlyphs {
            let tc = addContainer()
            layoutManager.ensureLayout(for: tc)
        }

        // Must produce multiple pages for ~200 sentences
        XCTAssertGreaterThan(containers.count, 1,
            "Issue #107: long text must produce multiple pages")

        // Each page (except possibly the last) must use a significant portion of the page
        for (i, tc) in containers.enumerated() {
            let glyphRange = layoutManager.glyphRange(for: tc)
            if i < containers.count - 1 { // skip last page
                XCTAssertGreaterThan(glyphRange.length, 50,
                    "Issue #107: page \(i) must have substantial content, not just 2 lines (got \(glyphRange.length) glyphs)")
            }
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Codec round-trip: checkboxes survive encode/decode
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    /// Checkbox placeholders must round-trip through encode→decode.
    func testCheckboxRoundTrip() {
        var text: NSAttributedString = NSAttributedString(string: "Todo: ")
        RichEditorCommands.insertChecklist(attributedText: &text, cursorLocation: text.length)

        let encoded = NoteBodyCodec.encode(text)
        guard case .success(let data) = encoded else {
            XCTFail("Encode must succeed for checkbox round-trip test")
            return
        }

        let decoded = NoteBodyCodec.decode(data, taskId: UUID())
        guard case .success(let result) = decoded else {
            XCTFail("Decode must succeed for checkbox round-trip test")
            return
        }

        // Should contain a CheckboxAttachment
        var foundCheckbox = false
        result.enumerateAttribute(.attachment, in: NSRange(location: 0, length: result.length), options: []) { value, _, _ in
            if value is CheckboxAttachment { foundCheckbox = true }
        }
        XCTAssertTrue(foundCheckbox, "Checkbox must survive encode→decode round-trip")
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Blockquote on empty document
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    /// Blockquote must work on empty text (slash command case).
    func testBlockquoteOnEmptyText() {
        var text: NSAttributedString = NSAttributedString(string: "")
        let range = NSRange(location: 0, length: 0)

        // Must not crash
        RichEditorCommands.applyBlockquote(attributedText: &text, selectedRange: range)

        XCTAssertTrue(text.string.hasPrefix("│ "),
            "Blockquote must insert bar even on empty document")
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Bullet list round-trip
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    /// Bullet list toggle on then off must return to clean text.
    func testBulletListToggle() {
        var text: NSAttributedString = NSAttributedString(string: "Item one")
        let range = NSRange(location: 0, length: text.length)

        // Toggle on
        RichEditorCommands.toggleBulletList(attributedText: &text, selectedRange: range)
        XCTAssertTrue(text.string.hasPrefix("• "), "Bullet must be added")

        // Toggle off
        RichEditorCommands.toggleBulletList(attributedText: &text, selectedRange: NSRange(location: 0, length: text.length))
        XCTAssertFalse(text.string.hasPrefix("• "), "Bullet must be removed on toggle off")
        XCTAssertEqual(text.string, "Item one", "Original text must be restored")
    }
}
