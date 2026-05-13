#!/usr/bin/env python3
"""Generate Retro Diffusion midground assets from prompts in midground-ideas.md.

Reads the canonical prompt block from midground-ideas.md (the section titled
"## Retro Diffusion API Prompts (Production)"), POSTs each prompt to the Retro
Diffusion v1 inferences endpoint, and writes the returned PNGs to
./midgrounds-new/<biome>/<biome>__<slug>__v<N>.png.

Auth: reads RETRO_DIFFUSION_KEY from the repo .env (same loader pattern as
tools/hero_art/generate_hf_hero.py). The key is never logged.

Examples:
  # See the total bill before spending credits (no images returned)
  python3 scripts/generate_midgrounds.py --check-cost

  # Cheap drafts of all 54 prompts (RD_FAST, default)
  python3 scripts/generate_midgrounds.py

  # Production quality for one biome
  python3 scripts/generate_midgrounds.py --style pro --biome arctic

  # Just one prompt
  python3 scripts/generate_midgrounds.py --style pro --biome arctic --prompt snowy
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ENV_FILE = ROOT / ".env"
PROMPTS_FILE = ROOT / "midground-ideas.md"
OUTPUT_DIR = ROOT / "midgrounds-new"

API_URL = "https://api.retrodiffusion.ai/v1/inferences"
PROMPTS_SECTION_HEADER = "## Retro Diffusion API Prompts (Production)"

STYLE_CONFIGS: dict[str, dict] = {
    "pro": {
        "prompt_style": "rd_pro__platformer",
        "width": 192,
        "height": 128,
        "num_images": 1,
        "remove_bg": True,
        "tile_x": False,
        "tile_y": False,
        "upscale_output_factor": 1,
    },
    "fast": {
        "prompt_style": "rd_fast__game_asset",
        "width": 192,
        "height": 128,
        "num_images": 1,
        "remove_bg": True,
        "tile_x": False,
        "tile_y": False,
        "upscale_output_factor": 1,
    },
}


def load_env_file(path: Path) -> None:
    if not path.exists():
        return
    for raw_line in path.read_text().splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        os.environ.setdefault(key, value)


def load_api_key() -> str:
    load_env_file(ENV_FILE)
    key = os.environ.get("RETRO_DIFFUSION_KEY", "").strip()
    if not key:
        sys.exit("RETRO_DIFFUSION_KEY not set (check .env or shell env).")
    return key


def parse_prompts() -> tuple[str, list[dict]]:
    """Parse (universal_suffix, prompts) from midground-ideas.md."""
    if not PROMPTS_FILE.exists():
        sys.exit(f"Missing {PROMPTS_FILE}")

    text = PROMPTS_FILE.read_text()
    if PROMPTS_SECTION_HEADER not in text:
        sys.exit(f"Section '{PROMPTS_SECTION_HEADER}' not found in {PROMPTS_FILE}")

    section = text.split(PROMPTS_SECTION_HEADER, 1)[1]
    next_h2 = re.search(r"\n## ", section)
    if next_h2:
        section = section[: next_h2.start()]

    blocks = re.split(r"\n### ", section)
    blocks = [b.strip() for b in blocks if b.strip()]

    universal_suffix = ""
    prompts: list[dict] = []
    for block in blocks:
        head, _, body = block.partition("\n")
        head = head.strip()
        body = body.strip()
        if not body:
            continue
        if head == "universal_suffix":
            universal_suffix = body
            continue
        if " / " not in head:
            continue
        biome, slug = (p.strip() for p in head.split(" / ", 1))
        if not biome or not slug:
            continue
        prompts.append({"biome": biome, "slug": slug, "prompt": body})

    if not universal_suffix:
        sys.exit("universal_suffix block not found in prompts section")
    if not prompts:
        sys.exit("No biome prompts parsed from prompts section")
    return universal_suffix, prompts


def filter_prompts(
    prompts: list[dict], biome: str | None, slug_substr: str | None
) -> list[dict]:
    out = prompts
    if biome:
        out = [p for p in out if p["biome"] == biome]
    if slug_substr:
        needle = slug_substr.lower()
        out = [p for p in out if needle in p["slug"].lower()]
    if not out:
        sys.exit("No prompts matched the given --biome / --prompt filters")
    return out


def build_payload(
    prompt_text: str, suffix: str, style: str, check_cost: bool
) -> dict:
    payload = dict(STYLE_CONFIGS[style])
    payload["prompt"] = f"{prompt_text}, {suffix}"
    if check_cost:
        payload["check_cost"] = True
    return payload


def post_inference(payload: dict, api_key: str) -> dict:
    req = urllib.request.Request(
        API_URL,
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "X-RD-Token": api_key,
            "Content-Type": "application/json",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=180) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        sys.exit(f"HTTP {e.code} from RD API: {body}")
    except urllib.error.URLError as e:
        sys.exit(f"Network error talking to RD API: {e}")


def save_images(b64_list: list[str], biome: str, slug: str) -> list[Path]:
    biome_dir = OUTPUT_DIR / biome
    biome_dir.mkdir(parents=True, exist_ok=True)
    saved: list[Path] = []
    for i, b64 in enumerate(b64_list, start=1):
        out = biome_dir / f"{biome}__{slug}__v{i}.png"
        out.write_bytes(base64.b64decode(b64))
        saved.append(out)
    return saved


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument(
        "--style",
        choices=list(STYLE_CONFIGS),
        default="fast",
        help="Model style (default: fast = rd_fast__game_asset).",
    )
    ap.add_argument("--biome", help="Restrict to one biome (e.g. arctic).")
    ap.add_argument(
        "--prompt",
        help="Substring of slug to restrict to (e.g. 'snowy' matches snowy_ice_boulder_cluster).",
    )
    ap.add_argument(
        "--check-cost",
        action="store_true",
        help="Use API check_cost mode; print bill, generate no images.",
    )
    ap.add_argument(
        "--dry-run",
        action="store_true",
        help="Print what would be sent. No API calls, no key needed.",
    )
    ap.add_argument(
        "--sleep",
        type=float,
        default=0.5,
        help="Seconds to sleep between calls (default 0.5).",
    )
    ap.add_argument(
        "--skip-existing",
        action="store_true",
        help="Skip prompts whose v1 PNG already exists under OUTPUT_DIR.",
    )
    args = ap.parse_args()

    suffix, all_prompts = parse_prompts()
    prompts = filter_prompts(all_prompts, args.biome, args.prompt)
    api_key = "" if args.dry_run else load_api_key()

    mode = "DRY-RUN" if args.dry_run else ("CHECK-COST" if args.check_cost else "GENERATE")
    print(f"Mode: {mode}  |  Style: {args.style}  |  Prompts: {len(prompts)}")
    if not args.dry_run and not args.check_cost:
        print(f"Output: {OUTPUT_DIR}")
    print()

    total_cost = 0.0
    last_balance = None

    for i, p in enumerate(prompts, start=1):
        payload = build_payload(p["prompt"], suffix, args.style, args.check_cost)
        tag = f"[{i:>2}/{len(prompts)}] {p['biome']:>11} / {p['slug']}"

        if args.skip_existing and not args.check_cost and not args.dry_run:
            v1_path = OUTPUT_DIR / p["biome"] / f"{p['biome']}__{p['slug']}__v1.png"
            if v1_path.exists():
                print(f"{tag}  skip (v1 exists)")
                continue

        if args.dry_run:
            print(f"{tag}\n  prompt: {payload['prompt'][:140]}...\n")
            continue

        result = post_inference(payload, api_key)
        cost = result.get("balance_cost") or 0
        total_cost += float(cost)
        if "remaining_balance" in result:
            last_balance = result["remaining_balance"]

        if args.check_cost:
            print(f"{tag}  cost: {cost}")
        else:
            b64s = result.get("base64_images") or []
            saved = save_images(b64s, p["biome"], p["slug"])
            bal = f"  balance: {last_balance}" if last_balance is not None else ""
            print(f"{tag}  cost: {cost}  saved: {len(saved)}{bal}")

        time.sleep(args.sleep)

    if not args.dry_run:
        print(f"\nTotal cost: {total_cost:.2f}")
        if last_balance is not None:
            print(f"Remaining balance: {last_balance}")


if __name__ == "__main__":
    main()
