import Foundation
import StoreKit

enum SubscriptionProduct {
    static let legacyRemoveAds = "com.decibelpro.removeads.lifetime"
    static let weekly = "com.goodcraft.NoiseRecord.weekly"
    static let monthly = "com.goodcraft.NoiseRecord.monthly"
    static let yearly = "com.goodcraft.NoiseRecord.yearly"

    static let allSubscriptionIDs: Set<String> = [weekly, monthly, yearly]
    static let allProductIDs: Set<String> = [legacyRemoveAds, weekly, monthly, yearly]

    static func isSubscriptionProductID(_ productID: String) -> Bool {
        allSubscriptionIDs.contains(productID)
    }
}

/// 根据单笔已验证交易合并本地权益（可单测）。
enum EntitlementGrantMerge {
    struct Result: Equatable {
        let hasRemovedAds: Bool
        let isPremiumUser: Bool
        let purchasedProductIds: Set<String>
        let isEarlySupporter: Bool
    }

    static func merged(
        hasRemovedAds: Bool,
        isPremiumUser: Bool,
        purchasedProductIds: Set<String>,
        isLegacyPurchase: Bool,
        isSubscriptionPurchase: Bool,
        purchasedProductID: String
    ) -> Result? {
        guard isLegacyPurchase || isSubscriptionPurchase else { return nil }

        var nextHasRemovedAds = hasRemovedAds || isLegacyPurchase || isSubscriptionPurchase
        let nextIsPremium = isPremiumUser || isSubscriptionPurchase
        var nextProductIDs = purchasedProductIds
        nextProductIDs.insert(purchasedProductID)
        let nextEarlySupporter = isLegacyPurchase && !nextIsPremium

        return Result(
            hasRemovedAds: nextHasRemovedAds,
            isPremiumUser: nextIsPremium,
            purchasedProductIds: nextProductIDs,
            isEarlySupporter: nextEarlySupporter
        )
    }
}

enum SubscriptionTier: String, CaseIterable, Identifiable, Sendable {
    case weekly
    case monthly
    case yearly

    var id: String { rawValue }

    var productID: String {
        switch self {
        case .weekly: SubscriptionProduct.weekly
        case .monthly: SubscriptionProduct.monthly
        case .yearly: SubscriptionProduct.yearly
        }
    }

    var fallbackPrimaryPrice: String {
        switch self {
        case .weekly: L10n.paywallPriceWeeklyFallback
        case .monthly: L10n.paywallPriceMonthlyFallback
        case .yearly: L10n.paywallPriceYearlyFallback
        }
    }

    var fallbackSecondaryPrice: String? {
        switch self {
        case .yearly: L10n.paywallPriceYearlyMonthlyFallback
        case .monthly: L10n.paywallPriceMonthlyDailyFallback
        default: nil
        }
    }
}

enum PaywallContext: String, Sendable {
    case launch
    case settings
    case videoEvidence
    case aiFilter
    case advancedFFT
    case voiceDurationLimit
    case videoDailyLimit
    case videoDurationLimit
}

enum SubscriptionPurchaseResult: Sendable, Equatable {
    case purchased
    case pending
    case cancelled
}

enum SubscriptionManagerError: LocalizedError, Sendable, Equatable {
    case productNotFound
    case verificationFailed
    case nothingToRestore
    case entitlementNotGranted
    case unknownPurchaseResult

    var errorDescription: String? {
        switch self {
        case .productNotFound:
            L10n.iapErrorProductNotFound
        case .verificationFailed:
            L10n.iapErrorVerificationFailed
        case .nothingToRestore:
            L10n.iapErrorNothingToRestore
        case .entitlementNotGranted:
            L10n.iapErrorEntitlementNotGranted
        case .unknownPurchaseResult:
            L10n.iapErrorUnknown
        }
    }
}

enum PaywallPriceFormatter {
    static func monthlyEquivalentDisplay(from product: Product) -> String {
        monthlyEquivalentDisplay(fromDisplayPrice: product.displayPrice, price: product.price)
    }

    static func dailyEquivalentDisplay(from product: Product) -> String {
        dailyEquivalentDisplay(fromDisplayPrice: product.displayPrice, price: product.price)
    }

    static func monthlyEquivalentPrice(from product: Product) -> String {
        var monthly = product.price / 12
        var rounded = Decimal()
        NSDecimalRound(&rounded, &monthly, 2, .down)
        if let formatted = formattedCurrency(rounded, localeIdentifier: localeIdentifier(from: product.displayPrice)) {
            return formatted
        }
        return "$1.66"
    }

    static func monthlyEquivalentDisplay(fromDisplayPrice displayPrice: String, price: Decimal) -> String {
        var monthly = price / 12
        var rounded = Decimal()
        NSDecimalRound(&rounded, &monthly, 2, .down)
        if let formatted = formattedCurrency(rounded, localeIdentifier: localeIdentifier(from: displayPrice)) {
            return L10n.paywallYearlyMonthlyEquivalent(formatted)
        }
        return L10n.paywallPriceYearlyMonthlyFallback
    }

    static func dailyEquivalentDisplay(fromDisplayPrice displayPrice: String, price: Decimal) -> String {
        var daily = price / 30
        var rounded = Decimal()
        NSDecimalRound(&rounded, &daily, 2, .down)
        if let formatted = formattedCurrency(rounded, localeIdentifier: localeIdentifier(from: displayPrice)) {
            return L10n.paywallMonthlyDailyEquivalent(formatted)
        }
        return L10n.paywallPriceMonthlyDailyFallback
    }

    private static func localeIdentifier(from displayPrice: String) -> String {
        displayPrice.contains("$") ? "en_US" : Locale.current.identifier
    }

    private static func formattedCurrency(_ value: Decimal, localeIdentifier: String) -> String? {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: localeIdentifier)
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: value as NSDecimalNumber)
    }
}

enum PaywallOfferPresentation {
    static func purchaseButtonTitle(showsFreeTrial: Bool, trialDays: Int) -> String {
        if showsFreeTrial {
            return L10n.paywallCTAStartFreeTrial(days: trialDays)
        }
        return L10n.paywallCTASubscribeNow
    }

    static func purchaseButtonSubtitle(
        tier: SubscriptionTier,
        showsFreeTrial: Bool,
        trialDays: Int,
        tierPrice: String,
        monthlyEquivalentPrice: String
    ) -> String {
        switch tier {
        case .yearly:
            if showsFreeTrial {
                return L10n.paywallCTASubtitleTrialYearly(
                    monthlyPrice: monthlyEquivalentPrice,
                    trialDays: trialDays
                )
            }
            return L10n.paywallCTASubtitleStandardYearly(
                annualPrice: tierPrice,
                monthlyPrice: monthlyEquivalentPrice
            )
        case .weekly:
            return L10n.paywallCTASubtitleStandardWeekly(tierPrice)
        case .monthly:
            if showsFreeTrial {
                return L10n.paywallCTASubtitleTrialMonthly(
                    monthlyPrice: tierPrice,
                    trialDays: trialDays
                )
            }
            return L10n.paywallCTASubtitleStandardMonthly(tierPrice)
        }
    }
}

/// Backward compatibility with the legacy remove-ads purchase API.
typealias RemoveAdsPurchaseResult = SubscriptionPurchaseResult
typealias IAPManagerError = SubscriptionManagerError
