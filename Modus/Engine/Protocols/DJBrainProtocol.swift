import Foundation

struct TransitionMetadata: Sendable {
    let lastTrackTitle: String
    let lastTrackArtist: String
    let nextTrackTitle: String
    let nextTrackArtist: String
    let userMoodContext: String
    let currentBPM: Double
}

struct StationArcTarget: Sendable, Codable {
    let position: Int
    let targetEnergy: Double
    let targetValence: Double
    let targetBPM: Double
    let weight: Double
}

protocol DJBrainProtocol: Actor {
    var isAvailable: Bool { get }
    func generateTransition(meta: TransitionMetadata) async -> String
    func generateStationArc(
        seedTitle: String,
        seedArtist: String,
        userMoodContext: String,
        queueLength: Int
    ) async -> [StationArcTarget]
}
