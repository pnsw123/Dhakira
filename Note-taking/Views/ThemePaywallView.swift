import SwiftUI
import StoreKit

// MARK: - ThemePaywallView
// Native StoreKit UI sheet shown when user taps Apply on an unowned paid theme.
// Issue #76 — https://github.com/pnsw123/prod-note/issues/76

#Preview {
    ThemePaywallView(theme: .academia)
        .environment(StoreKitManager.shared)
}

struct ThemePaywallView: View {
    let theme: AppTheme
    @Environment(StoreKitManager.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Single theme ProductView (iOS 17 native UI)
                // Bug 3 fix: show loading spinner while products are fetching on first launch
                if let product = store.product(for: theme) {
                    ProductView(id: product.id) {
                        Image(systemName: "paintbrush.fill")
                    }
                    .productViewStyle(.large)
                } else if store.products.isEmpty {
                    ProgressView("Loading…")
                        .task { await store.fetchProducts() }
                } else {
                    // Products loaded but this specific one is missing — fall back to pro bundle
                    Text("This theme is included in the Pro bundle below.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Divider()

                // Pro bundle upsell
                Text("Or get all themes + future updates:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                StoreView(ids: ["com.prodnote.theme.pro"])
                    .storeButton(.visible, for: .restorePurchases)
            }
            .padding()
            .navigationTitle("Unlock \(theme.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
