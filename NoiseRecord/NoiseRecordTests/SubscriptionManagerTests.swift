import XCTest
@testable import NoiseRecord

final class SubscriptionProductTests: XCTestCase {
    func testAllProductIDsIncludeLegacyAndSubscriptions() {
        XCTAssertTrue(SubscriptionProduct.allProductIDs.contains(SubscriptionProduct.legacyRemoveAds))
        XCTAssertTrue(SubscriptionProduct.allProductIDs.contains(SubscriptionProduct.weekly))
        XCTAssertTrue(SubscriptionProduct.allProductIDs.contains(SubscriptionProduct.monthly))
        XCTAssertTrue(SubscriptionProduct.allProductIDs.contains(SubscriptionProduct.yearly))
        XCTAssertEqual(SubscriptionProduct.allProductIDs.count, 4)
    }

    func testSubscriptionTierProductIDs() {
        XCTAssertEqual(SubscriptionTier.weekly.productID, SubscriptionProduct.weekly)
        XCTAssertEqual(SubscriptionTier.monthly.productID, SubscriptionProduct.monthly)
        XCTAssertEqual(SubscriptionTier.yearly.productID, SubscriptionProduct.yearly)
    }
}

final class PaywallPriceFormatterTests: XCTestCase {
    func testYearlyMonthlyEquivalentFallbackUses166() {
        let text = PaywallPriceFormatter.monthlyEquivalentDisplay(
            fromDisplayPrice: "$19.99",
            price: Decimal(string: "19.99")!
        )
        XCTAssertTrue(text.contains("1.66") || text.contains("1,66"))
    }
}

final class EntitlementGrantMergeTests: XCTestCase {
    func testSubscriptionPurchaseGrantsPremiumAndRemovesAds() {
        let result = EntitlementGrantMerge.merged(
            hasRemovedAds: false,
            isPremiumUser: false,
            purchasedProductIds: [],
            isLegacyPurchase: false,
            isSubscriptionPurchase: true,
            purchasedProductID: SubscriptionProduct.yearly
        )

        XCTAssertEqual(result?.hasRemovedAds, true)
        XCTAssertEqual(result?.isPremiumUser, true)
        XCTAssertEqual(result?.purchasedProductIds, [SubscriptionProduct.yearly])
        XCTAssertEqual(result?.isEarlySupporter, false)
    }

    func testLegacyPurchaseGrantsAdsOnly() {
        let result = EntitlementGrantMerge.merged(
            hasRemovedAds: false,
            isPremiumUser: false,
            purchasedProductIds: [],
            isLegacyPurchase: true,
            isSubscriptionPurchase: false,
            purchasedProductID: SubscriptionProduct.legacyRemoveAds
        )

        XCTAssertEqual(result?.hasRemovedAds, true)
        XCTAssertEqual(result?.isPremiumUser, false)
        XCTAssertEqual(result?.purchasedProductIds, [SubscriptionProduct.legacyRemoveAds])
        XCTAssertEqual(result?.isEarlySupporter, true)
    }

    func testInactivePurchaseReturnsNil() {
        let result = EntitlementGrantMerge.merged(
            hasRemovedAds: false,
            isPremiumUser: false,
            purchasedProductIds: [],
            isLegacyPurchase: false,
            isSubscriptionPurchase: false,
            purchasedProductID: SubscriptionProduct.yearly
        )

        XCTAssertNil(result)
    }

    func testSubscriptionPreservesExistingLegacyAdsFlag() {
        let result = EntitlementGrantMerge.merged(
            hasRemovedAds: true,
            isPremiumUser: false,
            purchasedProductIds: [SubscriptionProduct.legacyRemoveAds],
            isLegacyPurchase: false,
            isSubscriptionPurchase: true,
            purchasedProductID: SubscriptionProduct.monthly
        )

        XCTAssertEqual(result?.hasRemovedAds, true)
        XCTAssertEqual(result?.isPremiumUser, true)
        XCTAssertEqual(
            result?.purchasedProductIds,
            Set([SubscriptionProduct.legacyRemoveAds, SubscriptionProduct.monthly])
        )
        XCTAssertEqual(result?.isEarlySupporter, false)
    }

    func testSubscriptionManagerErrorIncludesEntitlementNotGranted() {
        XCTAssertEqual(
            SubscriptionManagerError.entitlementNotGranted.errorDescription,
            L10n.iapErrorEntitlementNotGranted
        )
    }
}

// MARK: - Manual sandbox checklist
//
// 1. Purchase legacy remove ads → hasRemovedAds=true, isPremiumUser=false, early supporter banner visible.
// 2. Subscribe yearly → isPremiumUser true immediately after purchase success alert (no app restart), AI filter unlocks, voice/video limits removed, ads off.
// 3. Let subscription lapse with legacy → hasRemovedAds stays true, isPremiumUser false, AI locks; voice 3 min / video 1×10s limits apply.
// 4. Restore purchases recovers both legacy and active subscription entitlements (with short retry if StoreKit is slow).
// 5. If purchase succeeds but Pro stays locked, entitlementNotGranted alert guides Restore Purchases; restore should recover Pro.
