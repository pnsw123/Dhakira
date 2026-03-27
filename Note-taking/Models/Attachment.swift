import Foundation
import SwiftData

@Model
final class Attachment {
    var id: UUID = UUID()
    var type: String = ""
    var data: Data?
    var fileName: String?
    var createdAt: Date = Date()

    var task: TaskItem?

    init(type: String = "", fileName: String? = nil, task: TaskItem? = nil) {
        self.id = UUID()
        self.type = type
        self.createdAt = Date()
        self.fileName = fileName
        self.task = task
    }
}
