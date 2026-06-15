import CryptoKit
import Foundation
import StoreKit

// MARK: - 购买结果

/// 发起「永久免广告」购买后的业务结果（不含网络/验签失败等异常）。
enum RemoveAdsPurchaseResult: Sendable, Equatable {
    /// 购买成功且 JWS 验签通过，免广告已生效。
    case purchased
    /// 交易待处理（常见于「购买前询问」/家长批准流程）。
    case pending
    /// 用户主动取消。
    case cancelled
}

/// 内购流程中可预期的错误类型。
enum IAPManagerError: LocalizedError, Sendable, Equatable {
    case productNotFound
    case verificationFailed
    case nothingToRestore
    case unknownPurchaseResult

    var errorDescription: String? {
        switch self {
        case .productNotFound:
            L10n.iapErrorProductNotFound
        case .verificationFailed:
            L10n.iapErrorVerificationFailed
        case .nothingToRestore:
            L10n.iapErrorNothingToRestore
        case .unknownPurchaseResult:
            L10n.iapErrorUnknown
        }
    }
}

// MARK: - 本地权益缓存（HMAC 防篡改）

/// 双层缓存中的「快路径」：启动瞬间读取，避免等待 StoreKit 网络往返。
/// 使用 HMAC-SHA256 对布尔标记做完整性校验，降低直接改 UserDefaults 破解门槛。
private enum IAPEntitlementLocalCache {
    private static let markerKey = "iap.entitlement.v1.marker"
    private static let proofKey = "iap.entitlement.v1.proof"

    /// 已授权标记的字节常量（非明文 true/false）。
    private static let grantedMarker: UInt8 = 0xA7
    private static let revokedMarker: UInt8 = 0x5C

    private static var sealingMaterial: String {
        let bundleID = Bundle.main.bundleIdentifier ?? "com.goodcraft.NoiseRecord"
        return "\(IAPManager.removeAdsProductID)|\(bundleID)|DecibelPro-IAP-v1"
    }

    private static var sealingKey: SymmetricKey {
        SymmetricKey(data: Data(SHA256.hash(data: Data(sealingMaterial.utf8))))
    }

    /// 将验签通过后的免广告状态写入本地。
    static func write(granted: Bool) {
        let marker = granted ? grantedMarker : revokedMarker
        let markerData = Data([marker])
        let proof = HMAC<SHA256>.authenticationCode(
            for: markerData + Data(sealingMaterial.utf8),
            using: sealingKey
        )

        let defaults = UserDefaults.standard
        defaults.set(markerData.base64EncodedString(), forKey: markerKey)
        defaults.set(Data(proof).base64EncodedString(), forKey: proofKey)
    }

    /// 启动时同步读取；仅当 HMAC 校验通过且标记为已授权时返回 true。
    static func readFastPath() -> Bool {
        let defaults = UserDefaults.standard
        guard
            let markerBase64 = defaults.string(forKey: markerKey),
            let proofBase64 = defaults.string(forKey: proofKey),
            let markerData = Data(base64Encoded: markerBase64),
            let storedProof = Data(base64Encoded: proofBase64),
            markerData.count == 1
        else {
            return false
        }

        let expectedProof = HMAC<SHA256>.authenticationCode(
            for: markerData + Data(sealingMaterial.utf8),
            using: sealingKey
        )
        guard Data(expectedProof) == storedProof else {
            return false
        }

        return markerData[0] == grantedMarker
    }

    static func clear() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: markerKey)
        defaults.removeObject(forKey: proofKey)
    }
}

// MARK: - IAPManager

/// StoreKit 2 内购管理单例：永久买断免广告（Non-Consumable）。
///
/// 纯客户端闭环：
/// 1. 启动读本地 HMAC 缓存 → 瞬间解锁 UI
/// 2. 后台 `Transaction.currentEntitlements` JWS 权威校验
/// 3. `Transaction.updates` 实时监听运行期/后台交易变更
@Observable
@MainActor
final class IAPManager {
    static let shared = IAPManager()

    /// App Store Connect 中配置的非消耗型产品 ID。
    static let removeAdsProductID = "com.decibelpro.removeads.lifetime"

    /// 供非 MainActor 代码（如广告配置）同步读取的免广告快照。
    /// 与 `isAdsRemoved` 保持同步，避免跨 actor 访问。
    nonisolated(unsafe) private(set) static var adsRemovedSnapshot = false

    /// 是否已免广告（驱动 UI 与广告 SDK 开关）。
    private(set) var isAdsRemoved = false

