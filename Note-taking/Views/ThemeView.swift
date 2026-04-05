import SwiftUI
import StoreKit
import UIKit

// MARK: - ThemeView
// 2-column LazyVGrid gallery of all themes.
// Issue #71 — https://github.com/pnsw123/prod-note/issues/71

struct ThemeView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(StoreKitManager.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedTheme: AppTheme? = nil
    @State private var showBundleSheet = false
    @State private var showDevUnlockedAlert = false
    @Namespace private var namespace

    private var displayedThemes: [AppTheme] {
        if searchText.isEmpty { return AppTheme.all }
        return AppTheme.all.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {

                // Bundle upsell banner — hidden once user has the bundle or dev unlock
                if !store.purchasedIds.contains("com.prodnote.theme.pro") && !store.isDeveloperUnlocked {
                    bundleBanner
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                }

                // Theme grid
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
            }
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
                // Back button + search bar — no title needed, cards speak for themselves
                HStack(spacing: 10) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Color.themeAccent)
                            .frame(width: 36, height: 36)
                            .glassEffect(.regular.tint(Color.themeAccent.opacity(0.2)).interactive(), in: .circle)
                    }
                    .buttonStyle(.plain)

                    // Search field — doubles as secret developer unlock input
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(Color.secondaryText)
                            .font(.system(size: 15))
                        TextField("Search themes", text: $searchText)
                            .font(.system(size: 17))
                            .foregroundStyle(Color.primaryText)
                            .onChange(of: searchText) { _, newValue in
                                checkForDeveloperPhrase(newValue)
                            }
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
                }
                .padding(.horizontal, 12)
                .padding(.top, 4)
                .padding(.bottom, 10)
            }
            .contentShape(Rectangle())
        }
        // Bundle purchase sheet (StoreKit native UI)
        .sheet(isPresented: $showBundleSheet) {
            NavigationStack {
                VStack(spacing: 24) {
                    Text("Get every theme, forever.")
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)

                    Text("All 8 premium themes included, plus any themes added in future updates.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    StoreView(ids: ["com.prodnote.theme.pro"])
                        .storeButton(.visible, for: .restorePurchases)
                }
                .padding()
                .navigationTitle("Trending Bundle")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { showBundleSheet = false }
                    }
                }
            }
        }
        // Developer unlock confirmation
        .alert("Developer Mode", isPresented: $showDevUnlockedAlert) {
            Button("Nice", role: .cancel) { }
        } message: {
            Text("All themes unlocked on this device.")
        }
    }

    // MARK: — Bundle banner

    private var bundleBanner: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Trending Bundle")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.primaryText)
                Text("All 8 themes · $14.99 lifetime")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.secondaryText)
            }
            Spacer()
            Button("Get All") {
                showBundleSheet = true
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.themeAccent, in: Capsule())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.secondaryText.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: — Developer unlock phrase detection

    private func checkForDeveloperPhrase(_ text: String) {
        guard text == StoreKitManager.developerPhrase else { return }
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
        store.activateDeveloperUnlock()
        searchText = ""
        showDevUnlockedAlert = true
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
