/*
 * pixelart_engine - A real pixel art rendering tool
 * 
 * Features:
 *   - Floyd-Steinberg error-diffusion dithering
 *   - Ordered (Bayer matrix) dithering at multiple sizes
 *   - Palette-constrained color quantization
 *   - Pixel-perfect edge rendering with controlled aliasing
 *   - Gradient fills with dithering
 *   - Noise/texture generation
 *   - PNG input/output via stb
 *
 * Usage: pixelart_engine <command> [options] <input.png> <output.png>
 *
 * Commands:
 *   dither_fs     - Floyd-Steinberg dithering to N colors
 *   dither_ordered - Ordered (Bayer) dithering 
 *   dither_gradient - Generate dithered gradient between two colors
 *   quantize      - Reduce to palette with optional dithering
 *   texture       - Add pixel noise/texture overlay
 *   outline       - Add pixel-art style outlines
 *   shade         - Apply multi-step shading ramp
 *   composite     - Layer multiple PNGs with alpha
 *   generate      - Generate from a JSON scene description
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <stdint.h>

#define STB_IMAGE_IMPLEMENTATION
#include "stb/stb_image.h"
#define STB_IMAGE_WRITE_IMPLEMENTATION  
#include "stb/stb_image_write.h"

// Bayer dithering matrices
static const int BAYER2[2][2] = {{0,2},{3,1}};
static const int BAYER4[4][4] = {
    { 0, 8, 2,10},
    {12, 4,14, 6},
    { 3,11, 1, 9},
    {15, 7,13, 5}
};
static const int BAYER8[8][8] = {
    { 0,32, 8,40, 2,34,10,42},
    {48,16,56,24,50,18,58,26},
    {12,44, 4,36,14,46, 6,38},
    {60,28,52,20,62,30,54,22},
    { 3,35,11,43, 1,33, 9,41},
    {51,19,59,27,49,17,57,25},
    {15,47, 7,39,13,45, 5,37},
    {63,31,55,23,61,29,53,21}
};

typedef struct { uint8_t r, g, b, a; } Color;
typedef struct { uint8_t *data; int w, h, channels; } Image;

// Color distance (perceptual weighted)
static double color_dist(Color a, Color b) {
    double dr = (double)a.r - b.r;
    double dg = (double)a.g - b.g;
    double db = (double)a.b - b.b;
    // Weighted for human perception
    return 0.299*dr*dr + 0.587*dg*dg + 0.114*db*db;
}

static Color get_pixel(Image *img, int x, int y) {
    Color c = {0,0,0,255};
    if (x < 0 || x >= img->w || y < 0 || y >= img->h) return c;
    int idx = (y * img->w + x) * img->channels;
    c.r = img->data[idx];
    c.g = img->data[idx+1];
    c.b = img->data[idx+2];
    if (img->channels >= 4) c.a = img->data[idx+3];
    return c;
}

static void set_pixel(Image *img, int x, int y, Color c) {
    if (x < 0 || x >= img->w || y < 0 || y >= img->h) return;
    int idx = (y * img->w + x) * img->channels;
    img->data[idx] = c.r;
    img->data[idx+1] = c.g;
    img->data[idx+2] = c.b;
    if (img->channels >= 4) img->data[idx+3] = c.a;
}

static Image *create_image(int w, int h, int channels) {
    Image *img = malloc(sizeof(Image));
    img->w = w;
    img->h = h;
    img->channels = channels;
    img->data = calloc(w * h * channels, 1);
    return img;
}

static Image *load_image(const char *path) {
    Image *img = malloc(sizeof(Image));
    img->data = stbi_load(path, &img->w, &img->h, &img->channels, 4);
    if (!img->data) { free(img); return NULL; }
    img->channels = 4;
    return img;
}

static void save_image(Image *img, const char *path) {
    stbi_write_png(path, img->w, img->h, img->channels, img->data, img->w * img->channels);
}

static void free_image(Image *img) {
    if (img) { free(img->data); free(img); }
}

static Color lerp_color(Color a, Color b, double t) {
    Color c;
    c.r = (uint8_t)(a.r + t * (b.r - a.r));
    c.g = (uint8_t)(a.g + t * (b.g - a.g));
    c.b = (uint8_t)(a.b + t * (b.b - a.b));
    c.a = (uint8_t)(a.a + t * (b.a - a.a));
    return c;
}

static uint8_t clamp8(int v) { return v < 0 ? 0 : (v > 255 ? 255 : v); }

// Find nearest color in palette
static int find_nearest(Color c, Color *palette, int n) {
    int best = 0;
    double best_d = 1e30;
    for (int i = 0; i < n; i++) {
        double d = color_dist(c, palette[i]);
        if (d < best_d) { best_d = d; best = i; }
    }
    return best;
}

// ============ FLOYD-STEINBERG DITHERING ============
static void floyd_steinberg(Image *img, Color *palette, int ncolors) {
    // Work with float buffer for error diffusion
    double *buf = malloc(img->w * img->h * 3 * sizeof(double));
    for (int y = 0; y < img->h; y++)
        for (int x = 0; x < img->w; x++) {
            Color c = get_pixel(img, x, y);
            int idx = (y * img->w + x) * 3;
            buf[idx] = c.r; buf[idx+1] = c.g; buf[idx+2] = c.b;
        }
    
    for (int y = 0; y < img->h; y++) {
        for (int x = 0; x < img->w; x++) {
            // PRESERVE TRANSPARENCY — skip fully transparent pixels
            Color orig = get_pixel(img, x, y);
            if (orig.a < 10) continue;
            
            int idx = (y * img->w + x) * 3;
            Color old = { clamp8((int)buf[idx]), clamp8((int)buf[idx+1]), clamp8((int)buf[idx+2]), orig.a };
            int nearest = find_nearest(old, palette, ncolors);
            Color newc = palette[nearest];
            newc.a = orig.a;  // preserve original alpha
            set_pixel(img, x, y, newc);
            
            double er = buf[idx] - newc.r;
            double eg = buf[idx+1] - newc.g;
            double eb = buf[idx+2] - newc.b;
            
            // Floyd-Steinberg error diffusion to 4 neighbors
            {
                int dirs[4][2] = {{1,0},{-1,1},{0,1},{1,1}};
                double weights[4] = {7.0/16, 3.0/16, 5.0/16, 1.0/16};
                for (int d = 0; d < 4; d++) {
                    int nx = x + dirs[d][0], ny = y + dirs[d][1];
                    if (nx >= 0 && nx < img->w && ny < img->h) {
                        // Only diffuse error to non-transparent neighbors
                        Color nb = get_pixel(img, nx, ny);
                        if (nb.a >= 10) {
                            int ni = (ny * img->w + nx) * 3;
                            buf[ni]   += er * weights[d];
                            buf[ni+1] += eg * weights[d];
                            buf[ni+2] += eb * weights[d];
                        }
                    }
                }
            }
        }
    }
    free(buf);
}

// ============ ORDERED DITHERING ============
static void ordered_dither(Image *img, Color *palette, int ncolors, int matrix_size) {
    for (int y = 0; y < img->h; y++) {
        for (int x = 0; x < img->w; x++) {
            Color c = get_pixel(img, x, y);
            // PRESERVE TRANSPARENCY
            if (c.a < 10) continue;
            
            double threshold;
            if (matrix_size == 2)
                threshold = (BAYER2[y%2][x%2] / 4.0 - 0.5) * 64;
            else if (matrix_size == 4)
                threshold = (BAYER4[y%4][x%4] / 16.0 - 0.5) * 64;
            else
                threshold = (BAYER8[y%8][x%8] / 64.0 - 0.5) * 64;
            
            Color adj = { clamp8(c.r + (int)threshold), clamp8(c.g + (int)threshold), clamp8(c.b + (int)threshold), c.a };
            int nearest = find_nearest(adj, palette, ncolors);
            Color nc = palette[nearest];
            nc.a = c.a;  // preserve original alpha
            set_pixel(img, x, y, nc);
        }
    }
}

// ============ DITHERED GRADIENT ============
static void dither_gradient(Image *img, Color c1, Color c2, int direction, int dither_type, Color *palette, int ncolors) {
    // direction: 0=horizontal, 1=vertical, 2=radial
    for (int y = 0; y < img->h; y++) {
        for (int x = 0; x < img->w; x++) {
            double t;
            if (direction == 0) t = (double)x / (img->w - 1);
            else if (direction == 1) t = (double)y / (img->h - 1);
            else {
                double cx = img->w / 2.0, cy = img->h / 2.0;
                double maxr = sqrt(cx*cx + cy*cy);
                t = sqrt((x-cx)*(x-cx) + (y-cy)*(y-cy)) / maxr;
                if (t > 1) t = 1;
            }
            
            Color c = lerp_color(c1, c2, t);
            
            if (dither_type == 1) { // ordered
                double threshold = (BAYER4[y%4][x%4] / 16.0 - 0.5) * 48;
                c.r = clamp8(c.r + (int)threshold);
                c.g = clamp8(c.g + (int)threshold);
                c.b = clamp8(c.b + (int)threshold);
            }
            
            if (palette && ncolors > 0) {
                int nearest = find_nearest(c, palette, ncolors);
                c = palette[nearest];
            }
            c.a = 255;
            set_pixel(img, x, y, c);
        }
    }
}

// ============ TEXTURE NOISE ============
// Simple hash-based noise
static uint32_t pcg_hash(uint32_t input) {
    uint32_t state = input * 747796405u + 2891336453u;
    uint32_t word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
    return (word >> 22u) ^ word;
}

static void add_texture(Image *img, int amount, int seed) {
    for (int y = 0; y < img->h; y++) {
        for (int x = 0; x < img->w; x++) {
            Color c = get_pixel(img, x, y);
            if (c.a < 10) continue;  // preserve transparency
            int noise = (int)(pcg_hash(x + y * img->w + seed) % (amount * 2 + 1)) - amount;
            c.r = clamp8(c.r + noise);
            c.g = clamp8(c.g + noise);
            c.b = clamp8(c.b + noise);
            set_pixel(img, x, y, c);
        }
    }
}

// ============ OUTLINE ============
static void add_outline(Image *img, Color outline_color, int threshold) {
    Image *src = create_image(img->w, img->h, img->channels);
    memcpy(src->data, img->data, img->w * img->h * img->channels);
    
    for (int y = 1; y < img->h - 1; y++) {
        for (int x = 1; x < img->w - 1; x++) {
            Color c = get_pixel(src, x, y);
            if (c.a < 128) continue;
            
            // Check 4-connected neighbors for alpha edges
            int is_edge = 0;
            Color neighbors[4];
            neighbors[0] = get_pixel(src, x-1, y);
            neighbors[1] = get_pixel(src, x+1, y);
            neighbors[2] = get_pixel(src, x, y-1);
            neighbors[3] = get_pixel(src, x, y+1);
            
            for (int i = 0; i < 4; i++) {
                if (neighbors[i].a < 128) { is_edge = 1; break; }
                if (color_dist(c, neighbors[i]) > threshold * threshold) { is_edge = 1; break; }
            }
            
            if (is_edge) {
                set_pixel(img, x, y, outline_color);
            }
        }
    }
    free_image(src);
}

// ============ SHADING RAMP ============
static void apply_shade_ramp(Image *img, Color *ramp, int ramp_len, int light_x, int light_y) {
    double max_dist = sqrt(img->w * img->w + img->h * img->h);
    for (int y = 0; y < img->h; y++) {
        for (int x = 0; x < img->w; x++) {
            Color c = get_pixel(img, x, y);
            if (c.a < 10) continue;
            
            double dist = sqrt((x-light_x)*(x-light_x) + (y-light_y)*(y-light_y));
            double t = dist / max_dist;
            if (t > 1) t = 1;
            
            // Darken based on distance from light
            int ramp_idx = (int)(t * (ramp_len - 1));
            if (ramp_idx >= ramp_len) ramp_idx = ramp_len - 1;
            
            Color shade = ramp[ramp_idx];
            // Multiply blend
            c.r = (uint8_t)((c.r * shade.r) / 255);
            c.g = (uint8_t)((c.g * shade.g) / 255);
            c.b = (uint8_t)((c.b * shade.b) / 255);
            set_pixel(img, x, y, c);
        }
    }
}

// ============ COMPOSITE ============
static void composite_over(Image *dst, Image *src, int ox, int oy) {
    for (int y = 0; y < src->h; y++) {
        for (int x = 0; x < src->w; x++) {
            int dx = x + ox, dy = y + oy;
            if (dx < 0 || dx >= dst->w || dy < 0 || dy >= dst->h) continue;
            
            Color s = get_pixel(src, x, y);
            Color d = get_pixel(dst, dx, dy);
            
            if (s.a == 0) continue;
            if (s.a == 255) { set_pixel(dst, dx, dy, s); continue; }
            
            double sa = s.a / 255.0;
            Color result;
            result.r = (uint8_t)(s.r * sa + d.r * (1 - sa));
            result.g = (uint8_t)(s.g * sa + d.g * (1 - sa));
            result.b = (uint8_t)(s.b * sa + d.b * (1 - sa));
            result.a = 255;
            set_pixel(dst, dx, dy, result);
        }
    }
}

// ============ PARSE COLOR ============
static Color parse_color(const char *s) {
    Color c = {0,0,0,255};
    if (s[0] == '#') s++;
    unsigned int hex;
    sscanf(s, "%x", &hex);
    if (strlen(s) == 6) {
        c.r = (hex >> 16) & 0xFF;
        c.g = (hex >> 8) & 0xFF;
        c.b = hex & 0xFF;
    } else if (strlen(s) == 8) {
        c.r = (hex >> 24) & 0xFF;
        c.g = (hex >> 16) & 0xFF;
        c.b = (hex >> 8) & 0xFF;
        c.a = hex & 0xFF;
    }
    return c;
}

// ============ MAIN ============
int main(int argc, char **argv) {
    if (argc < 2) {
        printf("pixelart_engine - Pixel art rendering tool\n\n");
        printf("Commands:\n");
        printf("  dither_fs <input> <output> <color1> [color2] ...     Floyd-Steinberg dither to palette\n");
        printf("  dither_ordered <input> <output> <size> <color1> ...  Ordered dither (size: 2,4,8)\n");
        printf("  gradient <output> <w> <h> <c1> <c2> <dir> <dither>  Dithered gradient (dir:0=h,1=v,2=r)\n");
        printf("  texture <input> <output> <amount> [seed]            Add pixel texture noise\n");
        printf("  outline <input> <output> <color> [threshold]        Add pixel outlines\n");
        printf("  shade <input> <output> <light_x> <light_y> <c1>... Apply shading ramp\n");
        printf("  composite <base> <overlay> <output> [ox] [oy]      Alpha composite\n");
        printf("  quantize <input> <output> <n_colors> [dither_type]  Reduce colors (0=none,1=fs,2=ordered)\n");
        printf("  fill_rect <output> <w> <h> <color>                 Create solid rectangle\n");
        printf("  dither_band <output> <w> <h> <c1> <c2> <rows> <type> Horizontal dithered band\n");
        return 0;
    }
    
    const char *cmd = argv[1];
    
    if (strcmp(cmd, "dither_fs") == 0 && argc >= 5) {
        Image *img = load_image(argv[2]);
        if (!img) { printf("Failed to load %s\n", argv[2]); return 1; }
        int ncolors = argc - 4;
        Color *palette = malloc(ncolors * sizeof(Color));
        for (int i = 0; i < ncolors; i++) palette[i] = parse_color(argv[4+i]);
        floyd_steinberg(img, palette, ncolors);
        save_image(img, argv[3]);
        printf("Floyd-Steinberg dithered to %d colors -> %s\n", ncolors, argv[3]);
        free(palette); free_image(img);
    }
    else if (strcmp(cmd, "dither_ordered") == 0 && argc >= 6) {
        Image *img = load_image(argv[2]);
        if (!img) { printf("Failed to load %s\n", argv[2]); return 1; }
        int matrix_size = atoi(argv[4]);
        int ncolors = argc - 5;
        Color *palette = malloc(ncolors * sizeof(Color));
        for (int i = 0; i < ncolors; i++) palette[i] = parse_color(argv[5+i]);
        ordered_dither(img, palette, ncolors, matrix_size);
        save_image(img, argv[3]);
        printf("Ordered dithered (matrix %d) to %d colors -> %s\n", matrix_size, ncolors, argv[3]);
        free(palette); free_image(img);
    }
    else if (strcmp(cmd, "gradient") == 0 && argc >= 9) {
        int w = atoi(argv[3]), h = atoi(argv[4]);
        Color c1 = parse_color(argv[5]), c2 = parse_color(argv[6]);
        int dir = atoi(argv[7]), dither = atoi(argv[8]);
        Image *img = create_image(w, h, 4);
        // Optional palette from remaining args
        int ncolors = argc - 9;
        Color *palette = NULL;
        if (ncolors > 0) {
            palette = malloc(ncolors * sizeof(Color));
            for (int i = 0; i < ncolors; i++) palette[i] = parse_color(argv[9+i]);
        }
        dither_gradient(img, c1, c2, dir, dither, palette, ncolors);
        save_image(img, argv[2]);
        printf("Gradient %dx%d -> %s\n", w, h, argv[2]);
        free_image(img); if (palette) free(palette);
    }
    else if (strcmp(cmd, "texture") == 0 && argc >= 5) {
        Image *img = load_image(argv[2]);
        if (!img) { printf("Failed to load %s\n", argv[2]); return 1; }
        int amount = atoi(argv[4]);
        int seed = argc > 5 ? atoi(argv[5]) : 42;
        add_texture(img, amount, seed);
        save_image(img, argv[3]);
        printf("Added texture (amount=%d) -> %s\n", amount, argv[3]);
        free_image(img);
    }
    else if (strcmp(cmd, "outline") == 0 && argc >= 5) {
        Image *img = load_image(argv[2]);
        if (!img) { printf("Failed to load %s\n", argv[2]); return 1; }
        Color outline = parse_color(argv[4]);
        int threshold = argc > 5 ? atoi(argv[5]) : 30;
        add_outline(img, outline, threshold);
        save_image(img, argv[3]);
        printf("Added outlines -> %s\n", argv[3]);
        free_image(img);
    }
    else if (strcmp(cmd, "shade") == 0 && argc >= 7) {
        Image *img = load_image(argv[2]);
        if (!img) { printf("Failed to load %s\n", argv[2]); return 1; }
        int lx = atoi(argv[4]), ly = atoi(argv[5]);
        int nramp = argc - 6;
        Color *ramp = malloc(nramp * sizeof(Color));
        for (int i = 0; i < nramp; i++) ramp[i] = parse_color(argv[6+i]);
        apply_shade_ramp(img, ramp, nramp, lx, ly);
        save_image(img, argv[3]);
        printf("Shaded with %d-step ramp -> %s\n", nramp, argv[3]);
        free(ramp); free_image(img);
    }
    else if (strcmp(cmd, "composite") == 0 && argc >= 5) {
        Image *base = load_image(argv[2]);
        Image *overlay = load_image(argv[3]);
        if (!base || !overlay) { printf("Failed to load images\n"); return 1; }
        int ox = argc > 5 ? atoi(argv[5]) : 0;
        int oy = argc > 6 ? atoi(argv[6]) : 0;
        composite_over(base, overlay, ox, oy);
        save_image(base, argv[4]);
        printf("Composited -> %s\n", argv[4]);
        free_image(base); free_image(overlay);
    }
    else if (strcmp(cmd, "fill_rect") == 0 && argc >= 6) {
        int w = atoi(argv[3]), h = atoi(argv[4]);
        Color c = parse_color(argv[5]);
        Image *img = create_image(w, h, 4);
        for (int y = 0; y < h; y++)
            for (int x = 0; x < w; x++)
                set_pixel(img, x, y, c);
        save_image(img, argv[2]);
        printf("Filled %dx%d -> %s\n", w, h, argv[2]);
        free_image(img);
    }
    else if (strcmp(cmd, "dither_band") == 0 && argc >= 9) {
        int w = atoi(argv[3]), h = atoi(argv[4]);
        Color c1 = parse_color(argv[5]), c2 = parse_color(argv[6]);
        int rows = atoi(argv[7]);
        int type = atoi(argv[8]); // 0=ordered, 1=fs
        Image *img = create_image(w, h, 4);
        
        // Create horizontal bands with dithered transitions
        for (int y = 0; y < h; y++) {
            double t = (double)y / (h > 1 ? h - 1 : 1);
            for (int x = 0; x < w; x++) {
                Color c = lerp_color(c1, c2, t);
                if (type == 0) {
                    // Ordered dither
                    double thresh = (BAYER4[y%4][x%4] / 16.0 - 0.5) * 32;
                    c.r = clamp8(c.r + (int)thresh);
                    c.g = clamp8(c.g + (int)thresh);
                    c.b = clamp8(c.b + (int)thresh);
                }
                // Snap to nearest of c1 or c2
                Color pal[2] = {c1, c2};
                int nearest = find_nearest(c, pal, 2);
                c = pal[nearest];
                c.a = 255;
                set_pixel(img, x, y, c);
            }
        }
        save_image(img, argv[2]);
        printf("Dithered band %dx%d -> %s\n", w, h, argv[2]);
        free_image(img);
    }
    else if (strcmp(cmd, "quantize") == 0 && argc >= 5) {
        Image *img = load_image(argv[2]);
        if (!img) { printf("Failed to load %s\n", argv[2]); return 1; }
        int ncolors = atoi(argv[4]);
        int dither_type = argc > 5 ? atoi(argv[5]) : 0;
        
        // Simple median-cut quantization
        // Collect all unique colors, then k-means cluster
        // For simplicity, use uniform quantization
        Color *palette = malloc(ncolors * sizeof(Color));
        int steps = (int)cbrt(ncolors);
        if (steps < 2) steps = 2;
        int idx = 0;
        for (int r = 0; r < steps && idx < ncolors; r++)
            for (int g = 0; g < steps && idx < ncolors; g++)
                for (int b = 0; b < steps && idx < ncolors; b++) {
                    palette[idx].r = r * 255 / (steps-1);
                    palette[idx].g = g * 255 / (steps-1);
                    palette[idx].b = b * 255 / (steps-1);
                    palette[idx].a = 255;
                    idx++;
                }
        
        if (dither_type == 1) floyd_steinberg(img, palette, ncolors);
        else if (dither_type == 2) ordered_dither(img, palette, ncolors, 4);
        else {
            for (int y = 0; y < img->h; y++)
                for (int x = 0; x < img->w; x++) {
                    Color c = get_pixel(img, x, y);
                    int n = find_nearest(c, palette, ncolors);
                    set_pixel(img, x, y, palette[n]);
                }
        }
        save_image(img, argv[3]);
        printf("Quantized to %d colors -> %s\n", ncolors, argv[3]);
        free(palette); free_image(img);
    }
    else {
        printf("Unknown command or wrong arguments: %s\n", cmd);
        return 1;
    }
    
    return 0;
}
