import XCTest
import SwiftData
@testable import Note_taking

// MARK: - SwiftDataModelTests
// Validates the local model layer using an in-memory SwiftData container.
// These tests run on the Simulator with NO network or iCloud required.
// They prove that models save, relate, and purge correctly —
// a prerequisite before trusting iCloud to sync them.

final class SwiftDataModelTests: XCTestCase {

    // Each test gets its own isolated in-memory container.
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

    // MARK: - Test 1: Create task and fetch it back

    func testCreateTaskPersists() throws {
        let task = TaskItem(title: "Buy groceries")
        context.insert(task)
        try context.save()

        let results = try context.fetch(FetchDescriptor<TaskItem>())
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "Buy groceries")
    }

    // MARK: - Test 2: Soft-deleted task excluded from active query

    func testDeleteTaskSoftDeletes() throws {
        let active  = TaskItem(title: "Active task")
        let deleted = TaskItem(title: "Deleted task")
        deleted.isDeleted = true
        deleted.deletedAt = Date()

        context.insert(active)
        context.insert(deleted)
        try context.save()

        // Active query — mirrors what TaskListView uses
        let activeDescriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate { !$0.isDeleted }
        )
        let activeResults = try context.fetch(activeDescriptor)
        XCTAssertEqual(activeResults.count, 1)
        XCTAssertEqual(activeResults.first?.title, "Active task")

        // Deleted query — mirrors what RecentlyDeletedView uses
        let deletedDescriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate { $0.isDeleted }
        )
        let deletedResults = try context.fetch(deletedDescriptor)
        XCTAssertEqual(deletedResults.count, 1)
        XCTAssertEqual(deletedResults.first?.title, "Deleted task")
    }

    // MARK: - Test 3: Folder ↔ TaskItem relationship

    func testFolderWithTasksRelationship() throws {
        let folder = Folder(name: "Work")
        let task   = TaskItem(title: "Write report", folder: folder)

        context.insert(folder)
        context.insert(task)
        try context.save()

        // Fetch folder back and confirm relationship is intact
        let folders = try context.fetch(FetchDescriptor<Folder>())
        let fetched = try XCTUnwrap(folders.first)
        XCTAssertEqual(fetched.name, "Work")
        XCTAssertEqual(fetched.tasks?.count, 1)
        XCTAssertEqual(fetched.tasks?.first?.title, "Write report")

        // Fetch task back and confirm inverse
        let tasks = try context.fetch(FetchDescriptor<TaskItem>())
        XCTAssertEqual(tasks.first?.folder?.name, "Work")
    }

    // MARK: - Test 4: TaskList contains attached tasks

    func testTaskListContainsTasks() throws {
        let list  = TaskList(name: "Sprint 1")
        let task1 = TaskItem(title: "Design", taskList: list)
        let task2 = TaskItem(title: "Build", taskList: list)
        let task3 = TaskItem(title: "Ship", taskList: list)

        context.insert(list)
        context.insert(task1)
        context.insert(task2)
        context.insert(task3)
        try context.save()

        let lists = try context.fetch(FetchDescriptor<TaskList>())
        let fetched = try XCTUnwrap(lists.first)
        XCTAssertEqual(fetched.name, "Sprint 1")
        XCTAssertEqual(fetched.tasks?.count, 3)
    }

    // MARK: - Test 5: Attachment links back to parent TaskItem

    func testAttachmentLinksToTask() throws {
        let task       = TaskItem(title: "Note with photo")
        let attachment = Attachment(type: "image", fileName: "photo.jpg", task: task)

        context.insert(task)
        context.insert(attachment)
        try context.save()

        let attachments = try context.fetch(FetchDescriptor<Attachment>())
        let fetched     = try XCTUnwrap(attachments.first)
        XCTAssertEqual(fetched.fileName, "photo.jpg")
        XCTAssertEqual(fetched.task?.title, "Note with photo")

        // Verify reverse lookup via task
        let tasks = try context.fetch(FetchDescriptor<TaskItem>())
        XCTAssertEqual(tasks.first?.attachments?.count, 1)
        XCTAssertEqual(tasks.first?.attachments?.first?.fileName, "photo.jpg")
    }

    // MARK: - Test 6: 30-day purge logic identifies expired deleted tasks

    func testPurgeLogicIdentifiesExpiredDeletedTasks() throws {
        let cutoff = Date().addingTimeInterval(-30 * 24 * 60 * 60)

        // Expired (31 days ago) — should be purged
        let expired       = TaskItem(title: "Expired task")
        expired.isDeleted = true
        expired.deletedAt = Date().addingTimeInterval(-31 * 24 * 60 * 60)

        // Recent (10 days ago) — should be kept
        let recent        = TaskItem(title: "Recent deleted")
        recent.isDeleted  = true
        recent.deletedAt  = Date().addingTimeInterval(-10 * 24 * 60 * 60)

        context.insert(expired)
        context.insert(recent)
        try context.save()

        // Replicate the purge filter from StartupWorker.cleanup30DayDeletedTasks()
        let allDeleted = try context.fetch(FetchDescriptor<TaskItem>(
            predicate: #Predicate { $0.isDeleted == true }
        ))
        let toRemove = allDeleted.filter { ($0.deletedAt ?? Date()) < cutoff }

        XCTAssertEqual(toRemove.count, 1)
        XCTAssertEqual(toRemove.first?.title, "Expired task")
    }
}
