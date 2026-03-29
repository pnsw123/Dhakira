import XCTest
@testable import Note_taking

/// Unit tests for DeepLinkHandler (Issue #66).
///
/// Pure logic tests — no device, no navigation, no UI, no async required.
final class DeepLinkHandlerTests: XCTestCase {

    private let knownUUID = UUID(uuidString: "550E8400-E29B-41D4-A716-446655440000")!

    // MARK: - taskURL(for:)

    /// The generated URL must contain the UUID string.
    func test_taskURL_containsUUID() {
        let url = DeepLinkHandler.taskURL(for: knownUUID)
        XCTAssertTrue(
            url.absoluteString.contains(knownUUID.uuidString),
            "URL should contain the UUID string; got \(url.absoluteString)"
        )
    }

    /// The generated URL must use the registered custom scheme, not http/https.
    func test_taskURL_usesCustomScheme() {
        let url = DeepLinkHandler.taskURL(for: knownUUID)
        XCTAssertEqual(url.scheme, DeepLinkHandler.scheme,
                       "URL scheme should be '\(DeepLinkHandler.scheme)', got '\(url.scheme ?? "nil")'")
        XCTAssertNotEqual(url.scheme, "http")
        XCTAssertNotEqual(url.scheme, "https")
    }

    // MARK: - handleIncomingURL(_:)

    /// A URL produced by taskURL must decode back to the original UUID.
    func test_handleIncomingURL_decodesKnownURL() {
        let url = DeepLinkHandler.taskURL(for: knownUUID)
        let decoded = DeepLinkHandler.handleIncomingURL(url)
        XCTAssertEqual(decoded, knownUUID, "Decoded UUID should match original")
    }

    /// A completely unrelated URL should return nil.
    func test_handleIncomingURL_unrelatedURL_returnsNil() {
        let url = URL(string: "https://example.com/path")!
        XCTAssertNil(DeepLinkHandler.handleIncomingURL(url),
                     "Unrelated URL should return nil")
    }

    /// A URL with the right scheme but wrong host should return nil.
    func test_handleIncomingURL_wrongHost_returnsNil() {
        let url = URL(string: "\(DeepLinkHandler.scheme)://other/\(knownUUID.uuidString)")!
        XCTAssertNil(DeepLinkHandler.handleIncomingURL(url),
                     "Wrong host should return nil")
    }

    /// A URL with the right scheme/host but missing UUID in path should return nil.
    func test_handleIncomingURL_missingUUID_returnsNil() {
        let url = URL(string: "\(DeepLinkHandler.scheme)://\(DeepLinkHandler.taskHost)/not-a-uuid")!
        XCTAssertNil(DeepLinkHandler.handleIncomingURL(url),
                     "Malformed UUID path should return nil")
    }

    /// A URL with no path at all should return nil without crashing.
    func test_handleIncomingURL_emptyPath_returnsNil() {
        let url = URL(string: "\(DeepLinkHandler.scheme)://\(DeepLinkHandler.taskHost)")!
        XCTAssertNil(DeepLinkHandler.handleIncomingURL(url),
                     "Empty path should return nil")
    }

    // MARK: - Round-trip

    /// Encode a UUID to URL then decode back — must produce the original UUID.
    func test_roundTrip_encodeThenDecode_preservesUUID() {
        let original = UUID()
        let url = DeepLinkHandler.taskURL(for: original)
        let decoded = DeepLinkHandler.handleIncomingURL(url)
        XCTAssertEqual(decoded, original, "Round-trip should preserve the UUID")
    }

    /// Round-trip with multiple UUIDs to ensure no state leak between calls.
    func test_roundTrip_multipleUUIDs_allPreserved() {
        let uuids = (0..<10).map { _ in UUID() }
        for original in uuids {
            let url = DeepLinkHandler.taskURL(for: original)
            let decoded = DeepLinkHandler.handleIncomingURL(url)
            XCTAssertEqual(decoded, original, "Round-trip for \(original) should preserve UUID")
        }
    }
}
