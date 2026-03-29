import SwiftUI

// MARK: - ThemeCardView
// Reusable animated card used in the theme gallery grid.
// Shows MeshGradient background (iOS 18+), frosted material overlay,
// theme name, lock icon for unowned paid themes, and selected-state ring.
// Issue #72 — https://github.com/pnsw123/prod-note/issues/72

struct ThemeCardView: View {
    let theme: AppTheme
    let isSelected: Bool
    var namespace: Namespace.ID

    @Environment(ThemeManager.self) private var themeManager
    @Environment(StoreKitManager.self) private var store

    private var isOwned: Bool {
        !theme.isPaid || store.isOwned(theme)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {

            // Layer 1 — animated MeshGradient background
            cardBackground

            // Layer 2 — frosted material overlay
            // NOTE: ultraThinMaterial on cards, NOT glassEffect (Apple HIG: glass only on floating elements)
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)

            // Layer 3 — theme name + subtitle
            VStack(alignment: .leading, spacing: 4) {
                Spacer()
                Text(theme.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(theme.isPaid ? (isOwned ? "Owned" : "$1.99") : "Free")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)

            // Layer 4 — lock or checkmark
            Group {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                        .padding(8)
                        .modifier(DrawOnSymbolEffect(trigger: isSelected))
                } else if !isOwned {
                    Image(systemName: "lock.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .padding(8)
                }
            }

            // Layer 5 — selected ring
            if isSelected {
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(.blue, lineWidth: 3)
            }
        }
        .clipShape(cardShape)
        .aspectRatio(0.75, contentMode: .fit)
        // Transition source for zoom navigation (iOS 18)
        .matchedTransitionSource(id: theme.id, in: namespace)
        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
    }

    // MARK: — Card shape: ConcentricRectangle (iOS 26) else RoundedRectangle

    private var cardShape: AnyShape {
        if #available(iOS 26, *) {
            // ConcentricRectangle gives fluid "squircle" corners matching iOS 26 design
            AnyShape(ConcentricRectangle())
        } else {
            AnyShape(RoundedRectangle(cornerRadius: 20))
        }
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
        } else {
            // iOS 17 fallback: static linear gradient from first + last mesh colour
            LinearGradient(
                colors: [theme.meshColors.first ?? .gray,
                         theme.meshColors.last  ?? .black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    // Slowly animate interior control points so the gradient feels alive
    private func animatedPoints(t: Double) -> [SIMD2<Float>] {
        let s = Float(sin(t * 0.3) * 0.08)
        let c = Float(cos(t * 0.2) * 0.08)
        return [
            [0, 0], [0.5 + s, 0], [1, 0],
            [0, 0.5 + c], [0.5 - s, 0.5 + s], [1, 0.5 - c],
            [0, 1], [0.5 + c, 1], [1, 1]
        ]
    }
}

// MARK: — iOS 26 symbol effect availability gate

private struct DrawOnSymbolEffect: ViewModifier {
    let trigger: Bool
    func body(content: Content) -> some View {
        if #available(iOS 18, *) {
            content.symbolEffect(.drawOn, isActive: trigger)
        } else {
            content
        }
    }
}