    /// 是否正在与 StoreKit 通信（购买 / 恢复 / 同步）。
    private(set) var isPurchasing = false

    /// StoreKit 是否已成功拉取到商品（区分营销兜底价与真实商店价）。
    var isRemoveAdsProductLoaded: Bool {
        cachedRemoveAdsProduct != nil
    }

    /// 缓存的商品信息，避免每次购买重复拉取。
    private var cachedRemoveAdsProduct: Product?

    /// 后台交易流监听任务；App 生命周期内持续运行。
    private var transactionUpdatesTask: Task<Void, Never>?

    /// 已 finish 的交易 ID，避免 `purchase()` 与 `Transaction.updates` 双路径重复 finish。
    private var finishedTransactionIDs = Set<UInt64>()

    private init() {
        // 第一层：本地 HMAC 缓存，冷启动零等待解锁 UI。
        let fastPathGranted = IAPEntitlementLocalCache.readFastPath()
        applyAdsRemovedState(fastPathGranted, persistLocally: false)
        AppTelemetry.logIAPLifecycle(
            step: "init_fast_path",
            metadata: ["granted": String(fastPathGranted)]
        )

        // 实时监听交易更新（购买完成、退款、家庭共享变更等）。
        transactionUpdatesTask = Task { [weak self] in
            await self?.listenForTransactionUpdates()
        }

        // 第二层：StoreKit 2 权威 JWS 校验（可纠正本地缓存；启动时不主动降级以防竞态）。
        Task {
            await checkPurchasedEntitlements(allowDowngrade: false)
        }

        // 预拉商品元数据，购买按钮可展示本地化价格。
        Task {
            await prefetchRemoveAdsProduct()
        }
    }

    // MARK: - 对外 API

    /// 永久免广告商品的本地化展示价格；未加载完成时回退到营销定价。
    var removeAdsDisplayPrice: String? {
        removeAdsSaleDisplayPrice
    }

    /// 营销展示用原价（App Store 划线价）。
    var removeAdsOriginalDisplayPrice: String {
        L10n.settingsRemoveAdsPriceOriginal
    }

    /// 营销展示用折后价；优先使用 StoreKit 返回的本地化实付价。
    var removeAdsSaleDisplayPrice: String {
        cachedRemoveAdsProduct?.displayPrice ?? L10n.settingsRemoveAdsPriceSale
    }

    /// 发起永久免广告购买。
    func purchaseRemoveAds() async throws -> RemoveAdsPurchaseResult {
        isPurchasing = true
        defer { isPurchasing = false }

        AppTelemetry.logIAPLifecycle(step: "purchase_started")

        let product: Product
        do {
            product = try await loadRemoveAdsProduct()
        } catch {
            AppTelemetry.recordError(error, context: "iap_purchase_load_product")
            throw error
        }

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
                await handleVerifiedRemoveAdsTransaction(transaction)
                await finishTransactionIfNeeded(transaction)
                await checkPurchasedEntitlements(allowDowngrade: false)
                return .purchased

            case .unverified(let transaction, let error):
                AppTelemetry.recordError(error, context: "iap_purchase_unverified")
                await finishTransactionIfNeeded(transaction)
                throw IAPManagerError.verificationFailed
            }

        case .userCancelled:
            AppTelemetry.logIAPLifecycle(step: "purchase_user_cancelled")
            // 沙盒/非消耗型已购时，系统常返回 userCancelled 而非 success；补一次权益同步。
            try? await AppStore.sync()
            await checkPurchasedEntitlements(allowDowngrade: false)
            if isAdsRemoved {
                AppTelemetry.logIAPLifecycle(step: "purchase_cancelled_but_entitled")
                return .purchased
            }
            return .cancelled

        case .pending:
            AppTelemetry.logIAPLifecycle(step: "purchase_pending")
            return .pending

