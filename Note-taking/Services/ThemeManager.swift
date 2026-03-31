import SwiftUI
import WidgetKit
#if canImport(UIKit)
import UIKit
import ImageIO
#endif

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

    @ObservationIgnored
    @AppStorage("backgroundImagePath") private var backgroundImagePath: String = ""

    // MARK: — Init
    init() {
        // Restore last selected theme
        if let saved = AppTheme.all.first(where: { $0.id == selectedThemeId }) {
            current = saved
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
        guard let defaults = UserDefaults(suiteName: "group.com.prodnote.notetaking") else { return }
        defaults.set(widgetThemeId, forKey: "themeId")
        #if canImport(UIKit)
        // Copy background image JPEG to shared container so the widget can read it
        let sharedURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.prodnote.notetaking")?
            .appendingPathComponent("theme_background.jpg")
        if let sharedURL, let img = backgroundImage,
           let jpeg = img.jpegData(compressionQuality: 0.85) {
            try? jpeg.write(to: sharedURL)
        }
        #endif
        defaults.synchronize()
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
                    } else if tm.current.backgroundStyle == .gradient {
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
                    } else if tm.current.backgroundStyle == .gradient {
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
        guard let defaults = UserDefaults(suiteName: "group.com.prodnote.notetaking") else { return }
        defaults.set(totalCount, forKey: "activeTaskCount")
        if let encoded = try? JSONEncoder().encode(tasks) {
            defaults.set(encoded, forKey: "activeTasks")
        }
        // Force flush to disk — App Group UserDefaults may not sync immediately
        defaults.synchronize()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
