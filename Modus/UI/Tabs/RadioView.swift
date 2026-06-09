import SwiftUI
import SwiftData
import StoreKit
import TipKit

struct RadioView: View {
    @EnvironmentObject var env: AppEnvironment
    @AppStorage("djVoiceEnabled") private var djVoiceEnabled = true
    @State private var isPlaying: Bool = false
    @State private var progress: Double = 0.0
    @State private var trackTitle: String = ""
    @State private var trackArtist: String = ""
    @State private var artworkURL: URL? = nil
    @State private var upcoming: [TrackDisplay] = []
    @State private var showPaywall: Bool = false
    @State private var showRecent: Bool = false
    @State private var showQueue: Bool = false
    @State private var lastObservedTrackID: String? = nil
    @State private var pollTask: Task<Void, Never>? = nil
    @State private var isTransitioning: Bool = false
    @State private var currentEnergy: Double = 0.5
    @State private var currentValence: Double = 0.5

    // Haptic feedback generators
    private let skipImpact = UIImpactFeedbackGenerator(style: .light)
    private let playImpact = UIImpactFeedbackGenerator(style: .medium)

    var body: some View {
        ZStack {
            // Reactive VibeVisualizer background
            VibeVisualizer(energy: currentEnergy, valence: currentValence)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer(minLength: 20)

                // Artwork or empty-state placeholder
                Group {
                    if let url = artworkURL {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(.ultraThinMaterial)
                                    .frame(width: 260, height: 260)
                                    .overlay(ProgressView())
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 260, height: 260)
                                    .clipShape(RoundedRectangle(cornerRadius: 20))
                                    .shadow(radius: 12)
                            case .failure:
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(.ultraThinMaterial)
                                    .frame(width: 260, height: 260)
                                    .overlay(
                                        Image(systemName: "music.note")
                                            .font(.system(size: 48))
                                            .foregroundStyle(.secondary)
                                    )
                            @unknown default:
                                EmptyView()
                            }
                        }
                    } else {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.ultraThinMaterial)
                            .frame(width: 260, height: 260)
                            .overlay(
                                VStack(spacing: 12) {
                                    Image(systemName: "radio")
                                        .font(.system(size: 48))
                                        .foregroundStyle(.secondary)
                                    Text("Start a station from Search")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            )
                    }
                }

                // Track info + tier badge
                VStack(spacing: 6) {
                    Text(trackTitle.isEmpty ? "Welcome to Modus" : trackTitle)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)

                    HStack(spacing: 6) {
                        Text(trackArtist.isEmpty ? "Pick a track to begin your behavioral radio" : trackArtist)
                            .font(.body)
                            .foregroundStyle(.secondary)

                        if !trackTitle.isEmpty {
                            Button {
                                if !env.subscriptionManager.isPro {
                                    showPaywall = true
                                }
                            } label: {
                                Text(env.subscriptionManager.activeTier == .freeTier ? "Free" : "Pro")
                                    .font(.caption2.bold())
                                    .foregroundStyle(env.subscriptionManager.activeTier == .freeTier ? Color.secondary : Color.green)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        env.subscriptionManager.activeTier == .freeTier
                                            ? Color.secondary.opacity(0.15)
                                            : Color.green.opacity(0.15),
                                        in: Capsule()
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint(env.subscriptionManager.isPro ? "Pro subscription active" : "Tap to see Pro subscription options")
                        }
                    }
                }

                // DJ Arc transition indicator
                if isTransitioning {
                    HStack(spacing: 6) {
                        Image(systemName: "waveform")
                            .foregroundStyle(Color.accentColor)
                        Text("DJ Arc")
                            .font(.caption.bold())
                            .foregroundStyle(Color.accentColor)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .animation(.easeInOut(duration: 0.3), value: isTransitioning)
                }

                ProgressView(value: progress, total: 1.0)
                    .tint(.accentColor)
                    .padding(.horizontal)
                    .opacity(trackTitle.isEmpty ? 0.3 : 1.0)

                // "Next Up" button (opens queue sheet)
                if !trackTitle.isEmpty && !upcoming.isEmpty {
                    Button {
                        showQueue = true
                    } label: {
                        HStack(spacing: 4) {
                            Text("Next Up")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.up")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .popoverTip(RadioQueueTip())
                }

                HCenterControlsView(
                    isPlaying: isPlaying,
                    onPlayPause: togglePlayPause,
                    onHardSkip: hardSkip,
                    onSoftSkip: softSkip
                )
                .disabled(trackTitle.isEmpty)
                .opacity(trackTitle.isEmpty ? 0.5 : 1.0)

                Spacer(minLength: 0)
            }
        }
        .onAppear {
            startProgressTimer()
        }
        .onDisappear {
            pollTask?.cancel()
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
        .sheet(isPresented: $showQueue) {
            QueueSheet(upcoming: upcoming)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    private func startProgressTimer() {
        pollTask?.cancel()
        pollTask = Task { @MainActor in
            while !Task.isCancelled {
                let provider = env.musicProvider
                let playing = await provider.isPlaying
                let prog = await provider.currentPlaybackProgress
                let title = await provider.currentTitle
                let artist = await provider.currentArtist
                let art = await provider.currentArtworkURL
                let id = await provider.currentTrackID

                isPlaying = playing
                progress = prog
                trackTitle = title
                trackArtist = artist
                artworkURL = art

                if let currentID = id, currentID != lastObservedTrackID {
                    if let previous = lastObservedTrackID, !previous.isEmpty {
                        await env.telemetryCollector.recordFullPlay(trackID: previous)
                    }
                    lastObservedTrackID = currentID
                }

                let next = await env.queueManager.upcomingTracks(limit: 5)
                upcoming = next

                // Update vibe visualizer energy/valence from current track metadata
                if let firstTrack = next.first {
                    currentEnergy = firstTrack.energy
                    currentValence = firstTrack.valence
                }

                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func togglePlayPause() {
        playImpact.impactOccurred()
        Task {
            if isPlaying {
                await env.musicProvider.pause()
            } else {
                try? await env.musicProvider.play()
            }
        }
    }

    private func hardSkip() {
        skipImpact.impactOccurred()
        Task {
            let trackID = await env.musicProvider.currentTrackID ?? "Unknown"
            await env.telemetryCollector.recordHardSkip(trackID: trackID)
            try? await env.musicProvider.skipNext()

            // Only execute DJ transition if voice is enabled
            await env.transitionManager.executeTransition(isEnabled: djVoiceEnabled)
        }
    }

    private func softSkip() {
        skipImpact.impactOccurred()
        Task {
            let trackID = await env.musicProvider.currentTrackID ?? "Unknown"
            await env.telemetryCollector.recordSoftSkip(trackID: trackID)
            try? await env.musicProvider.skipNext()

            await env.transitionManager.executeTransition(isEnabled: djVoiceEnabled)
        }
    }
}

// MARK: - Center Controls

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
                    .frame(minWidth: 44, minHeight: 44)
            }
            .contentShape(Rectangle())
            .accessibilityLabel("Hard skip — don't like this track")

            Button(action: onPlayPause) {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 64))
                    .frame(minWidth: 44, minHeight: 44)
            }
            .contentShape(Rectangle())
            .scaleEffect(isPlaying ? 1.0 : 0.95)
            .animation(.easeInOut(duration: 0.15), value: isPlaying)
            .accessibilityLabel(isPlaying ? "Pause" : "Play")

            Button(action: onSoftSkip) {
                Image(systemName: "goforward.10")
                    .font(.title)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .contentShape(Rectangle())
            .accessibilityLabel("Soft skip — next track")
        }
        .foregroundStyle(.primary)
    }
}

// MARK: - Queue Sheet

private struct QueueSheet: View {
    let upcoming: [TrackDisplay]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(upcoming.indices, id: \.self) { index in
                    let track = upcoming[index]
                    HStack {
                        Text("\(index + 1).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading) {
                            Text(track.title)
                                .font(.subheadline.bold())
                            Text(track.artistName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
            }
            .navigationTitle("Next Up")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Recent Stations Sheet

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