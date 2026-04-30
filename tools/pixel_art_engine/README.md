# Pixel Art Engine

Custom C tool for generating production-quality pixel art with real dithering.

## Build
```bash
gcc -O2 -o pixelart_engine pixelart_engine.c -lm
```

## Pipeline (per layer)
1. **Python/PIL** draws raw shapes at native 200×155
2. **pixelart_engine** applies Floyd-Steinberg or ordered dithering to curated palette
3. **pixelart_engine** adds texture noise for organic feel
4. **pixelart_engine** adds pixel outlines where needed
5. **PIL** 4x nearest-neighbor upscale to 800×620

## Commands
- `dither_fs <input> <output> <color1> [color2] ...` — Floyd-Steinberg dither to palette
- `dither_ordered <input> <output> <size> <color1> ...` — Ordered (Bayer) dither
- `texture <input> <output> <amount> [seed]` — Add pixel texture noise
- `outline <input> <output> <color> [threshold]` — Add pixel outlines
- `gradient <output> <w> <h> <c1> <c2> <dir> <dither>` — Dithered gradient
- `composite <base> <overlay> <output> [ox] [oy]` — Alpha composite
- `quantize <input> <output> <n_colors> [dither_type]` — Reduce colors

## Key Design Principles
- Each layer gets a **curated 5-7 color palette** (no smooth gradients)
- Dithering creates transitions between palette colors
- Texture noise breaks up flat fills
- Alpha is preserved — transparent areas stay transparent for proper layer compositing
- Every theme needs completely unique assets and palettes

## Example
See `example_volcano.py` for the full volcano theme implementation.

## Game Architecture
- 9 layers per theme: bg1-3, mid1-3, fg1-3
- Native resolution: 200×155 → 4x upscale to 800×620
- Ground (fg2): 200×20 → 800×80
- Overlay (fg3): 200×25 → 800×100  
- All assets go in `FloppyDuck/Assets.xcassets/{theme}_{layer}.imageset/`
- 17 themes total: day, sunset, night, neonCity, pixelTokyo, underwater, volcano, arctic, western, jungle, egypt, cave, mountain, space, lagoon, losAngeles, london
