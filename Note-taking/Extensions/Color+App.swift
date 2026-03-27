import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

extension Color {
    // MARK: - Priority colors
    static let priorityHighColor = Color(red: 1.0, green: 0.0, blue: 0.0)         // #FF0000
    static let priorityMediumColor = Color(red: 1.0, green: 0.404, blue: 0.0)      // #FF6700

    static func forPriority(_ priority: String) -> Color {
        switch priority {
        case "high": return .priorityHighColor
        case "medium": return .priorityMediumColor
        default: return .gray
        }
    }

    // MARK: - Theme tokens
    static let screenBackground = Color.white

    /// FAB button background — warm charcoal (light), white (dark)
    static let fabColor = Color(light: Color(red: 0.235, green: 0.227, blue: 0.212),
                                dark: Color.white)

    /// FAB icon color — white (light), black (dark)
    static let fabIcon = Color(light: Color.white, dark: Color.black)
}

// MARK: - Light/dark adaptive color helper
extension Color {
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
