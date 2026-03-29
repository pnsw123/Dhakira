import UIKit
import RichTextKit
import OSLog

private let log = Logger(subsystem: "notes.Note-taking", category: "RichEditorCommands")

// MARK: - CheckboxAttachment
// A typed NSTextAttachment subclass that renders an SF Symbol checkbox.
// Using a subclass lets us identify checkboxes by type (vs any other attachment)
// and toggle them without storing external state.
// The image uses .alwaysTemplate rendering so UITextView tints it with the
// paragraph's .foregroundColor attribute — automatically adapts to light/dark mode.

final class CheckboxAttachment: NSTextAttachment {
    private(set) var isChecked: Bool

    init(checked: Bool = false) {
        self.isChecked = checked
        super.init(data: nil, ofType: nil)
        refresh()
    }
    required init?(coder: NSCoder) { fatalError("CheckboxAttachment does not support NSCoding") }

    func toggle() { isChecked.toggle(); refresh() }

    private func refresh() {
        let name   = isChecked ? "checkmark.square.fill" : "square"
        let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        image  = UIImage(systemName: name, withConfiguration: config)?
                     .withRenderingMode(.alwaysTemplate)
        bounds = CGRect(x: 0, y: -3, width: 16, height: 16)
    }
}

// MARK: - EditorContext (Issue #50)
// Bundles UITextView + RichTextContext into one value — passed into the dispatcher.

struct EditorContext {
    let textView: UITextView
    let richTextContext: RichTextContext
    var selectedRange: NSRange { textView.selectedRange }
}

// MARK: - ToolbarCommand (Issue #50)
// Typed enum for all toolbar button IDs — replaces stringly-typed switch.

enum ToolbarCommand: String, CaseIterable {
    case bold            = "bold"
    case italic          = "italic"
    case underline       = "underline"
    case strikethrough   = "strikethrough"
    case alignLeft       = "text.alignleft"
    case alignCenter     = "text.aligncenter"
    case alignRight      = "text.alignright"
    case bulletList      = "list.bullet"
}

// MARK: - RichEditorCommandDispatcher (Issue #50)
// Single dispatch point for all toolbar formatting commands.
// Focus is restored unconditionally inside the dispatcher — callers need no refocusAndApply.

enum RichEditorCommandDispatcher {

