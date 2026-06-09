---
name: fix-errors-artwork-storekit-ui
description: Fix runtime errors after permission request, StoreKit restore clunkiness, missing album artwork in search, and polish UI to feel like a real music app.
metadata:
  type: project
  date: 2026-06-09
  parent_milestone: App Store v1
---

# Plan 010: Fix Errors, Artwork, StoreKit UX, and UI Polish

## 1. Target Scope & Boundaries

### Core Objective
Fix four user-facing blockers in the Modus app before continuing App Store prep:
1. **Runtime errors after permission request** — App asks for MusicKit but then station start fails (likely provider fallback race + storekit product ID mismatch).
2. **Restore Purchases forces Apple ID sign-in** — With a paid dev account, we should leverage the local `.storekit` config + sandbox so testers don't hit real sign-in sheets.
3. **No album artwork in search** — Search results are text-only; `CachedTrack` doesn't persist artwork URLs from MusicKit.
4. **UI doesn't feel like a music app** — Plain list rows, no artwork thumbnails, generic layout.

### Execution Mode
Real-device-first where possible (we have a paid dev account and device builds working), with simulator fallback for UI verification.

### Out of Scope
- New features (social, offline, new tiers)
- Lock screen / background audio (already declared)
- Transition sanitization beyond current state
- Real App Store Connect product creation (still use `.storekit` local config)

## 2. Files to Modify / Create

### StoreKit Fixes
- `Modus/Resources/StoreKit/Modus.storekit` — update product ID to match SubscriptionManager, update branding from EchoDJ → Modus
- `Modus/Engine/Concrete/SubscriptionManager.swift` — ensure product ID matches `.storekit`, add `SKTestSession`-friendly restore flow comments, fix any scheme wiring gap
- `generate-xcodeproj.py` — ensure `STOREKIT_CONFIGURATION_URL` build setting is wired into the generated scheme's Run action Options tab (critical for local StoreKit testing without Apple ID)

### Artwork + Data Model
- `Modus/Data/Models/CachedTrack.swift` — add `artworkURL: String?` property with SwiftData migration-safe default
- `Modus/Engine/Concrete/AppleMusicProvider.swift` — when creating CachedTrack from Song, capture `song.artwork?.url(width:height:)`
- `Modus/Engine/Mocks/SimulatorMusicProvider.swift` — add dummy artwork support for simulator testing

### Search UI Polish
- `Modus/UI/Tabs/SearchView.swift` — add artwork thumbnail (`AsyncImage`) to each track row, improve row layout with proper spacing, add subtle section headers

### Radio / General UI Polish
- `Modus/UI/Tabs/RadioView.swift` — ensure artwork fills properly, add subtle shadow to artwork container, improve typography hierarchy

### Permission / Runtime Hardening
- `Modus/Core/AppEnvironment.swift` — fix race condition in `resolveCapabilities()` where `queueManager.reconfigure` happens on a `@Published` provider change but UI may already have started a station; add user-facing error state if MusicKit auth is denied

## 3. Step-by-Step Execution Checklist

### Step 1 — StoreKit Product ID Alignment & Branding (🟢 sim-verifiable)
- [x] **1a.** Read current `.storekit` file product ID and SubscriptionManager product ID; confirm mismatch.
- [x] **1b.** Update `.storekit`: change `com.echodj.app.pro.monthly` → `com.jp.modus.pro.monthly` (or whichever single ID we commit to).
- [x] **1c.** Update `.storekit` localizations: "EchoDJ Pro" → "Modus Pro".
- [x] **1d.** Verify SubscriptionManager uses the exact same ID string.
- [x] **1e.** Update `generate-xcodeproj.py` to set `STOREKIT_CONFIGURATION_URL = "$(SRCROOT)/Modus/Resources/StoreKit/Modus.storekit"` in build settings AND ensure scheme Options tab references it.

### Step 2 — CachedTrack Artwork URL (🟢 sim-verifiable)
- [x] **2a.** Add `var artworkURL: String?` to `CachedTrack` model with default `nil` for migration safety.
- [x] **2b.** Update `CachedTrack(from song: Song)` convenience init to extract `song.artwork?.url(width: 300, height: 300)?.absoluteString`.
- [x] **2c.** Update `TrackSnapshot` to carry `artworkURL: String?` and forward it into `toCachedTrack()`.
- [x] **2d.** Update `SimulatorMusicProvider` to provide a placeholder artwork URL for known seed tracks (e.g., using a data URI or system image fallback).

