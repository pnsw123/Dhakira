import XCTest
import SwiftData
@testable import Note_taking

// MARK: - ModelTests
// Tests basic init, defaults, and relationships for all SwiftData models:
// TaskItem, TaskList, Folder, Attachment

final class ModelTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        container = try AppSchemaBuilder.makeInMemoryContainer()
        context   = container.mainContext
    }

    override func tearDownWithError() throws {
        container = nil
        context   = nil
    }

    // MARK: - TaskItem

    // #1 — TaskItem has a non-nil UUID after init.
    func test_taskItem_hasUUID() {
        let task = TaskItem(title: "My Task")
        XCTAssertNotNil(task.id, "TaskItem must have a UUID after init")
    }

    // #2 — Default priority is "default".
    func test_taskItem_defaultPriority() {
        let task = TaskItem(title: "Task")
        XCTAssertEqual(task.priority, "default",
                       "TaskItem default priority should be 'default'")
    }

    // #3 — isCompleted starts false.
    func test_taskItem_isCompletedStartsFalse() {
        let task = TaskItem(title: "New task")
        XCTAssertFalse(task.isCompleted, "New task must not start as completed")
    }

    // #4 — isDeleted starts false.
    func test_taskItem_isDeletedStartsFalse() {
        let task = TaskItem(title: "Fresh task")
        XCTAssertFalse(task.isDeleted, "New task must not start as soft-deleted")
    }

    // #5 — Two TaskItems have unique IDs.
    func test_taskItem_idsAreUnique() {
        let t1 = TaskItem(title: "First")
        let t2 = TaskItem(title: "Second")
        XCTAssertNotEqual(t1.id, t2.id, "Each TaskItem must get a unique UUID")
    }

    // #6 — Priority can be set to "high".
    func test_taskItem_highPriority() {
        let task = TaskItem(title: "Urgent", priority: "high")
        XCTAssertEqual(task.priority, "high")
    }

    // #7 — createdAt is set to approximately now.
    func test_taskItem_createdAtIsNow() {
        let before = Date()
        let task = TaskItem(title: "Timed task")
        let after = Date()
        XCTAssertGreaterThanOrEqual(task.createdAt, before)
        XCTAssertLessThanOrEqual(task.createdAt, after)
    }

    // #8 — body starts nil.
    func test_taskItem_bodyStartsNil() {
        let task = TaskItem(title: "No body yet")
        XCTAssertNil(task.body, "New task body must start as nil")
    }

    // #9 — sortOrder starts at 0.
    func test_taskItem_sortOrderStartsZero() {
        let task = TaskItem(title: "Ordered")
        XCTAssertEqual(task.sortOrder, 0)
    }

    // #10 — Subtasks list is empty (not nil) by default.
    func test_taskItem_subtasksStartEmpty() {
        let task = TaskItem(title: "Parent")
        XCTAssertNotNil(task.subtasks)
        XCTAssertEqual(task.subtasks?.count, 0,
                       "New task should have 0 subtasks")
    }

    // MARK: - TaskList

    // #11 — TaskList has a non-nil UUID.
    func test_taskList_hasUUID() {
        let list = TaskList(name: "My List")
        XCTAssertNotNil(list.id)
    }

    // #12 — TaskList name is set correctly.
    func test_taskList_nameSetCorrectly() {
        let list = TaskList(name: "Work Tasks")
        XCTAssertEqual(list.name, "Work Tasks")
    }

    // #13 — Two task lists have unique IDs.
    func test_taskList_idsAreUnique() {
        let l1 = TaskList(name: "List A")
        let l2 = TaskList(name: "List B")
        XCTAssertNotEqual(l1.id, l2.id)
    }

    // #14 — TaskList createdAt is set to approximately now.
    func test_taskList_createdAtIsNow() {
        let before = Date()
        let list = TaskList(name: "Timed list")
        let after = Date()
        XCTAssertGreaterThanOrEqual(list.createdAt, before)
        XCTAssertLessThanOrEqual(list.createdAt, after)
    }

    // #15 — TaskList can be associated with a Folder.
    func test_taskList_canBelongToFolder() {
        let folder = Folder(name: "Work")
        let list   = TaskList(name: "Sprint 1", folder: folder)
        XCTAssertEqual(list.folder?.name, "Work",
                       "TaskList should reference its parent Folder")
    }

    // MARK: - Folder

    // #16 — Folder has a non-nil UUID.
    func test_folder_hasUUID() {
        let folder = Folder(name: "Projects")
        XCTAssertNotNil(folder.id)
    }

    // #17 — Folder name is set correctly.
    func test_folder_nameSetCorrectly() {
        let folder = Folder(name: "Personal")
        XCTAssertEqual(folder.name, "Personal")
    }

    // #18 — Two folders have unique IDs.
    func test_folder_idsAreUnique() {
        let f1 = Folder(name: "A")
        let f2 = Folder(name: "B")
        XCTAssertNotEqual(f1.id, f2.id)
    }

    // #19 — Folder parentFolder defaults to nil (top-level).
    func test_folder_parentFolderDefaultsToNil() {
        let folder = Folder(name: "Root")
        XCTAssertNil(folder.parentFolder,
                     "Top-level folder must have no parentFolder")
    }

    // #20 — Folder can have a parentFolder (nested).
    func test_folder_canBeNested() {
        let parent = Folder(name: "Parent")
        let child  = Folder(name: "Child", parentFolder: parent)
        XCTAssertEqual(child.parentFolder?.name, "Parent",
                       "Nested folder must reference its parent")
    }

    // #21 — Folder subfolders starts empty.
    func test_folder_subfoldersStartEmpty() {
        let folder = Folder(name: "Empty parent")
        XCTAssertNotNil(folder.subfolders)
        XCTAssertEqual(folder.subfolders?.count ?? 0, 0)
    }

    // #22 — Folder createdAt is set to approximately now.
    func test_folder_createdAtIsNow() {
        let before = Date()
        let folder = Folder(name: "Timestamped")
        let after  = Date()
        XCTAssertGreaterThanOrEqual(folder.createdAt, before)
        XCTAssertLessThanOrEqual(folder.createdAt, after)
    }

    // MARK: - Attachment

    // #23 — Attachment has a non-nil UUID.
    func test_attachment_hasUUID() {
        let attachment = Attachment(type: "image", fileName: "photo.jpg")
        XCTAssertNotNil(attachment.id)
    }

    // #24 — Attachment type is set correctly.
    func test_attachment_typeSetCorrectly() {
        let attachment = Attachment(type: "audio", fileName: "recording.m4a")
        XCTAssertEqual(attachment.type, "audio")
    }

    // #25 — Attachment fileName is set correctly.
    func test_attachment_fileNameSetCorrectly() {
        let attachment = Attachment(type: "file", fileName: "report.pdf")
        XCTAssertEqual(attachment.fileName, "report.pdf")
    }

    // #26 — Attachment data starts nil.
    func test_attachment_dataStartsNil() {
        let attachment = Attachment(type: "image", fileName: "img.png")
        XCTAssertNil(attachment.data,
                     "New attachment data should default to nil until set")
    }

    // #27 — Two attachments have unique IDs.
    func test_attachment_idsAreUnique() {
        let a1 = Attachment(type: "image", fileName: "a.png")
        let a2 = Attachment(type: "image", fileName: "b.png")
        XCTAssertNotEqual(a1.id, a2.id)
    }

    // #28 — Attachment can be linked to a TaskItem.
    func test_attachment_canBelongToTask() {
        let task       = TaskItem(title: "Task with attachment")
        let attachment = Attachment(type: "image", fileName: "pic.jpg", task: task)
        XCTAssertEqual(attachment.task?.title, "Task with attachment",
                       "Attachment should reference its parent TaskItem")
    }

    // MARK: - Persistence round-trip

    // #29 — TaskItem persists and is fetchable.
    func test_taskItem_persistsAndFetches() throws {
        let task = TaskItem(title: "Persisted task")
        context.insert(task)
        try context.save()

        let descriptor = FetchDescriptor<TaskItem>()
        let all = try context.fetch(descriptor)
        XCTAssertTrue(all.contains { $0.title == "Persisted task" },
                      "Saved TaskItem must be fetchable from the context")
    }

    // #30 — Folder + TaskList + TaskItem hierarchy persists correctly.
    func test_hierarchy_persists() throws {
        let folder = Folder(name: "Persisted Folder")
        let list   = TaskList(name: "Persisted List", folder: folder)
        let task   = TaskItem(title: "Persisted Task", taskList: list)

        context.insert(folder)
        context.insert(list)
        context.insert(task)
        try context.save()

        let taskDescriptor = FetchDescriptor<TaskItem>()
        let tasks = try context.fetch(taskDescriptor)
        let found = tasks.first { $0.title == "Persisted Task" }
        XCTAssertNotNil(found, "TaskItem must be found after saving the full hierarchy")
        XCTAssertEqual(found?.taskList?.name, "Persisted List",
                       "TaskItem must reference the correct TaskList after persistence")
    }
}
