import SwiftUI
import SwiftData
import MusicKit

struct SearchView: View {
    @EnvironmentObject var env: AppEnvironment
    @State private var searchText = ""
    @State private var selectedSeedTrack: CachedTrack? = nil
    @State private var surpriseMode = false
    @State private var useArcShaping = false

    // Seed library persists into SwiftData on first launch so a fresh install
    // always has visible tracks to start a station from. On a real device,
    // MusicKit catalog search supplements this library when Apple Music is
    // authorized; on simulator we fall back to the seed list because catalog
    // search returns empty results.
    @State private var mockTracks: [CachedTrack] = SearchView.seedLibrary
    @State private var catalogResults: [CachedTrack] = []
    @State private var isSearching = false

    private static let seedLibrary: [CachedTrack] = [
        CachedTrack(trackID: "1", title: "After Hours", artistName: "The Weeknd", energy: 0.75, acousticness: 0.1, valence: 0.3, bpm: 109.0),
        CachedTrack(trackID: "2", title: "Midnight City", artistName: "M83", energy: 0.9, acousticness: 0.05, valence: 0.7, bpm: 125.0),
        CachedTrack(trackID: "3", title: "Come a Little Closer", artistName: "Cage The Elephant", energy: 0.68, acousticness: 0.2, valence: 0.5, bpm: 115.0),
        CachedTrack(trackID: "4", title: "Get Lucky", artistName: "Daft Punk", energy: 0.82, acousticness: 0.15, valence: 0.78, bpm: 116.0),
        CachedTrack(trackID: "5", title: "Blinding Lights", artistName: "The Weeknd", energy: 0.85, acousticness: 0.08, valence: 0.62, bpm: 171.0),
        CachedTrack(trackID: "6", title: "Levitating", artistName: "Dua Lipa", energy: 0.83, acousticness: 0.12, valence: 0.92, bpm: 103.0),
        CachedTrack(trackID: "7", title: "Save Your Tears", artistName: "The Weeknd", energy: 0.7, acousticness: 0.1, valence: 0.55, bpm: 118.0),
        CachedTrack(trackID: "8", title: "Heat Waves", artistName: "Glass Animals", energy: 0.55, acousticness: 0.35, valence: 0.45, bpm: 81.0),
        CachedTrack(trackID: "9", title: "As It Was", artistName: "Harry Styles", energy: 0.73, acousticness: 0.2, valence: 0.66, bpm: 174.0),
        CachedTrack(trackID: "10", title: "Anti-Hero", artistName: "Taylor Swift", energy: 0.65, acousticness: 0.18, valence: 0.48, bpm: 97.0),
        CachedTrack(trackID: "11", title: "Cruel Summer", artistName: "Taylor Swift", energy: 0.78, acousticness: 0.1, valence: 0.58, bpm: 170.0),
        CachedTrack(trackID: "12", title: "Flowers", artistName: "Miley Cyrus", energy: 0.7, acousticness: 0.12, valence: 0.65, bpm: 118.0),
        CachedTrack(trackID: "13", title: "Unholy", artistName: "Sam Smith & Kim Petras", energy: 0.8, acousticness: 0.08, valence: 0.4, bpm: 131.0),
        CachedTrack(trackID: "14", title: "Calm Down", artistName: "Rema & Selena Gomez", energy: 0.72, acousticness: 0.15, valence: 0.75, bpm: 107.0),
        CachedTrack(trackID: "15", title: "Stay", artistName: "The Kid LAROI & Justin Bieber", energy: 0.78, acousticness: 0.1, valence: 0.5, bpm: 170.0),
        CachedTrack(trackID: "16", title: "As It Was", artistName: "Harry Styles", energy: 0.73, acousticness: 0.2, valence: 0.66, bpm: 174.0),
        CachedTrack(trackID: "17", title: "Watermelon Sugar", artistName: "Harry Styles", energy: 0.7, acousticness: 0.18, valence: 0.78, bpm: 95.0),
        CachedTrack(trackID: "18", title: "good 4 u", artistName: "Olivia Rodrigo", energy: 0.85, acousticness: 0.07, valence: 0.42, bpm: 166.0),
        CachedTrack(trackID: "19", title: "Drivers License", artistName: "Olivia Rodrigo", energy: 0.4, acousticness: 0.3, valence: 0.2, bpm: 144.0),
        CachedTrack(trackID: "20", title: "Peaches", artistName: "Justin Bieber", energy: 0.65, acousticness: 0.2, valence: 0.7, bpm: 90.0),
        CachedTrack(trackID: "21", title: "Montero", artistName: "Lil Nas X", energy: 0.78, acousticness: 0.1, valence: 0.55, bpm: 178.0),
        CachedTrack(trackID: "22", title: "Industry Baby", artistName: "Lil Nas X & Jack Harlow", energy: 0.85, acousticness: 0.08, valence: 0.6, bpm: 150.0),
        CachedTrack(trackID: "23", title: "Easy On Me", artistName: "Adele", energy: 0.4, acousticness: 0.55, valence: 0.25, bpm: 142.0),
        CachedTrack(trackID: "24", title: "Hello", artistName: "Adele", energy: 0.45, acousticness: 0.35, valence: 0.3, bpm: 79.0),
        CachedTrack(trackID: "25", title: "Rolling in the Deep", artistName: "Adele", energy: 0.7, acousticness: 0.15, valence: 0.4, bpm: 105.0),
        CachedTrack(trackID: "26", title: "Shape of You", artistName: "Ed Sheeran", energy: 0.75, acousticness: 0.2, valence: 0.68, bpm: 96.0),
        CachedTrack(trackID: "27", title: "Bad Habits", artistName: "Ed Sheeran", energy: 0.85, acousticness: 0.1, valence: 0.6, bpm: 126.0),
        CachedTrack(trackID: "28", title: "Perfect", artistName: "Ed Sheeran", energy: 0.4, acousticness: 0.45, valence: 0.6, bpm: 95.0),
        CachedTrack(trackID: "29", title: "Shivers", artistName: "Ed Sheeran", energy: 0.8, acousticness: 0.12, valence: 0.75, bpm: 141.0),
        CachedTrack(trackID: "30", title: "Bad Guy", artistName: "Billie Eilish", energy: 0.7, acousticness: 0.15, valence: 0.5, bpm: 135.0),
        CachedTrack(trackID: "31", title: "Happier Than Ever", artistName: "Billie Eilish", energy: 0.35, acousticness: 0.4, valence: 0.3, bpm: 100.0),
        CachedTrack(trackID: "32", title: "Therefore I Am", artistName: "Billie Eilish", energy: 0.6, acousticness: 0.2, valence: 0.55, bpm: 130.0),
        CachedTrack(trackID: "33", title: "Bury a Friend", artistName: "Billie Eilish", energy: 0.5, acousticness: 0.3, valence: 0.3, bpm: 120.0),
        CachedTrack(trackID: "34", title: "Ocean Eyes", artistName: "Billie Eilish", energy: 0.25, acousticness: 0.6, valence: 0.5, bpm: 145.0),
        CachedTrack(trackID: "35", title: "When the Party's Over", artistName: "Billie Eilish", energy: 0.3, acousticness: 0.5, valence: 0.25, bpm: 75.0),
        CachedTrack(trackID: "36", title: "Lovely", artistName: "Billie Eilish & Khalid", energy: 0.3, acousticness: 0.5, valence: 0.2, bpm: 115.0),
        CachedTrack(trackID: "37", title: "positions", artistName: "Ariana Grande", energy: 0.7, acousticness: 0.15, valence: 0.7, bpm: 144.0),
        CachedTrack(trackID: "38", title: "7 rings", artistName: "Ariana Grande", energy: 0.75, acousticness: 0.1, valence: 0.7, bpm: 140.0),
        CachedTrack(trackID: "39", title: "thank u, next", artistName: "Ariana Grande", energy: 0.65, acousticness: 0.15, valence: 0.7, bpm: 107.0),
        CachedTrack(trackID: "40", title: "no tears left to cry", artistName: "Ariana Grande", energy: 0.8, acousticness: 0.1, valence: 0.65, bpm: 122.0),
        CachedTrack(trackID: "41", title: "God is a woman", artistName: "Ariana Grande", energy: 0.65, acousticness: 0.2, valence: 0.55, bpm: 145.0),
        CachedTrack(trackID: "42", title: "Side to Side", artistName: "Ariana Grande ft. Nicki Minaj", energy: 0.85, acousticness: 0.1, valence: 0.7, bpm: 95.0),
        CachedTrack(trackID: "43", title: "Problem", artistName: "Ariana Grande ft. Iggy Azalea", energy: 0.85, acousticness: 0.1, valence: 0.75, bpm: 103.0),
        CachedTrack(trackID: "44", title: "Break Free", artistName: "Ariana Grande ft. Zedd", energy: 0.9, acousticness: 0.05, valence: 0.7, bpm: 130.0),
        CachedTrack(trackID: "45", title: "Bang Bang", artistName: "Jessie J, Ariana Grande, Nicki Minaj", energy: 0.9, acousticness: 0.05, valence: 0.7, bpm: 150.0),
        CachedTrack(trackID: "46", title: "Levitating", artistName: "Dua Lipa", energy: 0.83, acousticness: 0.12, valence: 0.92, bpm: 103.0),
        CachedTrack(trackID: "47", title: "Don't Start Now", artistName: "Dua Lipa", energy: 0.85, acousticness: 0.1, valence: 0.75, bpm: 124.0),
        CachedTrack(trackID: "48", title: "New Rules", artistName: "Dua Lipa", energy: 0.78, acousticness: 0.15, valence: 0.6, bpm: 116.0),
        CachedTrack(trackID: "49", title: "IDGAF", artistName: "Dua Lipa", energy: 0.85, acousticness: 0.08, valence: 0.55, bpm: 130.0),
        CachedTrack(trackID: "50", title: "Physical", artistName: "Dua Lipa", energy: 0.85, acousticness: 0.1, valence: 0.7, bpm: 146.0),
        CachedTrack(trackID: "51", title: "Hallucinate", artistName: "Dua Lipa", energy: 0.85, acousticness: 0.12, valence: 0.78, bpm: 122.0),
        CachedTrack(trackID: "52", title: "Break My Heart", artistName: "Dua Lipa", energy: 0.83, acousticness: 0.1, valence: 0.7, bpm: 113.0),
        CachedTrack(trackID: "53", title: "Blinding Lights", artistName: "The Weeknd", energy: 0.85, acousticness: 0.08, valence: 0.62, bpm: 171.0),
        CachedTrack(trackID: "54", title: "Starboy", artistName: "The Weeknd ft. Daft Punk", energy: 0.8, acousticness: 0.1, valence: 0.5, bpm: 186.0)
    ]

