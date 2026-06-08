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

### Execution Mode: Simulator-First (real device paused)

All implementation and most verification runs in the iOS 26 simulator until the connected iPhone is unblocked for real-device smoke tests. Each task in section 3 is tagged with one of:

- 🟢 **sim** — fully verifiable on simulator, no real device needed.
- 🟡 **sim-degraded** — partially verifiable on simulator; flagged gaps are documented and re-tested on a real device before submit.
- 🔴 **device-only** — cannot be verified on simulator. Task is staged but the verification step is deferred to a "real-device gate" run before H6 submit.

**Real-device gate (before H6 submit):** MusicKit auth + actual playback + Apple Music subscriber path, lock screen + remote controls, background audio, sandbox StoreKit purchase, CloudKit cross-device sync, real `idevicesyslog` capture of the post-fix runtime.

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

The plan is broken into 8 sequential milestones, each independently verifiable. Tasks within a milestone are atomic. Each task is tagged with the simulator mode from section 1: 🟢 sim, 🟡 sim-degraded, 🔴 device-only. A final "real-device gate" run before H6 re-verifies every 🟡 and 🔴 task.

### Milestone A — Pre-flight verification (start now, sim)

- [ ] **A1. Verify simulator build** 🟢 — boot the iOS 26 simulator (`xcrun simctl list devices available | grep iOS-26`), then `xcodebuild -project EchoDJ.xcodeproj -scheme EchoDJ -destination 'platform=iOS Simulator,id=<sim-UDID>' build` succeeds with no warnings. *Target: `EchoDJ.xcodeproj`, terminal output in git history.*
- [ ] **A2. Capture simulator UDID and iOS version** 🟢 — write both to `docs/app-store/device-baseline.md` for use by Review when we reproduce. *Target: new file.*

### Milestone B — Trace the "Content block not found" runtime error (start now, mostly 🔴 device-only)

> **Status (2026-06-07 sim pass):** B1, B2, B4 on simulator completed. The string does **not** appear in a clean cold-launch + sim flow through `SimulatorMusicProvider`. The string is **not in our repo** (B2 grep returned zero matches across the entire codebase). The error is almost certainly produced by `MusicKit`'s `MusicCatalogSearchRequest.response()` deserialization path on a real device with a real subscriber — sim has no real catalog data, so the deserialization path that emits the log is not exercised. Repro is 🔴 device-only.
>
> **Files saved as evidence (sim side):**
> - `logs/content-block-grep.txt` — repo-wide grep result: 0 matches.
> - `logs/sim-baseline.log` — cold-launch runtime log (5 lines, no error).
> - `logs/sim-baseline-oslog.log` — oslog stream from the same launch.
> - `docs/app-store/device-baseline.md` — sim UDID + iOS version for the real-device gate.

- [x] **B1. Reproduce in simulator, capture log** 🟢 sim (no error reproduced, sim is not the source). *Target: `logs/sim-baseline.log` — DONE.*
- [x] **B2. Grep the entire repo for the offending string** 🟢 sim — `rg -i "content block"`, `rg "ContentBlock"`, `rg -i "block not found"`: **0 matches**. The string is not produced by our code. *Target: `logs/content-block-grep.txt` — DONE.*
- [ ] **B3. Identify the call site and add a guard or suppression** 🔴 device-only — likely origin: `MusicCatalogSearchRequest.response()` in `AppleMusicProvider.loadTrack` and `StationQueueManager.fetchSimilarArtistTracks` / `fetchGenreSearchTracks` / `fetchBroaderSearchTracks`. Decision (deferred to device gate): (a) wrap the calls in `do/try/catch` and swallow + log at debug; (b) replace `print` calls in the discovery path with `os_log(.debug, ...)`; (c) add a user-facing "Apple Music returned partial metadata — try another seed" UI if the partial result actually impacts the user. *Target: file paths above.*
- [ ] **B4. Verify the error does not appear on a cold launch + seed flow** 🔴 device-only — re-run B1 on a real device after B3; diff the log; confirm "Content block not found" is absent. *Target: device-only log file in `logs/post-fix-device.log`.*

### Milestone C — Smoke test (split: most 🟡 sim-degraded, one 🔴 device-only, one 🟢 Info.plist)

