"""
Shared pixel art utilities for all themes.
Drawing primitives, heightmaps, save functions.
"""
from PIL import Image
import os, math, random

NATIVE_W = 200
NATIVE_H = 155
GROUND_H = 20
OVERLAY_H = 25
SCALE = 4


def px(img, x, y, color):
    w, h = img.size
    if 0 <= x < w and 0 <= y < h:
        if len(color) == 3: color = color + (255,)
        img.load()[x, y] = color

def get_px(img, x, y):
    w, h = img.size
    if 0 <= x < w and 0 <= y < h:
        return img.load()[x, y]
    return (0, 0, 0, 0)

def lerp(c1, c2, t):
    t = max(0.0, min(1.0, t))
    r = [int(c1[i] + (c2[i] - c1[i]) * t) for i in range(min(len(c1), len(c2)))]
    if len(r) == 3: r.append(255)
    return tuple(r)

def hand_heightmap(width, points):
    """Linear interpolation heightmap (angular terrain)."""
    points = sorted(points, key=lambda p: p[0])
    if points[0][0] > 0: points.insert(0, (0, points[0][1]))
    if points[-1][0] < width - 1: points.append((width - 1, points[-1][1]))
    hmap = [0] * width
    for x in range(width):
        left = points[0]; right = points[-1]
        for i in range(len(points) - 1):
            if points[i][0] <= x <= points[i + 1][0]:
                left = points[i]; right = points[i + 1]; break
        span = right[0] - left[0]
        t = (x - left[0]) / span if span else 0
        hmap[x] = int(left[1] + (right[1] - left[1]) * t)
    return hmap

def cosine_heightmap(width, points):
    """Cosine interpolation heightmap (smooth rolling hills)."""
    points = sorted(points, key=lambda p: p[0])
    if points[0][0] > 0: points.insert(0, (0, points[0][1]))
    if points[-1][0] < width - 1: points.append((width - 1, points[-1][1]))
    hmap = [0] * width
    for x in range(width):
        left = points[0]; right = points[-1]
        for i in range(len(points) - 1):
            if points[i][0] <= x <= points[i + 1][0]:
                left = points[i]; right = points[i + 1]; break
        span = right[0] - left[0]
        t = (x - left[0]) / span if span else 0
        t = (1 - math.cos(t * math.pi)) / 2
        hmap[x] = int(left[1] + (right[1] - left[1]) * t)
    return hmap


def fill_terrain(img, heightmap, colors, outline_color=None):
    """Fill terrain from heightmap down. colors = list of (color, depth_threshold)."""
    w, h = img.size
    for x in range(w):
        top_y = heightmap[x]
        if top_y >= h: continue
        col_h = h - top_y
        for y in range(top_y, h):
            d = (y - top_y) / max(col_h - 1, 1)
            col = colors[-1][0]
            for c, thresh in colors:
                if d < thresh:
                    col = c; break
            # Texture noise
            n = (x * 13 + y * 7 + 42) % 23
            if n < 2: col = lerp(col, (0, 0, 0, col[3] if len(col) > 3 else 255), 0.12)
            px(img, x, y, col)
        if outline_color and top_y < h:
            px(img, x, top_y, outline_color)


