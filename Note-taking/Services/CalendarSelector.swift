import EventKit
import Foundation

/// A plain-data snapshot of a calendar's relevant properties, suitable for
/// testing the selection logic without needing a real `EKEventStore`.
struct CalendarEntry: Equatable {
    let title: String
    let sourceTitle: String
    let sourceType: EKSourceType
    let isWritable: Bool
}

/// Pure selection logic for picking which Apple/iCloud calendar should receive
/// new events. Decoupled from `EKEventStore` so it can be unit-tested directly.
///
/// Contract — in priority order:
/// 1. iCloud source wins.
/// 2. Any writable non-Google, non-Gmail, non-Subscribed calendar wins next.
/// 3. If no such calendar exists, returns `nil` (caller decides whether to
///    fall back to the system default — but by that point the caller knows
///    it's taking a risk).
enum CalendarSelector {

    static func selectBestAppleCalendar(from entries: [CalendarEntry]) -> CalendarEntry? {
        let writable = entries.filter { $0.isWritable }

        // 1. Prefer iCloud
        if let iCloud = writable.first(where: {
            $0.sourceTitle.localizedCaseInsensitiveContains("iCloud")
        }) {
            return iCloud
        }

        // 2. Fallback: any writable non-Google, non-Subscribed calendar
        if let nonGoogle = writable.first(where: { entry in
            let isGoogle = entry.sourceTitle.localizedCaseInsensitiveContains("google")
                        || entry.sourceTitle.localizedCaseInsensitiveContains("gmail")
            let isSubscribed = entry.sourceType == .subscribed
            return !isGoogle && !isSubscribed
        }) {
            return nonGoogle
        }

        // 3. Nothing safe → nil. Never silently leak to Gmail.
        return nil
    }
}
