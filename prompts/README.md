# Theme Asset Prompts

This directory stores the source prompts for Floppy Duck hero background
artwork. Each theme has one Markdown file named after its
`BackgroundTheme.rawValue`, for example `underwater.md`, `lagoon.md`, and
`roughOcean.md`.

See [../ARTWORK.md](../ARTWORK.md) for the full artwork workflow: hero image
generation, runtime overlays, open-source overlay packs, processing rules, and
final asset catalog output paths.

## Current Prompt Scheme

All theme prompt files should use the hero-background scheme:
- `hero` — one coherent opaque full-scene image generated through Hugging Face
- `runtime overlays` — optional non-generated guidance for particles, tints,
  foreground trims, and obstacle skins

Some committed runtime assets may still exist in legacy suffixes such as
`background1`, `background3`, `foreground1`, and `foreground2`. Treat those as
runtime compatibility details, not as the source prompt format for new artwork.

## Prompt Conventions

Use a fenced code block under the `hero` heading. The hero image should carry the
theme identity by itself while preserving a readable central flight corridor.

Overlay notes should name deterministic app-controlled elements only. Do not ask
Hugging Face to generate separate overlay layers unless a theme explicitly needs
custom art that cannot be handled by reusable sprite packs.
