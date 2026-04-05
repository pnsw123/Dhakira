import SwiftUI
import WidgetKit
import OSLog
#if canImport(UIKit)
import UIKit
import ImageIO
#endif

private let log = Logger(subsystem: "notes.Note-taking", category: "ThemeManager")

// MARK: - ThemeManager
// @Observable singleton that owns the active theme, custom background image, and persistence.
// Every other theme component depends on this being initialised first.
// Issue #69 — https://github.com/pnsw123/prod-note/issues/69

@Observable
final class ThemeManager {

    // MARK: — Singleton (used by Color+App.swift which has no environment access)
    static let shared = ThemeManager()

    // MARK: — Published state
    var current: AppTheme = .defaultLight
    var backgroundOpacity: Double = 0.35

    // backgroundImage only exists on UIKit platforms (iOS, iPadOS)
    #if canImport(UIKit)
    var backgroundImage: UIImage? = nil
    #endif

    // Bug 2 fix: custom background overrides (in-session; cleared when a theme is applied)
    var backgroundColorOverride: Color? = nil
    var backgroundGradientColors: [Color]? = nil

    // MARK: — Persistence keys
    @ObservationIgnored
    @AppStorage("selectedThemeId") private var selectedThemeId: String = "default"

    /// True when the user has not manually selected a paid theme.
    /// In this state, dark mode auto-applies Midnight; light mode shows defaultLight.
    var isAutoTheme: Bool { selectedThemeId == "default" }

    @ObservationIgnored
    @AppStorage("backgroundImagePath") private var backgroundImagePath: String = ""

    // MARK: — Init
    init() {
        // Restore last selected theme.
        // If the saved ID no longer exists (e.g. theme was removed), reset to "default"
        // so the app doesn't get stuck in a zombie state with mismatched theme/background.
        if let saved = AppTheme.all.first(where: { $0.id == selectedThemeId }) {
            current = saved
        } else if selectedThemeId != "default" && selectedThemeId != "midnight" {
            log.info("Saved theme '\(self.selectedThemeId)' no longer exists — resetting to default")
            selectedThemeId = "default"
        }
        // Restore background image — UIKit only (WWDC18 #416)
        // Bug 1 fix: store and restore as plain path string, not file:// URL absoluteString
        #if canImport(UIKit)
        if !backgroundImagePath.isEmpty {
            let url = URL(fileURLWithPath: backgroundImagePath)
            if FileManager.default.fileExists(atPath: url.path) {
                backgroundImage = Self.downsample(imageAt: url)
            }
        }
        #endif
        // Ensure the App Group always has the current themeId on launch so the
        // widget shows the correct theme even if the user has never opened Theme settings.
        syncToAppGroup()
    }

    // MARK: — Stored widget theme (can differ from app theme)
    @ObservationIgnored
    @AppStorage("widgetThemeId") private var widgetThemeId: String = "default"

    /// The theme currently applied to widgets (may differ from the app theme).
    var widgetTheme: AppTheme {
        AppTheme.all.first { $0.id == widgetThemeId } ?? current
    }

    // MARK: — Apply theme (legacy — applies to both)
    func apply(_ theme: AppTheme) {
        applyApp(theme)
        applyWidget(theme)
    }

    /// Apply theme to the app only.
    func applyApp(_ theme: AppTheme) {
        current = theme
        selectedThemeId = theme.id
        backgroundColorOverride = nil
        backgroundGradientColors = nil
    }

