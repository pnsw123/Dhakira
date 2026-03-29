import Combine
import EventKit
import Foundation
import OSLog

private let log = Logger(subsystem: "notes.Note-taking", category: "CalendarPermission")

/// Manages the one-time calendar permission request for the app.
///
/// The permission is requested exactly once on first app launch and the result is
/// cached in UserDefaults. All subsequent checks read from the cache without
/// prompting the user again. If permission is later changed in iOS Settings, the
/// next cold launch re-reads the live EventKit authorization status.
@MainActor
final class CalendarPermissionService: ObservableObject {

    static let shared = CalendarPermissionService()

    /// UserDefaults key for the cached permission result.
    private static let cacheKey = "calendarPermissionGranted"

    private let eventStore: EKEventStore
    @Published private(set) var isGranted: Bool

    private init(eventStore: EKEventStore = EKEventStore()) {
        self.eventStore = eventStore
        // Seed the published property from cache so callers get a synchronous answer.
        self.isGranted = UserDefaults.standard.bool(forKey: Self.cacheKey)
    }

    // MARK: - Public API

    /// Call this once from the app entry point (e.g. `Note_takingApp.init` or `.task`).
    /// Subsequent calls are cheap — they skip the system prompt if permission was
    /// already resolved, and refresh the live status from EventKit anyway.
    func requestIfNeeded() async {
        let liveStatus = EKEventStore.authorizationStatus(for: .event)

        switch liveStatus {
        case .fullAccess, .writeOnly:
            // Already granted — update cache and return without prompting.
            cache(result: true)
            return

        case .denied, .restricted:
            // User explicitly denied — update cache and return without prompting.
            cache(result: false)
            return

        case .notDetermined:
            // First time — ask the system.
            log.info("CalendarPermissionService: requesting full calendar access (first launch)")
            do {
                let granted = try await eventStore.requestFullAccessToEvents()
                log.info("CalendarPermissionService: access \(granted ? "granted" : "denied")")
                cache(result: granted)
            } catch {
                log.error("CalendarPermissionService: request failed — \(error.localizedDescription)")
                cache(result: false)
            }

        @unknown default:
            log.warning("CalendarPermissionService: unknown authorization status, treating as denied")
            cache(result: false)
        }
    }

    // MARK: - Private

    func cache(result: Bool) {
        UserDefaults.standard.set(result, forKey: Self.cacheKey)
        isGranted = result
    }
}
