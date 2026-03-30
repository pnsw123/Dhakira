import SwiftUI
import StoreKit

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
    @Environment(StoreKitManager.self) private var store

    private var isOwned: Bool {
        !theme.isPaid || store.isOwned(theme)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {

            // Layer 1 — live MeshGradient thumbnail
            cardBackground

            // Layer 2 — bottom gradient so text is always readable over any gradient
            LinearGradient(
                colors: [.clear, .black.opacity(0.6)],
                startPoint: UnitPoint(x: 0.5, y: 0.38),
                endPoint: .bottom
            )

            // Layer 3 — theme name + price
            VStack(alignment: .leading, spacing: 4) {
                Spacer()
                Text(theme.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(theme.isPaid ? (isOwned ? "Owned" : (store.product(for: theme)?.displayPrice ?? "—")) : "Free")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)

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
        .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 5)
    }

    // MARK: — Card shape: ConcentricRectangle (iOS 26) else RoundedRectangle

    private var cardShape: AnyShape {
        if #available(iOS 26, *) {
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
            LinearGradient(
                colors: [theme.meshColors.first ?? .gray,
                         theme.meshColors.last  ?? .black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private func animatedPoints(t: Double) -> [SIMD2<Float>] {
        let s = Float(sin(t * 0.3) * 0.08)
        let c = Float(cos(t * 0.2) * 0.08)
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
