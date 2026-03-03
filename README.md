# 🦆 Floppy Duck

A multiplayer Flappy Bird-style game built native for iOS with SpriteKit + SwiftUI.

## Requirements

- Xcode 15.0+
- iOS 17.0+
- Swift 5.9+

## Getting Started

1. Open `FloppyDuck.xcodeproj` in Xcode
2. Select your development team under Signing & Capabilities
3. Build & Run on simulator or device (⌘R)

## Architecture

| Layer | Technology | Purpose |
|-------|-----------|---------|
| **Game Engine** | SpriteKit | Physics, rendering, collision detection |
| **UI** | SwiftUI | Menus, overlays, navigation |
| **Graphics** | Core Graphics | All textures generated programmatically |
| **Backend** | Convex (REST) | Multiplayer state, matchmaking, ratings |
| **Haptics** | UIKit | Tactile feedback on flap, score, death |

## Game Modes

- **Quick Play** — instant matchmaking against the next available player
- **Ranked** — ELO-based matchmaking (K=32, ±300 rating window)
- **Single Player** — classic solo Flappy Bird
- **Private Rooms** — create/join with 5-character room codes

## Project Structure

```
FloppyDuck/
├── App/                    # App entry point, navigation
├── Game/                   # SpriteKit scene, physics constants
├── Models/                 # Game state, player stats, match types
├── Views/                  # SwiftUI screens and components
│   ├── HomeView            # Main menu with mode cards
│   ├── GameContainerView   # SpriteKit host + overlays
│   ├── MatchmakingView     # Search animation + timer
│   └── Components/         # Reusable UI (ModeCard, StatBadge)
├── Services/               # Convex REST client
└── Utilities/              # PRNG, haptics, texture factory
```

## Multiplayer

Uses seeded PRNG so both players see identical pipe layouts. The Convex backend handles:
- Match creation and joining
- Real-time state sync
- ELO rating calculation
- Matchmaking queue

## Credits

Built by Viktor AI for xmevans10.
