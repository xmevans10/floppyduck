# Floppy Duck Release Checklist

## Scope

This checklist tracks the path to a TestFlight-ready build with production-safe auth and multiplayer.

---

## Audit Summary

> Audited March 20, 2026. Items marked ✅ are verified code-side. Items marked
> 🔧 need Xcode, device, or manual portal work that can't be done from code alone.

| Category | Total | ✅ Code-verified | 🔧 Needs Xcode / Device / Portal |
|---|---|---|---|
| Security & Environment | 5 | 2 | 3 |
| Apple Sign In Setup | 4 | 0 | 4 |
| Contract & Compatibility | 3 | 0 | 3 |
| Metadata | 5 | 4 | 1 |
| Screenshot Matrix | 18 | 0 | 18 |
| Build & App Quality | 6 | 2 | 4 |
| Auth Smoke | 5 | 0 | 5 |
| Multiplayer Smoke | 5 | 0 | 5 |

---

## Critical Security and Environment Gates

- [x] ✅ `CONVEX_BASE_URL` in `Info.plist` is set to production deployment (`https://first-setter-743.convex.cloud`) for release.
- [x] ✅ No dev deployment URL (`zany-ram-588`) exists in release app config.
  > Verified: grep across entire `FloppyDuck/` directory shows zero matches for `zany-ram` or any other dev URL.
- [ ] 🔧 Apple identity token signature is verified against Apple JWKS in backend.
  > Requires: Convex backend code review / deployment inspection.
- [ ] 🔧 Apple token claim checks enforced (`iss`, `aud`, `exp`, `nonce`).
  > Requires: Convex backend code review.
- [ ] 🔧 `APPLE_EXPECTED_AUDIENCES` is configured in Convex (comma-separated allowed audiences).
  > Requires: Convex dashboard / environment variable check.

## Apple Sign In Production Setup (Manual)

> All items require Apple Developer portal access and a real device.

- [ ] 🔧 App ID has **Sign in with Apple** capability enabled in Apple Developer portal.
- [ ] 🔧 Release signing profile includes Sign in with Apple entitlement.
- [ ] 🔧 Sign in with Apple flow succeeds on real device using production signing.
- [ ] 🔧 Sign out and guest fallback flow succeeds on real device.

## Contract and Compatibility Gates

> All items require a running backend + device/simulator.

- [ ] 🔧 Auth contracts validated end-to-end:
  - `auth:bootstrapGuest`
  - `auth:linkApple`
  - `auth:getProfile`
  - `auth:signOutSession`
- [ ] 🔧 Multiplayer contracts validated end-to-end:
  - `matchmaking:*`
  - `matches:*`
  - `ratings:leaderboard`
- [ ] 🔧 iOS parsing assumptions validated:
  - required IDs and `sessionToken` always present where expected
  - rating / ELO payload fields map correctly
  - server error messages render as user-safe UI copy

## Metadata

- [x] ✅ App name, subtitle, and keywords finalized.
  > `docs/APPSTORE_METADATA.md` — "Floppy Duck", "Pixel Flap. Retro Quack.", keywords within 100 chars.
- [x] ✅ App description and promotional text drafted.
  > `docs/APPSTORE_METADATA.md` — full description and promo text present.
- [x] ✅ Privacy policy URL confirmed.
  > `https://xmevans10.github.io/floppyduck/privacy.html` — page exists in `docs/privacy.html`.
- [x] ✅ Support URL confirmed.
  > `https://xmevans10.github.io/floppyduck/support.html` — referenced in metadata.
- [ ] 🔧 Age rating questionnaire completed.
  > Requires: App Store Connect submission. Metadata doc says 4+.

## Screenshot Matrix

> CI workflow exists in `.github/workflows/ci.yml` and UI tests capture 13 screenshots.
> These need to be run on simulators at each required size to produce final assets.

### iPhone 6.7"

- [ ] 🔧 Home screen
- [ ] 🔧 Classic gameplay
- [ ] 🔧 VS Bot ladder
- [ ] 🔧 Shop
- [ ] 🔧 Stats
- [ ] 🔧 Matchmaking / head-to-head

### iPhone 6.5"

- [ ] 🔧 Home screen
- [ ] 🔧 Classic gameplay
- [ ] 🔧 VS Bot ladder
- [ ] 🔧 Shop
- [ ] 🔧 Stats
- [ ] 🔧 Matchmaking / head-to-head

### iPhone 5.5" (if required by target metadata)

- [ ] 🔧 Home screen
- [ ] 🔧 Classic gameplay
- [ ] 🔧 VS Bot ladder
- [ ] 🔧 Shop
- [ ] 🔧 Stats
- [ ] 🔧 Matchmaking / head-to-head

## Build and App Quality Gates

- [ ] 🔧 `Release` build compiles successfully.
- [ ] 🔧 Archive succeeds in Xcode.
- [x] ✅ App icon renders correctly on device and in archived app.
  > Pixel-art icons present in `Assets.xcassets/AppIcon.appiconset` with all required sizes. Final device check still recommended.
- [x] ✅ Custom launch screen renders correctly on device.
  > `LaunchScreen.storyboard` now wires `LaunchBackground` (full-bleed) and `LaunchDuck` (centered). Final device check still recommended.
- [ ] 🔧 No placeholder copy in user-facing flow.
  > Code-side grep found no placeholder text in `FloppyDuck/` (no TODO/FIXME/lorem/dummy strings). `GK.appStoreID` is `"000000000"` but the share sheet gracefully omits the URL when nil. Recommend a manual UI walkthrough to confirm.
- [ ] 🔧 No blocking runtime errors in startup/home/game-over paths.

## Auth Smoke Gates (2-device where applicable)

> All items require device + running Convex backend.

- [ ] 🔧 Fresh install -> guest bootstrap succeeds.
- [ ] 🔧 Guest -> Apple link succeeds and profile is retained.
- [ ] 🔧 Returning Apple user restores authenticated state from session.
- [ ] 🔧 Sign out returns to guest mode without app restart.
- [ ] 🔧 Offline / backend failure path falls back without crash.

## Multiplayer Smoke Gates

> All items require 2 devices + running Convex backend.

- [ ] 🔧 Quick Play pairs two clients and starts with shared seed.
- [ ] 🔧 Ranked pairs two clients and returns result payload with rating data.
- [ ] 🔧 Private Room create/join works with valid 5-character code.
- [ ] 🔧 Queue/room timeout and cancel paths exit cleanly.
- [ ] 🔧 Match result persists stats (games, wins/losses, bread, ELO).

## Ready for TestFlight

Ship when all are true:

- [ ] Security and environment gates complete.
- [ ] Apple Sign In production setup complete.
- [ ] Contract and compatibility gates complete.
- [ ] Build/archive gates complete.
- [ ] Auth smoke gates complete.
- [ ] Multiplayer smoke gates complete.
- [ ] Screenshot matrix complete.
- [ ] App metadata complete.
