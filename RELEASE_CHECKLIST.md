# Floppy Duck Release Checklist

## Scope

This checklist tracks the path to a TestFlight-ready build.

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

## Multiplayer Smoke Gates

- [ ] Quick Play pairs two clients and starts with shared seed.
- [ ] Ranked pairs two clients and returns result payload with rating data.
- [ ] Private Room create/join works with valid 5-character code.
- [ ] Queue/room timeout and cancel paths exit cleanly.
- [ ] Match result persists stats (games, wins/losses, bread, ELO).

## Ready for TestFlight

Ship when all are true:

- [ ] Build/archive gates complete.
- [ ] Multiplayer smoke gates complete.
- [ ] Screenshot matrix complete.
- [ ] App metadata complete.
