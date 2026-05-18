# Third-Party Assets

This file tracks external art that is imported into the app.

## Animated Birds 32x32

- Source: https://opengameart.org/content/animated-birds-32x32
- Author: MoikMellah
- License: CC0
- Imported file: `FloppyDuck/Assets.xcassets/ambientBirds.imageset/ambientBirds.png`
- Processing: converted the magenta background to transparency; runtime recolors
  the sprite for theme readability.

## Animated Character

- Source: https://opengameart.org/content/animated-character
- Author: Sogomn
- License: CC0
- Imported file: `FloppyDuck/Assets.xcassets/Backgrounds/london_sprite_walker.imageset/london_sprite_walker@2x.png`
- Processing: cropped one 4-frame row from `guy.png` into a horizontal walking
  strip and recolored the clothing into a muted London commuter palette.

## Pixelorama Terrain Patterns

- Source: `pixelorama/pixelorama_data/Patterns/`
- Author: Orama Interactive and contributors
- License: MIT, tracked in `pixelorama/LICENSE`
- Imported files: none in the current production ground pass.
- Notes: kept as a viable MIT-licensed texture source, but the current
  regenerated ground strips are derived from first-party hero layers.

## Hero-Derived Ground Patterns

- Source: `FloppyDuck/Assets.xcassets/*_hero.imageset/*_hero.png`
- Author: first-party/generated in this repo
- Imported files: `FloppyDuck/Assets.xcassets/*_ground.imageset/*_ground.png`
- Processing: sampled each theme's hero layer, pixelated its luminance/motifs,
  and recolored through a per-theme material palette so ground strips tie back
  to the visible scene without importing new texture packs.

## Egypt Hero

- Source: generated in repo by `tools/theme_recipe/generate_ground_and_egypt_hero.py`
- Author: first-party/generated in this repo
- Imported file: `FloppyDuck/Assets.xcassets/egypt_hero.imageset/egypt_hero.png`
- Processing: generated a new pixel-art pyramid scene, composed so the sun and
  pyramids land inside the production portrait crop.

## Candidate Sources

These sources are safe candidates for future overlay/trim work but are not
imported unless listed above.

- Kenney game assets: https://kenney.nl/assets
  - Kenney documents game assets as public-domain licensed CC0.
- OpenGameArt Ground Tiles: https://opengameart.org/content/ground-tiles-0
  - CC0, useful future source if hero-derived patterns are not enough.
- OpenGameArt Pyramid Background: https://opengameart.org/content/pyramid-background-0
  - CC0, useful future source for alternate Egypt composition work.
- Tiny Surface 8x8 Tileset: https://prototypegames.itch.io/tiny-surface-tileset
  - CC0, useful future source for plains/autumn/desert material variation.
- Grassy Top-down Tileset: https://ringosnoop.itch.io/grassy-top-down-tileset
  - CC0, useful future source for grass, light dirt/sand, and water transitions.
