"""
FloppyDuck — All 17 Background Themes Production Pipeline

GPT Image 2 → background removal → downscale → C dither → 4x upscale
Each theme: 9 layers, unique content, curated palettes, theme-appropriate art.

Key design rule: content lives in the LOWER portion of each layer.
Upper 60%+ must be clear sky/space for the duck to fly through.
"""
import asyncio, subprocess, os, sys, random
from PIL import Image
import numpy as np
from collections import deque

ENGINE = '/work/pixel_tools/pixelart_engine'
BASE_OUT = '/work/pixel_art/output_production'
NATIVE_W, NATIVE_H = 200, 155

os.makedirs(BASE_OUT, exist_ok=True)

# ============================================================
# UTILITY FUNCTIONS
# ============================================================

def run_engine(args):
    cmd = [ENGINE] + args
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        print(f"  ENGINE ERROR: {r.stderr[:200]}")
    return r.returncode == 0

def remove_bg_topdown(img_path, tolerance=50):
    """Remove background above content using top-down column scan."""
    img = Image.open(img_path).convert('RGBA')
    arr = np.array(img, dtype=np.int16)
    h, w = arr.shape[:2]
    
    bg_sample = arr[:min(20, h), :min(20, w), :3]
    bg_color = np.median(bg_sample.reshape(-1, 3), axis=0)
    
    content_edges = np.full(w, h, dtype=int)
    for x in range(w):
        for y in range(h):
            diff = np.sqrt(np.sum((arr[y, x, :3].astype(float) - bg_color) ** 2))
            if diff > tolerance:
                content_edges[x] = y
                break
    
    # Smooth edge
    for i in range(w):
        s, e = max(0, i - 5), min(w, i + 6)
        content_edges[i] = np.min(content_edges[s:e])
    
    result = np.array(img, dtype=np.uint8)
    total_t = 0
    for x in range(w):
        ey = content_edges[x]
        for y in range(ey):
            result[y, x, 3] = 0
            total_t += 1
        for dy in range(min(3, ey)):
            y2 = ey - 1 - dy
            if y2 >= 0:
                result[y2, x, 3] = int(result[y2, x, 3] * (1 - (dy+1)/4.0))
    
    pct = 100 * total_t / (h * w)
    print(f"  BG removed: {pct:.0f}% transparent")
    return Image.fromarray(result)

def remove_bg_flood(img_path, threshold=240):
    """Flood-fill bg removal for irregular shapes (smoke, clouds)."""
    img = Image.open(img_path).convert('RGBA')
    arr = np.array(img)
    h, w = arr.shape[:2]
    
    is_bg = (arr[:,:,0] > threshold) & (arr[:,:,1] > threshold) & (arr[:,:,2] > threshold)
    visited = np.zeros((h, w), dtype=bool)
    bg_mask = np.zeros((h, w), dtype=bool)
    queue = deque()
    
    for x in range(w):
        if is_bg[0, x]: queue.append((0, x))
        if is_bg[h-1, x]: queue.append((h-1, x))
    for y in range(h):
        if is_bg[y, 0]: queue.append((y, 0))
        if is_bg[y, w-1]: queue.append((y, w-1))
    
    while queue:
        y, x = queue.popleft()
        if visited[y, x]: continue
        visited[y, x] = True
        if not is_bg[y, x]: continue
        bg_mask[y, x] = True
        for dy, dx in [(-1,0),(1,0),(0,-1),(0,1)]:
            ny, nx = y+dy, x+dx
            if 0 <= ny < h and 0 <= nx < w and not visited[ny, nx]:
                queue.append((ny, nx))
    
    arr[bg_mask, 3] = 0
    pct = 100 * bg_mask.sum() / (h * w)
    print(f"  BG removed: {pct:.0f}% transparent (flood)")
    return Image.fromarray(arr)

def process_layer(img, name, palette_hex, target_w, target_h, out_dir, dither='fs', texture_amt=3, outline=False, outline_color='1a0a00'):
    """Full processing pipeline for one layer."""
    temp = os.path.join(out_dir, 'temp')
    os.makedirs(temp, exist_ok=True)
    
    downscaled = img.resize((target_w, target_h), Image.LANCZOS)
    down_path = os.path.join(temp, f'{name}_down.png')
    downscaled.save(down_path)
    
    dithered_path = os.path.join(temp, f'{name}_dither.png')
    if dither == 'fs':
        run_engine(['dither_fs', down_path, dithered_path] + palette_hex)
    elif dither == 'ordered':
        run_engine(['dither_ordered', down_path, dithered_path, '4'] + palette_hex)
    else:
        from shutil import copy2; copy2(down_path, dithered_path)
    
    textured_path = os.path.join(temp, f'{name}_tex.png')
    if texture_amt > 0:
        run_engine(['texture', dithered_path, textured_path, str(texture_amt), str(random.randint(1,9999))])
    else:
        from shutil import copy2; copy2(dithered_path, textured_path)
    
    final_path = os.path.join(temp, f'{name}_final.png')
    if outline:
        run_engine(['outline', textured_path, final_path, outline_color, '40'])
    else:
        from shutil import copy2; copy2(textured_path, final_path)
    
    final_img = Image.open(final_path)
    upscaled = final_img.resize((target_w * 4, target_h * 4), Image.NEAREST)
    out_path = os.path.join(out_dir, f'{name}.png')
    upscaled.save(out_path)
    print(f"  ✓ {name}: {target_w*4}x{target_h*4}")
    return out_path

def make_composite(layer_paths, out_dir, theme_name):
    """Create composite and layer strip images."""
    comp_w, comp_h = NATIVE_W * 4, NATIVE_H * 4
    comp = Image.new('RGBA', (comp_w, comp_h), (0,0,0,255))
    
    for name, path in layer_paths:
        if not os.path.exists(path): continue
        layer = Image.open(path).convert('RGBA')
        temp_img = Image.new('RGBA', (comp_w, comp_h), (0,0,0,0))
        
        if 'foreground2' in name or 'foreground3' in name:
            y_off = comp_h - layer.height
            for x in range(0, comp_w, layer.width):
                temp_img.paste(layer, (x, y_off))
        else:
            temp_img.paste(layer, (0, 0))
        comp = Image.alpha_composite(comp, temp_img)
    
    comp_path = os.path.join(out_dir, f'{theme_name}_composite.png')
    comp.convert('RGB').save(comp_path)
    
    # Layer strip (3x3 grid)
    sw, sh = NATIVE_W * 4, NATIVE_H * 4
    strip = Image.new('RGBA', (sw * 3 + 20, sh * 3 + 80), (30, 30, 35, 255))
    for i, (name, path) in enumerate(layer_paths):
        if not os.path.exists(path): continue
        layer = Image.open(path).convert('RGBA')
        row, col = i // 3, i % 3
        xo, yo = 10 + col * sw, 40 + row * sh
        cell = Image.new('RGBA', (sw, sh), (30, 30, 35, 255))
        if 'foreground2' in name or 'foreground3' in name:
            cell.paste(layer, (0, sh - layer.height), layer)
        else:
            cell.paste(layer, (0, 0), layer)
        strip.paste(cell, (xo, yo))
    
    strip_path = os.path.join(out_dir, f'{theme_name}_layers.png')
    strip.convert('RGB').save(strip_path)
    return comp_path, strip_path

# ============================================================
# THEME DEFINITIONS
# Each theme: 9 layers with unique content, palettes, prompts
# Content positioned LOW — upper 60%+ clear for duck to fly
# ============================================================

