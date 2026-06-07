import Foundation
import SwiftData

@Model
final class UserTasteProfile {
    var id: UUID
    var lastUpdated: Date

    var energyPreference: Double
    var acousticnessPreference: Double
    var valencePreference: Double
    var targetBPM: Double
    var explorationPreference: Double // 0.0 = auto, >0 = manual override

    init(
        energy: Double = 0.5,
        acoustic: Double = 0.5,
        valence: Double = 0.5,
        bpm: Double = 110.0,
        exploration: Double = 0.0
    ) {
        self.id = UUID()
        self.lastUpdated = Date()
        self.energyPreference = energy
        self.acousticnessPreference = acoustic
        self.valencePreference = valence
        self.targetBPM = bpm
        self.explorationPreference = exploration
    }
}
