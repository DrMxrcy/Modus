import Foundation

#if targetEnvironment(simulator)

actor SimulatorMusicProvider: MusicProviderProtocol {
    var isAvailable: Bool = true
    var isPlaying: Bool = false
    var currentTrackID: String? = nil
    var currentPlaybackProgress: Double = 0.0
    var playbackDuration: Double = 240.0

    func loadTrack(id: String) async throws {
        currentTrackID = id
        currentPlaybackProgress = 0.0
        print("SimulatorMusicProvider: Loaded track \(id)")
    }

    func play() async throws {
        isPlaying = true
        print("SimulatorMusicProvider: Playback initiated")
    }

    func pause() async {
        isPlaying = false
        print("SimulatorMusicProvider: Playback paused")
    }

    func skipNext() async throws {
        print("SimulatorMusicProvider: Skipping track at progress \(currentPlaybackProgress)")
        isPlaying = false
    }
}

#endif
