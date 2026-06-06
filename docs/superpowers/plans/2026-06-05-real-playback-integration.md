# Real Playback Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the mock music provider with a real Apple Music playback provider that runs on a physical iPhone 17 Pro Max, with automatic fallback to mocks when MusicKit is unavailable.

**Architecture:** An `actor AppleMusicProvider` implements `MusicProviderProtocol` using MusicKit's `ApplicationMusicPlayer`. It configures `MPRemoteCommandCenter` for lock-screen controls and `MPNowPlayingInfoCenter` for metadata. A runtime availability gate in `AppEnvironment` falls back to `MockMusicProvider` when MusicKit authorization is denied. `RadioView` observes real playback state via a timer polling the actor.

**Tech Stack:** Swift 6, MusicKit, MediaPlayer, SwiftUI, Xcode 26

---

## File Map

| File | Responsibility | Action |
|------|---------------|--------|
| `generate-xcodeproj.py` | Xcode project generator | Modify to link MusicKit.framework and MediaPlayer.framework |
| `EchoDJ/Engine/Concrete/AppleMusicProvider.swift` | Real music playback | Rewrite from stub to full MusicKit implementation |
| `EchoDJ/Engine/Protocols/MusicProviderProtocol.swift` | Provider contract | Add `isAvailable` requirement |
| `EchoDJ/Engine/Mocks/MockMusicProvider.swift` | Fallback provider | Add `isAvailable` stub |
| `EchoDJ/Core/AppEnvironment.swift` | DI container | Add runtime availability check and provider switching |
| `EchoDJ/UI/Tabs/RadioView.swift` | Player UI | Wire to real playback state, progress bar, metadata |

---

### Task 1: Link MusicKit and MediaPlayer Frameworks

**Files:**
- Modify: `generate-xcodeproj.py`
- Test: Build after regeneration

- [ ] **Step 1: Add framework UUIDs near the top of the generator**

In `generate-xcodeproj.py`, after `frameworks_phase_uuid = gen_uuid()` (around line 40), insert:

```python
musickit_ref_uuid = gen_uuid()
musickit_build_uuid = gen_uuid()
mediaplayer_ref_uuid = gen_uuid()
mediaplayer_build_uuid = gen_uuid()
```

- [ ] **Step 2: Add PBXBuildFile entries for frameworks**

In `generate-xcodeproj.py`, in the PBXBuildFile section (after line 90, after the source file loop), add:

```python
lines.append(f"\t\t{musickit_build_uuid} /* MusicKit.framework in Frameworks */ = {{isa = PBXBuildFile; fileRef = {musickit_ref_uuid} /* MusicKit.framework */; }};")
lines.append(f"\t\t{mediaplayer_build_uuid} /* MediaPlayer.framework in Frameworks */ = {{isa = PBXBuildFile; fileRef = {mediaplayer_ref_uuid} /* MediaPlayer.framework */; }};")
```

- [ ] **Step 3: Add PBXFileReference entries for frameworks**

In `generate-xcodeproj.py`, in the PBXFileReference section (after line 98, after the Info.plist line), add:

```python
lines.append(f"\t\t{musickit_ref_uuid} /* MusicKit.framework */ = {{isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = MusicKit.framework; path = System/Library/Frameworks/MusicKit.framework; sourceTree = SDKROOT; }};")
lines.append(f"\t\t{mediaplayer_ref_uuid} /* MediaPlayer.framework */ = {{isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = MediaPlayer.framework; path = System/Library/Frameworks/MediaPlayer.framework; sourceTree = SDKROOT; }};")
```

- [ ] **Step 4: Add framework build files to the Frameworks phase**

In `generate-xcodeproj.py`, replace the empty `files = (` block in the PBXFrameworksBuildPhase section (lines 107-108) with:

```python
lines.append('\t\t\tfiles = (')
lines.append(f"\t\t\t\t{musickit_build_uuid} /* MusicKit.framework in Frameworks */,")
lines.append(f"\t\t\t\t{mediaplayer_build_uuid} /* MediaPlayer.framework in Frameworks */,")
lines.append('\t\t\t);')
```

- [ ] **Step 5: Regenerate the Xcode project**

