import Foundation

// MARK: - AudioLink
// Value type that carries all metadata for a saved voice recording.
// Lives entirely in memory — the persistent representation is the
// prodnote-audio:// URL stored as an NSAttributedString .link attribute.

struct AudioLink: Equatable, Identifiable {
    let uuid: UUID
    let name: String
    let duration: TimeInterval   // seconds
    let date: Date

    var id: UUID { uuid }

    /// The permanent on-disk URL for this recording.
    var fileURL: URL { AudioStorageService.permanentURL(for: uuid) }
}

// MARK: - AudioLinkBuilder
// Single place that encodes and decodes prodnote-audio:// URLs.
//
// URL format:
//   prodnote-audio://{uuid}?name={percent-encoded}&duration={seconds-double}&date={ISO8601}
//
// Example:
//   prodnote-audio://550e8400-e29b-41d4-a716-446655440000
//       ?name=Recording%20Mar%2029&duration=42.3&date=2026-03-29T14%3A22%3A00Z
//
// Why this format:
//   • RTF serialization stores .link values as plain strings — all components survive.
//   • On deserialization from RTF, .link comes back as String (not URL).
//     AudioTapCoordinator handles both String and URL .link values.

enum AudioLinkBuilder {

    static let scheme = "prodnote-audio"

    private static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    // MARK: Encode

    /// Build a prodnote-audio:// URL from components.
    static func buildURL(uuid: UUID, name: String, duration: TimeInterval, date: Date) -> URL {
        var components     = URLComponents()
        components.scheme  = scheme
        components.host    = uuid.uuidString.lowercased()
        components.queryItems = [
            URLQueryItem(name: "name",     value: name),
            URLQueryItem(name: "duration", value: String(duration)),
            URLQueryItem(name: "date",     value: iso8601.string(from: date)),
        ]
        // Force-unwrap is safe: all components are valid by construction.
        return components.url!
    }

    // MARK: Decode

    /// Decode a URL back into an AudioLink.
    /// Returns nil for non-audio URLs, malformed input, or missing required fields.
    /// Handles both `URL` and `String` .link values (RTF deserializes links as String).
    static func parse(_ url: URL) -> AudioLink? {
        guard url.scheme?.lowercased() == scheme else { return nil }

        guard let uuidString = url.host,
              let uuid = UUID(uuidString: uuidString) else { return nil }

        guard let components  = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems  = components.queryItems else { return nil }

        func query(_ key: String) -> String? {
            queryItems.first(where: { $0.name == key })?.value
        }

        let name     = query("name") ?? "Recording"
        let duration = Double(query("duration") ?? "") ?? 0
        let date     = query("date").flatMap { iso8601.date(from: $0) } ?? Date()

        return AudioLink(uuid: uuid, name: name, duration: duration, date: date)
    }

    /// Parse from a String value (RTF round-trip returns .link as String, not URL).
    static func parse(_ string: String) -> AudioLink? {
        guard let url = URL(string: string) else { return nil }
        return parse(url)
    }

    /// Returns true if the URL (or string) uses the prodnote-audio scheme.
    static func isAudioLink(_ url: URL) -> Bool {
        url.scheme?.lowercased() == scheme
    }

    static func isAudioLink(_ string: String) -> Bool {
        string.lowercased().hasPrefix(scheme + "://")
    }
}
