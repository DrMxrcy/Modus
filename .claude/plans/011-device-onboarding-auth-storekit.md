---
name: device-onboarding-auth-storekit
description: Build a real-device onboarding flow: explicit MusicKit authorization, Apple Music library history import for real seed tracks, StoreKit sandbox configuration for premium testing without purchases, and hardened device playback paths.
metadata:
  type: project
  date: 2026-06-09
  parent_milestone: App Store v1
---

# Plan 011: Device Onboarding, Auth & StoreKit Sandbox

## 1. Target Scope & Boundaries

### Core Objective
Make the app actually work on a real iPhone with a real Apple Music subscription. This means:
1. **Explicit MusicKit authorization flow** — user sees a clear onboarding screen before any station can start; no buried background-task auth.
2. **Apple Music library import** — on first launch (or after auth), import the user's real library/playlists/history to build seed tracks with real MusicKit IDs, replacing the synthetic `trackID: "1"` seed library.
3. **StoreKit sandbox testing** — configure the local `.storekit` + scheme wiring so we can test Pro tier flips without real Apple ID purchases.
4. **Device playback hardening** — fix the silent failure chain where auth → empty catalog → empty queue → empty playback → alert.

### Execution Mode
**Device-first.** Every task that touches MusicKit or StoreKit is verified on the connected iPhone before being marked complete. Simulator is only used for UI layout sanity checks.

### Out of Scope (deferred to sim-only follow-up or later plans)
- Real App Store Connect product creation (we keep `.storekit` local)
- Lock screen / background audio refinement (separate plan)
- Transition sanitization beyond current state
- CloudKit cross-device sync (single-device testing only)
- **Search artwork thumbnails + RadioView shadow/polish** — absorbed from Plan 010 as 🟢 sim-only UI tasks; they don't block device onboarding and can run in parallel on simulator.

## 1b. Cross-Reference with Plan 010
Plan 010 (`fix-errors-artwork-storekit-ui`) is superseded by this plan for everything device-critical. The remaining Plan 010 items that are purely UI polish are moved to a 🟢 sim-only parallel track below so they don't gate device work.

## 2. Files to Create

- `Modus/UI/Onboarding/OnboardingView.swift` — full-screen onboarding: welcome, MusicKit auth request button, privacy note, skip-to-settings fallback.
- `Modus/Engine/Concrete/MusicLibraryImporter.swift` — actor that queries `MusicLibraryRequest` / `MPMediaQuery` to build real `CachedTrack` seeds with real MusicKit IDs.

## 3. Files to Modify

- `Modus/Core/AppEnvironment.swift` — add `@Published var musicAuthStatus: MusicAuthorization.Status`, expose `requestAuth()` as explicit user action, gate `resolveCapabilities()` on completed onboarding.
- `Modus/Core/ModusApp.swift` (or `EchoDJApp.swift`) — show `OnboardingView` as root when auth is not `.authorized` and onboarding not completed.
- `Modus/UI/Tabs/SearchView.swift` — remove synthetic `seedLibrary` for device builds (`#if targetEnvironment(simulator)`); on device, show imported library + catalog search results only.
- `Modus/UI/Tabs/RadioView.swift` — add auth status banner (not just tier badge); if auth is `.denied`, show "Open Settings" button.
- `Modus/Engine/Concrete/AppleMusicProvider.swift` — log auth status on every `loadTrack` call; add explicit `authRequired` error instead of generic `trackNotFound` when auth is missing.
- `Modus/Engine/Concrete/StationQueueManager.swift` — fail fast with user-facing message when discovery pool is empty due to auth failure.
- `Modus/Engine/Concrete/SubscriptionManager.swift` — ensure product ID matches `.storekit`; add `isSandbox` flag for test-only Pro override.
- `Modus/Resources/StoreKit/Modus.storekit` — update branding (EchoDJ → Modus), ensure product ID matches code.
- `generate-xcodeproj.py` — verify `STOREKIT_CONFIGURATION_URL` is wired into scheme Options so sandbox testing works without Apple ID sign-in.

## 4. Step-by-Step Execution Checklist

