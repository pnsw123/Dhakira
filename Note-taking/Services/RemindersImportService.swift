import EventKit
import SwiftData
import Foundation

final class RemindersImportService {
    private let eventStore = EKEventStore()

    func requestAccess() async -> Bool {
        do {
            return try await eventStore.requestFullAccessToReminders()
        } catch {
            return false
        }
    }

    func fetchNewReminders() async -> [EKReminder] {
        let hasAccess = await requestAccess()
        guard hasAccess else { return [] }

        let predicate = eventStore.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: nil,
            calendars: nil
        )

        return await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }
    }

    func importReminder(_ reminder: EKReminder, into context: ModelContext) -> TaskItem {
        let task = TaskItem(title: reminder.title ?? "Untitled")
        if let notes = reminder.notes {
            task.body = notes.data(using: .utf8)
        }
        context.insert(task)
        return task
    }

    func deleteReminder(_ reminder: EKReminder) {
        try? eventStore.remove(reminder, commit: true)
    }
}
