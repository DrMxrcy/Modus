# 📑 Plan 001: Core App MVP
> **Status:** Active | **Parent Milestone:** Phase 1: Core App MVP

## 🎯 1. Target Scope & Boundaries
- **Core Objective:** Bootstrap the EchoDJ iOS project with SwiftData models, vector recommendation engine, mock music/DJ providers, dependency injection container, and basic SwiftUI tab interface. Ensure the project compiles and runs in the iOS Simulator without requiring a paid Apple Developer account.
- **Out of Scope:** Apple MusicKit integration (MusicKit requires paid dev account), Foundation Models LLM DJ brain, StoreKit, background audio telemetry, CloudKit syncing, and complex UI animations beyond the basic VibeVisualizer.

## 🏗️ 2. Architectural Blueprint
- **Files to Create:**
  - `EchoDJ/Core/EchoDJApp.swift`
  - `EchoDJ/Core/AppEnvironment.swift`
  - `EchoDJ/Data/Models/UserTasteProfile.swift`
  - `EchoDJ/Data/Models/TrackCooldown.swift`
  - `EchoDJ/Data/Models/CachedTrack.swift`
  - `EchoDJ/Engine/Protocols/MusicProviderProtocol.swift`
  - `EchoDJ/Engine/Protocols/DJBrainProtocol.swift`
  - `EchoDJ/Engine/Concrete/VectorAffinityEngine.swift`
  - `EchoDJ/Engine/Concrete/AppleMusicProvider.swift` (placeholder stub)
  - `EchoDJ/Engine/Concrete/OnDeviceDJBrain.swift` (placeholder stub)
  - `EchoDJ/Engine/Mocks/MockMusicProvider.swift`
  - `EchoDJ/Engine/Mocks/MockDJBrain.swift`
  - `EchoDJ/UI/Tabs/MainTabView.swift`
  - `EchoDJ/UI/Tabs/RadioView.swift`
  - `EchoDJ/UI/Tabs/SearchView.swift`
  - `EchoDJ/UI/Components/VibeVisualizer.swift`
  - `EchoDJ/Resources/Info.plist`
  - `project.yml`
  - `generate-xcodeproj.py`
- **Files to Modify:** None (greenfield bootstrap)
- **Data Model/Schema Changes:** SwiftData local-only schema with three `@Model` classes; no CloudKit in mock mode.
- **Downstream Impact:** All future features depend on this foundation. Mock providers must be replaceable with real providers via `AppEnvironment` flags.

## 🚶‍♂️ 3. Step-by-Step Execution Checklist
- [x] Step 1: Define SwiftData models (UserTasteProfile, TrackCooldown, CachedTrack)
- [x] Step 2: Implement vector recommendation engine (VectorAffinityEngine)
- [x] Step 3: Define actor-isolated protocols (MusicProviderProtocol, DJBrainProtocol)
- [x] Step 4: Implement mock providers (MockMusicProvider, MockDJBrain)
- [x] Step 5: Implement AppEnvironment DI container and EchoDJApp entry point
- [x] Step 6: Create placeholder stubs for Phase 2 concrete providers
- [x] Step 7: Build SwiftUI views (MainTabView, RadioView, SearchView, VibeVisualizer)
- [x] Step 8: Generate Xcode project manually (xcodegen unavailable)
- [x] Step 9: Fix iOS 26 / Swift 6 compilation errors (ForEach ambiguity, .accent deprecation)
- [x] Step 10: Verify successful build against iOS Simulator
