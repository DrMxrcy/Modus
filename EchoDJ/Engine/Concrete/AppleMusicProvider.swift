import Foundation

actor AppleMusicProvider: MusicProviderProtocol {
    var isAvailable: Bool { true }
    var isPlaying: Bool { false }
    var currentTrackID: String? { nil }
    var currentPlaybackProgress: Double { 0.0 }

    func loadTrack(id: String) async throws {
        // Placeholder: MusicKit integration deferred to Phase 2.
    }

    func play() async throws {
        // Placeholder.
    }

    func pause() async {
        // Placeholder.
    }

    func skipNext() async throws {
        // Placeholder.
    }
}
