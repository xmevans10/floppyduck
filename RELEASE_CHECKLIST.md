# Floppy Duck Release Checklist

## Scope

This checklist tracks the path to a TestFlight-ready build with production-safe auth and multiplayer.

## Critical Security and Environment Gates

- [ ] Apple identity token signature is verified against Apple JWKS in backend.
- [ ] Apple token claim checks enforced (`iss`, `aud`, `exp`, `nonce`).
- [ ] `APPLE_EXPECTED_AUDIENCES` is configured in Convex (comma-separated allowed audiences).
- [ ] `CONVEX_BASE_URL` in `Info.plist` is set to production deployment (`https://first-setter-743.convex.cloud`) for release.
- [ ] No dev deployment URL (`zany-ram-588`) exists in release app config.

## Apple Sign In Production Setup (Manual)

- [ ] App ID has **Sign in with Apple** capability enabled in Apple Developer portal.
- [ ] Release signing profile includes Sign in with Apple entitlement.
- [ ] Sign in with Apple flow succeeds on real device using production signing.
- [ ] Sign out and guest fallback flow succeeds on real device.

## Contract and Compatibility Gates

- [ ] Auth contracts validated end-to-end:
  - `auth:bootstrapGuest`
  - `auth:linkApple`
  - `auth:getProfile`
  - `auth:signOutSession`
- [ ] Multiplayer contracts validated end-to-end:
  - `matchmaking:*`
  - `matches:*`
  - `ratings:leaderboard`
- [ ] iOS parsing assumptions validated:
  - required IDs and `sessionToken` always present where expected
  - rating / ELO payload fields map correctly
  - server error messages render as user-safe UI copy

## Metadata

- [ ] App name, subtitle, and keywords finalized.
- [ ] App description and promotional text drafted.
- [ ] Privacy policy URL confirmed.
- [ ] Support URL confirmed.
- [ ] Age rating questionnaire completed.

## Screenshot Matrix

### iPhone 6.7"

- [ ] Home screen
- [ ] Classic gameplay
- [ ] VS Bot ladder
- [ ] Shop
- [ ] Stats
- [ ] Matchmaking / head-to-head

### iPhone 6.5"

- [ ] Home screen
- [ ] Classic gameplay
- [ ] VS Bot ladder
- [ ] Shop
- [ ] Stats
- [ ] Matchmaking / head-to-head

### iPhone 5.5" (if required by target metadata)

- [ ] Home screen
- [ ] Classic gameplay
- [ ] VS Bot ladder
- [ ] Shop
- [ ] Stats
- [ ] Matchmaking / head-to-head

## Build and App Quality Gates

- [ ] `Release` build compiles successfully.
- [ ] Archive succeeds in Xcode.
- [ ] App icon renders correctly on device and in archived app.
- [ ] Custom launch screen renders correctly on device.
- [ ] No placeholder copy in user-facing flow.
- [ ] No blocking runtime errors in startup/home/game-over paths.

## Auth Smoke Gates (2-device where applicable)

- [ ] Fresh install -> guest bootstrap succeeds.
- [ ] Guest -> Apple link succeeds and profile is retained.
- [ ] Returning Apple user restores authenticated state from session.
- [ ] Sign out returns to guest mode without app restart.
- [ ] Offline / backend failure path falls back without crash.

## Multiplayer Smoke Gates

- [ ] Quick Play pairs two clients and starts with shared seed.
- [ ] Ranked pairs two clients and returns result payload with rating data.
- [ ] Private Room create/join works with valid 5-character code.
- [ ] Queue/room timeout and cancel paths exit cleanly.
- [ ] Match result persists stats (games, wins/losses, bread, ELO).

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
