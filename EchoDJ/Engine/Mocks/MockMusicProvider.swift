import Foundation

actor MockMusicProvider: MusicProviderProtocol {
    var isPlaying: Bool = false
    var currentTrackID: String? = nil
    var currentPlaybackProgress: Double = 0.0

    func loadTrack(id: String) async throws {
        currentTrackID = id
        currentPlaybackProgress = 0.0
        print("Mock: Loaded track \(id)")
    }

    func play() async throws {
        isPlaying = true
        print("Mock: Playback initiated")
    }

    func pause() async {
        isPlaying = false
        print("Mock: Playback paused")
    }

    func skipNext() async throws {
        print("Mock: Skipping track. Reporting telemetry completion: \(currentPlaybackProgress)")
        isPlaying = false
    }
}
