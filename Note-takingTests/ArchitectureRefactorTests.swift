import XCTest
import SwiftData
@testable import Note_taking

// MARK: - ArchitectureRefactorTests
// Verifies behaviors introduced in issues #90–93 (architecture refactor sprint).
// Tests use public interfaces only — no mocking of internals.
// All tests run without network, iCloud, or App Group entitlements.

final class ArchitectureRefactorTests: XCTestCase {

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

    // MARK: - Issue #91: CalendarSyncCoordinator

    /// Verifies the coordinator singleton is accessible.
    /// Regression guard: ensures CalendarSyncCoordinator.swift compiled into the target.
    func testCalendarSyncCoordinatorSingletonIsAccessible() {
        let coordinator = CalendarSyncCoordinator.shared
        XCTAssertNotNil(coordinator, "CalendarSyncCoordinator.shared must not be nil")
    }

    // MARK: - Issue #93: CheckboxTapCoordinator (moved to own file)

    #if canImport(UIKit)
    /// Verifies the moved class initializes with the correct default state.
    /// Regression guard: confirms the class compiles and initializes correctly
    /// after being extracted from TaskDetailView.swift into its own file.
    func testCheckboxTapCoordinatorInitialState() {
        let coordinator = CheckboxTapCoordinator()
        XCTAssertEqual(coordinator.toggleVersion, 0,
            "toggleVersion must start at 0 — used by TaskDetailView to detect change events")
        XCTAssertNil(coordinator.lastToggledText,
            "lastToggledText must start nil — no toggle has occurred yet")
    }
    #endif

    // MARK: - Issue #91: BodyCalendarEvent model (synced by CalendarSyncCoordinator)

    /// Verifies BodyCalendarEvent inserts correctly and links to its parent task.
    /// The CalendarSyncCoordinator writes these records; if the model is broken,
    /// sync silently stops working.
    func testBodyCalendarEventLinksToTask() throws {
        let task = TaskItem(title: "Meeting prep")
        context.insert(task)

        let event = BodyCalendarEvent(
            lineText: "Meeting at 3pm",
            task: task,
            calendarEventId: "EK-001",
            googleCalendarEventId: nil
        )
        context.insert(event)
        try context.save()

        let events = try context.fetch(FetchDescriptor<BodyCalendarEvent>())
        XCTAssertEqual(events.count, 1)

        let fetched = try XCTUnwrap(events.first)
        XCTAssertEqual(fetched.lineText, "Meeting at 3pm")
        XCTAssertEqual(fetched.calendarEventId, "EK-001")
        XCTAssertNil(fetched.googleCalendarEventId)
        XCTAssertFalse(fetched.isStruck, "New events must not be struck")
        XCTAssertEqual(fetched.task?.title, "Meeting prep",
            "BodyCalendarEvent must link back to its parent TaskItem")
    }

    /// Verifies that a struck BodyCalendarEvent (externally deleted from Calendar)
    /// is correctly identified — used by CalendarSyncCoordinator to skip re-syncing.
    func testBodyCalendarEventStruckState() throws {
        let task = TaskItem(title: "Dentist")
        context.insert(task)

        let event = BodyCalendarEvent(
            lineText: "Dentist at 10am",
            task: task,
            calendarEventId: "EK-002",
            googleCalendarEventId: nil
        )
        event.isStruck = true
        context.insert(event)
        try context.save()

        let struck = try context.fetch(FetchDescriptor<BodyCalendarEvent>(
            predicate: #Predicate<BodyCalendarEvent> { $0.isStruck == true }
        ))
        XCTAssertEqual(struck.count, 1,
            "Struck events must be queryable — coordinator uses this to skip re-sync")
    }

    // MARK: - Issue #92: ThemeManager.syncActiveTasks still works

    /// Verifies that syncActiveTasks does not crash with a valid task list.
    /// This ensures the WidgetSyncBridge extraction did not break the method signature.
    /// Note: App Group UserDefaults write will silently no-op in the test environment
    /// (no group entitlement) — we only verify it doesn't throw or crash.
    func testThemeManagerSyncActiveTasksDoesNotCrash() {
        let tasks = [
            WidgetTask(id: UUID(), title: "Task A", priority: "none", hasContent: false),
            WidgetTask(id: UUID(), title: "Task B", priority: "high", hasContent: true),
        ]
        // Must not crash — App Group write will silently no-op without entitlement
        XCTAssertNoThrow(
            ThemeManager.shared.syncActiveTasks(tasks, totalCount: 2),
            "syncActiveTasks must not throw after WidgetSyncBridge extraction"
        )
    }
}
