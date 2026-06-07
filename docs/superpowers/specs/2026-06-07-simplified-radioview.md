# Simplified RadioView Design

## Problem
The current `RadioView` includes a "Vibe Tuner" slider and a `MeshGradient` visualizer background that were added without user request. The user wants a clean now-playing view.

## Design

### Keep
- Album artwork display (replace placeholder with real artwork when available)
- Track title and artist
- Playback progress bar
- Play/Pause, Hard Skip, Soft Skip controls
- "Next Up" section showing upcoming tracks
- Tier badge (Free / Pro)

### Remove
- `VibeVisualizer` background visualizer
- "VIBE TUNER" slider and its `@State` bindings (`valenceLevel`, `energyLevel`)
- SwiftData mutation logic from the slider callback

### Update
- `VibeVisualizer.swift` can stay in the project but will no longer be used in `RadioView`
- `RadioView` background becomes a simple gradient or solid color instead of the animated mesh

## Offline Implications
This change does not affect offline behavior directly. Offline support (playing downloaded Apple Music tracks) is a separate concern that will be addressed after this UI cleanup.

## Files to modify
- `EchoDJ/UI/Tabs/RadioView.swift` — remove slider, visualizer, simplify layout
