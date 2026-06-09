# App Store Connect Metadata — EchoDJ v1

> Created 2026-06-07 during Plan 009 Milestone G. Paste into App Store Connect when enrollment is complete.
> Character limits: subtitle ≤30, promotional text ≤170, description ≤4000, keywords ≤100, "What's New" ≤4000.

## App name

**EchoDJ** (24 chars, fits standard 30-char app name field)

## Subtitle (≤30 chars)

**AI-Powered Radio Stations** (28 chars)

## Promotional text (≤170 chars, editable any time)

> Your personal radio, powered by Apple Music and an on-device DJ. Free for everyone — Pro unlocks DJ Arc and station memory. 7-day free trial.

## Description (≤4000 chars)

> **EchoDJ turns your favorite songs into AI-curated radio stations that feel handpicked by a real DJ.**
>
> Start with any track in Apple Music, and EchoDJ builds a station around it — pulling from related artists, genre stations, and curated playlists — then ranking every candidate with an on-device vector engine that learns your taste as you listen. Skip what you don't like. Hear what you didn't know you wanted.
>
> **Free for everyone.** Play unlimited stations, skip freely, build your taste profile. No ads, no tracking.
>
> **EchoDJ Pro — 7-day free trial, then $4.99/month.**
> - **DJ Arc:** the on-device Apple Foundation Model writes short spoken transitions between tracks, so the station feels like a real DJ set instead of a shuffled playlist.
> - **Station Memory:** Pro remembers your last stations and syncs them across your devices via iCloud, so you can jump back to a vibe any time.
>
> **Built on Apple platforms.**
> - Apple Music (MusicKit) for the entire library and streaming.
> - StoreKit 2 for the Pro subscription. Restore Purchases is one tap.
> - CloudKit (private database) to sync your taste profile and recent stations across your devices.
> - Foundation Models (on-device) for DJ Arc. No audio ever leaves your phone.
>
> **Privacy by design.** EchoDJ does not collect personal data, does not use advertising identifiers, and does not track you across other apps. Your taste profile and station memory live in your private iCloud database — only you can read them.
>
> **Online-only for v1.** EchoDJ streams music through Apple Music, so a network connection is required. Offline support and on-device library playback are coming in a future update.

## Keywords (≤100 chars)

> ai radio,apple music,dj,stations,mood,music discovery,favorites,mixes

(96 chars)

## What's New (≤4000 chars)

