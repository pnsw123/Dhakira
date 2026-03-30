import SwiftUI

// MARK: - ThemeView
// 2-column LazyVGrid gallery of paid themes.
// Default and Midnight are intentionally excluded — users rely on system dark/light mode.
// Issue #71 — https://github.com/pnsw123/prod-note/issues/71

struct ThemeView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(StoreKitManager.self) private var store
    @State private var searchText = ""
    @State private var selectedTheme: AppTheme? = nil
    @Namespace private var namespace

    // Filter out Default and Midnight — users use system appearance for those.
    private var displayedThemes: [AppTheme] {
        let base = AppTheme.all.filter { $0.id != "default" && $0.id != "midnight" }
        if searchText.isEmpty { return base }
        return base.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)],
                spacing: 20
            ) {
                ForEach(displayedThemes) { theme in
                    Button {
                        selectedTheme = theme
                    } label: {
                        ThemeCardView(
                            theme: theme,
                            isSelected: themeManager.current.id == theme.id,
                            namespace: namespace
                        )
                        .scrollTransition { content, phase in
                            content
                                .opacity(phase.isIdentity ? 1 : 0)
                                .scaleEffect(phase.isIdentity ? 1 : 0.88)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .navigationDestination(item: $selectedTheme) { theme in
            ThemeDetailView(theme: theme, namespace: namespace)
                .environment(themeManager)
                .environment(store)
                .navigationTransition(.zoom(sourceID: theme.id, in: namespace))
        }
        .scrollContentBackground(.hidden)
        .contentMargins(16, for: .scrollContent)
        .searchable(text: $searchText, placement: .navigationBarDrawer, prompt: "Search themes")
        .navigationTitle("Themes")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(Color.screenBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
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
