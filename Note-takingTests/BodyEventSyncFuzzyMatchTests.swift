import XCTest
@testable import Note_taking

// MARK: - BodyEventSyncFuzzyMatchTests
// Verifies the fuzzy-match similarity scoring used to decide when a body-line
// edit should UPDATE an existing BodyCalendarEvent record vs. CREATE a new one.
//
// The matching threshold is 0.80 — at or above, records are considered the same
// line and get updated (including revival of struck records per Bug #3 fix).
// Below 0.80, a new record is created.

final class BodyEventSyncFuzzyMatchTests: XCTestCase {

    private let threshold = 0.80

    // MARK: - Identity

    func testIdenticalStringsScoreOne() {
        let score = BodyEventSyncService.fuzzyMatch("gym at 5pm", "gym at 5pm")
        XCTAssertEqual(score, 1.0, accuracy: 0.001,
            "Identical strings must score 1.0")
    }

    func testBothEmptyScoreOne() {
        // Jaccard convention: both empty sets are treated as identical.
        let score = BodyEventSyncService.fuzzyMatch("", "")
        XCTAssertEqual(score, 1.0, accuracy: 0.001,
            "Both-empty must not divide by zero")
    }

    // MARK: - Above threshold (should match → update record)

    func testMinorEditAboveThreshold() {
        // Adding one word to a 5-word line: 5/6 ≈ 0.83 (above 0.80)
        let score = BodyEventSyncService.fuzzyMatch(
            "pick up laundry on monday",
            "pick up red laundry on monday"
        )
        XCTAssertGreaterThanOrEqual(score, threshold,
            "Minor edit (one added word) must still match existing record")
    }

    func testCaseInsensitiveMatches() {
        let score = BodyEventSyncService.fuzzyMatch("DENTIST at 5pm", "dentist at 5pm")
        XCTAssertEqual(score, 1.0, accuracy: 0.001,
            "Case should not affect fuzzy match")
    }

    // MARK: - Below threshold (should NOT match → create new record)

    func testCompletelyDifferentBelowThreshold() {
        let score = BodyEventSyncService.fuzzyMatch("dentist appointment", "buy groceries")
        XCTAssertLessThan(score, threshold,
            "Unrelated lines must not match")
    }

    func testTwoOverlappingWordsBelowThreshold() {
        // "meet alice tomorrow" vs "meet bob at work" = only "meet" overlaps
        // → 1 / 7 ≈ 0.14 — well below threshold
        let score = BodyEventSyncService.fuzzyMatch("meet alice tomorrow", "meet bob at work")
        XCTAssertLessThan(score, threshold,
            "Single-word overlap must not be enough to match")
    }

    // MARK: - Edge cases

    func testOneEmptyScoresZero() {
        let score = BodyEventSyncService.fuzzyMatch("dentist at 5pm", "")
        XCTAssertEqual(score, 0.0, accuracy: 0.001,
            "One-sided empty string must score 0.0")
    }

    func testExtraWhitespaceIsIgnoredByTokenizer() {
        let score = BodyEventSyncService.fuzzyMatch(
            "meet alice tomorrow",
            "meet  alice  tomorrow"
        )
        XCTAssertEqual(score, 1.0, accuracy: 0.001,
            "Extra whitespace must be normalized away")
    }
}
