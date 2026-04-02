import UIKit
import OSLog

private let log = Logger(subsystem: "notes.Note-taking", category: "NativeExport")

// MARK: - NativeExportService
// Replaces WKWebView-based export with fully native PDF + RTF export (Issue #45).

#if canImport(UIKit)
final class NativeExportService {

    // MARK: - Export as PDF

    static func exportAsPDF(title: String, content: NSAttributedString, from viewController: UIViewController) {
        log.info("exportAsPDF: starting for '\(title)', \(content.length) chars")

        let pageRect  = CGRect(x: 0, y: 0, width: 595.2, height: 841.8) // A4
        let margin: CGFloat = 40
        let printableRect = pageRect.insetBy(dx: margin, dy: margin + 20)

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
        // CoreText (CTFrameDraw) does not render image attachments, hence the empty PDF before.
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
    private static func normalizeForPDF(_ source: NSAttributedString) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: source)
        let fullRange = NSRange(location: 0, length: mutable.length)
        mutable.enumerateAttributes(in: fullRange, options: []) { attrs, range, _ in
            // Force all text to black so it's visible on a white page
            mutable.addAttribute(.foregroundColor, value: UIColor.black, range: range)
            // Remove dark background highlights — they'd appear as black blocks on white
            if let bg = attrs[.backgroundColor] as? UIColor {
                var white: CGFloat = 0
                bg.getWhite(&white, alpha: nil)
                if white < 0.5 { mutable.removeAttribute(.backgroundColor, range: range) }
            }
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
