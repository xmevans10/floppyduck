# Floppy Duck — Quality Roadmap

> Current repo truth as of March 20, 2026.

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

### Test Baseline
- `xcodebuild test -project FloppyDuck.xcodeproj -scheme FloppyDuck -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:FloppyDuckTests -derivedDataPath build/DerivedData CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO`
- Current result: 106 tests passing.

## 🟡 Partial / Needs Verification

### Launch Hardening
- Launch screen assets exist, but `LaunchScreen.storyboard` still renders a black screen until the artwork is actually wired in.
- App Store metadata docs exist, but final screenshots, StoreKit sandbox validation, and TestFlight/submission checks still need verification.
- Head-to-head auth + multiplayer flows are implemented, but two-device smoke validation is still outstanding.

### Leaderboard
- UX polish is in place, but leaderboard loading is still fixed-limit rather than paginated.

## 🔴 Watchouts

- Controller extraction is no longer a "wire this next" roadmap item. It is live code and future refactors must preserve current `GameScene` behavior.
- Do not regress these recently revalidated behaviors:
  - full-radius / cap-aware bot collision envelope
  - ground-only physical collision after ghost-duck expiry
  - achievement signal callbacks that `GameScene` relies on for shield/debuff tracking

## 🔜 Next Up

### 1. Launch Hardening
- Replace the placeholder App Store URL in `GK.appStoreURL`.
- Wire `LaunchBackground` / `LaunchDuck` into `LaunchScreen.storyboard`.
- Verify screenshot CI output across all required sizes.
- Run StoreKit sandbox validation plus two-device auth/multiplayer smoke tests.
- Finalize TestFlight / App Store metadata and disclosure checks.

### 2. Multiplayer Resilience
- Reconnect cleanly when a head-to-head match backgrounds and returns.
- Add abandoned-match timeout / disconnect UX instead of indefinite polling.
- Add cursor-based leaderboard pagination.

### 3. Gameplay / Performance
- Explore dynamic gap difficulty without breaking deterministic multiplayer seeds.
- Investigate draw-call batching / atlas work where Instruments says it matters.
- Run on-device profiling to target real CPU / allocation hotspots before more refactors.
