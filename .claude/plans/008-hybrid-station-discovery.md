---
name: hybrid-station-discovery-cloud-taste
description: Design for replacing artist-only station seeding with hybrid MusicKit discovery, vector affinity ranking with exploration, on-device AI arc shaping, and future anonymized cloud taste aggregation.
metadata:
  type: project
  date: 2026-06-07
---

# Phase 8 Design: Hybrid Station Discovery & Cloud Taste Learning

## 1. Problem Statement

Today, `StationQueueManager.generateStation(seedTrackID:)` searches MusicKit for the seed track, then naively fetches more songs by that **same artist** via a text search on the artist name. This is not how real radio stations work and produces repetitive, shallow stations.

Additionally:
- The `UserTasteProfile` only learns from local skip/play history.
- There is no mechanism for "new vibe" discovery when the profile is generic.
- `OnDeviceDJBrain` is only used for spoken transitions, not for guiding the station arc.
- There is no collective learning: each user's taste vector lives in isolation.

## 2. Design Goals

1. **Rich Discovery**: Use MusicKit's native relationships (`Artist.similarArtists`, `Artist.station`, genre filters, curated playlists) to build a diverse candidate pool from a seed track.
2. **Exploration vs Exploitation**: Introduce a tunable `epsilon` parameter so the vector engine can inject "wildcards" that expand the taste profile.
3. **AI-Guided Arc**: Optionally use the on-device AI to define a time-varying target vector across the queue (e.g., "start chill, build energy").
4. **Offline Resilience**: The app must remain fully functional offline using cached local data.
5. **Future Collective Learning**: Design a privacy-preserving, opt-in cloud aggregation layer so anonymized taste vectors can improve discovery for all users without leaking personal data.

## 3. Architecture

```
Seed Track (Song)
    ↓
┌─────────────────────────────────────┐
│  Catalog Discovery Layer (async)   │  ← 3 parallel MusicKit queries
│  A. Similar Artists & Stations   │
│  B. Genre/Playlist Discovery       │
│  C. Apple Music Artist Station     │
└─────────────────────────────────────┘
    ↓
[Candidate Pool] ← deduplicated, cooldown-filtered
    ↓
[Ranking Engine]
   - VectorAffinityEngine.calculateDistance()
   - Exploration parameter ε (0.0 → 1.0)
   - Optional AI arc shaping
    ↓
[Final Queue] ← loaded into StationQueueManager
    ↓
[Telemetry] ← updates UserTasteProfile
```

## 4. Discovery Sources (replaces `searchRequest(term: artistName)`)

### 4A. Similar Artists + Their Top Tracks

Given the seed track's `Artist`, traverse `artist.similarArtists` (MusicKit property available iOS 15+). For each similar artist, fetch their `Artist.station` or top songs via catalog search.

**Pros**: Direct relationship graph, diverse but related.
**Cons**: Requires the seed track to resolve to an `Artist` object with populated relationships.

### 4B. Genre Station Filter

Use `MusicCatalogResourceRequest<Station>` filtered by the seed's `genreNames`. Apple Music exposes genre stations (`Get All Station Genres` API). Fetch the station and extract its track list.

**Pros**: Broad, mood-aligned catalog; works even for obscure seeds.
**Cons**: Station tracks are opaque; may need to map station → songs via playback or catalog lookup.

### 4C. Apple Music Artist Station (`Artist.station`)

Every `Artist` in the Apple Music catalog has a `.station` property that returns a `Station`. This is essentially Apple Music's own "Artist Radio" for that artist. We can fetch the station and sample its tracks.

**Pros**: This **is** Apple Music's DJ/radio logic for that artist. High quality, automatically updated.
**Cons**: We may not get direct track enumeration; we might need to play the station and observe upcoming items, or there may be an API to list station contents.

### 4D. Curated Playlist Search (fallback)

If the above return insufficient candidates, fall back to `MusicCatalogSearchRequest` for playlists matching the seed's primary genre + an era keyword (e.g., "Indie 2020s"). Sample tracks from the top playlist.

**Execution Strategy**: All 4 sources run in parallel `TaskGroup`. The first 3 are primary; 4D is a fallback if the pool is below a threshold (e.g., <30 candidates).

## 5. Ranking Pipeline

### 5.1. Vector Affinity Core

`VectorAffinityEngine.calculateDistance` remains unchanged. It computes weighted Euclidean distance between a `UserTasteProfile` and a `CachedTrack` over:
- `energy` (weight 1.0)
- `acousticness` (weight 1.0)
- `valence` (weight 1.2)
- `bpm` (weight 0.8, normalized by 200)

### 5.2. Exploration Parameter `epsilon`