    var filteredTracks: [CachedTrack] {
        if searchText.isEmpty {
            return mockTracks
        }
        if !catalogResults.isEmpty {
            return catalogResults
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
                    if isSearching {
                        ProgressView("Searching Apple Music…")
                            .padding()
                    }
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
            .task(id: searchText) {
                await performCatalogSearch(term: searchText)
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

    private func performCatalogSearch(term: String) async {
        #if targetEnvironment(simulator)
        // MusicKit catalog search returns empty results on simulator.
        // Falling back to the local seed-library filter handled by filteredTracks.
        catalogResults = []
        return
        #else
        guard !term.isEmpty else {
            catalogResults = []
            return
        }
        guard MusicAuthorization.currentStatus == .authorized else {
            catalogResults = []
            return
        }
        isSearching = true
        defer { isSearching = false }
        do {
            try await Task.sleep(for: .milliseconds(300))
            try Task.checkCancellation()
            var request = MusicCatalogSearchRequest(term: term, types: [Song.self])
            request.limit = 25
            let response = try await request.response()
            let tracks = response.songs.compactMap { CachedTrack(from: $0) }
            // Persist new results so they remain available offline and as seeds.
            let context = ModelContext(env.modelContainer)
            for track in tracks {
                context.insert(track)
            }
            try? context.save()
            catalogResults = tracks
        } catch {
            catalogResults = []
        }
        #endif
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
