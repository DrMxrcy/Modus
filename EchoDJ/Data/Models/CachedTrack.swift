import Foundation
import SwiftData

@Model
final class CachedTrack {
    @Attribute(.unique) var trackID: String
    var title: String
    var artistName: String
    var energy: Double
    var acousticness: Double
    var valence: Double
    var bpm: Double

    init(
        trackID: String,
        title: String,
        artistName: String,
        energy: Double,
        acousticness: Double,
        valence: Double,
        bpm: Double
    ) {
        self.trackID = trackID
        self.title = title
        self.artistName = artistName
        self.energy = energy
        self.acousticness = acousticness
        self.valence = valence
        self.bpm = bpm
    }
}

extension CachedTrack: Identifiable {
    var id: String { trackID }
}