- [ ] **C1. MusicKit authorization denied path** 🟡 sim-degraded — boot the simulator, deny MusicKit in the system prompt, relaunch the app, confirm a clean "Enable Apple Music access in Settings" surface, no crash. Real-device MusicKit auth UI is identical, so sim is a faithful test of the denied path; only the actual playback path needs real device. *Target: `RadioView.swift`, `AppleMusicProvider.swift`.*
- [ ] **C2. Real playback + Now Playing on lock screen** 🔴 device-only — playback requires a real Apple Music subscriber; lock screen Now Playing requires real device. Skip on simulator; queue for the real-device gate before H6. *Target: `MPNowPlayingInfoCenter` usage in `AppleMusicProvider.swift`.*
- [ ] **C3. Lock screen + remote controls** 🔴 device-only — skip on simulator; queue for the real-device gate. *Target: same as C2.*
- [ ] **C4. Background audio** 🔴 device-only — skip on simulator; queue for the real-device gate. Confirm `UIBackgroundModes` in C5 is correct in advance. *Target: same as C2.*
- [ ] **C5. Info.plist audit** 🟢 sim — `NSAppleMusicUsageDescription` present and human-readable; `UIBackgroundModes` includes `audio`; no extraneous permissions. *Target: `Info.plist`.*
- [ ] **C6. No-network path** 🟡 sim-degraded — toggle simulator's network off mid-flow, confirm graceful error UI, no crash, no stuck spinner. Sim is faithful for this; flagged for real-device re-verification. *Target: `RadioView.swift`.*
- [ ] **C7. Document all C results in `docs/app-store/smoke-test-results.md`** 🟢 sim — note which items are 🟡 (sim-verified) and which are 🔴 (deferred to real-device gate).

### Milestone D — StoreKit product (split: 🟢 sim-config now, 🔴 real product after enrollment)

> **Blocker:** D3 and D4 require App Store Connect access (real product creation + real product ID), which requires Apple Developer Program enrollment. D1 and D2 are doable on simulator *today* using a `.storekit` configuration file so the rest of the app can be exercised end-to-end.

- [x] **D1. Create a `.storekit` configuration file** 🟢 sim — `EchoDJ/Resources/StoreKit/EchoDJ.storekit` with one auto-renewable subscription, product ID `com.echodj.app.pro.monthly`, 7-day free trial. Wired into the build via `STOREKIT_CONFIGURATION_URL` in `generate-xcodeproj.py` and the pbxproj Resources phase. *Target: new file + `project.yml` — DONE 2026-06-07. See `docs/app-store/storekit-config.md`.*
- [x] **D2. Verify StoreKit pipeline on simulator** 🟢 sim — `Product.SubscriptionInfo.status(for: "premium_monthly_group")` is invoked at launch (`(StoreKit) StoreKit/SubscriptionStatusQuery` in `logs/sim-storekit-baseline.log`); no error; `activeTier` correctly falls back to `freeTier` because no purchase exists. Pro-flip verification requires `Product.purchase()` to be callable from the app, which is E-scope (purchase UI). *Target: sim + log — DONE 2026-06-07.*
- [ ] **D3. Create the real auto-renewable subscription product in App Store Connect** 🔴 device-only — product ID `com.echodj.app.pro.monthly`, 7-day free trial, monthly auto-renew, single price tier, all localizations. Paste the product ID into `docs/app-store/metadata.md` for safekeeping. *Action: in App Store Connect UI.*
- [ ] **D4. Wire the real product ID into `SubscriptionManager.swift`** 🔴 device-only — replace the `.storekit` placeholder with the real product ID. *Target: `SubscriptionManager.swift`.*
- [ ] **D5. Verify on a real device with a sandbox Apple ID** 🔴 device-only — sandbox test account buys, trial activates, `SubscriptionManager.activeTier` flips to Pro, DJ arc becomes available, station memory UI shows Pro-only items. *Target: device + log.*

### Milestone E — Tier enforcement hardening (start now, mostly 🟢 sim, with 🟡 no-network pieces)

