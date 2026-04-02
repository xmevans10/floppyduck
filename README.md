# 🦆 Floppy Duck

A retro iOS flappy-style game built with SpriteKit + SwiftUI.

## Current Status (April 2, 2026)

- `Shipped`: Classic solo mode, VS Bot ladder, shop, stats, settings, controller-wired gameplay, leaderboard polish, accessibility labels, haptics/audio polish.
- `Implemented`: Head-to-head multiplayer contracts (queue/room/matches/ratings), guest + Apple identity flows, and authoritative result polling.
- `In Hardening`: Two-device smoke validation, real App Store URL, screenshot verification, StoreKit/App Store Connect reconciliation, and final metadata/compliance checks.
- `Already In Repo`: App icon set and privacy manifest.

## Source Of Truth

- Launch readiness: [testflight.md](/Users/xanderevans/Documents/floppyduck/testflight.md)
- App Store copy and IAP inventory: [docs/APPSTORE_METADATA.md](/Users/xanderevans/Documents/floppyduck/docs/APPSTORE_METADATA.md)
- Business/operator playbooks: [marketing.md](/Users/xanderevans/Documents/floppyduck/marketing.md), [product.md](/Users/xanderevans/Documents/floppyduck/product.md), [research.md](/Users/xanderevans/Documents/floppyduck/research.md), [tracking.md](/Users/xanderevans/Documents/floppyduck/tracking.md), [growth.md](/Users/xanderevans/Documents/floppyduck/growth.md), [support.md](/Users/xanderevans/Documents/floppyduck/support.md), [monetization.md](/Users/xanderevans/Documents/floppyduck/monetization.md)

## Requirements

- Xcode 15.0+
- iOS 17.0+
- Swift 5.9+

## Getting Started

1. Open `FloppyDuck.xcodeproj` in Xcode.
2. Select your development team under Signing & Capabilities.
3. Build and run on simulator or device (`⌘R`).

## Architecture

| Layer | Technology | Purpose |
|-------|-----------|---------|
| `Game Engine` | SpriteKit | Physics, rendering, collisions |
| `UI` | SwiftUI | Menus, overlays, navigation |
| `Graphics` | Core Graphics | Programmatic pixel-art textures |
| `Backend` | Convex (REST) | Live auth + multiplayer contracts deployed |
| `Haptics` | UIKit | Tactile feedback on flap/score/death |

## Game Modes

- `Shipped` `Classic` - Solo endless run.
- `Shipped` `VS Bot` - Bot ladder progression.
- `Implemented` `Head to Head` - Quick Play / Ranked / Private Room UI + Convex contract wiring.
- `In Hardening` `Launch readiness` - Smoke validation, screenshot verification, and TestFlight/App Store completion.

## Project Structure

```text
FloppyDuck/
├── App/                    # App entry point + navigation
├── Game/                   # SpriteKit scene + physics constants
├── Models/                 # App state, stats, matchmaking/session models
├── Views/                  # SwiftUI screens
│   ├── HomeView            # Main menu
│   ├── MatchmakingView     # Multiplayer mode select + queue/room flows (scaffolded/in-progress)
│   ├── GameContainerView   # SpriteKit host + overlays + match result handling
│   └── Components/         # Reusable UI components
├── Services/               # Convex REST client
└── Utilities/              # PRNG, haptics, texture/icon/audio factories
```

## Multiplayer

### What exists now

- Matchmaking mode selection (Quick Play, Ranked, Private Room).
- Queue/room join flows with timeout and cancel handling.
- Head-to-head game config wiring (seed/opponent/match metadata).
- In-game score reporting + opponent score polling hooks.
- Match finish + stats application path (wins/losses/bread/ELO handling).

### What remains to ship

- End-to-end release smoke tests (auth + multiplayer) across two real devices.
- Screenshot verification across required sizes.
- Metadata, StoreKit, and compliance completion for TestFlight/App Store submission.

## Roadmap

- Launch hardening: real App Store URL, screenshot verification, StoreKit sandbox pass, and TestFlight/App Store Connect completion.
- Multiplayer resilience: reconnect handling, abandoned-match timeout UX, leaderboard pagination.
- Gameplay/performance: deterministic dynamic gaps, draw-call batching, on-device profiling.

## Credits

Built by Viktor AI for xmevans10.
