# Floppy Duck TestFlight Runbook

Updated May 4, 2026.

## Purpose

Canonical launch-readiness source for getting Floppy Duck into TestFlight. [docs/APPSTORE_METADATA.md](docs/APPSTORE_METADATA.md) is the canonical product-page and IAP inventory source. [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md) and [LAUNCH_CHECKLIST.md](LAUNCH_CHECKLIST.md) are retained only as archived pointers.

## Already Code-Verified

- Release app config points at the production Convex deployment.
- Privacy manifest exists and declares a privacy-first posture with no ATT/tracking domains. PostHog analytics integration is covered by the existing privacy manifest.
- App Store metadata draft exists with ASO-optimized subtitle, keywords, and description (updated April 13).
- Legacy local stats decode safely even when older payloads are missing `peakElo`, `winStreak`, and `bestWinStreak`.
- Remote stats parsing accepts `peakElo`, `winStreak`, and `bestWinStreak` from backend payloads.
- Targeted unit coverage exists for stats migration, snapshot compatibility, and peak/streak behavior.
- **PowerUpController** — `remainingPipes` force-unwrap guarded to prevent crash on time-based power-ups.
- **TextureFactory / PixelIconFactory** — NSLock added around cache reads/writes and `isPreWarmed` to fix background `preWarm()` race condition.
- **Server-side score cap** — `MAX_SCORE = 500` applied to `reportScore` and `finishMatch` in `convex/matches.ts`.
- **Guest account deletion** — `deleteAccount` now resolves any authenticated user (guest or Apple-linked), fixing App Review guideline 5.1.1(v) compliance.
- **StoreKit config** — All 10 visible premium products are listed in `FloppyDuckProducts.storekit`: 3 duck skins, 3 pipe skins, 2 backgrounds, and 2 banners.

## Automation Available

- `bundle install` installs Fastlane from the repo `Gemfile`.
- `bundle exec fastlane ios setup_app` creates the App Store Connect app record for `com.xmevans10.FloppyDuck` if credentials permit it.
- `bundle exec fastlane ios register_iaps` registers missing non-consumable IAP records from `FloppyDuck/Config/FloppyDuckProducts.storekit`.
- `bundle exec fastlane ios build` creates the App Store archive and IPA using App Store export settings.
- `bundle exec fastlane ios metadata` uploads metadata from `fastlane/metadata` without submitting for review.
- `bundle exec fastlane ios upload` uploads `/tmp/FloppyDuckFastlane/FloppyDuck.ipa` to TestFlight.
- `REAL_APP_STORE_ID=1234567890 bundle exec fastlane ios set_app_store_id` replaces the placeholder App Store ID after the numeric ID exists.

## What David Needs to Do (Manual Blockers)

### 1. App Store Connect setup

- Create or confirm the App Store Connect app record, manually or with `bundle exec fastlane ios setup_app`.
- Get the real Apple app ID and replace the placeholder `GK.appStoreID = "000000000"` in `GameConstants.swift` before final release submission, manually or with `fastlane ios set_app_store_id`.
- Enter the metadata from [docs/APPSTORE_METADATA.md](docs/APPSTORE_METADATA.md), manually or with `bundle exec fastlane ios metadata`.
- Complete pricing, age rating, review contact info, and privacy disclosures.

### 2. Signing and Apple auth

- Enable Sign in with Apple on the App ID in the Apple Developer portal.
- Confirm the release provisioning profile includes the entitlement.
- Run the Sign in with Apple flow on a real device with release-style signing.

### 3. IAP reconciliation and StoreKit validation

- Register all 10 premium products in App Store Connect (3 skins, 3 pipe skins, 2 backgrounds, 2 banners), manually or with `bundle exec fastlane ios register_iaps`.
- Validate that App Store Connect product inventory matches `FloppyDuckProducts.storekit` and `APPSTORE_METADATA.md`.
- Run StoreKit sandbox purchases and restore flows on device.

### 4. On-device smoke test

- Fresh install → guest flow.
- Guest → Apple link flow.
- Returning user session restore.
- Sign out and delete account (test both guest and Apple-linked).
- Quick Play, Ranked, and Private Room on two devices.
- Shop browse, purchase, and restore.
- Offline / failed backend startup behavior.

### 5. Screenshot and asset package

- Generate the final screenshot matrix for required device sizes.
- Upload screenshots matching product page copy and current UI.
- Confirm icon and launch screen look correct on real devices.

### 6. Archive and upload

- Verify signing and release archive settings in Xcode.
- Archive the build manually or with `bundle exec fastlane ios build`.
- Upload to App Store Connect manually or with `bundle exec fastlane ios upload`.
- Install from TestFlight and re-run a quick critical-path smoke test.

## Final Push Order

1. ~~Run focused unit tests and fix any launch-critical failures.~~ ✅ Code fixes pushed.
2. Reconcile visible IAP inventory against App Store Connect.
3. Update the real App Store ID in code once the app record exists.
4. Verify signing, Sign in with Apple capability, and release archive settings in Xcode.
5. Run the on-device smoke test and two-device multiplayer.
6. Generate screenshots and finalize App Store Connect metadata/disclosures.
7. Archive and upload the build.
8. Install from TestFlight and re-run the shortest critical-path smoke test.

## Optional Polish, Not Ship Blockers

- Abandoned match timeout (server-side cron to clean stale matches/queue entries).
- VersusIntroView / SplashView timer chains — migrate from `asyncAfter` to `Task`-based sleep for cancellation safety.
- Rate limiting on `reportScore` mutation.
- Multiplayer network error retry logic.
- Improve leaderboard pagination.
- Tighten ASO copy after first tester feedback.

## Go / No-Go Checklist

- `GO` only if all 10 user-facing premium items are registered in App Store Connect or intentionally hidden from this build.
- `GO` only if Sign in with Apple works on a real device and delete-account flow is verified (both guest and Apple-linked).
- `GO` only if at least one full StoreKit sandbox purchase and one restore flow pass on device.
- `GO` only if Quick Play, Ranked, and Private Room each pass one end-to-end two-device run.
- `GO` only if screenshots, privacy disclosures, support URL, and review notes are all present in App Store Connect.
- `NO-GO` if the app still uses the placeholder App Store ID at release submission time.
