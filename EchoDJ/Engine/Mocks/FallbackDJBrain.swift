import Foundation

#if targetEnvironment(simulator)

actor FallbackDJBrain: DJBrainProtocol {
    var isAvailable: Bool { true }

    func generateTransition(meta: TransitionMetadata) async -> String {
        return "Echo here. Next up: \(meta.nextTrackTitle). Keep the \(meta.userMoodContext) flowing."
    }

    func generateStationArc(
        seedTitle: String,
        seedArtist: String,
        userMoodContext: String,
        queueLength: Int
    ) async -> [StationArcTarget] {
        return []
    }
}

#endif