    /// Reset the app theme back to system default (follows iOS light/dark mode automatically).
    func resetToDefault() {
        current = .defaultLight
        selectedThemeId = "default"
        backgroundColorOverride = nil
        backgroundGradientColors = nil
        #if canImport(UIKit)
        clearBackground()
        #endif
        syncToAppGroup()
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Apply theme to widgets only.
    func applyWidget(_ theme: AppTheme) {
        widgetThemeId = theme.id
        syncToAppGroup()
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: — Apply background image (UIKit / iOS only)
    #if canImport(UIKit)
    // Bug 1 + Bug 5 fix: store as plain path (not absoluteString), write file on background thread.
    // Uses DispatchQueue + Task (not Task.detached) to avoid Swift 6 Sendable / actor-isolation errors.
    func applyBackground(data: Data) {
        let url = backgroundURL()
        Task {
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                DispatchQueue.global(qos: .utility).async {
                    try? data.write(to: url)
                    cont.resume()
                }
            }
            // Back on the calling actor (main) after the file write completes
            let img = Self.downsample(imageAt: url)
            self.backgroundImagePath = url.path
            self.backgroundImage = img
            self.backgroundColorOverride = nil
            self.backgroundGradientColors = nil
            self.syncToAppGroup()
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    func clearBackground() {
        backgroundImage = nil
        backgroundImagePath = ""
        try? FileManager.default.removeItem(at: backgroundURL())
        syncToAppGroup()
        WidgetCenter.shared.reloadAllTimelines()
    }
    #endif

    // MARK: — Color / Gradient overrides (Bug 2 fix: wire up Color + Gradient tabs)
    func applyColorOverride(_ color: Color) {
        backgroundColorOverride = color
        backgroundGradientColors = nil
        #if canImport(UIKit)
        backgroundImage = nil
        backgroundImagePath = ""
        #endif
    }

    func applyGradientOverride(_ colors: [Color]) {
        backgroundGradientColors = colors
        backgroundColorOverride = nil
        #if canImport(UIKit)
        backgroundImage = nil
        backgroundImagePath = ""
        #endif
    }

    // MARK: — App Group sync (widgets read from here)
    private func syncToAppGroup() {
        #if canImport(UIKit)
        WidgetSyncBridge.syncTheme(
            effectiveThemeId: isAutoTheme ? current.id : widgetThemeId,
            backgroundImage: backgroundImage
        )
        #else
        WidgetSyncBridge.syncTheme(
            effectiveThemeId: isAutoTheme ? current.id : widgetThemeId,
            backgroundImage: nil
        )
        #endif
    }

    // MARK: — WidgetSyncBridge
    // Private helper that owns all App Group UserDefaults writes + WidgetCenter reloads.
    // ThemeManager calls into this; no other type should access these keys directly.
    private enum WidgetSyncBridge {
        private static let suiteName = "group.com.prodnote.notetaking"

        #if canImport(UIKit)
        static func syncTheme(effectiveThemeId: String, backgroundImage: UIImage?) {
            guard let defaults = UserDefaults(suiteName: suiteName) else {
                log.error("WidgetSyncBridge.syncTheme: failed to open App Group — widget will not update")
                return
            }
            log.debug("WidgetSyncBridge.syncTheme: writing themeId='\(effectiveThemeId)'")
            defaults.set(effectiveThemeId, forKey: "themeId")
            // Copy background JPEG to shared container so the widget can read it
            if let sharedURL = FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: suiteName)?
                .appendingPathComponent("theme_background.jpg"),
               let img = backgroundImage,
               let jpeg = img.jpegData(compressionQuality: 0.85) {
                try? jpeg.write(to: sharedURL)
            }
            defaults.synchronize()
            log.debug("WidgetSyncBridge.syncTheme: EXIT")
        }
        #else
        static func syncTheme(effectiveThemeId: String, backgroundImage: (Any)?) {
            guard let defaults = UserDefaults(suiteName: suiteName) else { return }
            defaults.set(effectiveThemeId, forKey: "themeId")
            defaults.synchronize()
        }
        #endif

        static func syncTasks(_ tasks: [WidgetTask], totalCount: Int) {
            guard let defaults = UserDefaults(suiteName: suiteName) else {
                log.error("WidgetSyncBridge.syncTasks: failed to open App Group — widget task list will not update")
                return
            }
            log.debug("WidgetSyncBridge.syncTasks: pushing \(tasks.count) task(s) (total=\(totalCount))")
            defaults.set(totalCount, forKey: "activeTaskCount")
            if let encoded = try? JSONEncoder().encode(tasks) {
                defaults.set(encoded, forKey: "activeTasks")
            } else {
                log.error("WidgetSyncBridge.syncTasks: JSONEncoder failed — widget will show stale data")
            }
            defaults.synchronize()
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    // MARK: — Downsampling (WWDC18 #416, UIKit only)
    // nonisolated static: pure computation — safe to call from any actor or background queue.
    // Fixed maxPixelSize avoids UIScreen.main (deprecated iOS 26).
    // 3510 = 1170 logical pts × 3x — covers the largest iPhone Pro Max at full resolution.
    // CGImageSourceCreateThumbnailAtIndex: 87MB raw 12MP → ~11MB (85% savings)
    #if canImport(UIKit)
    nonisolated private static func downsample(imageAt url: URL,
                                               maxPixelSize: CGFloat = 3510) -> UIImage? {
        let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, imageSourceOptions) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: thumbnail)
    }
    #endif

    private func backgroundURL() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("background.jpg")
    }
}

// MARK: - WithAppBackground ViewModifier
// Apply .withAppBackground() to every top-level screen so the theme color/photo shows through.
// Issue #70 — https://github.com/pnsw123/prod-note/issues/70

struct WithAppBackground: ViewModifier {
    // @Environment(ThemeManager.self) gives SwiftUI a proper @Observable property to
    // track — the modifier re-renders whenever current / overrides change.
    // The singleton approach (let tm = ThemeManager.shared) does NOT register an
    // observation dependency and therefore never re-renders on theme change.
    @Environment(\.colorScheme) var colorScheme
    @Environment(ThemeManager.self) private var tm

