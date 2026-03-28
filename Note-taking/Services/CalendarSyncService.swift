import EventKit
import Foundation
import OSLog

private let log = Logger(subsystem: "notes.Note-taking", category: "CalendarSync")

final class CalendarSyncService {
    private let eventStore = EKEventStore()

    func requestAccess() async -> Bool {
        log.info("requestAccess: requesting full calendar access")
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            log.info("requestAccess: access \(granted ? "granted" : "denied")")
            return granted
        } catch {
            log.error("requestAccess: failed — \(error.localizedDescription)")
            return false
        }
    }

    func syncDateToCalendar(title: String, date: Date, existingEventId: String?) async -> String? {
        log.info("syncDateToCalendar: '\(title)' on \(date.description), existingEventId=\(existingEventId ?? "nil")")
        let hasAccess = await requestAccess()
        guard hasAccess else {
            log.warning("syncDateToCalendar: no calendar access — aborting")
            return existingEventId
        }

        // If event already exists, update it
        if let eventId = existingEventId,
           let existingEvent = eventStore.event(withIdentifier: eventId) {
            log.info("syncDateToCalendar: updating existing event '\(eventId)'")
            existingEvent.title = title
            existingEvent.startDate = date
            existingEvent.endDate = date.addingTimeInterval(3600) // 1 hour default
            do {
                try eventStore.save(existingEvent, span: .thisEvent)
                log.info("syncDateToCalendar: event updated successfully")
            } catch {
                log.error("syncDateToCalendar: failed to update event — \(error.localizedDescription)")
            }
            return existingEvent.eventIdentifier
        }

        // Create new event — no alarms (silent)
        guard let defaultCalendar = eventStore.defaultCalendarForNewEvents else {
            log.error("syncDateToCalendar: no default calendar available")
            return nil
        }
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = date
        event.endDate = date.addingTimeInterval(3600)
        event.calendar = defaultCalendar
        log.info("syncDateToCalendar: creating new event in calendar '\(defaultCalendar.title)'")

        do {
            try eventStore.save(event, span: .thisEvent)
            log.info("syncDateToCalendar: event created with id '\(event.eventIdentifier ?? "unknown")'")
            return event.eventIdentifier
        } catch {
            log.error("syncDateToCalendar: failed to save new event — \(error.localizedDescription)")
            return nil
        }
    }
}
