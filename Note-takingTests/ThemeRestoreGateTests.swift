import XCTest
@testable import Note_taking
import ProdNoteShared

// MARK: - ThemeRestoreGateTests
// Adversarial tests for the iCloud-theme-restore ownership gate.
// Goal: no code path can apply a paid theme without proof of ownership.
//
// Ownership signals accepted:
//   - Individual purchase (productId in purchasedIds)
//   - "Trending Bundle" (com.prodnote.theme.pro) grants all paid themes
//   - Developer unlock (on-device override)
//   - Theme is free (isPaid == false)
//
// Every other case must return .resetToDefault with an appropriate reason.

final class ThemeRestoreGateTests: XCTestCase {

    // MARK: - Helpers

    private var emptyOwnership: ThemeRestoreGate.OwnershipState {
        ThemeRestoreGate.OwnershipState(purchasedIds: [], isDeveloperUnlocked: false)
    }

    private func owning(_ ids: String...) -> ThemeRestoreGate.OwnershipState {
        ThemeRestoreGate.OwnershipState(purchasedIds: Set(ids), isDeveloperUnlocked: false)
    }

    private var developerUnlocked: ThemeRestoreGate.OwnershipState {
        ThemeRestoreGate.OwnershipState(purchasedIds: [], isDeveloperUnlocked: true)
    }

    // MARK: - Free themes (always safe)

    func testFreeBrightModeAlwaysApplies() {
        let d = ThemeRestoreGate.decide(themeId: "default", ownership: emptyOwnership)
        XCTAssertEqual(d, .apply(.defaultLight),
            "Free Bright Mode must always apply")
    }

    func testFreeMidnightAlwaysApplies() {
        let d = ThemeRestoreGate.decide(themeId: "midnight", ownership: emptyOwnership)
        guard case .apply(let theme) = d else {
            return XCTFail("Midnight must apply, got \(d)")
        }
        XCTAssertEqual(theme.id, "midnight")
        XCTAssertFalse(theme.isPaid, "Midnight must be free")
    }

    // MARK: - Paid themes rejected without ownership

    func testPaidThemeRejectedWithNoOwnership() {
        for theme in AppTheme.paid {
            let d = ThemeRestoreGate.decide(themeId: theme.id, ownership: emptyOwnership)
            XCTAssertEqual(d, .resetToDefault(reason: .paidThemeNotOwned),
                "Paid theme '\(theme.id)' must be rejected when user owns nothing")
        }
    }

    func testPaidThemeRejectedWhenOwningADifferentTheme() {
        // Own Mango, try to restore Nebula → must reject.
        let ownsMango = owning("com.prodnote.theme.mango")
        let d = ThemeRestoreGate.decide(themeId: "mk-nebula", ownership: ownsMango)
        XCTAssertEqual(d, .resetToDefault(reason: .paidThemeNotOwned),
            "Owning Mango must not unlock Nebula")
    }

    // MARK: - Individual purchases

    func testPaidThemeAppliedWhenOwnedIndividually() {
        let ownsNebula = owning("com.prodnote.theme.nebula")
        let d = ThemeRestoreGate.decide(themeId: "mk-nebula", ownership: ownsNebula)
        guard case .apply(let theme) = d else {
            return XCTFail("Owned Nebula must apply, got \(d)")
        }
        XCTAssertEqual(theme.id, "mk-nebula")
    }

    func testEveryPaidThemeResolvesCorrectProductId() {
        // Defensive: if AppTheme.productId mapping changes, this catches it.
        for theme in AppTheme.paid {
            let productId = theme.productId ?? ""
            XCTAssertFalse(productId.isEmpty,
                "Paid theme '\(theme.id)' must expose a productId")
            let ownership = ThemeRestoreGate.OwnershipState(
                purchasedIds: [productId], isDeveloperUnlocked: false)
            let d = ThemeRestoreGate.decide(themeId: theme.id, ownership: ownership)
            XCTAssertEqual(d, .apply(theme),
                "Owning '\(productId)' must unlock theme '\(theme.id)'")
        }
    }

