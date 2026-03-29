import Foundation
import OSLog

private let log = Logger(subsystem: "notes.Note-taking", category: "DeepLink")

/// Encodes task UUIDs into deep-link URLs and decodes incoming URLs back to UUIDs.
///
/// URL scheme:  prodnote://task/{uuid}
/// Example:     prodnote://task/550e8400-e29b-41d4-a716-446655440000
///
/// Registration: the scheme is declared in project.pbxproj via
/// INFOPLIST_KEY_CFBundleURLTypes (added alongside the calendar permission keys).
enum DeepLinkHandler {

    // MARK: - Constants

    static let scheme = "prodnote"
    static let taskHost = "task"

    // MARK: - Encoding

    /// Produces a `prodnote://task/{uuid}` URL for the given task ID.
    static func taskURL(for taskId: UUID) -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = taskHost
        components.path = "/\(taskId.uuidString)"
        guard let url = components.url else {
            log.error("taskURL: failed to build URL for \(taskId)")
            // Fallback: construct raw string — always valid for a UUID
            return URL(string: "\(scheme)://\(taskHost)/\(taskId.uuidString)")!
        }
        return url
    }

    // MARK: - Decoding

    /// Extracts the task UUID from a `prodnote://task/{uuid}` URL.
    /// Returns `nil` for any unrecognised or malformed URL without throwing.
    static func handleIncomingURL(_ url: URL) -> UUID? {
        guard url.scheme?.lowercased() == scheme else {
            log.debug("handleIncomingURL: unrecognised scheme '\(url.scheme ?? "nil")' — ignoring")
            return nil
        }
        guard url.host?.lowercased() == taskHost else {
            log.debug("handleIncomingURL: unrecognised host '\(url.host ?? "nil")' — ignoring")
            return nil
        }
        // Path is "/UUID" — strip the leading slash.
        let rawPath = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !rawPath.isEmpty, let uuid = UUID(uuidString: rawPath) else {
            log.warning("handleIncomingURL: could not parse UUID from path '\(url.path)'")
            return nil
        }
        log.info("handleIncomingURL: resolved task UUID \(uuid)")
        return uuid
    }
}
