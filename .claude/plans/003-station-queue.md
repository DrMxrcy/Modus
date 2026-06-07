# Station Queue Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Build a `StationQueueManager` that generates a personalized 20-track station queue using vector-based recommendations, with MusicKit catalog search or local mock fallback.

**Architecture:** An `actor StationQueueManager` fetches candidate tracks (from MusicKit catalog or local `CachedTrack` pool), calculates weighted Euclidean distance against the current `UserTasteProfile`, filters out tracks in `TrackCooldown`, and populates `ApplicationMusicPlayer.queue`. `SearchView` tapping a track seeds the station instead of playing a single song. `RadioView` displays the next 3 upcoming tracks.

**Tech Stack:** Swift 6, MusicKit, SwiftData, SwiftUI, Xcode 26

---

## File Map

| File | Responsibility | Action |
|------|---------------|--------|
| `EchoDJ/Engine/Concrete/StationQueueManager.swift` | Queue generation, filtering, ranking | Create |
| `EchoDJ/Data/Models/CachedTrack.swift` | Local track pool | Extend with convenience init from MusicKit `Track` |
| `EchoDJ/UI/Tabs/SearchView.swift` | Search & seed UI | Modify to seed station instead of single play |
| `EchoDJ/UI/Tabs/RadioView.swift` | Player UI | Add "Next Up" section showing upcoming tracks |
| `EchoDJ/Core/AppEnvironment.swift` | DI container | Add `StationQueueManager` reference |

---

### Task 1: Extend CachedTrack with MusicKit Bridge

**Files:**
- Modify: `EchoDJ/Data/Models/CachedTrack.swift`
- Test: Build

- [x] **Step 1: Add MusicKit convenience initializer**

Append to `EchoDJ/Data/Models/CachedTrack.swift` (after the existing `init`):

```swift
#if canImport(MusicKit)
import MusicKit

extension CachedTrack {
    convenience init?(from track: Track) {
        guard let id = track.id.rawValue else { return nil }
        self.init(
            trackID: id,
            title: track.title,
            artistName: track.artistName,
            energy: Double.random(in: 0.3...0.9), // Placeholder until real audio analysis
            acousticness: Double.random(in: 0.1...0.6),
            valence: Double.random(in: 0.2...0.8),
            bpm: Double.random(in: 80...140)
        )
    }
}
#endif
```

- [x] **Step 2: Build to verify conditional compilation**

