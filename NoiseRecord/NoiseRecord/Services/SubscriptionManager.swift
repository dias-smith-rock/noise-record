import CryptoKit
import Foundation
import StoreKit

// MARK: - 本地权益缓存 v2（双闸门 HMAC）

private enum EntitlementLocalCacheV2 {
    struct Snapshot: Sendable, Equatable {
        let hasRemovedAds: Bool
        let isPremiumUser: Bool
    }

    private static let markerKey = "iap.entitlement.v2.marker"
    private static let proofKey = "iap.entitlement.v2.proof"

    private static let adsGranted: UInt8 = 0xA7
    private static let adsRevoked: UInt8 = 0x5C
    private static let premiumGranted: UInt8 = 0xB3
    private static let premiumRevoked: UInt8 = 0x6D

    private static var sealingMaterial: String {
        let bundleID = Bundle.main.bundleIdentifier ?? "com.goodcraft.NoiseRecord"
        return "\(SubscriptionProduct.legacyRemoveAds)|\(bundleID)|DecibelPro-Entitlement-v2"
    }

    private static var sealingKey: SymmetricKey {
        SymmetricKey(data: Data(SHA256.hash(data: Data(sealingMaterial.utf8))))
    }

    static func write(hasRemovedAds: Bool, isPremiumUser: Bool) {
        let markerData = Data([
            hasRemovedAds ? adsGranted : adsRevoked,
            isPremiumUser ? premiumGranted : premiumRevoked,
        ])
        let proof = HMAC<SHA256>.authenticationCode(
            for: markerData + Data(sealingMaterial.utf8),
            using: sealingKey
        )
        let defaults = UserDefaults.standard
        defaults.set(markerData.base64EncodedString(), forKey: markerKey)
        defaults.set(Data(proof).base64EncodedString(), forKey: proofKey)
    }

    static func readFastPath() -> Snapshot? {
        let defaults = UserDefaults.standard
        guard
            let markerBase64 = defaults.string(forKey: markerKey),
            let proofBase64 = defaults.string(forKey: proofKey),
            let markerData = Data(base64Encoded: markerBase64),
            let storedProof = Data(base64Encoded: proofBase64),
            markerData.count == 2
        else {
            return nil
        }

        let expectedProof = HMAC<SHA256>.authenticationCode(
            for: markerData + Data(sealingMaterial.utf8),
            using: sealingKey
        )
        guard Data(expectedProof) == storedProof else {
            return nil
        }

        return Snapshot(
            hasRemovedAds: markerData[0] == adsGranted,
            isPremiumUser: markerData[1] == premiumGranted
        )
    }

    static func clear() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: markerKey)
        defaults.removeObject(forKey: proofKey)
    }
}

// MARK: - SubscriptionManager

/// StoreKit 2 双闸门变现单例：免广告 + Premium 订阅。
@Observable
@MainActor
final class SubscriptionManager {
    static let shared = SubscriptionManager()
    nonisolated static let entitlementsDidChangeNotification = Notification.Name(
        "SubscriptionManager.entitlementsDidChange"
    )

    static let removeAdsProductID = SubscriptionProduct.legacyRemoveAds

    nonisolated(unsafe) private(set) static var adsRemovedSnapshot = false
    nonisolated(unsafe) private(set) static var isPremiumSnapshot = false

    private(set) var hasRemovedAds = false
    private(set) var isPremiumUser = false
    private(set) var isEarlySupporter = false
    private(set) var isPurchasing = false
    private(set) var purchasedProductIds: Set<String> = []

    /// Legacy alias — maps to `hasRemovedAds`.
    var isAdsRemoved: Bool { hasRemovedAds }

    /// 7 日睡眠历史（免费功能）。
    var canAccessSleepHistory: Bool { true }

    /// 睡眠数据导出（CSV / 司法级 PDF 分享）。
    var canAccessSleepExport: Bool {
        isPremiumUser
    }

    private var cachedProducts: [String: Product] = [:]
    private var introductoryOfferEligibility: [String: Bool] = [:]
    private(set) var isRefreshingIntroductoryEligibility = false
    private var transactionUpdatesTask: Task<Void, Never>?
    private var finishedTransactionIDs = Set<UInt64>()

