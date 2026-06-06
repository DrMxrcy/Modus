import Foundation

protocol MusicProviderProtocol: Actor {
    var isPlaying: Bool { get }
    var currentTrackID: String? { get }
    var currentPlaybackProgress: Double { get }

    func loadTrack(id: String) async throws
    func play() async throws
    func pause() async
    func skipNext() async throws
}
