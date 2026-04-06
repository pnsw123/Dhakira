import StoreKit
import SwiftUI

// MARK: - StoreKitManager
// @Observable class handling all StoreKit 2 operations:
// product fetch, purchase, restore, and continuous Transaction.updates listener.
// Issue #76 — https://github.com/pnsw123/prod-note/issues/76

@Observable
final class StoreKitManager {

    static let shared = StoreKitManager()

    // All known product IDs — must match App Store Connect exactly
    static let allProductIds: Set<String> = [
        "com.prodnote.theme.mango",
        "com.prodnote.theme.nebula",
        "com.prodnote.theme.neon",
        "com.prodnote.theme.galaxy",
        "com.prodnote.theme.cosmos",
        "com.prodnote.theme.twilight",
        "com.prodnote.theme.ember",
        "com.prodnote.theme.crystal",
        "com.prodnote.theme.pro",
    ]

    // Secret developer phrase — typed in the theme search bar to unlock all themes
    static let developerPhrase = "yazeedjameel"
    private let devUnlockKey = "dev.dhakira.unlocked"

    var products: [Product] = []
    var purchasedIds: Set<String> = []
    var isPurchasing: Bool = false
    var lastError: String? = nil

    /// True when the developer secret phrase has been entered on this device.
    var isDeveloperUnlocked: Bool {
        get { UserDefaults.standard.bool(forKey: devUnlockKey) }
        set { UserDefaults.standard.set(newValue, forKey: devUnlockKey) }
    }

    @ObservationIgnored
    private var transactionListener: Task<Void, Error>? = nil

    init() {
        transactionListener = startTransactionListener()
        Task { await fetchProducts() }
        Task { await restoreEntitlements() }
    }

    deinit { transactionListener?.cancel() }

    // MARK: — Fetch products (StoreKit 2, iOS 15+)
    func fetchProducts() async {
        print("[StoreKit] Fetching \(Self.allProductIds.count) products…")
        do {
            products = try await Product.products(for: Self.allProductIds)
            print("[StoreKit] ✅ Fetched \(products.count) products: \(products.map(\.id))")
            if products.isEmpty {
                print("[StoreKit] ⚠️ No products returned — make sure the StoreKit config file is active in your scheme (Product → Scheme → Edit Scheme → Run → StoreKit Config)")
            }
        } catch {
            lastError = error.localizedDescription
            print("[StoreKit] ❌ fetchProducts failed: \(error)")
        }
    }

    // MARK: — Purchase
    func purchase(_ product: Product) async {
        print("[StoreKit] Starting purchase: \(product.id) (\(product.displayPrice))")
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try verification.payloadValue
                await transaction.finish()
                await MainActor.run {
                    purchasedIds.insert(transaction.productID)
                    if transaction.productID == "com.prodnote.theme.pro" {
                        purchasedIds.formUnion(Self.allProductIds)
                    }
                }
                print("[StoreKit] ✅ Purchase success: \(transaction.productID)")
            case .pending:
                print("[StoreKit] ⏳ Purchase pending (Ask to Buy)")
            case .userCancelled:
                print("[StoreKit] 🚫 User cancelled purchase")
            @unknown default:
                print("[StoreKit] ❓ Unknown purchase result")
            }
        } catch {
            lastError = error.localizedDescription
            print("[StoreKit] ❌ Purchase failed: \(error)")
        }
    }

    // MARK: — Restore / check current entitlements on launch
    func restoreEntitlements() async {
        print("[StoreKit] Restoring entitlements…")
        var count = 0
        for await result in StoreKit.Transaction.currentEntitlements {
            if let transaction = try? result.payloadValue {
                // Finish every restored transaction — unfinished transactions
                // block future purchases and leave them stuck in "pending".
                await transaction.finish()
                await MainActor.run {
                    purchasedIds.insert(transaction.productID)
                    if transaction.productID == "com.prodnote.theme.pro" {
                        purchasedIds.formUnion(Self.allProductIds)
                    }
                }
                count += 1
                print("[StoreKit] ↩️ Restored: \(transaction.productID)")
            }
        }
        print("[StoreKit] Restore done — \(count) entitlements found")
    }

    // MARK: — Continuous listener for updates (family sharing, Ask to Buy approval, refunds)
    private func startTransactionListener() -> Task<Void, Error> {
        Task.detached(priority: .background) { [weak self] in
            print("[StoreKit] Transaction listener started")
            for await result in StoreKit.Transaction.updates {
                if let transaction = try? result.payloadValue {
                    print("[StoreKit] 🔔 Transaction update: \(transaction.productID), revoked=\(transaction.revocationDate != nil)")
                    await self?.handleVerifiedTransaction(transaction)
                }
            }
        }
    }

    @MainActor
    private func handleVerifiedTransaction(_ transaction: StoreKit.Transaction) async {
        if transaction.revocationDate != nil {
            purchasedIds.remove(transaction.productID)
            // If the pro bundle is revoked (refund, family sharing removal),
            // also remove all individual theme IDs that were granted by the bundle.
            if transaction.productID == "com.prodnote.theme.pro" {
                purchasedIds.subtract(Self.allProductIds)
                // Re-check: user may still own individual themes purchased separately.
                // Re-run restore to pick those up.
                Task { await restoreEntitlements() }
            }
            print("[StoreKit] ❌ Entitlement revoked: \(transaction.productID)")
        } else {
            purchasedIds.insert(transaction.productID)
            if transaction.productID == "com.prodnote.theme.pro" {
                purchasedIds.formUnion(Self.allProductIds)
            }
            print("[StoreKit] ✅ Entitlement granted: \(transaction.productID)")
        }
        await transaction.finish()
    }

    // MARK: — Ownership check
    func isOwned(_ theme: AppTheme) -> Bool {
        let owned = !theme.isPaid
            || isDeveloperUnlocked
            || purchasedIds.contains(theme.productId ?? "")
            || purchasedIds.contains("com.prodnote.theme.pro")
        return owned
    }

    // MARK: — Developer unlock (secret phrase)
    func activateDeveloperUnlock() {
        print("[StoreKit] 🔓 Developer unlock activated")
        isDeveloperUnlocked = true
        purchasedIds.formUnion(Self.allProductIds)
    }

    func product(for theme: AppTheme) -> Product? {
        guard let id = theme.productId else { return nil }
        let found = products.first { $0.id == id }
        if found == nil {
            print("[StoreKit] ⚠️ No product found for theme '\(theme.name)' (id: \(id)) — products loaded: \(products.map(\.id))")
        }
        return found
    }
}
