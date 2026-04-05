import UIKit
import PencilKit
import OSLog

private let log = Logger(subsystem: "notes.Note-taking", category: "NativeExport")

// MARK: - NativeExportService
// Replaces WKWebView-based export with fully native PDF + RTF export (Issue #45).

#if canImport(UIKit)
final class NativeExportService {

    // MARK: - Export as PDF

    static func exportAsPDF(title: String, content: NSAttributedString, drawing: PKDrawing? = nil, from viewController: UIViewController) {
        log.info("exportAsPDF: starting for '\(title)', \(content.length) chars, hasDrawing=\(drawing != nil)")

        let pageRect  = CGRect(x: 0, y: 0, width: 595.2, height: 841.8) // A4
        let margin: CGFloat = 40
        let printableRect = pageRect.insetBy(dx: margin, dy: margin + 20)
        let printableHeight = printableRect.height

        // Prepend title as bold heading
        let full = NSMutableAttributedString()
        if !title.isEmpty {
            full.append(NSAttributedString(string: title + "\n\n", attributes: [
                .font: UIFont.systemFont(ofSize: 20, weight: .bold),
                .foregroundColor: UIColor.black
            ]))
        }
        full.append(normalizeForPDF(content))

        // UISimpleTextPrintFormatter uses TextKit — correctly renders NSTextAttachment images.
        let formatter = UISimpleTextPrintFormatter(attributedText: full)
        let renderer  = UIPrintPageRenderer()
        renderer.addPrintFormatter(formatter, startingAtPageAt: 0)
        renderer.setValue(NSValue(cgRect: pageRect),     forKey: "paperRect")
        renderer.setValue(NSValue(cgRect: printableRect), forKey: "printableRect")

        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, pageRect, nil)
        renderer.prepare(forDrawingPages: NSRange(location: 0, length: renderer.numberOfPages))
        for i in 0..<renderer.numberOfPages {
            UIGraphicsBeginPDFPage()
            renderer.drawPage(at: i, in: pageRect)

            // Overlay PKDrawing — position it on the correct page at the correct offset.
            // drawing.bounds gives us the position in the UITextView's coordinate space.
            // We map that to the paginated PDF: which page and at what Y offset on that page.
            if let drawing, !drawing.strokes.isEmpty {
                let bounds = drawing.bounds
                // Scale factor: screen points to PDF points (A4 width / screen width)
                let screenWidth = printableRect.width
                let drawingScale = min(screenWidth / max(bounds.width, 1), 1.0)

                // Which page does the drawing start on?
                let drawingTopInDoc = bounds.origin.y * drawingScale
                let drawingPage = Int(drawingTopInDoc / printableHeight)

                if i == drawingPage {
                    let drawingImage = drawing.image(from: bounds, scale: 2.0)
                    // Y position on this page = drawing's Y minus page offset
                    let yOnPage = drawingTopInDoc - (CGFloat(drawingPage) * printableHeight)
                    let drawSize = CGSize(
                        width: bounds.width * drawingScale,
                        height: bounds.height * drawingScale
                    )
                    let drawRect = CGRect(
                        x: printableRect.origin.x + (bounds.origin.x * drawingScale),
                        y: printableRect.origin.y + yOnPage,
                        width: drawSize.width,
                        height: drawSize.height
                    )
                    drawingImage.draw(in: drawRect)
                    log.debug("exportAsPDF: drew PKDrawing on page \(i) at y=\(yOnPage)")
                }
            }
        }
        UIGraphicsEndPDFContext()

