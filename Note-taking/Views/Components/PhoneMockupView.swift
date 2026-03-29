import SwiftUI

// MARK: - PhoneMockupView
// Scales down app content inside a phone-frame outline. Non-interactive.
// When scope is .widgets, shows WidgetPreviewLayout instead of a solid colour.
// Issue #74 — https://github.com/pnsw123/prod-note/issues/74

struct PhoneMockupView: View {
    let theme: AppTheme
    let scope: ThemeScope

    var body: some View {
        ZStack {
            // Phone bezel
            RoundedRectangle(cornerRadius: 44)
                .stroke(.white.opacity(0.35), lineWidth: 1.5)
                .background(
                    RoundedRectangle(cornerRadius: 44)
                        .fill(.black.opacity(0.15))
                )

            // Scaled app content — non-interactive
            Group {
                if scope == .widgets {
                    WidgetPreviewLayout(theme: theme)
                } else {
                    // Solid colour placeholder until HomeView reads ThemeManager from environment.
                    Color(theme.screenBackground)
                }
            }
            .scaleEffect(0.35)
            .allowsHitTesting(false)
            .clipped()
        }
        .clipShape(RoundedRectangle(cornerRadius: 44))
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 8)
    }
}
