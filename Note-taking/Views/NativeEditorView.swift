import SwiftUI
import RichTextKit
import OSLog
import UniformTypeIdentifiers

private let log = Logger(subsystem: "notes.Note-taking", category: "NativeEditor")

// MARK: - HighlightLayoutManagerDelegate
// NSLayoutManagerDelegate that fixes background highlight gaps between lines
// by expanding each line's fragment rect to cover inter-line spacing.
// Uses the safe delegate pattern — never replaces or modifies the layout manager itself.

final class HighlightLayoutManagerDelegate: NSObject, NSLayoutManagerDelegate {
    static let shared = HighlightLayoutManagerDelegate()

    /// Expand the line fragment rect slightly to close gaps between highlighted lines.
    /// Without this, .backgroundColor only covers the glyph area, leaving visible
    /// gaps where the dark editor background shows through.
    func layoutManager(
        _ layoutManager: NSLayoutManager,
        shouldSetLineFragmentRect lineFragmentRect: UnsafeMutablePointer<CGRect>,
        lineFragmentUsedRect: UnsafeMutablePointer<CGRect>,
        baselineOffset: UnsafeMutablePointer<CGFloat>,
        in textContainer: NSTextContainer,
        forGlyphRange glyphRange: NSRange
    ) -> Bool {
        // Extend the used rect height to cover inter-line spacing
        var used = lineFragmentUsedRect.pointee
        used.size.height = lineFragmentRect.pointee.size.height
        lineFragmentUsedRect.pointee = used
        return true
    }
}

// MARK: - NativeEditorView
// Thin SwiftUI wrapper around RichTextKit's RichTextEditor.
// Exposes the underlying UITextView via onEditorReady so the parent
// can manage focus (becomeFirstResponder / resignFirstResponder)
// before issuing formatting commands — without this, tapping a
// toolbar button causes the text view to lose focus and the formatting
// action lands on an empty {0,0} selection and does nothing.

struct NativeEditorView: View {
    @Binding var attributedText: NSAttributedString
    @ObservedObject var context: RichTextContext
    /// Fires once when the underlying UITextView is ready.
    /// Store the reference to call becomeFirstResponder() before formatting commands.
    var onEditorReady: ((UITextView) -> Void)?

    var body: some View {
        RichTextEditor(
            text: $attributedText,
            context: context,
            format: .rtf
        ) { view in
            // viewConfiguration fires once inside makeUIView — safe to capture here.
            if let richTV = view as? RichTextView {
                // Override RichTextKit's default theme font (16pt) to match
                // the body font (17pt) used everywhere in this app.
                richTV.theme = RichTextView.Theme(
                    font: UIFont.preferredFont(forTextStyle: .body),
                    fontColor: .label,
                    backgroundColor: .clear
                )
            }
            if let tv = view as? UITextView {
                // FIX: Force TextKit 1 at creation to avoid mid-selection freeze.
                // 5+ call sites use tv.layoutManager — if the switch happens lazily
                // during a layout pass (e.g. text selection), it deadlocks the UI.
                _ = tv.layoutManager
                log.debug("NativeEditorView: UITextView ready (TextKit 1 forced)")

                // Use the layout manager's delegate for custom drawing instead of
                // swapping/upgrading the class — avoids breaking UITextView's internal
                // selection and scroll calculations.
                tv.layoutManager.delegate = HighlightLayoutManagerDelegate.shared
                log.debug("NativeEditorView: set HighlightLayoutManagerDelegate")
                // Use adaptive .label color so text is visible in both light and dark mode.
                // Without this, UIKit defaults to black which disappears on dark backgrounds.
                tv.isScrollEnabled = true
                tv.textColor = .label
                tv.font = UIFont.preferredFont(forTextStyle: .body)
                tv.typingAttributes[.font] = UIFont.preferredFont(forTextStyle: .body)
                tv.typingAttributes[.foregroundColor] = UIColor.label
                // Match the editor area background to the active theme so bright / dark
                // themes don't leave a system-white or system-black rectangle behind.
                // Clear background lets withEditorBackground() fill the screen
                // uniformly — no visible seam between the header and editor area.
                tv.backgroundColor = .clear
                DispatchQueue.main.async { onEditorReady?(tv) }
            }
        }
        .padding(.horizontal, 16)
        .background(Color.clear)
    }
}

// MARK: - RTF Data helpers (used by TaskDetailView for save/load)

extension NSAttributedString {
    /// Serialise to RTF Data. Returns nil if conversion fails.
    func rtfData() -> Data? {
        let range = NSRange(location: 0, length: length)
        return try? data(
            from: range,
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )
    }
}

extension Data {
    /// Deserialise from RTF Data into NSAttributedString. Returns nil if conversion fails.
    func attributedStringFromRTF() -> NSAttributedString? {
        try? NSAttributedString(
            data: self,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        )
    }
}