All steps are tagged: 🟢 **sim** (simulator-only), 🟡 **sim-degraded** (sim first, device re-verify), 🔴 **device-only** (cannot verify on sim).

---

### 🟢 Sim-Only Parallel Track — UI Polish from Plan 010
*These can run on simulator at any time and do not block device work.*

- [ ] **S1.** SearchView artwork thumbnails — add `AsyncImage` 48×48 thumbnail to each row, placeholder for missing art.
- [ ] **S2.** RadioView artwork shadow + empty-state copy polish.
- [ ] **S3.** `CachedTrack` add `artworkURL: String?` with migration-safe default; `TrackSnapshot` forwards it.
- [ ] **S4.** Verify simulator build after S1–S3; confirm zero warnings.

---

### 🔴 Step 1 — StoreKit Sandbox Alignment (device-verifiable)
- [ ] **1a.** Read current `.storekit` product ID and `SubscriptionManager` product ID; confirm mismatch or stale branding.
- [ ] **1b.** Update `.storekit`: product ID → `com.moduslabs.app.pro.monthly`; localization → "Modus Pro".
- [ ] **1c.** Update `SubscriptionManager` to use the exact same ID; add `isSandbox: Bool` computed from `STOREKIT_CONFIGURATION_URL` presence so test builds can force Pro state.
- [ ] **1d.** Update `generate-xcodeproj.py` to wire `STOREKIT_CONFIGURATION_URL` into the scheme Run action Options (not just build settings).
- [ ] **1e.** 🔴 **Device test:** open paywall, confirm product metadata loads (price, trial) without real Apple ID prompt.

### 🔴 Step 2 — Onboarding View (device-verifiable UI)
- [ ] **2a.** Create `OnboardingView.swift` with: welcome headline ("Welcome to Modus"), subheadline ("Your Apple Music, reimagined as behavioral radio"), primary button ("Connect Apple Music"), secondary button ("Maybe Later — limited radio"), privacy footnote.
- [ ] **2b.** The primary button calls `MusicAuthorization.request()` and awaits the result; on `.authorized`, dismisses onboarding and triggers library import.
- [ ] **2c.** The secondary button dismisses onboarding but keeps `musicAuthStatus` as `.notDetermined`; SearchView shows a "Connect Apple Music to start radio" placeholder instead of the seed list.
- [ ] **2d.** Add `@AppStorage("hasCompletedOnboarding")` gating so onboarding only shows once per install.
- [ ] **2e.** 🔴 **Device test:** cold launch → onboarding appears → tap "Connect Apple Music" → system auth sheet → allow → onboarding dismisses → Search shows real library.

### 🔴 Step 3 — Music Library Importer (device-critical)
- [ ] **3a.** Create `MusicLibraryImporter.swift` actor with `importLibrary() async -> [CachedTrack]`.
- [ ] **3b.** Use `MusicLibraryRequest<Song>` (iOS 26+) to fetch user's library songs; map each to `CachedTrack` with real `song.id.rawValue`, real artwork URL, and placeholder audio features (energy/valence/bpm from random or heuristic until we have real analysis).
- [ ] **3c.** Fallback: if `MusicLibraryRequest` returns empty or errors, use `MPMediaQuery.songs()` for local-device songs and synthesize MusicKit-compatible IDs.
- [ ] **3d.** Persist imported tracks to SwiftData; on subsequent launches, skip import if `CachedTrack` count > 0.
- [ ] **3e.** 🔴 **Device test:** after onboarding auth, SearchView populates with real library songs within 2–3 seconds; tapping a real song starts a station with a real MusicKit ID.

