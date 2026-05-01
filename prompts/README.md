# Theme Asset Prompts

Prompts used to generate pixel art parallax backgrounds for each Floppy Duck theme.

## Architecture
Each theme uses 4 layers:
- **background1** — Full sky/atmosphere (opaque, scrolls at 8 pt/s)
- **background3** — Distant terrain/horizon (transparent top, scrolls at 25 pt/s)
- **foreground1** — Close detailed terrain (transparent top, scrolls at 90 pt/s)
- **foreground2** — Ground strip (opaque, scrolls at 150 pt/s)

## Generation
- Model: GPT Image (via Viktor AI)
- Aspect ratio: 3:2 (1536×1024)
- Processing: crop to aspect → bg removal → alpha fringe cleanup → NEAREST downscale

## Background Removal
- **bg1, fg2**: Opaque (no removal)
- **bg3, fg1**: Flood fill from top row only (preserves light terrain content)
- Alpha fringe cleanup: threshold 220, 1 pass

## Style Guide
All prompts include this style block:
```
PIXEL ART STYLE:
- Detailed pixel art, fine pixels (1-3px), smooth gradients between similar colors
- Clean edges, rich shading with light/shadow sides
- Atmospheric perspective for depth, limited color palette
```

Terrain layers include:
```
Content fills from THE VERY BOTTOM EDGE upward.
BOTTOM ROW must be solid ground/terrain color, NOT white/sky.
The terrain should fill at minimum the bottom third of the image.
```
