# 📑 Plan 000: EchoDJ Master Roadmap Design
> **Status:** Active | **Parent Milestone:** Master Roadmap

## 🎯 1. Target Scope & Boundaries
- **Core Objective:** Build a fully testable iOS radio application (EchoDJ) that generates personalized music stations using vector-based recommendation math, runs on-device without requiring a paid Apple Developer account, and provides a complete DJ transition experience. All real Apple APIs (MusicKit, Foundation Models, CloudKit) are integrated immediately with runtime mock fallbacks.
- **Out of Scope:** App Store distribution, TestFlight, self-hosted Navidrome integration (Pro+ tier), social features, user accounts.

## 🏗️ 2. Hardware & Account Constraints
- **Device:** iPhone 17 Pro Max (supports Foundation Models on-device LLM).
- **Subscription:** Apple Music active (enables MusicKit playback).
- **Dev Account:** Free Apple ID. Provisioning expires every 7 days. Max 3 sideloaded apps.
- **Implication:** MusicKit, CloudKit development, and Foundation Models are all testable. The only hard gate is the 7-day re-signing cycle, not functionality.

## 🚶‍♂️ 3. Phase-by-Phase Execution Checklist

### Phase 1: Core App MVP *(Complete)*
- [x] SwiftData models: `UserTasteProfile`, `TrackCooldown`, `CachedTrack`
- [x] Vector math engine: `VectorAffinityEngine`
- [x] Actor-isolated protocols: `MusicProviderProtocol`, `DJBrainProtocol`
- [x] Mock providers: `MockMusicProvider`, `MockDJBrain`
- [x] Dependency injection container: `AppEnvironment` with runtime mock flag
- [x] Basic SwiftUI shell: `MainTabView`, `RadioView`, `SearchView`, `VibeVisualizer`
- [x] Manual Xcode project generation (xcodegen unavailable)
- [x] iOS 26 / Swift 6 compilation fixes

### Phase 2: Real Playback Integration
- [ ] Implement `AppleMusicProvider` using `ApplicationMusicPlayer` + MusicKit
- [ ] Add runtime availability gate: if MusicKit auth is `.denied`, simulator, or no Apple Music sub → auto-fallback to `MockMusicProvider`
- [ ] Configure `MPRemoteCommandCenter` for lock-screen / background skip controls
- [ ] Set `MPNowPlayingInfoCenter` metadata (artwork, title, artist, progress)
- [ ] Enable background audio mode in `Info.plist`
- [ ] Wire `RadioView` play/pause button to real playback state
- [ ] Add playback progress bar tied to `ApplicationMusicPlayer.playbackTime`

### Phase 3: Station Queue Engine
- [ ] Create `StationQueueManager` singleton actor
- [ ] Catalog search via `MusicCatalogResourceRequest` or fallback to local `CachedTrack` pool
- [ ] Queue generation: calculate weighted Euclidean distance for candidate tracks, filter by `TrackCooldown`, select top 20
- [ ] Inject generated queue into `ApplicationMusicPlayer.queue`
- [ ] Modify `SearchView`: tapping a track seeds a station (generates queue) rather than playing a single song
- [ ] Add "Next Up" UI in `RadioView` showing the upcoming 3 tracks

### Phase 4: Taste Profile Evolution & Telemetry
- [ ] Playback ratio tracker: `playbackTime / duration` updated on a timer
- [ ] Soft Skip (thumbs down): call `VectorAffinityEngine.applyFeedback(profile:track:playbackRatio:)` with current ratio, insert `TrackCooldown` (24h, penaltyScore=1)
- [ ] Hard Skip (thumbs down + hold): same as soft skip but penaltyScore=2, 7-day cooldown
- [ ] Full play (>90%): positive vector shift toward track traits
- [ ] Instant skip (<10%): negative vector shift away from track traits
- [ ] Vibe Tuner slider: mutate `UserTasteProfile` energy/valence in real-time, persist via SwiftData
- [ ] Clamp all vector attributes to [0.0, 1.0]

### Phase 5: DJ Transition Pipeline
- [ ] Create `TransitionManager` actor
- [ ] Pre-render transition: while Track A plays, call `DJBrainProtocol.generateTransition(meta:)` concurrently for Track B
- [ ] TTS integration: ElevenLabs Flash API or Cartesia API (network call)
- [ ] Local disk cache for rendered `.mp3` files in `NSTemporaryDirectory`
- [ ] Audio ducking: lower playback gain (simulated via MusicKit volume if accessible, or system volume), inject transition MP3, fade back
- [ ] If TTS fails or is unavailable, fall back to local bundled MP3 or silence
- [ ] Mock mode: `MockDJBrain` returns hardcoded strings; TTS still works via network or local files

### Phase 6: On-Device LLM DJ
- [ ] Implement `OnDeviceDJBrain` using Foundation Models `LanguageModelSession`
- [ ] Check `SystemLanguageModel.default.availability` at init; if `.unavailable`, retain `MockDJBrain` as fallback
- [ ] Prompt engineering: "You are Echo. Write a brief, witty segue under 15 words. Reference mood and BPM."
- [ ] Pass `TransitionMetadata` (last/next track titles, artists, mood context, BPM) to prompt
- [ ] Handle model download states and errors gracefully
- [ ] Replace `MockDJBrain` in `AppEnvironment` when available, with runtime fallback preserved

### Phase 7: CloudKit Sync & Monetization
- [ ] Add CloudKit container to SwiftData `ModelConfiguration` when `!isMockMode`
- [ ] Sync `UserTasteProfile` and `TrackCooldown` across devices via iCloud
- [ ] Implement `SubscriptionManager` with StoreKit 2
- [ ] Tiers: Free (limited skips, no DJ voice), Pro (unlimited skips, full DJ, TTS), Pro+ (future: self-hosted Navidrome)
- [ ] Entitlement-gate DJ transition pipeline and CloudKit sync behind Pro tier
- [ ] Graceful degradation: if StoreKit fails, treat as Free tier

## 🔄 4. Fallback Strategy (Mock &lt;- &gt; Real)
All concrete providers implement an `isAvailable` check. `AppEnvironment` resolves the live provider first; if unavailable, falls back to the mock. This applies to:
- `AppleMusicProvider` ↔ `MockMusicProvider`
- `OnDeviceDJBrain` ↔ `MockDJBrain`
- CloudKit container ↔ local-only `ModelConfiguration`

No separate build targets or compile-time flags are needed. The decision is runtime and logged.

## 🧪 5. Verification Criteria Per Phase
Each phase must pass:
1. **Build:** `xcodebuild` succeeds with zero errors on iOS 18.0+ simulator target.
2. **Runtime:** App launches without crashing on iPhone 17 Pro Max physical device.
3. **Feature:** The specific user-facing behavior described in the phase works end-to-end.
4. **Fallback:** If real APIs are unavailable, mock behavior activates silently and logs the reason.

## 📦 6. Git Commit Cadence
- Atomic commits per sub-task.
- Conventional Commits format: `feat(scope): description`, `fix(scope): description`, `docs(scope): description`.
- No `git push` — all work remains local.
