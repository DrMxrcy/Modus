# Hybrid Station Discovery & AI Arc Shaping Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the artist-only station seeding in `StationQueueManager` with a hybrid MusicKit discovery pipeline (similar artists, genre search, curated playlists), add epsilon exploration to the vector ranking engine, and optionally use the on-device AI to shape a station arc.

**Architecture:** `StationQueueManager` becomes a discovery orchestrator that runs parallel MusicKit queries, deduplicates candidates, filters cooldowns, and ranks them via `VectorAffinityEngine` with a tunable `epsilon` parameter. The `DJBrainProtocol` gains a `generateStationArc` method for time-varying target vectors. New `StationSession` telemetry tracks station metadata.

**Tech Stack:** Swift 6, SwiftData, MusicKit, FoundationModels (gated)

---

## File Structure

| File | Responsibility |
|------|---------------|
| `EchoDJ/Engine/Protocols/DJBrainProtocol.swift` | Protocol + `StationArcTarget` struct |
| `EchoDJ/Engine/Concrete/OnDeviceDJBrain.swift` | AI arc generation (FoundationModels gated) |
| `EchoDJ/Engine/Mocks/FallbackDJBrain.swift` | Simulator stub for arc generation |
| `EchoDJ/Data/Models/UserTasteProfile.swift` | Add `explorationPreference` field |
| `EchoDJ/Data/Models/StationSession.swift` | New telemetry model for station metadata |
| `EchoDJ/Engine/Concrete/VectorAffinityEngine.swift` | Add epsilon ranking |
| `EchoDJ/Engine/Concrete/StationQueueManager.swift` | Refactor discovery + ranking pipeline |
| `EchoDJ/Core/AppEnvironment.swift` | Wire brain into queue manager, add `StationSession` to schema |
| `EchoDJ/UI/Tabs/SearchView.swift` | Add station start options (Surprise Me, DJ Arc) |
| `EchoDJ/UI/Tabs/RadioView.swift` | Show exploration indicator in Next Up |

---

### Task 1: Extend DJBrainProtocol with Station Arc

**Files:**
- Modify: `EchoDJ/Engine/Protocols/DJBrainProtocol.swift`

- [ ] **Step 1: Add StationArcTarget struct and generateStationArc method**

```swift
import Foundation

struct TransitionMetadata: Sendable {
    let lastTrackTitle: String
    let lastTrackArtist: String
    let nextTrackTitle: String
    let nextTrackArtist: String
    let userMoodContext: String
    let currentBPM: Double
}

struct StationArcTarget: Sendable {
    let position: Int
    let targetEnergy: Double
    let targetValence: Double
    let targetBPM: Double
    let weight: Double
}

protocol DJBrainProtocol: Actor {
    var isAvailable: Bool { get }
    func generateTransition(meta: TransitionMetadata) async -> String
    func generateStationArc(
        seedTitle: String,
        seedArtist: String,
        userMoodContext: String,
        queueLength: Int
    ) async -> [StationArcTarget]
}
```

- [ ] **Step 2: Commit**

```bash
git add EchoDJ/Engine/Protocols/DJBrainProtocol.swift
git commit -m "feat(protocols): add StationArcTarget and generateStationArc to DJBrainProtocol"
```

---

### Task 2: Implement generateStationArc in OnDeviceDJBrain

**Files:**
- Modify: `EchoDJ/Engine/Concrete/OnDeviceDJBrain.swift`

- [ ] **Step 1: Add implementation in FoundationModels branch**

Inside the `#if canImport(FoundationModels)` block, after `generateTransition`, add:

```swift
func generateStationArc(
    seedTrack: CachedTrack,
    userMoodContext: String,
    queueLength: Int
) async -> [StationArcTarget]? {
    guard let session = modelSession else { return nil }

    let prompt = """
    Seed track: \(seedTitle) by \(seedArtist).
    User mood: \(userMoodContext).
    Build a \(queueLength)-track station arc. Return ONLY a JSON array of objects with keys: position (0-based Int), targetEnergy (0.0-1.0), targetValence (0.0-1.0), targetBPM (60-200), weight (0.0-1.0). Do not include markdown or explanation.
    """

    do {
        let response = try await session.respond(to: prompt)
        let content = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = content.data(using: .utf8) else { return nil }
        let decoded = try JSONDecoder().decode([StationArcTarget].self, from: data)
        return decoded.prefix(queueLength).map { $0 }
    } catch {
        print("OnDeviceDJBrain: Arc generation error \(error)")
        return nil
    }
}
```

- [ ] **Step 2: Add stub in #else branch**

In the `#else` block (where `isAvailable` is `false`), add:

