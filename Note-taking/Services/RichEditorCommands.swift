import UIKit
import RichTextKit
import OSLog

private let log = Logger(subsystem: "notes.Note-taking", category: "RichEditorCommands")

// MARK: - RichEditorCommands
// Centralised formatting commands for the native editor (Issues #39–#43).
// High-level style commands go through RichTextContext.
// Structural formatting (headings, blockquote, lists, tables) operates on the
// underlying UITextView via NSAttributedString mutations.

final class RichEditorCommands {

    // MARK: - Inline Formatting (#39) — via RichTextContext

    static func toggleBold(context: RichTextContext) {
        log.debug("toggleBold: toggling bold")
        context.toggleStyle(.bold)
    }

    static func toggleItalic(context: RichTextContext) {
        log.debug("toggleItalic: toggling italic")
        context.toggleStyle(.italic)
    }

    static func toggleUnderline(context: RichTextContext) {
        log.debug("toggleUnderline: toggling underline")
        context.toggleStyle(.underlined)
    }

    static func toggleStrikethrough(context: RichTextContext) {
        log.debug("toggleStrikethrough: toggling strikethrough")
        context.toggleStyle(.strikethrough)
    }

    // MARK: - Headings (#42) — via NSAttributedString + UITextView

    enum HeadingLevel {
        case h1, h2, h3, body

        var font: UIFont {
            switch self {
            case .h1: return UIFont.systemFont(ofSize: 22, weight: .bold)
            case .h2: return UIFont.systemFont(ofSize: 18, weight: .semibold)
            case .h3: return UIFont.systemFont(ofSize: 15, weight: .semibold)
            case .body: return UIFont.preferredFont(forTextStyle: .body)
            }
        }
    }

    static func applyHeading(_ level: HeadingLevel, attributedText: inout NSAttributedString, selectedRange: NSRange) {
        let mutable = attributedText.mutableCopy() as! NSMutableAttributedString
        let paragraphRange = (mutable.string as NSString).paragraphRange(for: selectedRange)

        // If already this heading, revert to body
        let existingFont = mutable.attribute(.font, at: paragraphRange.location, effectiveRange: nil) as? UIFont
        let targetFont = level.font
        let isAlready = existingFont?.pointSize == targetFont.pointSize
        let newFont = isAlready ? HeadingLevel.body.font : targetFont
        log.debug("applyHeading: level=\(String(describing: level)), toggling (isAlready=\(isAlready)), range=\(paragraphRange.location)-\(paragraphRange.length)")
        mutable.addAttribute(.font, value: newFont, range: paragraphRange)
        attributedText = mutable
    }

    // MARK: - Lists (#40)

    static func toggleBulletList(attributedText: inout NSAttributedString, selectedRange: NSRange) {
        let mutable = attributedText.mutableCopy() as! NSMutableAttributedString
        let paragraphRange = (mutable.string as NSString).paragraphRange(for: selectedRange)

        let existingStyle = mutable.attribute(.paragraphStyle, at: paragraphRange.location, effectiveRange: nil) as? NSParagraphStyle
        let hasList = (existingStyle?.textLists.isEmpty == false)
        log.debug("toggleBulletList: hasList=\(hasList), range=\(paragraphRange.location)-\(paragraphRange.length)")

        if hasList {
            let style = NSMutableParagraphStyle()
            mutable.addAttribute(.paragraphStyle, value: style, range: paragraphRange)
            log.debug("toggleBulletList: removed bullet list")
        } else {
            let list = NSTextList(markerFormat: .disc, options: 0)
            let style = NSMutableParagraphStyle()
            style.textLists = [list]
            style.firstLineHeadIndent = 15
            style.headIndent = 30
            mutable.addAttribute(.paragraphStyle, value: style, range: paragraphRange)
            log.debug("toggleBulletList: applied bullet list")
        }
        attributedText = mutable
    }

    static func applyBlockquote(attributedText: inout NSAttributedString, selectedRange: NSRange) {
        let mutable = attributedText.mutableCopy() as! NSMutableAttributedString
        let paragraphRange = (mutable.string as NSString).paragraphRange(for: selectedRange)
        log.debug("applyBlockquote: range=\(paragraphRange.location)-\(paragraphRange.length)")

        let style = NSMutableParagraphStyle()
        style.firstLineHeadIndent = 20
        style.headIndent = 20
        style.tailIndent = -20

        mutable.addAttribute(.paragraphStyle, value: style, range: paragraphRange)
        mutable.addAttribute(.foregroundColor, value: UIColor.secondaryLabel, range: paragraphRange)
        attributedText = mutable
    }

    // MARK: - To-do Checklists (#41)

    /// Insert a checklist item at the current cursor position
    static func insertChecklist(attributedText: inout NSAttributedString, cursorLocation: Int) {
        log.debug("insertChecklist: inserting at cursor=\(cursorLocation)")
        let mutable = attributedText.mutableCopy() as! NSMutableAttributedString
        let insertRange = NSRange(location: cursorLocation, length: 0)
        let item = NSAttributedString(
            string: "☐ ",
            attributes: [.font: UIFont.preferredFont(forTextStyle: .body)]
        )
        mutable.replaceCharacters(in: insertRange, with: item)
        attributedText = mutable
    }

