# Artwork Pipeline

This document describes how Floppy Duck theme artwork moves from prompts to
runtime assets.

## Direction

Themes should use one generated hero background plus deterministic runtime
overlays. Do not generate separate AI background, midground, and foreground
images by default.

The practical target is:
- one coherent `hero` image per theme
- reusable overlay sprites/particles controlled by theme config
- optional custom foreground masks only when gameplay needs them

This keeps lighting, palette, and composition coherent while avoiding the common
AI failure where separately generated layers do not match each other.

## Prompt Files

Theme prompts live in `prompts/`. Each file is named with the exact
`BackgroundTheme.rawValue`, such as `day.md`, `underwater.md`, or
`roughOcean.md`.

Each prompt file should contain one generated image prompt:
- `hero`: the full-scene opaque background source

Prompts may also include a non-generated `runtime overlays` note describing what
the app should add on top of the hero image. Overlay notes are implementation
guidance, not Hugging Face image prompts.

## Hero Image Rules

Generate a polished full-scene pixel-art image that already contains the theme's
main identity. The image should look good by itself, but it must leave the play
area readable.

Required constraints:
- opaque full-frame image
- 16-bit pixel art or crisp pixel-art style
- wide 16:9 or 3:2 source, preferably at least `1536x864`
- no UI, text, logos, characters, player avatars, or pipes
- no bright clutter in the central duck flight corridor
- strongest detail belongs near the lower third and far edges
- avoid large foreground silhouettes that block gameplay
- avoid centered hero props unless they sit behind the flight corridor

## Runtime Overlays

Depth and motion should come from deterministic overlays, not separate AI
layers. Theme config can control:
- particles: stars, rain, snow, embers, bubbles, dust, sea spray
- atmospheric overlays: fog, haze, color tint, sunset glow, lightning flash
- low foreground trim: grass, rocks, foam, snow, city curb, ruins, lava edge
- obstacle skin: pipe palette, stone columns, neon posts, ice pillars
- optional tiny prop sprites at the bottom edges

Overlay sprites should be small, reusable, tintable, and gameplay-safe. They
should never occupy the main flight corridor unless they are purely atmospheric.

## Open Source Overlay Packs

Use CC0 packs first so we can recolor, crop, and ship without attribution or
commercial licensing friction.

Primary pack:
- Kenney Pixel Platformer
  - URL: `https://kenney-assets.itch.io/pixel-platformer`
  - License: CC0 1.0 Universal
  - Use for: generic blocks, ground trims, small props, platformer-style pieces,
    basic environment accents

Recommended companion packs:
- Kenney Pixel Platformer Blocks
  - URL: `https://kenney-assets.itch.io/pixel-platformer-blocks`
  - License: CC0 1.0 Universal
  - Use for: recolorable stone/rock/ground fragments and obstacle skins
- Kenney Pixel Platformer: Industrial Expansion
  - URL: `https://kenney-assets.itch.io/pixel-platformer-industrial-expansion`
  - License: CC0 1.0 Universal
  - Use for: barrels, crates, metal fragments, city/industrial overlays
- Kenney Pixel Platformer Farm Expansion
  - URL: `https://kenney-assets.itch.io/pixel-platformer-farm-expansion`
  - License: CC0 1.0 Universal
  - Use for: grass, crops, cozy ground trims, countryside props
- Kenney Tiny Dungeon
  - URL: `https://kenney-assets.itch.io/tiny-dungeon`
  - License: CC0 1.0 Universal
  - Use for: cave, ruins, stone, dungeon, and fantasy fragments

Desert-specific fallback packs:
- OpenGameArt / Liberated Pixel Cup Desert Tilesets by AdebGameSoft
  - URL: `https://lpc.opengameart.org/content/desert-tilesets`
  - License: CC0
  - Use for: Egypt/western desert tiles, rocks, vegetation, dune references
- OpenGameArt / Liberated Pixel Cup Desert tileset by CDmir
  - URL: `https://lpc.opengameart.org/content/desert-tileset-1`
  - License: CC0
  - Use for: 32x32 sand/desert tile source material

When importing any third-party art, keep a local license note beside the imported
asset folder even when attribution is not required.

## Hugging Face Generation Path

Achieve generation with Hugging Face Inference Providers or a Hugging Face Job
that reads one prompt file, generates the `hero` image, and writes the source
PNG to a durable local output path.

Recommended path:
- Read `prompts/{theme}.md` and extract the fenced prompt under `hero`.
- Use `black-forest-labs/FLUX.2-dev` for high-quality production attempts after
  accepting the model's Hugging Face terms. For cheaper iteration, use
  `black-forest-labs/FLUX.1-schnell`, `stabilityai/sdxl-turbo`, or
  `stabilityai/sd-turbo`.
- Generate at `1600x1240` when the provider supports it. This is exactly 2x the
  runtime hero panel (`800x620`) and avoids aspect-ratio cropping.
- Save source files as `{theme}_hero_source.png`.
- Record the chosen model, dimensions, seed, steps, and guidance in the theme
  prompt file or commit notes when final assets are accepted.

Do not generate fallback art locally when the task requires HF generation. Local
scripts are still appropriate for deterministic processing after the HF source
images exist.

## Processing

Process generated hero sources into final runtime dimensions:
- gameplay background: `800x620`
- preview card derivatives as required by the current UI

Use the hero import tool:

```bash
python3 tools/hero_art/import_hero.py pixelTokyo ~/Downloads/pixel-tokyo.png
```

Or generate through Hugging Face and import in one pass:

```bash
python3 -m pip install -r tools/hero_art/requirements.txt
cp tools/hero_art/.env.example tools/hero_art/.env
# edit tools/hero_art/.env and set HF_TOKEN
python3 tools/hero_art/generate_hf_hero.py pixelTokyo --import
```

`generate_hf_hero.py` reads the `## hero` prompt from `prompts/{theme}.md`.
The HF token must come from `HF_TOKEN` or `tools/hero_art/.env`; never commit
real tokens.

For a busy image, lightly dim the central flight corridor:

```bash
python3 tools/hero_art/import_hero.py pixelTokyo ~/Downloads/pixel-tokyo.png --darken-center 0.10
```

Processing should:
- crop for gameplay readability before resizing
- keep nearest-neighbor or pixel-preserving scaling
- palette-match only enough to keep catalog consistency
- preserve alpha at 255 for the hero image
- avoid over-dithering faces, readable landmarks, and sky gradients

Reusable overlay sprites from asset packs should be:
- extracted into repo-owned asset folders
- recolored per theme when needed
- scaled with nearest-neighbor only
- kept small enough to avoid gameplay obstruction

Existing tooling lives under `tools/pixel_art_engine/`; prefer extending that
pipeline over making one-off scripts when adding repeatable production steps.

## Outputs

Final hero PNGs should go in the Xcode asset catalog:

```text
FloppyDuck/Assets.xcassets/{theme}_hero.imageset/{theme}_hero.png
```

If the runtime still expects legacy parallax suffixes, generate compatibility
assets from the hero image rather than asking HF for separate layer art.

Each imageset must include a `Contents.json` that references the PNG at `1x`.

## Validation

Before shipping a theme:
- build the app with the iOS simulator scheme
- open Shop and Collection to verify the preview card renders
- launch gameplay with the theme selected
- confirm no missing asset warnings appear
- confirm the duck flight corridor remains readable
- confirm overlays animate without covering obstacles or the duck
- confirm existing legacy themes still load while the runtime migration is in
  progress
