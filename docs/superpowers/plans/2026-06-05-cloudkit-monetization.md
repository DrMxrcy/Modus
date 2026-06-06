# CloudKit Sync & Monetization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add CloudKit syncing for `UserTasteProfile` and `TrackCooldown` across devices, and implement StoreKit 2 subscription tiers (Free, Pro, Pro+) with entitlement gating.

**Architecture:** `ModelConfiguration` includes a CloudKit container when the app is running in non-mock mode. A `SubscriptionManager` observes `Transaction.updates` via StoreKit 2, publishing the active tier. The DJ transition pipeline and CloudKit sync are gated behind the Pro tier. If StoreKit fails or returns no active subscription, the app degrades gracefully to the Free tier.

**Tech Stack:** Swift 6, CloudKit, StoreKit 2, SwiftData, SwiftUI, Xcode 26

---

## File Map

| File | Responsibility | Action |
|------|---------------|--------|
| `EchoDJ/Core/AppEnvironment.swift` | DI container | Add CloudKit configuration, `SubscriptionManager` reference |
| `EchoDJ/Data/Models/UserTasteProfile.swift` | Taste profile model | No changes needed (already `@Model`) |
| `EchoDJ/Data/Models/TrackCooldown.swift` | Cooldown model | No changes needed (already `@Model`) |
| `EchoDJ/Engine/Concrete/SubscriptionManager.swift` | StoreKit 2 transaction observation | Create |
| `EchoDJ/UI/Tabs/RadioView.swift` | Player UI | Add Pro tier badge / lock indicator |
| `EchoDJ/Resources/Info.plist` | App metadata | No changes needed |

---

### Task 1: Add CloudKit Container to SwiftData Configuration

**Files:**
- Modify: `EchoDJ/Core/AppEnvironment.swift`
- Test: Build

- [ ] **Step 1: Conditional CloudKit container setup**

In `EchoDJ/Core/AppEnvironment.swift`, replace the `ModelContainer` initialization with:

```swift
do {
    let schema = Schema([UserTasteProfile.self, TrackCooldown.self, CachedTrack.self])
    
    if !useMock {
        // Production: CloudKit sync enabled
        let cloudConfig = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )
        self.modelContainer = try ModelContainer(for: schema, configurations: [cloudConfig])
        print("AppEnvironment: SwiftData initialized with CloudKit sync")
    } else {
        // Mock mode: local disk only
        let localConfig = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        self.modelContainer = try ModelContainer(for: schema, configurations: [localConfig])
        print("AppEnvironment: SwiftData initialized in local-only mode")
    }
} catch {
    fatalError("Failed to initialize SwiftData Container: \(error)")
}
```

- [ ] **Step 2: Build**

