#!/usr/bin/env python3
"""Generate a theme hero image with Hugging Face Inference Providers.

The prompt is read dynamically from prompts/{theme}.md under the "## hero"
fenced code block. HF credentials are read from HF_TOKEN in the environment or
from a local .env file that must not be committed.

Usage:
  HF_TOKEN=hf_... python3 tools/hero_art/generate_hf_hero.py egypt
  python3 tools/hero_art/generate_hf_hero.py pixelTokyo --env-file tools/hero_art/.env --import
"""

from __future__ import annotations

import argparse
import os
import re
import hashlib
import subprocess
import sys
from pathlib import Path

DEFAULT_MODEL = "black-forest-labs/FLUX.2-dev"
DEFAULT_WIDTH = 1600
DEFAULT_HEIGHT = 1240


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


def read_hero_prompt(repo: Path, theme: str) -> str:
    prompt_path = repo / "prompts" / f"{theme}.md"
    if not prompt_path.exists():
        raise FileNotFoundError(f"Missing prompt file: {prompt_path}")

    text = prompt_path.read_text()
    match = re.search(r"^## hero\s*```(?:text)?\s*(.*?)\s*```", text, flags=re.M | re.S)
    if not match:
        raise ValueError(f"Could not find a fenced ## hero prompt in {prompt_path}")
    return match.group(1).strip()


def generate_image(
    prompt: str,
    model: str,
    provider: str,
    width: int,
    height: int,
    steps: int | None,
    guidance_scale: float | None,
    seed: int | None,
):
    token = os.environ.get("HF_TOKEN")
    if not token:
        raise RuntimeError(
            "HF_TOKEN is not set. Put it in your shell environment or in "
            "tools/hero_art/.env. Do not commit the token."
        )

    try:
        from huggingface_hub import InferenceClient
    except ImportError as exc:
        raise RuntimeError(
            "Missing dependency: huggingface_hub. Install with "
            "`python3 -m pip install -r tools/hero_art/requirements.txt`."
        ) from exc

    client = InferenceClient(provider=provider, api_key=token)
    kwargs = {
        "prompt": prompt,
        "model": model,
        "width": width,
        "height": height,
    }
    if steps is not None:
        kwargs["num_inference_steps"] = steps
    if guidance_scale is not None:
        kwargs["guidance_scale"] = guidance_scale
    if seed is not None:
        kwargs["seed"] = seed

    return client.text_to_image(**kwargs)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("theme", help="BackgroundTheme rawValue, e.g. pixelTokyo")
    parser.add_argument("--repo", type=Path, default=Path.cwd())
    parser.add_argument("--env-file", type=Path, default=Path("tools/hero_art/.env"))
    parser.add_argument("--model", default=DEFAULT_MODEL)
    parser.add_argument("--provider", default="auto")
    parser.add_argument("--width", type=int, default=DEFAULT_WIDTH)
    parser.add_argument("--height", type=int, default=DEFAULT_HEIGHT)
    parser.add_argument("--steps", type=int, default=None)
    parser.add_argument("--guidance-scale", type=float, default=None)
    parser.add_argument("--seed", type=int, default=None)
    parser.add_argument("--out-dir", type=Path, default=Path("artifacts/hero_sources"))
    parser.add_argument("--variant", default=None, help="Optional output filename suffix")
    parser.add_argument("--import", dest="run_import", action="store_true")
    parser.add_argument("--darken-center", type=float, default=0)
    parser.add_argument("--colors", type=int, default=128)
    parser.add_argument("--asset-scale", type=int, choices=[1, 2], default=1)
    args = parser.parse_args()

    repo = args.repo.resolve()
    load_env_file(repo / ".env")
    load_env_file(repo / args.env_file)
    prompt = read_hero_prompt(repo, args.theme)

    out_dir = (repo / args.out_dir).resolve()
    out_dir.mkdir(parents=True, exist_ok=True)
    variant = args.variant
    if variant is None:
        variant = re.sub(r"[^A-Za-z0-9_.-]+", "-", args.model).strip("-")
        if len(variant) > 80:
            variant = hashlib.sha1(args.model.encode("utf-8")).hexdigest()[:12]
    output = out_dir / f"{args.theme}_hero_source_{variant}.png"

    image = generate_image(
        prompt=prompt,
        model=args.model,
        provider=args.provider,
        width=args.width,
        height=args.height,
        steps=args.steps,
        guidance_scale=args.guidance_scale,
        seed=args.seed,
    )
    image.save(output)
    print(output)

    if args.run_import:
        import_script = repo / "tools" / "hero_art" / "import_hero.py"
        cmd = [
            sys.executable,
            str(import_script),
            args.theme,
            str(output),
            "--repo",
            str(repo),
            "--colors",
            str(args.colors),
            "--darken-center",
            str(args.darken_center),
            "--scale",
            str(args.asset_scale),
        ]
        subprocess.run(cmd, check=True)


if __name__ == "__main__":
    main()
