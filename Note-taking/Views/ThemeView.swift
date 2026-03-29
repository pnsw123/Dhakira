import SwiftUI

// MARK: - ThemeView
// 2-column LazyVGrid gallery of all themes.
// Replaces the old "Themes coming soon" placeholder.
// Issue #71 — https://github.com/pnsw123/prod-note/issues/71

struct ThemeView: View {
    @Environment(ThemeManager.self) private var themeManager
    @State private var searchText = ""
    @Namespace private var namespace

    private var filteredThemes: [AppTheme] {
        if searchText.isEmpty { return AppTheme.all }
        return AppTheme.all.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 16
                ) {
                    ForEach(filteredThemes) { theme in
                        NavigationLink {
                            ThemeDetailView(theme: theme, namespace: namespace)
                                .navigationTransition(.zoom(sourceID: theme.id, in: namespace))
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
            .contentMargins(16, for: .scrollContent)
            .searchable(text: $searchText, placement: .navigationBarDrawer, prompt: "Search themes")
            .navigationTitle("Themes")
            .navigationBarTitleDisplayMode(.large)
            .modifier(SoftScrollEdge())
        }
    }
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
