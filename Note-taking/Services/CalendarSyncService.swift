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

    private let eventStore: EKEventStore

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
    ///   - deepLinkURL: Optional `prodnote://task/{uuid}` URL attached to the event
    ///                  so tapping it in Calendar opens the app at the right task.
    /// - Returns: The EKEvent identifier to store back on the task, or `nil` if the
    ///            operation was skipped or failed.
    func syncDateToCalendar(
        title: String,
        date: Date,
        existingEventId: String?,
        targetCalendar: EKCalendar? = nil,
        deepLinkURL: URL? = nil
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
                configure(existingEvent, title: title, date: date, deepLinkURL: deepLinkURL)
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
        configure(event, title: title, date: date, deepLinkURL: deepLinkURL)
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
        let cal = Calendar.current
        let now = Date()
        let title = task.title
        let existingEventId = task.calendarEventId

        let detector = DateDetectionService()
        let titleDetected = detector.detectDates(in: title)
        let bodyDetected  = bodyText.isEmpty ? [] : detector.detectDates(in: bodyText)

        // Accept dates that are today (even if the exact time has passed) or in the future.
        func isRelevant(_ date: Date) -> Bool {
            date > now || cal.isDateInToday(date)
        }

        let relevantTitle = titleDetected.filter { isRelevant($0.date) }
        let relevantBody  = bodyDetected.filter  { isRelevant($0.date) }
        let allRelevant   = relevantTitle + relevantBody

        guard let earliest = allRelevant.min(by: { $0.date < $1.date }) else {
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

        // Sync to Apple Calendar (unless the user disabled it).
        let appleEnabled = await MainActor.run { CalendarSelectionService.shared.appleCalendarSyncEnabled }
        let appleEventId: String?
        if appleEnabled {
            appleEventId = await syncDateToCalendar(
                title: cleanTitle,
                date: earliest.date,
                existingEventId: existingEventId,
                targetCalendar: eventStore.defaultCalendarForNewEvents,
                deepLinkURL: deepLinkURL
            )
        } else {
            // Apple sync disabled — delete any stale event and clear the stored ID.
            if let staleId = existingEventId { await deleteEvent(withId: staleId) }
            appleEventId = nil
        }
        await MainActor.run { task.calendarEventId = appleEventId }

        // Sync to Google Calendar.
        // Priority: CalDAV (local Google account in system Settings) → REST API (OAuth).
        let googleCal = await MainActor.run { CalendarSelectionService.shared.googleCalendar() }
        let googleEventId: String?

        if let googleCal {
            // User has Google Calendar synced locally via iOS/Mac Settings — use CalDAV.
            googleEventId = await syncDateToCalendar(
                title: cleanTitle,
                date: earliest.date,
                existingEventId: task.googleCalendarEventId,
                targetCalendar: googleCal,
                deepLinkURL: deepLinkURL
            )
        } else if await MainActor.run(body: { GoogleAuthService.shared.isConnected && CalendarSelectionService.shared.googleWebCalendarEnabled }) {
            // No local Google Calendar but user authenticated via OAuth — use REST API.
            googleEventId = await GoogleCalendarAPIService.shared.syncEvent(
                title: cleanTitle,
                date: earliest.date,
                existingId: task.googleCalendarEventId,
                deepLinkURL: deepLinkURL
            )
        } else {
            googleEventId = nil
        }

        await MainActor.run { task.googleCalendarEventId = googleEventId }
    }

    // MARK: - Date text stripping

    /// Returns `title` with the detected date match removed, plus leading preposition.
    /// "Dentist at 5pm" → "Dentist"
    /// "Watch movie on Friday" → "Watch movie"
    func strippingDateText(_ detected: DetectedDate, from title: String) -> String {
        let ns = title as NSString
        let matchRange = NSRange(detected.range, in: title)
        var start  = matchRange.location
        var length = matchRange.length
        // Swallow a leading preposition separator (" at ", " on ", ", ", " ")
        let separators = [" at ", " on ", ", ", " "]
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
        // Swallow trailing whitespace
        while start + length < ns.length, ns.character(at: start + length) == 32 {
            length += 1
        }
        let cleaned = ns.replacingCharacters(in: NSRange(location: start, length: length), with: "")
        return cleaned.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Private helpers

    /// Applies all standard fields to an EKEvent: title, dates, 15-minute alarm, deep link.
    private func configure(_ event: EKEvent, title: String, date: Date, deepLinkURL: URL?) {
        event.title = title
        event.startDate = date
        event.endDate = date.addingTimeInterval(3600) // 1 hour default

        // Attach (or replace) the 15-minute reminder alarm.
        // Setting the array replaces any existing alarms, preventing duplicates on update.
        event.alarms = [EKAlarm(relativeOffset: -900)] // -900 seconds = 15 minutes before

        // Store the deep link URL so tapping the event in Calendar opens the task.
        if let url = deepLinkURL {
            event.url = url
        }
    }
}
