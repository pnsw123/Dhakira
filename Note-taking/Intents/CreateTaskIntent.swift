import AppIntents
import SwiftData

struct CreateTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Create Task"
    static var description: IntentDescription = "Creates a new task in the app"

    @Parameter(title: "Title")
    var title: String

    @Parameter(title: "Details", default: nil)
    var details: String?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try ModelContainer(for: TaskItem.self, Attachment.self, Folder.self)
        let context = container.mainContext

        let task = TaskItem(title: title)
        if let details = details {
            task.body = details.data(using: .utf8)
        }
        context.insert(task)
        try context.save()

        return .result(dialog: "Created task: \(title)")
    }
}
