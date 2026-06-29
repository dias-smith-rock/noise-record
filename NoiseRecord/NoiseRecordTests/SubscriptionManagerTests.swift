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

// MARK: - Manual sandbox checklist
//
// 1. Purchase legacy remove ads → hasRemovedAds=true, isPremiumUser=false, early supporter banner visible.
// 2. Subscribe yearly → isPremiumUser true, AI filter unlocks, voice/video limits removed, ads off.
// 3. Let subscription lapse with legacy → hasRemovedAds stays true, isPremiumUser false, AI locks; voice 3 min / video 1×10s limits apply.
// 4. Restore purchases recovers both legacy and active subscription entitlements.
