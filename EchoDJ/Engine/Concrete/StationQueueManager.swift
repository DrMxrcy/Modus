import Foundation
import SwiftData
import MusicKit

actor StationQueueManager {
    private let modelContainer: ModelContainer
    private let provider: any MusicProviderProtocol

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
        if await provider is AppleMusicProvider {
            return try await fetchMusicKitCandidates(seedID: seedID, count: count)
        } else {
            return fetchLocalCandidates(count: count)
        }
    }

    private func fetchMusicKitCandidates(seedID: String, count: Int) async throws -> [CachedTrack] {
        let searchRequest = MusicCatalogSearchRequest(term: seedID, types: [Song.self])
        searchRequest.limit = 10
        let searchResponse = try await searchRequest.response()
        guard let seedTrack = searchResponse.songs.first(where: { $0.id.rawValue == seedID }) ?? searchResponse.songs.first else {
            return []
        }

        let artistSearch = MusicCatalogSearchRequest(term: seedTrack.artistName, types: [Song.self])
        artistSearch.limit = count
        let artistResponse = try await artistSearch.response()

        return artistResponse.songs.compactMap { CachedTrack(from: $0) }
    }

    private func fetchLocalCandidates(count: Int) -> [CachedTrack] {
        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<CachedTrack>()
        guard let all = try? context.fetch(descriptor) else { return [] }
        return Array(all.shuffled().prefix(count))
    }

    private func filterCooldowns(tracks: [CachedTrack]) async throws -> [CachedTrack] {
        let context = modelContainer.mainContext
        let now = Date()
        let descriptor = FetchDescriptor<TrackCooldown>(
            predicate: #Predicate { $0.cooldownExpiration > now }
        )
        let activeCooldowns = (try? context.fetch(descriptor)) ?? []
        let blockedIDs = Set(activeCooldowns.map { $0.trackID })
        return tracks.filter { !blockedIDs.contains($0.trackID) }
    }

    private func rankTracks(tracks: [CachedTrack], count: Int) -> [CachedTrack] {
        let context = modelContainer.mainContext
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
        guard await provider is AppleMusicProvider else {
            for track in tracks {
                try? await provider.loadTrack(id: track.trackID)
            }
            return
        }

        var musicTracks: [Song] = []
        for cached in tracks {
            let request = MusicCatalogSearchRequest(term: cached.trackID, types: [Song.self])
            request.limit = 10
            if let song = try? await request.response().songs.first(where: { $0.id.rawValue == cached.trackID }) ?? request.response().songs.first {
                musicTracks.append(song)
            }
        }

        ApplicationMusicPlayer.shared.queue = musicTracks
    }

    func upcomingTracks(limit: Int = 3) async -> [CachedTrack] {
        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<CachedTrack>()
        let all = (try? context.fetch(descriptor)) ?? []
        return Array(all.prefix(limit))
    }
}