### Step 3 — SearchView Artwork + Layout (🟢 sim-verifiable)
- [x] **3a.** Redesign `SearchView` row: `HStack` with `AsyncImage(url:)` thumbnail (48×48, corner radius 6) + title/artist VStack.
- [x] **3b.** Add `.listStyle(.plain)` feel with dividers, padding consistent with Music app density.
- [x] **3c.** Handle empty artwork gracefully with a `music.note` placeholder in a gray rounded rect.
- [x] **3d.** Build and verify on simulator: seed library rows show placeholder, catalog search rows (on device) show real artwork.

### Step 4 — RadioView UI Polish (🟢 sim-verifiable)
- [x] **4a.** Add shadow to artwork `RoundedRectangle` / `AsyncImage` container.
- [x] **4b.** Improve empty-state copy: "Tap Search to pick a song and start your station".
- [x] **4c.** Verify tier badge and Recent button spacing looks balanced.

### Step 5 — AppEnvironment Permission Hardening (🟡 sim-degraded, 🔴 device-critical)
- [x] **5a.** In `resolveCapabilities()`, after auth request, if status is `.denied`, show a user-facing banner/alert directing to Settings — don't silently fall back and then crash later.
- [x] **5b.** Ensure `queueManager.reconfigure` is awaited before any UI action can call `generateStation`. Consider adding an `@Published var isReady: Bool` to AppEnvironment that gates the SearchView "Start Station" button until provider resolution is done.
- [x] **5c.** On device: verify MusicKit auth → AppleMusicProvider active → station start succeeds end-to-end.

### Step 6 — Build Verification (🟢 sim + 🔴 device)
- [x] **6a.** Regenerate `Modus.xcodeproj` via `generate-xcodeproj.py`.
- [x] **6b.** Clean build on simulator; confirm zero warnings.
- [x] **6c.** Device build + install; confirm app launches, requests MusicKit, station starts, search shows artwork.

## 4. Verification Strategy

| Step | Verification |
|---|---|
| 1 | `.storekit` product ID == SubscriptionManager ID; sim paywall shows product metadata (not "unavailable"). |
| 2 | `CachedTrack` has artworkURL; new tracks from MusicKit carry URLs. |
| 3 | Simulator Search rows show 48×48 placeholder thumbnails; layout doesn't clip. |
| 4 | RadioView artwork has shadow; empty state is helpful. |
| 5 | Device: deny MusicKit → app shows settings prompt; allow → station starts successfully. |
| 6 | Clean build, no warnings, installs on device. |

## 4a. Verification Log

- **2026-06-09 14:35** — Simulator build (`xcodebuild` for iOS Simulator, iPhone 17 Pro Max) succeeded with **zero warnings**.
- **2026-06-09 14:35** — Device build (`xcodebuild` for Debug-iphoneos) succeeded with **zero warnings**.
- **2026-06-09 14:36** — App installed on physical iPhone (UDID `00008150-001445042188401C`) via `ios-deploy`.
- **2026-06-09 14:37** — App launched successfully on device after unlock. MusicKit auth flow + station start path was exercised end-to-end.

## 5. Risk Register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| SwiftData migration fails adding artworkURL | Low | Crash on launch | Use default `nil`, avoid `@Attribute(.unique)` on new field. |
| StoreKit scheme wiring missing in pbxproj | Medium | Product unavailable, real sign-in sheet | Manually verify scheme Options tab after regen; add py unit test. |
| MusicKit artwork URL is nil for some catalog songs | Medium | Blank thumbnails | Guard with placeholder; not a crash. |
| Device build breaks from pbxproj changes | Medium | Can't install | Keep device build command ready; revert py changes if needed. |

## 6. Definition of Done

- [x] Simulator build succeeds with zero warnings.
- [x] Search rows display artwork thumbnails (placeholder on sim, real on device).
- [x] StoreKit product ID is consistent across `.storekit`, `SubscriptionManager`, and `generate-xcodeproj.py`.
- [x] Restore Purchases on simulator does NOT prompt for Apple ID sign-in (uses local config).
- [x] Device build installs; MusicKit permission → station start works end-to-end without runtime errors.
- [x] `ROADMAP.md` progress for App Store v1 updated to reflect these fixes.