    /// Dispatch a toolbar command. Focus is restored before the command runs.
    /// Returns the updated NSAttributedString when the command mutates it directly.
    @discardableResult
    static func dispatch(
        _ command: ToolbarCommand,
        context: inout EditorContext,
        attributedText: inout NSAttributedString
    ) -> NSAttributedString? {
        // Restore focus unconditionally — toolbar taps always steal first-responder
        let range = context.selectedRange
        context.textView.becomeFirstResponder()
        if range.length > 0 {
            context.textView.selectedRange = range
        }

        log.info("RichEditorCommandDispatcher.dispatch: \(command.rawValue)")

        switch command {
        case .bold:
            RichEditorCommands.toggleBold(context: context.richTextContext)
        case .italic:
            RichEditorCommands.toggleItalic(context: context.richTextContext)
        case .underline:
            RichEditorCommands.toggleUnderline(context: context.richTextContext)
        case .strikethrough:
            RichEditorCommands.toggleStrikethrough(context: context.richTextContext)
        case .alignLeft:
            RichEditorCommands.setAlignment(.left, context: context.richTextContext)
        case .alignCenter:
            RichEditorCommands.setAlignment(.center, context: context.richTextContext)
        case .alignRight:
            RichEditorCommands.setAlignment(.right, context: context.richTextContext)
        case .bulletList:
            RichEditorCommands.toggleBulletList(attributedText: &attributedText,
                                                selectedRange: range)
            return attributedText
        }
        return nil
    }
}

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

    // MARK: - Font Size (Increase / Decrease)

    /// Step font size up or down by 2pt. Min 10pt, no upper limit.
    static func stepFontSize(increase: Bool, attributedText: inout NSAttributedString, selectedRange: NSRange) {
        let step: CGFloat = 2
        let minSize: CGFloat = 10
        let mutable = attributedText.mutableCopy() as! NSMutableAttributedString
        let range: NSRange
        if selectedRange.length > 0 {
            range = selectedRange
        } else {
            range = (mutable.string as NSString).paragraphRange(for: selectedRange)
        }
        guard range.length > 0, range.location + range.length <= mutable.length else { return }

        mutable.enumerateAttribute(.font, in: range, options: []) { value, subRange, _ in
            let font = (value as? UIFont) ?? UIFont.preferredFont(forTextStyle: .body)
            let currentSize = font.pointSize
            let newSize = increase ? currentSize + step : max(minSize, currentSize - step)
            let newFont = UIFont(descriptor: font.fontDescriptor, size: newSize)
            mutable.addAttribute(.font, value: newFont, range: subRange)
        }
        attributedText = mutable
        log.debug("stepFontSize: \(increase ? "+" : "-")\(step)pt")
    }

    /// Legacy wrapper — kept for ToolbarCommand dispatcher compatibility.
    static func increaseFontSize(attributedText: inout NSAttributedString, selectedRange: NSRange) {
        stepFontSize(increase: true, attributedText: &attributedText, selectedRange: selectedRange)
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

        // attribute(_:at:) requires index < length — crashes with NSRangeException on empty string.
        // When text is empty after slash deletion, bail here; the caller sets typingAttributes
        // so the heading font applies as soon as the user starts typing.
        guard mutable.length > 0 else { return }

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
    // NSTextList is unreliable in UITextView (TextKit 1) on iOS — list markers
    // never render and can crash the layout engine.  We use a "• " text-prefix
    // approach instead: bullet is real text, wrapped lines hang-indent to align.

    static func toggleBulletList(attributedText: inout NSAttributedString, selectedRange: NSRange) {
        let mutable = attributedText.mutableCopy() as! NSMutableAttributedString
        guard mutable.length > 0 else { return }

        // Allow safeLoc == mutable.length so an insertion point past the last character
        // (e.g. cursor at end of string after a slash command deleted its text) maps to
        // the implicit empty paragraph at the end instead of to the previous paragraph's \n.
        let safeLoc = min(selectedRange.location, mutable.length)
        let parRange = (mutable.string as NSString).paragraphRange(
            for: NSRange(location: safeLoc, length: 0))
        // parRange.length == 0 is valid: it means an empty paragraph at end-of-string.
        guard parRange.location <= mutable.length else { return }

        let parText = (mutable.string as NSString).substring(with: parRange)
        let hasBullet = parText.hasPrefix("• ")
        log.debug("toggleBulletList: hasBullet=\(hasBullet), parRange=\(parRange.location)-\(parRange.length)")

        if hasBullet {
            // Remove "• " (2 UTF-16 code units) and clear hanging indent.
            let delRange = NSRange(location: parRange.location, length: 2)
            mutable.deleteCharacters(in: delRange)
            let cleared = NSRange(location: parRange.location,
                                  length: max(0, parRange.length - 2))
            if cleared.length > 0 {
                mutable.addAttribute(.paragraphStyle, value: NSMutableParagraphStyle(),
                                     range: cleared)
            }
            log.debug("toggleBulletList: removed bullet prefix")
        } else {
            // Insert "• " at the paragraph start with adaptive colour.
            let bullet = NSAttributedString(string: "• ", attributes: [
                .font:            UIFont.preferredFont(forTextStyle: .body),
                .foregroundColor: UIColor.label,
            ])
            mutable.insert(bullet, at: parRange.location)

            // Apply hanging indent so wrapped lines align under the text (not the bullet).
            let newLen = min(parRange.length + 2, mutable.length - parRange.location)
            if newLen > 0 {
                let hangStyle = NSMutableParagraphStyle()
                hangStyle.headIndent = 14           // aligns second+ lines under text after "• "
                mutable.addAttribute(.paragraphStyle, value: hangStyle,
                                     range: NSRange(location: parRange.location, length: newLen))
            }
            log.debug("toggleBulletList: inserted bullet prefix")
        }
        attributedText = mutable
    }

    // MARK: - Blockquote
    // Uses a "│ " (BOX DRAWINGS LIGHT VERTICAL + space) text prefix in the accent
    // colour as a visible left bar — no UITextView subclassing required.
    // Wrapped lines hang-indent to align under the quoted text.

    static func applyBlockquote(attributedText: inout NSAttributedString, selectedRange: NSRange) {
        let mutable = attributedText.mutableCopy() as! NSMutableAttributedString
        guard mutable.length > 0 else { return }

        // Same end-of-string fix as toggleBulletList: allow safeLoc == mutable.length.
        let safeLoc = min(selectedRange.location, mutable.length)
        let parRange = (mutable.string as NSString).paragraphRange(
            for: NSRange(location: safeLoc, length: 0))
        guard parRange.location <= mutable.length else { return }

        let parText = (mutable.string as NSString).substring(with: parRange)
        let hasBar  = parText.hasPrefix("│ ")
        log.debug("applyBlockquote: hasBar=\(hasBar), parRange=\(parRange.location)-\(parRange.length)")

        if hasBar {
            // Toggle off — remove "│ " (2 UTF-16 units) and clear style.
            let delRange = NSRange(location: parRange.location, length: 2)
            mutable.deleteCharacters(in: delRange)
            let cleared = NSRange(location: parRange.location,
                                  length: max(0, parRange.length - 2))
            if cleared.length > 0 {
                mutable.addAttribute(.paragraphStyle, value: NSMutableParagraphStyle(),
                                     range: cleared)
                mutable.removeAttribute(.foregroundColor, range: cleared)
            }
            log.debug("applyBlockquote: removed quote bar")
        } else {
            // Insert "│ " at paragraph start styled in the system accent colour.
            let bar = NSAttributedString(string: "│ ", attributes: [
                .font:            UIFont.preferredFont(forTextStyle: .body),
                .foregroundColor: UIColor.systemBlue,
            ])
            mutable.insert(bar, at: parRange.location)

            // Hang-indent wrapped lines so they start under the quoted text, not under "│".
            let newLen = min(parRange.length + 2, mutable.length - parRange.location)
            if newLen > 0 {
                let quoteStyle = NSMutableParagraphStyle()
                quoteStyle.headIndent  = 16
                quoteStyle.tailIndent  = -16
                mutable.addAttribute(.paragraphStyle, value: quoteStyle,
                                     range: NSRange(location: parRange.location, length: newLen))
            }
            log.debug("applyBlockquote: inserted quote bar")
        }
        attributedText = mutable
    }

    // MARK: - To-do Checklists (#41)
    // Uses CheckboxAttachment (SF Symbol) instead of Unicode glyphs so the checkbox
    // is correctly sized, tinted adaptively, and identifiable by type at tap time.

    /// Insert a CheckboxAttachment + space at cursorLocation.
    /// Returns the new cursor location (attachment char + space = +2).
    @discardableResult
    static func insertChecklist(attributedText: inout NSAttributedString, cursorLocation: Int) -> Int {
        let mutable     = attributedText.mutableCopy() as! NSMutableAttributedString
        let safeLocation = max(0, min(cursorLocation, mutable.length))
        log.debug("insertChecklist: inserting at \(safeLocation) (requested \(cursorLocation), length \(mutable.length))")

        let checkbox    = CheckboxAttachment(checked: false)
        let attachStr   = NSMutableAttributedString(attachment: checkbox)
        // Set foreground color on the attachment character so .alwaysTemplate
        // rendering picks up the adaptive colour in both light and dark mode.
        attachStr.addAttribute(.foregroundColor, value: UIColor.label,
                                range: NSRange(location: 0, length: attachStr.length))

        let space = NSAttributedString(string: " ", attributes: [
            .font:            UIFont.preferredFont(forTextStyle: .body),
            .foregroundColor: UIColor.label,
        ])
        attachStr.append(space)

        mutable.replaceCharacters(in: NSRange(location: safeLocation, length: 0), with: attachStr)
        attributedText = mutable
        return safeLocation + 2   // attachment U+FFFC (1) + space (1) = 2
    }

    /// Toggle the CheckboxAttachment on the line at the given tap location.
    static func toggleCheckbox(at location: Int, attributedText: inout NSAttributedString) {
        let mutable  = attributedText.mutableCopy() as! NSMutableAttributedString
        guard mutable.length > 0 else { return }
        let safeLoc  = max(0, min(location, mutable.length - 1))
        let lineRange = (mutable.string as NSString).lineRange(
            for: NSRange(location: safeLoc, length: 0))

        var found = false
        mutable.enumerateAttribute(.attachment, in: lineRange, options: []) { value, range, stop in
            guard let cb = value as? CheckboxAttachment else { return }
            cb.toggle()
            // Re-set the attribute to force UITextView to redraw the attachment.
            mutable.removeAttribute(.attachment, range: range)
            mutable.addAttribute(.attachment, value: cb, range: range)
            found = true
            stop.pointee = true
        }
        log.debug("toggleCheckbox: found=\(found) at location=\(location)")
        attributedText = mutable
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
        let mutable = attributedText.mutableCopy() as! NSMutableAttributedString
        // Use paragraph range so this works whether text is selected or just cursor-positioned
        let paragraphRange = (mutable.string as NSString).paragraphRange(for: selectedRange)
        guard paragraphRange.length > 0,
              paragraphRange.location + paragraphRange.length <= mutable.length else {
            log.debug("applyBodyText: skipped — empty paragraph range")
            return
        }
        log.debug("applyBodyText: resetting paragraph at range=\(paragraphRange.location)-\(paragraphRange.length)")
        mutable.addAttribute(.font, value: UIFont.preferredFont(forTextStyle: .body), range: paragraphRange)
        mutable.removeAttribute(.paragraphStyle, range: paragraphRange)
        attributedText = mutable
    }
}
