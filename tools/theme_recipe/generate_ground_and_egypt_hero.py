#!/usr/bin/env python3
"""Generate ground strips from each theme's hero layer.

The ground output keeps the existing asset catalog names. Each strip is derived
from the matching `*_hero` image, deliberately downsampled and nearest-neighbor
scaled so the result reads as pixelated terrain tied to the scene palette.
"""

from __future__ import annotations

import json
import math
import random
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageOps


ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "FloppyDuck" / "Assets.xcassets"
MANIFEST = ROOT / "artifacts" / "theme_recipe_previews" / "ground_texture_manifest.json"

GROUND_W = 800
GROUND_H = 80
HERO_W = 800
HERO_H = 620


@dataclass(frozen=True)
class ThemeStyle:
    material: str
    surface: str
    crop: tuple[float, float]
    accent_bias: str
    colors: tuple[tuple[int, int, int], tuple[int, int, int], tuple[int, int, int]]


THEMES: dict[str, ThemeStyle] = {
    "day": ThemeStyle("hero-derived grass/dirt", "grass", (0.48, 0.92), "green", ((58, 45, 34), (103, 78, 47), (122, 179, 72))),
    "sunset": ThemeStyle("hero-derived warm field", "grass", (0.50, 0.94), "warm", ((75, 43, 36), (139, 88, 48), (196, 149, 67))),
    "night": ThemeStyle("hero-derived dark grass", "grass", (0.44, 0.90), "dark", ((20, 25, 29), (42, 56, 48), (72, 104, 72))),
    "neonCity": ThemeStyle("hero-derived neon pavement", "paved", (0.50, 0.96), "neon", ((20, 20, 34), (48, 44, 70), (72, 230, 225))),
    "underwater": ThemeStyle("hero-derived seabed", "sand", (0.45, 0.92), "aqua", ((35, 62, 70), (80, 122, 113), (139, 176, 142))),
    "volcano": ThemeStyle("hero-derived basalt/lava", "stone", (0.44, 0.94), "lava", ((25, 20, 20), (63, 44, 35), (224, 72, 28))),
    "arctic": ThemeStyle("hero-derived snow/ice", "snow", (0.42, 0.90), "ice", ((95, 134, 160), (175, 208, 222), (240, 250, 250))),
    "western": ThemeStyle("hero-derived desert sand", "sand", (0.48, 0.95), "warm", ((88, 58, 40), (151, 105, 56), (226, 175, 89))),
    "jungle": ThemeStyle("hero-derived jungle floor", "grass", (0.45, 0.93), "green", ((33, 44, 34), (61, 80, 45), (68, 163, 64))),
    "cave": ThemeStyle("hero-derived cave rock", "stone", (0.34, 0.90), "crystal", ((27, 25, 38), (57, 49, 68), (68, 176, 194))),
    "mountain": ThemeStyle("hero-derived alpine ground", "snow", (0.50, 0.94), "green", ((61, 76, 72), (118, 140, 121), (223, 237, 229))),
    "lagoon": ThemeStyle("hero-derived beach turf", "grass", (0.50, 0.95), "aqua", ((75, 73, 49), (143, 122, 70), (78, 184, 102))),
    "losAngeles": ThemeStyle("hero-derived dry park soil", "grass", (0.50, 0.95), "warm", ((73, 48, 40), (124, 86, 52), (158, 156, 78))),
    "london": ThemeStyle("hero-derived wet embankment", "paved", (0.52, 0.96), "gray", ((37, 40, 43), (75, 77, 78), (129, 130, 122))),
    "roughOcean": ThemeStyle("hero-derived storm shore", "stone", (0.45, 0.94), "aqua", ((22, 35, 44), (43, 61, 70), (90, 137, 145))),
    "space": ThemeStyle("hero-derived alien regolith", "stone", (0.42, 0.94), "violet", ((37, 33, 52), (76, 67, 94), (153, 116, 218))),
    "pixelTokyo": ThemeStyle("hero-derived city path", "paved", (0.50, 0.96), "pink", ((42, 40, 58), (82, 74, 92), (216, 103, 146))),
    "egypt": ThemeStyle("hero-derived pyramid sand", "sand", (0.48, 0.95), "warm", ((93, 60, 35), (160, 111, 55), (232, 178, 86))),
}


