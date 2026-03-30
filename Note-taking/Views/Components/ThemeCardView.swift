import SwiftUI

// MARK: - ThemeCardView
// Reusable animated card used in the theme gallery grid.
// Shows live MeshGradient thumbnail with a bottom gradient for text legibility.
// No frosted material overlay — material was killing the gradient visibility.
// Issue #72 — https://github.com/pnsw123/prod-note/issues/72

struct ThemeCardView: View {
    let theme: AppTheme
    let isSelected: Bool
    var namespace: Namespace.ID

    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        ZStack(alignment: .topTrailing) {

            // Layer 1 — live MeshGradient thumbnail
            cardBackground

            // Layer 2 — specular highlight (light streak at top = elevated, premium feel)
            LinearGradient(
                colors: [.white.opacity(0.18), .clear],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.42)
            )

            // Layer 3 — bottom gradient so text is always readable
            LinearGradient(
                colors: [.clear, .black.opacity(0.65)],
                startPoint: UnitPoint(x: 0.5, y: 0.42),
                endPoint: .bottom
            )

            // Layer 3 — theme name only
            VStack {
                Spacer()
                Text(theme.name)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
            }

            // Layer 4 — selected checkmark (top-right corner)
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .padding(8)
                    .modifier(DrawOnSymbolEffect(trigger: isSelected))
            }

            // Layer 5 — selected ring
            if isSelected {
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(.white, lineWidth: 3)
            }
        }
        .clipShape(cardShape)
        .aspectRatio(0.75, contentMode: .fit)
        .matchedTransitionSource(id: theme.id, in: namespace)
        .shadow(color: .black.opacity(0.28), radius: 16, x: 0, y: 8)
    }

    // MARK: — Card shape: ConcentricRectangle (iOS 26) else RoundedRectangle

    private var cardShape: AnyShape {
        AnyShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: — MeshGradient background (iOS 18+)

    @ViewBuilder
    private var cardBackground: some View {
        if #available(iOS 18, *) {
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                MeshGradient(
                    width: 3, height: 3,
                    points: animatedPoints(t: t),
                    colors: theme.meshColors
                )
            }
            // Scale up 1.5× so the vivid focal color at index 4 (centre) dominates
            // the visible thumbnail — looks like a zoomed-in crop of the full wallpaper.
            .scaleEffect(1.5, anchor: .center)
        } else {
            LinearGradient(
                colors: [theme.meshColors.first ?? .gray,
                         theme.meshColors.last  ?? .black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private func animatedPoints(t: Double) -> [SIMD2<Float>] {
        let s = Float(sin(t * 0.25) * 0.10)
        let c = Float(cos(t * 0.18) * 0.10)
        func cl(_ v: Float) -> Float { min(max(v, 0), 1) }
        return [
            [0, 0], [cl(0.5 + s), 0], [1, 0],
            [0, cl(0.5 + c)], [cl(0.5 - s), cl(0.5 + s)], [1, cl(0.5 - c)],
            [0, 1], [cl(0.5 + c), 1], [1, 1]
        ]
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: 12) {
        ThemeCardView(theme: .academia, isSelected: false, namespace: Namespace().wrappedValue)
        ThemeCardView(theme: .rose,     isSelected: true,  namespace: Namespace().wrappedValue)
    }
    .environment(ThemeManager.shared)
    .environment(StoreKitManager.shared)
    .padding()
    .background(Color.gray)
}

// MARK: — iOS 26 symbol effect

private struct DrawOnSymbolEffect: ViewModifier {
    let trigger: Bool
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.symbolEffect(.drawOn, isActive: trigger)
        } else {
            content
        }
    }
}
