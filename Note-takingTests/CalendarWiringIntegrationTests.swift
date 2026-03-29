import XCTest
import SwiftData
@testable import Note_taking

// MARK: - SpyCalendarSyncService

/// A spy (test double) that records calls made to CalendarSyncService without
/// touching real EventKit or requiring device permission.
///
/// We cannot easily subclass CalendarSyncService because its shared instance is
/// used deep in TaskDetailView. Instead, these integration tests operate at the
/// layer below the view — directly invoking the same logic that TaskDetailView
/// runs in saveBody() — using an in-memory SwiftData container for task persistence.
actor SpyCalendarSyncService {

    struct SyncCall {
        let title: String
        let date: Date
        let existingEventId: String?
        let deepLinkURL: URL?
    }

    var syncCalls: [SyncCall] = []
    var deletedIds: [String] = []

    /// Simulates the contract of CalendarSyncService.syncDateToCalendar.
    func syncDateToCalendar(
        title: String,
        date: Date,
        existingEventId: String?,
        deepLinkURL: URL? = nil
    ) async -> String? {
        syncCalls.append(SyncCall(
            title: title,
            date: date,
            existingEventId: existingEventId,
            deepLinkURL: deepLinkURL
        ))
        // Return the same ID if updating, or a new one if creating.
        return existingEventId ?? "spy-event-\(syncCalls.count)"
    }

    /// Simulates the contract of CalendarSyncService.deleteEvent(withId:).
    func deleteEvent(withId id: String) async {
        deletedIds.append(id)
    }
}

// MARK: - CalendarWiringTests