    private init() {
        if let snapshot = EntitlementLocalCacheV2.readFastPath() {
            applyEntitlementState(
                hasRemovedAds: snapshot.hasRemovedAds,
                isPremiumUser: snapshot.isPremiumUser,
                purchasedProductIds: purchasedProductIds,
                persistLocally: false
            )
            AppTelemetry.logIAPLifecycle(
                step: "init_fast_path",
                metadata: [
                    "has_removed_ads": String(snapshot.hasRemovedAds),
                    "is_premium": String(snapshot.isPremiumUser),
                ]
            )
        }

        transactionUpdatesTask = Task { [weak self] in
            await self?.listenForTransactionUpdates()
        }

        Task {
            await checkEntitlements(allowDowngrade: false)
        }

        Task {
            await prefetchProducts()
        }
    }

    // MARK: - Legacy remove-ads API

    var isRemoveAdsProductLoaded: Bool {
        cachedProducts[SubscriptionProduct.legacyRemoveAds] != nil
    }

    var removeAdsDisplayPrice: String? { removeAdsSaleDisplayPrice }

    var removeAdsOriginalDisplayPrice: String {
        L10n.settingsRemoveAdsPriceOriginal
    }

    var removeAdsSaleDisplayPrice: String {
        cachedProducts[SubscriptionProduct.legacyRemoveAds]?.displayPrice
            ?? L10n.settingsRemoveAdsPriceSale
    }

    func purchaseRemoveAds() async throws -> SubscriptionPurchaseResult {
        let product: Product
        if let cached = cachedProducts[SubscriptionProduct.legacyRemoveAds] {
            product = cached
        } else {
            product = try await loadProduct(id: SubscriptionProduct.legacyRemoveAds)
        }
        return try await purchase(product: product, tier: nil)
    }

    // MARK: - Subscription API

    func product(for tier: SubscriptionTier) -> Product? {
        cachedProducts[tier.productID]
    }

    func displayPrice(for tier: SubscriptionTier) -> String {
        product(for: tier)?.displayPrice ?? tier.fallbackPrimaryPrice
    }

    func primaryDisplayText(for tier: SubscriptionTier) -> String {
        switch tier {
        case .weekly:
            L10n.paywallWeeklyPrice(displayPrice(for: .weekly))
        case .monthly:
            L10n.paywallMonthlyPrice(displayPrice(for: .monthly))
        case .yearly:
            L10n.paywallYearlyPrice(displayPrice(for: .yearly))
        }
    }

    func secondaryDisplayText(for tier: SubscriptionTier) -> String? {
        switch tier {
        case .yearly:
            if let product = product(for: .yearly) {
                return PaywallPriceFormatter.monthlyEquivalentDisplay(from: product)
            }
            return tier.fallbackSecondaryPrice
        case .monthly:
            if let product = product(for: .monthly) {
                return PaywallPriceFormatter.dailyEquivalentDisplay(from: product)
            }
            return tier.fallbackSecondaryPrice
        case .weekly:
            return nil
        }
    }

    func monthlyEquivalentPrice(for tier: SubscriptionTier) -> String {
        if let product = product(for: tier) {
            return PaywallPriceFormatter.monthlyEquivalentPrice(from: product)
        }
        switch tier {
        case .yearly: return "$1.66"
        case .monthly: return displayPrice(for: .monthly)
        case .weekly: return displayPrice(for: .weekly)
        }
    }

    func isEligibleForIntroductoryOffer(tier: SubscriptionTier) -> Bool {
        introductoryOfferEligibility[tier.productID] ?? false
    }

    func hasIntroductoryOffer(tier: SubscriptionTier) -> Bool {
        product(for: tier)?.subscription?.introductoryOffer != nil
    }

    func shouldPresentFreeTrial(for tier: SubscriptionTier) -> Bool {
        isEligibleForIntroductoryOffer(tier: tier) && hasIntroductoryOffer(tier: tier)
    }

