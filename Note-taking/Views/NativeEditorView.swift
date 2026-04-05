import SwiftUI
import RichTextKit
import OSLog
import UniformTypeIdentifiers

private let log = Logger(subsystem: "notes.Note-taking", category: "NativeEditor")

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
            if let tv = view as? UITextView {
                // FIX: Force TextKit 1 at creation to avoid mid-selection freeze.
                // 5+ call sites use tv.layoutManager — if the switch happens lazily
                // during a layout pass (e.g. text selection), it deadlocks the UI.
                _ = tv.layoutManager
                log.debug("NativeEditorView: UITextView ready (TextKit 1 forced)")
                // Use adaptive .label color so text is visible in both light and dark mode.
                // Without this, UIKit defaults to black which disappears on dark backgrounds.
                tv.isScrollEnabled = true
                tv.textColor = .label
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
