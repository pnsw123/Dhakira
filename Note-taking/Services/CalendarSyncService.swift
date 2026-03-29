import EventKit
import Foundation
import OSLog

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

        // Create a brand-new event.
        guard let calendar = eventStore.defaultCalendarForNewEvents else {
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

    /// Removes a calendar event by its stored identifier.
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
