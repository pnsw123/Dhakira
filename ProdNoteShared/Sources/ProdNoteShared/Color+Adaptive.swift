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
}
