import Foundation
import SwiftData

@Model
final class Folder {
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date()

    var parentFolder: Folder?

    @Relationship(deleteRule: .nullify, inverse: \Folder.parentFolder)
    var subfolders: [Folder]? = []

    @Relationship(deleteRule: .nullify, inverse: \TaskItem.folder)
    var tasks: [TaskItem]? = []

    init(name: String = "", parentFolder: Folder? = nil) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.parentFolder = parentFolder
    }
}