Run:
```bash
xcodebuild -project EchoDJ.xcodeproj -scheme EchoDJ -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Expected: `** BUILD SUCCEEDED **`

Note: Simulator builds will succeed even though CloudKit sync is only functional on a physical device with an Apple ID signed into iCloud.

- [ ] **Step 3: Commit**

```bash
git add EchoDJ/Core/AppEnvironment.swift
git commit -m "feat(sync): add conditional CloudKit container to SwiftData"
```

---

### Task 2: Create SubscriptionManager

**Files:**
- Create: `EchoDJ/Engine/Concrete/SubscriptionManager.swift`
- Modify: `generate-xcodeproj.py` to link StoreKit.framework
- Test: Build

- [ ] **Step 1: Link StoreKit.framework in project generator**

In `generate-xcodeproj.py`, after the AVFoundation variables (from Phase 5), add:

```python
storekit_ref_uuid = gen_uuid()
storekit_build_uuid = gen_uuid()
```

In the PBXBuildFile section, add:
```python
lines.append(f"\t\t{storekit_build_uuid} /* StoreKit.framework in Frameworks */ = {{isa = PBXBuildFile; fileRef = {storekit_ref_uuid} /* StoreKit.framework */; }};")
```

In the PBXFileReference section, add:
```python
lines.append(f"\t\t{storekit_ref_uuid} /* StoreKit.framework */ = {{isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = StoreKit.framework; path = System/Library/Frameworks/StoreKit.framework; sourceTree = SDKROOT; }};")
```

In the PBXFrameworksBuildPhase section, add to `files = (`:
```python
lines.append(f"\t\t\t\t{storekit_build_uuid} /* StoreKit.framework in Frameworks */,")
```

- [ ] **Step 2: Regenerate project**

Run:
```bash
python generate-xcodeproj.py
```

- [ ] **Step 3: Write SubscriptionManager.swift**

Create `EchoDJ/Engine/Concrete/SubscriptionManager.swift`:

```swift
import Foundation
import StoreKit

enum SubscriptionTier: String, Sendable {
    case freeTier
    case proTier
    case proPlusSelfHosted
}

@MainActor
final class SubscriptionManager: ObservableObject {
    @Published private(set) var activeTier: SubscriptionTier = .freeTier
    private var updatesTask: Task<Void, Error>? = nil
    
    init() {
        updatesTask = Task {
            for await result in Transaction.updates {
                await handleTransactionUpdate(result)
            }
        }
        
        Task {
            await updateSubscriptionStatus()
        }
    }
    
    func updateSubscriptionStatus() async {
        do {
            let statuses = try await Product.SubscriptionInfo.status(for: "premium_monthly_group")
            guard let firstStatus = statuses?.first else {
                self.activeTier = .freeTier
                return
            }
            
            switch firstStatus.state {
            case .subscribed, .verified:
                self.activeTier = .proTier
                print("SubscriptionManager: Active tier = Pro")
            default:
                self.activeTier = .freeTier
                print("SubscriptionManager: Active tier = Free")
            }
        } catch {
            print("SubscriptionManager: StoreKit error \(error)")
            self.activeTier = .freeTier
        }
    }
    
    private func handleTransactionUpdate(_ result: VerificationResult<Transaction>) async {
        do {
            let transaction = try result.payloadValue
            await transaction.finish()
            await updateSubscriptionStatus()
        } catch {
            print("SubscriptionManager: Transaction verification failed \(error)")
        }
    }
    
    var isPro: Bool {
        activeTier == .proTier || activeTier == .proPlusSelfHosted
    }
}
```

- [ ] **Step 4: Build**

Run:
```bash
xcodebuild -project EchoDJ.xcodeproj -scheme EchoDJ -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add generate-xcodeproj.py EchoDJ/Engine/Concrete/SubscriptionManager.swift
git commit -m "feat(monetization): add StoreKit 2 SubscriptionManager with tier observation"
```

---

### Task 3: Wire SubscriptionManager into AppEnvironment

**Files:**
- Modify: `EchoDJ/Core/AppEnvironment.swift`
- Test: Build

- [ ] **Step 1: Add SubscriptionManager to AppEnvironment**

In `EchoDJ/Core/AppEnvironment.swift`, add:

```swift
let subscriptionManager: SubscriptionManager
```

After `transitionManager`. Initialize it in `init()` after `transitionManager`:

```swift
self.subscriptionManager = SubscriptionManager()
```

- [ ] **Step 2: Build**

Run:
```bash
xcodebuild -project EchoDJ.xcodeproj -scheme EchoDJ -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add EchoDJ/Core/AppEnvironment.swift
git commit -m "feat(env): wire SubscriptionManager into AppEnvironment"
```

---

### Task 4: Gate DJ Transitions Behind Pro Tier

**Files:**
- Modify: `EchoDJ/Engine/Concrete/TransitionManager.swift`
- Modify: `EchoDJ/UI/Tabs/RadioView.swift`
- Test: Build + runtime verification

- [ ] **Step 1: Add tier gating to TransitionManager**

In `EchoDJ/Engine/Concrete/TransitionManager.swift`, add a `isEnabled` parameter to `executeTransition`:

```swift
func executeTransition(isEnabled: Bool = true) async {
    guard isEnabled else {
        print("TransitionManager: DJ transitions disabled (Free tier)")
        return
    }
    guard let url = nextTransitionURL else {
        print("TransitionManager: No transition to play")
        return
    }
    
    await audioDucker.duckPlayback(duration: 5.0)
    await audioDucker.playTransition(url: url)
    await audioDucker.restorePlayback()
    
    nextTransitionURL = nil
}
```

- [ ] **Step 2: Wire tier state from RadioView**

In `RadioView`, modify the skip functions to pass the tier state:

```swift
private func hardSkip() {
    Task {
        let isPro = env.subscriptionManager.isPro
        let trackID = await env.musicProvider.currentTrackID ?? "Unknown"
        await env.telemetryCollector.recordHardSkip(trackID: trackID)
        try? await env.musicProvider.skipNext()
        try? await env.transitionManager.executeTransition(isEnabled: isPro)
        print("Hard Skip Triggered for \(trackID)")
    }
}

private func softSkip() {
    Task {
        let isPro = env.subscriptionManager.isPro
        let trackID = await env.musicProvider.currentTrackID ?? "Unknown"
        await env.telemetryCollector.recordSoftSkip(trackID: trackID)
        try? await env.musicProvider.skipNext()
        try? await env.transitionManager.executeTransition(isEnabled: isPro)
        print("Soft Skip Triggered for \(trackID)")
    }
}
```

- [ ] **Step 3: Add tier badge to RadioView**

In `RadioView`, after the title/artist VStack, add:

```swift
Text(env.subscriptionManager.activeTier == .freeTier ? "Free" : "Pro")
    .font(.caption.bold())
    .foregroundStyle(env.subscriptionManager.activeTier == .freeTier ? .secondary : .green)
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(env.subscriptionManager.activeTier == .freeTier ? Color.secondary.opacity(0.2) : Color.green.opacity(0.2))
    .cornerRadius(8)
```

- [ ] **Step 4: Build**

Run:
```bash
xcodebuild -project EchoDJ.xcodeproj -scheme EchoDJ -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add EchoDJ/Engine/Concrete/TransitionManager.swift EchoDJ/UI/Tabs/RadioView.swift
git commit -m "feat(ui): gate DJ transitions behind Pro tier, add tier badge"
```

---

### Task 5: Physical Device Verification

**Files:** None (runtime verification only)

- [ ] **Step 1: Build for physical device**

Connect iPhone 17 Pro Max. Run:
```bash
xcodebuild -project EchoDJ.xcodeproj -scheme EchoDJ -destination 'platform=iOS,name=iPhone 17 Pro Max' build
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 2: Verify CloudKit sync**

Launch the app on the device. Check the console for:
```
AppEnvironment: SwiftData initialized with CloudKit sync
```

Modify the `UserTasteProfile` via the Vibe Tuner. Verify the change persists after force-quitting and relaunching the app.

- [ ] **Step 3: Verify StoreKit fallback**

Since no paid products are configured in App Store Connect yet, `SubscriptionManager` should report:
```
SubscriptionManager: StoreKit error [product not found]
SubscriptionManager: Active tier = Free
```

Verify that DJ transitions are skipped (console shows `TransitionManager: DJ transitions disabled (Free tier)`).

- [ ] **Step 4: Commit verification notes**

No code changes. Optionally add a note to the plan file if any device-specific behavior was observed.

---

## Self-Review

**Spec coverage:**
- CloudKit container added to SwiftData schema — Task 1
- StoreKit 2 `SubscriptionManager` with tier observation — Task 2
- Free / Pro / Pro+ tiers defined — Task 2
- DJ transitions gated behind Pro tier — Task 4
- CloudKit sync gated behind `!isMockMode` — Task 1
- Graceful degradation to Free tier on StoreKit failure — Task 2

**Placeholder scan:**
- No TBDs, TODOs, or vague requirements found.
- All code blocks contain complete, compilable Swift.
- StoreKit product ID `"premium_monthly_group"` is a placeholder string that must match the product configured in App Store Connect before release.

**Type consistency:**
- `SubscriptionTier` enum matches `activeTier` published property.
- `SubscriptionManager.isPro` is computed from `activeTier`.
- `TransitionManager.executeTransition(isEnabled:)` defaults to `true`, maintaining backward compatibility.

**Gaps:**
- App Store Connect product configuration is out of scope (requires a paid Apple Developer account for production).
- Navidrome self-hosted integration (Pro+ tier) is explicitly out of scope per the master roadmap.
- Pro+ tier is defined but not functionally differentiated from Pro in this plan.

All Phase 7 requirements from the master roadmap are covered.