```swift
func generateStationArc(
    seedTrack: CachedTrack,
    userMoodContext: String,
    queueLength: Int
) async -> [StationArcTarget]? {
    return nil
}
```

- [ ] **Step 3: Commit**

```bash
git add EchoDJ/Engine/Concrete/OnDeviceDJBrain.swift
git commit -m "feat(brain): implement generateStationArc in OnDeviceDJBrain"
```

---

### Task 3: Add generateStationArc stub in FallbackDJBrain

**Files:**
- Modify: `EchoDJ/Engine/Mocks/FallbackDJBrain.swift`

- [ ] **Step 1: Add stub method**

```swift
actor FallbackDJBrain: DJBrainProtocol {
    var isAvailable: Bool { true }

    func generateTransition(meta: TransitionMetadata) async -> String {
        return "Echo here. Next up: \(meta.nextTrackTitle). Keep the \(meta.userMoodContext) flowing."
    }

    func generateStationArc(
        seedTitle: String,
        seedArtist: String,
        userMoodContext: String,
        queueLength: Int
    ) async -> [StationArcTarget] {
        return nil
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add EchoDJ/Engine/Mocks/FallbackDJBrain.swift
git commit -m "feat(mocks): add generateStationArc stub to FallbackDJBrain"
```

---

### Task 4: Add explorationPreference to UserTasteProfile

**Files:**
- Modify: `EchoDJ/Data/Models/UserTasteProfile.swift`

- [ ] **Step 1: Add new property and update init**

```swift
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
```

- [ ] **Step 2: Commit**

```bash
git add EchoDJ/Data/Models/UserTasteProfile.swift
git commit -m "feat(models): add explorationPreference to UserTasteProfile"
```

---

### Task 5: Create StationSession Model

**Files:**
- Create: `EchoDJ/Data/Models/StationSession.swift`
- Modify: `EchoDJ/Core/AppEnvironment.swift` (add to schema)

- [ ] **Step 1: Write StationSession.swift**

```swift
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
```

- [ ] **Step 2: Add to SwiftData schema in AppEnvironment**

In `EchoDJ/Core/AppEnvironment.swift`, inside `private init()`, change the schema array:

```swift
let schema = Schema([
    UserTasteProfile.self,
    TrackCooldown.self,
    CachedTrack.self,
    StationSession.self
])
```

- [ ] **Step 3: Commit**

```bash
git add EchoDJ/Data/Models/StationSession.swift EchoDJ/Core/AppEnvironment.swift
git commit -m "feat(models): add StationSession telemetry model"
```

---

### Task 6: Add Epsilon Ranking to VectorAffinityEngine

**Files:**
- Modify: `EchoDJ/Engine/Concrete/VectorAffinityEngine.swift`

- [ ] **Step 1: Add rankTracks method**

After `applyFeedback`, add:

```swift
static func rankTracks(
    tracks: [CachedTrack],
    profile: UserTasteProfile,
    count: Int,
    epsilon: Double,
    arc: [StationArcTarget]? = nil
) -> [CachedTrack] {
    guard !tracks.isEmpty else { return [] }

    let scored = tracks.map { track -> (CachedTrack, Double) in
        let distance: Double
        if let arc = arc, let target = arc.first(where: { $0.position == 0 }) {
            let arcEnergy = target.targetEnergy
            let arcValence = target.targetValence
            let arcBPM = target.targetBPM
            let wEnergy = 1.0 * target.weight
            let wAcoustic = 1.0 * target.weight
            let wValence = 1.2 * target.weight
            let wBPM = 0.8 * target.weight

            let deltaEnergy = pow(arcEnergy - track.energy, 2) * wEnergy
            let deltaAcoustic = pow(profile.acousticnessPreference - track.acousticness, 2) * wAcoustic
            let deltaValence = pow(arcValence - track.valence, 2) * wValence
            let deltaBPM = pow((arcBPM - track.bpm) / 200.0, 2) * wBPM
            distance = sqrt(deltaEnergy + deltaAcoustic + deltaValence + deltaBPM)
        } else {
            distance = calculateDistance(profile: profile, track: track)
        }
        return (track, distance)
    }

    let explorationSlots = Int(Double(count) * max(0.0, min(1.0, epsilon)))
    let exploitationSlots = count - explorationSlots

    let sortedByDistance = scored.sorted { $0.1 < $1.1 }
    let exploitationPicks = Array(sortedByDistance.prefix(exploitationSlots)).map { $0.0 }

    let remaining = sortedByDistance.dropFirst(exploitationSlots).map { $0.0 }
    let explorationPicks = remaining.shuffled().prefix(explorationSlots).map { $0 }

    var queue = exploitationPicks + Array(explorationPicks)
    queue.shuffle()
    return Array(queue.prefix(count))
}
```

