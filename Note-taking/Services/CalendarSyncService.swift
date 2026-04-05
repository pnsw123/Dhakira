import EventKit
import Foundation
import OSLog
import SwiftData

private let log = Logger(subsystem: "notes.Note-taking", category: "CalendarSync")

/// Manages creation, update, and deletion of EKEvents in Apple Calendar.
///
/// All operations are fire-and-forget from the caller's perspective — errors are
/// logged via OSLog but never surfaced to the UI.  Permission is checked via the
/// cached value in CalendarPermissionService; no permission prompt is ever issued
/// from inside this service.
final class CalendarSyncService {

    // Shared instance for use from Task save flows.
    static let shared = CalendarSyncService()

    /// Exposed for two-way sync reconciliation (Issue #86).
    let eventStore: EKEventStore

    init(eventStore: EKEventStore = EKEventStore()) {
        self.eventStore = eventStore
    }

    // MARK: - Sync

    /// Creates or updates a calendar event for the given task.
    ///
    /// - Parameters:
    ///   - title: The task title — used as the event title.
    ///   - date: The detected start date for the event.
    ///   - existingEventId: The previously stored EKEvent identifier, if any.
    ///   - deepLinkURL: Optional `dhakira://task/{uuid}` URL attached to the event
    ///                  so tapping it in Calendar opens the app at the right task.
    /// - Returns: The EKEvent identifier to store back on the task, or `nil` if the
    ///            operation was skipped or failed.
    func syncDateToCalendar(
        title: String,
        date: Date,
        endDate: Date? = nil,
        existingEventId: String?,
        targetCalendar: EKCalendar? = nil,
        deepLinkURL: URL? = nil,
        notes: String? = nil
    ) async -> String? {
        let permitted = await MainActor.run { CalendarPermissionService.shared.isGranted }
        guard permitted else {
            log.warning("syncDateToCalendar: calendar permission not granted — skipping")
            return existingEventId
        }

        // If we have a stored event ID, try to locate the event.
        if let eventId = existingEventId {
            if let existingEvent = eventStore.event(withIdentifier: eventId) {
                // Update the existing event in place.
                log.info("syncDateToCalendar: updating existing event '\(eventId)'")
                configure(existingEvent, title: title, date: date, endDate: endDate, deepLinkURL: deepLinkURL, notes: notes)
                do {
                    try eventStore.save(existingEvent, span: .thisEvent)
                    log.info("syncDateToCalendar: event updated ✓")
                    return existingEvent.eventIdentifier
                } catch {
                    log.error("syncDateToCalendar: failed to update — \(error.localizedDescription)")
                    return existingEventId
                }
            } else {
                // Stale ID — event was deleted externally. Fall through to create a new one.
                log.warning("syncDateToCalendar: stale event ID '\(eventId)' — creating new event")
            }
        }

        // Create a brand-new event in the specified calendar (or system default).
        guard let calendar = targetCalendar ?? eventStore.defaultCalendarForNewEvents else {
            log.error("syncDateToCalendar: no default calendar available")
            return nil
        }
        let event = EKEvent(eventStore: eventStore)
        event.calendar = calendar
        configure(event, title: title, date: date, endDate: endDate, deepLinkURL: deepLinkURL, notes: notes)
        do {
            try eventStore.save(event, span: .thisEvent)
            log.info("syncDateToCalendar: event created ✓ id='\(event.eventIdentifier ?? "unknown")'")
            return event.eventIdentifier
        } catch {
            log.error("syncDateToCalendar: failed to create — \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Delete

    /// Deletes a Google Calendar event — tries EventKit (CalDAV) first, then REST API (OAuth).
    /// Safe to call with a stale ID.
    func deleteGoogleEvent(_ eventId: String) async {
        // Try EventKit first (CalDAV-created events have EKEvent identifiers).
        if eventStore.event(withIdentifier: eventId) != nil {
            await deleteEvent(withId: eventId)
            return
        }
        // Not an EKEvent ID — assume it's a Google REST API event ID.
        let isOAuth = await MainActor.run { GoogleAuthService.shared.isConnected }
        if isOAuth {
            await GoogleCalendarAPIService.shared.deleteEvent(id: eventId)
        }
    }

    /// Removes an Apple Calendar (EKEvent) by its stored identifier.
    ///
    /// Safe to call with a stale or already-deleted identifier — does not throw or crash.
    func deleteEvent(withId eventId: String) async {
        let permitted = await MainActor.run { CalendarPermissionService.shared.isGranted }
        guard permitted else {
            log.warning("deleteEvent: calendar permission not granted — skipping")
            return
        }
        guard let event = eventStore.event(withIdentifier: eventId) else {
            log.info("deleteEvent: event '\(eventId)' not found — already deleted or never existed")
            return
        }
        do {
            try eventStore.remove(event, span: .thisEvent)
            log.info("deleteEvent: event '\(eventId)' removed ✓")
        } catch {
            log.error("deleteEvent: failed to remove '\(eventId)' — \(error.localizedDescription)")
        }
    }

    // MARK: - High-level task sync

    /// Scans the task title (and optional body text) for a natural-language date/time.
    /// If found → creates or updates a calendar event and stores the ID back on the task.
    /// If not found → deletes any stale calendar event.
    ///
    /// Uses Apple's NSDataDetector — understands "today", "tomorrow", "next Friday",
    /// "March 30", "3/30", "5pm", "9 o'clock", and virtually every other format.
    /// Safe to call at task creation time or after any edit.
    func syncTaskIfNeeded(_ task: TaskItem, bodyText: String = "") async {
        // Never create/update calendar events for completed or trashed tasks.
        guard !task.isCompleted && !task.isTrashed else {
            log.info("syncTaskIfNeeded: skipping — task is \(task.isCompleted ? "completed" : "trashed")")
            return
        }
        let cal = Calendar.current
        let now = Date()
        let title = task.title
        let existingEventId = task.calendarEventId

        let detector = DateDetectionService()
        let titleDetected = detector.detectDates(in: title)

        // Accept dates that are today (even if the exact time has passed) or in the future.
        func isRelevant(_ date: Date) -> Bool {
            date > now || cal.isDateInToday(date)
        }

        let relevantTitle = titleDetected.filter { isRelevant($0.date) }

        // Title event uses ONLY title dates — body dates are handled by BodyEventSyncService.
        // Without this, "Laundry" with body "do this at 9pm" would create a spurious
        // "Laundry" event at 9pm in addition to the body-line event.
        guard let earliest = relevantTitle.min(by: { $0.date < $1.date }) else {
            // No date in the text — delete any stale calendar events (Apple + Google).
            if let staleId = existingEventId {
                await deleteEvent(withId: staleId)
                await MainActor.run { task.calendarEventId = nil }
            }
            if let staleGoogleId = task.googleCalendarEventId {
                await deleteGoogleEvent(staleGoogleId)
                await MainActor.run { task.googleCalendarEventId = nil }
            }
            return
        }

        // Build a clean event title by stripping the date text from the task title.
        // "Dentist at 5pm" → "Dentist"   |   "Meeting tomorrow at 9am" → "Meeting"
        // If the date came from the body, keep the full title as-is.
        let eventTitle: String
        if relevantTitle.contains(where: { $0.date == earliest.date }) {
            eventTitle = strippingDateText(earliest, from: title)
        } else {
            eventTitle = title
        }

        let cleanTitle = eventTitle.isEmpty ? title : eventTitle
        let deepLinkURL = DeepLinkHandler.taskURL(for: task.id)

        // ── Apple Calendar sync ───────────────────────────────────────────────
        // IMPORTANT: Use preferredAppleCalendar() instead of defaultCalendarForNewEvents
        // because the user's default might be a Gmail/Google calendar (via CalDAV).
        // That would cause events to leak into Google Calendar through the "Apple" path.
        let appleEnabled = await MainActor.run { CalendarSelectionService.shared.appleCalendarSyncEnabled }
        let appleCal = preferredAppleCalendar()
        log.info("syncTaskIfNeeded: appleEnabled=\(appleEnabled) appleCal='\(appleCal?.title ?? "none")' source='\(appleCal?.source?.title ?? "?")'")
        let appleEventId: String?
        if appleEnabled {
            appleEventId = await syncDateToCalendar(
                title: cleanTitle,
                date: earliest.date,
                endDate: earliest.endDate,
                existingEventId: existingEventId,
                targetCalendar: appleCal,
                deepLinkURL: deepLinkURL
            )
        } else {
            if let staleId = existingEventId { await deleteEvent(withId: staleId) }
            appleEventId = nil
        }
        await MainActor.run { task.calendarEventId = appleEventId }

        // ── Google Calendar sync ──────────────────────────────────────────────
        // Priority: CalDAV (local Google account in system Settings) → REST API (OAuth).
        let googleCal = await MainActor.run { CalendarSelectionService.shared.googleCalendar() }
        let isOAuthConnected = await MainActor.run { GoogleAuthService.shared.isConnected }
        let webEnabled = await MainActor.run { CalendarSelectionService.shared.googleWebCalendarEnabled }
        log.info("syncTaskIfNeeded: googleCal=\(googleCal != nil) isOAuthConnected=\(isOAuthConnected) webEnabled=\(webEnabled)")

        let googleEventId: String?

        if let googleCal {
            log.info("syncTaskIfNeeded: using CalDAV path → calendar '\(googleCal.title)'")
            googleEventId = await syncDateToCalendar(
                title: cleanTitle,
                date: earliest.date,
                endDate: earliest.endDate,
                existingEventId: task.googleCalendarEventId,
                targetCalendar: googleCal,
                deepLinkURL: deepLinkURL
            )
        } else if isOAuthConnected && webEnabled {
            log.info("syncTaskIfNeeded: using OAuth REST API path")
            googleEventId = await GoogleCalendarAPIService.shared.syncEvent(
                title: cleanTitle,
                date: earliest.date,
                endDate: earliest.endDate,
                existingId: task.googleCalendarEventId,
                deepLinkURL: deepLinkURL
            )
        } else {
            log.info("syncTaskIfNeeded: Google Calendar SKIPPED — no CalDAV calendar and OAuth not ready (connected=\(isOAuthConnected), webEnabled=\(webEnabled))")
            googleEventId = nil
        }

        await MainActor.run { task.googleCalendarEventId = googleEventId }
    }

    // MARK: - Date text stripping

    /// Returns `title` with the detected date match removed, plus leading preposition/connector.
    /// "Dentist at 5pm" → "Dentist"
    /// "Watch movie on Friday" → "Watch movie"
    /// "assignment due tomorrow" → "assignment"
    /// "gym tmrw at 5p" → "gym"
    func strippingDateText(_ detected: DetectedDate, from title: String) -> String {
        // If the detected range is empty (slang like "tmrw" that didn't map back),
        // fall back to regex-based stripping of known date patterns from the original text.
        let matchRange = NSRange(detected.range, in: title)
        if matchRange.length == 0 {
            return stripDatePatternsFromOriginal(title)
        }

        let ns = title as NSString
        var start  = matchRange.location
        var length = matchRange.length

        // Swallow a leading preposition/connector word.
        // Longest separators first so " due on " matches before " on ".
        let separators = [
            " due on ", " due at ", " due by ", " due ",
            " before ", " until ", " by ",
            " at ", " on ", ", ", " ",
        ]
        for sep in separators {
            let sepLen = sep.utf16.count
            if start >= sepLen {
                let candidate = ns.substring(with: NSRange(location: start - sepLen, length: sepLen))
                if candidate.lowercased() == sep {
                    start  -= sepLen
                    length += sepLen
                    break
                }
            }
        }

        // Swallow trailing whitespace and punctuation (periods, exclamation marks)
        while start + length < ns.length {
            let ch = ns.character(at: start + length)
            if ch == 32 || ch == 46 || ch == 33 { // space, period, exclamation
                length += 1
            } else {
                break
            }
        }

        let cleaned = ns.replacingCharacters(in: NSRange(location: start, length: length), with: "")
        return cleaned.trimmingCharacters(in: .whitespaces)
    }

    /// Fallback stripping for when the normalized→original range mapping fails
    /// (e.g. slang like "tmrw", "nxt mon", "2morrow").
    ///
    /// Mirrors EVERY token from DateDetectionService's slangMap + normalize().
    /// Connectors ("at", "on", "by", "due") are ONLY stripped when directly
    /// attached to a recognized date token — "at school" and "on a boat" are safe.
    private func stripDatePatternsFromOriginal(_ title: String) -> String {
        var result = title

        // ── Reusable token groups (from DateDetectionService) ────────────────

        // Tomorrow: all slang variants
        let tmrw = "tmrw|tmrrow|tmr|tmro|tomo|tomoro|2morrow|2mrw|2moro|2mrow|2mro|tomorrow"
        // Today: all slang variants
        let tdy  = "2day|2dy|tdy|tod|today"
        // Tonight: all slang variants
        let tn   = "2nite|tonite|tnite|2night|tonight|tn"
        // Weekdays: full + 3-letter + 2-letter (from slangMap)
        let wkday = "monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun|mo|tu|we|th|fr|sa|su"
        // Months: full + abbreviations (from slangMap)
        let mnth = "january|february|march|april|may|june|july|august|september|october|november|december|janu|feb|mar|apr|jun|jul|aug|sep|oct|nov|dec"
        // Prefix words: next/this/coming/upcoming + slang
        let pfx  = "nxt\\s+nxt|next\\s+next|nxt|next|coming|upcoming|comin|upcomin|dis|this"
        // Time periods
        let prd  = "week|weekend|month|day|year"
        // Duration units (from expandRelativeDurations)
        let duru = "hours?|hrs?|h|minutes?|mins?|m|seconds?|secs?|s|days?|d|weeks?|wks?|w|months?|mo|mos|years?|yrs?|y|fortnight"

        // Connector: ONLY matches when followed by a date token (built into each pattern).
        // This ensures "at school" is NOT stripped — "at" is only removed when
        // it precedes a known date/time word like "at 5pm" or "at noon".
        let conn = "(?:\\s+(?:due\\s+)?(?:at|on|by|before|until|for))?\\s+"

        // Patterns ordered most-specific → least-specific to avoid partial matches.
        let patterns = [
            // ── Multi-word phrases first ──────────────────────────────────────
            // "day after tomorrow"
            "(?i)" + conn + "day\\s+after\\s+(?:" + tmrw + ")\\b[.!]?",
            // "end of day/week/month" + EOD/EOW/EOM
            "(?i)\\s+(?:end\\s+of\\s+(?:the\\s+)?(?:week|day|month)|EOD|EOW|EOM)\\b[.!]?",
            // "later today"
            "(?i)\\s+later\\s+(?:" + tdy + ")\\b[.!]?",

            // ── <prefix> <weekday> (next Monday, nxt fri, this sat, etc.) ─────
            "(?i)" + conn + "(?:" + pfx + ")\\s+(?:" + wkday + ")\\b[.!]?",
            // ── <prefix> <period> (next week, nxt month, this weekend, etc.) ──
            "(?i)" + conn + "(?:" + pfx + ")\\s+(?:" + prd + ")\\b[.!]?",

            // ── tomorrow / today / tonight slang ─────────────────────────────
            "(?i)" + conn + "(?:" + tmrw + ")\\b[.!]?",
            "(?i)" + conn + "(?:" + tdy + ")\\b[.!]?",
            "(?i)" + conn + "(?:" + tn + ")\\b[.!]?",

            // ── bare weekday (just "Monday", "fri") ──────────────────────────
            "(?i)" + conn + "(?:" + wkday + ")\\b[.!]?",

            // ── "in N <units>" (in 2 hours, in 3d, in a week, etc.) ──────────
            "(?i)\\s+in\\s+\\d+(?:\\.\\d+)?\\s*(?:" + duru + ")\\b[.!]?",
            "(?i)\\s+in\\s+an?\\s+(?:" + duru + ")\\b[.!]?",

            // ── <month> <day> <year>? (April 3, mar 15 2026, etc.) ───────────
            "(?i)" + conn + "(?:" + mnth + ")\\s+\\d{1,2}(?:(?:st|nd|rd|th))?(?:,?\\s+\\d{4})?\\b[.!]?",

            // ── "the 15th" / "the 1st" ───────────────────────────────────────
            "(?i)\\s+(?:on\\s+)?the\\s+\\d{1,2}(?:st|nd|rd|th)\\b[.!]?",

            // ── numeric dates: 4/3, 4/3/2026, 4-3-26, 4.3.26 ────────────────
            "(?i)" + conn + "\\d{1,2}[/\\-.]\\d{1,2}(?:[/\\-.]\\d{2,4})?\\b[.!]?",

            // ── time: "5pm", "5:30pm", "@5pm", "5p", "5a", "5 a.m." ─────────
            // Only strip "at" when followed by a number+am/pm — NOT "at school"
            "(?i)\\s+(?:(?:due\\s+)?at\\s+)?@?\\d{1,2}(?::\\d{2})?\\s*(?:am|pm|a\\.?m\\.?|p\\.?m\\.?)\\b[.!]?",

            // ── "N o'clock" / "half past N" / "quarter to N" ─────────────────
            "(?i)\\s+(?:(?:due\\s+)?at\\s+)?\\d{1,2}\\s+o'?clock\\b[.!]?",
            "(?i)\\s+(?:(?:due\\s+)?at\\s+)?(?:half\\s+past|quarter\\s+(?:past|to))\\s+\\d{1,2}\\b[.!]?",

            // ── noon / midnight ──────────────────────────────────────────────
            "(?i)" + conn + "(?:noon|midnight)\\b[.!]?",
            // "nite" / "night" (standalone)
            "(?i)" + conn + "(?:nite|night)\\b[.!]?",

            // ── time-of-day qualifiers that follow a date ────────────────────
            // "tomorrow morning", "nxt fri evening" — strip the trailing qualifier
            "(?i)\\s+(?:morning|afternoon|evening|morn|aft|eve)\\b[.!]?",
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: ""
                )
            }
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Bulk re-sync

    /// Re-syncs all incomplete tasks that have dates to the newly connected calendar.
    /// Call after the user first connects Google Calendar (or toggles it on) so that
    /// tasks created before the connection still get events.
    ///
    /// Syncs BOTH title-level dates AND body-line dates (Issue #89).
    /// Previously only title dates were re-synced, leaving body events orphaned
    /// on Google Calendar after account reconnection.
    func resyncAllTasks(in context: ModelContext) async {
        log.info("resyncAllTasks: starting bulk re-sync of existing tasks (title + body events)")
        let descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate { !$0.isCompleted && !$0.isTrashed }
        )
        guard let tasks = try? context.fetch(descriptor) else {
            log.error("resyncAllTasks: failed to fetch tasks")
            return
        }
        var syncedTitle = 0
        var syncedBody = 0
        for task in tasks {
            // Title-level date sync.
            await syncTaskIfNeeded(task)
            syncedTitle += 1

            // Body-line date sync — extract plain text from the stored body Data.
            if let bodyData = task.body {
                let bodyText: String
                switch NoteBodyCodec.decode(bodyData, taskId: task.id) {
                case .success(let attrStr):
                    bodyText = attrStr.string
                case .failure:
                    bodyText = ""
                }
                if !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    await BodyEventSyncService.shared.sync(
                        bodyText: bodyText, task: task, context: context
                    )
                    syncedBody += 1
                }
            }
        }
        try? context.save()
        log.info("resyncAllTasks: re-synced \(syncedTitle) title events + \(syncedBody) body event tasks ✓")
    }

    // MARK: - Account switch cleanup

    /// Deletes all Google Calendar events (title + body) AND clears stored IDs.
    /// Call BEFORE disconnecting (while we still have the old account's token)
    /// so events are actually removed from the old account's calendar.
    func deleteAllGoogleEvents(in context: ModelContext) async {
        log.info("deleteAllGoogleEvents: deleting all Google Calendar events + clearing IDs (title + body)")
        let descriptor = FetchDescriptor<TaskItem>()
        guard let allTasks = try? context.fetch(descriptor) else {
            log.error("deleteAllGoogleEvents: failed to fetch tasks")
            return
        }
        var deletedTitle = 0
        var deletedBody = 0
        for task in allTasks {
            // Delete title-level Google event.
            if let googleId = task.googleCalendarEventId {
                log.info("deleteAllGoogleEvents: deleting title event '\(googleId)' for task '\(task.title)'")
                await deleteGoogleEvent(googleId)
                await MainActor.run { task.googleCalendarEventId = nil }
                deletedTitle += 1
            }
            // Delete body-level Google events and reset struck status (Issue #89).
            for record in (task.bodyCalendarEvents ?? []) {
                if let googleId = record.googleCalendarEventId {
                    log.info("deleteAllGoogleEvents: deleting body event '\(googleId)' for line '\(record.lineText)'")
                    await deleteGoogleEvent(googleId)
                    record.googleCalendarEventId = nil
                    deletedBody += 1
                }
                if record.isStruck {
                    record.isStruck = false
                }
            }
        }
        if deletedTitle + deletedBody > 0 { try? context.save() }
        log.info("deleteAllGoogleEvents: deleted \(deletedTitle) title + \(deletedBody) body event(s) ✓")
    }

    /// Clears all stored Google Calendar event IDs (without deleting the events)
    /// and resets struck status on body events so they can be re-synced to the new account.
    ///
    /// Use when the old token is already gone and we can't delete from the API.
    /// On Google account switch, old event IDs belong to the previous account — they must
    /// be cleared. Struck records must also be reset because the "user deleted from Calendar"
    /// signal is meaningless across different accounts (Issue #89).
    func clearAllGoogleEventIds(in context: ModelContext) async {
        log.info("clearAllGoogleEventIds: wiping all stored Google event IDs + resetting struck status")
        let descriptor = FetchDescriptor<TaskItem>()
        guard let allTasks = try? context.fetch(descriptor) else {
            log.error("clearAllGoogleEventIds: failed to fetch tasks")
            return
        }
        var clearedTitle = 0
        var clearedBody = 0
        var resetStruck = 0
        for task in allTasks {
            // Clear title-level Google event ID.
            if task.googleCalendarEventId != nil {
                task.googleCalendarEventId = nil
                clearedTitle += 1
            }
            // Clear body-level Google event IDs and reset struck status.
            for record in (task.bodyCalendarEvents ?? []) {
                if record.googleCalendarEventId != nil {
                    record.googleCalendarEventId = nil
                    clearedBody += 1
                }
                // Reset struck status — the struck flag was set because the event was missing
                // on the OLD account. On the new account, it should be recreated.
                if record.isStruck {
                    record.isStruck = false
                    resetStruck += 1
                }
            }
        }
        if clearedTitle + clearedBody + resetStruck > 0 { try? context.save() }
        log.info("clearAllGoogleEventIds: cleared \(clearedTitle) title + \(clearedBody) body event ID(s), reset \(resetStruck) struck record(s) ✓")
    }

    // MARK: - Startup cleanup

    /// Removes stale calendar events for tasks that are completed or trashed.
    /// Call on every app launch to clean up orphaned events — covers:
    ///   - Tasks completed/deleted on another device (synced via CloudKit)
    ///   - Tasks that were completed while the app was killed
    ///   - Reinstall scenarios where CloudKit restores old data
    func cleanupStaleEvents(in context: ModelContext) async {
        log.info("cleanupStaleEvents: scanning for completed/trashed tasks with leftover calendar events")
        let descriptor = FetchDescriptor<TaskItem>()
        guard let allTasks = try? context.fetch(descriptor) else {
            log.error("cleanupStaleEvents: failed to fetch tasks")
            return
        }

        var cleaned = 0
        for task in allTasks {
            let needsCleanup = task.isCompleted || task.isTrashed
            guard needsCleanup else { continue }

            if let eventId = task.calendarEventId {
                log.info("cleanupStaleEvents: removing Apple event '\(eventId)' for completed/trashed task '\(task.title)'")
                await deleteEvent(withId: eventId)
                await MainActor.run { task.calendarEventId = nil }
                cleaned += 1
            }
            if let googleId = task.googleCalendarEventId {
                log.info("cleanupStaleEvents: removing Google event '\(googleId)' for completed/trashed task '\(task.title)'")
                await deleteGoogleEvent(googleId)
                await MainActor.run { task.googleCalendarEventId = nil }
                cleaned += 1
            }
        }

        if cleaned > 0 {
            try? context.save()
        }
        log.info("cleanupStaleEvents: removed \(cleaned) stale event(s) ✓")
    }

    // MARK: - Parent event reconciliation

    /// Check whether a single task's parent calendar event still exists in Apple Calendar.
    /// If the event has been deleted externally, clear the stored ID so the app doesn't
    /// treat the task as still synced.
    @MainActor
    func reconcileParentEvent(for task: TaskItem) {
        guard let eventId = task.calendarEventId, !eventId.isEmpty else { return }
        if eventStore.event(withIdentifier: eventId) == nil {
            log.info("reconcileParentEvent: event '\(eventId)' no longer exists — clearing calendarEventId for '\(task.title)'")
            task.calendarEventId = nil
        }
    }

    private var isReconcilingParents = false

    /// Reconcile ALL tasks' parent calendar events against Apple Calendar.
    /// Called on launch, foreground return, and EKEventStoreChanged.
    @MainActor
    func reconcileAllParentEvents(context: ModelContext) {
        guard !isReconcilingParents else {
            log.debug("reconcileAllParentEvents: already running — skipping duplicate call")
            return
        }
        isReconcilingParents = true
        defer { isReconcilingParents = false }

        let descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate<TaskItem> { $0.calendarEventId != nil }
        )
        guard let tasks = try? context.fetch(descriptor) else { return }
        var cleared = 0
        for task in tasks {
            guard let eventId = task.calendarEventId, !eventId.isEmpty else { continue }
            if eventStore.event(withIdentifier: eventId) == nil {
                log.info("reconcileAllParentEvents: event '\(eventId)' missing — clearing for '\(task.title)'")
                task.calendarEventId = nil
                cleared += 1
            }
        }
        if cleared > 0 {
            try? context.save()
            log.info("reconcileAllParentEvents: cleared \(cleared) stale parent event ID(s) ✓")
        }
    }

