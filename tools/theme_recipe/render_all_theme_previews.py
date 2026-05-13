#!/usr/bin/env python3
"""Render gameplay-sized QA previews for every theme recipe.

The renderer mirrors the static layer stack in ThemeRecipeCatalog and the
placement rules in ParallaxManager: 400x700 world, 80pt ground height, 800pt
wide tiles, SpriteKit-style bottom-left anchors, and z-position ordering.
"""

from __future__ import annotations

import json
import math
from dataclasses import dataclass
from pathlib import Path
from typing import Literal

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "FloppyDuck" / "Assets.xcassets"
OUT = ROOT / "artifacts" / "theme_recipe_previews" / "all_themes"

WORLD_W = 400
WORLD_H = 700
GROUND_H = 80
TILE_W = WORLD_W * 2

Anchor = Literal["top", "ground", "horizon"]


@dataclass(frozen=True)
class Layer:
    role: str
    asset: str
    z: int
    height: int
    anchor: Anchor
    tiles: int
    horizon_offset: int = 0
    is_ground: bool = False


def y_for(layer: Layer) -> int:
    if layer.anchor == "top":
        return GROUND_H
    if layer.anchor == "ground":
        return 0
    return GROUND_H + layer.horizon_offset


def make_layer(
    role: str,
    asset: str,
    z: int,
    height: int,
    anchor: Anchor,
    tiles: int = 2,
    horizon_offset: int = 0,
    is_ground: bool = False,
) -> Layer:
    return Layer(role, asset, z, height, anchor, tiles, horizon_offset, is_ground)


def recipe(
    hero: tuple[str, int, Anchor],
    clouds: tuple[str, int, Anchor, int] | None,
    midground: tuple[str, int, Anchor],
    ground: str | None,
    ground_base: str | None,
) -> list[Layer]:
    layers = [
        make_layer("hero", hero[0], -85, hero[1], hero[2], tiles=2),
    ]
    if clouds is not None:
        layers.append(make_layer("clouds", clouds[0], -70, clouds[1], clouds[2], tiles=2, horizon_offset=clouds[3]))
    layers.append(make_layer("midground", midground[0], -40, midground[1], midground[2], tiles=2))
    if ground_base is not None:
        layers.append(make_layer("groundBase", ground_base, 45, 100, "ground", tiles=3, is_ground=True))
    if ground is not None:
        layers.append(make_layer("ground", ground, 50, GROUND_H, "ground", tiles=3, is_ground=True))
    return layers


THEMES: dict[str, list[Layer]] = {
    "day": recipe(("day_hero", 620, "top"), ("day_clouds", 150, "horizon", 350), ("day_midground_trees", 183, "top"), "day_foreground2", "day_foreground3"),
    "sunset": recipe(("sunset_hero", 620, "top"), ("sunset_clouds", 150, "horizon", 350), ("sunset_midground_trees", 200, "top"), "sunset_foreground2", "sunset_foreground3"),
    "night": recipe(("night_hero", 620, "top"), ("night_clouds", 150, "horizon", 350), ("night_midground_trees", 300, "ground"), "night_foreground2", "night_foreground3"),
    "neonCity": recipe(("neonCity_hero", 620, "top"), ("neonCity_clouds", 150, "horizon", 350), ("neonCity_midground_buildings", 400, "ground"), "neonCity_foreground2", "neonCity_foreground3"),
    "underwater": recipe(("underwater_hero", 620, "top"), None, ("underwater_midground_coral", 400, "ground"), "underwater_foreground2", "underwater_foreground3"),
    "volcano": recipe(("volcano_hero", 620, "top"), ("volcano_clouds", 150, "horizon", 350), ("volcano_midground_rocks", 250, "top"), "volcano_foreground2", "volcano_foreground3"),
    "arctic": recipe(("arctic_hero", 620, "top"), ("arctic_clouds", 150, "horizon", 350), ("arctic_midground_trees", 300, "top"), "arctic_foreground2", "arctic_foreground3"),
    "western": recipe(("western_hero", 620, "top"), ("western_clouds", 150, "horizon", 350), ("western_midground_rocks", 250, "top"), "western_foreground2", "western_foreground3"),
    "jungle": recipe(("jungle_hero", 620, "top"), ("jungle_clouds", 150, "horizon", 350), ("jungle_midground_trees", 300, "top"), "jungle_foreground2", "jungle_foreground3"),
    "cave": recipe(("cave_hero", 620, "top"), None, ("cave_midground_rocks", 400, "ground"), "cave_foreground2", "cave_foreground3"),
    "mountain": recipe(("mountain_hero", 620, "top"), ("mountain_clouds", 150, "horizon", 350), ("mountain_midground_trees", 200, "top"), "mountain_foreground2", "mountain_foreground3"),
    "space": recipe(("space_hero", 620, "top"), None, ("space_midground_rocks", 250, "top"), "space_foreground2", "space_foreground3"),
    "pixelTokyo": recipe(("pixelTokyo_hero", 620, "top"), ("pixelTokyo_clouds", 150, "horizon", 350), ("pixelTokyo_midground_buildings", 350, "ground"), "pixelTokyo_foreground2", "pixelTokyo_foreground3"),
    "egypt": recipe(("egypt_hero", 620, "top"), ("egypt_clouds", 150, "horizon", 350), ("egypt_midground_ruins", 350, "top"), "egypt_foreground2", "egypt_foreground3"),
    "lagoon": recipe(("lagoon_hero", 620, "top"), ("lagoon_clouds", 150, "horizon", 350), ("lagoon_midground_palms", 300, "top"), "lagoon_foreground2", "lagoon_foreground3"),
    "losAngeles": recipe(("losAngeles_hero", 620, "top"), ("losAngeles_clouds", 150, "horizon", 350), ("losAngeles_midground_palms", 300, "top"), "losAngeles_foreground2", "losAngeles_foreground3"),
    "london": recipe(("london_hero", 620, "top"), ("london_clouds", 150, "horizon", 350), ("london_midground_buildings", 350, "ground"), "london_foreground2", "london_foreground3"),
    "roughOcean": recipe(("roughOcean_hero", 620, "top"), ("roughOcean_clouds", 150, "horizon", 350), ("roughOcean_midground_shore", 300, "top"), None, None),
}