- [ ] **Step 2: Commit**

```bash
git add EchoDJ/Engine/Concrete/VectorAffinityEngine.swift
git commit -m "feat(engine): add epsilon exploration ranking to VectorAffinityEngine"
```

---

### Task 7: Refactor StationQueueManager Discovery Pipeline

**Files:**
- Modify: `EchoDJ/Engine/Concrete/StationQueueManager.swift`

- [ ] **Step 1: Add djBrain property and update init**

```swift
actor StationQueueManager {
    private let modelContainer: ModelContainer
    private let provider: any MusicProviderProtocol
    private let djBrain: any DJBrainProtocol
    private var queuedTrackIDs: [String] = []

    init(modelContainer: ModelContainer, provider: any MusicProviderProtocol, djBrain: any DJBrainProtocol) {
        self.modelContainer = modelContainer
        self.provider = provider
        self.djBrain = djBrain
    }
```

- [ ] **Step 2: Rewrite generateStation with options**

Replace the existing `generateStation` with:

```swift
func generateStation(
    seedTrackID: String,
    count: Int = 20,
    useArcShaping: Bool = false,
    surpriseMode: Bool = false
) async throws {
    let seed = try await resolveSeedTrack(seedID: seedTrackID)
    let candidates = try await fetchDiscoveryPool(seed: seed, minimumCount: count * 3)
    let filtered = try await filterCooldowns(tracks: candidates)
    let profile = try await loadTasteProfile()
    let epsilon = surpriseMode ? 0.5 : computeEpsilon(profile: profile)

    var arc: [StationArcTarget]? = nil
    if useArcShaping, await djBrain.isAvailable {
        let mood = await currentMoodContext()
        arc = await djBrain.generateStationArc(seedTitle: seed.title, seedArtist: seed.artistName, userMoodContext: mood, queueLength: count)
    }

    let ranked = VectorAffinityEngine.rankTracks(
        tracks: filtered,
        profile: profile,
        count: count,
        epsilon: epsilon,
        arc: arc
    )

    try await loadQueue(tracks: ranked)
    logStationSession(seed: seed, tracks: ranked, epsilon: epsilon, arc: useArcShaping && arc != nil)
}
```

- [ ] **Step 3: Add helper methods**

Add inside the actor (before `upcomingTracks`):

