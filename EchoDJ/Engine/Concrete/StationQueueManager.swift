import Foundation
import SwiftData
import MusicKit

struct TrackDisplay: Sendable {
    let trackID: String
    let title: String
    let artistName: String
}

actor StationQueueManager {
    private let modelContainer: ModelContainer
    private let provider: any MusicProviderProtocol
    private var queuedTrackIDs: [String] = []

    init(modelContainer: ModelContainer, provider: any MusicProviderProtocol) {
        self.modelContainer = modelContainer
        self.provider = provider
    }

    func generateStation(seedTrackID: String, count: Int = 20) async throws {
        let candidates = try await fetchCandidates(seedID: seedTrackID, count: count * 3)
        let filtered = try await filterCooldowns(tracks: candidates)
        let ranked = rankTracks(tracks: filtered, count: count)

        try await loadQueue(tracks: ranked)
    }

    private func fetchCandidates(seedID: String, count: Int) async throws -> [CachedTrack] {
        if provider is AppleMusicProvider {
            return try await fetchMusicKitCandidates(seedID: seedID, count: count)
        } else {
            return fetchLocalCandidates(count: count)
        }
    }

    private func fetchMusicKitCandidates(seedID: String, count: Int) async throws -> [CachedTrack] {
        var searchRequest = MusicCatalogSearchRequest(term: seedID, types: [Song.self])
        searchRequest.limit = 10
        let searchResponse = try await searchRequest.response()
        guard let seedTrack = searchResponse.songs.first(where: { $0.id.rawValue == seedID }) ?? searchResponse.songs.first else {
            return []
        }

        var artistSearch = MusicCatalogSearchRequest(term: seedTrack.artistName, types: [Song.self])
        artistSearch.limit = count
        let artistResponse = try await artistSearch.response()

        return artistResponse.songs.compactMap { CachedTrack(from: $0) }
    }

    private func fetchLocalCandidates(count: Int) -> [CachedTrack] {
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<CachedTrack>()
        guard let all = try? context.fetch(descriptor) else { return [] }
        return Array(all.shuffled().prefix(count))
    }

    private func filterCooldowns(tracks: [CachedTrack]) async throws -> [CachedTrack] {
        let context = ModelContext(modelContainer)
        let now = Date()
        let descriptor = FetchDescriptor<TrackCooldown>(
            predicate: #Predicate { $0.cooldownExpiration > now }
        )
        let activeCooldowns = (try? context.fetch(descriptor)) ?? []
        let blockedIDs = Set(activeCooldowns.map { $0.trackID })
        return tracks.filter { !blockedIDs.contains($0.trackID) }
    }

    private func rankTracks(tracks: [CachedTrack], count: Int) -> [CachedTrack] {
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<UserTasteProfile>()
        let profile = (try? context.fetch(descriptor))?.first ?? UserTasteProfile()

        let scored = tracks.map { track in
            (track, VectorAffinityEngine.calculateDistance(profile: profile, track: track))
        }

        return scored
            .sorted { $0.1 < $1.1 }
            .prefix(count)
            .map { $0.0 }
    }

    private func loadQueue(tracks: [CachedTrack]) async throws {
        queuedTrackIDs = tracks.map { $0.trackID }

        guard let firstID = queuedTrackIDs.first else { return }

        if provider is AppleMusicProvider {
            try await provider.loadTrack(id: firstID)
        } else {
            for track in tracks {
                try? await provider.loadTrack(id: track.trackID)
            }
        }
    }

    func upcomingTracks(limit: Int = 3) async -> [TrackDisplay] {
        let context = ModelContext(modelContainer)
        let ids = queuedTrackIDs
        guard !ids.isEmpty else {
            let descriptor = FetchDescriptor<CachedTrack>()
            let all = (try? context.fetch(descriptor)) ?? []
            return Array(all.prefix(limit)).map { TrackDisplay(trackID: $0.trackID, title: $0.title, artistName: $0.artistName) }
        }

        let descriptor = FetchDescriptor<CachedTrack>(
            predicate: #Predicate { ids.contains($0.trackID) }
        )
        let matches = (try? context.fetch(descriptor)) ?? []
        let ordered = ids.compactMap { id in matches.first(where: { $0.trackID == id }) }
        return Array(ordered.prefix(limit)).map { TrackDisplay(trackID: $0.trackID, title: $0.title, artistName: $0.artistName) }
    }
}
