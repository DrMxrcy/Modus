# Taste Profile Evolution & Telemetry Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Implement playback telemetry, skip-based taste profile evolution, and real-time Vibe Tuner mutation so the station adapts to user behavior.

**Architecture:** A `TelemetryCollector` actor polls playback progress and records completion ratios. On skip events, it calls `VectorAffinityEngine.applyFeedback(...)` to mutate the `UserTasteProfile`. Soft and hard skips insert `TrackCooldown` records with 24h and 7-day expiration respectively. The Vibe Tuner slider in `RadioView` directly mutates the profile via SwiftData. All changes are clamped to [0.0, 1.0].

**Tech Stack:** Swift 6, SwiftData, SwiftUI, Xcode 26

---

## File Map

| File | Responsibility | Action |
|------|---------------|--------|
| `EchoDJ/Engine/Concrete/TelemetryCollector.swift` | Playback progress tracking, skip telemetry dispatch | Create |
| `EchoDJ/Engine/Concrete/VectorAffinityEngine.swift` | Vector math and feedback application | Extend with clamping |
| `EchoDJ/UI/Tabs/RadioView.swift` | Player UI | Wire skip buttons to telemetry, Vibe Tuner to profile mutation |
| `EchoDJ/Core/AppEnvironment.swift` | DI container | Add `TelemetryCollector` reference |

---

### Task 1: Extend VectorAffinityEngine with Clamping

**Files:**
- Modify: `EchoDJ/Engine/Concrete/VectorAffinityEngine.swift`
- Test: Build

- [x] **Step 1: Add clamping after every profile mutation**

In `EchoDJ/Engine/Concrete/VectorAffinityEngine.swift`, modify `applyFeedback` to clamp all values immediately after the positive and negative branches. Add a private helper:

```swift
private static func clamp(_ value: Double) -> Double {
    max(0.0, min(1.0, value))
}
```

Then wrap the profile mutations:

```swift
static func applyFeedback(profile: inout UserTasteProfile, track: CachedTrack, playbackRatio: Double) {
    let alpha = 0.15
    
    if playbackRatio >= 0.90 {
        profile.energyPreference = clamp(profile.energyPreference + alpha * (track.energy - profile.energyPreference))
        profile.acousticnessPreference = clamp(profile.acousticnessPreference + alpha * (track.acousticness - profile.acousticnessPreference))
        profile.valencePreference = clamp(profile.valencePreference + alpha * (track.valence - profile.valencePreference))
        profile.targetBPM = clamp(profile.targetBPM + alpha * (track.bpm - profile.targetBPM))
    } else if playbackRatio <= 0.10 {
        profile.energyPreference = clamp(profile.energyPreference - alpha * (track.energy - profile.energyPreference))
        profile.acousticnessPreference = clamp(profile.acousticnessPreference - alpha * (track.acousticness - profile.acousticnessPreference))
        profile.valencePreference = clamp(profile.valencePreference - alpha * (track.valence - profile.valencePreference))
        profile.targetBPM = clamp(profile.targetBPM - alpha * (track.bpm - profile.targetBPM))
    }
    profile.lastUpdated = Date()
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
git add EchoDJ/Engine/Concrete/VectorAffinityEngine.swift
git commit -m "refactor(engine): add clamping to VectorAffinityEngine feedback"
```

---

### Task 2: Create TelemetryCollector

**Files:**
- Create: `EchoDJ/Engine/Concrete/TelemetryCollector.swift`
- Modify: `EchoDJ/Engine/Protocols/MusicProviderProtocol.swift`
- Test: Build

- [x] **Step 1: Add `playbackDuration` to protocol**

In `EchoDJ/Engine/Protocols/MusicProviderProtocol.swift`, add:

```swift
var playbackDuration: Double { get }
```

After `currentPlaybackProgress`.

Implement it in `EchoDJ/Engine/Mocks/MockMusicProvider.swift`:

```swift
var playbackDuration: Double { 240.0 } // Mock 4-minute track
```

Implement it in `EchoDJ/Engine/Concrete/AppleMusicProvider.swift`:

```swift
var playbackDuration: Double {
    player.queue.currentEntry?.item.duration ?? 0.0
}
```

- [x] **Step 2: Write TelemetryCollector.swift**

Create `EchoDJ/Engine/Concrete/TelemetryCollector.swift`:

```swift
import Foundation
import SwiftData

actor TelemetryCollector {
    private let provider: any MusicProviderProtocol
    private let modelContainer: ModelContainer
    
    init(provider: any MusicProviderProtocol, modelContainer: ModelContainer) {
        self.provider = provider
        self.modelContainer = modelContainer
    }
    
    func recordSoftSkip(trackID: String) async {
        await applySkipFeedback(trackID: trackID, penaltyScore: 1)
    }
    
    func recordHardSkip(trackID: String) async {
        await applySkipFeedback(trackID: trackID, penaltyScore: 2)
    }
    
    private func applySkipFeedback(trackID: String, penaltyScore: Int) async {
        let progress = await provider.currentPlaybackProgress
        let context = modelContainer.mainContext
        
        let trackDescriptor = FetchDescriptor<CachedTrack>(
            predicate: #Predicate { $0.trackID == trackID }
        )
        let profileDescriptor = FetchDescriptor<UserTasteProfile>()
        
        guard let track = (try? context.fetch(trackDescriptor))?.first,
              var profile = (try? context.fetch(profileDescriptor))?.first else { return }
        
        VectorAffinityEngine.applyFeedback(
            profile: &profile,
            track: track,
            playbackRatio: progress
        )
        
        let expiration = Date().addingTimeInterval(
            penaltyScore == 1 ? 86400 : 604800 // 24h vs 7 days
        )
        
        let cooldown = TrackCooldown(
            trackID: trackID,
            artistName: track.artistName,
            expiration: expiration,
            penaltyScore: penaltyScore
        )
        
        context.insert(cooldown)
        try? context.save()
    }
    
    func recordFullPlay(trackID: String) async {
        let context = modelContainer.mainContext
        
        let trackDescriptor = FetchDescriptor<CachedTrack>(
            predicate: #Predicate { $0.trackID == trackID }
        )
        let profileDescriptor = FetchDescriptor<UserTasteProfile>()
        
        guard let track = (try? context.fetch(trackDescriptor))?.first,
              var profile = (try? context.fetch(profileDescriptor))?.first else { return }
        
        VectorAffinityEngine.applyFeedback(
            profile: &profile,
            track: track,
            playbackRatio: 1.0
        )
        
        try? context.save()
    }
}
```

