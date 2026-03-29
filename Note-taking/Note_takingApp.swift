import SwiftUI
import SwiftData
import OSLog

@main
struct Note_takingApp: App {
    let container: ModelContainer

    private let log = Logger(subsystem: "notes.Note-taking", category: "App")

    /// Task UUID received via deep link (prodnote://task/{uuid}).
    /// Passed into ContentView so it can navigate to the correct task detail page.
    @State private var pendingDeepLinkTaskId: UUID? = nil

    init() {
        log.info("App init — building ModelContainer via AppSchemaBuilder")
        do {
            container = try AppSchemaBuilder.makeContainer()
            log.info("ModelContainer ready ✓")
        } catch {
            log.critical("ModelContainer FAILED to init: \(error.localizedDescription)")
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(pendingDeepLinkTaskId: $pendingDeepLinkTaskId)
                .task {
                    // Request calendar permission once on first launch (Issue #60).
                    await CalendarPermissionService.shared.requestIfNeeded()
                    // Run all startup work on a background actor so the UI renders immediately.
                    let worker = StartupWorker(modelContainer: container)
                    await worker.run()
                }
                // Warm launch: app already running, user taps a calendar event deep link.
                .onOpenURL { url in
                    log.info("onOpenURL: \(url.absoluteString)")
                    if let taskId = DeepLinkHandler.handleIncomingURL(url) {
                        pendingDeepLinkTaskId = taskId
                    }
                }
        }
        .modelContainer(container)
    }
}

// MARK: - StartupWorker

/// Runs one-time and recurring startup maintenance on a background actor,
/// keeping the main thread (and the UI) completely unblocked.
@ModelActor
private actor StartupWorker {

    private let log = Logger(subsystem: "notes.Note-taking", category: "StartupWorker")

    func run() {
        cleanupEmptyTasks()
        seedDefaultFolderIfNeeded()
        cleanup30DayDeletedTasks()
    }

    // MARK: Cleanup empty tasks

    private func cleanupEmptyTasks() {
        log.debug("cleanupEmptyTasks: scanning for empty-title tasks")
        let descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate<TaskItem> { $0.title == "" }
        )
        guard let emptyTasks = try? modelContext.fetch(descriptor), !emptyTasks.isEmpty else {
            log.debug("cleanupEmptyTasks: nothing to clean")
            return
        }
        log.info("cleanupEmptyTasks: deleting \(emptyTasks.count) empty task(s)")
        emptyTasks.forEach { modelContext.delete($0) }
        try? modelContext.save()
        log.info("cleanupEmptyTasks: done ✓")
    }

    // MARK: Seed default folder

    private func seedDefaultFolderIfNeeded() {
        guard let existingFolders = try? modelContext.fetch(FetchDescriptor<Folder>()) else { return }

        if existingFolders.isEmpty {
            log.info("seedDefaultFolder: seeding Default Folder + Tasks TaskList")
            let defaultFolder = Folder(name: "Default")
            modelContext.insert(defaultFolder)
            let defaultTaskList = TaskList(name: "Tasks", folder: defaultFolder)
            modelContext.insert(defaultTaskList)
            try? modelContext.save()
            log.info("seedDefaultFolder: done ✓")
        } else {
            log.debug("seedDefaultFolder: folders already exist, skipping seed")
        }

        migrateOrphanedTasks()
    }

    // MARK: Migrate orphaned tasks

    private func migrateOrphanedTasks() {
        let orphanDescriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate<TaskItem> { $0.taskList == nil }
        )
        guard let orphans = try? modelContext.fetch(orphanDescriptor), !orphans.isEmpty else { return }

        var listDescriptor = FetchDescriptor<TaskList>()
        listDescriptor.fetchLimit = 1
        guard let lists = try? modelContext.fetch(listDescriptor),
              let defaultList = lists.first else { return }

        log.info("migrateOrphanedTasks: migrating \(orphans.count) tasks to '\(defaultList.name)'")
        orphans.forEach { $0.taskList = defaultList }
        try? modelContext.save()
    }

    // MARK: Purge 30-day deleted tasks

    private func cleanup30DayDeletedTasks() {
        let cutoff = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        let descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate<TaskItem> { $0.isDeleted == true }
        )
        guard let deletedTasks = try? modelContext.fetch(descriptor), !deletedTasks.isEmpty else { return }

        // Stamp any orphaned deleted tasks that are missing a deletedAt timestamp
        var needsSave = false
        for task in deletedTasks where task.deletedAt == nil {
            task.deletedAt = Date()
            needsSave = true
        }
        if needsSave {
            log.info("cleanup30DayDeletedTasks: stamped \(deletedTasks.filter { $0.deletedAt != nil }.count) orphaned task(s) with deletedAt")
        }

        let toRemove = deletedTasks.filter { ($0.deletedAt ?? Date()) < cutoff }
        guard !toRemove.isEmpty else {
            if needsSave { try? modelContext.save() }
            return
        }
        log.info("cleanup30DayDeletedTasks: permanently removing \(toRemove.count) expired task(s)")
        toRemove.forEach { modelContext.delete($0) }
        try? modelContext.save()
    }
}
