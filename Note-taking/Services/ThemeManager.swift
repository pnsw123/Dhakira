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

    // MARK: — Persistence keys
    @ObservationIgnored
    @AppStorage("selectedThemeId") private var selectedThemeId: String = "defaultLight"

    @ObservationIgnored
    @AppStorage("backgroundImagePath") private var backgroundImagePath: String = ""

    // MARK: — Init
    init() {
        // Restore last selected theme
        if let saved = AppTheme.all.first(where: { $0.id == selectedThemeId }) {
            current = saved
        }
        // Restore background image — UIKit only (WWDC18 #416)
        #if canImport(UIKit)
        if !backgroundImagePath.isEmpty,
           let url = URL(string: backgroundImagePath),
           FileManager.default.fileExists(atPath: url.path) {
            backgroundImage = downsample(imageAt: url, to: UIScreen.main.bounds.size)
        }
        #endif
    }

    // MARK: — Apply theme
    func apply(_ theme: AppTheme) {
        current = theme
        selectedThemeId = theme.id
        syncToAppGroup()
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: — Apply background image (UIKit / iOS only)
    #if canImport(UIKit)
    func applyBackground(data: Data) {
        let url = backgroundURL()
        try? data.write(to: url)
        backgroundImagePath = url.absoluteString
        backgroundImage = downsample(imageAt: url, to: UIScreen.main.bounds.size)
        syncToAppGroup()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func clearBackground() {
        backgroundImage = nil
        backgroundImagePath = ""
        try? FileManager.default.removeItem(at: backgroundURL())
        syncToAppGroup()
        WidgetCenter.shared.reloadAllTimelines()
    }
    #endif

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
    // CGImageSourceCreateThumbnailAtIndex: 87MB raw 12MP → ~11MB (85% savings)
    #if canImport(UIKit)
    private func downsample(imageAt url: URL,
                            to pointSize: CGSize,
                            scale: CGFloat = UITraitCollection.current.displayScale) -> UIImage? {
        let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, imageSourceOptions) else { return nil }
        let maxDimension = max(pointSize.width, pointSize.height) * scale
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension
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
