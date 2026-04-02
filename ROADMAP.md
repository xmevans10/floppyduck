# Floppy Duck — Quality Roadmap

> Current repo truth as of April 2, 2026.

## ✅ Done

### Gameplay / Architecture
- `ParallaxManager`, `BotController`, and `PowerUpController` are extracted and wired into `GameScene`.
- Death particles, reduce-motion support, and leaderboard accessibility/polish landed on `main`.
- Controller parity now has regression coverage for:
  - bot collision envelope matching current `GameScene` behavior
  - ghost-duck expiry restoring the non-drifting collision mask
  - power-up collection / shield callbacks preserving achievement signals

### Release Assets Already Present
- Pixel-art app icons exist in `Assets.xcassets/AppIcon.appiconset`.
- Privacy manifest exists in `FloppyDuck/PrivacyInfo.xcprivacy`.
- Screenshot CI workflow exists in `.github/workflows/ci.yml`.

### Launch Hardening (Code-Side)
- `LaunchScreen.storyboard` wired: `LaunchBackground` (full-bleed, scaleAspectFill) and `LaunchDuck` (centered, 200×137.5) with proper Auto Layout constraints.
- `GK.appStoreURL` refactored to `URL?` via `makeAppStoreURL(appID:)` — returns `nil` for placeholder `"000000000"`. Callers (`HomeView`, `GameContainerView`) handle nil safely.
- Test coverage: `testPlaceholderAppStoreIDDoesNotProduceShareURL` and `testRealAppStoreIDProducesShareURL`.
- `Info.plist` `CONVEX_BASE_URL` already set to production (`first-setter-743`). No dev URL present.
- Backward-compatible stats decoding now preserves older local saves and inbound cloud stats after the addition of `peakElo`, `winStreak`, and `bestWinStreak`.
- App Store metadata drafted in `docs/APPSTORE_METADATA.md`. Privacy policy and support pages live in `docs/`.

### Test Baseline
- `xcodebuild test -project FloppyDuck.xcodeproj -scheme FloppyDuck -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:FloppyDuckTests/PlayerStatsTests -derivedDataPath build/DerivedData CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO`
- Current result: 22 `PlayerStatsTests` passing after the stats migration fix.

## 🟡 Partial / Needs Verification

### Launch Hardening
- Canonical launch runbook is now `testflight.md`.
- App Store metadata docs exist, but final screenshots, StoreKit sandbox validation, and TestFlight/submission checks still need verification.
- Head-to-head auth + multiplayer flows are implemented, but two-device smoke validation is still outstanding.
- `GK.appStoreID` is still the placeholder `"000000000"` — needs the real ID once the app is registered in App Store Connect.

### Leaderboard
- UX polish is in place, but leaderboard loading is still fixed-limit rather than paginated.

## 🔴 Watchouts

- Controller extraction is no longer a "wire this next" roadmap item. It is live code and future refactors must preserve current `GameScene` behavior.
- Do not regress these recently revalidated behaviors:
  - full-radius / cap-aware bot collision envelope
  - ground-only physical collision after ghost-duck expiry
  - achievement signal callbacks that `GameScene` relies on for shield/debuff tracking

## 🔜 Next Up

### 1. Launch Hardening (Remaining)
- Replace `GK.appStoreID` placeholder with real App Store ID once assigned.
- Verify screenshot CI output across all required sizes (run on device/simulator).
- Run StoreKit sandbox validation plus two-device auth/multiplayer smoke tests.
- Finalize TestFlight / App Store metadata and disclosure checks.
- Complete the remaining manual launch items in `testflight.md`.

### 2. Multiplayer Resilience
- Reconnect cleanly when a head-to-head match backgrounds and returns.
- Add abandoned-match timeout / disconnect UX instead of indefinite polling.
- Add cursor-based leaderboard pagination.

### 3. Gameplay / Performance
- Explore dynamic gap difficulty without breaking deterministic multiplayer seeds.
- Investigate draw-call batching / atlas work where Instruments says it matters.
- Run on-device profiling to target real CPU / allocation hotspots before more refactors.