def draw_string_sprite(img, cx, cy, rows, color_map):
    """Draw from a string map centered at cx, cy."""
    h = len(rows)
    w = max(len(r) for r in rows)
    for ry, row in enumerate(rows):
        for rx, ch in enumerate(row):
            if ch in color_map:
                px(img, cx - w // 2 + rx, cy - h // 2 + ry, color_map[ch])


def draw_ellipse(img, cx, cy, rx, ry, color_func, outline=None, seed=0):
    """Draw a filled ellipse with custom color function(dist, dx, dy)."""
    random.seed(seed)
    for dy in range(-ry - 1, ry + 2):
        for dx in range(-rx - 1, rx + 2):
            distort = 0.1 * math.sin(dy * 0.5 + seed) + 0.08 * math.cos(dx * 0.3 + seed * 2)
            dist = math.sqrt((dx / max(rx, 1)) ** 2 + (dy / max(ry, 1)) ** 2) + distort * 0.2
            if dist > 1.0: continue
            col = color_func(dist, dx, dy)
            if col:
                px(img, cx + dx, cy + dy, col)
    
    if outline:
        for angle_deg in range(0, 360, 4):
            angle = math.radians(angle_deg)
            ox = cx + int(math.cos(angle) * (rx + 1))
            oy = cy + int(math.sin(angle) * (ry + 1))
            px(img, ox, oy, outline)


def save_layer(img, path):
    w, h = img.size
    if h == GROUND_H:
        out = img.resize((w * SCALE, 80), Image.NEAREST)
    elif h == OVERLAY_H:
        out = img.resize((w * SCALE, 100), Image.NEAREST)
    else:
        out = img.resize((w * SCALE, h * SCALE), Image.NEAREST)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    out.save(path)
    print(f"  ✓ {os.path.basename(path)} ({w}×{h} → {out.size[0]}×{out.size[1]})")


def make_composite(layer_dir, theme_name, sky_colors):
    """Build composite from layers with sky gradient.
    sky_colors = [(r,g,b) top, (r,g,b) bottom]
    """
    OUT_W, OUT_H = 800, 700
    sky = Image.new('RGBA', (OUT_W, OUT_H), (0, 0, 0, 255))
    top, bot = sky_colors
    for y in range(OUT_H):
        t = y / OUT_H
        r = int(top[0] + (bot[0] - top[0]) * t)
        g = int(top[1] + (bot[1] - top[1]) * t)
        b = int(top[2] + (bot[2] - top[2]) * t)
        for x in range(OUT_W):
            sky.putpixel((x, y), (r, g, b, 255))
    
    layers_order = [
        (f'{theme_name}_background1.png', 0),
        (f'{theme_name}_background2.png', 0),
        (f'{theme_name}_background3.png', 0),
        (f'{theme_name}_midground1.png', 0),
        (f'{theme_name}_midground2.png', 0),
        (f'{theme_name}_midground3.png', 0),
        (f'{theme_name}_foreground1.png', 0),
        (f'{theme_name}_foreground2.png', 620),
        (f'{theme_name}_foreground3.png', 600),
    ]
    for fname, y_off in layers_order:
        path = os.path.join(layer_dir, fname)
        if os.path.exists(path):
            layer = Image.open(path).convert('RGBA')
            sky.paste(layer, (0, y_off), layer)
    
    out_path = os.path.join(os.path.dirname(layer_dir), f'{theme_name}_composite.png')
    sky.save(out_path)
    print(f"  ✓ Composite: {out_path}")
    return out_path


def make_layer_strip(layer_dir, theme_name, labels, sky_colors):
    """Create comparison strip showing all 9 layers."""
    from PIL import ImageDraw
    
    THUMB_W = 267
    THUMB_H = 207
    PADDING = 8
    COLS = 3
    ROWS = 3
    LABEL_H = 24
    
    strip_w = COLS * THUMB_W + (COLS + 1) * PADDING
    strip_h = ROWS * (THUMB_H + LABEL_H) + (ROWS + 1) * PADDING
    
    strip = Image.new('RGB', (strip_w, strip_h), (25, 25, 30))
    draw = ImageDraw.Draw(strip)
    
    layer_names = ['background1', 'background2', 'background3',
                   'midground1', 'midground2', 'midground3',
                   'foreground1', 'foreground2', 'foreground3']
    
    top, bot = sky_colors
    
    for idx, (lname, label) in enumerate(zip(layer_names, labels)):
        col = idx % COLS
        row = idx // COLS
        x = PADDING + col * (THUMB_W + PADDING)
        y = PADDING + row * (THUMB_H + LABEL_H + PADDING)
        
        bg = Image.new('RGBA', (THUMB_W, THUMB_H), (0, 0, 0, 255))
        for gy in range(THUMB_H):
            t = gy / THUMB_H
            r = int(top[0] + (bot[0] - top[0]) * t)
            g = int(top[1] + (bot[1] - top[1]) * t)
            b = int(top[2] + (bot[2] - top[2]) * t)
            for gx in range(THUMB_W):
                bg.putpixel((gx, gy), (r, g, b, 255))
        
        fname = f'{theme_name}_{lname}.png'
        path = os.path.join(layer_dir, fname)
        if os.path.exists(path):
            layer = Image.open(path).convert('RGBA')
            lw, lh = layer.size
            scale = min(THUMB_W / lw, THUMB_H / lh)
            new_w = int(lw * scale)
            new_h = int(lh * scale)
            layer_resized = layer.resize((new_w, new_h), Image.NEAREST)
            ox = (THUMB_W - new_w) // 2
            oy = THUMB_H - new_h
            bg.paste(layer_resized, (ox, oy), layer_resized)
        
        strip.paste(bg.convert('RGB'), (x, y))
        draw.text((x + 4, y + THUMB_H + 2), label, fill=(200, 200, 210))
    
    out_path = os.path.join(os.path.dirname(layer_dir), f'{theme_name}_layers_strip.png')
    strip.save(out_path)
    print(f"  ✓ Layer strip: {out_path}")
    return out_path
