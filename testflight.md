# Floppy Duck TestFlight Runbook

Current repo truth as of April 2, 2026.

## Purpose

Use this file as the canonical launch-readiness source for getting Floppy Duck into TestFlight. [docs/APPSTORE_METADATA.md](/Users/xanderevans/Documents/floppyduck/docs/APPSTORE_METADATA.md) is the canonical product-page and IAP inventory source. [RELEASE_CHECKLIST.md](/Users/xanderevans/Documents/floppyduck/RELEASE_CHECKLIST.md) and [LAUNCH_CHECKLIST.md](/Users/xanderevans/Documents/floppyduck/LAUNCH_CHECKLIST.md) are retained only as archived pointers.

## Already Code-Verified

- Release app config points at the production Convex deployment.
- Privacy manifest exists and currently declares a privacy-first posture with no ATT/tracking domains.
- App Store metadata draft exists, including support/privacy URLs and base copy.
- Legacy local stats now decode safely even when older payloads are missing `peakElo`, `winStreak`, and `bestWinStreak`.
- Remote stats parsing now accepts `peakElo`, `winStreak`, and `bestWinStreak` from backend payloads.
- Targeted unit coverage exists for stats migration, snapshot compatibility, and peak/streak behavior.

## Manual Blockers Before Upload

### 1. App Store Connect setup

- Create or confirm the App Store Connect app record.
- Get the real Apple app ID and replace the placeholder `GK.appStoreID = "000000000"` in code before final release submission.
- Enter the metadata from [docs/APPSTORE_METADATA.md](/Users/xanderevans/Documents/floppyduck/docs/APPSTORE_METADATA.md).
- Complete pricing, age rating, review contact info, and privacy disclosures.

### 2. Signing and Apple auth

- Enable Sign in with Apple on the App ID in the Apple Developer portal.
- Confirm the release provisioning profile includes the entitlement.
- Run the Sign in with Apple flow on a real device with release-style signing.

### 3. IAP reconciliation and StoreKit validation

- Register every premium product that will be visible in TestFlight.
- Validate that App Store Connect product inventory matches what the app exposes.
- Current inventory source of truth is [docs/APPSTORE_METADATA.md](/Users/xanderevans/Documents/floppyduck/docs/APPSTORE_METADATA.md), which should match the visible Shop tabs and product IDs exactly.
- Run StoreKit sandbox purchases and restore flows on device.

### 4. Screenshot and asset package

- Generate the final screenshot matrix for required device sizes.
- Upload the screenshots that match the product page copy and current UI.
- Confirm icon and launch screen look correct on real devices.

### 5. Manual smoke pass

- Fresh install to guest flow.
- Guest to Apple link flow.
- Returning user session restore.
- Sign out and delete account.
- Quick Play, Ranked, and Private Room on two devices.
- Shop browse, purchase, and restore.
- Offline/failed backend startup behavior.

## Final Push Order

1. Run focused unit tests and fix any launch-critical failures.
2. Reconcile visible IAP inventory against App Store Connect.
3. Update the real App Store ID in code once the app record exists.
4. Verify signing, Sign in with Apple capability, and release archive settings in Xcode.
5. Run the manual smoke pass on device and two-device multiplayer.
6. Generate screenshots and finalize App Store Connect metadata/disclosures.
7. Archive and upload the build.
8. Install from TestFlight and re-run the shortest critical-path smoke test.

## Optional Polish, Not Ship Blockers

- Improve leaderboard pagination and deeper multiplayer reconnect UX.
- Expand post-launch analytics instrumentation after validating privacy implications.
- Tighten ASO copy after first tester feedback and review mining.

## Go / No-Go Checklist

- `GO` only if all user-facing premium items are either registered in App Store Connect or intentionally hidden from this build.
- `GO` only if Sign in with Apple works on a real device and delete-account flow is verified.
- `GO` only if at least one full StoreKit sandbox purchase and one restore flow pass on device.
- `GO` only if Quick Play, Ranked, and Private Room each pass one end-to-end two-device run.
- `GO` only if screenshots, privacy disclosures, support URL, and review notes are all present in App Store Connect.
- `NO-GO` if the app still uses the placeholder App Store ID at release submission time.
