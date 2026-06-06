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
    func generateTransition(meta: TransitionMetadata) async -> String
}