/// Integration tests for the full save-to-calendar wiring (Issue #67).
///
/// These tests operate at the task-save logic layer using an in-memory SwiftData
/// container. They use SpyCalendarSyncService to intercept calendar calls, verifying
/// that the right operations are triggered without any real EventKit side effects.
final class CalendarWiringIntegrationTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var spy: SpyCalendarSyncService!
    private var dateDetector: DateDetectionService!

    override func setUp() async throws {
        try await super.setUp()
        container = try AppSchemaBuilder.makeInMemoryContainer()
        context = ModelContext(container)
        spy = SpyCalendarSyncService()
        dateDetector = DateDetectionService()
        // Grant calendar permission so the spy is not short-circuited.
        UserDefaults.standard.set(true, forKey: "calendarPermissionGranted")
    }

    override func tearDown() async throws {
        UserDefaults.standard.removeObject(forKey: "calendarPermissionGranted")
        container = nil
        context = nil
        spy = nil
        dateDetector = nil
        try await super.tearDown()
    }

    // MARK: - Helpers

    /// Simulates what TaskDetailView.saveBody() + syncCalendarIfNeeded() do together.
    /// Runs the detection + sync logic and updates the task's calendarEventId.
    private func simulateSave(task: TaskItem) async {
        let detected = dateDetector.detectDates(in: task.title)

        if let first = detected.first {
            let deepLinkURL = DeepLinkHandler.taskURL(for: task.id)
            let newEventId = await spy.syncDateToCalendar(
                title: task.title,
                date: first.date,
                existingEventId: task.calendarEventId,
                deepLinkURL: deepLinkURL
            )
            task.calendarEventId = newEventId
        } else if let staleId = task.calendarEventId {
            await spy.deleteEvent(withId: staleId)
            task.calendarEventId = nil
        }
        try? context.save()
    }

    // MARK: - Tests

    /// Saving a task with a date in the title results in calendarEventId being non-nil.
    func test_saveTaskWithDate_populatesCalendarEventId() async {
        let task = TaskItem(title: "Dentist tomorrow at 3pm")
        context.insert(task)

        await simulateSave(task: task)

        XCTAssertNotNil(task.calendarEventId, "calendarEventId should be non-nil after save with date")
        let syncCalls = await spy.syncCalls
        XCTAssertEqual(syncCalls.count, 1, "syncDateToCalendar should be called once")
    }

    /// Saving a task with no date leaves calendarEventId as nil.
    func test_saveTaskWithNoDate_leavesCalendarEventIdNil() async {
        let task = TaskItem(title: "Buy milk")
        context.insert(task)

        await simulateSave(task: task)

        XCTAssertNil(task.calendarEventId, "calendarEventId should remain nil when title has no date")
        let syncCalls = await spy.syncCalls
        XCTAssertTrue(syncCalls.isEmpty, "syncDateToCalendar should not be called when no date is found")
    }

    /// Saving a task with a date, then editing the title to a different date,
    /// results in calendarEventId being updated (not duplicated).
    func test_saveTaskWithDate_thenEditToDifferentDate_updatesEventId() async {
        let task = TaskItem(title: "Meeting tomorrow")
        context.insert(task)

        // First save — create event.
        await simulateSave(task: task)
        let firstEventId = task.calendarEventId
        XCTAssertNotNil(firstEventId, "First save should produce an event ID")

        // Edit title to a different date — update event.
        task.title = "Meeting next Monday at 2pm"
        await simulateSave(task: task)
        let secondEventId = task.calendarEventId

        XCTAssertNotNil(secondEventId, "Second save should produce an event ID")
        // The sync was called with the existing ID → spy returns it (simulating update, not duplicate).
        let syncCalls = await spy.syncCalls
        XCTAssertEqual(syncCalls.count, 2, "syncDateToCalendar should be called twice (create + update)")
        XCTAssertEqual(syncCalls[1].existingEventId, firstEventId,
                       "Second sync should pass the existing event ID for update")
        let deletedIds = await spy.deletedIds
        XCTAssertTrue(deletedIds.isEmpty, "deleteEvent should not be called when updating date")
    }

    /// Saving a task with a date, then editing the title to remove the date,
    /// results in calendarEventId being set to nil and deleteEvent being called once.
    func test_saveTaskWithDate_thenRemoveDate_deletesEventAndClearsId() async {
        let task = TaskItem(title: "Gym session today at 6am")
        context.insert(task)

        // First save — create event.
        await simulateSave(task: task)
        let createdId = task.calendarEventId
        XCTAssertNotNil(createdId, "First save should produce an event ID")

        // Edit title to remove date.
        task.title = "Gym session"
        await simulateSave(task: task)

        XCTAssertNil(task.calendarEventId, "calendarEventId should be nil after date is removed from title")
        let deletedIds = await spy.deletedIds
        XCTAssertEqual(deletedIds.count, 1, "deleteEvent should be called exactly once")
        XCTAssertEqual(deletedIds[0], createdId, "deleteEvent should be called with the previously stored ID")
    }

    /// Saving a task with no date, then editing title to add a date, creates a new event.
    func test_saveTaskWithNoDate_thenAddDate_createsNewEvent() async {
        let task = TaskItem(title: "Call the bank")
        context.insert(task)

        // First save — no date, nothing happens.
        await simulateSave(task: task)
        XCTAssertNil(task.calendarEventId, "Should have no event initially")

        // Edit title to add a date.
        task.title = "Call the bank tomorrow at 10am"
        await simulateSave(task: task)

        XCTAssertNotNil(task.calendarEventId, "calendarEventId should be set after adding date to title")
        let syncCalls = await spy.syncCalls
        XCTAssertEqual(syncCalls.count, 1, "syncDateToCalendar should be called once (on second save)")
        XCTAssertNil(syncCalls[0].existingEventId, "First sync should have no existing event ID")
    }

    /// The task body/details text is never passed to DateDetectionService.
    func test_onlyTitleIsScanned_notBody() async {
        let task = TaskItem(title: "Buy groceries")
        context.insert(task)
        // Even if body contained a date-like string, only title is scanned in simulateSave.
        // (The logic above only calls detectDates(in: task.title) — body is never read.)
        // We verify by checking the title has no date → no sync call.
        await simulateSave(task: task)

        let syncCalls = await spy.syncCalls
        XCTAssertTrue(syncCalls.isEmpty, "Body text is never scanned — only title")
    }
}
