---
name: app-store-review-v1
description: Cut a v1 release of EchoDJ for App Store submission — online-only Apple Music radio, one Pro auto-renewable subscription with free trial, Free = full radio no DJ arc, Pro = DJ arc + station memory. Trace the unresolved "Content block not found" runtime error, fix on a real device, harden against guideline 2.x/3.x/5.x/AI-disclosure rejections, and submit.
metadata:
  type: project
  date: 2026-06-07
  parent_milestone: App Store v1
  depends_on_external: [Apple Developer Program enrollment]
  blocks: [Phase 9 Cloud Taste Aggregation, Phase 10 Offline, v1.1 features]
---

# Plan 009: App Store Review v1

## 🎯 1. Target Scope & Boundaries

### Core Objective

Ship a real App Store submission of EchoDJ: an online-only Apple Music radio that monetizes via a single Pro auto-renewable subscription with a 7-day free trial. Free tier gets full radio playback and unlimited station generation; Pro adds DJ arc (live on-device LLM transitions) and station memory (CloudKit-synced track cooldowns + local recent-stations list). Soft paywall via a persistent corner badge — no first-launch gate.

This plan exists to satisfy App Review's hard requirements (no crashes, real IAP, working restore, honest privacy disclosures, appropriate AI-Generated Content answers) and to leave Phase 9 (Cloud Taste Aggregation) and Phase 10 (Offline / MPMediaQuery) as documented v1.1 follow-ups.

### Out of Scope (defer to v1.1+)

- **Offline playback / MPMediaQuery local fallback** (ROADMAP Phase 10). v1 is online-only; copy is honest about it.
- **Cloud Taste Aggregation** (ROADMAP Phase 9).
- **"Surprise Me" / wildcard boost** in production. The exploration epsilon is wired, but we do not ship a user-facing toggle in v1 — keep surface area minimal.
- **Pre-baked transition template library.** v1 ships live `OnDeviceDJBrain`; if Review pushes back, a v1.0.1 hotfix is the contingency.
- **New subscription tiers** (Plus, Family, etc.). One product, one tier.
- **Collaborative taste vectors, social sharing, Navidrome integration.**

## 🏗️ 2. Architectural Blueprint

### Files to Create

