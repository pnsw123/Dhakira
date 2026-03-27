import EventKit
import Foundation

final class CalendarSyncService {
    private let eventStore = EKEventStore()

    func requestAccess() async -> Bool {
        do {
            return try await eventStore.requestFullAccessToEvents()
        } catch {
            return false
        }
    }

    func syncDateToCalendar(title: String, date: Date, existingEventId: String?) async -> String? {
        let hasAccess = await requestAccess()
        guard hasAccess else { return existingEventId }

        // If event already exists, update it
        if let eventId = existingEventId,
           let existingEvent = eventStore.event(withIdentifier: eventId) {
            existingEvent.title = title
            existingEvent.startDate = date
            existingEvent.endDate = date.addingTimeInterval(3600) // 1 hour default
            try? eventStore.save(existingEvent, span: .thisEvent)
            return existingEvent.eventIdentifier
        }

        // Create new event — no alarms (silent)
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = date
        event.endDate = date.addingTimeInterval(3600)
        event.calendar = eventStore.defaultCalendarForNewEvents

        do {
            try eventStore.save(event, span: .thisEvent)
            return event.eventIdentifier
        } catch {
            return nil
        }
    }
}