    func introductoryTrialDays(for tier: SubscriptionTier) -> Int {
        guard let period = product(for: tier)?.subscription?.introductoryOffer?.period else {
            return 3
        }
        switch period.unit {
        case .day: return max(1, period.value)
        case .week: return max(1, period.value * 7)
        case .month: return max(1, period.value * 30)
        case .year: return max(1, period.value * 365)
        @unknown default: return 3
        }
    }

    func purchaseButtonTitle(for tier: SubscriptionTier) -> String {
        PaywallOfferPresentation.purchaseButtonTitle(
            showsFreeTrial: shouldPresentFreeTrial(for: tier),
            trialDays: introductoryTrialDays(for: tier)
        )
    }

    func purchaseButtonSubtitle(for tier: SubscriptionTier) -> String {
        PaywallOfferPresentation.purchaseButtonSubtitle(
            tier: tier,
            showsFreeTrial: shouldPresentFreeTrial(for: tier),
            trialDays: introductoryTrialDays(for: tier),
            tierPrice: displayPrice(for: tier),
            monthlyEquivalentPrice: monthlyEquivalentPrice(for: tier)
        )
    }

    func refreshIntroductoryOfferEligibility() async {
        isRefreshingIntroductoryEligibility = true
        defer { isRefreshingIntroductoryEligibility = false }

        var updated: [String: Bool] = [:]
        for tier in SubscriptionTier.allCases {
            do {
                let product = try await loadProduct(id: tier.productID)
                if let subscription = product.subscription {
                    updated[tier.productID] = await subscription.isEligibleForIntroOffer
                } else {
                    updated[tier.productID] = false
                }
            } catch {
                AppTelemetry.recordError(error, context: "iap_intro_eligibility")
                updated[tier.productID] = false
            }
        }
        introductoryOfferEligibility = updated
    }

    func purchase(tier: SubscriptionTier) async throws -> SubscriptionPurchaseResult {
        let product = try await loadProduct(id: tier.productID)
        return try await purchase(product: product, tier: tier)
    }

    func restorePurchases() async throws {
        isPurchasing = true
        defer { isPurchasing = false }

        AppTelemetry.logIAPLifecycle(step: "restore_started")
        try await AppStore.sync()
        await checkEntitlements(allowDowngrade: true)

        if !hasRemovedAds && !isPremiumUser {
            await checkEntitlementsWithRetry()
        }

        guard hasRemovedAds || isPremiumUser else {
            AppTelemetry.logIAPLifecycle(step: "restore_nothing_found")
            throw SubscriptionManagerError.nothingToRestore
        }

        AppTelemetry.logIAPLifecycle(step: "restore_succeeded")
    }

    func checkEntitlements(allowDowngrade: Bool = false) async {
        var legacyActive = false
        var subscriptionActive = false
        var activeProductIDs = Set<String>()
        var verifiedCount = 0

        for await verificationResult in Transaction.currentEntitlements {
            guard case .verified(let transaction) = verificationResult else {
                AppTelemetry.logIAPLifecycle(step: "entitlement_skipped_unverified")
                continue
            }

            verifiedCount += 1

            if isActiveLegacyRemoveAds(transaction) {
                legacyActive = true
                activeProductIDs.insert(transaction.productID)
            }

            if isActiveSubscription(transaction) {
                subscriptionActive = true
                activeProductIDs.insert(transaction.productID)
            }
        }

        let nextHasRemovedAds = legacyActive || subscriptionActive
        let nextIsPremium = subscriptionActive
        let nextEarlySupporter = legacyActive && !subscriptionActive

        if legacyActive && !subscriptionActive {
            AppTelemetry.logCommercialEvent(
                domain: "iap",
                outcome: "legacy_entitlement_detected",
                metadata: ["product_id": SubscriptionProduct.legacyRemoveAds]
            )
        }

        AppTelemetry.logIAPLifecycle(
            step: "entitlement_check_completed",
            metadata: [
                "has_removed_ads": String(nextHasRemovedAds),
                "is_premium": String(nextIsPremium),
                "verified_count": String(verifiedCount),
                "allow_downgrade": String(allowDowngrade),
            ]
        )

        if nextHasRemovedAds || nextIsPremium {
            applyEntitlementState(
                hasRemovedAds: nextHasRemovedAds,
                isPremiumUser: nextIsPremium,
                purchasedProductIds: activeProductIDs,
                persistLocally: true
            )
            isEarlySupporter = nextEarlySupporter
        } else if allowDowngrade || (!hasRemovedAds && !isPremiumUser) {
            applyEntitlementState(
                hasRemovedAds: false,
                isPremiumUser: false,
                purchasedProductIds: [],
                persistLocally: false
            )
            isEarlySupporter = false
        } else {
            purchasedProductIds = activeProductIDs
            isEarlySupporter = nextEarlySupporter
        }
    }

