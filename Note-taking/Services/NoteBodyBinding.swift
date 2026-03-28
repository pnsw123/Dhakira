import Foundation
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

        switch NoteBodyCodec.decode(data) {
        case .success(let str):
            logger.info("NoteBodyBinding.load: loaded \(str.length) chars for task '\(task.title)'")
            attributedText = str
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
