import Foundation
import OSLog

/// Bidirectional sync between UserDefaults and iCloud (NSUbiquitousKeyValueStore).
/// Keeps user preferences consistent across all devices.
///
/// Usage: call `CloudSettings.shared.start()` once at app launch.
/// Any @AppStorage key registered here will automatically push to iCloud on change
/// and pull from iCloud when another device updates the value.
final class CloudSettings: NSObject, @unchecked Sendable {
    static let shared = CloudSettings()

    private let log = Logger(subsystem: "notes.Note-taking", category: "CloudSettings")
    private let iCloud = NSUbiquitousKeyValueStore.default
    private let defaults = UserDefaults.standard

    /// Keys to sync — only user preferences, NOT device-specific UI state.
    private let syncKeys: [String] = [
        "taskListSortBy",
        "editorToolbarOrder",
        "widgetThemeId",
        // "selectedThemeId" is handled by ThemeManager's own iCloud logic
    ]

    private var observer: Any?
    private var started = false

    private override init() { super.init() }

    /// Call once at app launch to start bidirectional sync.
    func start() {
        guard !started else { return }
        started = true

        // Kick iCloud to sync latest values from other devices.
        iCloud.synchronize()

        // Restore: if this device has never set a key, pull from iCloud.
        for key in syncKeys {
            let localValue = defaults.object(forKey: key)
            if localValue == nil, let cloudValue = iCloud.object(forKey: key) {
                defaults.set(cloudValue, forKey: key)
                log.info("Restored '\(key)' from iCloud")
            }
        }

        // Push only keys that have been explicitly set locally.
        // Don't push defaults — avoids overwriting another device's real preference.
        for key in syncKeys {
            if let value = defaults.object(forKey: key) {
                iCloud.set(value, forKey: key)
            }
        }

        // Listen for local changes via KVO
        for key in syncKeys {
            defaults.addObserver(self, forKeyPath: key, context: nil)
        }

        // Listen for iCloud changes from other devices
        observer = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: iCloud,
            queue: .main
        ) { [weak self] notification in
            self?.handleICloudChange(notification)
        }
    }

    /// Call when the app returns to foreground — forces a fresh pull from iCloud.
    func refreshFromiCloud() {
        iCloud.synchronize()
        for key in syncKeys {
            if let cloudValue = iCloud.object(forKey: key) {
                let localValue = defaults.object(forKey: key)
                // iCloud wins if the values differ — latest writer wins.
                if "\(cloudValue)" != "\(localValue ?? "" as Any)" {
                    defaults.set(cloudValue, forKey: key)
                    log.info("Foreground refresh: pulled '\(key)' from iCloud")
                }
            }
        }
    }

    // KVO: local UserDefaults changed → push to iCloud
    override func observeValue(forKeyPath keyPath: String?, of object: Any?,
                                change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        guard let key = keyPath, syncKeys.contains(key) else { return }
        if let value = defaults.object(forKey: key) {
            iCloud.set(value, forKey: key)
            log.info("Pushed '\(key)' to iCloud")
        }
    }

    // iCloud changed → pull into UserDefaults
    private func handleICloudChange(_ notification: Notification) {
        guard let changedKeys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] else { return }
        for key in changedKeys where syncKeys.contains(key) {
            if let value = iCloud.object(forKey: key) {
                defaults.set(value, forKey: key)
                log.info("Pulled '\(key)' from iCloud")
            }
        }
    }
}