### 🔴 Step 4 — Harden Auth & Playback Error Surfaces (device-critical)
- [ ] **4a.** In `AppleMusicProvider.loadTrack`, check `MusicAuthorization.currentStatus` at entry; if not `.authorized`, throw a new `AppleMusicError.authRequired` with localized description "Apple Music access is required to play this track."
- [ ] **4b.** In `StationQueueManager.generateStation`, if discovery pool is empty after all searches, throw a new `StationError.noAuth` with message "We couldn't reach Apple Music. Please check your connection and Apple Music subscription."
- [ ] **4c.** In `SearchView`, catch `AppleMusicError.authRequired` and `StationError.noAuth` and show specific alerts instead of generic `error.localizedDescription`.
- [ ] **4d.** In `RadioView`, add an `authBanner` view modifier: if auth is `.denied`, show a yellow banner "Apple Music access denied — open Settings to enable"; if `.notDetermined`, show "Connect Apple Music to start radio" with a button.
- [ ] **4e.** 🔴 **Device test:** deny auth during onboarding → SearchView shows auth placeholder → RadioView shows banner → settings re-enable → app detects change on next launch/resume.

### 🟡 Step 5 — Remove Synthetic Seeds on Device (build-only, sim-degraded)
- [ ] **5a.** Wrap `SearchView.seedLibrary` in `#if targetEnvironment(simulator)` / `#else`.
- [ ] **5b.** On device (`#else`), `seedLibrary` returns an empty array; all seeds come from library import or catalog search.
- [ ] **5c.** Simulator path keeps the synthetic list so UI layout tests still work without auth.
- [ ] **5d.** 🟡 **Sim test:** confirm simulator build still shows synthetic seeds; Search rows render correctly.

### 🟡/🔴 Step 6 — Build & Device Verification
- [ ] **6a.** Regenerate `Modus.xcodeproj` via `generate-xcodeproj.py`.
- [ ] **6b.** 🟡 Clean simulator build; confirm zero warnings.
- [ ] **6c.** 🔴 Device build + install; cold launch.
- [ ] **6d.** 🔴 **Device gate checklist:**
  - Onboarding appears on first launch.
  - "Connect Apple Music" triggers system auth sheet.
  - "Allow" → library imports → Search shows real songs.
  - Tap real song → Start Station → Radio plays with artwork.
  - "Deny" → Search shows auth placeholder → Radio shows banner.
  - Paywall shows Modus Pro pricing without real Apple ID sign-in.
  - "Restore Purchases" does not force Apple ID password.

### 🔴 Step 7 — App Store Connect Pre-Work (web UI, not code)
*These are human-in-the-loop tasks in the ASC web portal. They don't block local device testing but are required before TestFlight or App Store submission. Do them in parallel with code work.*

