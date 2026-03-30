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
    }

    // MARK: — Apply theme
    func apply(_ theme: AppTheme) {
        current = theme
        selectedThemeId = theme.id
        backgroundColorOverride = nil
        backgroundGradientColors = nil
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
        guard let defaults = UserDefaults(suiteName: "group.com.prodnote.shared") else { return }
        defaults.set(current.id, forKey: "themeId")
        #if canImport(UIKit)
        // Copy background image JPEG to shared container so the widget can read it
        let sharedURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.prodnote.shared")?
            .appendingPathComponent("theme_background.jpg")
        if let sharedURL, let img = backgroundImage,
           let jpeg = img.jpegData(compressionQuality: 0.85) {
            try? jpeg.write(to: sharedURL)
        }
        #endif
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
    @Environment(ThemeManager.self) var themeManager
    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        ZStack {
            #if canImport(UIKit)
            if let img = themeManager.backgroundImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea(.all)
                Color.black.opacity(colorScheme == .dark ? 0.55 : 0.25)
                    .ignoresSafeArea(.all)
            } else if let color = themeManager.backgroundColorOverride {
                color
                    .ignoresSafeArea(.all)
            } else if let gradColors = themeManager.backgroundGradientColors {
                LinearGradient(colors: gradColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea(.all)
            } else {
                themeManager.current.screenBackground
                    .ignoresSafeArea(.all)
            }
            #else
            themeManager.current.screenBackground
                .ignoresSafeArea(.all)
            #endif
            content
        }
    }
}

extension View {
    func withAppBackground() -> some View {
        modifier(WithAppBackground())
    }
}