        let fileName = sanitizeFilename(title.isEmpty ? "Note" : title) + ".pdf"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try (pdfData as Data).write(to: tempURL)
            log.info("exportAsPDF: written \(pdfData.length) bytes to \(tempURL.lastPathComponent)")
            presentShareSheet(items: [tempURL], from: viewController)
        } catch {
            log.error("exportAsPDF: write failed — \(error.localizedDescription)")
        }
    }

    // MARK: - Export as RTF (Word-compatible)

    static func exportAsRTF(title: String, content: NSAttributedString, from viewController: UIViewController) {
        log.info("exportAsRTF: starting for '\(title)', \(content.length) chars")

        // Prepend title as bold heading
        let full = NSMutableAttributedString()
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 20, weight: .bold)
        ]
        full.append(NSAttributedString(string: title + "\n\n", attributes: titleAttrs))
        full.append(normalizeForWord(content))

        guard let data = full.rtfData() else {
            log.error("exportAsRTF: RTF conversion failed")
            return
        }

        let fileName = sanitizeFilename(title.isEmpty ? "Note" : title) + ".doc"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: tempURL)
            log.info("exportAsRTF: written \(data.count) bytes to \(tempURL.lastPathComponent)")
            presentShareSheet(items: [tempURL], from: viewController)
        } catch {
            log.error("exportAsRTF: write failed — \(error.localizedDescription)")
        }
    }

    // MARK: - Share plain text

    static func shareText(title: String, content: NSAttributedString, from viewController: UIViewController) {
        log.info("shareText: sharing '\(title)', \(content.length) chars")
        let plainText = content.string
        let shareText = title.isEmpty ? plainText : "\(title)\n\n\(plainText)"
        log.debug("shareText: plain text length=\(shareText.count) chars")
        presentShareSheet(items: [shareText], from: viewController)
    }

    // MARK: - Helpers

    /// Replaces dynamic (theme-aware) colors with static print-safe equivalents.
    /// Prevents dark-theme white text from becoming invisible on a white PDF page.
    /// Also replaces CheckboxAttachment SF Symbols with .alwaysOriginal images
    /// to prevent them rendering as solid black boxes (Issue #106).
    private static func normalizeForPDF(_ source: NSAttributedString) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: source)
        let fullRange = NSRange(location: 0, length: mutable.length)

        // Pass 1: Replace CheckboxAttachment template images with print-safe originals.
        // SF Symbol .alwaysTemplate images fill with the foreground color in print
        // contexts, producing solid black boxes. Re-render with .alwaysOriginal.
        var checkboxUpdates: [(NSRange, NSTextAttachment)] = []
        mutable.enumerateAttribute(.attachment, in: fullRange, options: []) { value, range, _ in
            guard let cb = value as? CheckboxAttachment else { return }
            let symbolName = cb.isChecked ? "checkmark.square.fill" : "square"
            let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .regular)
                .applying(UIImage.SymbolConfiguration(paletteColors: [.black]))
            if let img = UIImage(systemName: symbolName, withConfiguration: config)?
                .withRenderingMode(.alwaysOriginal) {
                let printAttachment = NSTextAttachment()
                printAttachment.image = img
                printAttachment.bounds = CGRect(x: 0, y: -3, width: 16, height: 16)
                checkboxUpdates.append((range, printAttachment))
            }
        }
        for (range, attachment) in checkboxUpdates.reversed() {
            mutable.removeAttribute(.attachment, range: range)
            mutable.addAttribute(.attachment, value: attachment, range: range)
        }

        // Pass 2: Force all text to black and remove dark backgrounds.
        // Collect changes first — mutating during enumerateAttributes is undefined behavior.
        let updatedRange = NSRange(location: 0, length: mutable.length)
        var colorUpdates: [NSRange] = []
        var bgRemoves: [NSRange] = []
        mutable.enumerateAttributes(in: updatedRange, options: []) { attrs, range, _ in
            colorUpdates.append(range)
            if let bg = attrs[.backgroundColor] as? UIColor {
                var white: CGFloat = 0
                bg.getWhite(&white, alpha: nil)
                if white < 0.5 { bgRemoves.append(range) }
            }
        }
        for range in colorUpdates {
            mutable.addAttribute(.foregroundColor, value: UIColor.black, range: range)
        }
        for range in bgRemoves {
            mutable.removeAttribute(.backgroundColor, range: range)
        }

        // Pass 3: Make quote bar characters visible for PDF (AFTER color normalization).
        // In the editor, "│" is drawn with .clear foreground (a UIView overlay
        // provides the visible bar). PDFs don't have overlays, so we make the
        // actual character blue and ensure proper indentation (Issue #105).
        let str = mutable.string as NSString
        var loc = 0
        while loc < mutable.length {
            let parRange = str.paragraphRange(for: NSRange(location: loc, length: 0))
            let parText = str.substring(with: parRange)
            if parText.hasPrefix("│ ") || parText == "│" || parText == "│\n" {
                // Make the bar character blue and visible (overrides the black from pass 2)
                let barRange = NSRange(location: parRange.location, length: 1)
                mutable.addAttribute(.foregroundColor, value: UIColor.systemBlue, range: barRange)
                // Ensure quote text has proper indentation in PDF
                let style = NSMutableParagraphStyle()
                style.headIndent = 28
                style.firstLineHeadIndent = 28
                style.tailIndent = -16
                mutable.addAttribute(.paragraphStyle, value: style, range: parRange)
            }
            let next = parRange.location + parRange.length
            if next <= loc { break }
            loc = next
        }

        return mutable
    }

    /// Prepares content for RTF/Word export:
    /// - Forces text color to black (dark-theme white text is invisible in Word)
    /// - Replaces NSTextAttachment images with "[Image]" — RTF encoder can't handle
    ///   inline image attachments and produces malformed output (each letter on a new page).
    private static func normalizeForWord(_ source: NSAttributedString) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: normalizeForPDF(source))
        var attachmentRanges: [NSRange] = []
        mutable.enumerateAttribute(.attachment, in: NSRange(location: 0, length: mutable.length), options: []) { value, range, _ in
            if value != nil { attachmentRanges.append(range) }
        }
        for range in attachmentRanges.reversed() {
            let placeholder = NSAttributedString(string: "[Image]", attributes: [
                .font: UIFont.italicSystemFont(ofSize: 12),
                .foregroundColor: UIColor.darkGray
            ])
            mutable.replaceCharacters(in: range, with: placeholder)
        }
        return mutable
    }

    private static func sanitizeFilename(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:*?\"<>|")
        let sanitized = name.components(separatedBy: invalid).joined(separator: "_")
        if sanitized != name {
            log.debug("sanitizeFilename: '\(name)' → '\(sanitized)'")
        }
        return sanitized
    }

    static func presentShareSheet(items: [Any], from viewController: UIViewController) {
        log.info("presentShareSheet: presenting with \(items.count) item(s)")
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        vc.modalPresentationStyle = .formSheet
        viewController.present(vc, animated: true)
    }
}
#endif
