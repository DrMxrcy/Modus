import Foundation
import SwiftData
import MusicKit
import OSLog

private let logger = Logger(subsystem: "app.modus", category: "StationQueueManager")

struct TrackDisplay: Sendable {
    let trackID: String
    let title: String
    let artistName: String
}

enum StationError: Error {
    case seedNotFound
}

struct SeedInfo: Sendable {
    let trackID: String
    let title: String
    let artistName: String
}

struct TrackSnapshot: Sendable {
    let trackID: String
    let title: String
    let artistName: String
    let energy: Double
    let acousticness: Double
    let valence: Double
    let bpm: Double

    init?(
        trackID: String,
        title: String,
        artistName: String,
        energy: Double,
        acousticness: Double,
        valence: Double,
        bpm: Double
    ) {
        guard !trackID.isEmpty else { return nil }
        self.trackID = trackID
        self.title = title
        self.artistName = artistName
        self.energy = energy
        self.acousticness = acousticness
        self.valence = valence
        self.bpm = bpm
    }
}

#if canImport(MusicKit)
extension TrackSnapshot {
    init?(from song: Song) {
        let id = song.id.rawValue
        guard !id.isEmpty else { return nil }
        self.init(
            trackID: id,
            title: song.title,
            artistName: song.artistName,
            energy: Double.random(in: 0.3...0.9),
            acousticness: Double.random(in: 0.1...0.6),
            valence: Double.random(in: 0.2...0.8),
            bpm: Double.random(in: 80...140)
        )
    }

    func toCachedTrack() -> CachedTrack {
        CachedTrack(
            trackID: trackID,
            title: title,
            artistName: artistName,
            energy: energy,
            acousticness: acousticness,
            valence: valence,
            bpm: bpm
        )
    }
}
#endif

