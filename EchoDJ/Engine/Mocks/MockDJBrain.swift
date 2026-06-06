import Foundation

actor MockDJBrain: DJBrainProtocol {
    func generateTransition(meta: TransitionMetadata) async -> String {
        return "Hey it's Echo. Up next we have \(meta.nextTrackTitle) matching your current \(meta.userMoodContext) vibe. Let's step into it."
    }
}
