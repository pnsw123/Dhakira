import SwiftUI

extension Color {
    static func forPriority(_ priority: String) -> Color {
        switch priority {
        case "high": return .priorityHigh
        case "medium": return .priorityMedium
        default: return .priorityDefault
        }
    }
}