- `docs/superpowers/specs/2026-06-07-app-store-v1.md` — human-readable spec for this plan, used for review and onboarding.
- `docs/superpowers/plans/2026-06-07-app-store-v1.md` — sibling plan-mirror file (matches the project's pattern from Phase 8).
- `docs/app-store/metadata.md` — App Store Connect copy drafts: description, keywords, "What's New", privacy nutrition label answers, AI-Generated Content answers, export compliance, age rating rationale, demo Apple Music account instructions, App Review contact.
- `docs/app-store/rejection-playbook.md` — top 6 first-rejection reasons for music apps and the pre-built defenses.
- `EchoDJ/Resources/PrivacyInfo.xcprivacy` — privacy manifest (required since May 2024 for new apps).

### Files to Modify

- `EchoDJ/Resources/Info.plist` — add/verify `NSAppleMusicUsageDescription`, `UIBackgroundModes = [audio]`, `ITSAppUsesNonExemptEncryption = false` (or true+CCATS if we ever add custom crypto).
- `EchoDJ/Engine/Concrete/SubscriptionManager.swift` — replace placeholder product ID with the real App Store Connect product ID, verify `Transaction.updates` listener, surface an explicit "Restore Purchases" entry point.
- `EchoDJ/UI/Tabs/RadioView.swift` — wire "Restore Purchases" affordance, fix `isExplorationPick` placeholder (return `false` is fine for v1; remove the TODO comment), surface a non-crashing empty-state for "no product configured yet" so first launch on a real device doesn't show a stuck "Free" badge with broken Pro flow.
- `EchoDJ/UI/Tabs/SearchView.swift` — verify paywall gating on the Pro-only options; show a clean upgrade sheet (not a silent no-op) when a Free user hits DJ Arc / station memory controls.
- `EchoDJ/Engine/Concrete/TransitionManager.swift` — verify `executeTransition(isEnabled: false)` is a true no-op (no LLM call, no TTS, no logging side-effects). Defensive: confirm on a real device, not just by code review.
- `EchoDJ/Engine/Concrete/OnDeviceDJBrain.swift` — confirm `clamp` and sanitization are present in `generateTransition` and `generateStationArc` outputs; document the safety story in `docs/app-store/metadata.md`.
- `EchoDJ/Engine/Concrete/AppleMusicProvider.swift` — confirm graceful handling of `.denied` and `.notDetermined` MusicKit auth without crashing; surface a user-readable message.
- `ROADMAP.md` — add the new "App Store v1" milestone with progress 0% and a link to this plan.

### Data Model / Schema Changes

- No new `@Model` types. `UserTasteProfile` already exists and is CloudKit-synced; cooldowns and recent stations will use the existing `TrackCooldown` and `CachedTrack` tables. If the recent-stations list needs persistence, add a single new `RecentStation` `@Model` (id, seedTrackID, createdAt, userID-via-CloudKit) — keep it CloudKit-private.

### Downstream Impact

- `TransitionManager` is touched by tier gating changes; if it stops calling the brain when `!isPro`, verify nothing else in the engine depends on the brain output.
- `SubscriptionManager` is touched for the real product ID; verify `activeTier` and `isPro` everywhere downstream still resolve correctly.
- `Info.plist` changes require a clean archive; the xcodeproj doesn't need a regenerate but `project.yml` should mirror any new entries.

## 🚶‍♂️ 3. Step-by-Step Execution Checklist

The plan is broken into 8 sequential milestones, each independently verifiable. Tasks within a milestone are atomic.

### Milestone A — Pre-flight verification (start now)

- [ ] **A1. Verify device readiness for builds** — confirm the connected iPhone is trusted, Developer Mode is on, Xcode sees it, and `xcodebuild -project EchoDJ.xcodeproj -scheme EchoDJ -destination 'platform=iOS,id=<UDID>' build` succeeds with no warnings. *Target: `EchoDJ.xcodeproj`, terminal output in git history.*
- [ ] **A2. Capture the device UDID and the iOS version** — write both to `docs/app-store/device-baseline.md` for use by Review when we reproduce. *Target: new file.*

### Milestone B — Trace the "Content block not found" runtime error (start now)

- [ ] **B1. Reproduce on device, capture log** — `xcodebuild ... build && xcrun devicectl device install app && xcrun devicectl device process launch ...`, then `idevicesyslog` (or Xcode console attached) while exercising the seed→queue→playback flow. Save the full log to `logs/device-baseline.log`. *Target: `logs/`.*
- [ ] **B2. Grep the entire repo for the offending string** — `rg -i "content block"` and `rg "ContentBlock"`. The string is *not* in `StationQueueManager.swift` (verified 2026-06-07) — search likely candidates: system framework wrappers, `print` statements, MusicKit error mapping. *Target: terminal output saved to `logs/content-block-grep.txt`.*
- [ ] **B3. Identify the call site and fix or guard it** — modify the offending code path to either (a) suppress the log, (b) handle the missing block gracefully, or (c) replace the call. Add a regression check (a unit test if the path is testable, or a documented manual reproduction step). *Target: file path TBD from B2.*
- [ ] **B4. Verify the error does not appear on a cold launch + seed flow** — re-run the B1 capture after the fix; diff the log; confirm "Content block not found" is absent. *Target: `logs/post-fix.log`.*

### Milestone C — Real-device smoke test (start now)

- [ ] **C1. MusicKit authorization path** — cold launch → system prompt → accept. Then test .denied path: cold launch → deny → re-launch → confirm app shows a clear "Enable Apple Music access in Settings" surface, not a crash. *Target: `RadioView.swift`, `AppleMusicProvider.swift`.*
- [ ] **C2. Apple Music subscriber present** — play a track, confirm audio output, confirm Now Playing shows up on lock screen.
- [ ] **C3. Lock screen + remote controls** — pause, play, skip from Control Center / lock screen. Confirm `MPNowPlayingInfoCenter.default().nowPlayingInfo` is updated.
- [ ] **C4. Background audio** — start playback, lock the device, wait 30s, confirm playback continues. *Requires `UIBackgroundModes = [audio]` in Info.plist — verify in C5.*
- [ ] **C5. Info.plist audit** — `NSAppleMusicUsageDescription` present and human-readable; `UIBackgroundModes` includes `audio`; no extraneous permissions. *Target: `Info.plist`.*
- [ ] **C6. No-network path** — toggle Wi-Fi off mid-playback, confirm graceful error UI, no crash, no stuck spinner. *Target: `RadioView.swift`.*
- [ ] **C7. Document all C results in `docs/app-store/smoke-test-results.md`** with timestamps and log excerpts.

### Milestone D — Real StoreKit product (queue on Apple Developer Program enrollment)

> **Blocker:** tasks D1, D2, D3 require App Store Connect access, which requires the Apple Developer Program enrollment you have pending.

- [ ] **D1. Create the auto-renewable subscription product in App Store Connect** — product ID `com.echodj.app.pro.monthly` (or your final choice), 7-day free trial, monthly auto-renew, single price tier, all localizations. *Action: in App Store Connect UI, paste the product ID into `docs/app-store/metadata.md` for safekeeping.*
- [ ] **D2. Wire the real product ID into `SubscriptionManager.swift`** — replace the placeholder string. *Target: `SubscriptionManager.swift`.*
- [ ] **D3. Verify on device with a sandbox Apple ID** — sandbox test account buys, trial activates, `SubscriptionManager.activeTier` flips to Pro, DJ arc becomes available in `RadioView`, station memory UI shows Pro-only items. *Target: device + log.*

### Milestone E — Tier enforcement hardening (start now, finalize after D)

- [ ] **E1. Verify `TransitionManager.executeTransition(isEnabled: false)` is a true no-op** — read the code path; on device confirm Free users hear no spoken transition. *Target: `TransitionManager.swift`.*
- [ ] **E2. Verify Pro-only UI controls on Free tier** — Free user taps DJ Arc toggle in `SearchView`'s station options sheet → it must either be disabled with a clear "Pro" badge, or trigger an upgrade sheet, not silently no-op. Defends guideline 3.1.1 (no hidden paywall). *Target: `SearchView.swift`.*
- [ ] **E3. Verify Pro-only "Recent Stations" entry** — on Free, the entry must be visibly locked with the Pro upsell, not absent. *Target: TBD by station memory implementation.*
- [ ] **E4. Add a Restore Purchases button** — surfacing in `SubscriptionManager`'s UI entry point; on tap, calls `AppStore.sync()`. Required by App Review; the absence of an entry point is an automatic 3.1.1 rejection. *Target: `SubscriptionManager.swift`, parent UI.*

### Milestone F — Station memory (Pro tier) — implementation (start now, finalize after D)

- [ ] **F1. Add `RecentStation` SwiftData model** — `id: UUID`, `seedTrackID: String`, `createdAt: Date`. Wire into `AppEnvironment.modelContainer` schema. CloudKit-private. *Target: new file `EchoDJ/Data/Models/RecentStation.swift`.*
- [ ] **F2. Persist on station start** — `StationQueueManager.generateStation` inserts a `RecentStation` for the seed before returning. *Target: `StationQueueManager.swift`.*
- [ ] **F3. CloudKit-synced track cooldown (uses existing `TrackCooldown` model)** — confirm `filterCooldowns` already filters active cooldowns. Extend so cooldowns are written when a track is hard-skipped or played-to-completion. *Target: `StationQueueManager.swift`, `TelemetryCollector.swift`.*
- [ ] **F4. Pro-gated "Recent Stations" UI entry** — visible only when `subscriptionManager.isPro == true`; on Free, show locked placeholder. *Target: `RadioView.swift` or sibling.*

### Milestone G — Info.plist, privacy, AI disclosure (start now)

- [ ] **G1. Create `PrivacyInfo.xcprivacy`** — declare `NSPrivacyAccessedAPITypes` for any `UserDefaults`, file timestamp, or system boot time reads. Truthful; under-declare is a rejection. *Target: new file.*
- [ ] **G2. Draft `docs/app-store/metadata.md`** — description (≤4000 chars), keywords (≤100 chars), "What's New" (≤4000 chars), privacy nutrition label answers, AI-Generated Content answers (v1 ships live `OnDeviceDJBrain` with Foundation Models safety stack + our `clamp`/sanitization; we generate spoken transitions, not audio of copyrighted text; no user-provided content is fed to the model beyond seed metadata), export compliance (`ITSAppUsesNonExemptEncryption = false`), age rating answers, demo Apple Music account credentials, App Review contact email. *Target: new file.*
- [ ] **G3. Draft `docs/app-store/rejection-playbook.md`** — top 6 rejection reasons for music apps (MusicKit capability not justified, restore purchases broken, missing privacy manifest, content rights on AI output, crash on launch, misleading subscription copy) and the defense for each. *Target: new file.*

### Milestone H — Build, submit, defend (queue on enrollment)

- [ ] **H1. Final code signing** — generate Distribution certificate and provisioning profile in App Store Connect / Xcode. Set `DEVELOPMENT_TEAM` in `project.yml`. *Target: `project.yml`.*
- [ ] **H2. AppIcon + launch screen** — verify all required sizes present; add a launch screen if missing. *Target: `EchoDJ/Resources/Assets.xcassets`.*
- [ ] **H3. Archive** — `xcodebuild -project EchoDJ.xcodeproj -scheme EchoDJ -configuration Release archive`. Verify the archive is clean (no warnings, no missing required icons, no entitlements gaps).
- [ ] **H4. Validate** — `xcrun altool --validate-app` or Xcode Organizer's "Validate App" before upload. Address every warning.
- [ ] **H5. Upload to App Store Connect** — `xcrun altool --upload-app` or Xcode Organizer's "Distribute App" → App Store Connect.
- [ ] **H6. Submit for review** — fill in the metadata from G2 in App Store Connect UI; answer all required questions; attach a demo Apple Music account. Submit.
- [ ] **H7. Monitor and respond** — check daily for 7 days. If rejected, refer to `rejection-playbook.md` and respond within 24h with the prebuilt defense.

## 4. Architectural & Behavioral Notes

### 4.1 "Content block not found" hypothesis

Verified on 2026-06-07 that the string is **not** in `EchoDJ/Engine/Concrete/StationQueueManager.swift` (the only place that produces "Content" or "block" in our code is `print` statements with `for track in tracks`). The most likely origins, in order of probability:

1. **MusicKit framework log noise** — `MusicCatalogSearchRequest.response()` can emit this when its inner deserialization hits a missing content block. A user-facing error should be surfaced, but the log itself is harmless.
2. **`print` in `AppleMusicProvider`** — not yet read; could be a debug print of a `Song` field that's missing in the sandbox.
3. **`print` in `OnDeviceDJBrain`** — Foundation Models occasionally logs "content block" when generation produces a partial response. We've already added `clamp` and sanitization; the log itself is just noise.

The fix is **not** a code change; it's either (a) suppress the log, (b) demote to `os_log` debug, or (c) add a graceful "Apple Music did not return full metadata — try another seed" UI when the partial result actually impacts the user. Decide based on B2's grep results.

### 4.2 Paywall surface area

Confirmed in `EchoDJ/UI/Tabs/RadioView.swift` that the only Pro indicator is a corner badge (line 36–42). No first-launch gate. Pro gating on the actual feature (`transitionManager.executeTransition(isEnabled: isPro)`) is wired at the call site in `hardSkip` and `softSkip` (lines 137, 148). This is correct soft-paywall posture.

`SearchView`'s station options sheet still needs verification (E2) — that the Free user cannot silently toggle DJ Arc.

### 4.3 SubscriptionManager current state

Not read in this pass. Must be read in D2 to confirm the `activeTier == .freeTier` default for a fresh install (which is what causes the always-"Free" badge today), and to confirm `Transaction.updates` is set up before the paywall can be presented.

### 4.4 Privacy posture

We use CloudKit (private DB only) for taste profile, cooldowns, recent stations. We do not use CloudKit public DB in v1. We do not collect advertising identifiers. We do not use third-party SDKs. We do use Apple frameworks (MusicKit, StoreKit, CloudKit, FoundationModels, SwiftData, AVFoundation). The privacy "nutrition label" should reflect this truthfully.

### 4.5 AI-Generated Content disclosure

v1 ships live `OnDeviceDJBrain` for spoken transitions and `StationArcTarget` generation. The model is Apple's `FoundationModels` on-device, which has its own safety stack. We further:

- Strip markdown fences from prompt responses.
- Clamp `targetEnergy`, `targetValence`, `targetBPM` to safe ranges in `StationArcTarget`.
- Sanitize transition text in `OnDeviceDJBrain` (verify in E1).

We do **not** feed user-provided content (no chat input, no listening history text). We do **not** generate audio of copyrighted text. The generated content is short transition phrases, used once, and not stored beyond the active session.

If Review pushes back hard, the v1.0.1 contingency is a curated template library (see brainstorm).

## 5. Verification Strategy (per-task)

Every task in section 3 ends with a verifiable artifact. Summary:

| Milestone | Verification |
|---|---|
| A | Clean device build, no warnings. UDID + iOS version in `device-baseline.md`. |
| B | "Content block not found" absent from `post-fix.log`. |
| C | All 6 scenarios documented in `smoke-test-results.md` with log excerpts. |
| D | Sandbox Apple ID buys, trial activates, Pro flows unlock. |
| E | Free user cannot trigger DJ arc or station memory. Restore Purchases works. |
| F | RecentStation persisted; CloudKit syncs across two test devices. |
| G | `PrivacyInfo.xcprivacy` validates; `metadata.md` covers all required answers. |
| H | Clean archive, valid build, submitted, not rejected on first review (or rejection defended successfully). |

## 6. Risk Register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Developer Program enrollment takes >48h | Medium | Schedule slip | Start milestones A–C, F, G in parallel. Only D and H need enrollment. |
| Review rejects the live LLM as unsafe | Medium | Reject; lose 24h | Have a v1.0.1 hotfix plan ready: swap to curated template library, no LLM at all. |
| StoreKit 2 + iOS 26 has a new quirk | Low | Build/buy broken | Test on sandbox account before submit; verify with `xcodebuild test`. |
| "Content block not found" turns out to be a real crash | Low | Reject for crash on launch | B-milestone runs before any submit attempt. |
| Privacy manifest misses an `NSPrivacyAccessedAPIType` | Medium | Reject | Use the `privacy-info` lint or Apple's `xcprivacy` validator before submit. |
| Apple Music subscriber not present on the review device | Low | Reject (can't test primary function) | Provide a demo Apple Music account in the submission notes. |
| CloudKit-sync issue in v1 affects reviewers | Low | Data loss on reviewer's test | We are submitting before any real users; risk is theoretical. |

## 7. Rollout & Communication

- **No public test flight in v1.** Review goes directly from sandbox testing to App Store.
- **Local git-only.** All commits stay on `main` locally per CLAUDE.md Git Boundaries. No pushes.
- **v1.1 backlog** is captured in `docs/app-store/rejection-playbook.md` and inline in the v1 cut notes.

## 8. Documentation Deliverables (created during this plan)

| File | Purpose |
|---|---|
| `docs/superpowers/specs/2026-06-07-app-store-v1.md` | Human-readable spec, mirrors plan for onboarding |
| `docs/superpowers/plans/2026-06-07-app-store-v1.md` | Sibling plan-mirror (project pattern) |
| `docs/app-store/metadata.md` | App Store Connect copy drafts |
| `docs/app-store/rejection-playbook.md` | Top-6 rejection defenses |
| `docs/app-store/device-baseline.md` | Device UDID, iOS version, build settings snapshot |
| `docs/app-store/smoke-test-results.md` | Milestone C results with log excerpts |
| `logs/device-baseline.log`, `logs/post-fix.log`, `logs/content-block-grep.txt` | Evidence for milestones A and B |

## 9. Out-of-Scope Confirmation (deferred to v1.1)

The following are explicitly **not** in v1 and are documented here so the next brainstorm starts from a clean baseline:

- Offline playback / `MPMediaQuery` local fallback (ROADMAP Phase 10)
- "Surprise Me" user-facing toggle (epsilon decay is wired, but no UI in v1)
- Cloud Taste Aggregation (ROADMAP Phase 9)
- Collaborative taste vectors, social sharing, Navidrome integration
- Family Sharing, Plus tier, Family tier
- Mac Catalyst / iPad split-view
- Localization beyond `en-US` (single locale in v1)

## 10. Definition of Done

This plan is **done** when:

1. All 8 milestones are checked off in section 3.
2. The app is **submitted** to App Store Review (does not need to be approved; that's v1's first day).
3. `ROADMAP.md` shows "App Store v1: 100% — Submitted YYYY-MM-DD" and links to this plan.
4. A short retrospective note is added to `docs/app-store/rejection-playbook.md` after the first review outcome.
