import SwiftUI

// MARK: - ThemeCardView
// Compact thumbnail card used in the 2-column theme gallery grid.
// Shows the theme's real MeshGradient so each card is a true colour preview.

struct ThemeCardView: View {
    let theme: AppTheme
    let isSelected: Bool
    var namespace: Namespace.ID

    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        ZStack(alignment: .bottom) {

            // Layer 1 — real theme gradient (shows exactly what you get)
            cardBackground

            // Layer 2 — bottom fade so label is always legible
            LinearGradient(
                colors: [.clear, .black.opacity(0.68)],
                startPoint: UnitPoint(x: 0.5, y: 0.45),
                endPoint: .bottom
            )

            // Layer 3 — theme name + mood tag
            HStack(alignment: .bottom, spacing: 4) {
                Text(theme.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer(minLength: 4)
                tagBadge
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 11)

            // Layer 4 — selection ring in the theme's own accent colour
            if isSelected {
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(theme.accentColor, lineWidth: 2.5)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .aspectRatio(0.82, contentMode: .fit)
        .matchedTransitionSource(id: theme.id, in: namespace)
        .shadow(color: .black.opacity(0.28), radius: 16, x: 0, y: 8)
    }

    // MARK: — Tag badge

    @ViewBuilder
    private var tagBadge: some View {
        let label = isSelected ? "Active" : theme.tag
        Text(label)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                isSelected ? theme.accentColor.opacity(0.85) : .white.opacity(0.20),
                in: Capsule()
            )
    }

    // MARK: — Card background
    // MeshGradient blurs badly at thumbnail size — not used here.
    // Instead: vivid focal colour (meshColors[4]) as base, with the theme's
    // corner tones layered on top as a diagonal gradient so the full palette
    // reads clearly at any size.

    @ViewBuilder
    private var cardBackground: some View {
        ZStack {
            // Base — most vivid / saturated colour of the theme
            theme.meshColors[4]

            // Diagonal overlay — top-left corner → centre → bottom-right corner
            // Adds the dark/light tonal range without MeshGradient blur
            LinearGradient(
                colors: [
                    theme.meshColors[0].opacity(0.78),
                    theme.meshColors[4].opacity(0.0),
                    theme.meshColors[8].opacity(0.78)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - Preview

#Preview {
    LazyVGrid(
        columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)],
        spacing: 16
    ) {
        ThemeCardView(theme: .academia,   isSelected: false, namespace: Namespace().wrappedValue)
        ThemeCardView(theme: .nord,       isSelected: false, namespace: Namespace().wrappedValue)
        ThemeCardView(theme: .tokyoNight, isSelected: false, namespace: Namespace().wrappedValue)
        ThemeCardView(theme: .forest,     isSelected: true,  namespace: Namespace().wrappedValue)
        ThemeCardView(theme: .rose,       isSelected: false, namespace: Namespace().wrappedValue)
        ThemeCardView(theme: .void,       isSelected: false, namespace: Namespace().wrappedValue)
    }
    .padding(16)
    .background(Color(red: 0.11, green: 0.11, blue: 0.12))
    .environment(ThemeManager.shared)
    .environment(StoreKitManager.shared)
}