- [ ] **7a.** **Register bundle ID** `com.moduslabs.app` in [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list). App ID type: App; enable **Apple Music** capability; check **CloudKit**, **In-App Purchase**, **Push Notifications**.
- [ ] **7b.** **Create App record** in [App Store Connect](https://appstoreconnect.apple.com) → Apps → "+" → iOS → bundle ID `com.moduslabs.app`. Primary language: English (US). SKU: `modus-v1-2026`.
- [ ] **7c.** **Create subscription product** in ASC → App → Subscription Groups → "+".
  - Group name: `Modus Pro`
  - Product ID: `com.moduslabs.app.pro.monthly`
  - Type: Auto-Renewable Subscription
  - Duration: 1 Month
  - Free Trial: 7 days
  - Price: pick a tier (e.g. $4.99 USD)
  - Localization: display name "Modus Pro", description "Unlock DJ Arc, station memory, and unlimited exploration."
- [ ] **7d.** **Add pricing & territories** — select all territories or a focused launch set; set local prices.
- [ ] **7e.** **Upload AppIcon** (1024×1024 PNG, no alpha) in ASC → App → Media. Also verify `AppIcon.appiconset` in repo has all required sizes for Xcode archive.
- [ ] **7f.** **Create demo Apple Music account** — a fresh Apple ID with an active Apple Music subscription, used *only* for App Review testing. Add credentials to App Review notes in submission.
- [ ] **7g.** **Privacy questionnaire** in ASC → App → Privacy & Data. Fill from `docs/app-store/metadata.md` (already drafted in Plan 009). Declare: no tracking, no advertising ID, data types = none (or only crash logs if using Xcode analytics).

---

## 5. Verification Strategy

| Step | Tag | Verification |
|---|---|---|
| S1–S4 | 🟢 sim | Search rows show thumbnails; RadioView has shadow; build zero warnings. |
| 1 | 🔴 device | `.storekit` ID matches code; paywall shows price on device without real sign-in. |
| 2 | 🔴 device | Onboarding shows once; auth button triggers sheet; dismiss persists via `@AppStorage`. |
| 3 | 🔴 device | Real library songs appear in Search within 3s; have real MusicKit IDs (not "1", "2"…). |
| 4 | 🔴 device | Deny auth → specific error messages; no generic "Station Error" alerts. |
| 5 | 🟡 sim-degraded | Simulator still has synthetic seeds; device does not. |
| 6 | 🔴 device | All device gate items pass on connected iPhone. |
| 7a–g | 🔴 human | ASC web tasks completed; bundle ID registered, app record exists, product created with trial. |

## 6. Risk Register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| `MusicLibraryRequest` is iOS 26-only and requires entitlement | Medium | Can't import library on device | Fallback to `MPMediaQuery` which works without special entitlement. |
| Library import is slow (>5s) for large libraries | Medium | User thinks app is frozen | Add progress indicator in onboarding; cap import to first 200 songs. |
| StoreKit scheme wiring still broken after py changes | Medium | Real sign-in sheet appears | Manually inspect scheme Options tab; add XcodeBuildMCP test. |
| Device build fails from new source files | Low | Can't install | Add new files to `SWIFT_FILES` in `generate-xcodeproj.py`. |
| Sim UI polish (S1–S4) regresses device layout | Low | Device looks broken | Keep sim changes conditional; verify on device at final gate. |

## 8. App Store Metadata Draft (for ASC submission)

**App Name:** Modus: The Behavioral Radio
**Subtitle:** AI DJ that learns how you listen
**Bundle ID:** `com.moduslabs.app`
**SKU:** `modus-v1-2026`

**Description:**
> Modus is not a playlist. It's a behavioral radio station that learns from every skip, every repeat, and every mood shift.
>
> Pick any song from your Apple Music library and Modus builds a live station around it — not with static playlists, but with a real-time AI DJ that shapes the arc of your session. Energy rises when you need momentum. It breathes when you need calm. And when your taste drifts, Modus drifts with you.
>
> **How it works:**
> - Start a station from any song in your library
> - The AI DJ sequences tracks using real-time audio features (energy, valence, tempo)
> - Every skip and full play updates your taste profile
> - Pro subscribers unlock DJ Arc — spoken transitions between tracks and station memory that syncs across devices
>
> **Free Forever:**
> - Unlimited station generation
> - Full Apple Music playback
> - Real-time taste learning
>
> **Modus Pro:**
> - DJ Arc: AI-generated spoken transitions
> - Station Memory: recent stations synced via CloudKit
> - Advanced taste evolution with exploration mode
>
> Requires an active Apple Music subscription. Modus does not play music on its own — it orchestrates your Apple Music library into something personal.
>
> Privacy-first. Your taste profile lives on your device and in your private iCloud. We don't sell data. We don't track you across apps.

**Keywords:** music, radio, dj, apple music, playlist, ai, stations, behavioral radio, mood, discovery

**Support URL:** https://moduslabs.app/support
**Marketing URL:** https://moduslabs.app
**Privacy Policy URL:** https://moduslabs.app/privacy

## 7. Definition of Done

- [ ] **🔴 Device:** build installs on iPhone; onboarding + auth + library import + station start works end-to-end.
- [ ] **🔴 Device:** StoreKit paywall shows product metadata without real Apple ID purchase flow.
- [ ] **🟡 Sim-degraded:** simulator build works with synthetic seeds; zero warnings.
- [ ] **🟢 Sim:** Search artwork thumbnails + RadioView polish render correctly on simulator.
- [ ] No generic "Station Error" alerts — every error has a specific, user-facing message.
- [ ] `ROADMAP.md` updated to reflect onboarding completion and Plan 010 supersession.
- [ ] **🔴 ASC:** bundle ID `com.moduslabs.app` registered with Apple Music + IAP + CloudKit capabilities.
- [ ] **🔴 ASC:** App record created in App Store Connect with bundle ID linked.
- [ ] **🔴 ASC:** Subscription product `com.moduslabs.app.pro.monthly` created with 7-day free trial and pricing.