    /// Toggle ☐/☑ on the line at the given location
    static func toggleCheckbox(at location: Int, attributedText: inout NSAttributedString) {
        let mutable = attributedText.mutableCopy() as! NSMutableAttributedString
        let str = mutable.string as NSString
        let lineRange = str.lineRange(for: NSRange(location: location, length: 0))
        let lineText = str.substring(with: lineRange)

        if lineText.hasPrefix("☐") {
            log.debug("toggleCheckbox: ☐ → ☑ at location=\(location)")
            mutable.replaceCharacters(in: NSRange(location: lineRange.location, length: 1), with: "☑")
        } else if lineText.hasPrefix("☑") {
            log.debug("toggleCheckbox: ☑ → ☐ at location=\(location)")
            mutable.replaceCharacters(in: NSRange(location: lineRange.location, length: 1), with: "☐")
        } else {
            log.debug("toggleCheckbox: no checkbox found at location=\(location)")
        }
        attributedText = mutable
    }

    // MARK: - Tables (#43)
    // NSTextTable/NSTextTableBlock are AppKit-only and unavailable on iOS.
    // On iOS, the correct approach is to build the table as HTML and convert it
    // to NSAttributedString — UIKit's HTML renderer preserves borders and the
    // header row background, and the result inserts cleanly into UITextView.

    static func insertTable(rows: Int, cols: Int, attributedText: inout NSAttributedString, cursorLocation: Int) {
        var html = "<table border='1' cellpadding='8' cellspacing='0' style='border-collapse:collapse;width:100%;font-family:-apple-system;font-size:15px;'>"
        for row in 0..<rows {
            html += "<tr>"
            for _ in 0..<cols {
                if row == 0 {
                    html += "<th style='background:#f2f2f7;font-weight:600;'>&nbsp;&nbsp;&nbsp;&nbsp;</th>"
                } else {
                    html += "<td>&nbsp;&nbsp;&nbsp;&nbsp;</td>"
                }
            }
            html += "</tr>"
        }
        html += "</table><br>"

        guard
            let data = html.data(using: .utf8),
            let tableAttr = try? NSAttributedString(
                data: data,
                options: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue
                ],
                documentAttributes: nil
            )
        else {
            log.error("insertTable: failed to build HTML table attributed string")
            return
        }

        let mutable = attributedText.mutableCopy() as! NSMutableAttributedString
        let safeLocation = min(cursorLocation, mutable.length)
        mutable.insert(tableAttr, at: safeLocation)
        attributedText = mutable
        log.debug("insertTable: inserted \(rows)×\(cols) HTML table at position \(safeLocation)")
    }

    // MARK: - Alignment — via RichTextContext

    static func setAlignment(_ alignment: RichTextAlignment, context: RichTextContext) {
        log.debug("setAlignment: \(String(describing: alignment))")
        context.textAlignment = alignment
    }

    // MARK: - Color (#44)
    // Context-based setColor(.background) sets the entire UITextView background — not
    // what we want. Both methods now operate directly on NSAttributedString so the
    // attribute is applied only to the exact selected character range.

    /// Apply foreground (text) colour to the given range.
    /// Pass UIColor.label to remove a custom colour (restores default).
    static func applyTextColor(_ color: UIColor,
                               attributedText: inout NSAttributedString,
                               selectedRange: NSRange) {
        guard selectedRange.length > 0 else {
            log.debug("applyTextColor: skipped — no selection")
            return
        }
        let mutable = attributedText.mutableCopy() as! NSMutableAttributedString
        let safe = clamp(selectedRange, to: mutable.length)
        guard safe.length > 0 else { return }
        if color == .label {
            mutable.removeAttribute(.foregroundColor, range: safe)
        } else {
            mutable.addAttribute(.foregroundColor, value: color, range: safe)
        }
        attributedText = mutable
        log.debug("applyTextColor: applied \(color.description) to range \(safe.location)+\(safe.length)")
    }

    /// Apply background (highlight) colour to the given range.
    /// Pass UIColor.clear to remove the highlight.
    static func applyHighlightColor(_ color: UIColor,
                                    attributedText: inout NSAttributedString,
                                    selectedRange: NSRange) {
        guard selectedRange.length > 0 else {
            log.debug("applyHighlightColor: skipped — no selection")
            return
        }
        let mutable = attributedText.mutableCopy() as! NSMutableAttributedString
        let safe = clamp(selectedRange, to: mutable.length)
        guard safe.length > 0 else { return }
        if color == .clear {
            mutable.removeAttribute(.backgroundColor, range: safe)
        } else {
            mutable.addAttribute(.backgroundColor, value: color, range: safe)
        }
        attributedText = mutable
        log.debug("applyHighlightColor: applied \(color.description) to range \(safe.location)+\(safe.length)")
    }

    /// Clamp an NSRange so it never exceeds the string's actual length.
    private static func clamp(_ range: NSRange, to length: Int) -> NSRange {
        let loc = min(range.location, length)
        let len = min(range.length, length - loc)
        return NSRange(location: loc, length: max(0, len))
    }

    // Context-based text colour — used by slash commands to set the typing attribute
    // for future typed text (no text selection needed).
    static func applyTextColor(_ color: UIColor, context: RichTextContext) {
        log.debug("applyTextColor (typing attr): \(color.description)")
        context.setColor(.foreground, to: color)
    }

    // MARK: - Body text reset

    static func applyBodyText(attributedText: inout NSAttributedString, selectedRange: NSRange) {
        guard selectedRange.length > 0 else {
            log.debug("applyBodyText: skipped — no selection")
            return
        }
        let mutable = attributedText.mutableCopy() as! NSMutableAttributedString
        let paragraphRange = (mutable.string as NSString).paragraphRange(for: selectedRange)
        log.debug("applyBodyText: resetting paragraph at range=\(paragraphRange.location)-\(paragraphRange.length)")
        mutable.addAttribute(.font, value: UIFont.preferredFont(forTextStyle: .body), range: paragraphRange)
        mutable.removeAttribute(.paragraphStyle, range: paragraphRange)
        attributedText = mutable
    }
}
