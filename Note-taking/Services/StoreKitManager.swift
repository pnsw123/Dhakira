import StoreKit
import SwiftUI

// MARK: - StoreKitManager
// @Observable class handling all StoreKit 2 operations:
// product fetch, purchase, restore, and continuous Transaction.updates listener.
// Issue #76 — https://github.com/pnsw123/prod-note/issues/76

@Observable
final class StoreKitManager {

    static let shared = StoreKitManager()

    // All known product IDs
    static let allProductIds: Set<String> = [
        "com.prodnote.theme.forest",
        "com.prodnote.theme.void",
        "com.prodnote.theme.ocean",
        "com.prodnote.theme.lavender",
        "com.prodnote.theme.aurora",

        "com.prodnote.theme.terracotta",
        "com.prodnote.theme.matrix",
        "com.prodnote.theme.midnightblue",
        "com.prodnote.theme.pro"
    ]

    var products: [Product] = []
    var purchasedIds: Set<String> = []
    var isPurchasing: Bool = false
    var lastError: String? = nil

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
        do {
            products = try await Product.products(for: Self.allProductIds)
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: — Purchase
    func purchase(_ product: Product) async {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try verification.payloadValue
                await transaction.finish()
                purchasedIds.insert(transaction.productID)
                // Pro bundle unlocks all paid themes
                if transaction.productID == "com.prodnote.theme.pro" {
                    purchasedIds.formUnion(Self.allProductIds)
                }
            case .pending:
                break // Ask to Buy — wait for Transaction.updates
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: — Restore / check current entitlements on launch
    func restoreEntitlements() async {
        for await result in StoreKit.Transaction.currentEntitlements {
            if let transaction = try? result.payloadValue {
                // Bug 6 fix: mutate @Observable state on main actor to prevent EXC_BAD_ACCESS
                await MainActor.run {
                    purchasedIds.insert(transaction.productID)
                    if transaction.productID == "com.prodnote.theme.pro" {
                        purchasedIds.formUnion(Self.allProductIds)
                    }
                }
            }
        }
    }

    // MARK: — Continuous listener for updates (family sharing, Ask to Buy approval, refunds)
    private func startTransactionListener() -> Task<Void, Error> {
        Task.detached(priority: .background) { [weak self] in
            for await result in StoreKit.Transaction.updates {
                if let transaction = try? result.payloadValue {
                    await self?.handleVerifiedTransaction(transaction)
                }
            }
        }
    }

    // Bug 6 fix: @MainActor ensures all purchasedIds mutations happen on the main thread
    @MainActor
    private func handleVerifiedTransaction(_ transaction: StoreKit.Transaction) async {
        if transaction.revocationDate != nil {
            purchasedIds.remove(transaction.productID)
        } else {
            purchasedIds.insert(transaction.productID)
            if transaction.productID == "com.prodnote.theme.pro" {
                purchasedIds.formUnion(Self.allProductIds)
            }
        }
        await transaction.finish()
    }

    // MARK: — Ownership check
    func isOwned(_ theme: AppTheme) -> Bool {
        !theme.isPaid
            || purchasedIds.contains(theme.productId ?? "")
            || purchasedIds.contains("com.prodnote.theme.pro")
    }

    func product(for theme: AppTheme) -> Product? {
        guard let id = theme.productId else { return nil }
        return products.first { $0.id == id }
    }
}
