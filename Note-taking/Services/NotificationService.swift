import UserNotifications
import OSLog

private let log = Logger(subsystem: "notes.Note-taking", category: "Notifications")

/// Sends iOS local notifications when body-line calendar events are created.
///
/// Uses Apple's UNUserNotificationCenter — permission is requested on the first
/// notification attempt, not at app launch. Notifications are batched: one per
/// sync call, not one per line.
///
/// Apple docs:
/// - https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications
/// - https://developer.apple.com/documentation/usernotifications/unmutablenotificationcontent
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {

    static let shared = NotificationService()

    private var permissionRequested = false
    private var permissionGranted = false

    private override init() {
        super.init()
    }

    /// Call once at app launch to set the delegate for foreground display.
    func configure() {
        UNUserNotificationCenter.current().delegate = self
        log.info("NotificationService: configured as delegate")
    }

    // MARK: - Public API

    /// Sends a batched notification for newly created body-line events.
    /// Only notifies on creation — not update or delete.
    ///
    /// - Parameters:
    ///   - taskTitle: The task title (used as notification title).
    ///   - createdCount: Number of events created in this sync.
    func notifyBodyEventsCreated(taskTitle: String, createdCount: Int) {
        guard createdCount > 0 else { return }

        Task {
            // Request permission on first use — native Apple permission dialog.
            if !permissionRequested {
                await requestPermission()
            }
            guard permissionGranted else {
                log.info("notifyBodyEventsCreated: permission denied — skipping")
                return
            }

            let content = UNMutableNotificationContent()
            content.title = taskTitle
            content.body = "\(createdCount) event\(createdCount == 1 ? "" : "s") added to calendar"
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: "body-event-\(UUID().uuidString)",
                content: content,
                trigger: nil  // deliver immediately
            )

            do {
                try await UNUserNotificationCenter.current().add(request)
                log.info("notifyBodyEventsCreated: sent notification — '\(taskTitle)' (\(createdCount) events)")
            } catch {
                log.error("notifyBodyEventsCreated: failed — \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Permission

    private func requestPermission() async {
        permissionRequested = true
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            permissionGranted = granted
            log.info("requestPermission: \(granted ? "granted" : "denied")")
        } catch {
            log.error("requestPermission: \(error.localizedDescription)")
            permissionGranted = false
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Show banner + play sound even when app is in foreground.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
