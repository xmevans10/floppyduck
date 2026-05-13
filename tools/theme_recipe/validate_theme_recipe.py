#!/usr/bin/env python3
"""Validate the day theme recipe asset contract."""

from __future__ import annotations

import json
import statistics
import sys
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "FloppyDuck" / "Assets.xcassets"

EXPECTED = {
    "day_hero": (800, 570),
    "day_horizon": (800, 190),
    "day_ground": (800, 130),
    "day_clouds": (192, 24),
}

MAX_LUMINANCE_VARIANCE = 0.15
MAX_OVERLAY_DENSITY = 0.30


def fail(message: str) -> None:
    print(f"FAIL: {message}")
    raise SystemExit(1)


def load_image(name: str) -> Image.Image:
    folder = ASSETS / f"{name}.imageset"
    if not folder.exists():
        fail(f"missing imageset {folder}")

    contents_path = folder / "Contents.json"
    if not contents_path.exists():
        fail(f"missing Contents.json for {name}")

    try:
        contents = json.loads(contents_path.read_text())
    except json.JSONDecodeError as exc:
        fail(f"invalid Contents.json for {name}: {exc}")

    filename = None
    for image in contents.get("images", []):
        if image.get("scale") == "1x" and image.get("filename"):
            filename = image["filename"]
            break
    if filename is None:
        fail(f"{name} has no assigned 1x image")

    path = folder / filename
    if not path.exists():
        fail(f"{name} references missing file {filename}")
    return Image.open(path).convert("RGBA")


def check_dimensions(name: str, image: Image.Image) -> None:
    expected = EXPECTED[name]
    if image.size != expected:
        fail(f"{name} dimensions {image.size} != expected {expected}")


def check_ground_alpha(image: Image.Image) -> None:
    top_row = [image.getpixel((x, 0))[3] for x in range(image.width)]
    if any(alpha != 255 for alpha in top_row):
        fail("day_ground top row must be fully opaque")


def check_fully_opaque(name: str, image: Image.Image) -> None:
    extrema = image.getchannel("A").getextrema()
    if extrema != (255, 255):
        fail(f"{name} must be fully opaque; alpha extrema are {extrema}")


def check_horizon_transparency(image: Image.Image) -> None:
    alpha = image.getchannel("A")
    if alpha.getextrema()[0] != 0:
        fail("day_horizon must include transparent pixels")


def luminance(pixel: tuple[int, int, int, int]) -> float:
    r, g, b, _ = pixel
    return (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255


def check_hero_luminance(image: Image.Image) -> None:
    y0 = int(image.height * 0.25)
    y1 = int(image.height * 0.75)
    samples = [
        luminance(image.getpixel((x, y)))
        for y in range(y0, y1, 8)
        for x in range(0, image.width, 8)
    ]
    variance = statistics.pstdev(samples)
    if variance > MAX_LUMINANCE_VARIANCE:
        fail(f"day_hero protected corridor luminance variance {variance:.3f} > {MAX_LUMINANCE_VARIANCE:.3f}")


def check_overlay_density(image: Image.Image) -> None:
    alpha = image.getchannel("A")
    cell_w, cell_h = 48, 24
    for frame in range(image.width // cell_w):
        crop = alpha.crop((frame * cell_w, 0, frame * cell_w + cell_w, cell_h))
        opaque = sum(1 for value in crop.tobytes() if value > 0)
        density = opaque / (cell_w * cell_h)
        if density > MAX_OVERLAY_DENSITY:
            fail(f"day_clouds frame {frame} opaque density {density:.3f} > {MAX_OVERLAY_DENSITY:.3f}")


def main() -> None:
    images = {name: load_image(name) for name in EXPECTED}
    for name, image in images.items():
        check_dimensions(name, image)

    check_ground_alpha(images["day_ground"])
    check_fully_opaque("day_hero", images["day_hero"])
    check_fully_opaque("day_ground", images["day_ground"])
    check_horizon_transparency(images["day_horizon"])
    check_hero_luminance(images["day_hero"])
    check_overlay_density(images["day_clouds"])

    print("PASS: day recipe assets satisfy the pilot contract")


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception as exc:
        print(f"FAIL: unexpected validator error: {exc}")
        sys.exit(1)
