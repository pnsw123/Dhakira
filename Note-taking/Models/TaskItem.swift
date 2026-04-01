import Foundation
import SwiftData

@Model
final class TaskItem {
    var id: UUID = UUID()
    var title: String = ""
    var body: Data?
    var priority: String = "default"
    var isCompleted: Bool = false
    var createdAt: Date = Date()
    var completedAt: Date?
    var drawingData: Data?
    var calendarEventId: String?         // Apple Calendar EKEvent identifier
    var googleCalendarEventId: String?   // Google Calendar EKEvent identifier (CalDAV)
    var sortOrder: Int = 0

    var parentTask: TaskItem?

    @Relationship(deleteRule: .nullify, inverse: \TaskItem.parentTask)
    var subtasks: [TaskItem]? = []

    var folder: Folder?
    var taskList: TaskList?

    // Soft-delete fields
    var isDeleted: Bool = false
    var deletedAt: Date?

    @Relationship(deleteRule: .nullify, inverse: \Attachment.task)
    var attachments: [Attachment]? = []

    init(
        title: String = "",
        priority: String = "default",
        parentTask: TaskItem? = nil,
        folder: Folder? = nil,
        taskList: TaskList? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.priority = priority
        self.isCompleted = false
        self.createdAt = Date()
        self.parentTask = parentTask
        self.folder = folder
        self.taskList = taskList
        self.isDeleted = false
        self.deletedAt = nil
    }
}