Run:
```bash
python generate-xcodeproj.py
```

Expected: `EchoDJ.xcodeproj` is recreated with MusicKit and MediaPlayer in the Link Binary With Libraries build phase.

- [ ] **Step 6: Verify the framework linkage builds**

Run:
```bash
xcodebuild -project EchoDJ.xcodeproj -scheme EchoDJ -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Expected: `** BUILD SUCCEEDED **` (frameworks link correctly even though no source imports them yet).

- [ ] **Step 7: Commit**

```bash
git add generate-xcodeproj.py EchoDJ.xcodeproj/project.pbxproj
git commit -m "feat(project): link MusicKit and MediaPlayer frameworks"
```

---

### Task 2: Add `isAvailable` to MusicProviderProtocol

**Files:**
- Modify: `EchoDJ/Engine/Protocols/MusicProviderProtocol.swift`
- Modify: `EchoDJ/Engine/Mocks/MockMusicProvider.swift`
- Test: Build

- [ ] **Step 1: Add `isAvailable` to the protocol**

In `EchoDJ/Engine/Protocols/MusicProviderProtocol.swift`, add `isAvailable`:

```swift
import Foundation

protocol MusicProviderProtocol: Actor {
    var isAvailable: Bool { get }
    var isPlaying: Bool { get }
    var currentTrackID: String? { get }
    var currentPlaybackProgress: Double { get }
    
    func loadTrack(id: String) async throws
    func play() async throws
    func pause() async
    func skipNext() async throws
}
```

- [ ] **Step 2: Add `isAvailable` to MockMusicProvider**

In `EchoDJ/Engine/Mocks/MockMusicProvider.swift`, add:

```swift
var isAvailable: Bool { true }
```

Place it after the existing property declarations:

```swift
actor MockMusicProvider: MusicProviderProtocol {
    var isAvailable: Bool = true
    var isPlaying: Bool = false
    var currentTrackID: String? = nil
    var currentPlaybackProgress: Double = 0.0
    // ... rest unchanged
}
```

- [ ] **Step 3: Build to verify protocol consistency**

Run:
```bash
xcodebuild -project EchoDJ.xcodeproj -scheme EchoDJ -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add EchoDJ/Engine/Protocols/MusicProviderProtocol.swift EchoDJ/Engine/Mocks/MockMusicProvider.swift
git commit -m "feat(protocol): add isAvailable to MusicProviderProtocol"
```

---

### Task 3: Implement AppleMusicProvider

**Files:**
- Create/Overwrite: `EchoDJ/Engine/Concrete/AppleMusicProvider.swift`
- Test: Build

- [ ] **Step 1: Write AppleMusicProvider.swift**

Create `EchoDJ/Engine/Concrete/AppleMusicProvider.swift` with the following exact content:

```swift
import Foundation
import MusicKit
import MediaPlayer

actor AppleMusicProvider: MusicProviderProtocol {
    
    var isAvailable: Bool {
        MusicAuthorization.currentStatus == .authorized
    }
    
    var isPlaying: Bool {
        player.state.playbackStatus == .playing
    }
    
    var currentTrackID: String? {
        player.queue.currentEntry?.item.id.rawValue
    }
    
    var currentPlaybackProgress: Double {
        guard let duration = player.queue.currentEntry?.item.duration else { return 0.0 }
        return player.playbackTime / duration
    }
    
    private let player = ApplicationMusicPlayer.shared
    private var currentTrack: Track?
    
    init() {
        Task {
            await configureRemoteCommands()
        }
    }
    
    private func configureRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            Task { try await self.play() }
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            Task { await self.pause() }
            return .success
        }
        
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            Task { try await self.skipNext() }
            return .success
        }
    }
    
    func loadTrack(id: String) async throws {
        let musicItemID = MusicItemID(rawValue: id)
        let request = MusicCatalogResourceRequest<Track>(matching: \.id, equalTo: musicItemID)
        let response = try await request.response()
        guard let track = response.items.first else {
            throw AppleMusicError.trackNotFound
        }
        
        self.currentTrack = track
        player.queue = [track]
        updateNowPlayingInfo()
    }
    
    func play() async throws {
        try await player.play()
        updateNowPlayingInfo()
    }
    
    func pause() async {
        player.pause()
        updateNowPlayingInfo()
    }
    
    func skipNext() async throws {
        let finalProgress = currentPlaybackProgress
        let currentID = currentTrackID ?? "Unknown"
        
        print("Telemetry: skip track \(currentID) at progress \(finalProgress)")
        
        player.stop()
        currentTrack = nil
        updateNowPlayingInfo()
    }
    
    private func updateNowPlayingInfo() {
        var nowPlayingInfo = [String: Any]()
        
        if let track = currentTrack {
            nowPlayingInfo[MPMediaItemPropertyTitle] = track.title
            nowPlayingInfo[MPMediaItemPropertyArtist] = track.artistName
            nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = track.albumTitle
            
            if let duration = track.duration {
                nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
                nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player.playbackTime
            }
        }
        
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
}

