# Modus UI Redesign — Apple-Native Polish Spec

**Date:** 2026-06-09  
**Approach:** Incremental Polish (Approach A)  
**Target:** iOS 17+, SwiftUI, iPhone

## Context

Modus (formerly EchoDJ) has functional but bare UI: a static RadioView with basic controls, a flat SearchView list, no Settings, no onboarding, and no DJ voice toggle. The AI DJ voice (TransitionManager) runs automatically for Pro users with no user control. This redesign makes the existing structure feel Apple-native through materials, typography, haptics, animations, a Settings tab, onboarding, and contextual tips — without restructuring into an immersive Now Playing view.

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Settings location | Full Settings tab (third tab) | HIG: "general, infrequently changed settings" belong in a settings area |
| DJ Voice toggle | Settings tab (global default) + per-station in StationOptionsSheet | HIG: task-specific options near the task, global defaults in Settings |
| Onboarding | Welcome cards (3 cards on first launch) + TipKit contextual tips | HIG: "context-specific tips instead of a single flow"; SwiftUI-Onboarding library for welcome |
| Station flow | Incremental polish of current tab-based flow | User chose Approach A; immersive Now Playing can come later |
| Apple-native feel | Materials, typography, haptics, animations, SF Symbols | All four areas selected by user |

---

## 1. Settings Tab

**File:** `Modus/UI/Tabs/SettingsView.swift` (NEW)

A `NavigationStack` wrapping a `Form` with grouped sections:

### DJ & Station Section
- **AI DJ Voice** — `Toggle` bound to `@AppStorage("djVoiceEnabled")` (default: `true` for Pro, `false` for Free). Description: "Hear AI commentary between tracks"
- **Default Surprise Mode** — `Toggle` bound to `@AppStorage("defaultSurpriseMode")` (default: `false`). Description: "Start stations with surprise picks enabled"
- **Default Arc Shaping** — `Toggle` bound to `@AppStorage("defaultArcShaping")` (default: `false`). Pro-only; grayed out with "Pro" badge for Free tier. Description: "Use DJ Arc to shape station flow"

### Account Section
- **Subscription** — Shows current tier badge (`Free` / `Pro`). Tapping opens `PaywallSheet`.
- **Restore Purchases** — `Button` that calls `SubscriptionManager.restorePurchases()`

### About Section
- **Privacy Policy** — `Link` to `https://modus.audio/privacy`
- **Version** — Read-only `Text` from `Bundle.main.infoDictionary?["CFBundleShortVersionString"]`

### Implementation Notes
- Use `Form` with `.navigationTitle("Settings")` and grouped section headers
- `@AppStorage` for boolean defaults (persists across launches via UserDefaults)
- `SubscriptionManager` accessed via `@EnvironmentObject` from `AppEnvironment`
- SF Symbol icons on each row leading side (`waveform`, `shuffle`, `sparkles`, etc.)

---

## 2. Onboarding

### First-Launch Welcome Cards

**File:** `Modus/UI/Onboarding/OnboardingView.swift` (NEW)  
**Dependency:** `swiftui-onboarding` package (sedlacek-solutions/SwiftUI-Onboarding)

Three `FeatureInfo` cards:
1. **"Your Radio, Your Way"** — Icon: `dot.radiowaves.left.and.right` — "Modus builds behavioral radio stations from a single song."
2. **"AI DJ Arc"** — Icon: `waveform` — "Pro subscribers hear AI commentary between tracks. Toggle it anytime in Settings."
3. **"Discover & Grow"** — Icon: `sparkles` — "Start from any track and your station evolves based on what you skip, keep, and explore."

Applied via `.showOnboardingIfNeeded` on `MainTabView`, persisted with `@AppStorage("hasCompletedOnboarding")`.

### TipKit Contextual Tips

**File:** `Modus/UI/Tips/ModusTips.swift` (NEW)

Four tips using Apple's TipKit framework:
- `RadioQueueTip` — "Tap ↓ to see what's coming up next" (appears when `upcoming` first populates on RadioView)
- `HardSkipTip` — "Hard skip tells us you didn't vibe with this track" (appears on first `hand.thumbsdown.fill` tap)
- `SearchStartTip` — "Tap any track to start a behavioral radio station" (appears on first SearchView visit)
- `SurpriseModeTip` — "Surprise Me mixes in tracks outside your usual taste" (appears on first StationOptionsSheet)

Each tip fires once per `Tips.Event` trigger, then auto-dismisses and never reappears. `Tips.configure()` called in `ModusApp.swift` init with `displayFrequency: .daily` to avoid tip fatigue.

