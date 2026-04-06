import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Light/dark adaptive color helper
// Used by AppTheme for themes that adapt to system dark/light mode.

public extension Color {
    init(light: Color, dark: Color) {
        #if canImport(UIKit)
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(dark)
                : UIColor(light)
        })
        #else
        self = light
        #endif
    }

    /// Convenience init from a 6-digit hex string, e.g. Color(hex: "FF3399").
    /// Alpha is always 1.0. Works on all Apple platforms.
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int         & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