- [ ] **E1. Verify `TransitionManager.executeTransition(isEnabled: false)` is a true no-op** 🟢 sim — read the code path; on simulator confirm Free users produce no spoken transition. *Target: `TransitionManager.swift`.*
- [ ] **E2. Verify Pro-only UI controls on Free tier** 🟢 sim — Free user taps DJ Arc toggle in `SearchView`'s station options sheet → it must either be disabled with a clear "Pro" badge, or trigger an upgrade sheet, not silently no-op. Defends guideline 3.1.1 (no hidden paywall). Verifiable on simulator via the `.storekit` config with no purchase. *Target: `SearchView.swift`.*
- [ ] **E3. Verify Pro-only "Recent Stations" entry** 🟢 sim — on Free, the entry must be visibly locked with the Pro upsell, not absent. Verifiable on simulator. *Target: TBD by F4 implementation.*
- [ ] **E4. Add a Restore Purchases button** 🟢 sim — surfacing in `SubscriptionManager`'s UI entry point; on tap, calls `AppStore.sync()`. Required by App Review; the absence of an entry point is an automatic 3.1.1 rejection. *Target: `SubscriptionManager.swift`, parent UI.*

### Milestone F — Station memory (Pro tier) — implementation (start now, mostly 🟢 sim, one 🟡 CloudKit cross-device)

- [ ] **F1. Add `RecentStation` SwiftData model** 🟢 sim — `id: UUID`, `seedTrackID: String`, `createdAt: Date`. Wire into `AppEnvironment.modelContainer` schema. CloudKit-private. *Target: new file `EchoDJ/Data/Models/RecentStation.swift`.*
- [ ] **F2. Persist on station start** 🟢 sim — `StationQueueManager.generateStation` inserts a `RecentStation` for the seed before returning. *Target: `StationQueueManager.swift`.*
- [ ] **F3. CloudKit-synced track cooldown (uses existing `TrackCooldown` model)** 🟢 sim — confirm `filterCooldowns` already filters active cooldowns. Extend so cooldowns are written when a track is hard-skipped or played-to-completion. *Target: `StationQueueManager.swift`, `TelemetryCollector.swift`.*
- [ ] **F4. Pro-gated "Recent Stations" UI entry** 🟢 sim — visible only when `subscriptionManager.isPro == true`; on Free, show locked placeholder. *Target: `RadioView.swift` or sibling.*
- [ ] **F5. Verify CloudKit cross-device sync** 🟡 sim-degraded — requires two real devices (or one device + simulator) signed into the same iCloud. The schema and code path are verifiable on simulator with a single iCloud account; **true cross-device** verification is a real-device gate. Document the limitation in `smoke-test-results.md`. *Target: `AppEnvironment.swift`, CloudKit dashboard.*

### Milestone G — Info.plist, privacy, AI disclosure (start now, all 🟢 sim — docs only)

- [ ] **G1. Create `PrivacyInfo.xcprivacy`** 🟢 sim — declare `NSPrivacyAccessedAPITypes` for any `UserDefaults`, file timestamp, or system boot time reads. Truthful; under-declare is a rejection. *Target: new file.*
- [ ] **G2. Draft `docs/app-store/metadata.md`** 🟢 sim — description (≤4000 chars), keywords (≤100 chars), "What's New" (≤4000 chars), privacy nutrition label answers, AI-Generated Content answers (v1 ships live `OnDeviceDJBrain` with Foundation Models safety stack + our `clamp`/sanitization; we generate spoken transitions, not audio of copyrighted text; no user-provided content is fed to the model beyond seed metadata), export compliance (`ITSAppUsesNonExemptEncryption = false`), age rating answers, demo Apple Music account credentials, App Review contact email. *Target: new file.*
- [ ] **G3. Draft `docs/app-store/rejection-playbook.md`** 🟢 sim — top 6 rejection reasons for music apps (MusicKit capability not justified, restore purchases broken, missing privacy manifest, content rights on AI output, crash on launch, misleading subscription copy) and the defense for each. *Target: new file.*

### Milestone H — Build, submit, defend (queue on enrollment; archive is 🟢 sim)

