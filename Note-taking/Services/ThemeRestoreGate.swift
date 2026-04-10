import Foundation
import ProdNoteShared

// MARK: - ThemeRestoreGate
// Decides whether a theme ID restored from iCloud is safe to apply.
//
// Security context: iCloud KVS stores the user's last selected theme ID so it
// survives reinstalls and syncs across devices. Without an ownership check,
// a paid theme could be "restored" on a device that doesn't own it (e.g.
// after refund, family-share revoke, sandbox test → production install,
// or a malicious KVS write on a jailbroken device).
//
// This gate runs on every iCloud-sourced theme application (init restore,
// didChangeExternallyNotification handler, foreground refresh). It rejects
// any paid theme the user does not currently own and resets to default.
//
// Pure function: no iCloud, no StoreKit. The caller provides the ownership
// snapshot. Tests exercise every edge case without needing real services.

enum ThemeRestoreGate {

    /// Snapshot of ownership relevant to restoration decisions.
    struct OwnershipState: Equatable {
        let purchasedIds: Set<String>
        let isDeveloperUnlocked: Bool

        static let empty = OwnershipState(purchasedIds: [], isDeveloperUnlocked: false)
    }

    /// What the gate decided. Callers act on this to either apply the theme
    /// or reset to default.
    enum Decision: Equatable {
        case apply(AppTheme)
        case resetToDefault(reason: RejectReason)

        enum RejectReason: String, Equatable {
            case unknownThemeId
            case paidThemeNotOwned
            case emptyId
        }
    }

    /// Free themes are applied automatically via light/dark auto-switching
    /// in ContentView. They are not listed in `AppTheme.all` (which only
    /// exposes paid themes for the gallery), so we resolve them directly here.
    private static let freeThemesById: [String: AppTheme] = [
        "default": .defaultLight,
        "midnight": .midnight,
    ]

    /// Gate entry point.
    /// - Parameters:
    ///   - themeId: The ID stored in iCloud KVS.
    ///   - ownership: The current StoreKit ownership snapshot.
    /// - Returns: `.apply(theme)` if safe, otherwise `.resetToDefault(reason)`.
    static func decide(themeId: String, ownership: OwnershipState) -> Decision {
        // 1. Empty / missing ID → reset.
        let trimmed = themeId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .resetToDefault(reason: .emptyId)
        }

        // 2. Free themes always pass (no ownership check needed).
        if let free = freeThemesById[trimmed] {
            return .apply(free)
        }

        // 3. Paid themes must be in AppTheme.all — otherwise the ID is unknown.
        guard let theme = AppTheme.all.first(where: { $0.id == trimmed }) else {
            return .resetToDefault(reason: .unknownThemeId)
        }

        // 4. Defensive: if a free theme ever slipped into `all`, still treat it as safe.
        if !theme.isPaid {
            return .apply(theme)
        }

        // 4. Developer unlock bypasses ownership on-device.
        if ownership.isDeveloperUnlocked {
            return .apply(theme)
        }

        // 5. Individual purchase.
        if let productId = theme.productId, ownership.purchasedIds.contains(productId) {
            return .apply(theme)
        }

        // 6. Trending Bundle (grants all paid themes).
        if ownership.purchasedIds.contains("com.prodnote.theme.pro") {
            return .apply(theme)
        }

        // 7. Paid theme, not owned → reject.
        return .resetToDefault(reason: .paidThemeNotOwned)
    }
}
