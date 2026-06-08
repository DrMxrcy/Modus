# App Store Rejection Playbook — EchoDJ v1

> Created 2026-06-07 during Plan 009 Milestone G.
> The 6 most likely first-rejection reasons for music apps, and the pre-built defense for each. Refer to this file the moment a rejection lands.

---

## 1. MusicKit capability not justified (Guideline 2.3.7)

**What Review says:** "We were unable to locate the music content in your app, or the app did not function as expected. Specifically, the music stopped playing after a short time."

**Why we might get this:** Our app is online-only and depends on a real Apple Music subscriber session in the device's Music app. If Review is signed into a sandbox Apple ID that doesn't have an active Apple Music subscription, every playback request fails.

**Defense (pre-built):**

1. Open the Rejection email, find the reviewer contact.
2. Reply within 24h with:
   > "EchoDJ streams music via the standard Apple Music subscription on the reviewer's device. To verify, please sign in to Settings → [Reviewer Name]'s Apple ID → Media & Purchases → Apple Music using a sandbox Apple ID with an active Apple Music Individual subscription. We've included credentials in the App Review notes section. If the reviewer needs a different test account, please reply and we'll provide one."
3. Attach a 1-2 minute screen recording showing the seed→queue→playback flow working on a developer device with the demo Apple Music account.
4. Reference App Store Review guideline 2.3.7 and Apple's "Testing In-App Purchases" doc.

**Fix for v1.0.1:** Add a clearer "Apple Music subscription required" message at first launch, and surface the error earlier when auth is denied.

---

## 2. Restore Purchases missing (Guideline 3.1.1)

**What Review says:** "We were unable to complete the in-app purchase. Specifically, the restore button was missing or not functioning."

**Why we might get this:** We added Restore Purchases to the paywall sheet, but if Review tests Free → tap badge → Restore button is on a half-loaded paywall (StoreKit products still loading) → no product is visible → button might be off-screen or hit-area changed.

**Defense (pre-built):**

1. Confirm the Restore Purchases button is visible even when products array is empty (it is — see `PaywallSheet` in `RadioView.swift`).
2. Reply:
   > "Restore Purchases is available at the bottom of the Pro paywall, accessible from the tier badge in the Radio tab. It calls `AppStore.sync()` per StoreKit 2 guidance. Please let us know if the button is not visible in your test environment."
3. Attach a screenshot showing the paywall with Restore Purchases button visible.

**Fix for v1.0.1:** Move Restore Purchases to a more discoverable location, like a Settings screen, in addition to the paywall.

---

## 3. Missing privacy manifest (App Store policy since May 2024)

**What Review says:** "Your app is missing a privacy manifest. Apps that use required-reason APIs must include a `PrivacyInfo.xcprivacy` file in the app bundle."

**Why we might get this:** If the build doesn't actually bundle `PrivacyInfo.xcprivacy`, or if the manifest is malformed.

**Defense (pre-built):**

1. Run `unzip -l <built .app> | grep PrivacyInfo` — should show `PrivacyInfo.xcprivacy` in the bundle root.
2. Run `plutil -lint <built .app>/PrivacyInfo.xcprivacy` — should be valid.
3. Reply:
   > "EchoDJ includes `PrivacyInfo.xcprivacy` in the app bundle. We declare `NSPrivacyTracking: false`, no collected data types, and no accessed APIs (we use SwiftData and CloudKit, both of which manage their own disk access and are exempt from the file-timestamp reason)."

**Fix for v1.0.1:** None needed if the file is correctly bundled. If the build setup ever drops the resource, the symptom is the rejection.

---

## 4. Content rights / AI-generated content concern (Guidelines 5.1.1, AI Disclosure)

**What Review says:** "Your app generates content using AI. We are unable to determine that you have the rights to this content. Specifically, the AI-generated DJ transitions may contain copyrighted text."

**Why we might get this:** Live on-device LLM is a relatively new app surface. Review is asking, in good faith, how we know the generated transitions don't contain copyrighted text.

