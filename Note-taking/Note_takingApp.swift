import SwiftUI
import SwiftData

@main
struct Note_takingApp: App {
    let container: ModelContainer

    init() {
        let schema = Schema([TaskItem.self, Attachment.self, Folder.self])
        let config = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .automatic
        )
        do {
            container = try ModelContainer(for: schema, configurations: [config])
            // One-time cleanup: delete all empty test tasks
            let context = container.mainContext
            let allTasks = try context.fetch(FetchDescriptor<TaskItem>())
            for task in allTasks where task.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                context.delete(task)
            }
            try context.save()
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
