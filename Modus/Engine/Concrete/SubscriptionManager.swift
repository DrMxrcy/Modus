import Foundation
import StoreKit
import OSLog

private let logger = Logger(subsystem: "app.modus", category: "SubscriptionManager")

enum SubscriptionTier: String, Sendable {
    case freeTier
    case proTier
    case proPlusSelfHosted
}

/// Subscription-related product identifiers.
/// The group ID is queried at runtime; the product ID is what StoreKit loads for purchase.
enum StoreKitProductID {
    /// Group ID for subscription status queries. Matches `premium_monthly_group` in
    /// `Modus.storekit` and the real App Store Connect group (when configured).
    static let subscriptionGroupID = "premium_monthly_group"

    /// Product ID for the Pro monthly auto-renewable. Matches the .storekit config and
    /// the real App Store Connect product. Replace with the real ASC product ID at D4.
    static let proMonthly = "com.jp.modus.pro.monthly"
}

@MainActor
final class SubscriptionManager: ObservableObject {
    @Published private(set) var activeTier: SubscriptionTier = .freeTier
    @Published private(set) var products: [Product] = []
    @Published var purchaseError: String? = nil
    @Published var isPurchasing: Bool = false
    @Published var isRestoring: Bool = false

    private var updatesTask: Task<Void, Error>? = nil

    init() {
        updatesTask = Task {
            for await result in Transaction.updates {
                await handleTransactionUpdate(result)
            }
        }

        Task {
            await updateSubscriptionStatus()
            await loadProducts()
        }
    }

    // MARK: - Status / product loading

    func updateSubscriptionStatus() async {
        do {
            let statuses = try await Product.SubscriptionInfo.status(for: StoreKitProductID.subscriptionGroupID)
            guard let firstStatus = statuses.first else {
                self.activeTier = .freeTier
                logger.debug("No active subscription (free tier)")
                return
            }

            switch firstStatus.state {
            case .subscribed, .inGracePeriod:
                self.activeTier = .proTier
                logger.debug("Active tier = Pro")
            default:
                self.activeTier = .freeTier
                let stateDesc = String(describing: firstStatus.state)
                logger.debug("Active tier = Free (state: \(stateDesc, privacy: .public))")
            }
        } catch {
            logger.error("StoreKit error: \(error.localizedDescription, privacy: .public)")
            self.activeTier = .freeTier
        }
    }

    /// Loads Pro product metadata for the paywall. Safe to call multiple times.
    /// On sim with the `.storekit` config, returns the configured product. On device
    /// without a real product configured, returns empty array (and the paywall will
    /// show a "subscription unavailable" state).
    func loadProducts() async {
        do {
            let loaded = try await Product.products(for: [StoreKitProductID.proMonthly])
            self.products = loaded
            if loaded.isEmpty {
                logger.debug("No products returned for \(StoreKitProductID.proMonthly, privacy: .public)")
            } else {
                logger.debug("Loaded \(loaded.count) product(s)")
            }
        } catch {
            logger.error("Product load failed: \(error.localizedDescription, privacy: .public)")
            self.products = []
        }
    }

    // MARK: - Purchase / restore

    /// Buy the Pro product. Sets `isPurchasing` and `purchaseError` for UI binding.
    /// On success, the `Transaction.updates` listener flips `activeTier` to Pro.
    func purchase(_ product: Product) async {
        purchaseError = nil
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    await updateSubscriptionStatus()
                case .unverified(_, let error):
                    purchaseError = "Purchase could not be verified: \(error.localizedDescription)"
                }
            case .userCancelled:
                purchaseError = nil
            case .pending:
                purchaseError = "Purchase is pending (e.g., Ask to Buy)."
            @unknown default:
                purchaseError = "Unknown purchase result."
            }
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    /// Restore previous purchases. Required by App Review (guideline 3.1.1).
    /// Calls `AppStore.sync()` which re-delivers any unfinished transactions and
    /// updates the local status. On success, `activeTier` may flip to Pro.
    func restorePurchases() async {
        purchaseError = nil
        isRestoring = true
        defer { isRestoring = false }

        do {
            try await AppStore.sync()
            await updateSubscriptionStatus()
        } catch {
            purchaseError = "Restore failed: \(error.localizedDescription)"
        }
    }

    private func handleTransactionUpdate(_ result: VerificationResult<Transaction>) async {
        do {
            let transaction = try result.payloadValue
            await transaction.finish()
            await updateSubscriptionStatus()
        } catch {
            logger.error("Transaction verification failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Convenience

    var isPro: Bool {
        activeTier == .proTier || activeTier == .proPlusSelfHosted
    }

    /// The Pro monthly product, if loaded. Convenience for paywall UI.
    var proMonthlyProduct: Product? {
        products.first { $0.id == StoreKitProductID.proMonthly }
    }
}
