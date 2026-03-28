import SwiftUI
import RichTextKit
import OSLog

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
                log.debug("NativeEditorView: UITextView ready")
                DispatchQueue.main.async { onEditorReady?(tv) }
            }
        }
        .background(Color(uiColor: .systemBackground))
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