> **Welcome to EchoDJ v1.0.**
>
> This is the first public release. We're starting simple and listening to your feedback.
>
> - **Radio tab:** your live station. Album art, title, artist, progress, play/pause, hard and soft skip, "Next Up" preview.
> - **Search tab:** start a station from any cached track. Pick your discovery vibe and start listening.
> - **Soft paywall:** Free for everyone, Pro upgrades a few controls in place — no first-launch gate, no interruption.
> - **DJ Arc (Pro):** spoken transitions generated on-device by Apple Foundation Models.
> - **Station Memory (Pro):** your last 20 stations, synced via iCloud.
> - **Restore Purchases:** one tap in the paywall.
>
> Known limitations for v1 (we'll fix these in v1.1):
> - Requires a network connection (offline support coming).
> - Subscriptions are monthly only; annual is on the roadmap.
>
> Thanks for trying EchoDJ. Tell us what you think at support@echodj.app.

## Support URL

`https://echodj.app/support`

> **Action before submission:** Replace with a live page (e.g., a hosted help doc or a mailto link). Reviewers may click this.

## Marketing URL (optional)

`https://echodj.app`

> **Action before submission:** Replace with a live marketing site or landing page. Optional but recommended.

## Privacy URL

`https://echodj.app/privacy`

> **Action before submission:** Must be a live, publicly accessible privacy policy before the app can pass review. Minimum: data collection, retention, and contact practices.

## Privacy "Nutrition Label" — App Store Connect answers

### Data Not Collected

- **Contact Info** — None
- **Financial Info** — None
- **Health & Fitness** — None
- **Location** — None
- **Sensitive Info** — None
- **Contacts** — None
- **User Content** — None
- **Browsing History** — None
- **Search History** — None
- **Identifiers** — None (no advertising ID, no device fingerprinting)
- **Usage Data** — **Product Interaction** — yes, but **not linked to the user's identity** and **not used for tracking**. Stored locally and in the user's private iCloud database.
- **Purchases** — **Purchase History** — yes, but **not linked to the user's identity** and **not used for tracking**. Apple manages subscription status via StoreKit 2; we do not see or store the user's Apple ID.
- **Diagnostics** — **Crash Data** + **Performance Data** — none collected by us. (We may add Apple-supplied crash analytics in a future build; this label will be updated.)
- **Other Data** — **Apple Music library access** is requested at runtime via MusicKit authorization. We see the user's library-read status (authorized/denied) and may cache track metadata. We do not upload the library anywhere.

### Data Not Used to Track

All categories above are "not used to track" by default.

### Privacy Practices

- **Data is not linked to the user's identity.** All persisted data is in the user's private iCloud database, scoped to the user's iCloud account, and not associated with any EchoDJ account (we have no account system in v1).
- **Data is not used for tracking.** We do not use IDFA, Fingerprinting, or any cross-app tracking.
- **The app does not contain ads.** No ad SDKs.

## AI-Generated Content Disclosure (App Store Connect, 2024+ section)

Answer all three questions:

1. **Does your app use AI-generated content?** — Yes.
2. **What kind of AI-generated content?** — Spoken text (DJ transitions) and a numeric "station arc" (energy/valence/BPM over queue position).
3. **Does the user have a way to report concerns about the AI-generated content?** — Yes. Email `support@echodj.app`. Reported content is reviewed and the prompt is tightened.

Additional context to provide to Review (in the App Review notes field):

> EchoDJ uses Apple Foundation Models (on-device, iOS 26+) to generate short spoken transitions between tracks. Generation is gated behind the Pro subscription and runs entirely on-device; no user content, listening history text, or track metadata is sent to any cloud service for AI inference.
>
> The on-device model has Apple's built-in safety stack. We additionally:
> - Strip markdown fences from prompt responses.
> - Clamp generated energy/valence/BPM to safe ranges.
> - Sanitize generated transition text before passing to speech synthesis.
>
> We do not generate audio of copyrighted text. The generated content is short transition phrases that are not stored beyond the active session.
>
> v1 ships live on-device generation. If Review flags this, our contingency is a curated template library of pre-written transitions (no AI) for a v1.0.1 hotfix — no model dependency.

## Export Compliance (`ITSAppUsesNonExemptEncryption`)

- `ITSAppUsesNonExemptEncryption` set to `false` in Info.plist.
- Answer in App Store Connect: "No, my app only uses standard encryption available in iOS." EchoDJ does not use any custom cryptographic algorithms. HTTPS for network is provided by the OS.

## Age Rating Questionnaire

- **Unrestricted Web Access:** No (EchoDJ does not contain a browser).
- **User-Generated Content:** No (search results are local cache; the user does not post content in v1).
- **Real-Time Location:** No.
- **Mild / Frequent / Intense:** Cartoon or Fantasy Violence — None; Realistic Violence — None; Sexual Content or Nudity — None; Profanity or Crude Humor — None; Mature / Suggestive Themes — **None**; Horror / Fear Themes — None; Simulated Gambling — None.
- **Conclusion:** **4+** (no objectionable content).

## Demo Apple Music Account (for Review)

Required when the app's primary function requires a paid Apple Music subscription. Provide:

- **Apple ID:** `review@echodj.app`
- **Password:** provide via App Review's secure portal, not in this file
- **Subscription status:** Apple Music Individual, active during review period

> **Action before submission:** Create a dedicated Apple ID for Review (or use your own). Change the email above to the actual account. Ensure the account has an active Apple Music subscription during the review period.

> The reviewer will be asked to sign in on the device, then start a station. They should be able to see Free + Pro flow.

## App Review Contact

- **First name:** (your name)
- **Last name:** (your name)
- **Email:** `review@echodj.app`
- **Phone:** (your phone — required for review contact)

## Build & submission checklist (reference)

- AppIcon (all required sizes)
- Launch screen (UILaunchScreen dict, already in Info.plist)
- Version: 1.0.0
- Build: 1
- Bundle ID: com.echodj.app
- Auto-renewable subscription: com.echodj.app.pro.monthly, $4.99/month, 7-day free trial
- Privacy manifest: PrivacyInfo.xcprivacy (in bundle)
- Encryption: ITSAppUsesNonExemptEncryption = false

## Pre-submit sanity (run before clicking Submit)

- [ ] Demo Apple Music account is set up and active.
- [ ] The real subscription product exists in App Store Connect with the same product ID as the `.storekit` config (`com.echodj.app.pro.monthly`).
- [ ] `STOREKIT_CONFIGURATION_URL` build setting is **removed or empty** in the archive build (so the sim config doesn't override the real product).
- [ ] App Review contact info above is filled in.
- [ ] Privacy URL is live.
- [ ] Support URL is live.
- [ ] Description reads for typos.
- [ ] Screenshots are attached (see screenshot brief in `rejection-playbook.md`).
