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


BASE_W = 800
BASE_H = 620
TARGET_ASPECT = BASE_W / BASE_H


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


def process_image(source: Path, colors: int, darken_center: float, scale: int) -> Image.Image:
    out_w = BASE_W * scale
    out_h = BASE_H * scale
    img = Image.open(source).convert("RGBA")
    img = center_crop_to_aspect(img, TARGET_ASPECT)
    img = img.resize((out_w, out_h), Image.Resampling.LANCZOS)

    if darken_center > 0:
        overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
        pixels = overlay.load()
        cx0 = int(out_w * 0.24)
        cx1 = int(out_w * 0.62)
        cy0 = int(out_h * 0.18)
        cy1 = int(out_h * 0.78)
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


def write_imageset(root: Path, theme: str, image_1x: Image.Image, image_2x: Image.Image | None) -> Path:
    imageset = root / "FloppyDuck" / "Assets.xcassets" / f"{theme}_hero.imageset"
    imageset.mkdir(parents=True, exist_ok=True)

    filename = f"{theme}_hero.png"
    image_1x.save(imageset / filename)

    filename_2x = None
    if image_2x is not None:
        filename_2x = f"{theme}_hero@2x.png"
        image_2x.save(imageset / filename_2x)

    contents = {
        "images": [
            {
                "filename": filename,
                "idiom": "universal",
                "scale": "1x",
            },
            {
                **({"filename": filename_2x} if filename_2x else {}),
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
    parser.add_argument("--scale", type=int, choices=[1, 2], default=1, help="Write 1x only, or 1x + @2x")
    parser.add_argument(
        "--darken-center",
        type=float,
        default=0,
        help="Optional black overlay alpha for the central play corridor, 0.0-0.4",
    )
    args = parser.parse_args()

    source = args.source.expanduser()
    image_1x = process_image(source, args.colors, args.darken_center, scale=1)
    image_2x = process_image(source, args.colors, args.darken_center, scale=2) if args.scale == 2 else None
    output = write_imageset(args.repo.resolve(), args.theme, image_1x, image_2x)
    print(output)


if __name__ == "__main__":
    main()