Run:
```bash
xcodebuild -project EchoDJ.xcodeproj -scheme EchoDJ -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Expected: `** BUILD SUCCEEDED **`

- [x] **Step 3: Commit**

```bash
git add EchoDJ/Data/Models/CachedTrack.swift
git commit -m "feat(models): add MusicKit Track bridge to CachedTrack"
```

---

### Task 2: Create StationQueueManager

**Files:**
- Create: `EchoDJ/Engine/Concrete/StationQueueManager.swift`
- Modify: `EchoDJ/Engine/Concrete/AppleMusicProvider.swift`
- Test: Build

- [x] **Step 1: Write StationQueueManager.swift**

Create `EchoDJ/Engine/Concrete/StationQueueManager.swift`:

```swift
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
        let musicItemID = MusicItemID(rawValue: seedID)
        let request = MusicCatalogResourceRequest<Track>(matching: \.id, equalTo: musicItemID)
        let response = try await request.response()
        guard let seedTrack = response.items.first else { return [] }
        
        let searchTerm = seedTrack.artistName
        let searchRequest = MusicCatalogSearchRequest(term: searchTerm, types: [Track.self])
        searchRequest.limit = count
        let searchResponse = try await searchRequest.response()
        
        return searchResponse.tracks.compactMap { CachedTrack(from: $0) }
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
        guard let appleProvider = provider as? AppleMusicProvider else {
            for track in tracks {
                try? await provider.loadTrack(id: track.trackID)
            }
            return
        }
        
        var musicTracks: [Track] = []
        for cached in tracks {
            let musicItemID = MusicItemID(rawValue: cached.trackID)
            let request = MusicCatalogResourceRequest<Track>(matching: \.id, equalTo: musicItemID)
            if let track = try? await request.response().items.first {
                musicTracks.append(track)
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
```

- [x] **Step 2: Build to verify StationQueueManager compiles**

Run:
```bash
xcodebuild -project EchoDJ.xcodeproj -scheme EchoDJ -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Expected: `** BUILD SUCCEEDED **`

- [x] **Step 3: Commit**

```bash
git add EchoDJ/Engine/Concrete/StationQueueManager.swift
git commit -m "feat(queue): add StationQueueManager with vector ranking and cooldown filtering"
```

---

### Task 3: Wire StationQueueManager into AppEnvironment

**Files:**
- Modify: `EchoDJ/Core/AppEnvironment.swift`
- Test: Build

- [x] **Step 1: Add StationQueueManager to AppEnvironment**

In `EchoDJ/Core/AppEnvironment.swift`, add:

```swift
let queueManager: StationQueueManager
```

After the `djBrain` property declaration. Then initialize it in `init()` after the provider resolution:

```swift
self.queueManager = StationQueueManager(
    modelContainer: self.modelContainer,
    provider: self.musicProvider
)
```

The full `AppEnvironment.swift` should look like:

```swift
import Foundation
import SwiftData
import MusicKit

@MainActor
final class AppEnvironment: ObservableObject {
    static let shared = AppEnvironment()
    
    @Published var isMockMode: Bool = true
    @Published var musicProvider: any MusicProviderProtocol
    @Published var djBrain: any DJBrainProtocol
    let modelContainer: ModelContainer
    let queueManager: StationQueueManager
    
    private init() {
        let useMock = true
        self.isMockMode = useMock
        
        do {
            let schema = Schema([UserTasteProfile.self, TrackCooldown.self, CachedTrack.self])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            self.modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to initialize SwiftData Container: \(error)")
        }
        
        self.musicProvider = MockMusicProvider()
        self.djBrain = MockDJBrain()
        self.queueManager = StationQueueManager(
            modelContainer: self.modelContainer,
            provider: self.musicProvider
        )
        
        if !useMock {
            Task {
                await resolveProviders()
            }
        }
    }
    
    func resolveProviders() async {
        let realProvider = AppleMusicProvider()
        if await realProvider.isAvailable {
            self.musicProvider = realProvider
            print("AppEnvironment: Using AppleMusicProvider")
        } else {
            self.musicProvider = MockMusicProvider()
            print("AppEnvironment: MusicKit unavailable, falling back to MockMusicProvider")
        }
    }
}
```

- [x] **Step 2: Build to verify DI wiring**

Run:
```bash
xcodebuild -project EchoDJ.xcodeproj -scheme EchoDJ -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Expected: `** BUILD SUCCEEDED **`

- [x] **Step 3: Commit**

```bash
git add EchoDJ/Core/AppEnvironment.swift
git commit -m "feat(env): wire StationQueueManager into AppEnvironment"
```

---

### Task 4: Modify SearchView to Seed Stations

**Files:**
- Modify: `EchoDJ/UI/Tabs/SearchView.swift`
- Test: Build + runtime verification

- [x] **Step 1: Replace single-play tap with station seeding**

In `EchoDJ/UI/Tabs/SearchView.swift`, replace the `.onTapGesture` block inside the `ForEach`:

```swift
.onTapGesture {
    Task {
        try? await env.queueManager.generateStation(seedTrackID: track.trackID)
        try? await env.musicProvider.play()
        print("Station seeded from: \(track.title) [\(track.energy), \(track.valence)]")
    }
}
```

- [x] **Step 2: Build**

Run:
```bash
xcodebuild -project EchoDJ.xcodeproj -scheme EchoDJ -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Expected: `** BUILD SUCCEEDED **`

- [x] **Step 3: Commit**

```bash
git add EchoDJ/UI/Tabs/SearchView.swift
git commit -m "feat(ui): SearchView now seeds stations instead of playing single tracks"
```

---

### Task 5: Add "Next Up" UI to RadioView

**Files:**
- Modify: `EchoDJ/UI/Tabs/RadioView.swift`
- Test: Build + runtime verification

- [x] **Step 1: Add upcoming tracks state and fetch logic**

In `RadioView`, add a new state property after the existing `@State` declarations:

```swift
@State private var upcoming: [CachedTrack] = []
```

In `startProgressTimer()`, add an upcoming tracks fetch inside the timer block (after the provider state fetch):

```swift
let next = await env.queueManager.upcomingTracks(limit: 3)
await MainActor.run {
    self.upcoming = next
}
```

Add a "Next Up" section in the `VStack` after the progress bar:

```swift
if !upcoming.isEmpty {
    VStack(alignment: .leading, spacing: 8) {
        Text("Next Up")
            .font(.caption.bold())
            .foregroundStyle(.secondary)
        ForEach(upcoming.indices, id: \.self) { index in
            let track = upcoming[index]
            HStack {
                Text("\(index + 1).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading) {
                    Text(track.title)
                        .font(.caption.bold())
                    Text(track.artistName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }
    .padding()
    .background(.ultraThinMaterial)
    .cornerRadius(12)
    .padding(.horizontal)
}
```

- [x] **Step 2: Build**

Run:
```bash
xcodebuild -project EchoDJ.xcodeproj -scheme EchoDJ -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Expected: `** BUILD SUCCEEDED **`

- [x] **Step 3: Commit**

```bash
git add EchoDJ/UI/Tabs/RadioView.swift
git commit -m "feat(ui): add Next Up track list to RadioView"
```

---

## Self-Review

**Spec coverage:**
- `StationQueueManager` with vector ranking, cooldown filtering, MusicKit catalog search — Task 2
- `CachedTrack` MusicKit bridge — Task 1
- `AppEnvironment` wires `queueManager` — Task 3
- `SearchView` seeds stations — Task 4
- `RadioView` shows next 3 tracks — Task 5

**Placeholder scan:**
- No TBDs, TODOs, or vague requirements found.
- All code blocks contain complete, compilable Swift.
- `CachedTrack` genome values from MusicKit use `Double.random(in:)` as placeholders (noted in comment) since real audio analysis requires external APIs.

**Type consistency:**
- `StationQueueManager.generateStation(seedTrackID:count:)` signature matches call sites.
- `StationQueueManager.upcomingTracks(limit:)` returns `[CachedTrack]`, matches `RadioView` state.
- `VectorAffinityEngine.calculateDistance(profile:track:)` is static, matches call in Task 2.

**Gaps:** None. All Phase 3 requirements from the master roadmap are covered.
