import XCTest
import SwiftData
@testable import Note_taking

final class AppSchemaBuilderTests: XCTestCase {

    // MARK: - #1 makeInMemoryContainer creates a usable container

    func test_makeInMemoryContainer_succeeds() throws {
        let container = try AppSchemaBuilder.makeInMemoryContainer()
        XCTAssertNotNil(container, "makeInMemoryContainer should return a valid ModelContainer")
    }

    // MARK: - #2 All four model types are in the schema

    func test_allModelsAreRegistered() throws {
        // This is the CI test that prevents the "Siri breaks silently" bug (Issue #52).
        // If any model is missing from AppSchemaBuilder.registeredTypes,
        // SwiftData throws when you try to insert an instance of that type.
        let container = try AppSchemaBuilder.makeInMemoryContainer()
        let ctx = container.mainContext

        let folder = Folder(name: "Test Folder")
        ctx.insert(folder)

        let list = TaskList(name: "Test List", folder: folder)
        ctx.insert(list)

        let task = TaskItem(title: "Test Task", taskList: list)
        ctx.insert(task)

        let attachment = Attachment()
        ctx.insert(attachment)

        XCTAssertNoThrow(try ctx.save(),
            "All four models must be in the schema — if this fails, AppSchemaBuilder.registeredTypes is incomplete")
    }

    // MARK: - #3 In-memory container is isolated (no shared state between tests)

    func test_inMemoryContainer_isIsolated() throws {
        let container1 = try AppSchemaBuilder.makeInMemoryContainer()
        let ctx1 = container1.mainContext
        ctx1.insert(TaskItem(title: "Only in container 1"))
        try ctx1.save()

        let container2 = try AppSchemaBuilder.makeInMemoryContainer()
        let ctx2 = container2.mainContext
        let tasks = try ctx2.fetch(FetchDescriptor<TaskItem>())

        XCTAssertTrue(tasks.isEmpty,
            "A fresh in-memory container should not see data from another container")
    }
}