        @unknown default:
            AppTelemetry.logIAPLifecycle(step: "purchase_unknown_result")
            throw IAPManagerError.unknownPurchaseResult
        }
    }

    /// 恢复购买：同步 Apple ID 交易记录后重新验签权益。
    func restorePurchases() async throws {
        isPurchasing = true
        defer { isPurchasing = false }

        AppTelemetry.logIAPLifecycle(step: "restore_started")
        try await AppStore.sync()
        await checkPurchasedEntitlements(allowDowngrade: true)

        guard isAdsRemoved else {
            AppTelemetry.logIAPLifecycle(step: "restore_nothing_found")
            throw IAPManagerError.nothingToRestore
        }

        AppTelemetry.logIAPLifecycle(step: "restore_succeeded")
    }

    // MARK: - 权益校验

    /// 遍历 `Transaction.currentEntitlements`，仅信任 `.verified` 且 productID 匹配的交易。
    /// - Parameter allowDowngrade: 为 false 时，若当前已授权则不因空 entitlements 回写为未授权（防启动竞态）。
    func checkPurchasedEntitlements(allowDowngrade: Bool = false) async {
        var entitled = false
        var verifiedCount = 0

        for await verificationResult in Transaction.currentEntitlements {
            guard case .verified(let transaction) = verificationResult else {
                AppTelemetry.logIAPLifecycle(step: "entitlement_skipped_unverified")
                continue
            }

            verifiedCount += 1

            guard transaction.productID == Self.removeAdsProductID else {
                continue
            }

            // 非消耗型：退款或撤销后 revocationDate 非空，需收回权益。
            if transaction.revocationDate == nil {
                entitled = true
            }
        }

        AppTelemetry.logIAPLifecycle(
            step: "entitlement_check_completed",
            metadata: [
                "entitled": String(entitled),
                "verified_count": String(verifiedCount),
                "allow_downgrade": String(allowDowngrade),
                "current_granted": String(isAdsRemoved),
            ]
        )

        if entitled {
            applyAdsRemovedState(true, persistLocally: true)
        } else if allowDowngrade || !isAdsRemoved {
            applyAdsRemovedState(false, persistLocally: false)
        }
    }

    // MARK: - 交易流监听

    /// 持续消费 `Transaction.updates`，捕获 App 前台/后台期间的新交易与状态变更。
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
                if transaction.productID == Self.removeAdsProductID {
                    await handleVerifiedRemoveAdsTransaction(transaction)
                }
                await finishTransactionIfNeeded(transaction)

            case .unverified(let transaction, let error):
                AppTelemetry.recordError(error, context: "iap_transaction_update_unverified")
                await finishTransactionIfNeeded(transaction)
            }
        }
    }

    // MARK: - 内部状态机

    private func handleVerifiedRemoveAdsTransaction(_ transaction: Transaction) async {
        let granted = transaction.revocationDate == nil
        AppTelemetry.logIAPLifecycle(
            step: "transaction_apply_entitlement",
            metadata: ["granted": String(granted)]
        )
        applyAdsRemovedState(granted, persistLocally: granted)
    }

    private func finishTransactionIfNeeded(_ transaction: Transaction) async {
        let transactionID = transaction.id
        guard !finishedTransactionIDs.contains(transactionID) else {
            AppTelemetry.logIAPLifecycle(
                step: "transaction_finish_skipped_duplicate",
                metadata: ["transaction_id": String(transactionID)]
            )
            return
        }

        finishedTransactionIDs.insert(transactionID)
        await transaction.finish()
        AppTelemetry.logIAPLifecycle(
            step: "transaction_finished",
            metadata: ["transaction_id": String(transactionID)]
        )
    }

    /// 统一更新内存状态、广告快照与本地缓存。
    private func applyAdsRemovedState(_ granted: Bool, persistLocally: Bool) {
        isAdsRemoved = granted
        Self.adsRemovedSnapshot = granted

        if persistLocally {
            IAPEntitlementLocalCache.write(granted: granted)
        } else if !granted {
            IAPEntitlementLocalCache.clear()
        }
    }

    private func prefetchRemoveAdsProduct() async {
        do {
            _ = try await loadRemoveAdsProduct()
        } catch {
            AppTelemetry.recordError(error, context: "iap_prefetch_product")
        }
    }

    private func loadRemoveAdsProduct() async throws -> Product {
        if let cachedRemoveAdsProduct {
            AppTelemetry.logIAPLifecycle(step: "product_load_cache_hit")
            return cachedRemoveAdsProduct
        }

        AppTelemetry.logIAPLifecycle(
            step: "product_load_started",
            metadata: ["product_id": Self.removeAdsProductID]
        )

        let products = try await Product.products(for: [Self.removeAdsProductID])
        AppTelemetry.logIAPLifecycle(
            step: "product_load_completed",
            metadata: ["count": String(products.count)]
        )

        guard let product = products.first else {
            AppTelemetry.logIAPLifecycle(step: "product_load_not_found")
            throw IAPManagerError.productNotFound
        }

        cachedRemoveAdsProduct = product
        AppTelemetry.logIAPLifecycle(
            step: "product_load_succeeded",
            metadata: [
                "display_price": product.displayPrice,
                "product_id": product.id,
            ]
        )
        return product
    }
}