---

## 3. RadioView Polish

**File:** `Modus/UI/Tabs/RadioView.swift` (MODIFY)

### Visual Changes
- Replace static `LinearGradient` background with `VibeVisualizer(energy: currentEnergy, valence: currentValence)` — already built in `UI/Components/VibeVisualizer.swift`, just not wired. Pass energy/valence from `StationQueueManager` or `CachedTrack` metadata.
- Artwork area: shrink from 300pt to 260pt, add `.shadow(radius: 12)` and `.matchedGeometryEffect(id: "artwork", in: namespace)` for future transition readiness
- Track info: use `.font(.title)` for track name, `.font(.body)` for artist, proper `.foregroundStyle(.primary)` / `.foregroundStyle(.secondary)`
- "Free"/"Pro" badge: move inline next to artist, smaller font (`.font(.caption2.bold())`), less prominent background
- "Recent" button: move to `.toolbar` as icon-only button (`clock.arrow.circlepath`)
- Progress bar: add `.tint(.accentColor)` and subtle gradient fill
- "Next Up" queue: extract into a `.sheet` with `.presentationDetents([.medium])` and `.presentationDragIndicator(.visible)`, triggered by a "Next Up" button in the main view

### Controls
- `HCenterControlsView`: ensure 44pt minimum tap targets, add `ContentShape(Rectangle())` to each button
- Play/pause: add `.scaleEffect(isPlaying ? 1.0 : 0.95)` with `.animation(.easeInOut(duration: 0.15), value: isPlaying)`
- Skip buttons: add haptic via `UIImpactFeedbackGenerator(style: .light).impactOccurred()` on tap
- Dimmed state (no station): pulsing "Start a station from Search" text with `.animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: trackTitle.isEmpty)`

### DJ Transition Indicator
- New `@State private var isTransitioning: Bool = false` on RadioView
- When `TransitionManager.executeTransition` is called, set `isTransitioning = true`, then reset after ~5s
- Show a small inline indicator above the progress bar: `HStack { Image(systemName: "waveform"); Text("DJ Arc") }` with `.font(.caption)` and `.transition(.opacity.combined(with: .move(edge: .top)))`
- Fade out after transition completes

### State Management Changes
- Add `@AppStorage("djVoiceEnabled") var djVoiceEnabled: Bool = true`
- Pass `djVoiceEnabled` to `TransitionManager.executeTransition(isEnabled:)` — when OFF, skip TTS synthesis and ducking entirely
- Add `@State private var currentEnergy: Double = 0.5` and `@State private var currentValence: Double = 0.5` to drive `VibeVisualizer`; update in the poll timer from `CachedTrack` metadata

---

## 4. SearchView Polish

**File:** `Modus/UI/Tabs/SearchView.swift` (MODIFY)

### Visual Changes
- Replace flat `ScrollView` + `ForEach` with `List` using `.listStyle(.insetGrouped)`
- Section seed library under `Section("Popular Picks")` and catalog results under `Section("Apple Music")`
- Each row: add a colored artwork placeholder circle (deterministic color from `track.title.hashValue`), then `VStack` with `track.title` (`.font(.headline)`) and `track.artistName` (`.font(.subheadline) .foregroundStyle(.secondary)`)
- Trailing icon: `Image(systemName: "play.radiowaves.left.and.right")` in `.tint` accent color

### StationOptionsSheet Improvements
- Add `.presentationDetents([.medium])` and `.presentationDragIndicator(.visible)`
- Add track artwork + metadata at top (use `AsyncImage` if `track.artworkURL` exists, else colored placeholder)
- "Surprise Me" toggle: add description text "Mix in tracks outside your usual taste"
- "DJ Arc (Pro)" toggle: add description text "AI commentary between tracks"; read default from `@AppStorage("defaultArcShaping")` and `@AppStorage("djVoiceEnabled")`
- Add explanation line below toggles: "Modus builds a station from this track's energy, mood, and rhythm profile."
- "Start Station" button: `.buttonStyle(.borderedProminent)` with accent color

### Search UX States
- Empty state (no search text): show full seed library under "Popular Picks" header
- Searching: `ProgressView("Searching Apple Music…")` under "Apple Music" section header
- No results: `"No results for '\(searchText)'. Try a different song or artist."` as a `ContentUnavailableView`
- Catalog results appear under "Apple Music" section header

---

## 5. MainTabView Update

**File:** `Modus/UI/Tabs/MainTabView.swift` (MODIFY)