actor StationQueueManager {
    private let modelContainer: ModelContainer
    private let provider: any MusicProviderProtocol
    private let djBrain: any DJBrainProtocol
    private var queuedTrackIDs: [String] = []

    init(
        modelContainer: ModelContainer,
        provider: any MusicProviderProtocol,
        djBrain: any DJBrainProtocol
    ) {
        self.modelContainer = modelContainer
        self.provider = provider
        self.djBrain = djBrain
    }

    func generateStation(
        seedTrackID: String,
        count: Int = 20,
        useArcShaping: Bool = false,
        surpriseMode: Bool = false
    ) async throws {
        let seed = try await resolveSeedTrack(seedID: seedTrackID)
        let candidates = try await fetchDiscoveryPool(seed: seed, minimumCount: count * 3)
        var filtered = try await filterCooldowns(tracks: candidates)

        let context = ModelContext(modelContainer)

        if filtered.isEmpty {
            let fallbackDescriptor = FetchDescriptor<CachedTrack>()
            let all = (try? context.fetch(fallbackDescriptor)) ?? []
            filtered = all.filter { $0.trackID != seed.trackID }
            guard !filtered.isEmpty else {
                logger.error("Station generation failed: no tracks available after fallback (seed=\(seed.trackID, privacy: .public))")
                throw StationError.seedNotFound
            }
        }

        let descriptor = FetchDescriptor<UserTasteProfile>()
        let profile = (try? context.fetch(descriptor))?.first ?? UserTasteProfile()

        let epsilon: Double
        if surpriseMode {
            epsilon = 0.5
        } else {
            epsilon = VectorAffinityEngine.computeEpsilon(profile: profile)
        }

        let ranked = VectorAffinityEngine.rankTracks(
            tracks: filtered,
            profile: profile,
            count: count,
            epsilon: epsilon
        )

        if useArcShaping, await djBrain.isAvailable {
            _ = await djBrain.generateStationArc(
                seedTitle: seed.title,
                seedArtist: seed.artistName,
                userMoodContext: "",
                queueLength: count
            )
        }

        persistTracks(ranked)
        try await logStationSession(seed: seed, tracks: ranked, epsilon: epsilon, arc: useArcShaping)
        await recordRecentStation(seed: seed, trackCount: ranked.count)
        try await loadQueue(tracks: ranked)
    }

    private func resolveSeedTrack(seedID: String) async throws -> CachedTrack {
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<CachedTrack>(
            predicate: #Predicate { $0.trackID == seedID }
        )
        if let local = try? context.fetch(descriptor).first {
            return local
        }

        if provider is AppleMusicProvider {
            var searchRequest = MusicCatalogSearchRequest(term: seedID, types: [Song.self])
            searchRequest.limit = 10
            let searchResponse: MusicCatalogSearchResponse
            do {
                searchResponse = try await searchRequest.response()
            } catch {
                logger.error("resolveSeedTrack search failed: \(error.localizedDescription, privacy: .public)")
                throw StationError.seedNotFound
            }
            guard let song = searchResponse.songs.first(where: { $0.id.rawValue == seedID })
                    ?? searchResponse.songs.first else {
                throw StationError.seedNotFound
            }
            guard let cached = CachedTrack(from: song) else {
                throw StationError.seedNotFound
            }
            context.insert(cached)
            try? context.save()
            return cached
        }

        throw StationError.seedNotFound
    }

    private func fetchDiscoveryPool(
        seed: CachedTrack,
        minimumCount: Int
    ) async throws -> [CachedTrack] {
        let seedInfo = SeedInfo(
            trackID: seed.trackID,
            title: seed.title,
            artistName: seed.artistName
        )

        var snapshots: [TrackSnapshot] = []

        await withTaskGroup(of: [TrackSnapshot].self) { group in
            group.addTask {
                await self.fetchSimilarArtistTracks(seed: seedInfo)
            }
            group.addTask {
                await self.fetchGenreSearchTracks(seed: seedInfo)
            }
            group.addTask {
                await self.fetchPlaylistFallbackTracks(seed: seedInfo)
            }

            for await tracks in group {
                snapshots.append(contentsOf: tracks)
            }
        }

        var seen = Set<String>()
        var deduplicated: [TrackSnapshot] = []
        for snapshot in snapshots {
            if !seen.contains(snapshot.trackID) {
                seen.insert(snapshot.trackID)
                deduplicated.append(snapshot)
            }
        }

        if deduplicated.count < minimumCount {
            let broader = await fetchBroaderSearchTracks(seed: seedInfo)
            for snapshot in broader {
                if !seen.contains(snapshot.trackID) {
                    seen.insert(snapshot.trackID)
                    deduplicated.append(snapshot)
                }
            }
        }

        return snapshotsToCachedTracks(deduplicated)
    }

    private func fetchSimilarArtistTracks(seed: SeedInfo) async -> [TrackSnapshot] {
        var snapshots: [TrackSnapshot] = []

        var artistSearch = MusicCatalogSearchRequest(term: seed.artistName, types: [Song.self])
        artistSearch.limit = 25
        do {
            let response = try await artistSearch.response()
            snapshots.append(contentsOf: response.songs.compactMap { TrackSnapshot(from: $0) })
        } catch {
            logger.error("similar-artist search failed: \(error.localizedDescription, privacy: .public)")
        }

        let relatedTerms = [
            seed.artistName + " similar",
            seed.artistName + " related"
        ]

        for term in relatedTerms {
            var request = MusicCatalogSearchRequest(term: term, types: [Song.self])
            request.limit = 15
            do {
                let response = try await request.response()
                snapshots.append(contentsOf: response.songs.compactMap { TrackSnapshot(from: $0) })
            } catch {
                logger.error("related-terms search failed for \(term, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }

        return snapshots
    }

    private func fetchGenreSearchTracks(seed: SeedInfo) async -> [TrackSnapshot] {
        let terms = [
            seed.artistName,
            seed.artistName + " radio",
            seed.title,
            seed.title + " mix"
        ]

        var snapshots: [TrackSnapshot] = []
        for term in terms {
            var request = MusicCatalogSearchRequest(term: term, types: [Song.self])
            request.limit = 15
            do {
                let response = try await request.response()
                snapshots.append(contentsOf: response.songs.compactMap { TrackSnapshot(from: $0) })
            } catch {
                logger.error("genre search failed for \(term, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }

        return snapshots
    }

    private func fetchPlaylistFallbackTracks(seed: SeedInfo) async -> [TrackSnapshot] {
        return []
    }

    private func fetchBroaderSearchTracks(seed: SeedInfo) async -> [TrackSnapshot] {
        let terms = [
            seed.artistName + " playlist",
            seed.artistName + " essentials",
            seed.artistName + " hits"
        ]

        var snapshots: [TrackSnapshot] = []
        for term in terms {
            var request = MusicCatalogSearchRequest(term: term, types: [Song.self])
            request.limit = 20
            do {
                let response = try await request.response()
                snapshots.append(contentsOf: response.songs.compactMap { TrackSnapshot(from: $0) })
            } catch {
                logger.error("broader search failed for \(term, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }

        return snapshots
    }

    private func snapshotsToCachedTracks(_ snapshots: [TrackSnapshot]) -> [CachedTrack] {
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<CachedTrack>()
        let allExisting = (try? context.fetch(descriptor)) ?? []
        let existingByID = Dictionary(uniqueKeysWithValues: allExisting.map { ($0.trackID, $0) })

        return snapshots.map { snapshot in
            existingByID[snapshot.trackID] ?? snapshot.toCachedTrack()
        }
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

    private func persistTracks(_ tracks: [CachedTrack]) {
        let context = ModelContext(modelContainer)
        let trackIDs = tracks.map { $0.trackID }
        let descriptor = FetchDescriptor<CachedTrack>(
            predicate: #Predicate { trackIDs.contains($0.trackID) }
        )
        let existing = (try? context.fetch(descriptor)) ?? []
        let existingIDs = Set(existing.map { $0.trackID })

        for track in tracks {
            if !existingIDs.contains(track.trackID) {
                context.insert(track)
            }
        }
        try? context.save()
    }

    private func logStationSession(
        seed: CachedTrack,
        tracks: [CachedTrack],
        epsilon: Double,
        arc: Bool
    ) async throws {
        let context = ModelContext(modelContainer)
        let session = StationSession(
            seedTrackID: seed.trackID,
            epsilonUsed: epsilon,
            arcShaped: arc
        )
        session.tracksPlayed = tracks.map { $0.trackID }
        context.insert(session)
        try context.save()
    }

    /// Insert a RecentStation entry for the seed. Called after the station is built
    /// so only successful station starts are recorded. The CloudKit-backed SwiftData
    /// container (configured in `AppEnvironment`) syncs this to the user's private DB.
    ///
    /// Pro-tier: the UI only surfaces these when `subscriptionManager.isPro` is true;
    /// persistence happens unconditionally so upgrading mid-session unlocks history
    /// the user already created (no surprise data loss on upgrade).
    private func recordRecentStation(seed: CachedTrack, trackCount: Int) async {
        let context = ModelContext(modelContainer)
        let entry = RecentStation(
            seedTrackID: seed.trackID,
            seedTitle: seed.title,
            seedArtist: seed.artistName,
            trackCount: trackCount
        )
        context.insert(entry)
        try? context.save()
    }

    private func loadQueue(tracks: [CachedTrack]) async throws {
        queuedTrackIDs = tracks.map { $0.trackID }

        for track in tracks {
            do {
                try await provider.loadTrack(id: track.trackID)
            } catch {
                logger.error("loadTrack failed for \(track.trackID, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func upcomingTracks(limit: Int = 3) async -> [TrackDisplay] {
        let context = ModelContext(modelContainer)
        let ids = queuedTrackIDs
        guard !ids.isEmpty else {
            let descriptor = FetchDescriptor<CachedTrack>()
            let all = (try? context.fetch(descriptor)) ?? []
            return Array(all.prefix(limit)).map {
                TrackDisplay(trackID: $0.trackID, title: $0.title, artistName: $0.artistName)
            }
        }

        let descriptor = FetchDescriptor<CachedTrack>(
            predicate: #Predicate { ids.contains($0.trackID) }
        )
        let matches = (try? context.fetch(descriptor)) ?? []
        let ordered = ids.compactMap { id in matches.first(where: { $0.trackID == id }) }
        return Array(ordered.prefix(limit)).map {
            TrackDisplay(trackID: $0.trackID, title: $0.title, artistName: $0.artistName)
        }
    }
}