    func body(content: Content) -> some View {
        // Use .background{} instead of ZStack so the gradient is a true backdrop layer.
        // UIVisualEffectView (.ultraThinMaterial) only blurs content in the backdrop —
        // a sibling ZStack element is NOT a backdrop and won't be blurred by materials.
        return content
            .background {
                Group {
                    #if canImport(UIKit)
                    if let img = tm.backgroundImage {
                        ZStack {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                            Color.black.opacity(colorScheme == .dark ? 0.55 : 0.25)
                        }
                    } else if let color = tm.backgroundColorOverride {
                        color
                    } else if let gradColors = tm.backgroundGradientColors {
                        if #available(iOS 18, *) {
                            MeshGradient(
                                width: 2, height: 2,
                                points: [[0, 0], [1, 0], [0, 1], [1, 1]],
                                colors: Array(gradColors.prefix(4))
                            )
                        } else {
                            LinearGradient(colors: gradColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                        }
                    } else if !tm.isAutoTheme && tm.current.backgroundStyle == .gradient {
                        // Only render the themed gradient when a specific theme is active.
                        // When isAutoTheme (id == "default"), meshColors are hardcoded light-cream
                        // and would break dark mode — use the adaptive screenBackground instead.
                        if #available(iOS 18, *) {
                            let defaultGrid: [SIMD2<Float>] = [
                                [0,0],[0.5,0],[1,0],
                                [0,0.5],[0.5,0.5],[1,0.5],
                                [0,1],[0.5,1],[1,1]
                            ]
                            MeshGradient(
                                width: 3, height: 3,
                                points: tm.current.meshPoints ?? defaultGrid,
                                colors: tm.current.meshColors
                            )
                        } else {
                            ZStack {
                                tm.current.meshColors[4]
                                RadialGradient(colors: [tm.current.meshColors[0].opacity(0.85), .clear],
                                               center: .topLeading, startRadius: 0, endRadius: 600)
                                RadialGradient(colors: [tm.current.meshColors[8].opacity(0.80), .clear],
                                               center: .bottomTrailing, startRadius: 0, endRadius: 500)
                            }
                        }
                    } else {
                        // Auto theme or flat-color theme: use adaptive screenBackground
                        // which correctly returns dark/light via UIColor(UITraitCollection).
                        tm.current.screenBackground
                    }
                    #else
                    tm.current.screenBackground
                    #endif
                }
                .ignoresSafeArea()
            }
    }
}

extension View {
    func withAppBackground() -> some View {
        modifier(WithAppBackground())
    }
    /// Like withAppBackground() but fills the screen with editorBackground instead of
    /// screenBackground — used by TaskDetailView so the whole page is one uniform colour.
    func withEditorBackground() -> some View {
        modifier(WithEditorBackground())
    }
}

// MARK: - WithEditorBackground ViewModifier

struct WithEditorBackground: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    @Environment(ThemeManager.self) private var tm

    func body(content: Content) -> some View {
        return content
            .background {
                Group {
                    #if canImport(UIKit)
                    if let img = tm.backgroundImage {
                        ZStack {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                            Color.black.opacity(colorScheme == .dark ? 0.55 : 0.25)
                        }
                    } else if let color = tm.backgroundColorOverride {
                        color
                    } else if let gradColors = tm.backgroundGradientColors {
                        if #available(iOS 18, *) {
                            MeshGradient(
                                width: 2, height: 2,
                                points: [[0, 0], [1, 0], [0, 1], [1, 1]],
                                colors: Array(gradColors.prefix(4))
                            )
                        } else {
                            LinearGradient(colors: gradColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                        }
                    } else if !tm.isAutoTheme && tm.current.backgroundStyle == .gradient {
                        if #available(iOS 18, *) {
                            let defaultGrid: [SIMD2<Float>] = [
                                [0,0],[0.5,0],[1,0],
                                [0,0.5],[0.5,0.5],[1,0.5],
                                [0,1],[0.5,1],[1,1]
                            ]
                            MeshGradient(
                                width: 3, height: 3,
                                points: tm.current.meshPoints ?? defaultGrid,
                                colors: tm.current.meshColors
                            )
                        } else {
                            ZStack {
                                tm.current.meshColors[4]
                                RadialGradient(colors: [tm.current.meshColors[0].opacity(0.85), .clear],
                                               center: .topLeading, startRadius: 0, endRadius: 600)
                                RadialGradient(colors: [tm.current.meshColors[8].opacity(0.80), .clear],
                                               center: .bottomTrailing, startRadius: 0, endRadius: 500)
                            }
                        }
                    } else {
                        tm.current.editorBackground
                    }
                    #else
                    tm.current.editorBackground
                    #endif
                }
                .ignoresSafeArea()
            }
    }
}

// MARK: - Widget task sync

extension ThemeManager {
    /// Writes the top tasks to the shared App Group so the widget can display them.
    /// Called from TaskListView whenever the task list changes.
    func syncActiveTasks(_ tasks: [WidgetTask], totalCount: Int) {
        WidgetSyncBridge.syncTasks(tasks, totalCount: totalCount)
    }
}