Add third tab:
```swift
TabView(selection: $env.selectedTab) {
    RadioView()
        .tabItem { Label("Radio", systemImage: "dot.radiowaves.left.and.right") }
        .tag(0)
    SearchView()
        .tabItem { Label("Search", systemImage: "magnifyingglass") }
        .tag(1)
    SettingsView()
        .tabItem { Label("Settings", systemImage: "gearshape") }
        .tag(2)
}
```

Add `.showOnboardingIfNeeded` modifier for first-launch welcome cards (from SwiftUI-Onboarding library).

Add `Tips.configure()` call in `ModusApp.swift` init.

---

## 6. AppEnvironment Changes

**File:** `Modus/Core/AppEnvironment.swift` (MODIFY)

No structural changes needed. `TransitionManager.executeTransition(isEnabled:)` already takes a boolean — we'll read from `@AppStorage("djVoiceEnabled")` at the call site in RadioView rather than plumbing it through AppEnvironment.

---

## 7. StationOptionsSheet Changes

**File:** `Modus/UI/Tabs/SearchView.swift` (MODIFY — StationOptionsSheet struct within)

- Add `@AppStorage("defaultSurpriseMode") var defaultSurpriseMode: Bool = false`
- Add `@AppStorage("defaultArcShaping") var defaultArcShaping: Bool = false`
- Add `@AppStorage("djVoiceEnabled") var djVoiceEnabled: Bool = true`
- Initialize toggle bindings from these defaults
- When Pro: show "DJ Arc" toggle; when Free: hide it
- The "Start Station" action reads `djVoiceEnabled` and passes it to `TransitionManager`

---

## Files to Create

| File | Purpose |
|------|---------|
| `Modus/UI/Tabs/SettingsView.swift` | Settings tab with DJ Voice, defaults, account, about |
| `Modus/UI/Onboarding/OnboardingView.swift` | Welcome cards config using SwiftUI-Onboarding |
| `Modus/UI/Tips/ModusTips.swift` | TipKit tip definitions and event triggers |

## Files to Modify

| File | Changes |
|------|---------|
| `Modus/UI/Tabs/RadioView.swift` | VibeVisualizer background, materials, typography, haptics, DJ indicator, queue sheet, `@AppStorage` for voice toggle |
| `Modus/UI/Tabs/SearchView.swift` | List styling, sections, StationOptionsSheet improvements, `@AppStorage` defaults |
| `Modus/UI/Tabs/MainTabView.swift` | Add Settings tab, `.showOnboardingIfNeeded` |
| `Modus/Core/ModusApp.swift` | `Tips.configure()` call |
| `Modus/Engine/Concrete/TransitionManager.swift` | Read `djVoiceEnabled` from caller (no change to actor itself) |

## Dependency Addition

- **Swift Package:** `sedlacek-solutions/swiftui-onboarding` (for `WelcomeScreen` and `.showOnboardingIfNeeded` modifier)
- **Framework:** `TipKit` (Apple built-in, iOS 17+)

---

## Verification Plan

1. **Simulator build:** `python3 generate-xcodeproj.py && xcodebuild -project Modus.xcodeproj -scheme Modus -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build`
2. **Onboarding:** First launch should show 3 welcome cards; dismiss and relaunch should skip them
3. **Settings tab:** Verify all toggles persist via `@AppStorage`; Pro badge shows correctly; DJ Voice toggle affects transition execution
4. **RadioView:** VibeVisualizer renders with track energy/valence; haptics fire on skip; DJ Arc indicator appears and fades; "Next Up" sheet detents work
5. **SearchView:** Inset grouped list; sections appear; StationOptionsSheet shows descriptions and reads defaults
6. **TipKit:** Tips appear on first encounter and never again; can reset via Settings → Developer → Reset Tips (debug)
7. **Regression:** Station start → auto-switch to Radio still works; queue populates; play/pause/skip still functional

---

## Spec Self-Review

- **Placeholder scan:** No TBDs or TODOs remain. All descriptions are concrete.
- **Internal consistency:** `@AppStorage` keys are named consistently (`djVoiceEnabled`, `defaultSurpriseMode`, `defaultArcShaping`, `hasCompletedOnboarding`). Settings toggles match StationOptionsSheet defaults. TransitionManager reads from caller, not internally.
- **Scope check:** Single implementation plan covering 3 new files + 5 modified files. No decomposition needed.
- **Ambiguity check:** All UI elements are specified with SwiftUI API names. No two-interpretation requirements.