**Defense (pre-built):**

1. Reply:
   > "EchoDJ uses Apple Foundation Models (on-device, iOS 26+) for spoken transitions. The model is Apple's, with Apple's built-in safety stack. We additionally (a) sanitize the prompt to remove markdown fences, (b) clamp the station arc numerics to safe ranges, and (c) sanitize the generated text before TTS synthesis. We do not feed the model any user-provided content (no chat input, no listening history text). The generated content is short transition phrases and is not stored beyond the active session."
2. Provide the AI-Generated Content answers (already in `metadata.md`).
3. Offer the contingency: "If Review prefers, we can ship v1.0.1 with a curated template library of pre-written transitions (no AI), at the cost of reduced personalization."

**Fix for v1.0.1:** If Review strongly pushes back, swap to a template library. Build the library with ~30 pre-written transitions, hand-pick by energy/valence context.

---

## 5. Crash on launch (Guideline 2.1)

**What Review says:** "We were unable to review your app, as it crashed upon launch."

**Why we might get this:** "Content block not found" runtime error is a known unknown (Plan 009 Milestone B). Sim pass did not reproduce, but real device with real MusicKit may.

**Defense (pre-built):**

1. Reply:
   > "We've tested the build on iOS 26.3 simulator (clean) and on our test iPhone (iOS 26.3, signed-in Apple Music subscriber). We were unable to reproduce a crash. The runtime log from our last test session is attached. Could you share the crash log from the review device so we can identify the issue?"
2. Attach the latest `idevicesyslog` capture from the real-device gate run.
3. If Review provides a crash log, run the Xcode crash analyzer and ship a v1.0.1 hotfix.

**Fix for v1.0.1:** TBD based on the actual crash. Likely candidates: MusicKit error path in `AppleMusicProvider.loadTrack`, CloudKit schema migration if any, on-device model init failure.

---

## 6. Misleading subscription copy (Guideline 3.1.2)

**What Review says:** "We were unable to verify your subscription terms. Specifically, the free trial length or price was unclear or inconsistent with App Store Connect."

**Why we might get this:** The paywall copy in `PaywallSheet` and the App Store Connect product configuration must match exactly. The free trial is "1 week" in the `.storekit` config, but the paywall may show different wording.

**Defense (pre-built):**

1. Verify the App Store Connect product has the same 7-day free trial length, the same monthly auto-renew period, and the same price as the paywall.
2. Reply:
   > "EchoDJ's Pro subscription is $4.99/month with a 7-day free trial. The paywall in the app and the App Store Connect product configuration are configured identically. Please let us know if any field is inconsistent."

**Fix for v1.0.1:** Make the paywall copy more explicit ("7-day free trial, then $4.99/month" instead of "Start Free Trial").

---

## General response template

When a rejection lands, the response is always:

1. **Acknowledge:** "Thank you for the feedback. We want to make EchoDJ successful on the App Store."
2. **Investigate:** Run the specific test the reviewer mentions, capture logs, find the issue.
3. **Respond:** Quote the relevant defense from this playbook. Attach evidence (logs, screenshots).
4. **Time-bound:** "We can ship a fix in v1.0.1 within 7 days. Please confirm whether the current v1.0 binary is acceptable or if the v1.0.1 fix is required for approval."
5. **Close:** "Thank you again. We look forward to your reply."

---

## Submission discipline

- **Always include demo Apple Music account** in the App Review notes. This is non-negotiable for music apps.
- **Always have a live support URL** before submission.
- **Always have a live privacy URL** before submission.
- **Always attach screenshots** (at least 6.7", 6.1", 5.5", 12.9" iPad Pro).
- **Never reference "AI" in the app name** — App Store guidelines discourage this.
- **Never say "beta" or "preview"** in the description.

---

## Post-submit monitoring (H7)

- Check App Store Connect daily for 7 days.
- Reply to any rejection within 24h.
- Track all rejection reasons in a `rejection-log.md` (not yet created) for future reference.
