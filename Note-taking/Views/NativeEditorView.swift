import SwiftUI
import RichTextKit
import OSLog

private let log = Logger(subsystem: "notes.Note-taking", category: "NativeEditor")

// MARK: - NativeEditorView
// Thin SwiftUI wrapper around RichTextKit's RichTextEditor.
// Exposes the RichTextContext so parent views can issue formatting commands.
// Content is stored as NSAttributedString and serialised to/from RTF Data.

struct NativeEditorView: View {
    /// Two-way binding to the attributed string (RTF content)
    @Binding var attributedText: NSAttributedString
    /// Shared context — parent must hold onto this as @StateObject or pass it in
    @ObservedObject var context: RichTextContext

    var body: some View {
        RichTextEditor(
            text: $attributedText,
            context: context,
            format: .rtf
        )
        .background(Color(uiColor: .systemBackground))
        .onChange(of: attributedText) { _, _ in
            log.debug("NativeEditorView: text changed (\(attributedText.length) chars)")
        }
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
