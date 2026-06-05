# Floppy Duck

Retro iOS flappy-style game built with SpriteKit, SwiftUI, and a Convex multiplayer backend.

## Start Here

1. Open `FloppyDuck.xcodeproj` in Xcode.
2. Select a development team under Signing & Capabilities.
3. Build and run the `FloppyDuck` scheme on an iOS simulator or device.

Requirements: Xcode 15.0+, iOS 17.0+, Swift 5.9+.

## Repository Map

```text
FloppyDuck/             iOS app source, assets, and bundled audio
FloppyDuck/Audio/       Music, quacks, SFX, and QA source audio
FloppyDuckTests/        Unit and integration tests
FloppyDuckUITests/      Screenshot and UI performance tests
convex/                 Convex backend functions and schema
docs/                   Launch, product, art, public-site, and archive docs
fastlane/               App Store Connect and TestFlight automation
prompts/                Theme prompt sources
scripts/                Repo automation and generation helpers
tools/                  Local art and recipe tooling
artifacts/              Generated or review-only art outputs
midground-prod/         Production midground source exports
Pixelorama/             Vendored Pixelorama reference submodule
```

## Common References

- Launch readiness: [docs/launch/TESTFLIGHT_RUNBOOK.md](docs/launch/TESTFLIGHT_RUNBOOK.md)
- Documentation index: [docs/README.md](docs/README.md)
- Audio QA package: [FloppyDuck/Audio/README.md](FloppyDuck/Audio/README.md)
- App Store metadata: [docs/APPSTORE_METADATA.md](docs/APPSTORE_METADATA.md)
- Product roadmap: [docs/product/ROADMAP.md](docs/product/ROADMAP.md)
- Artwork pipeline: [docs/art/ARTWORK.md](docs/art/ARTWORK.md)

## App Structure

```text
FloppyDuck/
├── App/                 App entry point and navigation shell
├── Assets.xcassets/     Runtime visual assets
├── Audio/               Runtime audio and sound-designer QA sources
├── Config/              StoreKit and app configuration
├── Game/                SpriteKit scene, controllers, and game constants
├── Models/              App state, unlocks, themes, skins, and multiplayer models
├── Services/            Auth, analytics, identity, and Convex clients
├── Utilities/           Audio, haptics, PRNG, textures, and pixel UI helpers
└── Views/               SwiftUI screens and reusable components
```

## Validation

- Project sync: `ruby scripts/xcode/check_project_sync.rb`
- Unit tests: `xcodebuild test -project FloppyDuck.xcodeproj -scheme FloppyDuck -only-testing:FloppyDuckTests`
- Screenshot tests: `xcodebuild test -project FloppyDuck.xcodeproj -scheme FloppyDuck -only-testing:FloppyDuckUITests/ScreenshotTests`
