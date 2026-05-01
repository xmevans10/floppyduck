#!/usr/bin/env python3
"""Import a generated hero image into the FloppyDuck asset catalog.

Usage:
  python3 tools/hero_art/import_hero.py pixelTokyo ~/Downloads/tokyo.png

The script center-crops to the runtime hero aspect ratio, resizes to 800x620,
optionally quantizes color, and writes:
  FloppyDuck/Assets.xcassets/{theme}_hero.imageset/{theme}_hero.png
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image, ImageEnhance


OUT_W = 800
OUT_H = 620
TARGET_ASPECT = OUT_W / OUT_H


def center_crop_to_aspect(img: Image.Image, aspect: float) -> Image.Image:
    width, height = img.size
    current = width / height

    if current > aspect:
        new_width = round(height * aspect)
        left = (width - new_width) // 2
        return img.crop((left, 0, left + new_width, height))

    new_height = round(width / aspect)
    top = (height - new_height) // 2
    return img.crop((0, top, width, top + new_height))


def process_image(source: Path, colors: int, darken_center: float) -> Image.Image:
    img = Image.open(source).convert("RGBA")
    img = center_crop_to_aspect(img, TARGET_ASPECT)
    img = img.resize((OUT_W, OUT_H), Image.Resampling.LANCZOS)

    if darken_center > 0:
        overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
        pixels = overlay.load()
        cx0 = int(OUT_W * 0.24)
        cx1 = int(OUT_W * 0.62)
        cy0 = int(OUT_H * 0.18)
        cy1 = int(OUT_H * 0.78)
        alpha = int(max(0, min(0.4, darken_center)) * 255)
        for y in range(cy0, cy1):
            for x in range(cx0, cx1):
                pixels[x, y] = (0, 0, 0, alpha)
        img = Image.alpha_composite(img, overlay)

    if colors > 0:
        rgb = img.convert("RGB")
        quantized = rgb.quantize(colors=colors, method=Image.Quantize.MEDIANCUT)
        img = quantized.convert("RGBA")

    # A small contrast bump survives downsampling without making gameplay noisy.
    rgb = ImageEnhance.Contrast(img.convert("RGB")).enhance(1.04)
    return rgb.convert("RGBA")


def write_imageset(root: Path, theme: str, image: Image.Image) -> Path:
    imageset = root / "FloppyDuck" / "Assets.xcassets" / f"{theme}_hero.imageset"
    imageset.mkdir(parents=True, exist_ok=True)

    filename = f"{theme}_hero.png"
    image.save(imageset / filename)

    contents = {
        "images": [
            {
                "filename": filename,
                "idiom": "universal",
                "scale": "1x",
            },
            {
                "idiom": "universal",
                "scale": "2x",
            },
            {
                "idiom": "universal",
                "scale": "3x",
            },
        ],
        "info": {
            "author": "xcode",
            "version": 1,
        },
    }
    (imageset / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")
    return imageset / filename


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("theme", help="BackgroundTheme rawValue, e.g. pixelTokyo")
    parser.add_argument("source", type=Path, help="Generated source PNG/JPG")
    parser.add_argument("--repo", type=Path, default=Path.cwd())
    parser.add_argument("--colors", type=int, default=128, help="0 disables quantization")
    parser.add_argument(
        "--darken-center",
        type=float,
        default=0,
        help="Optional black overlay alpha for the central play corridor, 0.0-0.4",
    )
    args = parser.parse_args()

    image = process_image(args.source.expanduser(), args.colors, args.darken_center)
    output = write_imageset(args.repo.resolve(), args.theme, image)
    print(output)


if __name__ == "__main__":
    main()
