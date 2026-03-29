import XCTest
@testable import Note_taking

/// Unit tests for DateDetectionService (Issue #64).
///
/// These are pure logic tests — no device, no calendar access, no mocking required.
/// DateDetectionService wraps NSDataDetector, so tests verify that the wrapper
/// correctly surfaces what Apple's engine detects.
final class DateDetectionServiceTests: XCTestCase {

    private var sut: DateDetectionService!

    override func setUp() {
        super.setUp()
        sut = DateDetectionService()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Positive cases

    /// Title with "today at 5pm" → one DetectedDate on today's date.
    func test_titleWithTodayAtFivePm_returnsOneDate() {
        let results = sut.detectDates(in: "Meeting today at 5pm")
        XCTAssertEqual(results.count, 1, "Expected exactly one date")
        let detected = results[0].date
        XCTAssertTrue(
            Calendar.current.isDateInToday(detected),
            "Detected date should be today, got \(detected)"
        )
    }

    /// Title with "tomorrow" → one DetectedDate matching tomorrow.
    func test_titleWithTomorrow_returnsOneDate() {
        let results = sut.detectDates(in: "Submit report tomorrow")
        XCTAssertEqual(results.count, 1, "Expected exactly one date")
        let detected = results[0].date
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        XCTAssertTrue(
            Calendar.current.isDate(detected, inSameDayAs: tomorrow),
            "Detected date should be tomorrow, got \(detected)"
        )
    }

    /// Title with "next Monday at 3pm" → one DetectedDate on the upcoming Monday.
    func test_titleWithNextMonday_returnsUpcomingMonday() {
        let results = sut.detectDates(in: "Team standup next Monday at 3pm")
        XCTAssertEqual(results.count, 1, "Expected exactly one date")
        let detected = results[0].date
        let weekday = Calendar.current.component(.weekday, from: detected)
        // weekday 2 = Monday in Gregorian calendar
        XCTAssertEqual(weekday, 2, "Detected date should be a Monday, got weekday \(weekday)")
        // Must be in the future
        XCTAssertGreaterThan(detected, Date(), "Detected date should be in the future")
    }

    /// Title with a specific month-day like "March 5th" → one DetectedDate on March 5.
    func test_titleWithSpecificMonthDay_returnsCorrectDate() {
        let results = sut.detectDates(in: "Doctor appointment March 5th")
        XCTAssertEqual(results.count, 1, "Expected exactly one date")
        let detected = results[0].date
        let components = Calendar.current.dateComponents([.month, .day], from: detected)
        XCTAssertEqual(components.month, 3, "Expected month 3 (March), got \(String(describing: components.month))")
        XCTAssertEqual(components.day, 5, "Expected day 5, got \(String(describing: components.day))")
    }

    // MARK: - Negative / edge cases

    /// Title with no date expression → empty array.
    func test_titleWithNoDate_returnsEmpty() {
        let results = sut.detectDates(in: "Buy milk and eggs")
        XCTAssertTrue(results.isEmpty, "Expected no dates, got \(results.count)")
    }

    /// Title with two explicit date expressions → two DetectedDates.
    /// Uses specific month/day strings that NSDataDetector reliably parses as two separate events.
    func test_titleWithTwoDates_returnsTwoDates() {
        let results = sut.detectDates(in: "Dentist on March 5th, and follow-up on April 10th")
        XCTAssertGreaterThanOrEqual(results.count, 2,
                                    "Expected at least two dates, got \(results.count)")
    }

    /// Empty string input → empty array without crashing.
    func test_emptyString_returnsEmpty() {
        let results = sut.detectDates(in: "")
        XCTAssertTrue(results.isEmpty, "Empty string should return no dates")
    }

    // MARK: - Performance

    /// Each call should complete in well under 1 second.
    func test_performance() {
        measure {
            _ = sut.detectDates(in: "Dentist appointment next Tuesday at 2pm")
        }
    }
}