THEMES = {
    'volcano': {
        'layers': [
            {'name': 'background1', 'bg_removal': 'none', 'dither': 'ordered', 'texture': 2,
             'palette': ['120208', '2a0810', '4e1420', '782838', '9e3c30', 'c85828'],
             'prompt': 'Pixel art volcanic sky. Deep crimson at top fading to fiery orange at horizon. Scattered glowing ash embers and dim red stars. Tiny distant volcano silhouettes along the very bottom edge. 8-bit retro style. Full solid background, no transparency.'},
            {'name': 'background2', 'bg_removal': 'topdown', 'bg_tolerance': 40, 'dither': 'fs', 'texture': 3,
             'palette': ['1e0e0a', '3a2018', '5a3828', '7a5038', '986848'],
             'prompt': 'Pixel art distant volcanic mountain range. Dark brown-red jagged mountain silhouettes, 3-4 peaks. Mountains fill ONLY the bottom 25% of image. Upper 75% is plain white. Hazy muted tones. 8-bit retro style.'},
            {'name': 'background3', 'bg_removal': 'flood', 'dither': 'fs', 'texture': 2,
             'palette': ['2a2028', '4a3840', '6a5560', '8a7278', 'a89090'],
             'prompt': 'Pixel art volcanic smoke plumes. Gray-brown billowing smoke columns rising from below. On plain white background. Smoke in lower 40% only. 8-bit retro style.'},
            {'name': 'midground1', 'bg_removal': 'topdown', 'bg_tolerance': 45, 'dither': 'fs', 'texture': 4, 'outline': True,
             'palette': ['18100a', '302014', '4a3020', '684828', 'a06830', 'c88838'],
             'prompt': 'Pixel art erupting volcano. Large volcanic cone with glowing crater and lava streams down dark rocky slopes. On plain white background. Volcano fills lower 40% of frame. 8-bit retro style.'},
            {'name': 'midground2', 'bg_removal': 'topdown', 'bg_tolerance': 50, 'dither': 'fs', 'texture': 3,
             'palette': ['4a0c00', '8e1800', 'cc3808', 'e87020', 'ffaa38', 'ffe870'],
             'prompt': 'Pixel art churning lava lake. Bright orange-yellow molten lava with cooling crust plates and bubbling spots. Fills lower 35% of image. Upper portion plain white. 8-bit retro style.'},
            {'name': 'midground3', 'bg_removal': 'topdown', 'bg_tolerance': 50, 'dither': 'ordered', 'texture': 3, 'outline': True,
             'palette': ['0c0a10', '181620', '282430', '383440', '4a4858', '5a5870'],
             'prompt': 'Pixel art dark basalt column formations. Irregular blue-gray hexagonal basalt columns of varying heights from the bottom. On plain white background. Columns in lower 35%. 8-bit retro style.'},
            {'name': 'foreground1', 'bg_removal': 'topdown', 'bg_tolerance': 50, 'dither': 'fs', 'texture': 3,
             'palette': ['580800', 'a01808', 'e03810', 'ff6828', 'ff9838', 'ffcc58', 'ffe888'],
             'prompt': 'Pixel art close-up lava river. Intense bright orange-yellow molten lava with ripple patterns and dark rocks with glowing rims. Fills lower 30% of image. Upper portion plain white. 8-bit retro style.'},
            {'name': 'foreground2', 'bg_removal': 'none', 'dither': 'ordered', 'texture': 2, 'h': 20,
             'palette': ['100808', '201410', '301c14', '4a2c1c', 'e86020'],
             'prompt': 'Pixel art cracked volcanic rock ground. Dark charred black rock with glowing orange-red cracks. Wide horizontal strip, full coverage. 8-bit retro style.'},
            {'name': 'foreground3', 'bg_removal': 'none', 'dither': 'ordered', 'texture': 1, 'h': 25,
             'palette': ['0a0808', '181210', '281c14', 'ff8020', 'ffcc40'],
             'prompt': 'Pixel art volcanic ember overlay. Dark charred ground with bright orange floating ember particles and ash mounds. Wide horizontal strip, full coverage. 8-bit retro style.'},
        ]
    },
    'day': {
        'layers': [
            {'name': 'background1', 'bg_removal': 'none', 'dither': 'ordered', 'texture': 2,
             'palette': ['87ceeb', '5baadb', '3a8cc0', '2070a0', 'e8f4ff', 'ffffff'],
             'prompt': 'Pixel art bright daytime sky. Clear blue gradient from deep sky blue at top to pale sky at horizon. A few small white puffy cumulus clouds near the horizon. Warm sunlit feel. 8-bit retro style. Full solid background.'},
            {'name': 'background2', 'bg_removal': 'topdown', 'bg_tolerance': 40, 'dither': 'fs', 'texture': 3,
             'palette': ['3a6030', '4a7840', '5a9050', '78a868', 'a0c888'],
             'prompt': 'Pixel art distant rolling green hills for a side-scrolling game. Soft gentle hill silhouettes in muted green. Hills in lower 25% only. Upper 75% plain white background. 8-bit retro style.'},
            {'name': 'background3', 'bg_removal': 'flood', 'dither': 'fs', 'texture': 2,
             'palette': ['e8e8f0', 'c8d0e0', 'a8b8d0', 'f0f0f8', 'ffffff'],
             'prompt': 'Pixel art fluffy white clouds for a side-scrolling game. 3-4 scattered cumulus clouds of different sizes floating in the frame. On plain white background. Clouds in lower 40%. 8-bit retro style.'},
            {'name': 'midground1', 'bg_removal': 'topdown', 'bg_tolerance': 40, 'dither': 'fs', 'texture': 3, 'outline': True,
             'palette': ['2a4420', '3a5a30', '4a7040', '5a8850', '78a060', 'a0c880'],
             'prompt': 'Pixel art green meadow hill with a large oak tree. Grassy rolling hill with one big detailed tree with thick trunk and leafy canopy. On plain white background. Content in lower 35% only. 8-bit retro style.'},
            {'name': 'midground2', 'bg_removal': 'topdown', 'bg_tolerance': 45, 'dither': 'fs', 'texture': 3,
             'palette': ['3a2820', '5a4838', '7a6850', '9a8868', 'c0a880', 'e0c8a0'],
             'prompt': 'Pixel art wooden fence along a dirt path for a side-scrolling game. Rustic split-rail fence posts with a winding dirt trail. On plain white background. In lower 30% of image. 8-bit retro style.'},
            {'name': 'midground3', 'bg_removal': 'topdown', 'bg_tolerance': 45, 'dither': 'fs', 'texture': 2,
             'palette': ['2a5020', '3a6830', '508840', '68a050', '88c068', 'b0e088'],
             'prompt': 'Pixel art wildflower bushes and tall grass for a side-scrolling game. Mixed green bushes with scattered colorful wildflowers (yellow, red, purple dots). On plain white background. In lower 30%. 8-bit retro style.'},
            {'name': 'foreground1', 'bg_removal': 'topdown', 'bg_tolerance': 45, 'dither': 'fs', 'texture': 3,
             'palette': ['1a3810', '2a5020', '3a6830', '508840', '78b058', 'a8d878'],
             'prompt': 'Pixel art close-up tall grass and dandelions for a side-scrolling game. Detailed grass blades with seed heads and small butterflies. On plain white background. In lower 25%. 8-bit retro style.'},
            {'name': 'foreground2', 'bg_removal': 'none', 'dither': 'ordered', 'texture': 2, 'h': 20,
             'palette': ['3a6028', '508838', '68a048', '88c060', '60a040'],
             'prompt': 'Pixel art green grass ground strip. Bright green grass surface top-down view. Wide horizontal strip full coverage. 8-bit retro style.'},
            {'name': 'foreground3', 'bg_removal': 'none', 'dither': 'ordered', 'texture': 1, 'h': 25,
             'palette': ['2a4818', '3a6028', '508838', '68a048', '886830'],
             'prompt': 'Pixel art dirt and pebble ground overlay. Brown dirt path with small pebbles and grass tufts. Wide horizontal strip full coverage. 8-bit retro style.'},
        ]
    },
    'sunset': {
        'layers': [
            {'name': 'background1', 'bg_removal': 'none', 'dither': 'ordered', 'texture': 2,
             'palette': ['1a0828', '3a1040', '6a2050', '9a3848', 'c85838', 'e88828', 'f0b848'],
             'prompt': 'Pixel art sunset sky. Rich gradient from deep purple at top through magenta and orange to golden yellow at the horizon. A few wispy cirrus clouds catching the golden light. 8-bit retro style. Full solid background.'},
            {'name': 'background2', 'bg_removal': 'topdown', 'bg_tolerance': 40, 'dither': 'fs', 'texture': 3,
             'palette': ['1a0818', '2a1028', '3a1838', '4a2040', '5a2848'],
             'prompt': 'Pixel art distant city skyline silhouette at sunset. Dark purple building silhouettes of varying heights. In lower 20% only. Upper 80% plain white. 8-bit retro style.'},
            {'name': 'background3', 'bg_removal': 'flood', 'dither': 'fs', 'texture': 2,
             'palette': ['e8a050', 'c88040', 'f0c070', 'f8d898', 'f0b060'],
             'prompt': 'Pixel art golden sunset clouds. Warm orange-pink backlit clouds scattered across the frame. On plain white background. In lower 40%. 8-bit retro style.'},
            {'name': 'midground1', 'bg_removal': 'topdown', 'bg_tolerance': 40, 'dither': 'fs', 'texture': 3, 'outline': True,
             'palette': ['0a0410', '1a0820', '2a1030', '3a1840', '180c28'],
             'prompt': 'Pixel art silhouette of a church steeple and rooftops at sunset. Dark dramatic building profiles against bright sky. On plain white background. In lower 35%. 8-bit retro style.'},
            {'name': 'midground2', 'bg_removal': 'topdown', 'bg_tolerance': 45, 'dither': 'fs', 'texture': 3,
             'palette': ['0a0410', '180c20', '281830', '382438', '201028'],
             'prompt': 'Pixel art silhouette of telephone poles and power lines at sunset. Dark wooden poles with drooping wire lines. On plain white background. In lower 30%. 8-bit retro style.'},
            {'name': 'midground3', 'bg_removal': 'topdown', 'bg_tolerance': 45, 'dither': 'fs', 'texture': 2,
             'palette': ['0c0818', '1a1028', '281838', '362040', '1a0c20'],
             'prompt': 'Pixel art silhouette of trees and bushes at sunset. Dark leafy tree outlines of varying sizes. On plain white background. In lower 30%. 8-bit retro style.'},
            {'name': 'foreground1', 'bg_removal': 'topdown', 'bg_tolerance': 50, 'dither': 'fs', 'texture': 3,
             'palette': ['080410', '100818', '180c20', '281430', 'e87830'],
             'prompt': 'Pixel art close-up dark fence and grass silhouette at sunset. Picket fence and tall grass in deep shadow with a few firefly dots. On plain white background. In lower 25%. 8-bit retro style.'},
            {'name': 'foreground2', 'bg_removal': 'none', 'dither': 'ordered', 'texture': 2, 'h': 20,
             'palette': ['0a0610', '140c18', '1e1420', '281c28', '180e18'],
             'prompt': 'Pixel art dark ground at sunset. Very dark purple-brown ground strip. Wide horizontal, full coverage. 8-bit retro style.'},
            {'name': 'foreground3', 'bg_removal': 'none', 'dither': 'ordered', 'texture': 1, 'h': 25,
             'palette': ['060408', '0c0810', '140c18', '1c1020', 'e87020'],
             'prompt': 'Pixel art dark ground with scattered fallen leaves at sunset. Very dark ground with a few warm-colored leaf shapes. Wide horizontal strip. 8-bit retro style.'},
        ]
    },
    'night': {
        'layers': [
            {'name': 'background1', 'bg_removal': 'none', 'dither': 'ordered', 'texture': 2,
             'palette': ['020208', '080818', '101028', '182040', '203060', 'f8f8c0'],
             'prompt': 'Pixel art night sky. Very dark navy blue gradient with hundreds of twinkling stars of varying brightness. A bright crescent moon. Milky Way band faintly visible. 8-bit retro style. Full solid background.'},
            {'name': 'background2', 'bg_removal': 'topdown', 'bg_tolerance': 35, 'dither': 'fs', 'texture': 3,
             'palette': ['040410', '0a0818', '101020', '181828', '202030'],
             'prompt': 'Pixel art distant dark mountain range at night. Very dark blue-black mountain silhouettes against slightly lighter sky. In lower 25% only. Upper 75% plain white. 8-bit retro style.'},
            {'name': 'background3', 'bg_removal': 'flood', 'dither': 'fs', 'texture': 2,
             'palette': ['182848', '203858', '284868', '305878', '386888'],
             'prompt': 'Pixel art moonlit clouds at night. Thin wispy silver-blue clouds catching moonlight. On plain white background. Scattered across lower 40%. 8-bit retro style.'},
            {'name': 'midground1', 'bg_removal': 'topdown', 'bg_tolerance': 35, 'dither': 'fs', 'texture': 3, 'outline': True,
             'palette': ['020208', '080c18', '101828', '182438', '0a0c14'],
             'prompt': 'Pixel art dark pine forest treeline at night. Tall dark pine tree silhouettes of varying heights against moonlit sky. On plain white background. Trees in lower 35%. 8-bit retro style.'},
            {'name': 'midground2', 'bg_removal': 'topdown', 'bg_tolerance': 40, 'dither': 'fs', 'texture': 3,
             'palette': ['040408', '0a0c14', '141820', '1c2430', '243040', 'f0e880'],
             'prompt': 'Pixel art spooky old cabin with glowing windows at night. Small wooden cabin with warm yellow lit windows among dark trees. On plain white background. In lower 30%. 8-bit retro style.'},
            {'name': 'midground3', 'bg_removal': 'topdown', 'bg_tolerance': 40, 'dither': 'fs', 'texture': 2,
             'palette': ['020208', '080c14', '10141c', '1a2028', '0c0e14', '40e848'],
             'prompt': 'Pixel art dark bushes and fireflies at night. Dense dark shrubs with bright green glowing firefly dots scattered around. On plain white background. In lower 30%. 8-bit retro style.'},
            {'name': 'foreground1', 'bg_removal': 'topdown', 'bg_tolerance': 40, 'dither': 'fs', 'texture': 3,
             'palette': ['020206', '06080e', '0c1018', '141820', '182028', '48f850'],
             'prompt': 'Pixel art close-up dark grass and mushrooms at night. Detailed dark grass with tiny bioluminescent mushrooms glowing blue-green. On plain white background. In lower 25%. 8-bit retro style.'},
            {'name': 'foreground2', 'bg_removal': 'none', 'dither': 'ordered', 'texture': 2, 'h': 20,
             'palette': ['020206', '080a10', '101418', '181c22', '0c0e14'],
             'prompt': 'Pixel art dark nighttime ground. Very dark blue-black dirt ground strip. Full coverage. 8-bit retro style.'},
            {'name': 'foreground3', 'bg_removal': 'none', 'dither': 'ordered', 'texture': 1, 'h': 25,
             'palette': ['020206', '060810', '0c1018', '141820', '182838'],
             'prompt': 'Pixel art dark ground with fallen twigs at night. Nearly black ground with small twig and leaf shapes. Full coverage. 8-bit retro style.'},
        ]
    },
    'neonCity': {
        'layers': [
            {'name': 'background1', 'bg_removal': 'none', 'dither': 'ordered', 'texture': 2,
             'palette': ['040010', '0a0420', '140830', '1e0c40', '100620', 'ff00ff'],
             'prompt': 'Pixel art cyberpunk night sky. Very dark purple-black sky with faint neon pink and cyan light pollution glow near the horizon. A few stars barely visible through haze. 8-bit retro style. Full solid background.'},
            {'name': 'background2', 'bg_removal': 'topdown', 'bg_tolerance': 40, 'dither': 'fs', 'texture': 3,
             'palette': ['08040c', '140818', '201028', '301838', '402048', 'ff10a0', '10ffff'],
             'prompt': 'Pixel art distant cyberpunk skyscraper skyline. Dark building silhouettes with scattered neon window lights in pink and cyan. In lower 25% only. Upper 75% plain white. 8-bit retro style.'},
            {'name': 'background3', 'bg_removal': 'flood', 'dither': 'fs', 'texture': 2,
             'palette': ['ff0080', 'ff40a0', '00ffff', '40ffff', 'ff00ff', '8000ff'],
             'prompt': 'Pixel art neon sign reflections and light streaks. Floating neon glow effects in pink, cyan, and purple against white background. Scattered across lower 40%. 8-bit retro style.'},
            {'name': 'midground1', 'bg_removal': 'topdown', 'bg_tolerance': 40, 'dither': 'fs', 'texture': 3, 'outline': True,
             'palette': ['0a0414', '181028', '282040', '383050', 'ff0088', '00e8ff', 'ff00ff'],
             'prompt': 'Pixel art large cyberpunk building with neon signs at night. Concrete building facade with glowing neon signs in Japanese/Chinese characters, pink and cyan. On plain white background. In lower 35%. 8-bit retro style.'},
            {'name': 'midground2', 'bg_removal': 'topdown', 'bg_tolerance': 45, 'dither': 'fs', 'texture': 3,
             'palette': ['0c0818', '181428', '282038', '382c48', 'ff0080', '00ccff', 'ffff00'],
             'prompt': 'Pixel art row of cyberpunk shops and food stalls at night. Small neon-lit storefronts with glowing awnings and steam. On plain white background. In lower 30%. 8-bit retro style.'},
            {'name': 'midground3', 'bg_removal': 'topdown', 'bg_tolerance': 45, 'dither': 'fs', 'texture': 2,
             'palette': ['080410', '140c20', '201830', '2c2440', 'ff0080', '00ffcc', '8040ff'],
             'prompt': 'Pixel art neon-lit vending machines and street furniture at night. Glowing vending machines, trash cans, and a fire hydrant with neon reflections. On plain white background. In lower 30%. 8-bit retro style.'},
            {'name': 'foreground1', 'bg_removal': 'topdown', 'bg_tolerance': 50, 'dither': 'fs', 'texture': 3,
             'palette': ['04020a', '0c0818', '181028', 'ff0080', '00ffff', 'ff40ff', 'ffff40'],
             'prompt': 'Pixel art wet cyberpunk street with neon puddle reflections. Dark wet pavement with bright neon color reflections in rain puddles. On plain white background. In lower 25%. 8-bit retro style.'},
            {'name': 'foreground2', 'bg_removal': 'none', 'dither': 'ordered', 'texture': 2, 'h': 20,
             'palette': ['08040c', '140818', '201028', '2c1838', 'ff0088'],
             'prompt': 'Pixel art dark cyberpunk sidewalk. Dark concrete with neon pink crack lines. Full coverage strip. 8-bit retro style.'},
            {'name': 'foreground3', 'bg_removal': 'none', 'dither': 'ordered', 'texture': 1, 'h': 25,
             'palette': ['04020a', '0c0614', '14081c', '1c0c24', '00ffff'],
             'prompt': 'Pixel art dark wet ground with neon light pools. Nearly black wet pavement with small cyan neon light reflections. Full coverage strip. 8-bit retro style.'},
        ]
    },
    'pixelTokyo': {
        'layers': [
            {'name': 'background1', 'bg_removal': 'none', 'dither': 'ordered', 'texture': 2,
             'palette': ['0a0818', '141028', '1e1838', '282048', '322858', 'ff6090'],
             'prompt': 'Pixel art Tokyo twilight sky. Deep indigo to warm pink gradient at horizon. Soft pink glow of city lights below. Tiny stars emerging. 8-bit retro style. Full solid background.'},
            {'name': 'background2', 'bg_removal': 'topdown', 'bg_tolerance': 40, 'dither': 'fs', 'texture': 3,
             'palette': ['181828', '282838', '383848', '484858', 'e8a0b0', 'ff6888'],
             'prompt': 'Pixel art distant Tokyo Tower and skyscrapers at dusk. Silhouette skyline with Tokyo Tower prominent, lit windows. In lower 25% only. Upper 75% plain white. 8-bit retro style.'},
            {'name': 'background3', 'bg_removal': 'flood', 'dither': 'fs', 'texture': 2,
             'palette': ['f0a0b8', 'f8c0d0', 'ffe0e8', 'ffffff', 'e890a8'],
             'prompt': 'Pixel art floating cherry blossom petals. Delicate pink sakura petals scattered across the frame, drifting in wind. On plain white background. 8-bit retro style.'},
            {'name': 'midground1', 'bg_removal': 'topdown', 'bg_tolerance': 40, 'dither': 'fs', 'texture': 3, 'outline': True,
             'palette': ['181420', '282430', '383440', '484450', '585460', 'ff4870', 'e83860'],
             'prompt': 'Pixel art Japanese temple gate (torii) and pagoda rooftops. Red torii gate with curved roof pagoda behind it. On plain white background. In lower 35%. 8-bit retro style.'},
            {'name': 'midground2', 'bg_removal': 'topdown', 'bg_tolerance': 45, 'dither': 'fs', 'texture': 3,
             'palette': ['201828', '302838', '403848', '504858', 'ff6888', 'ffb0c0', 'e85070'],
             'prompt': 'Pixel art row of Japanese lanterns and shop fronts. Paper lanterns hanging from traditional wooden storefronts with Japanese text. On plain white background. In lower 30%. 8-bit retro style.'},
            {'name': 'midground3', 'bg_removal': 'topdown', 'bg_tolerance': 45, 'dither': 'fs', 'texture': 2,
             'palette': ['3a2820', '5a4030', '785840', '987050', 'b89068', '68a040'],
             'prompt': 'Pixel art cherry blossom trees in bloom. 2-3 sakura trees with pink blossoms on gnarled trunks. On plain white background. In lower 30%. 8-bit retro style.'},
            {'name': 'foreground1', 'bg_removal': 'topdown', 'bg_tolerance': 50, 'dither': 'fs', 'texture': 3,
             'palette': ['281820', '402830', '583840', '704850', 'f0a0b0', 'ff6080'],
             'prompt': 'Pixel art close-up stone garden path with fallen petals. Cobblestone path with pink sakura petals scattered. On plain white background. In lower 25%. 8-bit retro style.'},
            {'name': 'foreground2', 'bg_removal': 'none', 'dither': 'ordered', 'texture': 2, 'h': 20,
             'palette': ['282028', '383038', '484048', '585058', '685868'],
             'prompt': 'Pixel art cobblestone ground strip. Dark gray-purple cobblestones. Full coverage. 8-bit retro style.'},
            {'name': 'foreground3', 'bg_removal': 'none', 'dither': 'ordered', 'texture': 1, 'h': 25,
             'palette': ['201820', '302830', '403840', '504850', 'f08098'],
             'prompt': 'Pixel art ground with sakura petals scattered. Dark stone ground with fallen pink cherry blossom petals. Full coverage strip. 8-bit retro style.'},
        ]
    },
    'underwater': {
        'layers': [
            {'name': 'background1', 'bg_removal': 'none', 'dither': 'ordered', 'texture': 2,
             'palette': ['001020', '002040', '003060', '004880', '0060a0', '0080c0'],
             'prompt': 'Pixel art deep ocean water background. Dark navy blue at top gradually lightening to cerulean blue at bottom. Subtle light rays streaming down from above. Tiny distant particles/plankton. 8-bit retro style. Full solid background.'},
            {'name': 'background2', 'bg_removal': 'topdown', 'bg_tolerance': 40, 'dither': 'fs', 'texture': 3,
             'palette': ['001828', '002838', '003848', '004858', '005868'],
             'prompt': 'Pixel art distant underwater rock formations and coral reef silhouettes. Dark blue-teal distant reef shapes. In lower 25% only. Upper 75% plain white. 8-bit retro style.'},
            {'name': 'background3', 'bg_removal': 'flood', 'dither': 'fs', 'texture': 2,
             'palette': ['80c0f0', 'a0d8ff', 'c0e8ff', 'e0f4ff', '90d0f8'],
             'prompt': 'Pixel art underwater light caustics and bubbles. Bright shimmering light patterns and rising bubble streams. On plain white background. Scattered throughout. 8-bit retro style.'},
            {'name': 'midground1', 'bg_removal': 'topdown', 'bg_tolerance': 40, 'dither': 'fs', 'texture': 3, 'outline': True,
             'palette': ['002018', '003828', '005038', '006848', '008058', 'ff6040', 'ffa040'],
             'prompt': 'Pixel art large coral reef formation. Colorful branching coral in oranges, reds, and greens growing from rocky base. On plain white background. In lower 35%. 8-bit retro style.'},
            {'name': 'midground2', 'bg_removal': 'topdown', 'bg_tolerance': 45, 'dither': 'fs', 'texture': 3,
             'palette': ['183028', '284838', '386048', '487858', '589068', '68a878'],
             'prompt': 'Pixel art swaying seaweed and kelp forest. Tall green-brown kelp strands swaying with current. On plain white background. In lower 35%. 8-bit retro style.'},
            {'name': 'midground3', 'bg_removal': 'topdown', 'bg_tolerance': 45, 'dither': 'fs', 'texture': 2,
             'palette': ['182830', '283840', '384850', '485860', '586870', 'ff8848', 'ffe040'],
             'prompt': 'Pixel art underwater rocks with anemones and starfish. Scattered boulders with colorful sea anemones and bright starfish attached. On plain white background. In lower 30%. 8-bit retro style.'},
            {'name': 'foreground1', 'bg_removal': 'topdown', 'bg_tolerance': 50, 'dither': 'fs', 'texture': 3,
             'palette': ['002818', '004028', '005838', '007048', '009058', '40ff80', 'ff4040'],
             'prompt': 'Pixel art close-up sea floor with tube worms and small fish. Detailed ocean bottom with colorful tube worms, small tropical fish, and shells. On plain white background. In lower 25%. 8-bit retro style.'},
            {'name': 'foreground2', 'bg_removal': 'none', 'dither': 'ordered', 'texture': 2, 'h': 20,
             'palette': ['102818', '184020', '205828', '287030', '308838'],
             'prompt': 'Pixel art sandy ocean floor with seagrass. Yellow-green sandy bottom with short seagrass. Full coverage strip. 8-bit retro style.'},
            {'name': 'foreground3', 'bg_removal': 'none', 'dither': 'ordered', 'texture': 1, 'h': 25,
             'palette': ['0c2010', '183018', '204020', '285028', 'c8b868'],
             'prompt': 'Pixel art ocean floor sand and pebbles. Sandy bottom with small shells and colorful pebbles. Full coverage strip. 8-bit retro style.'},
        ]
    },
    'arctic': {
        'layers': [
            {'name': 'background1', 'bg_removal': 'none', 'dither': 'ordered', 'texture': 2,
             'palette': ['b0d0e8', '90b8d8', '70a0c8', '5088b8', '3070a8', 'c8e0f0'],
             'prompt': 'Pixel art arctic sky. Pale icy blue gradient from light steel blue at top to near-white at horizon. Faint aurora borealis green wisps. 8-bit retro style. Full solid background.'},
            {'name': 'background2', 'bg_removal': 'topdown', 'bg_tolerance': 40, 'dither': 'fs', 'texture': 3,
             'palette': ['90a8c0', 'a0b8d0', 'b0c8e0', 'c0d8e8', 'd0e0f0'],
             'prompt': 'Pixel art distant snowy mountain peaks. Pale blue-white snow-capped mountain silhouettes. In lower 25% only. Upper 75% plain white. 8-bit retro style.'},
            {'name': 'background3', 'bg_removal': 'flood', 'dither': 'fs', 'texture': 2,
             'palette': ['d0e0f0', 'e0e8f0', 'e8f0f8', 'f0f4f8', 'c8d8e8'],
             'prompt': 'Pixel art blowing snow and ice crystals. Scattered snow particles and ice crystal flurries drifting in wind. On plain white background. 8-bit retro style.'},
            {'name': 'midground1', 'bg_removal': 'topdown', 'bg_tolerance': 40, 'dither': 'fs', 'texture': 3, 'outline': True,
             'palette': ['607888', '7890a0', '90a8b8', 'a8c0d0', 'c0d8e8', 'e0f0ff'],
             'prompt': 'Pixel art large glacier and iceberg formation. Massive blue-white glacier with jagged ice formations and crevasses. On plain white background. In lower 35%. 8-bit retro style.'},
            {'name': 'midground2', 'bg_removal': 'topdown', 'bg_tolerance': 45, 'dither': 'fs', 'texture': 3,
             'palette': ['506878', '688090', '8098a8', 'a0b8c8', 'c0d8e8', 'e8f8ff'],
             'prompt': 'Pixel art ice floe field on frozen sea. Broken ice chunks floating on dark water with snow on top. On plain white background. In lower 30%. 8-bit retro style.'},
            {'name': 'midground3', 'bg_removal': 'topdown', 'bg_tolerance': 45, 'dither': 'fs', 'texture': 2,
             'palette': ['384050', '485868', '586870', '688088', 'd8e8f0', 'f0f8ff'],
             'prompt': 'Pixel art frozen rock outcrops with icicles. Dark rocks encrusted with thick ice and hanging icicles. On plain white background. In lower 30%. 8-bit retro style.'},
            {'name': 'foreground1', 'bg_removal': 'topdown', 'bg_tolerance': 50, 'dither': 'fs', 'texture': 3,
             'palette': ['384858', '506878', '688898', 'a0c0d8', 'd0e8f8', 'f0f8ff'],
             'prompt': 'Pixel art close-up snow drifts and ice crystals. Detailed snow banks with glistening ice crystal patterns. On plain white background. In lower 25%. 8-bit retro style.'},
            {'name': 'foreground2', 'bg_removal': 'none', 'dither': 'ordered', 'texture': 2, 'h': 20,
             'palette': ['c0d8e8', 'd0e0f0', 'e0e8f0', 'e8f0f8', 'b0c8d8'],
             'prompt': 'Pixel art packed snow and ice ground. White-blue packed snow surface. Full coverage strip. 8-bit retro style.'},
            {'name': 'foreground3', 'bg_removal': 'none', 'dither': 'ordered', 'texture': 1, 'h': 25,
             'palette': ['b8d0e0', 'c8d8e8', 'd8e4f0', 'e0ecf4', '90b0c8'],
             'prompt': 'Pixel art snow ground with footprints and frost patterns. White snow with subtle blue shadows and crystalline frost. Full coverage strip. 8-bit retro style.'},
        ]
    },
    'western': {
        'layers': [
            {'name': 'background1', 'bg_removal': 'none', 'dither': 'ordered', 'texture': 2,
             'palette': ['f0d888', 'e0c068', 'd0a848', 'c09030', 'a07820', '806018'],
             'prompt': 'Pixel art desert sky at high noon. Blazing hot yellow-orange sky fading to hazy white at horizon. Intense heat shimmer. Merciless sun. 8-bit retro style. Full solid background.'},
            {'name': 'background2', 'bg_removal': 'topdown', 'bg_tolerance': 40, 'dither': 'fs', 'texture': 3,
             'palette': ['885030', 'a06838', 'b88040', 'c89848', 'd8a858'],
             'prompt': 'Pixel art distant desert mesa formations. Flat-topped red-brown mesa silhouettes in the distance. In lower 25% only. Upper 75% plain white. 8-bit retro style.'},
            {'name': 'background3', 'bg_removal': 'flood', 'dither': 'fs', 'texture': 2,
             'palette': ['e8d0a0', 'd8c090', 'c8b080', 'f0ddb0', 'e0c898'],
             'prompt': 'Pixel art desert dust clouds and tumbleweeds. Hazy sand dust swirls and a couple of rolling tumbleweeds. On plain white background. In lower 40%. 8-bit retro style.'},
            {'name': 'midground1', 'bg_removal': 'topdown', 'bg_tolerance': 45, 'dither': 'fs', 'texture': 4, 'outline': True,
             'palette': ['402810', '604018', '805828', '9a7038', 'b88848', 'd0a058'],
             'prompt': 'Pixel art western saloon building. Wooden Old West saloon with swinging doors, porch, and a wooden sign. On plain white background. In lower 35%. 8-bit retro style.'},
            {'name': 'midground2', 'bg_removal': 'topdown', 'bg_tolerance': 45, 'dither': 'fs', 'texture': 3,
             'palette': ['302010', '483018', '604020', '785830', '386828', '508838'],
             'prompt': 'Pixel art cactus cluster — saguaro and prickly pear cacti. Tall saguaro with arms and round prickly pear clusters. On plain white background. In lower 30%. 8-bit retro style.'},
            {'name': 'midground3', 'bg_removal': 'topdown', 'bg_tolerance': 45, 'dither': 'fs', 'texture': 2,
             'palette': ['3a2010', '5a3820', '785030', '986840', 'b88050', 'c89058'],
             'prompt': 'Pixel art wooden wagon wheel and barrel props. Old weathered wagon wheel leaning against stacked wooden barrels. On plain white background. In lower 30%. 8-bit retro style.'},
            {'name': 'foreground1', 'bg_removal': 'topdown', 'bg_tolerance': 50, 'dither': 'fs', 'texture': 3,
             'palette': ['382810', '584018', '785828', '987038', 'b08848', '486028'],
             'prompt': 'Pixel art close-up desert ground with animal skull and rocks. Cracked dry earth with a bleached cow skull and scattered rocks. On plain white background. In lower 25%. 8-bit retro style.'},
            {'name': 'foreground2', 'bg_removal': 'none', 'dither': 'ordered', 'texture': 2, 'h': 20,
             'palette': ['785020', '906830', 'a88040', 'c09848', 'b88838'],
             'prompt': 'Pixel art sandy desert ground. Dry orange-tan sandy dirt surface. Full coverage strip. 8-bit retro style.'},
            {'name': 'foreground3', 'bg_removal': 'none', 'dither': 'ordered', 'texture': 1, 'h': 25,
             'palette': ['684818', '886028', 'a07838', 'b89048', '604010'],
             'prompt': 'Pixel art desert ground with wooden planks. Sandy dirt with old weathered wooden boardwalk planks. Full coverage strip. 8-bit retro style.'},
        ]
    },
    'jungle': {
        'layers': [
            {'name': 'background1', 'bg_removal': 'none', 'dither': 'ordered', 'texture': 2,
             'palette': ['102008', '183010', '204018', '285020', '306028', '408030'],
             'prompt': 'Pixel art dense jungle canopy light. Deep green gradient from dark emerald at top to brighter green at bottom. Scattered light spots filtering through leaves. Misty tropical atmosphere. 8-bit retro style. Full solid background.'},
            {'name': 'background2', 'bg_removal': 'topdown', 'bg_tolerance': 40, 'dither': 'fs', 'texture': 3,
             'palette': ['0c1808', '182810', '243818', '304820', '3c5828'],
             'prompt': 'Pixel art distant jungle treeline. Deep green tropical tree silhouettes with varied canopy shapes. In lower 25% only. Upper 75% plain white. 8-bit retro style.'},
            {'name': 'background3', 'bg_removal': 'flood', 'dither': 'fs', 'texture': 2,
             'palette': ['c0d8b0', 'a8c898', '90b880', 'd0e0c0', 'b8d0a8'],
             'prompt': 'Pixel art jungle mist and hanging vines in background. Translucent green fog wisps with dangling vine silhouettes. On plain white background. 8-bit retro style.'},
            {'name': 'midground1', 'bg_removal': 'topdown', 'bg_tolerance': 40, 'dither': 'fs', 'texture': 4, 'outline': True,
             'palette': ['1a2808', '2a3810', '3a4818', '4a5820', '5a6828', '6a7830', '8a9848'],
             'prompt': 'Pixel art massive jungle tree with thick trunk and wide spreading branches. Ancient gnarled tree with vines and epiphytes growing on it. On plain white background. In lower 35%. 8-bit retro style.'},
            {'name': 'midground2', 'bg_removal': 'topdown', 'bg_tolerance': 45, 'dither': 'fs', 'texture': 3,
             'palette': ['182008', '283010', '384018', '485020', '586028', 'ff4030', 'ff8820'],
             'prompt': 'Pixel art jungle undergrowth with exotic flowers. Dense tropical plants with large leaves and bright red-orange exotic flowers. On plain white background. In lower 30%. 8-bit retro style.'},
            {'name': 'midground3', 'bg_removal': 'topdown', 'bg_tolerance': 45, 'dither': 'fs', 'texture': 2,
             'palette': ['3a2810', '5a4020', '7a5830', '483818', '2a3010', '405020'],
             'prompt': 'Pixel art fallen log covered in moss with mushrooms. Decaying log bridge covered in bright green moss with bracket fungi. On plain white background. In lower 30%. 8-bit retro style.'},
            {'name': 'foreground1', 'bg_removal': 'topdown', 'bg_tolerance': 50, 'dither': 'fs', 'texture': 3,
             'palette': ['0c1806', '1a2810', '283818', '384820', '486028', '58782e', '20e840'],
             'prompt': 'Pixel art close-up large tropical fern leaves and vines. Detailed oversized fern fronds curling into frame. On plain white background. In lower 25%. 8-bit retro style.'},
            {'name': 'foreground2', 'bg_removal': 'none', 'dither': 'ordered', 'texture': 2, 'h': 20,
             'palette': ['1a2808', '2a3810', '3a4818', '4a5820', '382810'],
             'prompt': 'Pixel art jungle floor with leaf litter. Dark rich soil with fallen leaves and small ferns. Full coverage strip. 8-bit retro style.'},
            {'name': 'foreground3', 'bg_removal': 'none', 'dither': 'ordered', 'texture': 1, 'h': 25,
             'palette': ['182008', '283010', '384018', '281c08', '483820'],
             'prompt': 'Pixel art muddy jungle ground with roots. Dark wet soil with exposed tree roots and scattered leaves. Full coverage strip. 8-bit retro style.'},
        ]
    },
    'egypt': {
        'layers': [
            {'name': 'background1', 'bg_removal': 'none', 'dither': 'ordered', 'texture': 2,
             'palette': ['e8c858', 'd8b040', 'c89830', 'b88020', 'f0d878', 'f8e898'],
             'prompt': 'Pixel art Egyptian desert sky. Hot golden-yellow sky with intense sun. Slight heat haze. Sandy warm tones throughout. 8-bit retro style. Full solid background.'},
            {'name': 'background2', 'bg_removal': 'topdown', 'bg_tolerance': 40, 'dither': 'fs', 'texture': 3,
             'palette': ['c89838', 'd8a848', 'e0b858', 'e8c868', 'b08830'],
             'prompt': 'Pixel art distant Egyptian pyramids. 2-3 golden sand pyramids of different sizes on the horizon. In lower 25% only. Upper 75% plain white. 8-bit retro style.'},
            {'name': 'background3', 'bg_removal': 'flood', 'dither': 'fs', 'texture': 2,
             'palette': ['e8d0a0', 'd8c090', 'c8b080', 'f0d8b0', 'e0c898'],
             'prompt': 'Pixel art desert sand clouds and dust devils. Swirling sand dust clouds drifting across frame. On plain white background. 8-bit retro style.'},
            {'name': 'midground1', 'bg_removal': 'topdown', 'bg_tolerance': 45, 'dither': 'fs', 'texture': 4, 'outline': True,
             'palette': ['886830', 'a88040', 'c89850', 'e0b060', 'f0c870', '604818'],
             'prompt': 'Pixel art large sphinx statue. Detailed golden sandstone sphinx with headdress facing right. On plain white background. In lower 35%. 8-bit retro style.'},
            {'name': 'midground2', 'bg_removal': 'topdown', 'bg_tolerance': 45, 'dither': 'fs', 'texture': 3,
             'palette': ['785828', '987040', 'b08850', 'c8a060', 'e0b870', '304028', '488038'],
             'prompt': 'Pixel art Egyptian obelisk and palm trees. Tall stone obelisk with hieroglyphs next to date palm trees. On plain white background. In lower 30%. 8-bit retro style.'},
            {'name': 'midground3', 'bg_removal': 'topdown', 'bg_tolerance': 45, 'dither': 'fs', 'texture': 2,
             'palette': ['684818', '886028', 'a07838', 'b89048', 'd0a858', '504010'],
             'prompt': 'Pixel art ancient Egyptian stone ruins and pottery. Crumbling stone blocks with hieroglyph fragments and clay pots. On plain white background. In lower 30%. 8-bit retro style.'},
            {'name': 'foreground1', 'bg_removal': 'topdown', 'bg_tolerance': 50, 'dither': 'fs', 'texture': 3,
             'palette': ['785020', '986830', 'b88040', 'd09850', 'e8b060', '504010', 'f0d068'],
             'prompt': 'Pixel art close-up sand dune with half-buried artifacts. Sandy dune with exposed gold coins, scarab beetle, pottery shards. On plain white background. In lower 25%. 8-bit retro style.'},
            {'name': 'foreground2', 'bg_removal': 'none', 'dither': 'ordered', 'texture': 2, 'h': 20,
             'palette': ['c89838', 'b88828', 'd0a848', 'e0b858', 'a87820'],
             'prompt': 'Pixel art desert sand ground. Hot golden sand surface with subtle ripple patterns. Full coverage strip. 8-bit retro style.'},
            {'name': 'foreground3', 'bg_removal': 'none', 'dither': 'ordered', 'texture': 1, 'h': 25,
             'palette': ['b88828', 'c89838', 'd8a848', 'e8b858', '987020'],
             'prompt': 'Pixel art sand ground with stone tile fragments. Sand with partial ancient stone floor tiles and hieroglyphs. Full coverage strip. 8-bit retro style.'},
        ]
    },
    'cave': {
        'layers': [
            {'name': 'background1', 'bg_removal': 'none', 'dither': 'ordered', 'texture': 2,
             'palette': ['040408', '080810', '0c0c18', '101020', '141428', '181830'],
             'prompt': 'Pixel art deep cave interior darkness. Almost pure black with very faint purple-blue ambient glow. Tiny distant glowing crystals like distant stars. Oppressive dark atmosphere. 8-bit retro style. Full solid background.'},
            {'name': 'background2', 'bg_removal': 'topdown', 'bg_tolerance': 35, 'dither': 'fs', 'texture': 3,
             'palette': ['0a0a14', '14141e', '1e1e28', '282832', '32323c'],
             'prompt': 'Pixel art distant cave wall stalactites hanging from above. Dark gray-purple rock formations dripping from the top and bottom of frame creating cave walls. In lower 25% and upper 15%. On plain white background between. 8-bit retro style.'},
            {'name': 'background3', 'bg_removal': 'flood', 'dither': 'fs', 'texture': 2,
             'palette': ['4040a0', '5050b8', '6868d0', '8080e0', 'a0a0f0'],
             'prompt': 'Pixel art glowing blue crystal clusters in cave. Small groups of luminescent blue crystals scattered in the frame. On plain white background. 8-bit retro style.'},
            {'name': 'midground1', 'bg_removal': 'topdown', 'bg_tolerance': 35, 'dither': 'fs', 'texture': 4, 'outline': True,
             'palette': ['08080c', '101018', '181824', '202030', '28283c', '5050a0'],
             'prompt': 'Pixel art large cave rock formation with crystal veins. Massive dark boulder with glowing blue-purple crystal seams running through it. On plain white background. In lower 35%. 8-bit retro style.'},
            {'name': 'midground2', 'bg_removal': 'topdown', 'bg_tolerance': 40, 'dither': 'fs', 'texture': 3,
             'palette': ['0c0c14', '18181e', '242428', '303038', '3c3c48', '6868c0', 'a8a8ff'],
             'prompt': 'Pixel art cave stalagmites rising from ground with dripping water. Tall pointed stalagmites with glistening wet surface and water droplets. On plain white background. In lower 30%. 8-bit retro style.'},
            {'name': 'midground3', 'bg_removal': 'topdown', 'bg_tolerance': 40, 'dither': 'fs', 'texture': 2,
             'palette': ['080810', '101018', '1a1a24', '242430', '30303c', '4848a0'],
             'prompt': 'Pixel art underground mushroom patch in cave. Clusters of bioluminescent mushrooms glowing soft purple-blue among dark rocks. On plain white background. In lower 30%. 8-bit retro style.'},
            {'name': 'foreground1', 'bg_removal': 'topdown', 'bg_tolerance': 40, 'dither': 'fs', 'texture': 3,
             'palette': ['06060a', '0e0e14', '16161e', '1e1e28', '282834', '5858b0', '8888e0'],
             'prompt': 'Pixel art close-up cave floor with puddles and crystals. Wet dark stone floor with small reflective puddles and scattered crystal shards. On plain white background. In lower 25%. 8-bit retro style.'},
            {'name': 'foreground2', 'bg_removal': 'none', 'dither': 'ordered', 'texture': 2, 'h': 20,
             'palette': ['08080c', '101014', '18181c', '202024', '14141a'],
             'prompt': 'Pixel art dark cave stone floor. Very dark gray-purple rough stone surface. Full coverage strip. 8-bit retro style.'},
            {'name': 'foreground3', 'bg_removal': 'none', 'dither': 'ordered', 'texture': 1, 'h': 25,
             'palette': ['06060a', '0c0c10', '121218', '181820', '4040a0'],
             'prompt': 'Pixel art cave floor with scattered gems and bone fragments. Dark stone with tiny gem sparkles and ancient bone pieces. Full coverage strip. 8-bit retro style.'},
        ]
    },
    'mountain': {
        'layers': [
            {'name': 'background1', 'bg_removal': 'none', 'dither': 'ordered', 'texture': 2,
             'palette': ['4080c0', '5898d0', '70b0e0', '88c8e8', 'a0d8f0', 'b8e4f8'],
             'prompt': 'Pixel art crisp alpine sky. Clear bright blue gradient from medium blue at top to pale blue at horizon. A few small white clouds. Clean mountain air feel. 8-bit retro style. Full solid background.'},
            {'name': 'background2', 'bg_removal': 'topdown', 'bg_tolerance': 40, 'dither': 'fs', 'texture': 3,
             'palette': ['586878', '6880a0', '7898b8', 'a0b8d0', 'c8d8e8', 'e0e8f0'],
             'prompt': 'Pixel art distant snow-capped mountain range. Blue-gray mountains with white snow peaks. In lower 25% only. Upper 75% plain white. 8-bit retro style.'},
            {'name': 'background3', 'bg_removal': 'flood', 'dither': 'fs', 'texture': 2,
             'palette': ['e0e8f0', 'c8d8e8', 'b0c8e0', 'f0f4f8', 'd8e0ec'],
             'prompt': 'Pixel art mountain clouds and mist. Wispy white cloud layers drifting between peaks. On plain white background. 8-bit retro style.'},
            {'name': 'midground1', 'bg_removal': 'topdown', 'bg_tolerance': 40, 'dither': 'fs', 'texture': 3, 'outline': True,
             'palette': ['384830', '486038', '587840', '689050', 'a0b880', 'e0e8d0'],
             'prompt': 'Pixel art alpine meadow hillside with wildflowers. Green mountain slope dotted with colorful alpine wildflowers. On plain white background. In lower 35%. 8-bit retro style.'},
            {'name': 'midground2', 'bg_removal': 'topdown', 'bg_tolerance': 45, 'dither': 'fs', 'texture': 3,
             'palette': ['283828', '384838', '485848', '586858', '384028', '506040'],
             'prompt': 'Pixel art pine tree grove on mountain slope. Cluster of dark green pine trees of varying sizes. On plain white background. In lower 30%. 8-bit retro style.'},
            {'name': 'midground3', 'bg_removal': 'topdown', 'bg_tolerance': 45, 'dither': 'fs', 'texture': 2,
             'palette': ['484038', '585048', '686058', '787068', '908878', '688090'],
             'prompt': 'Pixel art granite boulder field with mountain stream. Large gray granite rocks with a small blue mountain stream between them. On plain white background. In lower 30%. 8-bit retro style.'},
            {'name': 'foreground1', 'bg_removal': 'topdown', 'bg_tolerance': 50, 'dither': 'fs', 'texture': 3,
             'palette': ['283820', '384830', '486038', '587840', '689050', '98b070'],
             'prompt': 'Pixel art close-up alpine flowers and mountain grass. Detailed edelweiss, gentian, and other alpine flowers in grass. On plain white background. In lower 25%. 8-bit retro style.'},
            {'name': 'foreground2', 'bg_removal': 'none', 'dither': 'ordered', 'texture': 2, 'h': 20,
             'palette': ['384028', '485838', '587048', '688858', '789868'],
             'prompt': 'Pixel art mountain grass ground. Rich green alpine grass surface. Full coverage strip. 8-bit retro style.'},
            {'name': 'foreground3', 'bg_removal': 'none', 'dither': 'ordered', 'texture': 1, 'h': 25,
             'palette': ['303828', '405038', '506848', '607858', '485840'],
             'prompt': 'Pixel art rocky mountain ground with moss. Gray-brown rocky trail surface with patches of green moss. Full coverage strip. 8-bit retro style.'},
        ]
    },
    'space': {
        'layers': [
            {'name': 'background1', 'bg_removal': 'none', 'dither': 'ordered', 'texture': 2,
             'palette': ['000004', '020208', '04040c', '060810', '080c18', 'f0f0e0'],
             'prompt': 'Pixel art deep space background. Pure black void with thousands of tiny stars, a colorful nebula cloud in purple and blue, and a distant spiral galaxy. 8-bit retro style. Full solid background.'},
            {'name': 'background2', 'bg_removal': 'topdown', 'bg_tolerance': 35, 'dither': 'fs', 'texture': 3,
             'palette': ['100820', '200c30', '301040', '401450', '501860', '8020a0'],
             'prompt': 'Pixel art distant purple nebula cloud. Wispy colorful nebula gas cloud in purple and magenta. In lower 25%. Upper 75% plain white. 8-bit retro style.'},
            {'name': 'background3', 'bg_removal': 'flood', 'dither': 'fs', 'texture': 2,
             'palette': ['f0f0d0', 'e0e0c0', 'd0d0b0', 'c0c0a0', 'ffffe0'],
             'prompt': 'Pixel art scattered asteroid fragments and space debris. Small rocky asteroid chunks floating in space. On plain white background. 8-bit retro style.'},
            {'name': 'midground1', 'bg_removal': 'topdown', 'bg_tolerance': 35, 'dither': 'fs', 'texture': 3, 'outline': True,
             'palette': ['282020', '483830', '685040', '886850', '604828', 'a88060', '386080'],
             'prompt': 'Pixel art large cratered moon surface. Rocky gray-brown lunar landscape with impact craters and ridges in lower portion. On plain white background. In lower 35%. 8-bit retro style.'},
            {'name': 'midground2', 'bg_removal': 'topdown', 'bg_tolerance': 40, 'dither': 'fs', 'texture': 3,
             'palette': ['181420', '302838', '484050', '605868', '787080', 'ff4020', 'ff8040'],
             'prompt': 'Pixel art space station modules and solar panels. Metal space station segments with extended solar panel arrays. On plain white background. In lower 30%. 8-bit retro style.'},
            {'name': 'midground3', 'bg_removal': 'topdown', 'bg_tolerance': 40, 'dither': 'fs', 'texture': 2,
             'palette': ['201818', '382828', '503838', '684848', '805858', '30a0e0'],
             'prompt': 'Pixel art floating space rocks and crystals. Medium asteroid chunks with glowing crystal deposits embedded in them. On plain white background. In lower 30%. 8-bit retro style.'},
            {'name': 'foreground1', 'bg_removal': 'topdown', 'bg_tolerance': 40, 'dither': 'fs', 'texture': 3,
             'palette': ['181010', '302020', '483030', '604040', '785050', '20c0ff'],
             'prompt': 'Pixel art close-up rocky alien terrain. Detailed alien planet surface with unusual rock formations and bioluminescent pools. On plain white background. In lower 25%. 8-bit retro style.'},
            {'name': 'foreground2', 'bg_removal': 'none', 'dither': 'ordered', 'texture': 2, 'h': 20,
             'palette': ['181010', '281818', '382020', '482828', '302020'],
             'prompt': 'Pixel art alien rock ground. Dark gray-brown rocky surface with metallic sheen. Full coverage strip. 8-bit retro style.'},
            {'name': 'foreground3', 'bg_removal': 'none', 'dither': 'ordered', 'texture': 1, 'h': 25,
             'palette': ['100c0c', '201414', '301c1c', '402424', '10e0ff'],
             'prompt': 'Pixel art alien ground with glowing mineral veins. Dark rock with bright cyan-blue glowing crack patterns. Full coverage strip. 8-bit retro style.'},
        ]
    },
    'lagoon': {
        'layers': [
            {'name': 'background1', 'bg_removal': 'none', 'dither': 'ordered', 'texture': 2,
             'palette': ['1898a0', '20a8b0', '28b8c0', '38c8d0', '48d8e0', '58e0e8'],
             'prompt': 'Pixel art tropical lagoon sky. Bright turquoise-aqua gradient from teal at top to pale cyan at horizon. Warm tropical sunlight. Soft wispy clouds. 8-bit retro style. Full solid background.'},
            {'name': 'background2', 'bg_removal': 'topdown', 'bg_tolerance': 40, 'dither': 'fs', 'texture': 3,
             'palette': ['106040', '187850', '209060', '28a870', '30c080'],
             'prompt': 'Pixel art distant tropical island with palm trees. Small lush green island silhouette with palm tree outlines on the horizon. In lower 20% only. Upper 80% plain white. 8-bit retro style.'},
            {'name': 'background3', 'bg_removal': 'flood', 'dither': 'fs', 'texture': 2,
             'palette': ['40c8d0', '60d8e0', '80e0e8', 'a0e8f0', 'c0f0f8'],
             'prompt': 'Pixel art gentle ocean waves and light reflections. Shimmering turquoise water surface with sun sparkles. On plain white background. In lower 40%. 8-bit retro style.'},
            {'name': 'midground1', 'bg_removal': 'topdown', 'bg_tolerance': 40, 'dither': 'fs', 'texture': 3, 'outline': True,
             'palette': ['3a2810', '5a4020', '785828', '184818', '287028', '388838', '50a048'],
             'prompt': 'Pixel art tall coconut palm trees leaning over water. 2-3 tropical palm trees with curved trunks and large fronds. On plain white background. In lower 35%. 8-bit retro style.'},
            {'name': 'midground2', 'bg_removal': 'topdown', 'bg_tolerance': 45, 'dither': 'fs', 'texture': 3,
             'palette': ['10808a', '20909a', '30a0a8', '40b0b8', 'e8d8a0', 'f0e0b0'],
             'prompt': 'Pixel art shallow lagoon water with sandy patches. Crystal clear turquoise shallow water over white sand with visible sandy bottom. On plain white background. In lower 30%. 8-bit retro style.'},
            {'name': 'midground3', 'bg_removal': 'topdown', 'bg_tolerance': 45, 'dither': 'fs', 'texture': 2,
             'palette': ['10605a', '20786a', '30907a', 'ff6848', 'ff9060', 'ffc080'],
             'prompt': 'Pixel art tropical coral and colorful fish. Bright coral formations with small tropical fish swimming above. On plain white background. In lower 30%. 8-bit retro style.'},
            {'name': 'foreground1', 'bg_removal': 'topdown', 'bg_tolerance': 50, 'dither': 'fs', 'texture': 3,
             'palette': ['10484a', '20585a', '30686a', 'e8d098', 'f0d8a0', 'f8e0b0'],
             'prompt': 'Pixel art close-up beach shoreline with waves. Wet sand meeting turquoise water with gentle foam waves. On plain white background. In lower 25%. 8-bit retro style.'},
            {'name': 'foreground2', 'bg_removal': 'none', 'dither': 'ordered', 'texture': 2, 'h': 20,
             'palette': ['d8c080', 'e0c888', 'e8d098', 'f0d8a0', 'c8b870'],
             'prompt': 'Pixel art white sand beach ground. Bright warm white-gold sand surface. Full coverage strip. 8-bit retro style.'},
            {'name': 'foreground3', 'bg_removal': 'none', 'dither': 'ordered', 'texture': 1, 'h': 25,
             'palette': ['c8b068', 'd8c078', 'e0c888', 'e8d098', 'ff8870'],
             'prompt': 'Pixel art sand with seashells and starfish. White sand with scattered colorful seashells, a pink starfish, and seaweed bits. Full coverage strip. 8-bit retro style.'},
        ]
    },
    'losAngeles': {
        'layers': [
            {'name': 'background1', 'bg_removal': 'none', 'dither': 'ordered', 'texture': 2,
             'palette': ['f89850', 'e88040', 'd86830', 'c85020', 'f8b068', 'f8c888'],
             'prompt': 'Pixel art Los Angeles golden hour sky. Warm orange-pink gradient with soft smog haze. California dreamy sunset vibes. Palm tree-lined horizon glow. 8-bit retro style. Full solid background.'},
            {'name': 'background2', 'bg_removal': 'topdown', 'bg_tolerance': 40, 'dither': 'fs', 'texture': 3,
             'palette': ['382838', '483848', '584858', '685868', '786878'],
             'prompt': 'Pixel art distant LA downtown skyscraper skyline. Gray-purple building silhouettes through smog haze. In lower 20% only. Upper 80% plain white. 8-bit retro style.'},
            {'name': 'background3', 'bg_removal': 'flood', 'dither': 'fs', 'texture': 2,
             'palette': ['f8a868', 'e89858', 'f8b878', 'f8c888', 'f09050'],
             'prompt': 'Pixel art smoggy sunset clouds over LA. Warm orange-pink clouds with hazy glow. On plain white background. 8-bit retro style.'},
            {'name': 'midground1', 'bg_removal': 'topdown', 'bg_tolerance': 40, 'dither': 'fs', 'texture': 3, 'outline': True,
             'palette': ['1a1818', '2a2828', '3a3838', '4a4848', '5a5858', 'f8a050', 'ff4830'],
             'prompt': 'Pixel art Hollywood sign on hillside. Iconic white HOLLYWOOD letters on scrubby brown hillside with a water tower. On plain white background. In lower 35%. 8-bit retro style.'},
            {'name': 'midground2', 'bg_removal': 'topdown', 'bg_tolerance': 45, 'dither': 'fs', 'texture': 3,
             'palette': ['201810', '383020', '504830', '686040', '807850', '289030', '38a840'],
             'prompt': 'Pixel art row of tall palm trees lining a boulevard. Iconic LA tall thin palm tree silhouettes with tufted tops. On plain white background. In lower 30%. 8-bit retro style.'},
            {'name': 'midground3', 'bg_removal': 'topdown', 'bg_tolerance': 45, 'dither': 'fs', 'texture': 2,
             'palette': ['181818', '303030', '484848', '606060', '787878', 'ff3030', 'ffff40'],
             'prompt': 'Pixel art retro motel sign and low-rise buildings. Classic neon motel sign, mid-century modern building with flat roof. On plain white background. In lower 30%. 8-bit retro style.'},
            {'name': 'foreground1', 'bg_removal': 'topdown', 'bg_tolerance': 50, 'dither': 'fs', 'texture': 3,
             'palette': ['202020', '383838', '505050', '686868', '808080', 'f0c040', 'ffffff'],
             'prompt': 'Pixel art close-up sidewalk with Walk of Fame star and movie camera. Hollywood Walk of Fame star embedded in concrete with small director chair. On plain white background. In lower 25%. 8-bit retro style.'},
            {'name': 'foreground2', 'bg_removal': 'none', 'dither': 'ordered', 'texture': 2, 'h': 20,
             'palette': ['484848', '585858', '686868', '787878', '888888'],
             'prompt': 'Pixel art concrete sidewalk ground. Gray concrete pavement with subtle cracks. Full coverage strip. 8-bit retro style.'},
            {'name': 'foreground3', 'bg_removal': 'none', 'dither': 'ordered', 'texture': 1, 'h': 25,
             'palette': ['383838', '484848', '585858', '686868', 'f0c030'],
             'prompt': 'Pixel art road asphalt with painted lane markings. Dark gray asphalt with a yellow dashed center line. Full coverage strip. 8-bit retro style.'},
        ]
    },
    'london': {
        'layers': [
            {'name': 'background1', 'bg_removal': 'none', 'dither': 'ordered', 'texture': 2,
             'palette': ['889098', '98a0a8', 'a8b0b8', 'b8c0c8', 'c8d0d8', '788088'],
             'prompt': 'Pixel art overcast London sky. Gray cloudy sky with heavy cloud cover. Moody atmospheric British weather. Subtle blue-gray tones. 8-bit retro style. Full solid background.'},
            {'name': 'background2', 'bg_removal': 'topdown', 'bg_tolerance': 40, 'dither': 'fs', 'texture': 3,
             'palette': ['303840', '404850', '505860', '606870', '707880'],
             'prompt': 'Pixel art distant London skyline with Big Ben and The Shard. Foggy gray building silhouettes with clock tower prominent. In lower 25% only. Upper 75% plain white. 8-bit retro style.'},
            {'name': 'background3', 'bg_removal': 'flood', 'dither': 'fs', 'texture': 2,
             'palette': ['a0a8b0', 'b0b8c0', 'c0c8d0', 'd0d8e0', '909aa0'],
             'prompt': 'Pixel art London fog and rain. Misty fog wisps and falling rain streaks. On plain white background. 8-bit retro style.'},
            {'name': 'midground1', 'bg_removal': 'topdown', 'bg_tolerance': 40, 'dither': 'fs', 'texture': 3, 'outline': True,
             'palette': ['281818', '402828', '583838', '704848', '885858', '602828'],
             'prompt': 'Pixel art iconic red London double-decker bus and phone box. Classic red bus next to a red telephone booth. On plain white background. In lower 35%. 8-bit retro style.'},
            {'name': 'midground2', 'bg_removal': 'topdown', 'bg_tolerance': 45, 'dither': 'fs', 'texture': 3,
             'palette': ['282020', '403030', '584040', '705050', '886060', '303840'],
             'prompt': 'Pixel art row of Victorian brick townhouses. Red-brown brick Georgian terraced houses with white window frames and iron railings. On plain white background. In lower 30%. 8-bit retro style.'},
            {'name': 'midground3', 'bg_removal': 'topdown', 'bg_tolerance': 45, 'dither': 'fs', 'texture': 2,
             'palette': ['181818', '282828', '383838', '484848', '585858', '181c20'],
             'prompt': 'Pixel art vintage street lamp and park bench. Ornate Victorian cast iron street lamp next to a wooden park bench. On plain white background. In lower 30%. 8-bit retro style.'},
            {'name': 'foreground1', 'bg_removal': 'topdown', 'bg_tolerance': 50, 'dither': 'fs', 'texture': 3,
             'palette': ['181c18', '283028', '384038', '485048', '586058', '8898a0'],
             'prompt': 'Pixel art close-up iron fence with ivy and puddle. Black wrought iron fence with climbing ivy and a rain puddle reflecting light. On plain white background. In lower 25%. 8-bit retro style.'},
            {'name': 'foreground2', 'bg_removal': 'none', 'dither': 'ordered', 'texture': 2, 'h': 20,
             'palette': ['383838', '484848', '585858', '686868', '404040'],
             'prompt': 'Pixel art wet cobblestone ground. Dark gray wet cobblestones with rain puddle reflections. Full coverage strip. 8-bit retro style.'},
            {'name': 'foreground3', 'bg_removal': 'none', 'dither': 'ordered', 'texture': 1, 'h': 25,
             'palette': ['303030', '404040', '505050', '606060', '283028'],
             'prompt': 'Pixel art wet pavement with fallen autumn leaves. Dark wet stone with scattered brown and orange fallen leaves. Full coverage strip. 8-bit retro style.'},
        ]
    },
}

