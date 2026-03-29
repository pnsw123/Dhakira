import XCTest
import EventKit
@testable import Note_taking

// MARK: - MockEKEventStore

/// A test double (mock) for EKEventStore that avoids touching real calendar data
/// and requires no device permission during test execution.
///
/// We subclass EKEventStore because it is a concrete class (no protocol exists in EventKit).
/// Subclassing is the standard Apple-recommended approach for testing EventKit code.
final class MockEKEventStore: EKEventStore {

    // MARK: - Stored events (in-memory dictionary keyed by eventIdentifier)

    /// Events currently tracked by this mock store.
    var storedEvents: [String: EKEvent] = [:]

    /// Set to true to simulate a missing default calendar (edge case).
    var simulateNoDefaultCalendar = false

    /// Tracks how many times save(_, span:) was called.
    var saveCallCount = 0

    /// Tracks how many times remove(_, span:) was called.
    var removeCallCount = 0

    // MARK: - EKEventStore overrides

    override var defaultCalendarForNewEvents: EKCalendar? {
        guard !simulateNoDefaultCalendar else { return nil }
        // Return any calendar — in tests we just need a non-nil value.
        return super.defaultCalendarForNewEvents
    }

    override func event(withIdentifier identifier: String) -> EKEvent? {
        return storedEvents[identifier]
    }

    override func save(_ event: EKEvent, span: EKSpan) throws {
        saveCallCount += 1
        // Assign a deterministic fake identifier if not already set.
        if event.eventIdentifier == nil {
            // EKEvent.eventIdentifier is read-only after saving, but since we're
            // in a mock context we use setValue(_:forKey:) to inject a test value.
            let fakeId = "mock-event-\(UUID().uuidString)"
            event.setValue(fakeId, forKey: "eventIdentifier")
        }
        storedEvents[event.eventIdentifier!] = event
    }

    override func remove(_ event: EKEvent, span: EKSpan) throws {
        removeCallCount += 1
        storedEvents.removeValue(forKey: event.eventIdentifier ?? "")
    }
}

// MARK: - CalendarSyncServiceTests

/// Unit tests for CalendarSyncService (Issue #65).
///
/// Uses MockEKEventStore to avoid real calendar access and device permission requirements.
final class CalendarSyncServiceTests: XCTestCase {

    private var mockStore: MockEKEventStore!
    private var sut: CalendarSyncService!

    override func setUp() async throws {
        try await super.setUp()
        mockStore = MockEKEventStore()
        sut = CalendarSyncService(eventStore: mockStore)
        // Grant permission for all tests (permission is checked via CalendarPermissionService.shared.isGranted).
        // We need the isGranted flag to be true. Since CalendarPermissionService reads a UserDefaults key,
        // set it directly for the test session.
        UserDefaults.standard.set(true, forKey: "calendarPermissionGranted")
    }

    override func tearDown() async throws {
        // Clean up the permission flag so other tests start fresh.
        UserDefaults.standard.removeObject(forKey: "calendarPermissionGranted")
        mockStore = nil
        sut = nil
        try await super.tearDown()
    }

    // MARK: - syncDateToCalendar

    /// Calling sync with no existing ID creates a new event and returns a non-nil identifier.
    func test_sync_withNoExistingId_createsNewEvent() async {
        let eventId = await sut.syncDateToCalendar(
            title: "Dentist tomorrow at 3pm",
            date: Date().addingTimeInterval(86400),
            existingEventId: nil
        )
        XCTAssertNotNil(eventId, "Should return a non-nil event identifier")
        XCTAssertEqual(mockStore.saveCallCount, 1, "Should call save exactly once")
    }

