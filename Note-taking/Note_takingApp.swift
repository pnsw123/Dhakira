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
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    await cleanupEmptyTasks()
                }
        }
        .modelContainer(container)
    }

    /// Deferred cleanup — runs in the background after UI is visible.
    @MainActor
    private func cleanupEmptyTasks() async {
        let context = container.mainContext
        do {
            var descriptor = FetchDescriptor<TaskItem>()
            descriptor.predicate = #Predicate<TaskItem> { task in
                task.title == ""
            }
            let emptyTasks = try context.fetch(descriptor)
            guard !emptyTasks.isEmpty else { return }
            for task in emptyTasks {
                context.delete(task)
            }
            try context.save()
        } catch {
            // Non-fatal — cleanup is best-effort
            print("Empty-task cleanup failed: \(error)")
        }
    }
}
