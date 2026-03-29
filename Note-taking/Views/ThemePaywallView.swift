import SwiftUI
import StoreKit

// MARK: - ThemePaywallView
// Native StoreKit UI sheet shown when user taps Apply on an unowned paid theme.
// Issue #76 — https://github.com/pnsw123/prod-note/issues/76

struct ThemePaywallView: View {
    let theme: AppTheme
    @Environment(StoreKitManager.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Single theme ProductView (iOS 17 native UI)
                if let product = store.product(for: theme) {
                    ProductView(id: product.id) {
                        // Custom icon
                        Image(systemName: "paintbrush.fill")
                    }
                    .productViewStyle(.large)
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
