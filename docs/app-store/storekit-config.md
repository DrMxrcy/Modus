# StoreKit Configuration — EchoDJ Pro

> Created 2026-06-07 during Plan 009 Milestone D.

## What this is

A StoreKit 2 `.storekit` configuration file at `EchoDJ/Resources/StoreKit/EchoDJ.storekit`, wired into the build via the `STOREKIT_CONFIGURATION_URL` build setting in both Debug and Release target configurations (see `generate-xcodeproj.py`).

This file lets the iOS simulator return a real StoreKit `Product` and `SubscriptionInfo` for EchoDJ Pro **without** requiring App Store Connect access, a Developer account, or a sandbox Apple ID.

## Product defined

- **Group ID:** `premium_monthly_group`
- **Product ID:** `com.echodj.app.pro.monthly`
- **Display price:** $4.99 / month
- **Free trial:** 1 week (1 period of `P1W`, payment mode `free`)
- **Recurring period:** `P1M` (1 month)
- **Family shareable:** No
- **Locale:** en_US

## How the sim picks it up

1. The `.storekit` file is a bundle resource (in `project.pbxproj` Resources phase, file ref `Resources/StoreKit/EchoDJ.storekit`).
2. The `STOREKIT_CONFIGURATION_URL` build setting points Xcode to the file at build time.
3. When the app starts, StoreKit 2's `Product.SubscriptionInfo.status(for: "premium_monthly_group")` and `Product.products(for: ["com.echodj.app.pro.monthly"])` resolve against the config instead of App Store Connect.

## How to test the Pro flip in sim

1. Open the sim.
2. Launch EchoDJ.
3. While the app is running, open the sim's **Debug → Manage StoreKit Transactions** menu (Xcode → Debug → Simulate StoreKit Transaction).
4. Pick the `com.echodj.app.pro.monthly` product and click **Buy**. Optionally configure a renewal rate / interruption.
5. The `SubscriptionManager.updateSubscriptionStatus()` is called from `Transaction.updates`, which should flip `activeTier` from `freeTier` to `proTier`. Confirm in the RadioView tier badge (turns green + says "Pro").

## How to swap in the real product ID later (D3 / D4)

When the Apple Developer Program enrollment is active and the real product is created in App Store Connect:

1. In App Store Connect, create the auto-renewable subscription in the `premium_monthly_group` group with the same trial/locale settings.
2. The **group ID** stays `premium_monthly_group` (it's internal to the app, not in App Store Connect).
3. The **product ID** in App Store Connect must match the one in this `.storekit` file: `com.echodj.app.pro.monthly`. If you want a different ID, update this file too.
4. The `STOREKIT_CONFIGURATION_URL` build setting should be **removed or set to empty** for the device-archive build, otherwise the sim config overrides the real App Store Connect config. The plan calls for this in H1 (code signing + final build settings).

## Plan verification

- [x] **D1.** `.storekit` config file created with one auto-renewable subscription, group ID `premium_monthly_group`, 7-day free trial. *Done 2026-06-07.*
- [x] **D2.** StoreKit pipeline on sim verified — `(StoreKit) StoreKit/SubscriptionStatusQuery` observed in `logs/sim-storekit-baseline.log`; no error in catch branch; `activeTier` correctly falls back to `freeTier` with no purchase. *Done 2026-06-07.*
- [ ] **D3.** Real auto-renewable product in App Store Connect. *Blocked on enrollment.*
- [ ] **D4.** Real product ID wired into `SubscriptionManager`. *Blocked on D3.*
- [ ] **D5.** Real-device sandbox Apple ID purchase. *Blocked on real-device gate before H6.*

## **Why:** Sim can validate the listener + status pipeline; the purchase flow itself needs E (Purchase + Restore UI) to be visible in the app, which is the next milestone.

## **How to apply:** When you want to test Pro on sim, use Debug → Manage StoreKit Transactions to "Buy" the product. When the dev account is active, the `.storekit` config is the bridge that lets the sim keep working with the same group ID.