    // MARK: - Private

    private func purchase(product: Product, tier: SubscriptionTier?) async throws -> SubscriptionPurchaseResult {
        isPurchasing = true
        defer { isPurchasing = false }

        AppTelemetry.logIAPLifecycle(
            step: "purchase_started",
            metadata: ["product_id": product.id]
        )

        let purchaseResult: Product.PurchaseResult
        do {
            purchaseResult = try await product.purchase()
        } catch {
            AppTelemetry.recordError(error, context: "iap_purchase_throw")
            throw error
        }

        switch purchaseResult {
        case .success(let verificationResult):
            switch verificationResult {
            case .verified(let transaction):
                AppTelemetry.logIAPLifecycle(
                    step: "purchase_verified",
                    metadata: [
                        "transaction_id": String(transaction.id),
                        "product_id": transaction.productID,
                    ]
                )
                if let tier {
                    AppTelemetry.logCommercialEvent(
                        domain: "sub",
                        outcome: "purchase_success",
                        metadata: ["tier": tier.rawValue]
                    )
                }
                grantEntitlement(from: transaction)
                await finishTransactionIfNeeded(transaction)
                await checkEntitlements(allowDowngrade: false)
                if !isPremiumUser && SubscriptionProduct.isSubscriptionProductID(transaction.productID) {
                    await checkEntitlementsWithRetry()
                }
                guard isPremiumUser || isActiveLegacyRemoveAds(transaction) else {
                    AppTelemetry.logIAPLifecycle(step: "purchase_entitlement_not_granted")
                    throw SubscriptionManagerError.entitlementNotGranted
                }
                return .purchased

            case .unverified(let transaction, let error):
                AppTelemetry.recordError(error, context: "iap_purchase_unverified")
                await finishTransactionIfNeeded(transaction)
                throw SubscriptionManagerError.verificationFailed
            }

        case .userCancelled:
            AppTelemetry.logIAPLifecycle(step: "purchase_user_cancelled")
            try? await AppStore.sync()
            await checkEntitlements(allowDowngrade: false)
            if hasRemovedAds || isPremiumUser {
                AppTelemetry.logIAPLifecycle(step: "purchase_cancelled_but_entitled")
                return .purchased
            }
            return .cancelled

        case .pending:
            AppTelemetry.logIAPLifecycle(step: "purchase_pending")
            return .pending

        @unknown default:
            AppTelemetry.logIAPLifecycle(step: "purchase_unknown_result")
            throw SubscriptionManagerError.unknownPurchaseResult
        }
    }

    private func listenForTransactionUpdates() async {
        for await verificationResult in Transaction.updates {
            switch verificationResult {
            case .verified(let transaction):
                AppTelemetry.logIAPLifecycle(
                    step: "transaction_update_verified",
                    metadata: [
                        "transaction_id": String(transaction.id),
                        "product_id": transaction.productID,
                    ]
                )
                grantEntitlement(from: transaction)
                await finishTransactionIfNeeded(transaction)
                await checkEntitlements(allowDowngrade: false)

            case .unverified(let transaction, let error):
                AppTelemetry.recordError(error, context: "iap_transaction_update_unverified")
                await finishTransactionIfNeeded(transaction)
            }
        }
    }

