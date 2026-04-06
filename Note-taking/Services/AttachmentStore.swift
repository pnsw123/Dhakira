import UIKit
import OSLog

/// File-based image storage. Images are saved as JPEG files in
/// Documents/Attachments/{taskId}/{attachmentId}.jpg
/// On save: also writes a copy to the App Group shared container (iCloud-backed).
/// On load: tries Documents first, falls back to App Group (survives reinstall).
final class AttachmentStore {
    static let shared = AttachmentStore()
    private let log = Logger(subsystem: "notes.Note-taking", category: "AttachmentStore")
    private let fileManager = FileManager.default
    private let suiteName = "group.com.prodnote.notetaking"

    private var baseDir: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Attachments")
    }

    /// App Group container — survives reinstall when iCloud Backup is enabled.
    private var groupBaseDir: URL? {
        fileManager.containerURL(forSecurityApplicationGroupIdentifier: suiteName)?
            .appendingPathComponent("Attachments")
    }

    /// Save image data to both Documents and App Group container.
    func save(imageData: Data, taskId: UUID) -> UUID {
        let attachmentId = UUID()

        // Save to Documents (primary, fast local access)
        let dir = baseDir.appendingPathComponent(taskId.uuidString)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("\(attachmentId.uuidString).jpg")
        do {
            try imageData.write(to: url)
            log.info("save: wrote \(imageData.count) bytes → \(url.lastPathComponent)")
        } catch {
            log.error("save: failed — \(error.localizedDescription)")
        }

        // Also save to App Group container (survives reinstall)
        if let groupDir = groupBaseDir?.appendingPathComponent(taskId.uuidString) {
            try? fileManager.createDirectory(at: groupDir, withIntermediateDirectories: true)
            let groupURL = groupDir.appendingPathComponent("\(attachmentId.uuidString).jpg")
            try? imageData.write(to: groupURL)
            log.debug("save: backed up to App Group container")
        }

        return attachmentId
    }

    /// Load image — tries Documents first, falls back to App Group after reinstall.
    func load(attachmentId: UUID, taskId: UUID) -> UIImage? {
        let localURL = baseDir
            .appendingPathComponent(taskId.uuidString)
            .appendingPathComponent("\(attachmentId.uuidString).jpg")

        // Try local Documents first (fast)
        if let data = try? Data(contentsOf: localURL) {
            return UIImage(data: data)
        }

        // Documents wiped (reinstall) — restore from App Group
        if let groupDir = groupBaseDir {
            let groupURL = groupDir
                .appendingPathComponent(taskId.uuidString)
                .appendingPathComponent("\(attachmentId.uuidString).jpg")
            if let data = try? Data(contentsOf: groupURL) {
                log.info("load: restored from App Group → \(attachmentId.uuidString)")
                // Re-cache to Documents for next time
                let dir = baseDir.appendingPathComponent(taskId.uuidString)
                try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
                try? data.write(to: localURL)
                return UIImage(data: data)
            }
        }

        log.debug("load: file not found — \(attachmentId.uuidString)")
        return nil
    }

    /// Delete a single attachment file from both locations.
    func delete(attachmentId: UUID, taskId: UUID) {
        let localURL = baseDir
            .appendingPathComponent(taskId.uuidString)
            .appendingPathComponent("\(attachmentId.uuidString).jpg")
        try? fileManager.removeItem(at: localURL)

        if let groupDir = groupBaseDir {
            let groupURL = groupDir
                .appendingPathComponent(taskId.uuidString)
                .appendingPathComponent("\(attachmentId.uuidString).jpg")
            try? fileManager.removeItem(at: groupURL)
        }
        log.debug("delete: \(attachmentId.uuidString)")
    }

    /// Delete all attachment files for a task from both locations.
    func deleteAll(taskId: UUID) {
        let dir = baseDir.appendingPathComponent(taskId.uuidString)
        try? fileManager.removeItem(at: dir)

        if let groupDir = groupBaseDir?.appendingPathComponent(taskId.uuidString) {
            try? fileManager.removeItem(at: groupDir)
        }
        log.info("deleteAll: removed attachments for task \(taskId.uuidString)")
    }
}
