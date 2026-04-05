import Foundation
import OSLog

private let log = Logger(subsystem: "notes.Note-taking", category: "GoogleCalendarAPI")

/// Creates, updates, and deletes Google Calendar events via the REST API.
///
/// Requires the user to be authenticated via GoogleAuthService.
/// Handles token expiry transparently — auto-retries once after a 401.
final class GoogleCalendarAPIService {

    static let shared = GoogleCalendarAPIService()

    private static let baseURL = "https://www.googleapis.com/calendar/v3/calendars/primary/events"

    // MARK: - Create / Update

    /// Creates a new event or updates an existing one.
    ///
    /// - Parameters:
    ///   - title: The event title (task name with date text stripped).
    ///   - date: The event start time.
    ///   - existingId: The Google Calendar event ID if previously created.
    ///   - deepLinkURL: Optional link back to the task in the app.
    /// - Returns: The Google Calendar event ID to store on the task, or nil on failure.
    func syncEvent(
        title: String,
        date: Date,
        endDate: Date? = nil,
        existingId: String?,
        deepLinkURL: URL? = nil
    ) async -> String? {
        guard let token = await GoogleAuthService.shared.validToken() else {
            log.warning("syncEvent: no valid token — user not connected")
            return existingId
        }

        let body = makeEventBody(title: title, date: date, endDate: endDate, deepLinkURL: deepLinkURL)

        if let existingId {
            // Try to update the existing event.
            let result = await request(
                method: "PUT",
                url: URL(string: "\(Self.baseURL)/\(existingId)")!,
                body: body,
                token: token
            )
            if let id = result { return id }
            // Fall through to create a new event if update fails (event may have been deleted).
        }

        // Create a new event.
        return await request(method: "POST", url: URL(string: Self.baseURL)!, body: body, token: token)
    }

    // MARK: - Delete

    /// Deletes a Google Calendar event by its ID.
    /// Safe to call with a stale ID — does nothing if the event no longer exists.
    func deleteEvent(id: String) async {
        guard let token = await GoogleAuthService.shared.validToken() else { return }
        await deleteEvent(id: id, token: token, isRetry: false)
    }

