import SwiftUI

// MARK: - ThemeView
// 2-column LazyVGrid gallery of all themes.
// Issue #71 — https://github.com/pnsw123/prod-note/issues/71

struct ThemeView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(StoreKitManager.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedTheme: AppTheme? = nil
    @Namespace private var namespace

    private var displayedThemes: [AppTheme] {
        if searchText.isEmpty { return AppTheme.all }
        return AppTheme.all.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)],
                spacing: 12
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
        .toolbar(.hidden, for: .navigationBar)
        .modifier(SoftScrollEdge())
        .safeAreaInset(edge: .top) {
            VStack(spacing: 0) {
                // Title row — fixed, matches Tasks / Folders header exactly
                HStack(spacing: 0) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Color.themeAccent)
                            .frame(width: 36, height: 36)
                            .glassEffect(.regular.tint(Color.themeAccent.opacity(0.2)).interactive(), in: .circle)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 8)

                    Text("Themes")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(Color.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 16)
                }
                .padding(.top, 4)
                .padding(.bottom, 8)

                // Search field — always visible, never collapses
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Color.secondaryText)
                        .font(.system(size: 15))
                    TextField("Search themes", text: $searchText)
                        .font(.system(size: 17))
                        .foregroundStyle(Color.primaryText)
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Color.secondaryText)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Color.secondaryText.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
            }
            .contentShape(Rectangle())
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ThemeView()
            .withAppBackground()
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
