#!/usr/bin/env python3
"""
generate_midground_assets.py

Generate high-quality standalone midground objects for FloppyDuck.
"""
import os, random
from PIL import Image
from pathlib import Path
from generate_themes_hf import generate_image_hf, process_layer, remove_bg_topdown

BASE_OUT = '../../artifacts/midground_assets'
os.makedirs(BASE_OUT, exist_ok=True)

ASSETS = [
    {
        'name': 'steampunk_airship',
        'palette': ['2a1a10', '4a3020', '6a4830', 'a06840', 'd09050', '304050', '506070'],
        'prompt': 'Pixel art steampunk airship with brass gears and wooden hull. Floating in white space. Detailed 8-bit retro style. Full object in frame.'
    },
    {
        'name': 'floating_island_ruins',
        'palette': ['3a4a30', '5a6a48', '7a8a60', '9a9078', 'b0a890', '4a3828'],
        'prompt': 'Pixel art floating earth island with ancient stone ruins and a single small waterfall. On plain white background. 8-bit retro style.'
    },
    {
        'name': 'crystal_pillar',
        'palette': ['102040', '204080', '4080c0', '80c0f0', 'c0e8ff', 'f0f4ff'],
        'prompt': 'Pixel art giant glowing blue crystal pillar with magical runes. On plain white background. 8-bit retro style.'
    },
    {
        'name': 'mystical_tree',
        'palette': ['1a0a20', '3a1a40', '5a2a60', '7a4a80', 'a070b0', '3a5a30', '508040'],
        'prompt': 'Pixel art ancient mystical tree with purple leaves and glowing bark. On plain white background. 8-bit retro style.'
    }
]

def main():
    print("=== Generating High-Quality Midground Assets ===")
    
    for asset in ASSETS:
        name = asset['name']
        print(f"🚀 Generating {name}...")
        
        try:
            img = generate_image_hf(asset['prompt'])
            
            # Use out_dir inside artifacts
            out_dir = os.path.join(BASE_OUT, name)
            os.makedirs(out_dir, exist_ok=True)
            
            raw_path = os.path.join(out_dir, f"{name}_raw.png")
            img.save(raw_path)
            
            # Process with top-down removal
            img_proc = remove_bg_topdown(raw_path, tolerance=50)
            
            # Process layer (using 100x100 for standalone assets, can scale in game)
            path = process_layer(
                img_proc, name, asset['palette'], 100, 100, out_dir,
                dither='fs', texture_amt=3, outline=True
            )
            print(f"  ✅ {name} complete: {path}")
            
        except Exception as e:
            print(f"  ❌ Error generating {name}: {e}")

if __name__ == "__main__":
    main()
