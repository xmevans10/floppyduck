# Pixel Art Engine

Custom C tool and Python pipeline for generating production-quality pixel art background themes for FloppyDuck.

## Full Pipeline

```
GPT Image 2 → background removal → downscale to 200×155 → C dither engine → 4x upscale → xcassets
```

### Step by step

1. **AI Generation** — GPT Image 2 generates raw layer artwork per theme with specific prompts ensuring content stays in the lower portion (upper 60%+ clear for the duck to fly through)
2. **Background Removal** — Transparent backgrounds extracted so layers composite correctly
3. **Downscale** — Raw images downscaled to native resolution (200×155 for most layers, 200×20 for ground, 200×25 for overlay)
4. **C Dither Engine** — `pixelart_engine` applies Floyd-Steinberg or ordered dithering to curated 5-7 color palettes, adds texture noise and pixel outlines
5. **4x Upscale** — PIL nearest-neighbor upscale to final resolution (800×620, 800×80, 800×100)
6. **xcassets** — Output PNGs placed in `FloppyDuck/Assets.xcassets/{theme}_{layer}.imageset/`

## Build the C Engine

```bash
gcc -O2 -o pixelart_engine pixelart_engine.c -lm
```

Requires `stb_image.h` and `stb_image_write.h` (included in `stb/`).

## Engine Commands

| Command | Description |
|---------|-------------|
| `dither_fs <in> <out> <colors...>` | Floyd-Steinberg dither to palette |
| `dither_ordered <in> <out> <size> <colors...>` | Ordered (Bayer) dither |
| `texture <in> <out> <amount> [seed]` | Add pixel texture noise |
| `outline <in> <out> <color> [threshold]` | Add pixel outlines |
| `gradient <out> <w> <h> <c1> <c2> <dir> <dither>` | Dithered gradient |
| `composite <base> <overlay> <out> [ox] [oy]` | Alpha composite |
| `quantize <in> <out> <n_colors> [dither_type]` | Reduce colors |

## Production Pipeline Script

`all_themes_production.py` generates all 17 themes end-to-end:

```bash
# Dependencies
pip install Pillow numpy openai httpx

# Set your OpenAI API key
export OPENAI_API_KEY=sk-...

# Run all themes (or edit THEMES list to run specific ones)
python all_themes_production.py
```

The script:
- Defines all 17 theme configurations (palettes, prompts, layer content)
- Calls GPT Image 2 for each layer's raw artwork
- Processes through background removal → downscale → dither → upscale
- Outputs to `output_production/{theme}/` with 9 PNGs per theme

### Adding a New Theme

1. Add theme config to `THEMES` dict in `all_themes_production.py` with:
   - Color palette (5-7 colors)
   - Layer descriptions for all 9 layers
   - Sky/atmosphere colors
2. Run the script
3. Copy outputs to xcassets: `{theme}_{layer}.imageset/{theme}_{layer}.png`
4. Ensure each imageset has a `Contents.json` referencing the PNG

## Key Design Principles

- Each layer gets a **curated 5-7 color palette** (no smooth gradients)
- Dithering creates authentic retro transitions between palette colors
- Texture noise breaks up flat fills for organic feel
- Alpha preserved — transparent areas stay transparent for layer compositing
- Every theme has completely unique assets, palettes, and art content
- Content lives in the **lower portion** — upper 60%+ clear sky for gameplay

## Game Architecture

- **9 layers per theme**: background1-3, midground1-3, foreground1-3
- **Native resolution**: 200×155 → 4x upscale to 800×620
- **Ground (foreground2)**: 200×20 → 800×80
- **Overlay (foreground3)**: 200×25 → 800×100
- **xcassets path**: `FloppyDuck/Assets.xcassets/{theme}_{layer}.imageset/`

## Themes

17 total themes: day, sunset, night, neonCity, pixelTokyo, underwater, volcano, arctic, western, jungle, egypt, cave, mountain, space, lagoon, losAngeles, london

## Files

| File | Purpose |
|------|---------|
| `pixelart_engine.c` | C dither/texture/outline engine |
| `stb/` | stb single-header image libraries |
| `all_themes_production.py` | Full production pipeline for all themes |
| `example_volcano.py` | Standalone volcano theme example |
| `pixel_utils.py` | Shared Python utilities |