    private func grantEntitlement(from transaction: Transaction) {
        let legacy = isActiveLegacyRemoveAds(transaction)
        let subscription = isActiveSubscription(transaction)
        guard let merged = EntitlementGrantMerge.merged(
            hasRemovedAds: hasRemovedAds,
            isPremiumUser: isPremiumUser,
            purchasedProductIds: purchasedProductIds,
            isLegacyPurchase: legacy,
            isSubscriptionPurchase: subscription,
            purchasedProductID: transaction.productID
        ) else {
            return
        }

        applyEntitlementState(
            hasRemovedAds: merged.hasRemovedAds,
            isPremiumUser: merged.isPremiumUser,
            purchasedProductIds: merged.purchasedProductIds,
            persistLocally: true
        )
        isEarlySupporter = merged.isEarlySupporter

        AppTelemetry.logIAPLifecycle(
            step: "entitlement_granted_from_transaction",
            metadata: [
                "product_id": transaction.productID,
                "has_removed_ads": String(merged.hasRemovedAds),
                "is_premium": String(merged.isPremiumUser),
            ]
        )
    }

    private func checkEntitlementsWithRetry(maxAttempts: Int = 3, delayMs: UInt64 = 300) async {
        guard maxAttempts > 1 else { return }

        for _ in 1..<maxAttempts {
            guard !hasRemovedAds && !isPremiumUser else { return }
            try? await Task.sleep(nanoseconds: delayMs * 1_000_000)
            await checkEntitlements(allowDowngrade: false)
        }
    }

    private func isActiveLegacyRemoveAds(_ transaction: Transaction) -> Bool {
        transaction.productID == SubscriptionProduct.legacyRemoveAds
            && transaction.revocationDate == nil
    }

    private func isActiveSubscription(_ transaction: Transaction) -> Bool {
        guard SubscriptionProduct.allSubscriptionIDs.contains(transaction.productID) else {
            return false
        }
        guard transaction.revocationDate == nil else { return false }
        if let expirationDate = transaction.expirationDate {
            return expirationDate > Date()
        }
        return true
    }

    private func applyEntitlementState(
        hasRemovedAds: Bool,
        isPremiumUser: Bool,
        purchasedProductIds: Set<String>,
        persistLocally: Bool
    ) {
        self.hasRemovedAds = hasRemovedAds
        self.isPremiumUser = isPremiumUser
        self.purchasedProductIds = purchasedProductIds
        Self.adsRemovedSnapshot = hasRemovedAds
        Self.isPremiumSnapshot = isPremiumUser

        if persistLocally {
            EntitlementLocalCacheV2.write(
                hasRemovedAds: hasRemovedAds,
                isPremiumUser: isPremiumUser
            )
        } else if !hasRemovedAds && !isPremiumUser {
            EntitlementLocalCacheV2.clear()
        }

        NotificationCenter.default.post(name: Self.entitlementsDidChangeNotification, object: self)
    }

    private func finishTransactionIfNeeded(_ transaction: Transaction) async {
        let transactionID = transaction.id
        guard !finishedTransactionIDs.contains(transactionID) else { return }
        finishedTransactionIDs.insert(transactionID)
        await transaction.finish()
    }

    private func prefetchProducts() async {
        do {
            let products = try await Product.products(for: Array(SubscriptionProduct.allProductIDs))
            for product in products {
                cachedProducts[product.id] = product
            }
            await refreshIntroductoryOfferEligibility()
        } catch {
            AppTelemetry.recordError(error, context: "iap_prefetch_products")
        }
    }

    private func loadProduct(id: String) async throws -> Product {
        if let cached = cachedProducts[id] {
            return cached
        }
        let products = try await Product.products(for: [id])
        guard let product = products.first else {
            throw SubscriptionManagerError.productNotFound
        }
        cachedProducts[id] = product
        return product
    }
}

/// Backward compatibility alias.
typealias IAPManager = SubscriptionManager

extension SubscriptionManager {
    /// Legacy entitlement check name.
    func checkPurchasedEntitlements(allowDowngrade: Bool = false) async {
        await checkEntitlements(allowDowngrade: allowDowngrade)
    }
}