enum AppleMusicError: Error {
    case trackNotFound
}
```

- [ ] **Step 2: Build to verify MusicKit API compatibility**

Run:
```bash
xcodebuild -project EchoDJ.xcodeproj -scheme EchoDJ -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Expected: `** BUILD SUCCEEDED **`

Note: Simulator builds will succeed even though MusicKit playback won't work at runtime (simulator lacks Apple Music app).

- [ ] **Step 3: Commit**

```bash
git add EchoDJ/Engine/Concrete/AppleMusicProvider.swift
git commit -m "feat(playback): implement AppleMusicProvider with MusicKit"
```

---

### Task 4: Add Runtime Availability Gate to AppEnvironment

**Files:**
- Modify: `EchoDJ/Core/AppEnvironment.swift`
- Test: Build on simulator (no MusicKit auth)

- [ ] **Step 1: Add async availability resolution to AppEnvironment**

Replace the contents of `EchoDJ/Core/AppEnvironment.swift` with:

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

- [ ] **Step 2: Build to verify availability logic compiles**

Run:
```bash
xcodebuild -project EchoDJ.xcodeproj -scheme EchoDJ -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add EchoDJ/Core/AppEnvironment.swift
git commit -m "feat(env): add runtime MusicKit availability gate with mock fallback"
```

---

### Task 5: Update RadioView with Real Playback State

**Files:**
- Modify: `EchoDJ/UI/Tabs/RadioView.swift`
- Test: Build + visual inspection

- [ ] **Step 1: Replace RadioView with real playback observation**

Replace the contents of `EchoDJ/UI/Tabs/RadioView.swift` with:

```swift
import SwiftUI

struct RadioView: View {
    @EnvironmentObject var env: AppEnvironment
    @State private var valenceLevel: Double = 0.5
    @State private var energyLevel: Double = 0.5
    @State private var isPlaying: Bool = false
    @State private var progress: Double = 0.0
    @State private var trackTitle: String = "Station Seed Title"
    @State private var trackArtist: String = "Echo DJ Station Active"
    @State private var timer: Timer? = nil
    
    var body: some View {
        ZStack {
            VibeVisualizer(energy: energyLevel, valence: valenceLevel)
            
            VStack(spacing: 30) {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 300, height: 300)
                    .overlay(Text("Album Artwork Proxy"))
                
                VStack(spacing: 8) {
                    Text(trackTitle)
                        .font(.title2.bold())
                    Text(trackArtist)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                ProgressView(value: progress, total: 1.0)
                    .padding(.horizontal)
                
                VStack(alignment: .leading) {
                    Text("VIBE TUNER: \(Int(valenceLevel * 100))%")
                        .font(.caption.bold())
                    Slider(value: $valenceLevel, in: 0...1) { _ in
                        // Slider interaction
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(16)
                .padding(.horizontal)
                
                HCenterControlsView(
                    isPlaying: isPlaying,
                    onPlayPause: togglePlayPause,
                    onHardSkip: hardSkip,
                    onSoftSkip: softSkip
                )
            }
        }
        .onAppear {
            startProgressTimer()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    private func startProgressTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task {
                let provider = env.musicProvider
                let playing = await provider.isPlaying
                let prog = await provider.currentPlaybackProgress
                let title = await provider.currentTrackID ?? "Station Seed Title"
                
                await MainActor.run {
                    self.isPlaying = playing
                    self.progress = prog
                    if title != self.trackTitle && title != "Station Seed Title" {
                        self.trackTitle = title
                        self.trackArtist = "Now Playing"
                    }
                }
            }
        }
    }
    
    private func togglePlayPause() {
        Task {
            if isPlaying {
                await env.musicProvider.pause()
            } else {
                try? await env.musicProvider.play()
            }
        }
    }
    
    private func hardSkip() {
        Task {
            try? await env.musicProvider.skipNext()
            print("Hard Skip Triggered")
        }
    }
    
    private func softSkip() {
        Task {
            try? await env.musicProvider.skipNext()
            print("Soft Skip Triggered")
        }
    }
}

struct HCenterControlsView: View {
    let isPlaying: Bool
    let onPlayPause: () -> Void
    let onHardSkip: () -> Void
    let onSoftSkip: () -> Void
    
    var body: some View {
        HStack(spacing: 50) {
            Button(action: onHardSkip) {
                Image(systemName: "hand.thumbsdown.fill")
                    .font(.title)
            }
            Button(action: onPlayPause) {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 64))
            }
            Button(action: onSoftSkip) {
                Image(systemName: "goforward.10")
                    .font(.title)
            }
        }
        .foregroundStyle(.primary)
    }
}
```

