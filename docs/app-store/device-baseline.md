# Device / Simulator Baseline

> Captured: 2026-06-07 during Plan 009 Milestone A.
> Real device on hold per user — simulator is the active test target.

## Real device (paused)

- Status: paused.
- When unblocked, capture UDID and iOS version here before any device build.

## Active simulator

- **Device:** iPhone 17 Pro Max
- **UDID:** `9334BD3F-60AE-43A2-95A0-9AB488AD1129`
- **State:** Booted
- **Runtime:** iOS 26.3 (com.apple.CoreSimulator.SimRuntime.iOS-26-3, build 23D8133)
- **Xcode toolchain:** see `xcodebuild -version` output during A1 build.

## Build command reference

- Sim build: `xcodebuild -project EchoDJ.xcodeproj -scheme EchoDJ -destination 'platform=iOS Simulator,id=9334BD3F-60AE-43A2-95A0-9AB488AD1129' build`
- Sim install: `xcrun simctl install 9334BD3F-60AE-43A2-95A0-9AB488AD1129 <built .app>`
- Sim launch: `xcrun simctl launch 9334BD3F-60AE-43A2-95A0-9AB488AD1129 <bundle-id>`
- Sim log stream: `xcrun simctl spawn 9334BD3F-60AE-43A2-95A0-9AB488AD1129 log stream --level=debug --style=compact`

## Why sim-only

Per user direction 2026-06-07: real device testing is paused. All verification runs on the iPhone 17 Pro Max simulator above. Real-device gate runs (before H6 submit) are documented in the plan but not currently scheduled.
