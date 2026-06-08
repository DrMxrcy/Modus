import SwiftUI
import SwiftData

struct SearchView: View {
    @EnvironmentObject var env: AppEnvironment
    @State private var searchText = ""
    @State private var selectedSeedTrack: CachedTrack? = nil
    @State private var surpriseMode = false
    @State private var useArcShaping = false

    // TODO: Replace with real data source
    @State private var mockTracks = [
        CachedTrack(
            trackID: "1",
            title: "After Hours",
            artistName: "The Weeknd",
            energy: 0.75,
            acousticness: 0.1,
            valence: 0.3,
            bpm: 109.0
        ),
        CachedTrack(
            trackID: "2",
            title: "Midnight City",
            artistName: "M83",
            energy: 0.9,
            acousticness: 0.05,
            valence: 0.7,
            bpm: 125.0
        ),
        CachedTrack(
            trackID: "3",
            title: "Come a Little Closer",
            artistName: "Cage The Elephant",
            energy: 0.68,
            acousticness: 0.2,
            valence: 0.5,
            bpm: 115.0
        )
    ]

    var filteredTracks: [CachedTrack] {
        if searchText.isEmpty {
            return mockTracks
        }
        return mockTracks.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) || $0.artistName.localizedCaseInsensitiveContains(searchText)
        }
    }

    @State private var showError: Bool = false
    @State private var errorMessage: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(filteredTracks) { track in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(track.title)
                                    .font(.headline)
                                Text(track.artistName)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "play.radiowaves.left.and.right")
                                .foregroundStyle(.tint)
                        }
                        .padding()
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedSeedTrack = track
                        }
                        if track != filteredTracks.last {
                            Divider()
                        }
                    }
                }
            }
            .navigationTitle("Search & Seed")
            .searchable(text: $searchText, prompt: "Search songs, albums, or vibes")
            .sheet(item: $selectedSeedTrack) { track in
                StationOptionsSheet(
                    track: track,
                    surpriseMode: $surpriseMode,
                    useArcShaping: $useArcShaping,
                    activeTier: env.subscriptionManager.activeTier,
                    onStart: {
                        Task { @MainActor in
                            do {
                                try await env.queueManager.generateStation(
                                    seedTrackID: track.trackID,
                                    useArcShaping: useArcShaping,
                                    surpriseMode: surpriseMode
                                )
                                try await env.musicProvider.play()
                                env.selectedTab = 0
                                selectedSeedTrack = nil
                                surpriseMode = false
                                useArcShaping = false
                            } catch {
                                errorMessage = error.localizedDescription
                                showError = true
                            }
                        }
                    },
                    onCancel: {
                        Task { @MainActor in
                            selectedSeedTrack = nil
                            surpriseMode = false
                            useArcShaping = false
                        }
                    }
                )
            }
            .alert("Station Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                Task {
                    let context = ModelContext(env.modelContainer)
                    let existing = (try? context.fetch(FetchDescriptor<CachedTrack>())) ?? []
                    let existingIDs = Set(existing.map { $0.trackID })
                    for track in mockTracks {
                        if !existingIDs.contains(track.trackID) {
                            context.insert(track)
                        }
                    }
                    try? context.save()
                }
            }
        }
    }
}

private struct StationOptionsSheet: View {
    let track: CachedTrack
    @Binding var surpriseMode: Bool
    @Binding var useArcShaping: Bool
    let activeTier: SubscriptionTier
    let onStart: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text(track.title)
                .font(.headline)
            Text(track.artistName)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Toggle("Surprise Me", isOn: $surpriseMode)
            if activeTier != .freeTier {
                Toggle("DJ Arc (Pro)", isOn: $useArcShaping)
            }

            Button(action: onStart) {
                Text("Start Station")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button("Cancel", role: .cancel, action: onCancel)
                .frame(maxWidth: .infinity)
        }
        .padding()
        .presentationDetents([.medium])
    }
}
