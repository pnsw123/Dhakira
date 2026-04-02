import EventKit
import Foundation
import Observation

/// Manages Google Calendar sync preference and detects whether Google Calendar
/// is available via CalDAV (synced through iOS/macOS system Settings).
///
/// Users control Google Calendar sync from within the app (Settings menu toggle).
/// Apple Calendar sync is always on — it cannot be disabled from here.
///
/// macOS trade-off: Google Calendar only works if added in System Settings →
/// Internet Accounts. Browser-only Google Calendar is not supported.
@Observable
@MainActor
final class CalendarSelectionService {

    static let shared = CalendarSelectionService()

    private static let appleSyncKey     = "appleCalendarSyncEnabled"
    private static let googleSyncKey    = "googleCalendarSyncEnabled"
    private static let googleWebSyncKey = "googleWebCalendarEnabled"

    /// Whether the user wants events synced to Apple Calendar. Defaults to true.
    private(set) var appleCalendarSyncEnabled: Bool

    /// Whether the user wants events synced to the local Google Calendar (CalDAV).
    private(set) var googleCalendarSyncEnabled: Bool

    /// Whether the user wants events synced via the web Google Calendar (OAuth).
    private(set) var googleWebCalendarEnabled: Bool

    private let eventStore: EKEventStore

    init(eventStore: EKEventStore = EKEventStore()) {
        self.eventStore = eventStore
        // Apple Calendar defaults to ON if the key has never been set.
        let appleRaw = UserDefaults.standard.object(forKey: Self.appleSyncKey)
        self.appleCalendarSyncEnabled  = appleRaw != nil ? UserDefaults.standard.bool(forKey: Self.appleSyncKey) : true
        self.googleCalendarSyncEnabled = UserDefaults.standard.bool(forKey: Self.googleSyncKey)
        self.googleWebCalendarEnabled  = UserDefaults.standard.bool(forKey: Self.googleWebSyncKey)
    }

    // MARK: - Preference

    func toggleAppleSync() {
        appleCalendarSyncEnabled.toggle()
        UserDefaults.standard.set(appleCalendarSyncEnabled, forKey: Self.appleSyncKey)
    }

    func toggleGoogleSync() {
        googleCalendarSyncEnabled.toggle()
        UserDefaults.standard.set(googleCalendarSyncEnabled, forKey: Self.googleSyncKey)
    }

    func toggleWebSync() {
        googleWebCalendarEnabled.toggle()
        UserDefaults.standard.set(googleWebCalendarEnabled, forKey: Self.googleWebSyncKey)
    }

    /// Re-reads all flags from UserDefaults (call when app returns to foreground).
    func refreshFromUserDefaults() {
        let appleRaw = UserDefaults.standard.object(forKey: Self.appleSyncKey)
        appleCalendarSyncEnabled  = appleRaw != nil ? UserDefaults.standard.bool(forKey: Self.appleSyncKey) : true
        googleCalendarSyncEnabled = UserDefaults.standard.bool(forKey: Self.googleSyncKey)
        googleWebCalendarEnabled  = UserDefaults.standard.bool(forKey: Self.googleWebSyncKey)
    }

    // MARK: - Detection

    /// True if at least one Google CalDAV account is set up in system Settings.
    var hasGoogleCalendar: Bool {
        eventStore.calendars(for: .event)
            .compactMap { $0.source }
            .contains { isGoogleSource($0) }
    }

    /// Returns the first writable Google Calendar if available AND sync is enabled.
    /// Returns nil if Google Calendar is not set up, or if the user disabled Google sync.
    func googleCalendar() -> EKCalendar? {
        guard googleCalendarSyncEnabled else { return nil }
        return eventStore.calendars(for: .event)
            .first { isGoogleSource($0.source) && $0.allowsContentModifications }
    }

    // MARK: - Private

    private func isGoogleSource(_ source: EKSource?) -> Bool {
        guard let source else { return false }
        guard source.sourceType == .calDAV else { return false }
        return source.title.localizedCaseInsensitiveContains("google")
            || source.sourceIdentifier.localizedCaseInsensitiveContains("com.apple.account.Google")
    }
}