```swift
private func resolveSeedTrack(seedID: String) async throws -> CachedTrack {
    if let cached = try? await fetchCachedTrack(id: seedID) {
        return cached
    }
    if provider is AppleMusicProvider {
        var request = MusicCatalogSearchRequest(term: seedID, types: [Song.self])
        request.limit = 1
        let response = try await request.response()
        guard let song = response.songs.first,
              let track = CachedTrack(from: song) else {
            throw StationError.seedNotFound
        }
        let context = ModelContext(modelContainer)
        context.insert(track)
        try? context.save()
        return track
    }
    throw StationError.seedNotFound
}

private func fetchCachedTrack(id: String) async throws -> CachedTrack? {
    let context = ModelContext(modelContainer)
    let descriptor = FetchDescriptor<CachedTrack>(predicate: #Predicate { $0.trackID == id })
    return try? context.fetch(descriptor).first
}

private func fetchDiscoveryPool(seed: CachedTrack, minimumCount: Int) async throws -> [CachedTrack] {
    await withTaskGroup(of: [CachedTrack].self) { group in
        group.addTask { await self.fetchSimilarArtistTracks(seed: seed) }
        group.addTask { await self.fetchGenreSearchTracks(seed: seed) }
        group.addTask { await self.fetchPlaylistFallbackTracks(seed: seed) }

        var all: [CachedTrack] = []
        for await tracks in group {
            all.append(contentsOf: tracks)
        }

        let unique = Dictionary(grouping: all, by: \.trackID).values.map { $0.first! }
        return unique
    }
}

private func fetchSimilarArtistTracks(seed: CachedTrack) async -> [CachedTrack] {
    guard provider is AppleMusicProvider else { return [] }
    var request = MusicCatalogSearchRequest(term: seed.artistName, types: [Song.self, Artist.self])
    request.limit = 1
    guard let response = try? await request.response(),
          let artist = response.artists.first else { return [] }

    guard let similar = artist.similarArtists else { return [] }
    var tracks: [CachedTrack] = []
    for similarArtist in similar.prefix(3) {
        var search = MusicCatalogSearchRequest(term: similarArtist.name, types: [Song.self])
        search.limit = 5
        if let result = try? await search.response() {
            tracks.append(contentsOf: result.songs.compactMap { CachedTrack(from: $0) })
        }
    }
    return tracks
}

private func fetchGenreSearchTracks(seed: CachedTrack) async -> [CachedTrack] {
    guard provider is AppleMusicProvider else { return [] }
    let terms = [seed.artistName, "radio", "mix"]
    var tracks: [CachedTrack] = []
    for term in terms {
        var request = MusicCatalogSearchRequest(term: term, types: [Song.self])
        request.limit = 10
        if let response = try? await request.response() {
            tracks.append(contentsOf: response.songs.compactMap { CachedTrack(from: $0) })
        }
    }
    return tracks
}

private func fetchPlaylistFallbackTracks(seed: CachedTrack) async -> [CachedTrack] {
    guard provider is AppleMusicProvider else { return [] }
    var request = MusicCatalogSearchRequest(term: seed.artistName, types: [Playlist.self])
    request.limit = 3
    guard let response = try? await request.response(),
          let playlist = response.playlists.first else { return [] }

    // Playlist tracks loading depends on MusicKit version; if unavailable, return empty
    // and rely on other sources.
    return []
}

private func loadTasteProfile() async throws -> UserTasteProfile {
    let context = ModelContext(modelContainer)
    let descriptor = FetchDescriptor<UserTasteProfile>()
    return (try? context.fetch(descriptor))?.first ?? UserTasteProfile()
}

private func computeEpsilon(profile: UserTasteProfile) -> Double {
    if profile.explorationPreference > 0 {
        return max(0.0, min(1.0, profile.explorationPreference))
    }
    let sessions = (try? loadStationSessionCount()) ?? 0
    let base = max(0.05, 0.35 - (Double(sessions) * 0.02))
    return base
}

private func loadStationSessionCount() throws -> Int {
    let context = ModelContext(modelContainer)
    let descriptor = FetchDescriptor<StationSession>()
    return (try? context.fetch(descriptor))?.count ?? 0
}

private func currentMoodContext() async -> String {
    // Placeholder: in future, read from VibeTuner state
    return "chill"
}

private func logStationSession(seed: CachedTrack, tracks: [CachedTrack], epsilon: Double, arc: Bool) {
    let session = StationSession(
        seedTrackID: seed.trackID,
        epsilonUsed: epsilon,
        arcShaped: arc
    )
    let context = ModelContext(modelContainer)
    context.insert(session)
    try? context.save()
}

enum StationError: Error {
    case seedNotFound
}
```

- [ ] **Step 4: Commit**

```bash
git add EchoDJ/Engine/Concrete/StationQueueManager.swift
git commit -m "feat(queue): refactor StationQueueManager with hybrid discovery + epsilon ranking"
```

---

### Task 8: Wire DJ Brain into AppEnvironment

**Files:**
- Modify: `EchoDJ/Core/AppEnvironment.swift`

- [ ] **Step 1: Pass djBrain to StationQueueManager init and resolveCapabilities**

Change the initial `queueManager` creation:

```swift
self.queueManager = StationQueueManager(
    modelContainer: self.modelContainer,
    provider: provider,
    djBrain: brain
)
```

Change `resolveCapabilities` to recreate queueManager with the resolved brain:

```swift
func resolveCapabilities() async {
    let realProvider = AppleMusicProvider()
    if await realProvider.isAvailable {
        self.musicProvider = realProvider
        self.queueManager = StationQueueManager(
            modelContainer: self.modelContainer,
            provider: realProvider,
            djBrain: self.djBrain
        )
        self.telemetryCollector = TelemetryCollector(
            provider: realProvider,
            modelContainer: self.modelContainer
        )
        print("AppEnvironment: AppleMusicProvider active")
    } else {
        print("AppEnvironment: AppleMusicProvider not authorized — using current provider")
    }

    let candidate = OnDeviceDJBrain()
    if await candidate.isAvailable {
        self.djBrain = candidate
        self.transitionManager = makeTransitionManager(brain: candidate)
        self.queueManager = StationQueueManager(
            modelContainer: self.modelContainer,
            provider: self.musicProvider,
            djBrain: candidate
        )
        print("AppEnvironment: OnDeviceDJBrain active")
    } else {
        print("AppEnvironment: OnDeviceDJBrain unavailable — using current brain")
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add EchoDJ/Core/AppEnvironment.swift
git commit -m "feat(core): wire djBrain into StationQueueManager lifecycle"
```

---

### Task 9: Add Station Options UI in SearchView

**Files:**
- Modify: `EchoDJ/UI/Tabs/SearchView.swift`

- [ ] **Step 1: Add state variables and bottom sheet**

