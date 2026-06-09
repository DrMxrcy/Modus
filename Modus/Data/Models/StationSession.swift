import Foundation
import SwiftData

@Model
final class StationSession {
    var id: UUID
    var seedTrackID: String
    var startDate: Date
    var endDate: Date?
    var tracksPlayed: [String]
    var epsilonUsed: Double
    var arcShaped: Bool

    init(
        seedTrackID: String,
        epsilonUsed: Double,
        arcShaped: Bool
    ) {
        self.id = UUID()
        self.seedTrackID = seedTrackID
        self.startDate = Date()
        self.endDate = nil
        self.tracksPlayed = []
        self.epsilonUsed = epsilonUsed
        self.arcShaped = arcShaped
    }
}
