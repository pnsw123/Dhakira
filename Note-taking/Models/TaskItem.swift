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
    var calendarEventId: String?

    var parentTask: TaskItem?

    @Relationship(deleteRule: .nullify, inverse: \TaskItem.parentTask)
    var subtasks: [TaskItem]? = []

    var folder: Folder?

    @Relationship(deleteRule: .nullify, inverse: \Attachment.task)
    var attachments: [Attachment]? = []

    init(
        title: String = "",
        priority: String = "default",
        parentTask: TaskItem? = nil,
        folder: Folder? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.priority = priority
        self.isCompleted = false
        self.createdAt = Date()
        self.parentTask = parentTask
        self.folder = folder
    }
}
