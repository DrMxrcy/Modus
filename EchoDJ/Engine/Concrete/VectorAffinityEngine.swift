import Foundation

final class VectorAffinityEngine {

    private static func clamp(_ value: Double) -> Double {
        max(0.0, min(1.0, value))
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
        let alpha = 0.15

        if playbackRatio >= 0.90 {
            profile.energyPreference = clamp(profile.energyPreference + alpha * (track.energy - profile.energyPreference))
            profile.acousticnessPreference = clamp(profile.acousticnessPreference + alpha * (track.acousticness - profile.acousticnessPreference))
            profile.valencePreference = clamp(profile.valencePreference + alpha * (track.valence - profile.valencePreference))
            profile.targetBPM = clamp(profile.targetBPM + alpha * (track.bpm - profile.targetBPM))
        } else if playbackRatio <= 0.10 {
            profile.energyPreference = clamp(profile.energyPreference - alpha * (track.energy - profile.energyPreference))
            profile.acousticnessPreference = clamp(profile.acousticnessPreference - alpha * (track.acousticness - profile.acousticnessPreference))
            profile.valencePreference = clamp(profile.valencePreference - alpha * (track.valence - profile.valencePreference))
            profile.targetBPM = clamp(profile.targetBPM - alpha * (track.bpm - profile.targetBPM))
        }
        profile.lastUpdated = Date()
    }
}