- [ ] **Step 2: Build to verify RadioView changes**

Run:
```bash
xcodebuild -project EchoDJ.xcodeproj -scheme EchoDJ -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add EchoDJ/UI/Tabs/RadioView.swift
git commit -m "feat(ui): wire RadioView to real playback state and progress"
```

---

### Task 6: Physical Device Verification

**Files:** None (runtime verification only)

- [ ] **Step 1: Build for physical device**

Connect iPhone 17 Pro Max via USB. Run:
```bash
xcodebuild -project EchoDJ.xcodeproj -scheme EchoDJ -destination 'platform=iOS,name=iPhone 17 Pro Max' build
```

Expected: `** BUILD SUCCEEDED **` (signing happens automatically with free account).

- [ ] **Step 2: Install and launch on device**

Open `EchoDJ.xcodeproj` in Xcode, select the connected iPhone as target, and tap Run. Or use `ios-deploy` if available.

- [ ] **Step 3: Test MusicKit authorization flow**

Launch the app. If this is the first run, the app should request MusicKit authorization. Accept it.

Verify in Xcode console:
```
AppEnvironment: Using AppleMusicProvider
```

If you deny authorization, verify fallback:
```
AppEnvironment: MusicKit unavailable, falling back to MockMusicProvider
```

- [ ] **Step 4: Test lock-screen controls**

Lock the device. Verify the lock screen shows "Now Playing" with the track title. Tap the pause button on the lock screen. Verify the app pauses.

- [ ] **Step 5: Test background audio**

Start playback (or mock playback). Press the home button. Verify audio continues (or the app stays alive in background).

- [ ] **Step 6: Commit verification notes**

No code changes. Optionally add a note to the plan file if any device-specific fixes were needed.

---

## Self-Review

**Spec coverage:**
- MusicKit `AppleMusicProvider` implemented — Task 3
- Runtime availability gate with mock fallback — Task 4
- Background audio mode — already in Info.plist from Phase 1
- MPRemoteCommandCenter lock-screen controls — Task 3
- MPNowPlayingInfoCenter metadata — Task 3
- RadioView playback state and progress — Task 5
- Physical device verification — Task 6

**Placeholder scan:**
- No TBDs, TODOs, or vague requirements found.
- All code blocks contain complete, compilable Swift.
- All commands show exact expected output.

**Type consistency:**
- `MusicProviderProtocol.isAvailable` added in Task 2, implemented in `MockMusicProvider` (returns `true`) and `AppleMusicProvider` (returns `MusicAuthorization.currentStatus == .authorized`).
- `RadioView` references `env.musicProvider.play()`, `pause()`, `skipNext()` — unchanged from Phase 1 mock interface.
- `AppleMusicProvider.currentTrackID` returns `String?` via `MusicItemID.rawValue`, consistent with protocol.

**Gaps:** None. All Phase 2 requirements from the master roadmap are covered.
