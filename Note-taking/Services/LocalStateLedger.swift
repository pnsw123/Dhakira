import Foundation
import OSLog

/// Tracks task UUIDs that the user explicitly deleted or completed.
/// Survives CloudKit overwrite because it lives in standard UserDefaults (not SwiftData).
/// When CloudKit restores a task the user already deleted, the app re-deletes it.
final class LocalStateLedger {
    static let shared = LocalStateLedger()
    private let log = Logger(subsystem: "notes.Note-taking", category: "LocalStateLedger")

    private let deletedKey = "ledger.deletedTaskIds"
    private let completedKey = "ledger.completedTaskIds"

    // MARK: - Deleted tasks

    func markDeleted(_ id: UUID) {
        var ids = deletedIds
        ids.insert(id.uuidString)
        UserDefaults.standard.set(Array(ids), forKey: deletedKey)
        log.debug("markDeleted: \(id.uuidString)")
    }

    func unmarkDeleted(_ id: UUID) {
        var ids = deletedIds
        ids.remove(id.uuidString)
        UserDefaults.standard.set(Array(ids), forKey: deletedKey)
        log.debug("unmarkDeleted: \(id.uuidString)")
    }

    func isMarkedDeleted(_ id: UUID) -> Bool {
        deletedIds.contains(id.uuidString)
    }

    private var deletedIds: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: deletedKey) ?? [])
    }

    // MARK: - Completed tasks

    func markCompleted(_ id: UUID) {
        var ids = completedIds
        ids.insert(id.uuidString)
        UserDefaults.standard.set(Array(ids), forKey: completedKey)
        log.debug("markCompleted: \(id.uuidString)")
    }

    func unmarkCompleted(_ id: UUID) {
        var ids = completedIds
        ids.remove(id.uuidString)
        UserDefaults.standard.set(Array(ids), forKey: completedKey)
        log.debug("unmarkCompleted: \(id.uuidString)")
    }

    func isMarkedCompleted(_ id: UUID) -> Bool {
        completedIds.contains(id.uuidString)
    }

    private var completedIds: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: completedKey) ?? [])
    }

    // MARK: - Cleanup (call when task is permanently deleted)

    func purge(_ id: UUID) {
        unmarkDeleted(id)
        unmarkCompleted(id)
    }
}