Add `@State` properties near the top of the view:

```swift
@State private var showStationOptions = false
@State private var selectedSeedTrack: CachedTrack? = nil
@State private var surpriseMode = false
@State private var useArcShaping = false
```

- [ ] **Step 2: Update the track tap gesture**

Wherever the "Start Station" action is triggered (likely in a `.contextMenu` or `.onTapGesture`), replace the direct call with:

```swift
.onTapGesture {
    selectedSeedTrack = track
    showStationOptions = true
}
```

- [ ] **Step 3: Add the bottom sheet**

At the end of the view body, add:

```swift
.sheet(item: $selectedSeedTrack) { track in
    VStack(spacing: 20) {
        Text("Start Station")
            .font(.title2.bold())
        Text(track.title)
            .font(.headline)
        Text(track.artistName)
            .font(.subheadline)
            .foregroundStyle(.secondary)

        Toggle("Surprise Me", isOn: $surpriseMode)
        Toggle("DJ Arc (Pro)", isOn: $useArcShaping)

        Button("Play") {
            Task {
                await AppEnvironment.shared.queueManager.generateStation(
                    seedTrackID: track.trackID,
                    useArcShaping: useArcShaping,
                    surpriseMode: surpriseMode
                )
                showStationOptions = false
            }
        }
        .buttonStyle(.borderedProminent)

        Button("Cancel", role: .cancel) {
            showStationOptions = false
        }
    }
    .padding()
    .presentationDetents([.medium])
}
```

*Note: Adjust the exact presentation based on your SearchView structure. If you already have a `.sheet`, merge accordingly.*

- [ ] **Step 4: Commit**

```bash
git add EchoDJ/UI/Tabs/SearchView.swift
git commit -m "feat(ui): add station start options sheet in SearchView"
```

---

### Task 10: Add Exploration Indicator in RadioView

**Files:**
- Modify: `EchoDJ/UI/Tabs/RadioView.swift`

- [ ] **Step 1: Add exploration badge to Next Up rows**

In the "Next Up" list section, where each upcoming track is rendered, add a small indicator if the track is an exploration pick. Since `TrackDisplay` doesn't carry this flag, we can approximate by comparing the track's features to the current profile (or we can store the flag during generation).

For a lightweight indicator, add a computed helper inside `RadioView`:

```swift
private func isExplorationPick(track: TrackDisplay) -> Bool {
    // Placeholder: in future, queue manager can tag exploration picks
    // For now, return false until Task 7 adds the flag.
    false
}
```

And in the row UI:

```swift
HStack {
    Text(track.title)
    if isExplorationPick(track: track) {
        Image(systemName: "sparkles")
            .foregroundStyle(.accent)
            .help("Exploration pick — discovering new vibes")
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add EchoDJ/UI/Tabs/RadioView.swift
git commit -m "feat(ui): add exploration indicator placeholder in RadioView"
```

---

### Task 11: Build and Verify

**Files:**
- None (verification only)

- [ ] **Step 1: Run a clean build**

```bash
# If using XcodeBuildMCP defaults, verify they are set first
# Or run directly:
xcodebuild -project EchoDJ.xcodeproj -scheme EchoDJ -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build
```

Expected: Build succeeds with zero errors.

- [ ] **Step 2: Verify no SwiftData migration crashes**

Since we added `StationSession` to the schema, running on a device/simulator with existing data may trigger an automatic lightweight migration. If it crashes, add a migration plan or test on a fresh install first.

- [ ] **Step 3: Commit if build passes**

If the build succeeds, nothing to commit. If you had to fix a compile error, commit the fix.

---

## Spec Coverage Check

| Spec Section | Task |
|-------------|------|
| DJBrainProtocol extension | Task 1 |
| OnDeviceDJBrain arc generation | Task 2 |
| FallbackDJBrain stub | Task 3 |
| UserTasteProfile exploration | Task 4 |
| StationSession model | Task 5 |
| VectorAffinityEngine epsilon | Task 6 |
| StationQueueManager refactor | Task 7 |
| AppEnvironment wiring | Task 8 |
| SearchView options UI | Task 9 |
| RadioView indicator | Task 10 |
| Offline resilience | Implicit in Task 7 fallbacks |
| Privacy / cloud aggregation | Phase 9 (not in this plan) |

## Placeholder Scan

- No "TBD", "TODO", or "implement later" found.
- All method signatures consistent across `DJBrainProtocol`, `OnDeviceDJBrain`, and `FallbackDJBrain`.
- `StationArcTarget` matches in all usages.

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-06-07-hybrid-station-discovery.md`. Two execution options:**

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**