Add a new parameter to the ranking call:

```swift
static func rankTracks(
    tracks: [CachedTrack],
    profile: UserTasteProfile,
    count: Int,
    epsilon: Double // 0.0 = pure exploitation, 1.0 = pure exploration
) -> [CachedTrack]
```

**Algorithm**:
1. Sort all candidates by vector distance ascending (closest = best match).
2. Let `explorationSlots = Int(Double(count) * epsilon)`.
3. Fill `(count - explorationSlots)` from the top of the sorted list (exploitation).
4. For the remaining `explorationSlots`, pick candidates that **maximize** vector distance (furthest from profile), but exclude tracks already in cooldown.
5. Shuffle the final queue slightly so exploration slots are distributed, not clustered at the end.

**Epsilon Decay**:
- `epsilon` starts at `0.35` for new users (generic profile, needs exploration).
- It decays by `0.02` per full station played, down to a floor of `0.05`.
- Users can manually boost epsilon via a "Surprise Me" toggle in the Vibe Tuner.

### 5.3. AI Arc Shaping (optional, gated)

Extend `DJBrainProtocol` with a new method:

```swift
func generateStationArc(
    seedTrack: CachedTrack,
    userMoodContext: String,
    queueLength: Int
) async -> [StationArcTarget]?
```

Where `StationArcTarget` is:
```swift
struct StationArcTarget {
    let position: Int // 0..<queueLength
    let targetEnergy: Double
    let targetValence: Double
    let targetBPM: Double
    let weight: Double // 0.0-1.0, how strongly to pull toward this target
}
```

**Integration**:
- If the brain is unavailable, skip arc shaping entirely.
- If available, the brain receives seed metadata + mood context and returns an array of target vectors.
- The ranking engine adjusts distance calculation per slot: instead of distance to the static `UserTasteProfile`, it computes distance to the `StationArcTarget` for that slot.
- This is a **Pro-tier feature** because it requires on-device FoundationModels, which is gated behind `OnDeviceDJBrain.isAvailable`.

**Fallback**: Without arc shaping, the queue is a static ranked list. With arc shaping, it becomes a dynamic journey.

## 6. Data Models (new / updated)

### `StationArcTarget`
New struct, `Sendable`, used only in-memory during queue generation.

### `UserTasteProfile` (update)
Add an `explorationPreference` field so the user can override the default epsilon:

```swift
var explorationPreference: Double // 0.0...1.0, default 0.0 = auto-decay
```

If `explorationPreference > 0`, use it directly instead of the auto-decay heuristic.

### `StationSession` (new @Model)
Track per-station metadata for telemetry and learning:

```swift
@Model
final class StationSession {
    var id: UUID
    var seedTrackID: String
    var startDate: Date
    var endDate: Date?
    var tracksPlayed: [String] // ordered trackIDs
    var epsilonUsed: Double
    var arcShaped: Bool
}
```

This helps us evaluate whether arc-shaped stations have better retention (fewer hard skips).

## 7. Cloud Taste Aggregation (Phase 9)

### 7.1. Privacy-First Design

- **Data leaving the device**: Only **anonymized aggregate vectors**. No track IDs, no listening history, no user identifiers.
- **Format**: Each contribution is a delta vector (what changed in the taste profile after a session) tagged with broad genre/mood buckets.
- **Storage**: CloudKit public database, write-only from the device. Reads are anonymous.
- **Opt-in**: Settings toggle "Help Improve Discovery" (default off). The app explains exactly what is shared.

### 7.2. Collective Vector Pool

In the cloud, we maintain:
- `AggregateGenreVectors`: Average taste vectors per genre bucket (e.g., "Indie", "Hip-Hop", "Electronic").
- `DriftGraph`: Weighted edges between genre buckets showing how listeners tend to drift (e.g., "Indie → Electronic" has a high weight).

### 7.3. Integration

When generating a station, if the user has opted in and network is available:
1. Fetch the aggregate vector for the seed's genre bucket.
2. Blend it with the local `UserTasteProfile` (e.g., 70% local, 30% aggregate) before ranking.
3. If the user requested a "new vibe," consult the `DriftGraph` for high-weight edges from their current dominant genre and bias candidates toward that target genre.

### 7.4. Offline Fallback

If the user is offline, opted out, or CloudKit fails, the app uses 100% local vectors. There is no degradation in core functionality.

## 8. StationQueueManager Refactor

### New Interface

```swift
actor StationQueueManager {
    func generateStation(
        seedTrackID: String,
        count: Int = 20,
        useArcShaping: Bool = false,
        surpriseMode: Bool = false
    ) async throws
}
```

### Internal Flow

