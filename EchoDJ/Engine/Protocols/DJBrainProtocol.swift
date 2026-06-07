import Foundation

struct TransitionMetadata: Sendable {
    let lastTrackTitle: String
    let lastTrackArtist: String
    let nextTrackTitle: String
    let nextTrackArtist: String
    let userMoodContext: String
    let currentBPM: Double
}

protocol DJBrainProtocol: Actor {
    var isAvailable: Bool { get }
    func generateTransition(meta: TransitionMetadata) async -> String
}
