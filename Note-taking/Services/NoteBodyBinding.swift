import Foundation
import UIKit
import OSLog

private let log = Logger(subsystem: "notes.Note-taking", category: "NoteBodyBinding")

// MARK: - NoteBodyBinding (Issue #53)
// View-layer convenience that wraps NoteBodyCodec and pre-answers all error handling decisions.
// Callers pass optional callbacks for load/save errors — the callbacks drive SwiftUI alerts.

@MainActor
struct NoteBodyBinding {

    // MARK: Load

    /// Load body from `task.body` into `attributedText`.
    /// - If `task.body` is nil → leaves `attributedText` unchanged (empty).
    /// - If decode fails → calls `onLoadError` with the typed error (drives an alert).
    static func load(
        from task: TaskItem,
        into attributedText: inout NSAttributedString,
        onLoadError: ((NoteBodyError) -> Void)? = nil
    ) {
        let logger = Logger(subsystem: "notes.Note-taking", category: "NoteBodyBinding")
        guard let data = task.body else {
            logger.info("NoteBodyBinding.load: no body for task '\(task.title)'")
            return
        }

        switch NoteBodyCodec.decode(data, taskId: task.id) {
        case .success(let str):
            logger.info("NoteBodyBinding.load: loaded \(str.length) chars for task '\(task.title)'")
            // RTF hardcodes black as the default text color. Strip it so the text view's
            // adaptive .label color takes over — otherwise text is invisible in dark mode.
            attributedText = str.removingRTFDefaultBlack()
        case .failure(let error):
            logger.error("NoteBodyBinding.load: decode failed for task '\(task.title)' — \(error.localizedDescription)")
            onLoadError?(error)
            // Do NOT overwrite attributedText — stale data is better than a blank editor
        }
    }

    // MARK: Save

    /// Save `attributedText` into `task.body`.
    /// - If text is whitespace-only → clears `task.body`.
    /// - If encode fails → calls `onSaveError` with the typed error and does NOT overwrite `task.body`.
    static func save(
        _ attributedText: NSAttributedString,
        into task: TaskItem,
        onSaveError: ((NoteBodyError) -> Void)? = nil
    ) {
        let logger = Logger(subsystem: "notes.Note-taking", category: "NoteBodyBinding")
        let trimmed = attributedText.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            logger.info("NoteBodyBinding.save: empty — clearing body for task '\(task.title)'")
            task.body = nil
            return
        }

        switch NoteBodyCodec.encode(attributedText) {
        case .success(let data):
            logger.info("NoteBodyBinding.save: saved \(data.count) bytes for task '\(task.title)'")
            task.body = data
        case .failure(let error):
            logger.error("NoteBodyBinding.save: encode failed for task '\(task.title)' — \(error.localizedDescription)")
            onSaveError?(error)
            // Do NOT overwrite task.body — preserve the last good save
        }
    }
}

// MARK: - Dark-mode RTF color fix

private extension NSAttributedString {
    /// RTF always encodes a default foreground color (black: r≈0, g≈0, b≈0).
    /// In dark mode that makes all text invisible. This strips any near-black
    /// foreground color so the UITextView's adaptive `.label` color shows through.
    /// Intentional user colors (red, blue, etc.) are left untouched.
    func removingRTFDefaultBlack() -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: self)
        let fullRange = NSRange(location: 0, length: mutable.length)
        mutable.enumerateAttribute(.foregroundColor, in: fullRange, options: []) { value, range, _ in
            guard let color = value as? UIColor else { return }
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: &a)
            if r < 0.15 && g < 0.15 && b < 0.15 && a > 0.9 {
                // Replace RTF-hardcoded black with the adaptive .label color so text
                // is visible on both light and dark/themed backgrounds.
                // Removing the attribute entirely causes UIKit to reset textColor to
                // black when attributedText is set, making text invisible in dark mode.
                mutable.addAttribute(.foregroundColor, value: UIColor.label, range: range)
            }
        }
        return mutable
    }
}
