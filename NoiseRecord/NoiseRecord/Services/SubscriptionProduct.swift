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

    static func monthlyEquivalentDisplay(fromDisplayPrice displayPrice: String, price: Decimal) -> String {
        var monthly = price / 12
        var rounded = Decimal()
        NSDecimalRound(&rounded, &monthly, 2, .down)
        if let formatted = formattedCurrency(rounded, localeIdentifier: localeIdentifier(from: displayPrice)) {
            return L10n.paywallYearlyMonthlyEquivalent(formatted)
        }
        return L10n.paywallPriceYearlyMonthlyFallback
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

/// Backward compatibility with the legacy remove-ads purchase API.
typealias RemoveAdsPurchaseResult = SubscriptionPurchaseResult
typealias IAPManagerError = SubscriptionManagerError
