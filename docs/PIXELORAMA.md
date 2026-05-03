# Pixelorama Reference

Pixelorama is vendored as a Git submodule at `Pixelorama/` for reference only.
It is not integrated into the iOS app, build, asset catalog, or runtime.

## Current State

- Upstream: `https://github.com/Orama-Interactive/Pixelorama.git`
- Local commit audited: `801646b1`
- License: MIT, copyright Orama Interactive and contributors
- Project type: Godot 4.6.1 app
- Local executable status: no `godot` or `godot4` binary was found during the
  initial audit
- Floppy Duck source art status: no `.pxo`, `.ase`, `.aseprite`, or `.kra`
  files were present in the submodule when this note was created

## Why Keep It

Pixelorama is a credible pixel-art authoring and automation reference. It gives
us a known open-source editor, palette format, dither assets, and export flow to
study before we decide whether Floppy Duck should move theme art into editable
source files.

## Possible Uses

### 1. Authoritative Theme Source Files

If we start storing editable theme source art, `.pxo` files could become the
source of truth for hero, midground, foreground, and ground layers. Pixelorama's
CLI supports exporting files in headless mode, including regular image export,
spritesheets, JSON metadata, split layers, frame ranges, direction, scale, and
output path selection.

Action needed before this is usable:
- install Godot 4.6.1 or a compatible Pixelorama binary in local/CI tooling
- create a small proof-of-concept `.pxo` file for one non-shipping theme
- export it headlessly into a temporary folder
- compare the output against the game-rendered SpriteKit QA path
- decide whether `.pxo` belongs in the repo or in an external art source store

### 2. Sprite / Layer QA

`Pixelorama/addons/SmartSlicer/Classes/RegionUnpacker.gd` contains useful
opaque-region detection logic. A Swift or Python port could detect:

- foreground assets with unexpectedly huge opaque slabs
- midground sprites that extend into the flight corridor
- asset bounds that include accidental transparent padding
- disconnected opaque islands that should be separate sprites
- layers whose effective occupied rectangle differs from their intended recipe

This is directly relevant to theme QA because the runtime path is recipe-driven:
`ThemeRecipeCatalog` chooses asset names and layer heights, and
`ParallaxManager` renders those assets in SpriteKit.

### 3. Palette Tools

Pixelorama includes palette JSON files and palette manipulation code. The most
useful references are:

- `Pixelorama/pixelorama_data/Palettes/Default.json`
- `Pixelorama/pixelorama_data/Palettes/Pixelorama.json`
- `Pixelorama/src/Palette/Palette.gd`
- `Pixelorama/src/Autoload/Palettes.gd`
- `Pixelorama/src/Classes/ImageExtended.gd`

Potential Floppy Duck tooling:
- parse theme PNGs and summarize color counts per layer
- compare each theme against an expected palette
- flag smooth gradients where pixel-art dithering was expected
- quantize experimental generated art into a small palette before import

### 4. Dithering Reference

`Pixelorama/assets/dither-matrices/` contains Bayer dither matrices. These can
inform a small Python post-processing step for generated theme art or visual QA
experiments.

This is probably lower risk than porting Pixelorama code because the matrices are
small, easy to inspect, and easy to test against sample images.

### 5. Pattern and Brush Inspiration

The bundled brushes and patterns are useful as references for low-risk texture
ideas: grass clumps, brick, gravel, leaves, stone blocks, planks, marble, snow,
and simple star shapes.

Do not copy these into app assets casually. If any Pixelorama-provided asset is
imported into the app, record it in `THIRD_PARTY_ASSETS.md` with source, license,
file path, and processing notes.

## Non-Goals For Now

- Do not add Pixelorama to the Xcode project.
- Do not make the app depend on Godot.
- Do not replace the current SpriteKit render path.
- Do not commit generated Pixelorama build outputs.
- Do not treat Pixelorama as proof that the current foreground assets are
  correct; runtime QA must still use the SpriteKit path.

## Open Decisions

- Submodule versus copied vendor source: current choice is submodule because the
  folder is large and has its own upstream history.
- Whether `.pxo` files should live in this repo, a separate art repo, or release
  artifacts.
- Whether the first practical integration should be headless export, palette
  linting, or opaque-region QA.
- Whether Pixelorama asset usage requires additional attribution beyond the MIT
  license notice in this repo's third-party asset log.