    // MARK: - Trending Bundle

    func testTrendingBundleUnlocksAllPaidThemes() {
        let bundle = owning("com.prodnote.theme.pro")
        for theme in AppTheme.paid {
            let d = ThemeRestoreGate.decide(themeId: theme.id, ownership: bundle)
            XCTAssertEqual(d, .apply(theme),
                "Bundle must unlock paid theme '\(theme.id)'")
        }
    }

    func testBundleAlsoAllowsFreeThemes() {
        let bundle = owning("com.prodnote.theme.pro")
        let d = ThemeRestoreGate.decide(themeId: "default", ownership: bundle)
        XCTAssertEqual(d, .apply(.defaultLight),
            "Free theme must still apply when bundle is owned")
    }

    // MARK: - Developer unlock

    func testDeveloperUnlockAppliesAnyPaidTheme() {
        for theme in AppTheme.paid {
            let d = ThemeRestoreGate.decide(themeId: theme.id, ownership: developerUnlocked)
            XCTAssertEqual(d, .apply(theme),
                "Developer unlock must apply paid theme '\(theme.id)'")
        }
    }

    // MARK: - Unknown / malformed IDs

    func testUnknownThemeIdIsRejected() {
        let d = ThemeRestoreGate.decide(themeId: "mk-does-not-exist", ownership: emptyOwnership)
        XCTAssertEqual(d, .resetToDefault(reason: .unknownThemeId))
    }

    func testUnknownThemeIdIsRejectedEvenWithFullOwnership() {
        // Even if the user owns everything, we don't silently apply a mystery theme.
        let bundle = owning("com.prodnote.theme.pro")
        let d = ThemeRestoreGate.decide(themeId: "made-up-theme", ownership: bundle)
        XCTAssertEqual(d, .resetToDefault(reason: .unknownThemeId))
    }

    func testEmptyIdIsRejected() {
        let d = ThemeRestoreGate.decide(themeId: "", ownership: emptyOwnership)
        XCTAssertEqual(d, .resetToDefault(reason: .emptyId))
    }

    func testWhitespaceOnlyIdIsRejected() {
        let d = ThemeRestoreGate.decide(themeId: "   ", ownership: emptyOwnership)
        XCTAssertEqual(d, .resetToDefault(reason: .emptyId))
    }

    func testWhitespacePaddedIdIsNormalized() {
        // "  default  " should still resolve to Bright Mode.
        let d = ThemeRestoreGate.decide(themeId: "  default  ", ownership: emptyOwnership)
        XCTAssertEqual(d, .apply(.defaultLight),
            "Padded whitespace must be trimmed before lookup")
    }

    // MARK: - Attack scenarios

    func testRevokedPurchaseCannotRestoreTheme() {
        // User buys Mango, uses it, refunds it. purchasedIds no longer contains the productId.
        // iCloud still has "mk-mango" from before. Must NOT restore.
        let afterRevoke = owning("com.prodnote.theme.nebula") // still owns something else
        let d = ThemeRestoreGate.decide(themeId: "mk-mango", ownership: afterRevoke)
        XCTAssertEqual(d, .resetToDefault(reason: .paidThemeNotOwned))
    }

    func testFamilyShareRevokedCannotRestoreTheme() {
        // Family member was granted bundle, then removed from sharing. Bundle ID vanishes.
        let d = ThemeRestoreGate.decide(themeId: "mk-cosmos", ownership: emptyOwnership)
        XCTAssertEqual(d, .resetToDefault(reason: .paidThemeNotOwned))
    }