def mix(a: tuple[int, int, int], b: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return tuple(max(0, min(255, int(a[i] * (1 - t) + b[i] * t))) for i in range(3))


def luminance(c: tuple[int, int, int]) -> float:
    return (c[0] * 0.2126 + c[1] * 0.7152 + c[2] * 0.0722) / 255


def hero_path(theme: str) -> Path:
    return ASSETS / f"{theme}_hero.imageset" / f"{theme}_hero.png"


def load_hero(theme: str) -> Image.Image:
    path = hero_path(theme)
    if not path.exists():
        raise FileNotFoundError(path)
    return Image.open(path).convert("RGB").resize((HERO_W, HERO_H), Image.Resampling.NEAREST)


def quantized_palette(image: Image.Image, count: int = 8) -> list[tuple[int, int, int]]:
    paletted = image.quantize(colors=count, method=Image.Quantize.MEDIANCUT)
    palette = paletted.getpalette() or []
    colors = paletted.getcolors(maxcolors=image.width * image.height) or []
    ranked: list[tuple[int, tuple[int, int, int]]] = []
    for amount, index in colors:
        i = index * 3
        color = tuple(palette[i:i + 3])
        if len(color) == 3:
            ranked.append((amount, color))
    ranked.sort(reverse=True)
    return [color for _, color in ranked]


def choose_accent(palette: list[tuple[int, int, int]], bias: str) -> tuple[int, int, int]:
    def score(color: tuple[int, int, int]) -> float:
        r, g, b = color
        if bias == "green":
            return g * 1.8 - r * 0.45 - b * 0.25
        if bias == "aqua":
            return (g + b) * 1.2 - r * 0.45
        if bias == "lava":
            return r * 1.6 + g * 0.4 - b
        if bias == "ice":
            return r + g + b + b * 0.5
        if bias == "neon":
            return abs(r - g) + abs(g - b) + max(r, g, b)
        if bias == "pink":
            return r * 1.3 + b * 0.8 - g * 0.35
        if bias == "violet":
            return b * 1.5 + r * 0.8 - g * 0.2
        if bias == "gray":
            return 255 - (abs(r - g) + abs(g - b) + abs(r - b))
        if bias == "dark":
            return 255 - (r + g + b) / 3
        return r * 1.2 + g * 0.8 - b * 0.25

    return max(palette, key=score) if palette else (128, 128, 128)


def posterize_pixelate(image: Image.Image, width: int = 160, height: int = 16) -> Image.Image:
    tiny = image.resize((width, height), Image.Resampling.BILINEAR)
    tiny = ImageOps.posterize(tiny.convert("RGB"), 4)
    return tiny.resize((GROUND_W, GROUND_H), Image.Resampling.NEAREST).convert("RGBA")


def colorize_from_luminance(image: Image.Image, style: ThemeStyle, width: int = 160, height: int = 16) -> Image.Image:
    tiny = image.resize((width, height), Image.Resampling.BILINEAR).convert("RGB")
    tiny = ImageOps.posterize(tiny, 4)
    dark, mid, light = style.colors
    out = Image.new("RGBA", tiny.size)
    src = tiny.load()
    dst = out.load()
    for y in range(tiny.height):
        depth = y / max(1, tiny.height - 1)
        for x in range(tiny.width):
            lum = luminance(src[x, y])
            if lum < 0.45:
                color = mix(dark, mid, lum / 0.45)
            else:
                color = mix(mid, light, (lum - 0.45) / 0.55)
            color = mix(color, dark, depth * 0.14)
            dst[x, y] = (*color, 255)
    return out.resize((GROUND_W, GROUND_H), Image.Resampling.NEAREST)


def crop_source(hero: Image.Image, style: ThemeStyle) -> Image.Image:
    y0 = int(hero.height * style.crop[0])
    y1 = int(hero.height * style.crop[1])
    band = hero.crop((0, y0, hero.width, y1)).filter(ImageFilter.GaussianBlur(radius=0.4))
    return band


def draw_surface(img: Image.Image, style: ThemeStyle, palette: list[tuple[int, int, int]], accent: tuple[int, int, int], seed: int) -> None:
    rng = random.Random(seed)
    d = ImageDraw.Draw(img)
    colors = sorted(palette or [(90, 70, 50)], key=luminance)
    dark = colors[0]
    mid = colors[len(colors) // 2]
    light = colors[-1]

    if style.surface == "grass":
        d.rectangle((0, 0, GROUND_W, 5), fill=(*mix(accent, light, 0.25), 255))
        d.line((0, 6, GROUND_W, 6), fill=(*mix(accent, dark, 0.45), 255))
        for _ in range(135):
            x = rng.randrange(0, GROUND_W)
            h = rng.randrange(2, 8)
            sway = rng.choice([-1, 0, 1])
            d.line((x, 6, x + sway, max(0, 6 - h)), fill=(*mix(accent, light, rng.random() * 0.35), 255))
    elif style.surface == "snow":
        d.rectangle((0, 0, GROUND_W, 7), fill=(*mix(light, (255, 255, 255), 0.35), 255))
        d.line((0, 8, GROUND_W, 8), fill=(*mix(mid, dark, 0.22), 255))
        for _ in range(80):
            x = rng.randrange(0, GROUND_W)
            y = rng.randrange(1, 35)
            d.rectangle((x, y, x + rng.randrange(1, 5), y), fill=(*mix(light, accent, 0.18), 255))
    elif style.surface == "sand":
        d.rectangle((0, 0, GROUND_W, 7), fill=(*mix(light, accent, 0.18), 255))
        d.line((0, 8, GROUND_W, 8), fill=(*mix(mid, dark, 0.22), 255))
        for _ in range(115):
            x = rng.randrange(0, GROUND_W)
            y = rng.randrange(6, GROUND_H)
            d.line((x, y, min(GROUND_W - 1, x + rng.randrange(4, 16)), y + rng.choice([-1, 0, 0, 1])), fill=(*mix(light, accent, rng.random() * 0.45), 255))
    elif style.surface == "paved":
        d.rectangle((0, 0, GROUND_W, 5), fill=(*mix(mid, light, 0.25), 255))
        for y in range(12, GROUND_H, 17):
            d.line((0, y, GROUND_W, y + rng.choice([-1, 0, 1])), fill=(*mix(dark, mid, 0.28), 255))
        for x in range(rng.randrange(0, 18), GROUND_W, 31):
            d.line((x, 6, x + rng.choice([-2, -1, 0, 1, 2]), GROUND_H), fill=(*mix(dark, accent, 0.18), 255))
    else:
        d.rectangle((0, 0, GROUND_W, 5), fill=(*mix(mid, light, 0.15), 255))
        d.line((0, 7, GROUND_W, 7), fill=(*mix(dark, mid, 0.3), 255))
        for _ in range(70):
            x = rng.randrange(0, GROUND_W)
            y = rng.randrange(12, GROUND_H - 3)
            w = rng.randrange(3, 10)
            d.polygon([(x, y), (x + w, y + 1), (x + w - 2, y + 4), (x + 1, y + 3)], fill=(*mix(mid, light, rng.random() * 0.4), 255))


def draw_material_marks(img: Image.Image, style: ThemeStyle, palette: list[tuple[int, int, int]], accent: tuple[int, int, int], seed: int) -> None:
    rng = random.Random(seed + 701)
    d = ImageDraw.Draw(img)
    colors = sorted(palette or [(90, 70, 50)], key=luminance)
    dark = colors[0]
    light = colors[-1]
    if style.accent_bias == "lava":
        for _ in range(18):
            x = rng.randrange(0, GROUND_W)
            y = rng.randrange(20, GROUND_H - 2)
            d.line((x, y, x + rng.randrange(8, 28), y + rng.randrange(-2, 3)), fill=(*mix(accent, light, 0.25), 255))
    elif style.accent_bias in {"aqua", "neon", "pink", "violet", "crystal"}:
        for _ in range(38):
            x = rng.randrange(0, GROUND_W)
            y = rng.randrange(12, GROUND_H)
            d.rectangle((x, y, x + rng.randrange(1, 4), y), fill=(*mix(accent, light, rng.random() * 0.45), 255))
    else:
        for _ in range(95):
            x = rng.randrange(0, GROUND_W)
            y = rng.randrange(15, GROUND_H)
            color = light if rng.random() < 0.48 else dark
            d.point((x, y), fill=(*color, 255))


def render_ground(theme: str, style: ThemeStyle) -> Image.Image:
    hero = load_hero(theme)
    crop = crop_source(hero, style)
    palette = quantized_palette(crop, 9)
    accent = choose_accent(palette, style.accent_bias)

    ground = colorize_from_luminance(crop, style)
    seed = sum(ord(c) for c in theme)

    # Blend in a second offset hero crop so repeated horizon/dune/tree shapes
    # become terrain texture instead of a literal mini-copy of the hero.
    offset = Image.new("RGB", crop.size)
    offset.paste(crop.crop((crop.width // 3, 0, crop.width, crop.height)), (0, 0))
    offset.paste(crop.crop((0, 0, crop.width // 3, crop.height)), (crop.width - crop.width // 3, 0))
    offset = colorize_from_luminance(offset, style, 120, 12)
    ground = Image.blend(ground, offset, 0.32)

    draw_surface(ground, style, palette, accent, seed)
    draw_material_marks(ground, style, palette, accent, seed)
    return ground.convert("RGBA")


def save_imageset(name: str, image: Image.Image) -> None:
    directory = ASSETS / f"{name}.imageset"
    directory.mkdir(parents=True, exist_ok=True)
    image.save(directory / f"{name}.png")
    image.resize((image.width * 2, image.height * 2), Image.Resampling.NEAREST).save(directory / f"{name}@2x.png")
    contents = {
        "images": [
            {"filename": f"{name}.png", "idiom": "universal", "scale": "1x"},
            {"filename": f"{name}@2x.png", "idiom": "universal", "scale": "2x"},
            {"idiom": "universal", "scale": "3x"},
        ],
        "info": {"author": "xcode", "version": 1},
    }
    (directory / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")


def gradient(draw: ImageDraw.ImageDraw, y0: int, y1: int, top: tuple[int, int, int], bottom: tuple[int, int, int], w: int) -> None:
    for y in range(y0, y1):
        t = (y - y0) / max(1, y1 - y0 - 1)
        draw.line((0, y, w, y), fill=mix(top, bottom, t))


def jagged_dune(draw: ImageDraw.ImageDraw, y: int, amp: int, color: tuple[int, int, int], phase: float) -> None:
    points = [(0, 310)]
    for x in range(0, 401, 10):
        yy = y + int(math.sin((x * 0.035) + phase) * amp + math.sin((x * 0.011) + phase * 1.7) * amp * 0.55)
        points.append((x, yy))
    points.extend([(400, 310), (0, 310)])
    draw.polygon(points, fill=color)


def render_egypt_hero() -> Image.Image:
    low = Image.new("RGB", (400, 310))
    d = ImageDraw.Draw(low)
    gradient(d, 0, 176, (70, 150, 192), (242, 187, 99), 400)
    gradient(d, 176, 310, (229, 157, 72), (126, 75, 43), 400)

    d.ellipse((164, 42, 210, 88), fill=(255, 235, 141))
    for r, color in [(34, (247, 203, 112)), (48, (231, 176, 91))]:
        d.ellipse((187 - r, 65 - r, 187 + r, 65 + r), outline=color)

    for cloud in [(28, 48, 94), (196, 35, 270), (106, 85, 174)]:
        x0, y0, x1 = cloud
        for x in range(x0, x1, 14):
            h = 7 + ((x + y0) % 11)
            d.rectangle((x, y0, x + 21, y0 + h), fill=(244, 207, 139))
            d.rectangle((x + 4, y0 + h, x + 25, y0 + h + 3), fill=(199, 125, 74))

    d.rectangle((0, 176, 400, 179), fill=(209, 135, 68))
    for x, y, w, h in [(62, 132, 72, 60), (129, 126, 82, 68), (262, 148, 46, 39)]:
        d.polygon([(x, y + h), (x + w // 2, y), (x + w, y + h)], fill=(168, 102, 45))
        d.polygon([(x + w // 2, y), (x + w, y + h), (x + w // 2, y + h)], fill=(222, 159, 70))
        d.line((x + w // 2, y, x + w // 2, y + h), fill=(115, 72, 43))
        for yy in range(y + 12, y + h, 8):
            d.line((x + 8, yy, x + w - 8, yy + 2), fill=(133, 82, 43))

    jagged_dune(d, 202, 10, (222, 157, 72), 0.3)
    jagged_dune(d, 231, 16, (186, 111, 53), 1.4)
    jagged_dune(d, 266, 22, (125, 72, 43), 2.2)

    rng = random.Random(2405)
    for _ in range(2600):
        x = rng.randrange(0, 400)
        y = rng.randrange(0, 310)
        r, g, b = low.getpixel((x, y))
        target = (255, 229, 146) if rng.random() < 0.55 else (92, 59, 48)
        low.putpixel((x, y), mix((r, g, b), target, 0.12))

    return low.resize((HERO_W, HERO_H), Image.Resampling.NEAREST).convert("RGBA")


def save_hero(image: Image.Image) -> None:
    directory = ASSETS / "egypt_hero.imageset"
    image.save(directory / "egypt_hero.png")
    image.resize((HERO_W * 2, HERO_H * 2), Image.Resampling.NEAREST).save(directory / "egypt_hero@2x.png")
    contents = {
        "images": [
            {"filename": "egypt_hero.png", "idiom": "universal", "scale": "1x"},
            {"filename": "egypt_hero@2x.png", "idiom": "universal", "scale": "2x"},
        ],
        "info": {"author": "xcode", "version": 1},
    }
    (directory / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")


def main() -> None:
    # Egypt hero is generated first so egypt_ground derives from the new hero.
    save_hero(render_egypt_hero())

    manifest = {
        "sources": [
            {
                "name": "Theme hero layers",
                "license": "first-party/generated in repo",
                "local": "FloppyDuck/Assets.xcassets/*_hero.imageset/*_hero.png",
            }
        ],
        "grounds": {},
        "hero": {"theme": "egypt", "asset": "egypt_hero", "source": "generated in repo"},
    }
    for theme, style in THEMES.items():
        img = render_ground(theme, style)
        save_imageset(f"{theme}_ground", img)
        manifest["grounds"][theme] = {
            "asset": f"{theme}_ground",
            "material": style.material,
            "sourceHero": f"{theme}_hero",
        }

    MANIFEST.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST.write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"Wrote {len(THEMES)} hero-derived ground imagesets and egypt_hero")


if __name__ == "__main__":
    main()
