"""
Volcano theme v6 — Real dithering tooling + BRIGHTER, higher-contrast palettes.
Fix from v5: too dark/muddy. Need clear visual separation between layers.

Key changes:
- Sky: deeper reds at top, bright orange glow at horizon
- Volcano: MUCH larger, fills more of the frame, with visible rock detail
- Lava: brighter yellows/whites at hottest points
- More color range within each palette
- Better value separation between layers
"""
import sys, os, subprocess, random, math
sys.path.insert(0, '/work/pixel_art')
from PIL import Image, ImageDraw

ENGINE = '/work/pixel_tools/pixelart_engine'
OUT = '/work/pixel_art/output_v3/volcano'
TEMP = '/work/pixel_art/output_v3/volcano/temp'
NATIVE_W, NATIVE_H = 200, 155
GROUND_H, OVERLAY_H = 20, 25

os.makedirs(OUT, exist_ok=True)
os.makedirs(TEMP, exist_ok=True)

def run_engine(args):
    cmd = [ENGINE] + args
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        print(f"  ENGINE ERROR: {r.stderr}")
    return r.returncode == 0

def save_raw(img, name):
    path = os.path.join(TEMP, f'{name}_raw.png')
    img.save(path)
    return path

def process_layer(raw_path, name, palette_hex, dither='fs', texture_amt=3, outline=False, outline_color='1a0a00'):
    step1 = os.path.join(TEMP, f'{name}_dithered.png')
    step2 = os.path.join(TEMP, f'{name}_textured.png')
    final = os.path.join(TEMP, f'{name}_final.png')
    
    if dither == 'fs':
        run_engine(['dither_fs', raw_path, step1] + palette_hex)
    elif dither == 'ordered':
        run_engine(['dither_ordered', raw_path, step1, '4'] + palette_hex)
    else:
        from shutil import copy2; copy2(raw_path, step1)
    
    if texture_amt > 0:
        run_engine(['texture', step1, step2, str(texture_amt), str(random.randint(1, 9999))])
    else:
        from shutil import copy2; copy2(step1, step2)
    
    if outline:
        run_engine(['outline', step2, final, outline_color, '40'])
    else:
        from shutil import copy2; copy2(step2, final)
    
    return final

def upscale_4x(img_path, out_name, w, h):
    img = Image.open(img_path)
    upscaled = img.resize((w * 4, h * 4), Image.NEAREST)
    out_path = os.path.join(OUT, f'{out_name}.png')
    upscaled.save(out_path)
    print(f"  ✓ {out_name}.png ({w}×{h} → {w*4}×{h*4})")
    return out_path

def px(img, x, y, color):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), color)

# ============================================================
# BRIGHTER PALETTES — more range, better contrast
# ============================================================
# bg1: volcanic sky — deep red top to orange-red glow at bottom
PAL_SKY = ['120208', '2a0810', '4e1420', '782838', '9e3c30', 'c85828']
# bg2: distant mountains — muted warm grays to distinguish from sky
PAL_DIST = ['1e0e0a', '3a2018', '5a3828', '7a5038', '986848']
# bg3: smoke — warm gray with some variation
PAL_SMOKE = ['2a2028', '4a3840', '6a5560', '8a7278', 'a89090']
# mid1: volcano rock — wider range, visible detail
PAL_VOLCANO_ROCK = ['18100a', '302014', '4a3020', '684828', 'a06830', 'c88838']
# mid2: lava surface — HOT: deep red to bright yellow-white
PAL_LAVA = ['4a0c00', '8e1800', 'cc3808', 'e87020', 'ffaa38', 'ffe870']
# mid3: basalt columns — cooler dark tones (contrast with warm lava)
PAL_BASALT = ['0c0a10', '181620', '282430', '383440', '4a4858']
# fg1: lava river — brightest, most saturated
PAL_RIVER = ['580800', 'a01808', 'e03810', 'ff6828', 'ff9838', 'ffcc58', 'ffe888']
# fg2: cracked ground — dark with orange glow cracks
PAL_GROUND = ['100808', '201410', '301c14', '4a2c1c', 'e86020']
# fg3: overlay — dark with bright ember accents
PAL_OVERLAY = ['0a0808', '181210', '281c14', 'ff8020', 'ffcc40']

print("Generating volcano v6 with brighter palettes...\n")

