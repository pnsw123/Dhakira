import XCTest
@testable import Note_taking

// MARK: - DateDefaultBehaviorTests
//
// Verifies the pre-launch calendar sync contract:
//
//   • No date AND no time   → NO event (detectDates returns empty)
//   • Date only (no time)   → event defaults to 12:00 PM noon
//   • Date + explicit time  → event at that exact time
//   • Time only (no date)   → event today at that time
//
// This is the rule the app ships with. If any of these break, the App Store
// build must not go out until they're fixed.

final class DateDefaultBehaviorTests: XCTestCase {

    private lazy var dateService = DateDetectionService()
    private let cal = Calendar.current

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Rule 1: No date, no time → NO event
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    func testPlainTaskProducesNoDate_CheckThisTask() {
        let results = dateService.detectDates(in: "Check this task")
        XCTAssertTrue(results.isEmpty,
            "A plain task with no date/time must not produce a calendar event")
    }

    func testPlainTaskProducesNoDate_BuyGroceries() {
        let results = dateService.detectDates(in: "Buy groceries")
        XCTAssertTrue(results.isEmpty,
            "A plain task with no date/time must not produce a calendar event")
    }

    func testPlainTaskProducesNoDate_CallMom() {
        let results = dateService.detectDates(in: "Call mom")
        XCTAssertTrue(results.isEmpty,
            "A plain task with no date/time must not produce a calendar event")
    }

