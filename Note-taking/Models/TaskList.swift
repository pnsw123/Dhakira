import Foundation
import SwiftData

@Model
final class TaskList {
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date()

    var folder: Folder?

    @Relationship(deleteRule: .nullify, inverse: \TaskItem.taskList)
    var tasks: [TaskItem]? = []

    init(name: String = "", folder: Folder? = nil) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.folder = folder
    }
}
