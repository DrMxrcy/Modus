import SwiftUI
import SwiftData

struct SearchView: View {
    @EnvironmentObject var env: AppEnvironment
    @State private var searchText = ""

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
            $0.title.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(0..<filteredTracks.count) { index in
                    let track = filteredTracks[index]
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
                            .foregroundStyle(.accent)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        Task {
                            try? await env.musicProvider.loadTrack(id: track.trackID)
                            try? await env.musicProvider.play()
                            print("Station generated using seed track vector coordinates: [\(track.energy), \(track.valence)]")
                        }
                    }
                }
            }
            .navigationTitle("Search & Seed")
            .searchable(text: $searchText, prompt: "Search songs, albums, or vibes")
        }
    }
}
