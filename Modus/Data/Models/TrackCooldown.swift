import Foundation
import SwiftData

@Model
final class TrackCooldown {
    @Attribute(.unique) var trackID: String
    var artistName: String
    var cooldownExpiration: Date
    var penaltyScore: Int

    init(
        trackID: String,
        artistName: String,
        expiration: Date,
        penaltyScore: Int
    ) {
        self.trackID = trackID
        self.artistName = artistName
        self.cooldownExpiration = expiration
        self.penaltyScore = penaltyScore
    }
}

extension TrackCooldown: Identifiable {
    var id: String { trackID }
}
