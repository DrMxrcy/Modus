import Foundation
import StoreKit

enum SubscriptionTier: String, Sendable {
    case freeTier
    case proTier
    case proPlusSelfHosted
}

@MainActor
final class SubscriptionManager: ObservableObject {
    @Published private(set) var activeTier: SubscriptionTier = .freeTier
    private var updatesTask: Task<Void, Error>? = nil

    init() {
        updatesTask = Task {
            for await result in Transaction.updates {
                await handleTransactionUpdate(result)
            }
        }

        Task {
            await updateSubscriptionStatus()
        }
    }

    func updateSubscriptionStatus() async {
        do {
            let statuses = try await Product.SubscriptionInfo.status(for: "premium_monthly_group")
            guard let firstStatus = statuses?.first else {
                self.activeTier = .freeTier
                return
            }

            switch firstStatus.state {
            case .subscribed, .verified:
                self.activeTier = .proTier
                print("SubscriptionManager: Active tier = Pro")
            default:
                self.activeTier = .freeTier
                print("SubscriptionManager: Active tier = Free")
            }
        } catch {
            print("SubscriptionManager: StoreKit error \(error)")
            self.activeTier = .freeTier
        }
    }

    private func handleTransactionUpdate(_ result: VerificationResult<Transaction>) async {
        do {
            let transaction = try result.payloadValue
            await transaction.finish()
            await updateSubscriptionStatus()
        } catch {
            print("SubscriptionManager: Transaction verification failed \(error)")
        }
    }

    var isPro: Bool {
        activeTier == .proTier || activeTier == .proPlusSelfHosted
    }
}
