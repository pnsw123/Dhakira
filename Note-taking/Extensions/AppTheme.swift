// Re-export from ProdNoteShared package — single source of truth.
// The main app gets AppTheme, WidgetTask, and Color(light:dark:) from the package.
// Only the EnvironmentKey lives here because it's app-specific (widgets don't use @Environment).

@_exported import ProdNoteShared
import SwiftUI

// MARK: - EnvironmentKey
extension EnvironmentValues {
    @Entry var appTheme: AppTheme = .defaultLight
}