    /// Calling sync with a valid existing ID updates the event and does not create a duplicate.
    func test_sync_withValidExistingId_updatesEventWithoutDuplicate() async {
        // First create.
        let firstId = await sut.syncDateToCalendar(
            title: "Meeting today",
            date: Date(),
            existingEventId: nil
        )
        let countAfterFirst = mockStore.storedEvents.count

        // Then update.
        let secondId = await sut.syncDateToCalendar(
            title: "Meeting today (updated)",
            date: Date().addingTimeInterval(3600),
            existingEventId: firstId
        )
        XCTAssertEqual(mockStore.storedEvents.count, countAfterFirst,
                       "No extra event should be created on update")
        XCTAssertEqual(mockStore.saveCallCount, 2, "save should be called once for create + once for update")
        XCTAssertNotNil(secondId, "Should return an event identifier after update")
    }

    /// Calling sync with a stale existing ID (event deleted externally) creates a new event.
    func test_sync_withStaleExistingId_createsNewEvent() async {
        // Do NOT add anything to mockStore.storedEvents — simulate an externally-deleted event.
        let staleId = "stale-event-id-123"

        let newId = await sut.syncDateToCalendar(
            title: "Doctor appointment",
            date: Date().addingTimeInterval(7200),
            existingEventId: staleId
        )
        XCTAssertNotNil(newId, "Should return a new event identifier when stale ID is provided")
        XCTAssertNotEqual(newId, staleId, "New ID should differ from the stale one")
        XCTAssertEqual(mockStore.saveCallCount, 1, "Should create one new event")
    }

    /// Every newly created event has exactly one EKAlarm set to 15 minutes before.
    func test_sync_newEvent_hasExactlyOneAlarm15MinutesBefore() async {
        let eventId = await sut.syncDateToCalendar(
            title: "Stand-up",
            date: Date().addingTimeInterval(3600),
            existingEventId: nil
        )
        guard let id = eventId, let event = mockStore.storedEvents[id] else {
            XCTFail("Event should exist in mock store")
            return
        }
        let alarms = event.alarms ?? []
        XCTAssertEqual(alarms.count, 1, "Event should have exactly one alarm")
        XCTAssertEqual(alarms[0].relativeOffset, -900,
                       "Alarm offset should be -900 seconds (15 minutes)")
    }

    /// When a deepLinkURL is provided, the event's url field contains that URL.
    func test_sync_withDeepLinkURL_setsEventURL() async {
        let deepLink = URL(string: "prodnote://task/\(UUID().uuidString)")!
        let eventId = await sut.syncDateToCalendar(
            title: "Task with deep link",
            date: Date().addingTimeInterval(3600),
            existingEventId: nil,
            deepLinkURL: deepLink
        )
        guard let id = eventId, let event = mockStore.storedEvents[id] else {
            XCTFail("Event should exist in mock store")
            return
        }
        XCTAssertEqual(event.url, deepLink, "Event URL should match the provided deep link")
    }

    // MARK: - deleteEvent

    /// Calling deleteEvent with a valid event ID removes the event.
    func test_deleteEvent_withValidId_removesEvent() async {
        // Seed a "pre-existing" event in the mock store by going through sync first.
        let eventId = await sut.syncDateToCalendar(
            title: "Event to delete",
            date: Date().addingTimeInterval(3600),
            existingEventId: nil
        )
        guard let id = eventId else {
            XCTFail("Setup: sync should succeed")
            return
        }
        XCTAssertNotNil(mockStore.storedEvents[id], "Event should exist before deletion")

        await sut.deleteEvent(withId: id)

        XCTAssertNil(mockStore.storedEvents[id], "Event should be removed after deletion")
        XCTAssertEqual(mockStore.removeCallCount, 1, "remove should be called once")
    }

    /// Calling deleteEvent with an invalid/already-deleted ID does not crash.
    func test_deleteEvent_withInvalidId_doesNotCrash() async {
        // Should complete without throwing or crashing.
        await sut.deleteEvent(withId: "non-existent-id")
        XCTAssertEqual(mockStore.removeCallCount, 0,
                       "remove should not be called for a non-existent event ID")
    }
}
