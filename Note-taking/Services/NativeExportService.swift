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
        let printableWidth  = printableRect.width
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

        // Use TextKit 1 (NSLayoutManager + NSTextContainer) for manual page breaking
        // instead of UISimpleTextPrintFormatter which produces inconsistent page breaks
        // with only 2 lines on some pages (Issue #107).
        let textStorage = NSTextStorage(attributedString: full)
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)

        // Create one text container per page — TextKit fills them sequentially.
        var containers: [NSTextContainer] = []
        func addContainer() -> NSTextContainer {
            let tc = NSTextContainer(size: CGSize(width: printableWidth, height: printableHeight))
            tc.lineFragmentPadding = 0
            layoutManager.addTextContainer(tc)
            containers.append(tc)
            return tc
        }
        _ = addContainer()

        // Force layout so we know exactly how many containers are needed.
        layoutManager.ensureLayout(for: containers[0])
        // Keep adding containers until all glyphs are laid out.
        while layoutManager.glyphRange(for: containers.last!).upperBound < layoutManager.numberOfGlyphs {
            let tc = addContainer()
            layoutManager.ensureLayout(for: tc)
        }

        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, pageRect, nil)

        for (i, tc) in containers.enumerated() {
            UIGraphicsBeginPDFPage()
            let ctx = UIGraphicsGetCurrentContext()!
            ctx.saveGState()
            ctx.translateBy(x: printableRect.origin.x, y: printableRect.origin.y)

            let glyphRange = layoutManager.glyphRange(for: tc)
            layoutManager.drawBackground(forGlyphRange: glyphRange, at: .zero)
            layoutManager.drawGlyphs(forGlyphRange: glyphRange, at: .zero)

            // Draw continuous quote bars — the "│" glyph splits across lines,
            // so we draw a single blue rectangle spanning each contiguous quote block.
            let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
            let nsStr = textStorage.string as NSString
            var qLoc = charRange.location
            while qLoc < charRange.location + charRange.length {
                let parRange = nsStr.paragraphRange(for: NSRange(location: qLoc, length: 0))
                let parText = nsStr.substring(with: parRange)
                if parText.hasPrefix("│ ") || parText == "│" || parText == "│\n" {
                    // Find the end of this contiguous quote block
                    var blockEnd = parRange.location + parRange.length
                    while blockEnd < charRange.location + charRange.length {
                        let nextPar = nsStr.paragraphRange(for: NSRange(location: blockEnd, length: 0))
                        let nextText = nsStr.substring(with: nextPar)
                        guard nextText.hasPrefix("│ ") || nextText == "│" || nextText == "│\n" else { break }
                        blockEnd = nextPar.location + nextPar.length
                    }
                    // Draw one continuous bar for the whole block
                    let blockRange = NSRange(location: parRange.location, length: blockEnd - parRange.location)
                    let blockGlyphs = layoutManager.glyphRange(forCharacterRange: blockRange, actualCharacterRange: nil)
                    let blockRect = layoutManager.boundingRect(forGlyphRange: blockGlyphs, in: tc)
                    let barRect = CGRect(x: 4, y: blockRect.minY, width: 3, height: blockRect.height)
                    UIColor.systemBlue.setFill()
                    UIBezierPath(roundedRect: barRect, cornerRadius: 1.5).fill()
                    qLoc = blockEnd
                } else {
                    let next = parRange.location + parRange.length
                    if next <= qLoc { break }
                    qLoc = next
                }
            }

            ctx.restoreGState()

            // Overlay PKDrawing if present
            if let drawing, !drawing.strokes.isEmpty {
                let bounds = drawing.bounds
                let drawingScale = min(printableWidth / max(bounds.width, 1), 1.0)
                let drawingTopInDoc = bounds.origin.y * drawingScale
                let drawingPage = Int(drawingTopInDoc / printableHeight)

                if i == drawingPage {
                    let drawingImage = drawing.image(from: bounds, scale: 2.0)
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
    /// Testable entry point — same as normalizeForPDF but accessible from test target.
    static func normalizeForPDFTestable(_ source: NSAttributedString) -> NSAttributedString {
        normalizeForPDF(source)
    }

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
            if let symbolImg = UIImage(systemName: symbolName, withConfiguration: config),
               let img = renderSymbolToBitmap(symbolImg, color: .black) {
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

        // Pass 2: Normalize colors for print — dark-mode adaptive colors become
        // invisible on white paper. Preserve explicitly chosen custom colors
        // (red, blue, highlights, etc.) — only replace adaptive/theme colors.
        let updatedRange = NSRange(location: 0, length: mutable.length)
        mutable.enumerateAttributes(in: updatedRange, options: []) { attrs, range, _ in
            // Foreground: preserve custom colors, convert adaptive ones to black
            if let fg = attrs[.foregroundColor] as? UIColor {
                if isAdaptiveColor(fg) {
                    mutable.addAttribute(.foregroundColor, value: UIColor.black, range: range)
                }
                // Custom colors (red, blue, etc.) are kept as-is
            } else {
                // No foreground color set — default to black for print
                mutable.addAttribute(.foregroundColor, value: UIColor.black, range: range)
            }
            // Background: remove only dark backgrounds (invisible on white paper).
            // Keep light-colored highlights (yellow, pink, etc.) for print.
            if let bg = attrs[.backgroundColor] as? UIColor {
                var white: CGFloat = 0
                bg.getWhite(&white, alpha: nil)
                if white < 0.3 {
                    mutable.removeAttribute(.backgroundColor, range: range)
                }
            }
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
                // Hide the │ glyph — the continuous bar is drawn in the PDF render pass
                let barRange = NSRange(location: parRange.location, length: 1)
                mutable.addAttribute(.foregroundColor, value: UIColor.clear, range: barRange)
                // Ensure quote text has proper indentation in PDF
                let style = NSMutableParagraphStyle()
                style.headIndent = 18
                style.firstLineHeadIndent = 0
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

    /// Renders an SF Symbol into a flat bitmap image so it exports correctly
    /// in PDF contexts. SF Symbols in template mode get filled solid by the
    /// PDF renderer — rasterizing them first avoids that.
    private static func renderSymbolToBitmap(_ symbol: UIImage, color: UIColor) -> UIImage? {
        let size = symbol.size
        let renderer = UIGraphicsImageRenderer(size: size)
        let rendered = renderer.image { ctx in
            color.setFill()
            symbol.withRenderingMode(.alwaysTemplate).draw(in: CGRect(origin: .zero, size: size))
        }
        return rendered.withRenderingMode(.alwaysOriginal)
    }

    /// Returns true if the color is an adaptive/theme color that changes between
    /// light and dark mode (e.g. UIColor.label, .secondaryLabel, .primaryText).
    /// These must be replaced with static black for PDF export on white paper.
    /// Custom colors (red, blue, green, etc.) return false and are preserved.
    private static func isAdaptiveColor(_ color: UIColor) -> Bool {
        // Resolve the color in both light and dark traits.
        // Adaptive colors produce different RGB values; static colors stay the same.
        let lightTraits = UITraitCollection(userInterfaceStyle: .light)
        let darkTraits  = UITraitCollection(userInterfaceStyle: .dark)
        let lightResolved = color.resolvedColor(with: lightTraits)
        let darkResolved  = color.resolvedColor(with: darkTraits)
        var lr: CGFloat = 0, lg: CGFloat = 0, lb: CGFloat = 0, la: CGFloat = 0
        var dr: CGFloat = 0, dg: CGFloat = 0, db: CGFloat = 0, da: CGFloat = 0
        lightResolved.getRed(&lr, green: &lg, blue: &lb, alpha: &la)
        darkResolved.getRed(&dr, green: &dg, blue: &db, alpha: &da)
        // If the color differs between light and dark mode, it's adaptive
        let diff = abs(lr - dr) + abs(lg - dg) + abs(lb - db)
        return diff > 0.1
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
