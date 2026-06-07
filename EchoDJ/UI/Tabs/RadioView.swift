import SwiftUI
import SwiftData
import Combine

struct RadioView: View {
    @EnvironmentObject var env: AppEnvironment
    @State private var valenceLevel: Double = 0.5
    @State private var energyLevel: Double = 0.5
    @State private var isPlaying: Bool = false
    @State private var progress: Double = 0.0
    @State private var trackTitle: String = "Station Seed Title"
    @State private var trackArtist: String = "Echo DJ Station Active"
    @State private var upcoming: [TrackDisplay] = []
    @State private var timerCancellable: AnyCancellable? = nil

    var body: some View {
        ZStack {
            VibeVisualizer(energy: energyLevel, valence: valenceLevel)

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
                                Spacer()
                            }
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    .padding(.horizontal)
                }

                VStack(alignment: .leading) {
                    Text("VIBE TUNER: \(Int(valenceLevel * 100))%")
                        .font(.caption.bold())
                    Slider(value: $valenceLevel, in: 0...1) { _ in
                        Task {
                            let context = env.modelContainer.mainContext
                            let descriptor = FetchDescriptor<UserTasteProfile>()
                            if let profile = (try? context.fetch(descriptor))?.first {
                                profile.valencePreference = valenceLevel
                                try? context.save()
                                print("Vibe Tuner updated valence to \(valenceLevel)")
                            }
                        }
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(16)
                .padding(.horizontal)

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
                        trackTitle = title
                        trackArtist = "Now Playing"
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
            let trackID = await env.musicProvider.currentTrackID ?? "Unknown"
            await env.telemetryCollector.recordHardSkip(trackID: trackID)
            try? await env.musicProvider.skipNext()
            try? await env.transitionManager.executeTransition()
            print("Hard Skip Triggered for \(trackID)")
        }
    }

    private func softSkip() {
        Task {
            let trackID = await env.musicProvider.currentTrackID ?? "Unknown"
            await env.telemetryCollector.recordSoftSkip(trackID: trackID)
            try? await env.musicProvider.skipNext()
            try? await env.transitionManager.executeTransition()
            print("Soft Skip Triggered for \(trackID)")
        }
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