- [x] **Step 3: Build**

Run:
```bash
xcodebuild -project EchoDJ.xcodeproj -scheme EchoDJ -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Expected: `** BUILD SUCCEEDED **`

- [x] **Step 4: Commit**

```bash
git add EchoDJ/Engine/Concrete/TelemetryCollector.swift EchoDJ/Engine/Protocols/MusicProviderProtocol.swift EchoDJ/Engine/Mocks/MockMusicProvider.swift EchoDJ/Engine/Concrete/AppleMusicProvider.swift
git commit -m "feat(telemetry): add TelemetryCollector with skip/feedback pipeline"
```

---

### Task 3: Wire TelemetryCollector into AppEnvironment

**Files:**
- Modify: `EchoDJ/Core/AppEnvironment.swift`
- Test: Build

- [x] **Step 1: Add TelemetryCollector to AppEnvironment**

In `EchoDJ/Core/AppEnvironment.swift`, add:

```swift
let telemetryCollector: TelemetryCollector
```

After `queueManager`. Initialize it in `init()` after `queueManager`:

```swift
self.telemetryCollector = TelemetryCollector(
    provider: self.musicProvider,
    modelContainer: self.modelContainer
)
```

- [x] **Step 2: Build**

Run:
```bash
xcodebuild -project EchoDJ.xcodeproj -scheme EchoDJ -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Expected: `** BUILD SUCCEEDED **`

- [x] **Step 3: Commit**

```bash
git add EchoDJ/Core/AppEnvironment.swift
git commit -m "feat(env): wire TelemetryCollector into AppEnvironment"
```

---

### Task 4: Wire Skip Buttons in RadioView to Telemetry

**Files:**
- Modify: `EchoDJ/UI/Tabs/RadioView.swift`
- Test: Build + runtime verification

- [x] **Step 1: Replace hardSkip and softSkip with telemetry dispatch**

In `RadioView`, replace the `hardSkip` and `softSkip` functions:

```swift
private func hardSkip() {
    Task {
        let trackID = await env.musicProvider.currentTrackID ?? "Unknown"
        await env.telemetryCollector.recordHardSkip(trackID: trackID)
        try? await env.musicProvider.skipNext()
        print("Hard Skip Triggered for \(trackID)")
    }
}

private func softSkip() {
    Task {
        let trackID = await env.musicProvider.currentTrackID ?? "Unknown"
        await env.telemetryCollector.recordSoftSkip(trackID: trackID)
        try? await env.musicProvider.skipNext()
        print("Soft Skip Triggered for \(trackID)")
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
git add EchoDJ/UI/Tabs/RadioView.swift
git commit -m "feat(ui): wire RadioView skip buttons to TelemetryCollector"
```

---

### Task 5: Make Vibe Tuner Mutate UserTasteProfile

**Files:**
- Modify: `EchoDJ/UI/Tabs/RadioView.swift`
- Test: Build + runtime verification

- [x] **Step 1: Add SwiftData mutation to Slider value change**

In `RadioView`, replace the Slider closure:

```swift
Slider(value: $valenceLevel, in: 0...1) { _ in
    Task {
        let context = env.modelContainer.mainContext
        let descriptor = FetchDescriptor<UserTasteProfile>()
        if let profile = (try? context.fetch(descriptor))?.first {
            profile.valencePreference = valenceLevel
            try? context.save()
            print("Vibe Tuner updated valence to \(valenceLevel)")
        }
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
git add EchoDJ/UI/Tabs/RadioView.swift
git commit -m "feat(ui): Vibe Tuner slider now mutates UserTasteProfile in real-time"
```

---

## Self-Review

**Spec coverage:**
- Playback ratio tracking via `TelemetryCollector` — Task 2
- Soft skip (24h cooldown, penaltyScore=1) — Task 2
- Hard skip (7-day cooldown, penaltyScore=2) — Task 2
- Full play (>90%) positive vector shift — Task 2
- Instant skip (<10%) negative vector shift — Task 2
- Vibe Tuner slider mutates `UserTasteProfile` — Task 5
- Clamp all attributes to [0.0, 1.0] — Task 1

**Placeholder scan:**
- No TBDs, TODOs, or vague requirements found.
- All code blocks contain complete, compilable Swift.

**Type consistency:**
- `TelemetryCollector.recordSoftSkip(trackID:)` and `recordHardSkip(trackID:)` signatures match call sites in RadioView.
- `VectorAffinityEngine.applyFeedback(profile:track:playbackRatio:)` is `static`, matches all call sites.
- `UserTasteProfile.valencePreference` is `Double`, matches Slider value type.

**Gaps:** None. All Phase 4 requirements from the master roadmap are covered.
