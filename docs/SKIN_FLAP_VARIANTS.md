# Skin Flap Variants

- Run `swift -module-cache-path .DerivedData/SwiftModuleCache scripts/generate_skin_wing_variants.swift --only <skin>` for a single skin, or omit `--only` for all root `* final.png` skins.
- Finalized sources live at repo root as `{skin} final.png`; `bearskin.png` is included as a supplemental source.
- The generator removes white backgrounds, trims detached guide/bounding artifacts, pads a transparent canvas, and writes review frames to `artifacts/skin_wing_variants/<skin>/`.
- It also copies production frames to `FloppyDuck/Assets.xcassets/DuckSkins/duckskin_<skin>_<frame>.imageset/`.
- `wing_down` is the canonical black-outlined triangle. `wing_up` uses the same right-edge anchor and flips from the same top start line.
- Keep per-skin wing tuning in `wingAnchorXOffset(for:block:)`; move both up/down together.
- If frame dimensions change, update `DuckSkin.productionFrameSize` so gameplay keeps mallard body sizing.
