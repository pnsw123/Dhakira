import UIKit
import OSLog

/// File-based image storage. Images are saved as JPEG files in
/// Documents/Attachments/{taskId}/{attachmentId}.jpg
/// RTF body stores only text placeholders like [img:UUID].
final class AttachmentStore {
    static let shared = AttachmentStore()
    private let log = Logger(subsystem: "notes.Note-taking", category: "AttachmentStore")
    private let fileManager = FileManager.default

    private var baseDir: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Attachments")
    }

    /// Save image data to disk. Returns the attachment UUID.
    func save(imageData: Data, taskId: UUID) -> UUID {
        let attachmentId = UUID()
        let dir = baseDir.appendingPathComponent(taskId.uuidString)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("\(attachmentId.uuidString).jpg")
        do {
            try imageData.write(to: url)
            log.info("save: wrote \(imageData.count) bytes → \(url.lastPathComponent)")
        } catch {
            log.error("save: failed — \(error.localizedDescription)")
        }
        return attachmentId
    }

    /// Load image from disk by attachment UUID and task UUID.
    func load(attachmentId: UUID, taskId: UUID) -> UIImage? {
        let url = baseDir
            .appendingPathComponent(taskId.uuidString)
            .appendingPathComponent("\(attachmentId.uuidString).jpg")
        guard let data = try? Data(contentsOf: url) else {
            log.debug("load: file not found — \(attachmentId.uuidString)")
            return nil
        }
        return UIImage(data: data)
    }

    /// Delete a single attachment file.
    func delete(attachmentId: UUID, taskId: UUID) {
        let url = baseDir
            .appendingPathComponent(taskId.uuidString)
            .appendingPathComponent("\(attachmentId.uuidString).jpg")
        try? fileManager.removeItem(at: url)
        log.debug("delete: \(attachmentId.uuidString)")
    }

    /// Delete all attachment files for a task.
    func deleteAll(taskId: UUID) {
        let dir = baseDir.appendingPathComponent(taskId.uuidString)
        try? fileManager.removeItem(at: dir)
        log.info("deleteAll: removed attachments for task \(taskId.uuidString)")
    }
}
