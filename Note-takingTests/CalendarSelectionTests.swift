import XCTest
import EventKit
@testable import Note_taking

// MARK: - CalendarSelectionTests
// Verifies the Apple Calendar selection logic that prevents duplicate events
// when users have Gmail synced to Apple Calendar via CalDAV.
//
// Bug context: `defaultCalendarForNewEvents` returns whichever calendar the user
// set as default in iOS Settings — often Gmail. The old code leaked events into
// Gmail via the "Apple Calendar" sync path, producing duplicates.
//
// Contract under test (CalendarSelector.selectBestAppleCalendar):
//   1. Prefers iCloud source.
//   2. Falls back to any writable non-Google, non-Subscribed calendar.
//   3. Returns nil if nothing safe exists (never falls back to Gmail).

final class CalendarSelectionTests: XCTestCase {

    // MARK: - Test 1: iCloud is preferred when present
    func testPicksiCloudWhenPresent() {
        let entries: [CalendarEntry] = [
            CalendarEntry(title: "Home", sourceTitle: "iCloud", sourceType: .calDAV, isWritable: true),
            CalendarEntry(title: "Work", sourceTitle: "Gmail", sourceType: .calDAV, isWritable: true),
        ]
        let chosen = CalendarSelector.selectBestAppleCalendar(from: entries)
        XCTAssertEqual(chosen?.sourceTitle, "iCloud",
            "Must prefer iCloud over Gmail")
    }

    // MARK: - Test 2: Only Gmail present → returns nil (never leaks)
    func testReturnsNilWhenOnlyGmailAvailable() {
        let entries: [CalendarEntry] = [
            CalendarEntry(title: "Work", sourceTitle: "Gmail", sourceType: .calDAV, isWritable: true),
            CalendarEntry(title: "Personal", sourceTitle: "Google", sourceType: .calDAV, isWritable: true),
        ]
        let chosen = CalendarSelector.selectBestAppleCalendar(from: entries)
        XCTAssertNil(chosen,
            "Must NOT leak events into Gmail/Google calendars — return nil instead")
    }

    // MARK: - Test 3: Both iCloud + Gmail → picks iCloud
    func testPicksiCloudOverGmail() {
        let entries: [CalendarEntry] = [
            CalendarEntry(title: "Work", sourceTitle: "Gmail", sourceType: .calDAV, isWritable: true),
            CalendarEntry(title: "Personal", sourceTitle: "iCloud", sourceType: .calDAV, isWritable: true),
            CalendarEntry(title: "Shared", sourceTitle: "Google", sourceType: .calDAV, isWritable: true),
        ]
        let chosen = CalendarSelector.selectBestAppleCalendar(from: entries)
        XCTAssertEqual(chosen?.sourceTitle, "iCloud",
            "iCloud must win even when Gmail appears first")
    }

    // MARK: - Test 4: Subscribed calendars are filtered out
    func testSubscribedCalendarsAreSkipped() {
        let entries: [CalendarEntry] = [
            CalendarEntry(title: "Holidays", sourceTitle: "Subscriptions", sourceType: .subscribed, isWritable: true),
            CalendarEntry(title: "Birthdays", sourceTitle: "Birthdays", sourceType: .birthdays, isWritable: false),
        ]
        let chosen = CalendarSelector.selectBestAppleCalendar(from: entries)
        XCTAssertNil(chosen,
            "Subscribed/read-only calendars must never be chosen")
    }

    // MARK: - Test 5: Read-only calendars filtered out
    func testReadOnlyCalendarsAreSkipped() {
        let entries: [CalendarEntry] = [
            CalendarEntry(title: "TeamCal", sourceTitle: "iCloud", sourceType: .calDAV, isWritable: false),
        ]
        let chosen = CalendarSelector.selectBestAppleCalendar(from: entries)
        XCTAssertNil(chosen,
            "Read-only iCloud calendar must not be chosen")
    }

    // MARK: - Test 6: Empty list → nil safely
    func testEmptyListReturnsNil() {
        let chosen = CalendarSelector.selectBestAppleCalendar(from: [])
        XCTAssertNil(chosen,
            "Empty calendar list must return nil without crashing")
    }

    // MARK: - Test 7: Local (non-network) calendar is acceptable fallback
    func testLocalCalendarAcceptedWhenNoiCloud() {
        let entries: [CalendarEntry] = [
            CalendarEntry(title: "On My iPhone", sourceTitle: "On My iPhone", sourceType: .local, isWritable: true),
        ]
        let chosen = CalendarSelector.selectBestAppleCalendar(from: entries)
        XCTAssertEqual(chosen?.sourceTitle, "On My iPhone",
            "Local calendar must be acceptable when no iCloud exists")
    }

    // MARK: - Test 8: Case-insensitive iCloud match
    func testiCloudMatchIsCaseInsensitive() {
        let entries: [CalendarEntry] = [
            CalendarEntry(title: "Home", sourceTitle: "icloud", sourceType: .calDAV, isWritable: true),
        ]
        let chosen = CalendarSelector.selectBestAppleCalendar(from: entries)
        XCTAssertEqual(chosen?.sourceTitle, "icloud",
            "iCloud matching must be case-insensitive")
    }
}
