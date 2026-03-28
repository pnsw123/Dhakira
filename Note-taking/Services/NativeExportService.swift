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

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842)) // A4

        let data = renderer.pdfData { ctx in
            ctx.beginPage()
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 20, weight: .bold),
                .foregroundColor: UIColor.label
            ]
            let titleStr = NSAttributedString(string: title, attributes: titleAttrs)

            let margin: CGFloat = 40
            let pageWidth = ctx.pdfContextBounds.width - margin * 2
            let pageHeight = ctx.pdfContextBounds.height - margin * 2

            var yOffset: CGFloat = margin

            // Draw title
            let titleSize = titleStr.boundingRect(
                with: CGSize(width: pageWidth, height: .greatestFiniteMagnitude),
                options: .usesLineFragmentOrigin,
                context: nil
            )
            titleStr.draw(in: CGRect(x: margin, y: yOffset, width: pageWidth, height: titleSize.height))
            yOffset += titleSize.height + 12

            // Divider
            UIColor.separator.setStroke()
            let path = UIBezierPath()
            path.move(to: CGPoint(x: margin, y: yOffset))
            path.addLine(to: CGPoint(x: margin + pageWidth, y: yOffset))
            path.lineWidth = 0.5
            path.stroke()
            yOffset += 12

            // Body content
            let framesetter = CTFramesetterCreateWithAttributedString(content)
            let remainingHeight = pageHeight - yOffset + margin
            let bodyRect = CGRect(x: margin, y: yOffset, width: pageWidth, height: remainingHeight)
            let path2 = CGPath(rect: bodyRect, transform: nil)
            let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), path2, nil)

            let cgCtx = ctx.cgContext
            cgCtx.saveGState()
            // Flip coordinate system for CoreText
            cgCtx.translateBy(x: 0, y: ctx.pdfContextBounds.height)
            cgCtx.scaleBy(x: 1, y: -1)
            let flippedRect = CGRect(x: margin, y: ctx.pdfContextBounds.height - yOffset - remainingHeight, width: pageWidth, height: remainingHeight)
            let flippedPath = CGPath(rect: flippedRect, transform: nil)
            let flippedFrame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), flippedPath, nil)
            CTFrameDraw(flippedFrame, cgCtx)
            cgCtx.restoreGState()
        }

        let fileName = sanitizeFilename(title.isEmpty ? "Note" : title) + ".pdf"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: tempURL)
            log.info("exportAsPDF: written \(data.count) bytes to \(tempURL.lastPathComponent)")
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
        full.append(content)

        guard let data = full.rtfData() else {
            log.error("exportAsRTF: RTF conversion failed")
            return
        }

        let fileName = sanitizeFilename(title.isEmpty ? "Note" : title) + ".rtf"
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
        let plainText = content.string
        let shareText = title.isEmpty ? plainText : "\(title)\n\n\(plainText)"
        presentShareSheet(items: [shareText], from: viewController)
    }

    // MARK: - Helpers

    private static func sanitizeFilename(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:*?\"<>|")
        return name.components(separatedBy: invalid).joined(separator: "_")
    }

    static func presentShareSheet(items: [Any], from viewController: UIViewController) {
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        vc.modalPresentationStyle = .formSheet
        viewController.present(vc, animated: true)
    }
}
#endif
