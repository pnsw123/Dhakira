import EventKit
import Foundation
import OSLog
import SwiftData

private let log = Logger(subsystem: "notes.Note-taking", category: "BodyEventSync")

/// Syncs body-line dates to Apple Calendar as individual events.
/// Entry point: `sync(bodyText:task:context:)` — called on save, Enter+debounce, and background.
///
/// Diffing strategy:
/// - New date line → create Apple Calendar event + store BodyCalendarEvent record
/// - Changed line (fuzzy match ≥ 80%) → update existing event
/// - Deleted/dateless line → delete event + record
/// - Max 15 body events per task
final class BodyEventSyncService {

    static let shared = BodyEventSyncService()

    /// Maximum body-line events allowed per task.
    private let maxEventsPerTask = 15

    private let calendarSync = CalendarSyncService.shared
    private let detector = DateDetectionService()

    // MARK: - Public API

    /// Scans ALL body lines, diffs against stored BodyCalendarEvent records,
    /// and creates/updates/deletes Apple Calendar events accordingly.
    ///
    /// - Parameters:
    ///   - bodyText: Plain text of the body (rich text stripped).
    ///   - task: The owning TaskItem.
    ///   - context: SwiftData ModelContext for reading/writing BodyCalendarEvent records.
    @MainActor
    func sync(bodyText: String, task: TaskItem, context: ModelContext) async {
        let taskId = task.id
        let taskTitle = task.title
        log.info("sync: starting for task '\(taskTitle)' id=\(taskId)")

        // 1. Split body into lines, skip empty and attachment-only lines.
        let lines = bodyText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.allSatisfy({ $0 == "\u{FFFC}" }) }

        // 2. Detect dates per line.
        let cal = Calendar.current
        let now = Date()
        var datedLines: [(text: String, date: DetectedDate)] = []
        for line in lines {
            let detected = detector.detectDates(in: line)
            // Take the first relevant (today or future) date per line.
            if let best = detected.first(where: { $0.date > now || cal.isDateInToday($0.date) }) {
                datedLines.append((text: line, date: best))
            }
        }

        // 3. Fetch existing records for this task.
        let existing = (task.bodyCalendarEvents ?? []).sorted { $0.createdAt < $1.createdAt }
        log.info("sync: \(datedLines.count) dated lines, \(existing.count) existing records")

        // 4. Diff: match existing records to current lines via fuzzy match.
        var matched: Set<UUID> = []       // IDs of records that found a line match
        var unmatched = existing           // records not yet matched (shrinks as we match)

        struct SyncAction {
            enum Kind { case create, update, delete }
            let kind: Kind
            let lineText: String?
            let date: DetectedDate?
            let record: BodyCalendarEvent?
        }
        var actions: [SyncAction] = []

        for (lineText, detectedDate) in datedLines {
            // Try to find a fuzzy match in unmatched records.
            if let idx = unmatched.firstIndex(where: { fuzzyMatch($0.lineText, lineText) >= 0.80 }) {
                let record = unmatched[idx]
                matched.insert(record.id)
                unmatched.remove(at: idx)
                // Update if text or date changed.
                actions.append(SyncAction(kind: .update, lineText: lineText, date: detectedDate, record: record))
            } else {
                // New line with date — create.
                actions.append(SyncAction(kind: .create, lineText: lineText, date: detectedDate, record: nil))
            }
        }

        // Remaining unmatched records → delete.
        for record in unmatched {
            actions.append(SyncAction(kind: .delete, lineText: nil, date: nil, record: record))
        }

        // 5. Enforce max 15 body events.
        let createCount = actions.filter { $0.kind == .create }.count
        let currentLive = existing.count - unmatched.count  // existing that survived
        let totalAfter = currentLive + createCount
        var skippedCreates = 0
        if totalAfter > maxEventsPerTask {
            skippedCreates = totalAfter - maxEventsPerTask
            log.warning("sync: would exceed max \(self.maxEventsPerTask) events — skipping \(skippedCreates) newest creates")
        }

        // 6. Execute actions.
        let deepLinkURL = DeepLinkHandler.taskURL(for: taskId)
        var createsExecuted = 0

        for action in actions {
            switch action.kind {

            case .create:
                if createsExecuted >= (createCount - skippedCreates) {
                    log.info("sync: skipping create (max events reached)")
                    continue
                }
                guard let lineText = action.lineText, let detected = action.date else { continue }
                let eventId = await calendarSync.syncDateToCalendar(
                    title: taskTitle,
                    date: detected.date,
                    endDate: detected.endDate,
                    existingEventId: nil,
                    deepLinkURL: deepLinkURL
                )
                let record = BodyCalendarEvent(
                    lineText: lineText,
                    task: task,
                    calendarEventId: eventId
                )
                context.insert(record)
                createsExecuted += 1
                log.info("sync: CREATED event for line '\(lineText)' → eventId=\(eventId ?? "nil")")

            case .update:
                guard let record = action.record,
                      let lineText = action.lineText,
                      let detected = action.date else { continue }
                let eventId = await calendarSync.syncDateToCalendar(
                    title: taskTitle,
                    date: detected.date,
                    endDate: detected.endDate,
                    existingEventId: record.calendarEventId,
                    deepLinkURL: deepLinkURL
                )
                record.lineText = lineText
                record.calendarEventId = eventId
                // If the line was struck and user edited it with a new date, revive it.
                if record.isStruck {
                    record.isStruck = false
                    log.info("sync: revived struck record for '\(lineText)'")
                }
                log.info("sync: UPDATED event for line '\(lineText)' → eventId=\(eventId ?? "nil")")

            case .delete:
                guard let record = action.record else { continue }
                if let eventId = record.calendarEventId {
                    await calendarSync.deleteEvent(withId: eventId)
                }
                context.delete(record)
                log.info("sync: DELETED event for line '\(record.lineText)'")
            }
        }

        // 7. Persist.
        do {
            try context.save()
            log.info("sync: saved \(actions.count) actions for task '\(taskTitle)'")
        } catch {
            log.error("sync: context.save() failed — \(error.localizedDescription)")
        }
    }

    /// Delete ALL body-line events for a task (used on task completion/trash).
    @MainActor
    func deleteAllEvents(for task: TaskItem, context: ModelContext) async {
        let records = task.bodyCalendarEvents ?? []
        log.info("deleteAllEvents: removing \(records.count) records for '\(task.title)'")
        for record in records {
            if let eventId = record.calendarEventId {
                await calendarSync.deleteEvent(withId: eventId)
            }
            context.delete(record)
        }
        do {
            try context.save()
        } catch {
            log.error("deleteAllEvents: context.save() failed — \(error.localizedDescription)")
        }
    }

    // MARK: - Fuzzy matching

    /// Returns a similarity score (0.0–1.0) between two strings using
    /// Jaccard similarity on word tokens. 1.0 = identical, 0.0 = nothing in common.
    private func fuzzyMatch(_ a: String, _ b: String) -> Double {
        let wordsA = Set(a.lowercased().split(separator: " "))
        let wordsB = Set(b.lowercased().split(separator: " "))
        guard !wordsA.isEmpty || !wordsB.isEmpty else { return 1.0 }
        let intersection = wordsA.intersection(wordsB).count
        let union = wordsA.union(wordsB).count
        return Double(intersection) / Double(union)
    }
}