    // MARK: - Calendar selection

    /// Returns the preferred Apple/iCloud calendar for event sync.
    /// Avoids returning a Gmail/Google calendar (CalDAV) — that would cause events
    /// to leak into Google Calendar through the "Apple Calendar" sync path.
    private func preferredAppleCalendar() -> EKCalendar? {
        let allCalendars = eventStore.calendars(for: .event)
            .filter { $0.allowsContentModifications }

        // Prefer iCloud calendar
        if let iCloud = allCalendars.first(where: {
            $0.source?.title.localizedCaseInsensitiveContains("iCloud") == true
        }) {
            return iCloud
        }

        // Fallback: any non-Google, non-Subscribed writable calendar
        if let nonGoogle = allCalendars.first(where: { cal in
            let title = cal.source?.title ?? ""
            let isGoogle = title.localizedCaseInsensitiveContains("google")
                        || title.localizedCaseInsensitiveContains("gmail")
            let isSubscribed = cal.source?.sourceType == .subscribed
            return !isGoogle && !isSubscribed
        }) {
            return nonGoogle
        }

        // Last resort: whatever the system default is
        log.warning("preferredAppleCalendar: no iCloud or non-Google calendar found — using system default")
        return eventStore.defaultCalendarForNewEvents
    }

    // MARK: - Private helpers

    /// Applies all standard fields to an EKEvent: title, dates, 15-minute alarm, deep link.
    private func configure(_ event: EKEvent, title: String, date: Date, endDate: Date? = nil, deepLinkURL: URL?, notes: String? = nil) {
        event.title = title
        event.startDate = date
        event.endDate = endDate ?? date.addingTimeInterval(3600) // use detected end time, or 1 hour default

        // Attach (or replace) the 15-minute reminder alarm.
        // Setting the array replaces any existing alarms, preventing duplicates on update.
        event.alarms = [EKAlarm(relativeOffset: -900)] // -900 seconds = 15 minutes before

        // Store the deep link URL so tapping the event in Calendar opens the task.
        if let url = deepLinkURL {
            event.url = url
        }

        // Body-line events include the line text as event notes/description.
        if let notes {
            event.notes = notes
        }
    }
}
