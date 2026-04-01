import SwiftUI

// MARK: - ThemeDetailView
// Full-screen detail that opens when the user taps a theme card.
// Modelled on Apple's wallpaper picker: animated MeshGradient fills the screen,
// a live phone mockup sits in the centre, a scope selector below it,
// and Apply / Cancel buttons float at the top.
// Issue #73 — https://github.com/pnsw123/prod-note/issues/73

struct ThemeDetailView: View {
    let theme: AppTheme
    var namespace: Namespace.ID

    @Environment(ThemeManager.self) private var themeManager
    @Environment(StoreKitManager.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var selectedScope: ThemeScope = .app
    @State private var mockPage = 0

    private let pageCount = 3

    var body: some View {
        ZStack {
            // Full-screen animated MeshGradient background — only this ignores safe area
            themeBackground
                .ignoresSafeArea()

            VStack(spacing: 16) {

                // Top bar: Cancel + Apply/Remove — sits below status bar in safe area
                HStack {
                    Button("Cancel") { dismiss() }
                        .modifier(GlassButtonStyle(prominent: false))

                    Spacer()

                    if themeManager.current.id == theme.id && !themeManager.isAutoTheme {
                        // Already active — offer to remove and return to system default
                        Button("Remove Theme") {
                            withAnimation(.easeInOut(duration: 0.35)) {
                                themeManager.resetToDefault()
                            }
                            dismiss()
                        }
                        .modifier(GlassButtonStyle(prominent: false))
                    } else {
                        Button("Apply") {
                            withAnimation(.easeInOut(duration: 0.35)) {
                                themeManager.apply(theme)
                            }
                            dismiss()
                        }
                        .modifier(GlassButtonStyle(prominent: true))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                // Phone mockup + page dots below the bezel
                VStack(spacing: 10) {
                    PhoneMockupView(theme: theme, scope: selectedScope, currentPage: $mockPage)
                        .frame(width: 288, height: 624)
                        .overlay(alignment: .leading) {
                            if selectedScope == .app {
                                mockNavArrow(forward: false)
                                    .offset(x: -64)
                            }
                        }
                        .overlay(alignment: .trailing) {
                            if selectedScope == .app {
                                mockNavArrow(forward: true)
                                    .offset(x: 64)
                            }
                        }

                    // Page indicator dots — only for App scope
                    if selectedScope == .app {
                        HStack(spacing: 6) {
                            ForEach(0..<3, id: \.self) { i in
                                Circle()
                                    .fill(i == mockPage
                                          ? theme.accentColor
                                          : Color.white.opacity(0.5))
                                    .frame(width: 6, height: 6)
                                    .animation(.easeInOut(duration: 0.2), value: mockPage)
                            }
                        }
                    }
                }

                // Scope selector: App / Widgets
                ScopeSelectorView(selected: $selectedScope)

                Spacer()
            }
        }
        .navigationBarHidden(true)
    }

    @ViewBuilder
    private func mockNavArrow(forward: Bool) -> some View {
        let atEdge = forward ? (mockPage >= pageCount - 1) : (mockPage <= 0)
        Button {
            withAnimation(.spring(duration: 0.25)) {
                mockPage = forward ? min(pageCount - 1, mockPage + 1) : max(0, mockPage - 1)
            }
        } label: {
            Image(systemName: forward ? "chevron.right" : "chevron.left")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
        }
        .modifier(GlassCircleArrow())
        .disabled(atEdge)
        .opacity(atEdge ? 0.25 : 1)
    }

    // MARK: — Animated background

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
        ThemeDetailView(theme: .sakura, namespace: Namespace().wrappedValue)
    }
    .environment(ThemeManager.shared)
    .environment(StoreKitManager.shared)
}

// MARK: — iOS 26 glass button styles

private struct GlassCircleArrow: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.buttonStyle(.glass)
        } else {
            content.background(.ultraThinMaterial, in: Circle())
        }
    }
}

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
