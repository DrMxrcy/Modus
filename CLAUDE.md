# 🤖 Claude Code Project Guidelines & Workspace Protocol

> **Project:** Modus (formerly EchoDJ) — AI DJ Radio for Apple Music
> **Stack:** SwiftUI, MusicKit, StoreKit 2, SwiftData, Combine
> **Target:** iOS 17+, Xcode 15+
> **Build System:** Hand-rolled `generate-xcodeproj.py` → `Modus.xcodeproj` → `xcodebuild` (via XcodeBuildMCP)

## 🚀 Quick Start

```bash
# Generate / refresh the Xcode project (required after adding new source files)
python3 generate-xcodeproj.py

# Build for simulator (primary validation path)
# Use XcodeBuildMCP defaults: scheme=Modus, simulatorName=iPhone 15 Pro

# Build for device (requires paid Apple Developer Team ID in generate-xcodeproj.py)
# Update TEAM_ID and BUNDLE_ID in generate-xcodeproj.py first, then regenerate.
```

## 🎯 Core Persona & Guardrails
- You are an elite, practical software engineer working locally.
- **Scope Protection:** Prevent scope creep at all costs. Never write unvetted functional code without an active, approved plan file inside `.claude/plans/`.
- **Single-Tasking:** Work on exactly ONE checkbox item at a time. Do not multi-task across different features or bugs simultaneously.

---

## 🏁 Verification & Quality Gate
- **Build/Test Command:** After every code change, run a simulator build via XcodeBuildMCP to verify compilation. Use device builds only for StoreKit/MusicKit features that require real hardware.
- **Linting/Formatting:** Swift syntax is enforced by the compiler. Before staging, review the git diff for accidental pbxproj corruption (the generator is fragile) and ensure no `print()` statements leak into production code.
- **Strict Stop Policy:** You are strictly forbidden from marking a task as complete if any verification command returns a non-zero exit code. Treat test failures as high-priority sub-tasks and resolve them immediately.

---

## 🗺️ Hierarchical Planning State Machine
Whenever the user activates `/plan` mode, or explicitly requests an architectural breakdown, you MUST execute this loop before touching functional source files:

1. **Audit Context:** Read `@ROADMAP.md` and check for existing documents inside `.claude/plans/`.
   > **Current active plan:** `.claude/plans/009-app-store-review.md` (App Store v1 submission cut). All new functional work must align with this plan or require explicit re-scoping.
2. **Clone the Blueprint:** If spinning up a new epic, copy the read-only blueprint from `@.claude/templates/feature-plan.md` into a new unique file inside `.claude/plans/` using sequential indexing (e.g., `001-auth-setup.md`).
3. **Draft the Spec:** While remaining in read-only `/plan` mode, fill out the template fields completely. Break the execution timeline down into highly granular, tiny, testable steps.
4. **Link the Dashboard:** Propose the exact markdown diff to index your new plan file back into the master `@ROADMAP.md` dashboard. Wait for explicit human approval before exiting plan mode.

---

## 🏗️ Architecture Overview

```
Modus/
├── Core/              App entry point (ModusApp.swift), AppEnvironment.swift (DI container + capability resolution)
├── UI/Tabs/           MainTabView.swift, RadioView.swift, SearchView.swift
├── Engine/
│   ├── Protocols/     MusicProviderProtocol.swift, DJBrainProtocol.swift
│   ├── Concrete/      AppleMusicProvider.swift, StationQueueManager.swift, SubscriptionManager.swift, ...
│   └── Mocks/         SimulatorMusicProvider.swift, FallbackDJBrain.swift
└── Data/Models/       SwiftData models: CachedTrack.swift, StationSession.swift, RecentStation.swift, ...
```

**Key Patterns:**
- **Capability Resolution:** `AppEnvironment.resolveCapabilities()` picks `AppleMusicProvider` (device) vs `SimulatorMusicProvider` (sim) at runtime.
- **Provider Metadata:** `MusicProviderProtocol` exposes `currentTitle`, `currentArtist`, `currentArtworkURL` so the UI can render without reaching into MusicKit directly.
- **Queue Resilience:** `StationQueueManager` catches per-track `loadTrack(id:)` failures rather than aborting the entire station build.

---

## ⚠️ Project Gotchas

1. **Simulator MusicKit Limitations:** The simulator cannot perform real MusicKit catalog authorization or playback. `SimulatorMusicProvider` provides cached/demo tracks. UI behavior for Search→Radio must be validated on simulator; real MusicKit auth/playback requires a physical device.
2. **PBXProj Generator Fragility:** `generate-xcodeproj.py` is hand-rolled Python. Adding new source files requires regenerating the project. Never hand-edit `Modus.xcodeproj/project.pbxproj` directly—changes will be lost on the next generation.
3. **Device Signing & Team ID:** Device builds require the paid Team ID (`N2YP2AEB6U`) and a unique bundle identifier. If the build fails with provisioning errors, check `generate-xcodeproj.py` constants first.
4. **StoreKit 2 Verification:** `SubscriptionManager.handleTransactionUpdate` must pattern-match `VerificationResult<Transaction>` as `.verified(let transaction)` / `.unverified`. Reading `.payloadValue` directly is a compile/runtime error.
5. **SwiftData Save Reliability:** Replace `try? context.save()` with explicit `do/catch` + logging. Silent failures cause UI/persistence desync.
6. **No `print()` in Production:** App Store review flags syslog leakage. Use `Logger` subsystem (`app.modus`) and strip debug output before submission.

---

## 🔧 Environment & Dependencies

- **Xcode:** 15+ with iOS 17 SDK
- **Apple Developer Account:** Paid membership required for device builds and StoreKit testing
- **Team ID:** `N2YP2AEB6U` (paid); personal team `5F75D8ZW47` is deprecated
- **Bundle ID:** Unique variant of `com.modus.app` (check `generate-xcodeproj.py`)
- **Background Modes:** `audio`, `airplay`, `picture-in-picture` (see `Modus/Resources/Info.plist`)
- **StoreKit Config:** `Modus/Resources/StoreKit/Modus.storekit` wired via `STOREKIT_CONFIGURATION_URL`
- **Privacy Manifest:** `Modus/Resources/PrivacyInfo.xcprivacy` must stay in sync with actual data collection

---

## 🔄 Automated State Synchronization
During active code execution:
- The moment a discrete step passes its verification commands, physically change its checkbox status from `[ ]` to `[x]` inside its respective sub-plan file.
- Dynamically recalculate and update the macro completion percentage counters listed on the master `@ROADMAP.md` dashboard.
- Sync the codebase changes and the markdown tracking updates together into a single atomic Git action.

---

## 📦 Git & Repository Etiquette
- **Atomic Commits:** Keep commits single-purposed. If a change modifies independent layers, commit them separately.
- **Conventional Commits:** You must strictly format all local commit messages following the Conventional Commits specification:
  - `feat(scope): description` (New features)
  - `fix(scope): description` (Bug resolutions)
  - `refactor(scope): description` (Code cleanups without feature changes)
  - `docs(scope): description` (Roadmap updates or documentation changes)
- **Git Boundaries:** You are strictly forbidden from running `git push` or merging deployment branches. All your operations must remain completely local.

---

## 🧠 Context Lifecycle Management
- **Token Optimization:** Be explicit when referencing paths. Target specific files directly using `@path/to/file` rather than forcing workspace-wide parsing.
- **Compaction Reminder:** If a terminal workspace runs long and tool execution or reasoning speeds begin to lag, remind the human to invoke the `/compact` command to clear historical conversational noise while keeping the active sub-plan in memory.