import SwiftUI

// MARK: - ThemeDetailView
// Full-screen detail that opens when the user taps a theme card.
// Modelled on Apple's wallpaper picker: MeshGradient fills the screen,
// a live phone mockup sits in the centre, a scope selector below it,
// and Apply / Cancel buttons float at the top.
// Issue #73 — https://github.com/pnsw123/prod-note/issues/73

struct ThemeDetailView: View {
    let theme: AppTheme
    var namespace: Namespace.ID

    @Environment(ThemeManager.self) private var themeManager
    @Environment(StoreKitManager.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var selectedScope: ThemeScope = .all
    @State private var showPaywall = false

    private var isOwned: Bool { !theme.isPaid || store.isOwned(theme) }

    var body: some View {
        let _ = print("🎨 [THEME-DIAG] ThemeDetailView.body START — theme: \(theme.id)")
        let _ = print("🎨 [THEME-DIAG] ThemeDetailView — reading themeManager.current.id: \(themeManager.current.id)")
        let _ = print("🎨 [THEME-DIAG] ThemeDetailView — reading store.isPurchasing: \(store.isPurchasing)")
        let _ = print("🎨 [THEME-DIAG] ThemeDetailView — isOwned: \(isOwned)")
        ZStack {
            // Full-screen MeshGradient background
            themeBackground

            // Main content
            VStack(spacing: 20) {

                // Top bar: Cancel + Apply
                HStack {
                    Button("Cancel") { dismiss() }
                        .modifier(GlassButtonStyle(prominent: false))

                    Spacer()

                    Button("Apply") {
                        if isOwned {
                            themeManager.apply(theme)
                            dismiss()
                        } else {
                            showPaywall = true
                        }
                    }
                    .modifier(GlassButtonStyle(prominent: true))
                    .disabled(!isOwned && store.isPurchasing)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Spacer()

                // Centre: phone mockup
                PhoneMockupView(theme: theme, scope: selectedScope)
                    .frame(width: 180, height: 370)

                // Scope selector pill
                ScopeSelectorView(selected: $selectedScope)

                // Bottom customisation bar
                BottomCustomisationBar(theme: theme)
                    .padding(.horizontal, 20)

                Spacer().frame(height: 8)
            }
        }
        .ignoresSafeArea()
        .navigationBarHidden(true)
        .modifier(BackgroundExtension())
        .sheet(isPresented: $showPaywall) {
            ThemePaywallView(theme: theme)
                .environment(store)
        }
    }

    // MARK: — Background

    @ViewBuilder
    private var themeBackground: some View {
        if #available(iOS 18, *) {
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                MeshGradient(
                    width: 3, height: 3,
                    points: animatedPoints(t: t),
                    colors: theme.meshColors
                )
                .ignoresSafeArea()
            }
        } else {
            LinearGradient(
                colors: [theme.meshColors.first ?? .gray,
                         theme.meshColors.last  ?? .black],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }

    // Bug 4 fix: clamp all points to [0, 1] to prevent MeshGradient bleeding outside the screen
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
    NavigationStack {
        ThemeDetailView(theme: .midnight, namespace: Namespace().wrappedValue)
    }
    .environment(ThemeManager.shared)
    .environment(StoreKitManager.shared)
}

// MARK: — iOS 26 availability gates

private struct GlassButtonStyle: ViewModifier {
    let prominent: Bool
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            if prominent {
                content.buttonStyle(.glassProminent)
            } else {
                content.buttonStyle(.glass)
            }
        } else {
            content
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
        }
    }
}

private struct BackgroundExtension: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.backgroundExtensionEffect()
        } else {
            content
        }
    }
}