    private func deleteEvent(id: String, token: String, isRetry: Bool) async {
        guard let url = URL(string: "\(Self.baseURL)/\(id)") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if status == 204 || status == 404 {
                log.info("deleteEvent: '\(id)' removed (status \(status)) ✓")
            } else if status == 401 && !isRetry {
                // Token expired — clear stale token and retry once with a fresh one.
                log.warning("deleteEvent: 401 — refreshing token and retrying")
                await GoogleAuthService.shared.clearAccessToken()
                guard let freshToken = await GoogleAuthService.shared.validToken() else { return }
                await deleteEvent(id: id, token: freshToken, isRetry: true)
            } else {
                log.warning("deleteEvent: unexpected status \(status) for '\(id)'")
            }
        } catch {
            log.error("deleteEvent: \(error.localizedDescription)")
        }
    }

    // MARK: - Batch existence check (Issue #87)

    /// Checks which event IDs still exist in Google Calendar.
    /// Returns the set of IDs that are confirmed to exist.
    /// Uses a single list-events API call filtered by time range for efficiency.
    ///
    /// If the token is expired/invalid, returns nil (skip check, don't mark as deleted).
    func existingEventIds(from ids: Set<String>) async -> Set<String>? {
        guard !ids.isEmpty else { return [] }
        guard let token = await GoogleAuthService.shared.validToken() else {
            log.warning("existingEventIds: no valid token — skipping check")
            return nil  // nil = skip, not "all deleted"
        }
        return await existingEventIds(from: ids, token: token, isRetry: false)
    }

    private func existingEventIds(from ids: Set<String>, token: String, isRetry: Bool) async -> Set<String>? {
        // Fetch recent + upcoming events (30 days back, 365 days ahead) in batches.
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let timeMin = formatter.string(from: Date().addingTimeInterval(-30 * 86400))
        let timeMax = formatter.string(from: Date().addingTimeInterval(365 * 86400))

        var allEventIds: Set<String> = []
        var pageToken: String? = nil

        repeat {
            var urlStr = "\(Self.baseURL)?timeMin=\(timeMin)&timeMax=\(timeMax)&maxResults=250&fields=items(id)"
            if let pt = pageToken {
                urlStr += "&pageToken=\(pt)"
            }
            guard let url = URL(string: urlStr) else { break }

            var req = URLRequest(url: url)
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            do {
                let (data, response) = try await URLSession.shared.data(for: req)
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                if status == 401 && !isRetry {
                    log.warning("existingEventIds: 401 — refreshing token and retrying")
                    await GoogleAuthService.shared.clearAccessToken()
                    guard let freshToken = await GoogleAuthService.shared.validToken() else { return nil }
                    return await existingEventIds(from: ids, token: freshToken, isRetry: true)
                }
                guard (200..<300).contains(status) else {
                    log.warning("existingEventIds: HTTP \(status) — aborting check")
                    return nil  // don't mark anything as deleted on error
                }
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                if let items = json?["items"] as? [[String: Any]] {
                    for item in items {
                        if let id = item["id"] as? String {
                            allEventIds.insert(id)
                        }
                    }
                }
                pageToken = json?["nextPageToken"] as? String
            } catch {
                log.error("existingEventIds: \(error.localizedDescription)")
                return nil  // skip on error
            }
        } while pageToken != nil

        let found = ids.intersection(allEventIds)
        log.info("existingEventIds: checked \(ids.count) IDs, \(found.count) still exist")
        return found
    }

    // MARK: - Private

    private func request(method: String, url: URL, body: Data, token: String) async -> String? {
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = body

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0

            // 401 = token expired — clear only the access token and try refreshing.
            // IMPORTANT: Do NOT call disconnect() here — that nukes the refresh token
            // too, making it impossible to recover. Only invalidate the stale access token.
            if status == 401 {
                log.warning("\(method) \(url): 401 — clearing stale access token and refreshing")
                await GoogleAuthService.shared.clearAccessToken()
                guard let freshToken = await GoogleAuthService.shared.validToken() else { return nil }
                return await request(method: method, url: url, body: body, token: freshToken)
            }

            guard (200..<300).contains(status) else {
                let errorBody = String(data: data, encoding: .utf8) ?? "(no body)"
                log.error("\(method) \(url): HTTP \(status) — \(errorBody)")
                return nil
            }

            let event = try JSONDecoder().decode(EventResponse.self, from: data)
            log.info("\(method) event ✓ id='\(event.id)'")
            return event.id
        } catch {
            log.error("\(method) \(url): \(error.localizedDescription)")
            return nil
        }
    }

    private func makeEventBody(title: String, date: Date, endDate: Date? = nil, deepLinkURL: URL?) -> Data {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        let start = formatter.string(from: date)
        let end   = formatter.string(from: endDate ?? date.addingTimeInterval(3600))
        let tz    = TimeZone.current.identifier  // e.g. "America/New_York"

        let event: [String: Any] = [
            "summary": title,
            "start": ["dateTime": start, "timeZone": tz],
            "end":   ["dateTime": end,   "timeZone": tz],
            "reminders": [
                "useDefault": false,
                "overrides":  [["method": "popup", "minutes": 15]],
            ],
            // Note: "source" field removed — Google rejects non-HTTPS URLs
            // (our deep link uses dhakira:// scheme which causes HTTP 400).
            "description": deepLinkURL.map { "Open in Dhakira: \($0.absoluteString)" } ?? "",
        ]

        let data = (try? JSONSerialization.data(withJSONObject: event)) ?? Data()
        log.debug("makeEventBody: \(String(data: data, encoding: .utf8) ?? "")")
        return data
    }
}

// MARK: - Response model

private struct EventResponse: Decodable {
    let id: String
}
