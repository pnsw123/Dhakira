import EventKit
import SwiftData
import Foundation
import OSLog
import UIKit

private let log = Logger(subsystem: "notes.Note-taking", category: "RemindersImport")

final class RemindersImportService {
    private let eventStore = EKEventStore()

    func requestAccess() async -> Bool {
        log.info("requestAccess: requesting full reminders access")
        do {
            let granted = try await eventStore.requestFullAccessToReminders()
            log.info("requestAccess: access \(granted ? "granted" : "denied")")
            return granted
        } catch {
            log.error("requestAccess: failed — \(error.localizedDescription)")
            return false
        }
    }

    func fetchNewReminders() async -> [EKReminder] {
        log.info("fetchNewReminders: starting fetch")
        let hasAccess = await requestAccess()
        guard hasAccess else {
            log.warning("fetchNewReminders: no reminders access — returning empty list")
            return []
        }

        let predicate = eventStore.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: nil,
            calendars: nil
        )

        return await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                let result = reminders ?? []
                log.info("fetchNewReminders: fetched \(result.count) incomplete reminder(s)")
                continuation.resume(returning: result)
            }
        }
    }

    func importReminder(_ reminder: EKReminder, into context: ModelContext) -> TaskItem {
        let taskTitle = reminder.title ?? "Untitled"
        log.info("importReminder: importing '\(taskTitle)' (hasNotes=\(reminder.notes != nil))")
        let task = TaskItem(title: taskTitle)
        if let notes = reminder.notes {
            let attrStr = NSAttributedString(string: notes)
            let range = NSRange(location: 0, length: attrStr.length)
            task.body = try? attrStr.data(
                from: range,
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
            )
            log.debug("importReminder: attached \(notes.count) char note body as RTF")
        }
        context.insert(task)
        log.info("importReminder: inserted task for reminder '\(taskTitle)'")
        return task
    }

    func deleteReminder(_ reminder: EKReminder) {
        let title = reminder.title ?? "Untitled"
        log.info("deleteReminder: removing '\(title)' from EventKit")
        do {
            try eventStore.remove(reminder, commit: true)
            log.info("deleteReminder: '\(title)' removed successfully")
        } catch {
            log.error("deleteReminder: failed to remove '\(title)' — \(error.localizedDescription)")
        }
    }
}