# --- bg1: Volcanic sky ---
img = Image.new('RGBA', (NATIVE_W, NATIVE_H), (0,0,0,0))
for y in range(NATIVE_H):
    t = y / NATIVE_H
    # Top: deep dark red, bottom: orange glow
    r = int(18 + t * 180)
    g = int(2 + t * 70)
    b = int(8 + t * 25)
    for x in range(NATIVE_W):
        px(img, x, y, (r, g, b, 255))
# Subtle stars/embers in upper sky
for _ in range(20):
    x, y = random.randint(0, NATIVE_W-1), random.randint(0, NATIVE_H//2)
    brightness = random.randint(100, 200)
    px(img, x, y, (brightness, brightness//2, brightness//4, 200))
raw = save_raw(img, 'bg1')
final = process_layer(raw, 'bg1', PAL_SKY, dither='ordered', texture_amt=2)
upscale_4x(final, 'volcano_background1', NATIVE_W, NATIVE_H)

# --- bg2: Distant volcanic range ---
img = Image.new('RGBA', (NATIVE_W, NATIVE_H), (0,0,0,0))
# Jagged mountain silhouette with organic randomness
heights = []
h_val = 45
for x in range(NATIVE_W):
    h_val += random.uniform(-2.5, 2.5)
    # Create 3 distinct peaks
    for px_peak, ph in [(35, 85), (95, 70), (160, 60)]:
        dist = abs(x - px_peak)
        if dist < 30:
            pull = (1 - dist/30) * ph
            h_val = max(h_val, pull)
    h_val = max(25, min(95, h_val))
    heights.append(h_val)
# Smooth
for _ in range(2):
    heights = [(heights[max(0,i-1)] + heights[i] + heights[min(len(heights)-1,i+1)])/3 for i in range(len(heights))]

for x in range(NATIVE_W):
    top = NATIVE_H - int(heights[x])
    for y in range(top, NATIVE_H):
        t = (y - top) / max(1, NATIVE_H - top)
        # Lighter at bottom (atmospheric haze), darker at top
        r = int(30 + t * 90)
        g = int(14 + t * 55)
        b = int(10 + t * 40)
        px(img, x, y, (r, g, b, 255))
raw = save_raw(img, 'bg2')
final = process_layer(raw, 'bg2', PAL_DIST, dither='fs', texture_amt=3)
upscale_4x(final, 'volcano_background2', NATIVE_W, NATIVE_H)

# --- bg3: Smoke plumes ---
img = Image.new('RGBA', (NATIVE_W, NATIVE_H), (0,0,0,0))
def draw_smoke_cloud(img, cx, cy, radius, base_val):
    for dy in range(-radius, radius+1):
        for dx in range(-radius, radius+1):
            dist = math.sqrt(dx*dx + dy*dy)
            if dist <= radius:
                fade = 1 - (dist / radius) ** 1.3
                alpha = int(fade * 220)
                x, y = cx+dx, cy+dy
                if 0 <= x < NATIVE_W and 0 <= y < NATIVE_H:
                    v = int(base_val * (0.85 + random.uniform(0, 0.3)))
                    warm = random.randint(0, 10)
                    px(img, x, y, (min(255, v+warm), v, max(0, v-5), min(255, alpha)))

# Rising smoke columns
for base_x in [45, 100, 155]:
    for i in range(7):
        ox = random.randint(-12, 12) + int(math.sin(i*0.5) * 8)
        oy = i * 12
        r = random.randint(8, 18)
        v = 80 + i * 8  # Gets lighter as smoke rises and thins
        draw_smoke_cloud(img, base_x + ox, 20 + oy, r, v)

raw = save_raw(img, 'bg3')
final = process_layer(raw, 'bg3', PAL_SMOKE, dither='fs', texture_amt=2)
upscale_4x(final, 'volcano_background3', NATIVE_W, NATIVE_H)

# --- mid1: Main volcano (LARGE, prominent) ---
img = Image.new('RGBA', (NATIVE_W, NATIVE_H), (0,0,0,0))
# Big asymmetric volcano filling most of the width
peak_x, peak_y = 105, 18  # higher peak
left_base, right_base = 5, 198  # nearly full width

for y in range(peak_y, NATIVE_H):
    t = (y - peak_y) / (NATIVE_H - peak_y)
    # Wider spread with some irregularity
    left_x = int(peak_x - t * (peak_x - left_base) + math.sin(y*0.3)*2)
    right_x = int(peak_x + t * (right_base - peak_x) + math.sin(y*0.25)*2)
    for x in range(max(0, left_x), min(NATIVE_W, right_x)):
        # 3D-ish shading: center lighter, edges darker
        center_dist = abs(x - peak_x) / max(1, (right_x - left_x) / 2)
        shade = 0.5 + 0.5 * (1 - center_dist ** 1.5)
        v_shade = 0.4 + 0.6 * t  # darker near peak (shadow)
        r = int(100 * shade * v_shade)
        g = int(68 * shade * v_shade)
        b = int(40 * shade * v_shade)
        # Add rock texture variation
        noise = random.randint(-8, 8)
        r = max(0, min(255, r + noise))
        g = max(0, min(255, g + noise))
        b = max(0, min(255, b + noise))
        px(img, x, y, (r, g, b, 255))

# Crater glow (wider, brighter)
for y in range(peak_y - 3, peak_y + 15):
    crater_w = max(0, int(8 + (y - peak_y) * 1.2))
    for x in range(peak_x - crater_w, peak_x + crater_w):
        if 0 <= x < NATIVE_W and 0 <= y < NATIVE_H:
            dist_from_center = abs(x - peak_x) / max(1, crater_w)
            heat = 1 - dist_from_center
            r = int(200 + heat * 55)
            g = int(80 + heat * 120)
            b = int(10 + heat * 30)
            px(img, x, y, (min(255,r), min(255,g), min(255,b), 255))

# Lava veins down the slopes
for stream_start in [peak_x - 30, peak_x - 8, peak_x + 18, peak_x + 35]:
    sx = stream_start
    for y in range(peak_y + 15, NATIVE_H - 10):
        sx += random.uniform(-0.8, 0.8)
        for dx in range(-1, 2):
            ix = int(sx) + dx
            if 0 <= ix < NATIVE_W and 0 <= y < NATIVE_H:
                heat = 1 - abs(dx) * 0.3
                r = int(220 * heat)
                g = int(100 * heat)
                b = int(15 * heat)
                px(img, ix, y, (min(255,r), min(255,g), min(255,b), 255))

raw = save_raw(img, 'mid1')
final = process_layer(raw, 'mid1', PAL_VOLCANO_ROCK, dither='fs', texture_amt=4, outline=True, outline_color='100a06')
upscale_4x(final, 'volcano_midground1', NATIVE_W, NATIVE_H)

# --- mid2: Lava lake (bright, churning) ---
img = Image.new('RGBA', (NATIVE_W, NATIVE_H), (0,0,0,0))
lava_top = 80
for y in range(lava_top, NATIVE_H):
    for x in range(NATIVE_W):
        t = (y - lava_top) / (NATIVE_H - lava_top)
        # Churning lava with flow patterns
        flow = math.sin(x * 0.12 + y * 0.08) * 0.5 + 0.5
        heat = math.sin(x * 0.05 + y * 0.15 + flow * 2) * 0.3 + 0.7
        r = int(160 + heat * 95)
        g = int(50 + heat * 130 + flow * 40)
        b = int(5 + heat * 50 + flow * 20)
        # Cooler crust patches
        crust = math.sin(x * 0.3) * math.sin(y * 0.2)
        if crust > 0.5:
            r = int(r * 0.4)
            g = int(g * 0.3)
            b = int(b * 0.3)
        px(img, x, y, (min(255,r), min(255,g), max(0,b), 255))

# Bright bubbles
for _ in range(10):
    bx = random.randint(8, NATIVE_W-8)
    by = random.randint(lava_top+3, lava_top+30)
    br = random.randint(2, 4)
    for dy in range(-br, br+1):
        for dx in range(-br, br+1):
            if dx*dx + dy*dy <= br*br:
                glow = 1 - math.sqrt(dx*dx+dy*dy)/br
                r = int(255 * glow + 200 * (1-glow))
                g = int(230 * glow + 80 * (1-glow))
                b = int(100 * glow + 10 * (1-glow))
                nx, ny = bx+dx, by+dy
                if 0 <= nx < NATIVE_W and 0 <= ny < NATIVE_H:
                    px(img, nx, ny, (min(255,r), min(255,g), min(255,b), 255))

raw = save_raw(img, 'mid2')
final = process_layer(raw, 'mid2', PAL_LAVA, dither='fs', texture_amt=3)
upscale_4x(final, 'volcano_midground2', NATIVE_W, NATIVE_H)

# --- mid3: Basalt columns (COOL tones for contrast) ---
img = Image.new('RGBA', (NATIVE_W, NATIVE_H), (0,0,0,0))
# Irregular basalt columns — cooler blue-gray to contrast with warm layers
columns = []
cx = 3
while cx < NATIVE_W:
    w = random.randint(6, 12)
    h = random.randint(40, 80)
    columns.append((cx, w, h))
    cx += w + random.randint(1, 4)

for cx, cw, ch in columns:
    top_y = NATIVE_H - ch
    for y in range(top_y, NATIVE_H):
        for dx in range(cw):
            x = cx + dx
            if 0 <= x < NATIVE_W:
                # Side shading
                edge_shade = 1 - abs(dx - cw/2) / (cw/2) * 0.4
                depth_shade = 0.6 + 0.4 * ((y - top_y) / ch)
                v = int(55 * edge_shade * depth_shade)
                # Cool blue tint
                r = max(0, v - 5)
                g = max(0, v - 2)
                b = max(0, v + 8)
                px(img, x, y, (r, g, b, 255))
        # Column cap (lighter)
        for dx in range(cw):
            x = cx + dx
            if 0 <= x < NATIVE_W:
                px(img, x, top_y, (60, 58, 70, 255))
                if top_y + 1 < NATIVE_H:
                    px(img, x, top_y+1, (50, 48, 60, 255))

raw = save_raw(img, 'mid3')
final = process_layer(raw, 'mid3', PAL_BASALT, dither='ordered', texture_amt=3, outline=True, outline_color='060408')
upscale_4x(final, 'volcano_midground3', NATIVE_W, NATIVE_H)

# --- fg1: Lava river (BRIGHTEST layer) ---
img = Image.new('RGBA', (NATIVE_W, NATIVE_H), (0,0,0,0))
river_top = 95
for y in range(river_top, NATIVE_H):
    for x in range(NATIVE_W):
        t = (y - river_top) / (NATIVE_H - river_top)
        # Intense flowing lava
        flow1 = math.sin(x * 0.1 + y * 0.15) * 0.5 + 0.5
        flow2 = math.sin(x * 0.07 - y * 0.1 + 2) * 0.5 + 0.5
        heat = (flow1 + flow2) / 2
        r = int(180 + heat * 75)
        g = int(80 + heat * 120)
        b = int(10 + heat * 80)
        px(img, x, y, (min(255,r), min(255,g), min(255,b), 255))

# Hot rocks — dark centers with glowing rims
for _ in range(8):
    rx = random.randint(6, NATIVE_W-6)
    ry = random.randint(river_top+3, NATIVE_H-8)
    rr = random.randint(3, 5)
    for dy in range(-rr, rr+1):
        for dx in range(-rr, rr+1):
            dist = math.sqrt(dx*dx + dy*dy)
            if dist <= rr:
                nx, ny = rx+dx, ry+dy
                if 0 <= nx < NATIVE_W and 0 <= ny < NATIVE_H:
                    if dist > rr * 0.6:
                        # Glowing rim
                        px(img, nx, ny, (255, 200, 60, 255))
                    else:
                        # Dark rock
                        v = random.randint(25, 40)
                        px(img, nx, ny, (v, v-5, v-8, 255))

raw = save_raw(img, 'fg1')
final = process_layer(raw, 'fg1', PAL_RIVER, dither='fs', texture_amt=3)
upscale_4x(final, 'volcano_foreground1', NATIVE_W, NATIVE_H)

# --- fg2: Cracked ground (200x20) ---
img = Image.new('RGBA', (NATIVE_W, GROUND_H), (0,0,0,0))
for y in range(GROUND_H):
    for x in range(NATIVE_W):
        v = 20 + random.randint(0, 12)
        px(img, x, y, (v+5, v, v-3, 255))

# Glowing cracks (more of them, brighter)
cx = 0
while cx < NATIVE_W:
    cy = random.randint(3, GROUND_H-4)
    length = random.randint(8, 25)
    for dx in range(length):
        x = cx + dx
        cy += random.choice([-1, 0, 0, 0, 1])
        cy = max(1, min(GROUND_H-2, cy))
        if 0 <= x < NATIVE_W:
            # Bright crack
            px(img, x, cy, (230, 100, 15, 255))
            # Glow halo
            for gy in [-1, 1]:
                if 0 <= cy+gy < GROUND_H:
                    px(img, x, cy+gy, (120, 50, 8, 255))
    cx += length + random.randint(5, 15)

raw = save_raw(img, 'fg2')
final = process_layer(raw, 'fg2', PAL_GROUND, dither='ordered', texture_amt=2)
upscale_4x(final, 'volcano_foreground2', NATIVE_W, GROUND_H)

# --- fg3: Embers overlay (200x25) ---
img = Image.new('RGBA', (NATIVE_W, OVERLAY_H), (0,0,0,0))
for y in range(OVERLAY_H):
    for x in range(NATIVE_W):
        v = 10 + random.randint(0, 8)
        px(img, x, y, (v+3, v, v-2, 255))

# Bright embers scattered
for _ in range(35):
    ex = random.randint(0, NATIVE_W-1)
    ey = random.randint(0, OVERLAY_H-1)
    intensity = random.uniform(0.6, 1.0)
    r = int(255 * intensity)
    g = int(160 * intensity * random.uniform(0.4, 0.9))
    b = int(30 * intensity)
    px(img, ex, ey, (r, g, b, 255))
    # Cross glow
    for dx, dy in [(-1,0),(1,0),(0,-1),(0,1)]:
        if 0 <= ex+dx < NATIVE_W and 0 <= ey+dy < OVERLAY_H:
            px(img, ex+dx, ey+dy, (r//3, g//3, b//3, 255))

# Ash mounds
for ax in range(0, NATIVE_W, random.randint(20, 35)):
    pw = random.randint(6, 14)
    ph = random.randint(2, 5)
    for dy in range(ph):
        for dx in range(pw - dy*2):
            x = ax + dx + dy
            y = OVERLAY_H - 1 - dy
            if 0 <= x < NATIVE_W and 0 <= y < OVERLAY_H:
                v = 25 + random.randint(0, 10)
                px(img, x, y, (v+4, v, v-2, 255))

raw = save_raw(img, 'fg3')
final = process_layer(raw, 'fg3', PAL_OVERLAY, dither='ordered', texture_amt=1)
upscale_4x(final, 'volcano_foreground3', NATIVE_W, OVERLAY_H)

# ============================================================
# COMPOSITE
# ============================================================
print("\nCreating composite...")

layer_names = ['background1', 'background2', 'background3',
               'midground1', 'midground2', 'midground3',
               'foreground1', 'foreground2', 'foreground3']

comp_w, comp_h = NATIVE_W * 4, NATIVE_H * 4
comp = Image.new('RGBA', (comp_w, comp_h), (0,0,0,255))

for name in layer_names:
    path = os.path.join(OUT, f'volcano_{name}.png')
    if not os.path.exists(path):
        continue
    layer = Image.open(path).convert('RGBA')
    
    if 'foreground2' in name or 'foreground3' in name:
        y_offset = comp_h - layer.height
        temp = Image.new('RGBA', (comp_w, comp_h), (0,0,0,0))
        for x in range(0, comp_w, layer.width):
            temp.paste(layer, (x, y_offset))
        comp = Image.alpha_composite(comp, temp)
    else:
        temp = Image.new('RGBA', (comp_w, comp_h), (0,0,0,0))
        temp.paste(layer, (0, 0))
        comp = Image.alpha_composite(comp, temp)

comp_path = os.path.join(OUT, 'volcano_composite_v6.png')
comp.convert('RGB').save(comp_path)
print(f"  ✓ Composite: {comp_path}")

# Layer strip (3x3 grid)
sw = NATIVE_W * 4
sh = NATIVE_H * 4
strip = Image.new('RGB', (sw * 3 + 20, sh * 3 + 80), (30, 30, 35))

for i, name in enumerate(layer_names):
    path = os.path.join(OUT, f'volcano_{name}.png')
    if not os.path.exists(path):
        continue
    layer = Image.open(path).convert('RGB')
    row, col = i // 3, i % 3
    xo = 10 + col * (sw + 0)
    yo = 40 + row * (sh + 0)
    
    cell = Image.new('RGB', (sw, sh), (30, 30, 35))
    if 'foreground2' in name or 'foreground3' in name:
        paste_y = sh - layer.height
        cell.paste(layer, (0, paste_y))
    else:
        cell.paste(layer, (0, 0))
    strip.paste(cell, (xo, yo))

strip_path = os.path.join(OUT, 'volcano_layers_strip_v6.png')
strip.save(strip_path)
print(f"  ✓ Layer strip: {strip_path}")

print("\n✓ Volcano v6 complete!")
