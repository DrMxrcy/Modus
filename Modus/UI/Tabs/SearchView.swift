import SwiftUI
import SwiftData
import MusicKit
import OSLog
import TipKit

private let searchLogger = Logger(subsystem: "app.modus", category: "SearchView")

struct SearchView: View {
    @EnvironmentObject var env: AppEnvironment
    @AppStorage("defaultSurpriseMode") private var defaultSurpriseMode = false
    @AppStorage("defaultArcShaping") private var defaultArcShaping = false
    @AppStorage("djVoiceEnabled") private var djVoiceEnabled = true
    @State private var searchText = ""
    @State private var selectedSeedTrack: CachedTrack? = nil
    @State private var surpriseMode = false
    @State private var useArcShaping = false

    @State private var mockTracks: [CachedTrack] = SearchView.seedLibrary
    @State private var catalogResults: [CachedTrack] = []
    @State private var isSearching = false

    @State private var showError: Bool = false
    @State private var errorMessage: String = ""

    // TipKit tip for search onboarding
    @State private var searchStartTip = SearchStartTip()

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

    var body: some View {
        NavigationStack {
            List {
                if isSearching {
                    Section {
                        ProgressView("Searching Apple Music…")
                    }
                }

                if !searchText.isEmpty && !isSearching && filteredTracks.isEmpty && catalogResults.isEmpty {
                    // No-results state
                    ContentUnavailableView {
                        Label("No Results", systemImage: "magnifyingglass")
                    } description: {
                        Text("No results for \"\(searchText)\". Try a different song or artist.")
                    }
                } else {
                    // Popular Picks section
                    Section(searchText.isEmpty ? "Popular Picks" : "Library") {
                        ForEach(filteredTracks) { track in
                            Button {
                                selectedSeedTrack = track
                                surpriseMode = defaultSurpriseMode
                                useArcShaping = djVoiceEnabled && defaultArcShaping
                            } label: {
                                trackRow(track)
                            }
                        }
                    }
                }

                // Apple Music section (shown when catalog results exist)
                if !catalogResults.isEmpty {
                    Section("Apple Music") {
                        ForEach(catalogResults) { track in
                            Button {
                                selectedSeedTrack = track
                                surpriseMode = defaultSurpriseMode
                                useArcShaping = djVoiceEnabled && defaultArcShaping
                            } label: {
                                trackRow(track)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Search & Seed")
            .searchable(text: $searchText, prompt: "Search songs, albums, or vibes")
            .sheet(item: $selectedSeedTrack) { track in
                StationOptionsSheet(
                    track: track,
                    surpriseMode: $surpriseMode,
                    useArcShaping: $useArcShaping,
                    activeTier: env.subscriptionManager.activeTier,
                    djVoiceEnabled: djVoiceEnabled,
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
                    do {
                        try context.save()
                    } catch {
                        searchLogger.error("Seed persist failed: \(error.localizedDescription, privacy: .public)")
                    }
                }
            }
            .popoverTip(searchStartTip)
        }
    }

    // MARK: - Track Row

    @ViewBuilder
    private func trackRow(_ track: CachedTrack) -> some View {
        HStack(spacing: 12) {
            // Colored artwork placeholder circle (deterministic from track title)
            Circle()
                .fill(colorForTitle(track.title))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "music.note")
                        .font(.caption)
                        .foregroundStyle(.white)
                )

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
    }

    /// Generate a deterministic accent color from the track title hash.
    private func colorForTitle(_ title: String) -> Color {
        let hash = abs(title.hashValue)
        let hues: [Color] = [.purple, .blue, .teal, .indigo, .pink, .orange, .mint, .cyan]
        return hues[hash % hues.count].opacity(0.7)
    }

    // MARK: - Catalog Search

    private func performCatalogSearch(term: String) async {
        #if targetEnvironment(simulator)
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
            let context = ModelContext(env.modelContainer)
            for track in tracks {
                context.insert(track)
            }
            do { try context.save() } catch {
                searchLogger.error("Catalog persist failed: \(error.localizedDescription, privacy: .public)")
            }
            catalogResults = tracks
        } catch {
            catalogResults = []
        }
        #endif
    }

    // MARK: - Seed Library

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
        CachedTrack(trackID: "23", title: "Easy On Me", artistName: "Adele", energy: 0.4, acousticness: 0.55, valence: 0.25, bpm: 142.0),
        CachedTrack(trackID: "24", title: "Hello", artistName: "Adele", energy: 0.45, acousticness: 0.35, valence: 0.3, bpm: 79.0),
        CachedTrack(trackID: "25", title: "Rolling in the Deep", artistName: "Adele", energy: 0.7, acousticness: 0.15, valence: 0.4, bpm: 105.0),
        CachedTrack(trackID: "26", title: "Shape of You", artistName: "Ed Sheeran", energy: 0.75, acousticness: 0.2, valence: 0.68, bpm: 96.0),
        CachedTrack(trackID: "27", title: "Bad Habits", artistName: "Ed Sheeran", energy: 0.85, acousticness: 0.1, valence: 0.6, bpm: 126.0),
        CachedTrack(trackID: "30", title: "Bad Guy", artistName: "Billie Eilish", energy: 0.7, acousticness: 0.15, valence: 0.5, bpm: 135.0),
        CachedTrack(trackID: "34", title: "Ocean Eyes", artistName: "Billie Eilish", energy: 0.25, acousticness: 0.6, valence: 0.5, bpm: 145.0),
        CachedTrack(trackID: "37", title: "positions", artistName: "Ariana Grande", energy: 0.7, acousticness: 0.15, valence: 0.7, bpm: 144.0),
        CachedTrack(trackID: "40", title: "no tears left to cry", artistName: "Ariana Grande", energy: 0.8, acousticness: 0.1, valence: 0.65, bpm: 122.0),
        CachedTrack(trackID: "47", title: "Don't Start Now", artistName: "Dua Lipa", energy: 0.85, acousticness: 0.1, valence: 0.75, bpm: 124.0),
        CachedTrack(trackID: "48", title: "New Rules", artistName: "Dua Lipa", energy: 0.78, acousticness: 0.15, valence: 0.6, bpm: 116.0),
        CachedTrack(trackID: "50", title: "Physical", artistName: "Dua Lipa", energy: 0.85, acousticness: 0.1, valence: 0.7, bpm: 146.0),
        CachedTrack(trackID: "54", title: "Starboy", artistName: "The Weeknd ft. Daft Punk", energy: 0.8, acousticness: 0.1, valence: 0.5, bpm: 186.0),
    ]
}

// MARK: - Station Options Sheet

private struct StationOptionsSheet: View {
    let track: CachedTrack
    @Binding var surpriseMode: Bool
    @Binding var useArcShaping: Bool
    let activeTier: SubscriptionTier
    let djVoiceEnabled: Bool
    let onStart: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Track artwork + metadata header
                HStack(spacing: 16) {
                    Circle()
                        .fill(colorForTitle(track.title))
                        .frame(width: 56, height: 56)
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.title3)
                                .foregroundStyle(.white)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(track.title)
                            .font(.headline)
                        Text(track.artistName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal)

                Divider()

                // Options
                VStack(spacing: 16) {
                    Toggle(isOn: $surpriseMode) {
                        Label("Surprise Me", systemImage: "shuffle")
                    }
                    Text("Mix in tracks outside your usual taste")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if activeTier != .freeTier {
                        Toggle(isOn: $useArcShaping) {
                            Label("DJ Arc", systemImage: "sparkles")
                        }
                        Text("AI commentary between tracks")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        HStack {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("DJ Arc")
                                    Text("Pro feature — AI-powered station shaping")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: "sparkles")
                            }
                            Spacer()
                            Text("Pro")
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.accentColor, in: Capsule())
                        }
                    }
                }
                .padding(.horizontal)

                // Explanation
                Text("Modus builds a station from this track's energy, mood, and rhythm profile.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                // Start button
                Button(action: onStart) {
                    Text("Start Station")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Spacer(minLength: 0)
            }
            .padding(.vertical)
            .navigationTitle("Station Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .popoverTip(SurpriseModeTip())
    }

    private func colorForTitle(_ title: String) -> Color {
        let hash = abs(title.hashValue)
        let hues: [Color] = [.purple, .blue, .teal, .indigo, .pink, .orange, .mint, .cyan]
        return hues[hash % hues.count].opacity(0.7)
    }
}