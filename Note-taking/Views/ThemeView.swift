import SwiftUI

// MARK: - ThemeView
// 2-column LazyVGrid gallery of all themes.
// Replaces the old "Themes coming soon" placeholder.
// Issue #71 — https://github.com/pnsw123/prod-note/issues/71

struct ThemeView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(StoreKitManager.self) private var store
    @State private var searchText = ""
    @State private var selectedTheme: AppTheme? = nil
    @Namespace private var namespace

    private var filteredThemes: [AppTheme] {
        if searchText.isEmpty { return AppTheme.all }
        return AppTheme.all.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        let _ = print("🎨 [THEME-DIAG] ThemeView.body evaluated — themeManager reachable: true, themes: \(filteredThemes.count)")
        // No NavigationStack here — ThemeView is always pushed via navigationDestination
        // from an existing navigation context. Nesting NavigationStack is unsupported.
        //
        // NOTE: NavigationLink { destination } causes SwiftUI's NavigationHostingControllerCache
        // to pre-create UIHostingControllers for ALL visible destinations immediately, before the
        // environment chain is ready. This crashes @Environment(Observable.self) lookups.
        // Fix: use navigationDestination(item:) so the destination is only created on tap,
        // inside the live environment. (iOS 18 SwiftUI bug with zoom transitions + @Observable)
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 16
            ) {
                ForEach(filteredThemes) { theme in
                    Button {
                        selectedTheme = theme
                    } label: {
                        ThemeCardView(
                            theme: theme,
                            isSelected: themeManager.current.id == theme.id,
                            namespace: namespace
                        )
                        .containerRelativeFrame(.horizontal, count: 2, spacing: 12)
                        .scrollTransition { content, phase in
                            content
                                .opacity(phase.isIdentity ? 1 : 0)
                                .scaleEffect(phase.isIdentity ? 1 : 0.85)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
        .navigationDestination(item: $selectedTheme) { theme in
            let _ = print("🎨 [THEME-DIAG] navigationDestination fired — building ThemeDetailView for theme: \(theme.id)")
            ThemeDetailView(theme: theme, namespace: namespace)
                .environment(themeManager)
                .environment(store)
                .navigationTransition(.zoom(sourceID: theme.id, in: namespace))
        }
        .contentMargins(16, for: .scrollContent)
        .searchable(text: $searchText, placement: .navigationBarDrawer, prompt: "Search themes")
        .navigationTitle("Themes")
        .navigationBarTitleDisplayMode(.large)
        .modifier(SoftScrollEdge())
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ThemeView()
    }
    .environment(ThemeManager.shared)
    .environment(StoreKitManager.shared)
}

// MARK: - iOS 26 soft scroll edge

private struct SoftScrollEdge: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.scrollEdgeEffectStyle(.soft, for: .all)
        } else {
            content
        }
    }
}
