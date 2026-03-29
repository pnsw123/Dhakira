import SwiftUI
import WidgetKit

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
    var backgroundImage: UIImage? = nil
    var backgroundOpacity: Double = 0.35

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
        // Restore background image (downsample on load — WWDC18 #416)
        if !backgroundImagePath.isEmpty,
           let url = URL(string: backgroundImagePath),
           FileManager.default.fileExists(atPath: url.path) {
            backgroundImage = downsample(imageAt: url, to: UIScreen.main.bounds.size)
        }
    }

    // MARK: — Apply theme
    func apply(_ theme: AppTheme) {
        current = theme
        selectedThemeId = theme.id
        syncToAppGroup()
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: — Apply background image
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

    // MARK: — App Group sync (widgets read from here)
    private func syncToAppGroup() {
        guard let defaults = UserDefaults(suiteName: "group.com.prodnote.shared") else { return }
        defaults.set(current.id, forKey: "themeId")
        // Copy background image to shared container
        let sharedURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.prodnote.shared")?
            .appendingPathComponent("theme_background.jpg")
        if let sharedURL, let img = backgroundImage,
           let jpeg = img.jpegData(compressionQuality: 0.85) {
            try? jpeg.write(to: sharedURL)
        }
    }

    // MARK: — Downsampling (WWDC18 #416)
    // CGImageSourceCreateThumbnailAtIndex: 87MB raw 12MP → ~11MB (85% savings)
    private func downsample(imageAt url: URL, to pointSize: CGSize, scale: CGFloat = UIScreen.main.scale) -> UIImage? {
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
            if let img = themeManager.backgroundImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea(.all)
                Color.black.opacity(colorScheme == .dark ? 0.55 : 0.25)
                    .ignoresSafeArea(.all)
            } else {
                Color(themeManager.current.screenBackground)
                    .ignoresSafeArea(.all)
            }
            content
        }
    }
}

extension View {
    func withAppBackground() -> some View {
        modifier(WithAppBackground())
    }
}
