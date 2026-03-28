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
        context.toggleStyle(.bold)
    }

    static func toggleItalic(context: RichTextContext) {
        context.toggleStyle(.italic)
    }

    static func toggleUnderline(context: RichTextContext) {
        context.toggleStyle(.underlined)
    }

    static func toggleStrikethrough(context: RichTextContext) {
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
        mutable.addAttribute(.font, value: newFont, range: paragraphRange)
        attributedText = mutable
    }

    // MARK: - Lists (#40)

    static func toggleBulletList(attributedText: inout NSAttributedString, selectedRange: NSRange) {
        let mutable = attributedText.mutableCopy() as! NSMutableAttributedString
        let paragraphRange = (mutable.string as NSString).paragraphRange(for: selectedRange)

        let existingStyle = mutable.attribute(.paragraphStyle, at: paragraphRange.location, effectiveRange: nil) as? NSParagraphStyle
        let hasList = (existingStyle?.textLists.isEmpty == false)

        if hasList {
            let style = NSMutableParagraphStyle()
            mutable.addAttribute(.paragraphStyle, value: style, range: paragraphRange)
        } else {
            let list = NSTextList(markerFormat: .disc, options: 0)
            let style = NSMutableParagraphStyle()
            style.textLists = [list]
            style.firstLineHeadIndent = 15
            style.headIndent = 30
            mutable.addAttribute(.paragraphStyle, value: style, range: paragraphRange)
        }
        attributedText = mutable
    }

    static func applyBlockquote(attributedText: inout NSAttributedString, selectedRange: NSRange) {
        let mutable = attributedText.mutableCopy() as! NSMutableAttributedString
        let paragraphRange = (mutable.string as NSString).paragraphRange(for: selectedRange)

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
            mutable.replaceCharacters(in: NSRange(location: lineRange.location, length: 1), with: "☑")
        } else if lineText.hasPrefix("☑") {
            mutable.replaceCharacters(in: NSRange(location: lineRange.location, length: 1), with: "☐")
        }
        attributedText = mutable
    }

    // MARK: - Tables (#43)

    static func insertTable(rows: Int, cols: Int, attributedText: inout NSAttributedString, cursorLocation: Int) {
        let mutable = attributedText.mutableCopy() as! NSMutableAttributedString
        let table = NSTextTable()
        table.numberOfColumns = cols
        table.setContentWidth(300, type: .absoluteValueType)

        var tableStr = NSMutableAttributedString()
        for row in 0..<rows {
            for col in 0..<cols {
                let block = NSTextTableBlock(
                    table: table, startingRow: row, rowSpan: 1,
                    startingColumn: col, columnSpan: 1
                )
                block.setContentWidth(300.0 / CGFloat(cols), type: .absoluteValueType)
                block.backgroundColor = (row == 0) ? UIColor.systemGray5 : UIColor.clear
                block.setBorderColor(.separator, for: .minX)
                block.setBorderColor(.separator, for: .maxX)
                block.setBorderColor(.separator, for: .minY)
                block.setBorderColor(.separator, for: .maxY)
                block.setWidth(0.5, type: .absoluteValueType, for: .minX)
                block.setWidth(0.5, type: .absoluteValueType, for: .maxX)
                block.setWidth(0.5, type: .absoluteValueType, for: .minY)
                block.setWidth(0.5, type: .absoluteValueType, for: .maxY)

                let cellStyle = NSMutableParagraphStyle()
                cellStyle.textBlocks = [block]

                let cellFont: UIFont = (row == 0)
                    ? UIFont.systemFont(ofSize: 14, weight: .semibold)
                    : UIFont.preferredFont(forTextStyle: .body)

                let cell = NSMutableAttributedString(
                    string: "\t\n",
                    attributes: [
                        .paragraphStyle: cellStyle,
                        .font: cellFont
                    ]
                )
                tableStr.append(cell)
            }
        }

        mutable.insert(tableStr, at: cursorLocation)
        attributedText = mutable
    }

    // MARK: - Color (#44) — via RichTextContext

    static func applyTextColor(_ color: UIColor, context: RichTextContext) {
        context.setColor(.foreground, to: color)
    }

    static func applyHighlightColor(_ color: UIColor, context: RichTextContext) {
        context.setColor(.background, to: color)
    }

    // MARK: - Body text reset

    static func applyBodyText(attributedText: inout NSAttributedString, selectedRange: NSRange) {
        guard selectedRange.length > 0 else { return }
        let mutable = attributedText.mutableCopy() as! NSMutableAttributedString
        let paragraphRange = (mutable.string as NSString).paragraphRange(for: selectedRange)
        mutable.addAttribute(.font, value: UIFont.preferredFont(forTextStyle: .body), range: paragraphRange)
        mutable.removeAttribute(.paragraphStyle, range: paragraphRange)
        attributedText = mutable
    }
}