- [ ] **H1. Final code signing** 🔴 device-only — generate Distribution certificate and provisioning profile in App Store Connect / Xcode. Set `DEVELOPMENT_TEAM` in `project.yml`. *Target: `project.yml`.*
- [ ] **H2. AppIcon + launch screen** 🟢 sim — verify all required sizes present; add a launch screen if missing. *Target: `EchoDJ/Resources/Assets.xcassets`.*
- [ ] **H3. Archive (sim build dry-run)** 🟢 sim — `xcodebuild -project EchoDJ.xcodeproj -scheme EchoDJ -configuration Release archive -destination 'generic/platform=iOS Simulator'`. Verify the archive is clean (no warnings, no missing required icons, no entitlements gaps) for the simulator slice. *Target: derived data.*
- [ ] **H4. Validate** 🔴 device-only — `xcrun altool --validate-app` against the device archive. Address every warning. *Target: App Store Connect.*
- [ ] **H5. Upload to App Store Connect** 🔴 device-only — `xcrun altool --upload-app` or Xcode Organizer's "Distribute App" → App Store Connect. *Target: App Store Connect.*
- [ ] **H6. Submit for review** 🔴 device-only — fill in the metadata from G2 in App Store Connect UI; answer all required questions; attach a demo Apple Music account. Submit. **Pre-submit gate:** the real-device gate from C2/C3/C4/C6/D5/F5 must be re-verified on a real device before this step. *Target: App Store Connect.*
- [ ] **H7. Monitor and respond** 🔴 device-only — check daily for 7 days. If rejected, refer to `rejection-playbook.md` and respond within 24h with the prebuilt defense.

## 4. Architectural & Behavioral Notes

### 4.1 "Content block not found" — updated hypothesis after sim pass (2026-06-07)

**Confirmed:** the string is **not in our repo** (full repo grep returned 0 matches for `content block`, `ContentBlock`, and `block not found`). It is also **not emitted during a clean cold launch on the iOS 26.3 simulator** (sim baseline log shows only the 5 expected framework init lines: SwiftData init, `LanguageModelSession initialized`, "AppleMusicProvider not authorized", "LanguageModelSession initialized", "OnDeviceDJBrain active"). The sim does not exercise the real `MusicCatalogSearchRequest.response()` deserialization path because it has no real catalog data.

**Strongest hypothesis:** the log is emitted by `MusicKit`'s internal deserialization when a real `MusicCatalogSearchRequest` returns a partial response on a real device with a real Apple Music subscriber. It is a framework log, not a user-facing error. The fix is **not** a code change in our app — it's either (a) ignore the log (it's framework noise), or (b) wrap the call sites in `try/await` with explicit error handling and a graceful user fallback when the search returns partial results.

**Decision deferred to the real-device gate:** the call sites to guard (if any) are `AppleMusicProvider.loadTrack` and the three `fetch*Tracks` helpers in `StationQueueManager` (lines 224, 249, 273). All of them use `try? await request.response()` and silently drop errors today — that may be exactly the path that produces the "Content block not found" log. We won't know until we see it on a real device.

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

Every task in section 3 ends with a verifiable artifact, with the sim/device mode from section 1.

| Milestone | Verification |
|---|---|
| A | Clean sim build, no warnings. Sim UDID + iOS version in `device-baseline.md`. 🟢 |
| B | "Content block not found" absent from `post-fix.log` after sim repro. 🟢 |
| C | Denied-auth + no-network paths documented as 🟡 sim-verified. Real playback, lock screen, background audio deferred to real-device gate. 🟡/🔴 |
| D | `.storekit` config wired + sim-verified for product resolve / trial / tier flip. 🟢. Real product + sandbox Apple ID deferred to real-device gate. 🔴 |
| E | Free tier on sim cannot trigger DJ arc, no silent fallbacks, Restore Purchases works. 🟢 |
| F | RecentStation persisted locally on sim. Cross-device CloudKit sync deferred to real-device gate. 🟢/🟡 |
| G | `PrivacyInfo.xcprivacy` validates; `metadata.md` covers all required answers. 🟢 |
| H | Clean sim archive. Real-device gate re-runs C2/C3/C4/C6/D5/F5. Code signing, upload, submit, monitor all 🔴. |

**Real-device gate (single, before H6):** a focused run on the connected iPhone that re-verifies every 🟡 and 🔴 task, captures `idevicesyslog` for the MusicKit auth + playback + lock screen + background audio flow, and produces a one-line "all clear" entry in `smoke-test-results.md`. If any item fails on device, halt H6 until fixed.

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

1. All 8 milestones are checked off in section 3, **and** every 🟡 and 🔴 task has been re-verified on a real device in the single "real-device gate" run before H6.
2. The app is **submitted** to App Store Review (does not need to be approved; that's v1's first day).
3. `ROADMAP.md` shows "App Store v1: 100% — Submitted YYYY-MM-DD" and links to this plan.
4. A short retrospective note is added to `docs/app-store/rejection-playbook.md` after the first review outcome.
