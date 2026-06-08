import Foundation
import SwiftData

actor TelemetryCollector {
    private let provider: any MusicProviderProtocol
    private let modelContainer: ModelContainer

    init(provider: any MusicProviderProtocol, modelContainer: ModelContainer) {
        self.provider = provider
        self.modelContainer = modelContainer
    }

    func recordSoftSkip(trackID: String) async {
        await applySkipFeedback(trackID: trackID, penaltyScore: 1)
    }

    func recordHardSkip(trackID: String) async {
        await applySkipFeedback(trackID: trackID, penaltyScore: 2)
    }

    private func applySkipFeedback(trackID: String, penaltyScore: Int) async {
        let progress = await provider.currentPlaybackProgress
        let context = ModelContext(modelContainer)

        let trackDescriptor = FetchDescriptor<CachedTrack>(
            predicate: #Predicate { $0.trackID == trackID }
        )
        let profileDescriptor = FetchDescriptor<UserTasteProfile>()

        guard let track = (try? context.fetch(trackDescriptor))?.first,
              var profile = (try? context.fetch(profileDescriptor))?.first else { return }

        VectorAffinityEngine.applyFeedback(
            profile: &profile,
            track: track,
            playbackRatio: progress
        )

        let expiration = Date().addingTimeInterval(
            penaltyScore == 1 ? 86400 : 604800 // 24h vs 7 days
        )

        let cooldown = TrackCooldown(
            trackID: trackID,
            artistName: track.artistName,
            expiration: expiration,
            penaltyScore: penaltyScore
        )

        context.insert(cooldown)
        try? context.save()
    }

    func recordFullPlay(trackID: String) async {
        let context = ModelContext(modelContainer)

        let trackDescriptor = FetchDescriptor<CachedTrack>(
            predicate: #Predicate { $0.trackID == trackID }
        )
        let profileDescriptor = FetchDescriptor<UserTasteProfile>()

        guard let track = (try? context.fetch(trackDescriptor))?.first,
              var profile = (try? context.fetch(profileDescriptor))?.first else { return }

        VectorAffinityEngine.applyFeedback(
            profile: &profile,
            track: track,
            playbackRatio: 1.0
        )

        // Cooldown write on full play: keep a light 12h "don't auto-replay" so the
        // station doesn't loop the same track within a session, but shorter than
        // a hard-skip cooldown. Without this, a long session can repeat tracks.
        let cooldown = TrackCooldown(
            trackID: trackID,
            artistName: track.artistName,
            expiration: Date().addingTimeInterval(43200), // 12h
            penaltyScore: 0
        )
        context.insert(cooldown)

        try? context.save()
    }
}
