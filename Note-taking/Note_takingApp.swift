import SwiftUI
import SwiftData
import OSLog

private let log = Logger(subsystem: "notes.Note-taking", category: "App")

@main
struct Note_takingApp: App {
    let container: ModelContainer

    init() {
        log.info("App init — building ModelContainer")
        let schema = Schema([TaskItem.self, Attachment.self, Folder.self, TaskList.self])
        let config = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .automatic
        )
        do {
            container = try ModelContainer(for: schema, configurations: [config])
            log.info("ModelContainer ready ✓")
        } catch {
            log.critical("ModelContainer FAILED to init: \(error.localizedDescription)")
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    await cleanupEmptyTasks()
                    await seedDefaultFolderIfNeeded()
                    await cleanup30DayDeletedTasks()
                }
        }
        .modelContainer(container)
    }

    @MainActor
    private func cleanupEmptyTasks() async {
        log.debug("cleanupEmptyTasks: scanning for empty-title tasks")
        let context = container.mainContext
        do {
            var descriptor = FetchDescriptor<TaskItem>()
            descriptor.predicate = #Predicate<TaskItem> { task in
                task.title == ""
            }
            let emptyTasks = try context.fetch(descriptor)
            guard !emptyTasks.isEmpty else {
                log.debug("cleanupEmptyTasks: nothing to clean")
                return
            }
            log.info("cleanupEmptyTasks: deleting \(emptyTasks.count) empty task(s)")
            for task in emptyTasks {
                context.delete(task)
            }
            try context.save()
            log.info("cleanupEmptyTasks: done ✓")
        } catch {
            log.error("cleanupEmptyTasks FAILED: \(error.localizedDescription)")
        }
    }

    /// Seeds a Default Folder + "Tasks" TaskList on first launch (runs only once).
    /// Migrates any orphaned TaskItems (no taskList) into the default TaskList.
    @MainActor
    private func seedDefaultFolderIfNeeded() async {
        let context = container.mainContext
        do {
            let folderDescriptor = FetchDescriptor<Folder>()
            let existingFolders = try context.fetch(folderDescriptor)
            guard existingFolders.isEmpty else {
                log.debug("seedDefaultFolder: folders already exist, skipping seed")
                // Still migrate orphaned tasks if needed
                await migrateOrphanedTasks(context: context)
                return
            }

            log.info("seedDefaultFolder: seeding Default Folder + Tasks TaskList")
            let defaultFolder = Folder(name: "Default")
            context.insert(defaultFolder)

            let defaultTaskList = TaskList(name: "Tasks", folder: defaultFolder)
            context.insert(defaultTaskList)

            try context.save()
            log.info("seedDefaultFolder: done ✓")

            await migrateOrphanedTasks(context: context)
        } catch {
            log.error("seedDefaultFolder FAILED: \(error.localizedDescription)")
        }
    }

    /// Assigns any TaskItems without a taskList to the first available TaskList.
    @MainActor
    private func migrateOrphanedTasks(context: ModelContext) async {
        do {
            var orphanDescriptor = FetchDescriptor<TaskItem>()
            orphanDescriptor.predicate = #Predicate<TaskItem> { task in
                task.taskList == nil
            }
            let orphans = try context.fetch(orphanDescriptor)
            guard !orphans.isEmpty else { return }

            var listDescriptor = FetchDescriptor<TaskList>()
            listDescriptor.fetchLimit = 1
            let lists = try context.fetch(listDescriptor)
            guard let defaultList = lists.first else { return }

            log.info("migrateOrphanedTasks: migrating \(orphans.count) tasks to '\(defaultList.name)'")
            for task in orphans {
                task.taskList = defaultList
            }
            try context.save()
        } catch {
            log.error("migrateOrphanedTasks FAILED: \(error.localizedDescription)")
        }
    }

    /// Permanently deletes tasks soft-deleted more than 30 days ago.
    @MainActor
    private func cleanup30DayDeletedTasks() async {
        let context = container.mainContext
        let cutoff = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        do {
            var descriptor = FetchDescriptor<TaskItem>()
            descriptor.predicate = #Predicate<TaskItem> { task in
                task.isDeleted == true && task.deletedAt != nil
            }
            let deletedTasks = try context.fetch(descriptor)
            let toRemove = deletedTasks.filter { ($0.deletedAt ?? Date()) < cutoff }
            guard !toRemove.isEmpty else { return }
            log.info("cleanup30DayDeletedTasks: permanently removing \(toRemove.count) expired task(s)")
            for task in toRemove {
                context.delete(task)
            }
            try context.save()
        } catch {
            log.error("cleanup30DayDeletedTasks FAILED: \(error.localizedDescription)")
        }
    }
}
