import EventKit
import Foundation
import OSLog
import SwiftData

private let log = Logger(subsystem: "notes.Note-taking", category: "BodyEventSync")

/// Syncs body-line dates to Apple Calendar AND Google Calendar as individual events.
/// Entry point: `sync(bodyText:task:context:)` — called on save, Enter+debounce, and background.
///
/// Google Calendar uses the same dual-path architecture as title events:
/// - CalDAV (if Google account added in iOS Settings) → EKEventStore targeting Google calendar
/// - OAuth REST API (if connected via GoogleAuthService) → GoogleCalendarAPIService
///
/// Diffing strategy:
/// - New date line → create Apple + Google Calendar event + store BodyCalendarEvent record
/// - Changed line (fuzzy match ≥ 80%) → update existing events
/// - Deleted/dateless line → delete events + record
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
                // Apple Calendar
                let appleEventId = await syncAppleEvent(
                    title: taskTitle, date: detected.date, endDate: detected.endDate,
                    existingEventId: nil, deepLinkURL: deepLinkURL
                )
                // Google Calendar
                let googleEventId = await syncGoogleEvent(
                    title: taskTitle, date: detected.date, endDate: detected.endDate,
                    existingId: nil, deepLinkURL: deepLinkURL, bodyLineText: lineText
                )
                let record = BodyCalendarEvent(
                    lineText: lineText,
                    task: task,
                    calendarEventId: appleEventId,
                    googleCalendarEventId: googleEventId
                )
                context.insert(record)
                createsExecuted += 1
                log.info("sync: CREATED event for line '\(lineText)' → apple=\(appleEventId ?? "nil") google=\(googleEventId ?? "nil")")

            case .update:
                guard let record = action.record,
                      let lineText = action.lineText,
                      let detected = action.date else { continue }
                // Apple Calendar
                let appleEventId = await syncAppleEvent(
                    title: taskTitle, date: detected.date, endDate: detected.endDate,
                    existingEventId: record.calendarEventId, deepLinkURL: deepLinkURL
                )
                // Google Calendar
                let googleEventId = await syncGoogleEvent(
                    title: taskTitle, date: detected.date, endDate: detected.endDate,
                    existingId: record.googleCalendarEventId, deepLinkURL: deepLinkURL,
                    bodyLineText: lineText
                )
                record.lineText = lineText
                record.calendarEventId = appleEventId
                record.googleCalendarEventId = googleEventId
                // If the line was struck and user edited it with a new date, revive it.
                if record.isStruck {
                    record.isStruck = false
                    log.info("sync: revived struck record for '\(lineText)'")
                }
                log.info("sync: UPDATED event for line '\(lineText)' → apple=\(appleEventId ?? "nil") google=\(googleEventId ?? "nil")")

            case .delete:
                guard let record = action.record else { continue }
                if let eventId = record.calendarEventId {
                    await calendarSync.deleteEvent(withId: eventId)
                }
                if let googleId = record.googleCalendarEventId {
                    await calendarSync.deleteGoogleEvent(googleId)
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
            if let googleId = record.googleCalendarEventId {
                await calendarSync.deleteGoogleEvent(googleId)
            }
            context.delete(record)
        }
        do {
            try context.save()
        } catch {
            log.error("deleteAllEvents: context.save() failed — \(error.localizedDescription)")
        }
    }

    /// Clear all Google Calendar event IDs for a task's body events
    /// (used when Google account is disconnected or switched).
    @MainActor
    func clearGoogleEventIds(for task: TaskItem, context: ModelContext) {
        let records = task.bodyCalendarEvents ?? []
        for record in records {
            record.googleCalendarEventId = nil
        }
        do {
            try context.save()
        } catch {
            log.error("clearGoogleEventIds: context.save() failed — \(error.localizedDescription)")
        }
    }

    // MARK: - Apple Calendar sync helper

    /// Syncs a single body-line event to Apple Calendar using the preferred calendar.
    private func syncAppleEvent(
        title: String, date: Date, endDate: Date?,
        existingEventId: String?, deepLinkURL: URL?
    ) async -> String? {
        let appleEnabled = await MainActor.run { CalendarSelectionService.shared.appleCalendarSyncEnabled }
        guard appleEnabled else {
            if let staleId = existingEventId { await calendarSync.deleteEvent(withId: staleId) }
            return nil
        }
        return await calendarSync.syncDateToCalendar(
            title: title, date: date, endDate: endDate,
            existingEventId: existingEventId, deepLinkURL: deepLinkURL
        )
    }

    // MARK: - Google Calendar sync helper (Issue #83)

    /// Syncs a single body-line event to Google Calendar.
    /// CalDAV takes precedence over REST API (same logic as title events).
    private func syncGoogleEvent(
        title: String, date: Date, endDate: Date?,
        existingId: String?, deepLinkURL: URL?, bodyLineText: String
    ) async -> String? {
        let googleCal = await MainActor.run { CalendarSelectionService.shared.googleCalendar() }
        let isOAuthConnected = await MainActor.run { GoogleAuthService.shared.isConnected }
        let webEnabled = await MainActor.run { CalendarSelectionService.shared.googleWebCalendarEnabled }

        if let googleCal {
            // CalDAV path — event goes through EKEventStore targeting Google calendar.
            let descURL = deepLinkURL.map { "Open in Dhakira: \($0.absoluteString)" } ?? ""
            _ = descURL // description is set via configure() inside CalendarSyncService
            return await calendarSync.syncDateToCalendar(
                title: title, date: date, endDate: endDate,
                existingEventId: existingId, targetCalendar: googleCal,
                deepLinkURL: deepLinkURL
            )
        } else if isOAuthConnected && webEnabled {
            // OAuth REST API path.
            return await GoogleCalendarAPIService.shared.syncEvent(
                title: title, date: date, endDate: endDate,
                existingId: existingId, deepLinkURL: deepLinkURL
            )
        }

        return nil
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
