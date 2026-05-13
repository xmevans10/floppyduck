#!/usr/bin/env python3
"""Render deterministic day-theme recipe assets and a gameplay preview.

These outputs are placeholders for authored Aseprite/LibreSprite exports. The
important contract is role separation: quiet hero, transparent horizon, opaque
ground, and transparent overlay sprites.
"""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "FloppyDuck" / "Assets.xcassets"
PREVIEWS = ROOT / "artifacts" / "theme_recipe_previews"

WORLD_W = 400
WORLD_H = 700
GROUND_H = 130


def write_imageset(name: str, image_1x: Image.Image, image_2x: Image.Image | None = None) -> None:
    folder = ASSETS / f"{name}.imageset"
    folder.mkdir(parents=True, exist_ok=True)
    image_1x.save(folder / f"{name}.png")
    if image_2x is not None:
        image_2x.save(folder / f"{name}@2x.png")

    contents = {
        "images": [
            {"filename": f"{name}.png", "idiom": "universal", "scale": "1x"},
            {
                **({"filename": f"{name}@2x.png"} if image_2x is not None else {}),
                "idiom": "universal",
                "scale": "2x",
            },
            {"idiom": "universal", "scale": "3x"},
        ],
        "info": {"author": "xcode", "version": 1},
    }
    (folder / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")


def blend(a: tuple[int, int, int], b: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return tuple(round(a[i] * (1 - t) + b[i] * t) for i in range(3))


def render_hero(scale: int = 1) -> Image.Image:
    width, height = 800 * scale, 570 * scale
    top = (58, 154, 242)
    middle = (96, 185, 246)
    bottom = (188, 232, 246)
    image = Image.new("RGBA", (width, height), top + (255,))
    pixels = image.load()

    for y in range(height):
        t = y / max(1, height - 1)
        color = blend(top, middle, min(1, t * 1.35)) if t < 0.70 else blend(middle, bottom, (t - 0.70) / 0.30)
        for x in range(width):
            pixels[x, y] = color + (255,)

    draw = ImageDraw.Draw(image, "RGBA")
    band_colors = [(81, 173, 244), (115, 199, 247), (196, 237, 250)]
    for idx, y in enumerate([205, 275, 342, 415, 488]):
        yy = y * scale
        draw.rectangle([0, yy, width, yy + 5 * scale], fill=band_colors[idx % len(band_colors)] + (255,))

    return image


def render_horizon(scale: int = 1) -> Image.Image:
    width, height = 800 * scale, 190 * scale
    image = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image, "RGBA")

    draw.polygon(
        [(0, 122 * scale), (84 * scale, 104 * scale), (178 * scale, 126 * scale),
         (304 * scale, 90 * scale), (432 * scale, 124 * scale), (560 * scale, 100 * scale),
         (682 * scale, 126 * scale), (800 * scale, 108 * scale), (800 * scale, height), (0, height)],
        fill=(118, 194, 172, 118),
    )
    draw.polygon(
        [(0, 151 * scale), (132 * scale, 126 * scale), (268 * scale, 150 * scale),
         (386 * scale, 118 * scale), (530 * scale, 150 * scale), (650 * scale, 128 * scale),
         (800 * scale, 150 * scale), (800 * scale, height), (0, height)],
        fill=(136, 212, 164, 142),
    )

    for x in [74, 156, 626, 718]:
        trunk = x * scale
        draw.rectangle([trunk, 116 * scale, trunk + 7 * scale, height], fill=(73, 132, 93, 132))
        draw.polygon(
            [(trunk - 16 * scale, 124 * scale), (trunk + 3 * scale, 80 * scale), (trunk + 26 * scale, 124 * scale)],
            fill=(64, 129, 97, 146),
        )
    return image


def render_ground(scale: int = 1) -> Image.Image:
    width, height = 800 * scale, 130 * scale
    lip = (159, 233, 82)
    accent = (219, 255, 135)
    body = (76, 155, 56)
    shadow = (54, 112, 62)
    image = Image.new("RGBA", (width, height), body + (255,))
    draw = ImageDraw.Draw(image, "RGBA")
    draw.rectangle([0, 0, width, 4 * scale], fill=accent + (255,))
    draw.rectangle([0, 4 * scale, width, 18 * scale], fill=lip + (255,))
    draw.rectangle([0, 18 * scale, width, 22 * scale], fill=(58, 135, 57, 255))

    for x in range(0, width, 52 * scale):
        draw.rectangle([x, 10 * scale, x + 10 * scale, 14 * scale], fill=(192, 245, 108, 255))
    for row, y in enumerate(range(42 * scale, height - 8 * scale, 24 * scale)):
        offset = (row * 31 * scale) % (84 * scale)
        for x in range(-offset, width, 108 * scale):
            draw.rectangle([x, y, x + 18 * scale, y + 3 * scale], fill=shadow + (255,))
    return image


def render_cloud_sheet(scale: int = 1) -> Image.Image:
    cell_w, cell_h = 48 * scale, 24 * scale
    image = Image.new("RGBA", (cell_w * 4, cell_h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image, "RGBA")
    specs = [
        [(5, 14, 16, 5), (15, 9, 14, 8), (29, 13, 12, 5)],
        [(4, 15, 14, 4), (13, 10, 13, 7), (26, 12, 17, 6)],
        [(7, 13, 11, 4), (18, 8, 12, 7), (30, 13, 10, 4)],
        [(5, 16, 12, 3), (14, 12, 10, 5), (25, 14, 14, 4)],
    ]
    shadow = (194, 229, 234, 255)
    light = (248, 253, 252, 255)
    mid = (218, 240, 242, 255)

    for frame, puffs in enumerate(specs):
        ox = frame * cell_w
        for x, y, w, h in puffs:
            draw.rectangle([ox + x * scale, y * scale, ox + (x + w) * scale, (y + h) * scale], fill=shadow)
        for x, y, w, h in puffs:
            draw.rectangle([ox + (x + 1) * scale, (y - 1) * scale, ox + (x + w - 2) * scale, (y + h - 3) * scale], fill=light)
        draw.rectangle([ox + 10 * scale, 17 * scale, ox + 36 * scale, 18 * scale], fill=mid)
    return image


def paste_fit(dest: Image.Image, src: Image.Image, box: tuple[int, int, int, int]) -> None:
    x0, y0, x1, y1 = box
    resized = src.resize((x1 - x0, y1 - y0), Image.Resampling.NEAREST)
    dest.alpha_composite(resized, (x0, y0))


def render_preview() -> Image.Image:
    preview = Image.new("RGBA", (WORLD_W, WORLD_H), (0, 0, 0, 255))
    paste_fit(preview, render_hero(1), (0, 0, WORLD_W, WORLD_H - GROUND_H))
    paste_fit(preview, render_horizon(1), (0, WORLD_H - GROUND_H - 190 + 8, WORLD_W, WORLD_H - GROUND_H + 8))

    cloud_sheet = render_cloud_sheet(1)
    cloud_positions = [(28, 54, 0), (246, 78, 1), (132, 190, 2), (308, 242, 3), (54, 318, 1)]
    for x, y, frame in cloud_positions:
        cloud = cloud_sheet.crop((frame * 48, 0, frame * 48 + 48, 24))
        preview.alpha_composite(cloud, (x, y))

    paste_fit(preview, render_ground(1), (0, WORLD_H - GROUND_H, WORLD_W, WORLD_H))

    draw = ImageDraw.Draw(preview, "RGBA")
    # Gameplay guides for preview only.
    draw.rectangle([0, 222, WORLD_W, 472], outline=(255, 255, 255, 70), width=1)
    draw.ellipse([74, 336, 122, 384], outline=(37, 73, 49, 190), width=3)
    draw.polygon([(92, 348), (92, 372), (125, 360)], fill=(236, 166, 52, 180))
    draw.rectangle([302, 0, 334, 252], outline=(54, 112, 62, 120), width=2)
    draw.rectangle([302, 448, 334, WORLD_H - GROUND_H], outline=(54, 112, 62, 120), width=2)
    return preview


def main() -> None:
    write_imageset("day_hero", render_hero(1), render_hero(2))
    write_imageset("day_horizon", render_horizon(1), render_horizon(2))
    write_imageset("day_ground", render_ground(1), render_ground(2))
    write_imageset("day_clouds", render_cloud_sheet(1), render_cloud_sheet(2))

    PREVIEWS.mkdir(parents=True, exist_ok=True)
    render_preview().save(PREVIEWS / "day_recipe_gameplay.png")


if __name__ == "__main__":
    main()
