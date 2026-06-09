import SwiftUI
import SwiftData
import Combine
import StoreKit

struct RadioView: View {
    @EnvironmentObject var env: AppEnvironment
    @State private var isPlaying: Bool = false
    @State private var progress: Double = 0.0
    @State private var trackTitle: String = "Station Seed Title"
    @State private var trackArtist: String = "Echo DJ Station Active"
    @State private var upcoming: [TrackDisplay] = []
    @State private var timerCancellable: AnyCancellable? = nil
    @State private var showPaywall: Bool = false
    @State private var showRecent: Bool = false
    @State private var lastObservedTrackID: String? = nil

    var body: some View {
        ZStack {
            // Subtle gradient background
            LinearGradient(
                colors: [Color.purple.opacity(0.15), Color.black, Color.indigo.opacity(0.15)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 30) {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 300, height: 300)
                    .overlay(Text("Album Artwork Proxy"))

                VStack(spacing: 8) {
                    Text(trackTitle)
                        .font(.title2.bold())
                    Text(trackArtist)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button {
                        if !env.subscriptionManager.isPro {
                            showPaywall = true
                        }
                    } label: {
                        Text(env.subscriptionManager.activeTier == .freeTier ? "Free" : "Pro")
                            .font(.caption.bold())
                            .foregroundStyle(env.subscriptionManager.activeTier == .freeTier ? Color.secondary : Color.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(env.subscriptionManager.activeTier == .freeTier ? Color.secondary.opacity(0.2) : Color.green.opacity(0.2))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(env.subscriptionManager.isPro ? "Pro subscription active" : "Tap to see Pro subscription options")

                    Button {
                        if env.subscriptionManager.isPro {
                            showRecent = true
                        } else {
                            showPaywall = true
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: env.subscriptionManager.isPro ? "clock.arrow.circlepath" : "lock.fill")
                                .font(.caption2)
                            Text("Recent")
                                .font(.caption.bold())
                        }
                        .foregroundStyle(env.subscriptionManager.isPro ? Color.accentColor : Color.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(env.subscriptionManager.isPro ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.15))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(env.subscriptionManager.isPro ? "View recently played stations" : "Pro feature — tap to upgrade")
                }

                ProgressView(value: progress, total: 1.0)
                    .padding(.horizontal)

                if !upcoming.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Next Up")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        ForEach(upcoming.indices, id: \.self) { index in
                            let track = upcoming[index]
                            HStack {
                                Text("\(index + 1).")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                VStack(alignment: .leading) {
                                    Text(track.title)
                                        .font(.caption.bold())
                                    Text(track.artistName)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                if isExplorationPick(track: track) {
                                    Image(systemName: "sparkles")
                                        .foregroundStyle(Color.accentColor)
                                        .accessibilityLabel("Exploration pick")
                                        .help("Exploration pick — discovering new vibes")
                                }
                                Spacer()
                            }
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    .padding(.horizontal)
                }

                HCenterControlsView(
                    isPlaying: isPlaying,
                    onPlayPause: togglePlayPause,
                    onHardSkip: hardSkip,
                    onSoftSkip: softSkip
                )
            }
        }
        .onAppear {
            startProgressTimer()
        }
        .onDisappear {
            timerCancellable?.cancel()
        }
        .sheet(isPresented: $showPaywall) {
            PaywallSheet(
                subscriptionManager: env.subscriptionManager,
                onDismiss: { showPaywall = false }
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showRecent) {
            RecentStationsSheet(modelContainer: env.modelContainer)
                .presentationDetents([.medium, .large])
        }
    }

    private func startProgressTimer() {
        timerCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                Task { @MainActor in
                    let provider = env.musicProvider
                    let playing = await provider.isPlaying
                    let prog = await provider.currentPlaybackProgress
                    let title = await provider.currentTrackID ?? "Station Seed Title"

                    isPlaying = playing
                    progress = prog
                    if title != trackTitle && title != "Station Seed Title" {
                        // Detect a track transition: the previous track completed
                        // (auto-advance) or was skipped. Record a "full play" for the
                        // previous ID so the cooldown table prevents immediate replay.
                        if let previous = lastObservedTrackID, !previous.isEmpty, previous != "Station Seed Title" {
                            await env.telemetryCollector.recordFullPlay(trackID: previous)
                        }
                        trackTitle = title
                        trackArtist = "Now Playing"
                        lastObservedTrackID = title
                    }

                    let next = await env.queueManager.upcomingTracks(limit: 3)
                    upcoming = next
                }
            }
    }

    private func togglePlayPause() {
        Task {
            if isPlaying {
                await env.musicProvider.pause()
            } else {
                try? await env.musicProvider.play()
            }
        }
    }

    private func hardSkip() {
        Task {
            let isPro = env.subscriptionManager.isPro
            let trackID = await env.musicProvider.currentTrackID ?? "Unknown"
            await env.telemetryCollector.recordHardSkip(trackID: trackID)
            try? await env.musicProvider.skipNext()
            await env.transitionManager.executeTransition(isEnabled: isPro)
        }
    }

    private func softSkip() {
        Task {
            let isPro = env.subscriptionManager.isPro
            let trackID = await env.musicProvider.currentTrackID ?? "Unknown"
            await env.telemetryCollector.recordSoftSkip(trackID: trackID)
            try? await env.musicProvider.skipNext()
            await env.transitionManager.executeTransition(isEnabled: isPro)
        }
    }

    private func isExplorationPick(track: TrackDisplay) -> Bool {
        // Exploration picks are disabled for v1. Re-enable when StationQueueManager
        // can tag tracks that fall outside the user’s taste-profile bounds.
        false
    }
}

struct HCenterControlsView: View {
    let isPlaying: Bool
    let onPlayPause: () -> Void
    let onHardSkip: () -> Void
    let onSoftSkip: () -> Void

    var body: some View {
        HStack(spacing: 50) {
            Button(action: onHardSkip) {
                Image(systemName: "hand.thumbsdown.fill")
                    .font(.title)
            }
            Button(action: onPlayPause) {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 64))
            }
            Button(action: onSoftSkip) {
                Image(systemName: "goforward.10")
                    .font(.title)
            }
        }
        .foregroundStyle(.primary)
    }
}

private struct PaywallSheet: View {
    @ObservedObject var subscriptionManager: SubscriptionManager
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("EchoDJ Pro")
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

            // Required by App Store guideline 5.1.1: privacy policy must be
            // accessible within the app, not just on the App Store listing.
            Link("Privacy Policy",
                 destination: URL(string: "https://echodj.app/privacy")!)
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

private struct RecentStationsSheet: View {
    let modelContainer: ModelContainer
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \RecentStation.createdAt, order: .reverse) private var recent: [RecentStation]

    var body: some View {
        NavigationStack {
            Group {
                if recent.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("No recent stations yet")
                            .font(.headline)
                        Text("Start a station from the Search tab to see it here.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(recent.prefix(20)) { entry in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(entry.seedTitle)
                                        .font(.headline)
                                    Text(entry.seedArtist)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Text("\(entry.trackCount) tracks • \(entry.createdAt.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Recent Stations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