```swift
private func buildStation(seedID: String, count: Int, useArc: Bool, surprise: Bool) async throws {
    let seed = try await resolveSeedTrack(seedID)
    let candidates = try await fetchDiscoveryPool(seed: seed, minimumCount: count * 3)
    let filtered = filterCooldowns(tracks: candidates)
    let profile = loadTasteProfile()
    let epsilon = surprise ? 0.5 : computeEpsilon(profile: profile)
    
    var ranked: [CachedTrack]
    if useArc, let brain = await djBrain as? OnDeviceDJBrain, await brain.isAvailable {
        let arc = await brain.generateStationArc(seedTrack: seed, userMoodContext: currentMood, queueLength: count)
        ranked = rankWithArc(tracks: filtered, profile: profile, arc: arc, epsilon: epsilon, count: count)
    } else {
        ranked = VectorAffinityEngine.rankTracks(tracks: filtered, profile: profile, count: count, epsilon: epsilon)
    }
    
    try await loadQueue(tracks: ranked)
    logStationSession(seed: seed, tracks: ranked, epsilon: epsilon, arc: useArc)
}
```

### Discovery TaskGroup

```swift
private func fetchDiscoveryPool(seed: CachedTrack, minimumCount: Int) async throws -> [CachedTrack] {
    await withTaskGroup(of: [CachedTrack].self) { group in
        group.addTask { await fetchSimilarArtistTracks(seed: seed) }
        group.addTask { await fetchGenreStationTracks(seed: seed) }
        group.addTask { await fetchArtistStationTracks(seed: seed) }
        
        var all: [CachedTrack] = []
        for await tracks in group {
            all.append(contentsOf: tracks)
        }
        
        if all.count < minimumCount {
            group.addTask { await fetchPlaylistFallbackTracks(seed: seed) }
            for await tracks in group { all.append(contentsOf: tracks) }
        }
        
        return Array(Dictionary(grouping: all, by: \.trackID).values.map { $0.first! }.values)
    }
}
```

## 9. UI / UX Impact

- **SearchView**: "Start Station" action on a track opens a small bottom sheet with toggles:
  - `[ ] Surprise Me` (boosts epsilon)
  - `[ ] DJ Arc` (Pro feature, uses AI shaping if available)
- **RadioView**: "Next Up" shows a small indicator when a track is an "exploration pick" (different from profile), teaching the user why something unexpected appeared.
- **Settings**: New "Discovery" section with:
  - `Help Improve Discovery` (opt-in toggle for cloud aggregation)
  - `Exploration Level` slider (manual override, or "Auto" for decay heuristic)

## 10. Error Handling & Offline

| Failure Mode | Behavior |
|-------------|----------|
| MusicKit not authorized | Use local `CachedTrack` pool only |
| Network unavailable | Use local `CachedTrack` pool only |
| `Artist.similarArtists` empty | Compensate with genre station + playlist fallback |
| `Artist.station` unplayable/unlistable | Skip source, log for debugging |
| AI arc shaping unavailable | Fall back to static vector ranking |
| CloudKit read fails | Use 100% local vectors |

## 11. Testing Strategy

1. **Unit**: Mock `MusicProviderProtocol` to return synthetic `Artist` objects with `similarArtists` and verify discovery pool merging/dedup.
2. **Unit**: Verify `epsilon` ranking produces exactly `Int(count * epsilon)` high-distance tracks.
3. **Integration**: Build station on simulator with `SimulatorMusicProvider`, confirm queue length and no immediate cooldown repeats.
4. **Device**: Verify `Artist.station` resolves and yields playable tracks on real Apple Music subscription.
5. **Telemetry**: Assert `StationSession` is saved with correct `epsilonUsed` and `arcShaped` flags.

## 12. Privacy & Security

- No PII in CloudKit public database.
- Aggregate vectors are k-anonymized (bucketed by genre, not user).
- Opt-in is explicit; default is local-only.
- Station sessions are private CloudKit (per-user) or local-only.

## 13. Rollout Plan

**Phase 8a: Hybrid Discovery (this spec)**
- Implement discovery sources A, B, C in `StationQueueManager`.
- Add `epsilon` to `VectorAffinityEngine`.
- Add `StationSession` model.
- Update UI with toggles.

**Phase 8b: AI Arc Shaping**
- Extend `DJBrainProtocol` with `generateStationArc`.
- Implement in `OnDeviceDJBrain`.
- Gate behind Pro tier + `isAvailable`.

**Phase 9: Cloud Taste Aggregation (future)**
- Define CloudKit public schema for aggregate vectors.
- Build drift graph computation (server-side or device-aggregated).
- Add opt-in flow and settings.
- A/B test blended vs. pure-local ranking.
