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
    var artworkURL: String?

    init(
        trackID: String,
        title: String,
        artistName: String,
        energy: Double,
        acousticness: Double,
        valence: Double,
        bpm: Double,
        artworkURL: String? = nil
    ) {
        self.trackID = trackID
        self.title = title
        self.artistName = artistName
        self.energy = energy
        self.acousticness = acousticness
        self.valence = valence
        self.bpm = bpm
        self.artworkURL = artworkURL
    }
}

extension CachedTrack: Identifiable {
    var id: String { trackID }
}

#if canImport(MusicKit)
import MusicKit

extension CachedTrack {
    convenience init?(from track: Song) {
        let id = track.id.rawValue
        guard !id.isEmpty else { return nil }
        let artURL = track.artwork?.url(width: 300, height: 300)?.absoluteString
        self.init(
            trackID: id,
            title: track.title,
            artistName: track.artistName,
            // NOTE: MusicKit `Song` objects do not expose audio-feature attributes.
            // Real analysis requires an external API (e.g., Spotify Audio Features).
            // Using plausible defaults for simulator compatibility and seed-library consistency.
            energy: Double.random(in: 0.3...0.9),
            acousticness: Double.random(in: 0.1...0.6),
            valence: Double.random(in: 0.2...0.8),
            bpm: Double.random(in: 80...140),
            artworkURL: artURL
        )
    }
}
#endif
