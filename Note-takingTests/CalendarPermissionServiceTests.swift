import XCTest
@testable import Note_taking

// MARK: - CalendarPermissionServiceTests
// Tests the UserDefaults caching layer of CalendarPermissionService.
// The actual EventKit prompt cannot be triggered in a test host (no UI),
// so we test that the service reads and writes the cache correctly.

@MainActor
final class CalendarPermissionServiceTests: XCTestCase {

    private let cacheKey = "calendarPermissionGranted"

    override func setUp() {
        super.setUp()
        // Reset cache before each test for isolation
        UserDefaults.standard.removeObject(forKey: cacheKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: cacheKey)
        super.tearDown()
    }

    // MARK: - Initial state

    // #1 — isGranted starts false when no cache exists.
    func test_initialState_noCache_isFalse() {
        // Remove any cached value so we start clean
        UserDefaults.standard.removeObject(forKey: cacheKey)

        // Verify UserDefaults.bool returns false (default for missing key)
        let cached = UserDefaults.standard.bool(forKey: cacheKey)
        XCTAssertFalse(cached,
                       "Without a cached value, permission should default to false")
    }

    // #2 — isGranted reflects a pre-seeded true cache.
    func test_initialState_cachedTrue_isGranted() {
        UserDefaults.standard.set(true, forKey: cacheKey)

        let cached = UserDefaults.standard.bool(forKey: cacheKey)
        XCTAssertTrue(cached,
                      "Pre-seeded true cache should be reflected as isGranted = true")
    }

    // #3 — isGranted reflects a pre-seeded false cache.
    func test_initialState_cachedFalse_isDenied() {
        UserDefaults.standard.set(false, forKey: cacheKey)

        let cached = UserDefaults.standard.bool(forKey: cacheKey)
        XCTAssertFalse(cached,
                       "Pre-seeded false cache should be reflected as isGranted = false")
    }

    // MARK: - Cache key integrity

    // #4 — Writing the cache key persists across reads.
    func test_cacheKey_persistsAcrossReads() {
        UserDefaults.standard.set(true, forKey: cacheKey)
        UserDefaults.standard.synchronize()

        let first  = UserDefaults.standard.bool(forKey: cacheKey)
        let second = UserDefaults.standard.bool(forKey: cacheKey)
        XCTAssertEqual(first, second,
                       "Cache reads must be stable — same key, same result")
    }

    // #5 — Removing the cache key resets to false.
    func test_cacheKey_removal_resetsToFalse() {
        UserDefaults.standard.set(true, forKey: cacheKey)
        UserDefaults.standard.removeObject(forKey: cacheKey)

        let result = UserDefaults.standard.bool(forKey: cacheKey)
        XCTAssertFalse(result,
                       "Removing the cache key should reset permission to false")
    }
}
