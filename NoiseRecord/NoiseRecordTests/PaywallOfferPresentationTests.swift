import XCTest
@testable import NoiseRecord

final class PaywallOfferPresentationTests: XCTestCase {
    func testTrialCTAUsesFreeTrialTitle() {
        XCTAssertEqual(
            PaywallOfferPresentation.purchaseButtonTitle(showsFreeTrial: true, trialDays: 3),
            L10n.paywallCTAStartFreeTrial(days: 3)
        )
    }

    func testStandardCTAUsesSubscribeNow() {
        XCTAssertEqual(
            PaywallOfferPresentation.purchaseButtonTitle(showsFreeTrial: false, trialDays: 3),
            L10n.paywallCTASubscribeNow
        )
    }

    func testYearlyTrialSubtitleIncludesMonthlyPrice() {
        let subtitle = PaywallOfferPresentation.purchaseButtonSubtitle(
            tier: .yearly,
            showsFreeTrial: true,
            trialDays: 3,
            tierPrice: "$19.99",
            monthlyEquivalentPrice: "$1.66"
        )
        XCTAssertEqual(
            subtitle,
            L10n.paywallCTASubtitleTrialYearly(monthlyPrice: "$1.66", trialDays: 3)
        )
    }

    func testYearlyStandardSubtitleIncludesAnnualAndMonthlyPrices() {
        let subtitle = PaywallOfferPresentation.purchaseButtonSubtitle(
            tier: .yearly,
            showsFreeTrial: false,
            trialDays: 3,
            tierPrice: "$19.99",
            monthlyEquivalentPrice: "$1.66"
        )
        XCTAssertEqual(
            subtitle,
            L10n.paywallCTASubtitleStandardYearly(annualPrice: "$19.99", monthlyPrice: "$1.66")
        )
    }

    func testMonthlyTrialSubtitleIncludesMonthlyPrice() {
        let subtitle = PaywallOfferPresentation.purchaseButtonSubtitle(
            tier: .monthly,
            showsFreeTrial: true,
            trialDays: 3,
            tierPrice: "$9.99",
            monthlyEquivalentPrice: "$9.99"
        )
        XCTAssertEqual(
            subtitle,
            L10n.paywallCTASubtitleTrialMonthly(monthlyPrice: "$9.99", trialDays: 3)
        )
    }
}
