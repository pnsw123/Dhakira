import Foundation
import SwiftData

/// Tracks a calendar event created from a body-line date detection.
/// Each record maps one line of body text to one Apple/Google Calendar event.
@Model
final class BodyCalendarEvent {
    var id: UUID = UUID()
    /// The plain text of the body line that triggered this event.
    var lineText: String = ""
    /// Apple Calendar EKEvent identifier (nil if not synced to Apple Calendar).
    var calendarEventId: String?
    /// Google Calendar event identifier — CalDAV EKEvent ID or REST API event ID.
    var googleCalendarEventId: String?
    /// True when the calendar event was deleted externally (two-way sync strikethrough).
    var isStruck: Bool = false
    /// When this record was created.
    var createdAt: Date = Date()

    /// The owning task. Cascade delete: when the task is deleted, all body events go too.
    var task: TaskItem?

    init(
        lineText: String,
        task: TaskItem? = nil,
        calendarEventId: String? = nil,
        googleCalendarEventId: String? = nil
    ) {
        self.id = UUID()
        self.lineText = lineText
        self.task = task
        self.calendarEventId = calendarEventId
        self.googleCalendarEventId = googleCalendarEventId
        self.isStruck = false
        self.createdAt = Date()
    }
}