    func testPartialBundleIdDoesNotCountAsBundle() {
        // A bad write puts "theme.pro" (missing prefix) in purchasedIds. Must NOT unlock.
        let partial = owning("theme.pro", "com.prodnote.pro")
        let d = ThemeRestoreGate.decide(themeId: "mk-ember", ownership: partial)
        XCTAssertEqual(d, .resetToDefault(reason: .paidThemeNotOwned))
    }

    func testCaseSensitiveProductIdMatch() {
        // StoreKit product IDs are case-sensitive. Uppercased product should NOT match.
        let upper = owning("COM.PRODNOTE.THEME.MANGO")
        let d = ThemeRestoreGate.decide(themeId: "mk-mango", ownership: upper)
        XCTAssertEqual(d, .resetToDefault(reason: .paidThemeNotOwned),
            "Product ID matching must be case-sensitive to match StoreKit behavior")
    }

    func testSimilarButWrongThemeIdIsRejected() {
        // "mk-mango2" is not a real theme — must be rejected as unknown, not paid-not-owned.
        let d = ThemeRestoreGate.decide(themeId: "mk-mango2", ownership: emptyOwnership)
        XCTAssertEqual(d, .resetToDefault(reason: .unknownThemeId))
    }

    // MARK: - No crash / determinism

    func testDecisionIsDeterministic() {
        // Same inputs → same output, always. Guards against accidental Set iteration leaks.
        let ownership = owning("com.prodnote.theme.mango", "com.prodnote.theme.nebula")
        let first = ThemeRestoreGate.decide(themeId: "mk-mango", ownership: ownership)
        for _ in 0..<100 {
            XCTAssertEqual(
                ThemeRestoreGate.decide(themeId: "mk-mango", ownership: ownership),
                first,
                "Gate must be deterministic")
        }
    }

    func testLargePurchaseSetDoesNotAffectCorrectness() {
        // 1000 junk purchase IDs + 1 real one — must still match correctly.
        var bigSet = Set((0..<1000).map { "junk.product.\($0)" })
        bigSet.insert("com.prodnote.theme.cosmos")
        let ownership = ThemeRestoreGate.OwnershipState(
            purchasedIds: bigSet, isDeveloperUnlocked: false)
        let d = ThemeRestoreGate.decide(themeId: "mk-cosmos", ownership: ownership)
        guard case .apply(let theme) = d else {
            return XCTFail("Cosmos must apply, got \(d)")
        }
        XCTAssertEqual(theme.id, "mk-cosmos")
    }

    // MARK: - Sanity check on free/paid split
    //
    // NOTE: Free themes (Bright Mode, Midnight) are NOT listed in AppTheme.all
    // by design — they are applied automatically via light/dark mode switching
    // in ContentView. The gate resolves them explicitly via its own lookup.

    func testGateRecognizesBothFreeThemeIds() {
        // Both "default" and "midnight" must be accepted by the gate without ownership.
        let defaultDecision = ThemeRestoreGate.decide(themeId: "default", ownership: emptyOwnership)
        let midnightDecision = ThemeRestoreGate.decide(themeId: "midnight", ownership: emptyOwnership)
        if case .resetToDefault = defaultDecision {
            XCTFail("'default' must not be rejected")
        }
        if case .resetToDefault = midnightDecision {
            XCTFail("'midnight' must not be rejected")
        }
    }

    func testAllThemesInAllAreMarkedPaid() {
        // AppTheme.all only contains paid themes — every entry must have isPaid == true.
        for theme in AppTheme.all {
            XCTAssertTrue(theme.isPaid,
                "AppTheme.all must only contain paid themes, found free: \(theme.id)")
        }
    }

    func testAllPaidThemesHaveProductIds() {
        for theme in AppTheme.all {
            XCTAssertNotNil(theme.productId,
                "Paid theme '\(theme.id)' is missing a productId")
            XCTAssertTrue(theme.productId!.hasPrefix("com.prodnote.theme."),
                "Paid theme '\(theme.id)' productId must follow naming scheme")
        }
    }
}
