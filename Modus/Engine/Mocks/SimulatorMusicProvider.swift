import Foundation
import SwiftData

/// Fallback music provider that simulates playback state without requiring
/// Apple Music authorization or real catalog IDs. Available on both simulator
/// and device so the station flow and UI remain testable when MusicKit is
/// unavailable or when seed tracks have synthetic IDs.
actor SimulatorMusicProvider: MusicProviderProtocol {
    var isAvailable: Bool = true
    var isPlaying: Bool = false
    var currentTrackID: String? = nil
    var currentPlaybackProgress: Double = 0.0
    var playbackDuration: Double = 240.0
    var currentTitle: String = ""
    var currentArtist: String = ""
    var currentArtworkURL: URL? = nil

    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    func loadTrack(id: String) async throws {
        currentTrackID = id
        currentPlaybackProgress = 0.0
        
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<CachedTrack>(
            predicate: #Predicate { $0.trackID == id }
        )
        if let track = (try? context.fetch(descriptor))?.first {
            currentTitle = track.title
            currentArtist = track.artistName
            if let urlString = track.artworkURL, let url = URL(string: urlString) {
                currentArtworkURL = url
            } else {
                currentArtworkURL = nil
            }
        } else {
            currentTitle = id
            currentArtist = ""
            currentArtworkURL = nil
        }
    }

    func play() async throws {
        isPlaying = true
    }

    func pause() async {
        isPlaying = false
    }

    func skipNext() async throws {
        isPlaying = false
    }
}
