import Foundation
import SwiftData

/// Pro-tier feature: remembers the user's last N seeded stations so they can jump back.
/// Persists locally and syncs to the user's private CloudKit database via the
/// `modelContainer` configured in `AppEnvironment` with `cloudKitDatabase: .automatic`.
///
/// This is a *list* of seeds (not tracks): the actual station queue lives in
/// `StationQueueManager.queuedTrackIDs` and is rebuilt on demand.
@Model
final class RecentStation {
    @Attribute(.unique) var id: UUID
    var seedTrackID: String
    var seedTitle: String
    var seedArtist: String
    var createdAt: Date
    /// Number of tracks that were in the station at the time it was started.
    /// Used to size the "X tracks" pill in the Recent Stations UI.
    var trackCount: Int

    init(
        id: UUID = UUID(),
        seedTrackID: String,
        seedTitle: String,
        seedArtist: String,
        createdAt: Date = Date(),
        trackCount: Int = 0
    ) {
        self.id = id
        self.seedTrackID = seedTrackID
        self.seedTitle = seedTitle
        self.seedArtist = seedArtist
        self.createdAt = createdAt
        self.trackCount = trackCount
    }
}

extension RecentStation: Identifiable {}
