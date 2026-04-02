import XCTest
import SwiftData
@testable import Note_taking

// MARK: - SwiftDataModelTests
// Validates the local model layer using an in-memory SwiftData container.
// No network, no iCloud, no entitlements required — runs on Simulator in ~5s.
// Predicate style matches the production codebase (== true / == false, never !).

final class SwiftDataModelTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try AppSchemaBuilder.makeInMemoryContainer()
        context   = ModelContext(container)
    }

    override func tearDownWithError() throws {
        context   = nil
        container = nil
        try super.tearDownWithError()
    }

    // MARK: - 1. Create task and fetch it back

    func testCreateTaskPersists() throws {
        let task = TaskItem(title: "Buy groceries")
        context.insert(task)
        try context.save()

        let results = try context.fetch(FetchDescriptor<TaskItem>())
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "Buy groceries")
    }

    // MARK: - 2. Soft-deleted task excluded from active query

    func testDeleteTaskSoftDeletes() throws {
        let active  = TaskItem(title: "Active task")
        let deleted = TaskItem(title: "Deleted task")
        deleted.isTrashed = true
        deleted.deletedAt = Date()

        context.insert(active)
        context.insert(deleted)
        try context.save()

        // Matches the predicate pattern used in production (Note_takingApp.swift)
        let activeResults = try context.fetch(FetchDescriptor<TaskItem>(
            predicate: #Predicate<TaskItem> { $0.isTrashed == false }
        ))
        XCTAssertEqual(activeResults.count, 1)
        XCTAssertEqual(activeResults.first?.title, "Active task")

        let deletedResults = try context.fetch(FetchDescriptor<TaskItem>(
            predicate: #Predicate<TaskItem> { $0.isTrashed == true }
        ))
        XCTAssertEqual(deletedResults.count, 1)
        XCTAssertEqual(deletedResults.first?.title, "Deleted task")
    }

    // MARK: - 3. Folder ↔ TaskItem relationship

    func testFolderWithTasksRelationship() throws {
        let folder = Folder(name: "Work")
        context.insert(folder)

        // Insert task AFTER folder is in context so SwiftData can wire the inverse
        let task = TaskItem(title: "Write report", folder: folder)
        context.insert(task)
        try context.save()

        // Forward: task knows its folder
        let tasks = try context.fetch(FetchDescriptor<TaskItem>())
        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(tasks.first?.folder?.name, "Work")

        // Inverse: folder knows its tasks
        let folders = try context.fetch(FetchDescriptor<Folder>())
        let fetched = try XCTUnwrap(folders.first)
        XCTAssertEqual(fetched.name, "Work")
        XCTAssertEqual(fetched.tasks?.count, 1)
        XCTAssertEqual(fetched.tasks?.first?.title, "Write report")
    }

    // MARK: - 4. TaskList contains attached tasks

    func testTaskListContainsTasks() throws {
        let list = TaskList(name: "Sprint 1")
        context.insert(list)

        let task1 = TaskItem(title: "Design", taskList: list)
        let task2 = TaskItem(title: "Build",  taskList: list)
        let task3 = TaskItem(title: "Ship",   taskList: list)
        context.insert(task1)
        context.insert(task2)
        context.insert(task3)
        try context.save()

        let lists = try context.fetch(FetchDescriptor<TaskList>())
        let fetched = try XCTUnwrap(lists.first)
        XCTAssertEqual(fetched.name, "Sprint 1")
        XCTAssertEqual(fetched.tasks?.count, 3)
    }

    // MARK: - 5. Attachment links back to parent TaskItem

    func testAttachmentLinksToTask() throws {
        let task = TaskItem(title: "Note with photo")
        context.insert(task)

        // Insert attachment AFTER task is in context
        let attachment = Attachment(type: "image", fileName: "photo.jpg", task: task)
        context.insert(attachment)
        try context.save()

        // Forward: attachment → task
        let attachments = try context.fetch(FetchDescriptor<Attachment>())
        let fetched = try XCTUnwrap(attachments.first)
        XCTAssertEqual(fetched.fileName, "photo.jpg")
        XCTAssertEqual(fetched.task?.title, "Note with photo")

        // Inverse: task → attachments
        let tasks = try context.fetch(FetchDescriptor<TaskItem>())
        XCTAssertEqual(tasks.first?.attachments?.count, 1)
        XCTAssertEqual(tasks.first?.attachments?.first?.fileName, "photo.jpg")
    }

    // MARK: - 6. 30-day purge filter matches production logic

    func testPurgeLogicIdentifiesExpiredDeletedTasks() throws {
        // Replicates the cutoff from StartupWorker.cleanup30DayDeletedTasks()
        let cutoff = Date().addingTimeInterval(-30 * 24 * 60 * 60)

        let expired = TaskItem(title: "Expired task")
        expired.isTrashed = true
        expired.deletedAt = Date().addingTimeInterval(-31 * 24 * 60 * 60) // 31 days ago

        let recent = TaskItem(title: "Recent deleted")
        recent.isTrashed = true
        recent.deletedAt = Date().addingTimeInterval(-10 * 24 * 60 * 60)  // 10 days ago

        context.insert(expired)
        context.insert(recent)
        try context.save()

        let allDeleted = try context.fetch(FetchDescriptor<TaskItem>(
            predicate: #Predicate<TaskItem> { $0.isTrashed == true }
        ))
        XCTAssertEqual(allDeleted.count, 2)

        let toRemove = allDeleted.filter { ($0.deletedAt ?? Date()) < cutoff }
        XCTAssertEqual(toRemove.count, 1)
        XCTAssertEqual(toRemove.first?.title, "Expired task")
    }
}