def imageset_dir(asset: str) -> Path | None:
    direct = ASSETS / f"{asset}.imageset"
    if direct.exists():
        return direct
    matches = sorted(ASSETS.glob(f"**/{asset}.imageset"))
    return matches[0] if matches else None


def image_for(asset: str) -> Image.Image:
    folder = imageset_dir(asset)
    if folder is None:
        raise FileNotFoundError(f"missing imageset: {asset}")
    contents = json.loads((folder / "Contents.json").read_text())
    filenames = [img.get("filename") for img in contents.get("images", []) if img.get("filename")]
    preferred = [f"{asset}.png", "1x.png", filenames[0] if filenames else ""]
    for name in preferred + filenames:
        if name and (folder / name).exists():
            return Image.open(folder / name).convert("RGBA")
    raise FileNotFoundError(f"missing image file in imageset: {asset}")


def fit_nearest(image: Image.Image, width: int, height: int) -> Image.Image:
    return image.resize((width, height), Image.Resampling.NEAREST)


def composite_layer(base: Image.Image, layer: Layer) -> None:
    src = fit_nearest(image_for(layer.asset), TILE_W, layer.height)
    y_bottom = y_for(layer)
    y_top = WORLD_H - y_bottom - layer.height
    for i in range(layer.tiles):
        x = i * TILE_W
        if x >= WORLD_W:
            break
        base.alpha_composite(src, (x, y_top))


def render_theme(theme: str, layers: list[Layer]) -> Image.Image:
    canvas = Image.new("RGBA", (WORLD_W, WORLD_H), (0, 0, 0, 255))
    for layer in sorted(layers, key=lambda item: item.z):
        composite_layer(canvas, layer)
    return canvas


def add_label(image: Image.Image, label: str) -> Image.Image:
    out = Image.new("RGBA", (image.width, image.height + 28), (20, 22, 25, 255))
    out.alpha_composite(image, (0, 0))
    draw = ImageDraw.Draw(out)
    font = ImageFont.load_default()
    draw.text((8, image.height + 8), label, fill=(240, 240, 240, 255), font=font)
    return out


def contact_sheet(files: list[Path], output: Path, cols: int = 6) -> None:
    thumbs = []
    for file in files:
        thumb = Image.open(file).convert("RGBA")
        thumb = thumb.resize((160, 280), Image.Resampling.NEAREST)
        thumbs.append(add_label(thumb, file.stem))
    rows = math.ceil(len(thumbs) / cols)
    sheet = Image.new("RGBA", (cols * 160, rows * 308), (20, 22, 25, 255))
    for idx, thumb in enumerate(thumbs):
        x = (idx % cols) * 160
        y = (idx // cols) * 308
        sheet.alpha_composite(thumb, (x, y))
    sheet.save(output)


def render_layer_breakdown(theme: str, layers: list[Layer]) -> Image.Image:
    scale = 0.45
    width = int(WORLD_W * scale)
    height = int(WORLD_H * scale)
    panels = []
    for index in range(1, len(layers) + 1):
        partial = Image.new("RGBA", (WORLD_W, WORLD_H), (0, 0, 0, 255))
        ordered = sorted(layers, key=lambda item: item.z)
        for layer in ordered[:index]:
            composite_layer(partial, layer)
        label = " + ".join(layer.role for layer in ordered[:index])
        panel = partial.resize((width, height), Image.Resampling.NEAREST)
        panels.append(add_label(panel, label))

    gap = 8
    out = Image.new("RGBA", (len(panels) * width + (len(panels) - 1) * gap, height + 28), (20, 22, 25, 255))
    for idx, panel in enumerate(panels):
        out.alpha_composite(panel, (idx * (width + gap), 0))
    return out


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    individual = []
    missing: dict[str, str] = {}

    for theme, layers in THEMES.items():
        try:
            image = render_theme(theme, layers)
        except FileNotFoundError as exc:
            missing[theme] = str(exc)
            continue
        path = OUT / f"{theme}.png"
        image.save(path)
        individual.append(path)
        render_layer_breakdown(theme, layers).save(OUT / f"{theme}_layers.png")

    contact_sheet(individual, OUT / "all_themes_contact_sheet.png")
    manifest = {
        "world": {"width": WORLD_W, "height": WORLD_H, "groundHeight": GROUND_H},
        "themesRendered": [path.stem for path in individual],
        "missing": missing,
        "notes": "Matches ThemeRecipeCatalog layer definitions and ParallaxManager static placement; runtime particle overlays are not included.",
    }
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")

    if missing:
        for theme, error in missing.items():
            print(f"{theme}: {error}")
        raise SystemExit(1)
    print(f"Rendered {len(individual)} themes to {OUT}")


if __name__ == "__main__":
    main()