# ============================================================
# MAIN EXECUTION
# ============================================================

async def generate_theme(theme_name, theme_def):
    """Generate all 9 layers for one theme."""
    from sdk.tools.utils_tools import coworker_text2im
    
    out_dir = os.path.join(BASE_OUT, theme_name)
    os.makedirs(out_dir, exist_ok=True)
    
    print(f"\n{'='*60}")
    print(f"  THEME: {theme_name}")
    print(f"{'='*60}")
    
    layer_paths = []
    for ldef in theme_def['layers']:
        name = ldef['name']
        print(f"\n  🎨 {name}...")
        
        result = await coworker_text2im(
            prompt=ldef['prompt'],
            aspect_ratio="3:2",
        )
        print(f"    AI: {result.local_path}")
        
        # Background removal
        bg_mode = ldef.get('bg_removal', 'none')
        if bg_mode == 'topdown':
            img = remove_bg_topdown(result.local_path, tolerance=ldef.get('bg_tolerance', 50))
        elif bg_mode == 'flood':
            img = remove_bg_flood(result.local_path)
        else:
            img = Image.open(result.local_path).convert('RGBA')
        
        # Layer dimensions
        lw = ldef.get('w', NATIVE_W)
        lh = ldef.get('h', NATIVE_H)
        
        path = process_layer(
            img, name, ldef['palette'], lw, lh, out_dir,
            dither=ldef.get('dither', 'fs'),
            texture_amt=ldef.get('texture', 3),
            outline=ldef.get('outline', False),
        )
        layer_paths.append((name, path))
    
    comp_path, strip_path = make_composite(layer_paths, out_dir, theme_name)
    print(f"\n  ✓ {theme_name} complete!")
    return comp_path, strip_path

async def main():
    import sys
    # Accept theme names as args, or run all
    if len(sys.argv) > 1:
        themes_to_run = sys.argv[1:]
    else:
        themes_to_run = list(THEMES.keys())
    
    print(f"=== FloppyDuck Production Pipeline ===")
    print(f"Themes: {', '.join(themes_to_run)}")
    print(f"Total layers: {len(themes_to_run) * 9}\n")
    
    results = {}
    for tname in themes_to_run:
        if tname not in THEMES:
            print(f"Unknown theme: {tname}")
            continue
        comp, strip = await generate_theme(tname, THEMES[tname])
        results[tname] = (comp, strip)
    
    print(f"\n{'='*60}")
    print(f"  ALL DONE! Generated {len(results)} themes")
    print(f"{'='*60}")
    for tname, (comp, strip) in results.items():
        print(f"  {tname}: {comp}")

asyncio.run(main())