    func testPlainTaskProducesNoDate_WriteReport() {
        let results = dateService.detectDates(in: "Write report")
        XCTAssertTrue(results.isEmpty,
            "A plain task with no date/time must not produce a calendar event")
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Rule 2: Date only → default to 12:00 PM noon
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    func testBareWeekdayDefaultsToNoon() {
        let results = dateService.detectDates(in: "Meeting Monday")
        guard let first = results.first else {
            return XCTFail("Expected a detected date for 'Meeting Monday'")
        }
        let hour = cal.component(.hour, from: first.date)
        let minute = cal.component(.minute, from: first.date)
        XCTAssertEqual(hour, 12, "Bare date 'Monday' must default to 12 PM (noon)")
        XCTAssertEqual(minute, 0, "Bare date 'Monday' must default to exactly :00")
        XCTAssertFalse(first.hasExplicitTime,
            "'Monday' alone should be flagged as having no explicit time")
    }

    func testBareMonthDayDefaultsToNoon() {
        let results = dateService.detectDates(in: "Deadline April 15")
        guard let first = results.first else {
            return XCTFail("Expected a detected date for 'April 15'")
        }
        let hour = cal.component(.hour, from: first.date)
        XCTAssertEqual(hour, 12, "Bare date 'April 15' must default to 12 PM (noon)")
        XCTAssertFalse(first.hasExplicitTime)
    }

    func testBareSlashDateDefaultsToNoon() {
        let results = dateService.detectDates(in: "Assignment 4/15")
        guard let first = results.first else {
            return XCTFail("Expected a detected date for '4/15'")
        }
        let hour = cal.component(.hour, from: first.date)
        XCTAssertEqual(hour, 12, "Bare date '4/15' must default to 12 PM (noon)")
        XCTAssertFalse(first.hasExplicitTime)
    }

    func testBareTomorrowDefaultsToNoon() {
        let results = dateService.detectDates(in: "Call mom tomorrow")
        guard let first = results.first else {
            return XCTFail("Expected a detected date for 'tomorrow'")
        }
        let hour = cal.component(.hour, from: first.date)
        XCTAssertEqual(hour, 12, "'tomorrow' alone must default to 12 PM (noon)")
        XCTAssertFalse(first.hasExplicitTime)
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Rule 3: Explicit time → use that time
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    func testExplicitTime5pm() {
        let results = dateService.detectDates(in: "Meeting tomorrow at 5pm")
        guard let first = results.first else {
            return XCTFail("Expected a detected date for 'tomorrow at 5pm'")
        }
        let hour = cal.component(.hour, from: first.date)
        XCTAssertEqual(hour, 17, "Explicit '5pm' must map to hour 17")
        XCTAssertTrue(first.hasExplicitTime)
    }

    func testExplicitTime930am() {
        let results = dateService.detectDates(in: "Dentist at 9:30am")
        guard let first = results.first else {
            return XCTFail("Expected a detected date for '9:30am'")
        }
        let hour = cal.component(.hour, from: first.date)
        let minute = cal.component(.minute, from: first.date)
        XCTAssertEqual(hour, 9, "Explicit '9:30am' must map to hour 9")
        XCTAssertEqual(minute, 30, "Explicit '9:30am' must map to minute 30")
        XCTAssertTrue(first.hasExplicitTime)
    }

    func testExplicitNoonIsExplicit() {
        let results = dateService.detectDates(in: "Lunch at noon")
        guard let first = results.first else {
            return XCTFail("Expected a detected date for 'noon'")
        }
        let hour = cal.component(.hour, from: first.date)
        XCTAssertEqual(hour, 12)
        XCTAssertTrue(first.hasExplicitTime,
            "'noon' is an explicit time, not a bare-date default")
    }

    func testTonightIsExplicitEvening() {
        let results = dateService.detectDates(in: "Laundry tonight")
        guard let first = results.first else {
            return XCTFail("Expected a detected date for 'tonight'")
        }
        let hour = cal.component(.hour, from: first.date)
        XCTAssertEqual(hour, 20, "'tonight' must map to 8pm (existing product decision)")
        XCTAssertTrue(first.hasExplicitTime)
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Regression guards
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    /// The phantom 8–9pm bug: bare dates must NEVER map to the current wall-clock hour.
    func testBareDateNeverUsesCurrentHour() {
        let results = dateService.detectDates(in: "Meeting Friday")
        guard let first = results.first else {
            return XCTFail("Expected a detected date for 'Friday'")
        }
        let hour = cal.component(.hour, from: first.date)
        XCTAssertEqual(hour, 12,
            "Bare 'Friday' must always be noon, never the current wall-clock hour")
    }

    /// Empty input produces nothing.
    func testEmptyInputProducesNoDates() {
        XCTAssertTrue(dateService.detectDates(in: "").isEmpty)
        XCTAssertTrue(dateService.detectDates(in: "   ").isEmpty)
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Slang / abbreviated tomorrow variants
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    //
    // All "tomorrow" slang must resolve to a date AND default to 12 PM noon
    // when no explicit time is written.

    private func assertResolvesToTomorrowNoon(_ input: String, file: StaticString = #file, line: UInt = #line) {
        let results = dateService.detectDates(in: input)
        guard let first = results.first else {
            return XCTFail("'\(input)' must resolve to a date", file: file, line: line)
        }
        let tomorrow = cal.date(byAdding: .day, value: 1, to: Date())!
        XCTAssertTrue(cal.isDate(first.date, inSameDayAs: tomorrow),
            "'\(input)' must resolve to tomorrow's date", file: file, line: line)
        let hour = cal.component(.hour, from: first.date)
        XCTAssertEqual(hour, 12, "'\(input)' with no time must default to noon", file: file, line: line)
    }

    func testTomorrowSlang_tmrw() { assertResolvesToTomorrowNoon("call mom tmrw") }
    func testTomorrowSlang_tmr()  { assertResolvesToTomorrowNoon("call mom tmr") }
    func testTomorrowSlang_tmro() { assertResolvesToTomorrowNoon("call mom tmro") }
    func testTomorrowSlang_tomo() { assertResolvesToTomorrowNoon("call mom tomo") }
    func testTomorrowSlang_2morrow() { assertResolvesToTomorrowNoon("call mom 2morrow") }
    func testTomorrowSlang_2mrw() { assertResolvesToTomorrowNoon("call mom 2mrw") }
    func testTomorrowSlang_2moro() { assertResolvesToTomorrowNoon("call mom 2moro") }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Compact time formats: "10p" = 10 PM, "8a" = 8 AM
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    func testCompactTime_10p_meansTenPM() {
        let results = dateService.detectDates(in: "meeting at 10p")
        guard let first = results.first else {
            return XCTFail("'10p' must resolve to 10 PM")
        }
        let hour = cal.component(.hour, from: first.date)
        XCTAssertEqual(hour, 22, "'10p' must map to 10 PM (hour 22)")
        XCTAssertTrue(first.hasExplicitTime)
    }

    func testCompactTime_8a_meansEightAM() {
        let results = dateService.detectDates(in: "gym at 8a")
        guard let first = results.first else {
            return XCTFail("'8a' must resolve to 8 AM")
        }
        let hour = cal.component(.hour, from: first.date)
        XCTAssertEqual(hour, 8, "'8a' must map to 8 AM (hour 8)")
        XCTAssertTrue(first.hasExplicitTime)
    }

    func testCompactTime_5p_meansFivePM() {
        let results = dateService.detectDates(in: "pickup 5p")
        guard let first = results.first else {
            return XCTFail("'5p' must resolve to 5 PM")
        }
        let hour = cal.component(.hour, from: first.date)
        XCTAssertEqual(hour, 17, "'5p' must map to 5 PM (hour 17)")
        XCTAssertTrue(first.hasExplicitTime)
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Slang + explicit time combined
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    func testTomorrowSlang_withExplicitTime_tmrw5p() {
        let results = dateService.detectDates(in: "dentist tmrw 5p")
        guard let first = results.first else {
            return XCTFail("'tmrw 5p' must resolve")
        }
        let tomorrow = cal.date(byAdding: .day, value: 1, to: Date())!
        XCTAssertTrue(cal.isDate(first.date, inSameDayAs: tomorrow))
        let hour = cal.component(.hour, from: first.date)
        XCTAssertEqual(hour, 17, "Explicit '5p' must override noon default")
        XCTAssertTrue(first.hasExplicitTime)
    }

    func testTomorrowSlang_withAtTime_2mrwAt9am() {
        let results = dateService.detectDates(in: "call 2mrw at 9am")
        guard let first = results.first else {
            return XCTFail("'2mrw at 9am' must resolve")
        }
        let hour = cal.component(.hour, from: first.date)
        XCTAssertEqual(hour, 9)
        XCTAssertTrue(first.hasExplicitTime)
    }
}
