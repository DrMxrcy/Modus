import SwiftUI
import StoreKit

/// Paywall sheet for Modus Pro subscription.
/// Shared between RadioView and SettingsView.
struct PaywallSheet: View {
    @ObservedObject var subscriptionManager: SubscriptionManager
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Modus Pro")
                    .font(.title.bold())
                Spacer()
                Button("Close", action: onDismiss)
            }

            Text("Unlock DJ Arc, station memory, and unlimited exploration.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let product = subscriptionManager.proMonthlyProduct {
                VStack(alignment: .leading, spacing: 6) {
                    Text(product.displayName)
                        .font(.headline)
                    Text(product.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let subscription = product.subscription {
                        Text(subscriptionPeriodDescription(for: product, subscription: subscription))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(12)

                Button {
                    Task { await subscriptionManager.purchase(product) }
                } label: {
                    HStack {
                        if subscriptionManager.isPurchasing { ProgressView() }
                        Text(subscriptionManager.proMonthlyProduct?.subscription?.introductoryOffer != nil
                             ? "Start 7-Day Free Trial"
                             : "Subscribe")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(subscriptionManager.isPurchasing)
            } else {
                Text("Subscription unavailable. Pull to retry.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                Task { await subscriptionManager.restorePurchases() }
            } label: {
                HStack {
                    if subscriptionManager.isRestoring { ProgressView() }
                    Text("Restore Purchases")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.bordered)
            .disabled(subscriptionManager.isRestoring || subscriptionManager.isPurchasing)

            if let error = subscriptionManager.purchaseError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            // Required by App Store guideline 5.1.1: privacy policy accessible within the app.
            Link("Privacy Policy",
                 destination: URL(string: "https://modus.audio/privacy")!)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            Spacer(minLength: 0)
        }
        .padding()
    }

    private func subscriptionPeriodDescription(for product: Product, subscription: Product.SubscriptionInfo) -> String {
        let period = subscription.subscriptionPeriod
        let value = period.value
        let unit = period.unit
        let unitLabel: String
        switch unit {
        case .day: unitLabel = value == 1 ? "day" : "days"
        case .week: unitLabel = value == 1 ? "week" : "weeks"
        case .month: unitLabel = value == 1 ? "month" : "months"
        case .year: unitLabel = value == 1 ? "year" : "years"
        @unknown default: unitLabel = "period"
        }
        var lines: [String] = []
        if let introductory = subscription.introductoryOffer, introductory.paymentMode == .freeTrial {
            lines.append("Free for \(introductory.period.value) \(unitLabel == "weeks" ? "week" : (unitLabel == "days" ? "day" : unitLabel))")
        }
        lines.append("Then \(product.displayPrice) per \(value) \(unitLabel).")
        return lines.joined(separator: "\n")
    }
}