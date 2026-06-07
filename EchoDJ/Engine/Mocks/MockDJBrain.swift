import Foundation

actor MockDJBrain: DJBrainProtocol {
    var isAvailable: Bool { true }

    func generateTransition(meta: TransitionMetadata) async -> String {
        return "Hey it's Echo. Up next we have \(meta.nextTrackTitle) matching your current \(meta.userMoodContext) vibe. Let's step into it."
    }
}
