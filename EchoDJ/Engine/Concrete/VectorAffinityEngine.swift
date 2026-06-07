import Foundation

enum VectorAffinityEngine: Sendable {

    private static func clamp(_ value: Double) -> Double {
        max(0.0, min(1.0, value))
    }

    private static func clampBPM(_ value: Double) -> Double {
        max(60.0, min(200.0, value))
    }

    static func calculateDistance(profile: UserTasteProfile, track: CachedTrack) -> Double {
        let wEnergy = 1.0
        let wAcoustic = 1.0
        let wValence = 1.2
        let wBPM = 0.8

        let deltaEnergy = pow(profile.energyPreference - track.energy, 2) * wEnergy
        let deltaAcoustic = pow(profile.acousticnessPreference - track.acousticness, 2) * wAcoustic
        let deltaValence = pow(profile.valencePreference - track.valence, 2) * wValence

        let deltaBPM = pow((profile.targetBPM - track.bpm) / 200.0, 2) * wBPM

        return sqrt(deltaEnergy + deltaAcoustic + deltaValence + deltaBPM)
    }

    static func applyFeedback(profile: inout UserTasteProfile, track: CachedTrack, playbackRatio: Double) {
        guard (0...1).contains(playbackRatio) else { return }
        let alpha = 0.15

        if playbackRatio >= 0.90 {
            profile.energyPreference = clamp(profile.energyPreference + alpha * (track.energy - profile.energyPreference))
            profile.acousticnessPreference = clamp(profile.acousticnessPreference + alpha * (track.acousticness - profile.acousticnessPreference))
            profile.valencePreference = clamp(profile.valencePreference + alpha * (track.valence - profile.valencePreference))
            profile.targetBPM = clampBPM(profile.targetBPM + alpha * (track.bpm - profile.targetBPM))
        } else if playbackRatio <= 0.10 {
            profile.energyPreference = clamp(profile.energyPreference - alpha * (track.energy - profile.energyPreference))
            profile.acousticnessPreference = clamp(profile.acousticnessPreference - alpha * (track.acousticness - profile.acousticnessPreference))
            profile.valencePreference = clamp(profile.valencePreference - alpha * (track.valence - profile.valencePreference))
            profile.targetBPM = clampBPM(profile.targetBPM - alpha * (track.bpm - profile.targetBPM))
        }
        profile.lastUpdated = Date()
    }

    static func rankTracks(
        tracks: [CachedTrack],
        profile: UserTasteProfile,
        count: Int,
        epsilon: Double,
        excludedTrackIDs: [String] = []
    ) -> [CachedTrack] {
        guard !tracks.isEmpty, count > 0 else { return [] }

        let scored = tracks.map { (track: $0, score: calculateDistance(profile: profile, track: $0)) }
        let sorted = scored.sorted { $0.score < $1.score }.map(\.track)

        let clampedEpsilon = clamp(epsilon)
        guard clampedEpsilon.isFinite else { return Array(tracks.prefix(count)) }
        let explorationSlots = min(count, Int(Double(count) * clampedEpsilon))
        let exploitationCount = max(0, count - explorationSlots)

        let exploitationTracks = Array(sorted.prefix(exploitationCount))
        var excludedSet = Set(excludedTrackIDs)
        excludedSet.formUnion(exploitationTracks.map(\.trackID))

        var explorationTracks: [CachedTrack] = []
        for track in sorted.reversed() {
            if explorationTracks.count >= explorationSlots { break }
            if !excludedSet.contains(track.trackID) {
                explorationTracks.append(track)
                excludedSet.insert(track.trackID)
            }
        }

        var result = exploitationTracks
        for track in explorationTracks {
            let insertIndex = Int.random(in: 0...result.count)
            result.insert(track, at: insertIndex)
        }

        return Array(result.prefix(count))
    }

    static func computeEpsilon(profile: UserTasteProfile) -> Double {
        if profile.explorationPreference > 0 {
            return min(1.0, profile.explorationPreference)
        }

        let daysSinceUpdate = Date().timeIntervalSince(profile.lastUpdated) / 86400.0
        var epsilon = 0.35

        if daysSinceUpdate > 30 {
            epsilon -= 0.06
        } else if daysSinceUpdate > 14 {
            epsilon -= 0.04
        } else if daysSinceUpdate > 7 {
            epsilon -= 0.02
        }

        return max(0.05, epsilon)
    }
}
