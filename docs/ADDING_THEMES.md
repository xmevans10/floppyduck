# Adding a New Theme to Floppy Duck

This guide walks through every file you need to touch when adding a new background theme. Follow the steps in order — each one is required.

---

## Overview

A theme in Floppy Duck is a complete visual package: sky gradient, ground tiles, parallax layers, preview artwork, and optional music. The architecture is designed so themes are self-contained — once you add the enum case and fill in every switch, the theme appears automatically in the Shop, Collection view, and gameplay.

### Files You'll Touch

| File | What to add |
|------|-------------|
| `BackgroundTheme.swift` | Enum case + ~11 computed properties |
| `TextureFactory.swift` | 5 renderer functions + 5 dispatcher entries |
| `ThemePreviewView.swift` | 1 custom Canvas drawing function + dispatcher entry |
| `FloppyDuck.xcodeproj` | Only if you add new Swift files (rare) |

**You do NOT need to touch:**
- `ParallaxManager.swift` — calls themed API, no switch statements
- `SoundManager.swift` — has a `default` case, new themes fall through to generic music
- `ShopView.swift` / `CollectionView.swift` — use `BackgroundTheme.allCases`, auto-discover

---

## Step 1: Add the Enum Case

**File:** `FloppyDuck/Models/BackgroundTheme.swift`

Add your case to the `BackgroundTheme` enum:

```swift
enum BackgroundTheme: String, CaseIterable, Identifiable, Codable {
    // ... existing cases ...
    case myTheme    // <-- add here
```

Then fill in ALL computed properties. The compiler will error on any missing switch case, so you can't forget one. Here's the full list:

| Property | Type | Purpose |
|----------|------|---------|
| `displayName` | `String` | ALL-CAPS name shown in UI ("MY THEME") |
| `subtitle` | `String` | Tagline ("Vibe Check") |
| `purchaseKind` | `.free` / `.normal` / `.premium` | How player unlocks it |
| `breadPrice` | `Int?` | Cost in bread (only for `.normal` kind) |
| `gradientColors` | `[Color]` | Sky gradient, top-to-bottom (3–4 colors) |
| `backgroundColor` | `UIColor` | SpriteKit scene background fallback |
| `cloudTint` | `UIColor` | Cloud sprite tint + opacity |
| `previewGroundColor` | `Color` | Ground color in ThemePreviewView |
| `previewHillColor` | `Color` | Hill color in ThemePreviewView |
| `accentColor` | `Color` | UI accent (shop cards, selection ring) |
| `gameplayMusicFile` | `String?` | Bundle filename (no ext), or `nil` for default |

**Tips:**
- Use 3–4 gradient colors for a smooth sky
- `cloudTint` alpha controls cloud visibility — use lower alpha (~0.3) for dark/indoor themes
- For indoor themes (cave, etc.), `showStars` should return `false`

---

## Step 2: Add TextureFactory Renderers

**File:** `FloppyDuck/Utilities/TextureFactory.swift`

You need **5 renderer functions** and **5 dispatcher entries**. Each renderer draws pixel-art textures using `UIGraphicsImageRenderer`.

### 2a. Dispatcher Entries

Find each of these 5 switch statements and add your case:

```swift
// 1. Hills (background parallax layer)
private func renderThemedHills(theme:)
    case .myTheme: return renderMyThemeHills()

// 2. Trees (midground parallax layer)
private func renderThemedTrees(theme:)
    case .myTheme: return renderMyThemeMidground()

// 3. Bushes (foreground parallax layer)
private func renderThemedBushes(theme:)
    case .myTheme: return renderMyThemeStrip()

// 4. Ground tile
private func renderThemedGround(theme:)
    case .myTheme: return renderMyThemeGround()

// 5. Ground detail (surface decorations)
private func renderThemedGroundDetail(theme:, tileWidth:, groundHeight:, seed:)
    case .myTheme: return renderMyThemeGroundDetail(tileWidth:, groundHeight:, seed:)
```

### 2b. Renderer Functions

Each renderer follows a consistent pattern. Here's a template:

#### Hills Renderer (background mountains/skyline)

```swift
private func renderMyThemeHills() -> UIImage {
    let w: CGFloat = GK.worldWidth * 2    // standard width
    let h: CGFloat = 120                   // standard hills height
    let ps: CGFloat = 4                    // pixel size (keep at 4)
    let gridW = Int(w / ps)

    // Build a heightmap
    var heightMap = [Int](repeating: 1, count: gridW)
    // Add bumps, buildings, whatever fits your theme...

    let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
    return renderer.image { ctx in
        let c = ctx.cgContext
        for x in 0..<gridW {
            let colH = heightMap[x]
            for y in 0..<colH {
                let yPos = h - CGFloat(y + 1) * ps
                // Pick color based on y position...
                c.setFillColor(someColor.cgColor)
                c.fill(CGRect(x: CGFloat(x) * ps, y: yPos, width: ps, height: ps))
            }
        }
    }
}
```

#### Trees/Midground Renderer (pixel-art sprites)

```swift
private func renderMyThemeMidground() -> UIImage {
    let w: CGFloat = GK.worldWidth * 2
    let h: CGFloat = 160                   // standard midground height
    let ps: CGFloat = 4
    let C = UIColor.clear

    // Define pixel-art templates as 2D arrays:
    let mySprite: [[UIColor]] = [
        [C, color1, color1, C],
        [color1, color2, color2, color1],
        // ...
    ]

    // Place sprites at positions across the strip
    let positions: [(x: CGFloat, type: Int)] = [
        (30, 0), (150, 1), (280, 0), ...
    ]

    let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
    return renderer.image { ctx in
        let c = ctx.cgContext
        for pos in positions {
            // Draw the sprite template at pos.x, bottom-aligned
        }
    }
}
```

#### Bushes/Foreground Strip

```swift
private func renderMyThemeStrip() -> UIImage {
    let w = Int(GK.worldWidth * 2)
    let h = 40                             // standard bush height
    let ps = 4
    // Draw small repeating foreground elements
}
```

#### Ground Tile

```swift
private func renderMyThemeGround() -> UIImage {
    let w: CGFloat = GK.worldWidth * 2
    let h: CGFloat = GK.groundHeight       // use standard ground height
    let ps: CGFloat = 4
    // Draw the ground surface (dirt, sand, stone, etc.)
    // Include a top border line and some texture variation
}
```

#### Ground Detail (random decorations)

```swift
private func renderMyThemeGroundDetail(tileWidth: CGFloat, groundHeight: CGFloat, seed: Int) -> UIImage {
    srand48(seed)                          // IMPORTANT: use seed for determinism
    let h: CGFloat = groundHeight + 20
    let size = CGSize(width: tileWidth, height: h)
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { ctx in
        let c = ctx.cgContext
        let baseY = h - groundHeight       // where ground surface starts
        // Use drand48() for random positions (seeded!)
        // Draw small details: pebbles, grass, flowers, etc.
    }
}
```

### Standard Dimensions

| Layer | Width | Height | Pixel Size |
|-------|-------|--------|------------|
| Hills | `GK.worldWidth * 2` | `120` | `4` |
| Trees/Midground | `GK.worldWidth * 2` | `160` | `4` |
| Bushes/Foreground | `GK.worldWidth * 2` | `40` | `4` |
| Ground | `GK.worldWidth * 2` | `GK.groundHeight` | `4` |
| Ground Detail | `tileWidth` (param) | `groundHeight + 20` | varies |

---

## Step 3: Add Preview Card Scene

**File:** `FloppyDuck/Views/ThemePreviewView.swift`

This is the mini-scene thumbnail shown in Collection and Shop selection cards (70pt tall). Each theme has a completely unique, bespoke Canvas drawing — **no generic templates**.

### 3a. Add Dispatcher Entry

```swift
private func drawScene(ctx: inout GraphicsContext, w: CGFloat, h: CGFloat) {
    switch theme {
    // ... existing ...
    case .myTheme: drawMyTheme(ctx: &ctx, w: w, h: h)
    }
}
```

### 3b. Add Drawing Function

```swift
private func drawMyTheme(ctx: inout GraphicsContext, w: CGFloat, h: CGFloat) {
    // Sky gradient (use the helper)
    skyGradient(&ctx, w: w, h: h)

    // Draw signature elements of your theme
    // Use the pixel helpers: fill(), pixel(), drawSineHills(), etc.
    // Think: what makes this theme instantly recognizable at 70pt?

    // Ground strip at bottom
    fill(&ctx, x: 0, y: h * 0.78, w: w, h: h * 0.22, theme.previewGroundColor)
}
```

**Available helpers:**
- `fill(&ctx, x:, y:, w:, h:, color)` — fill a rectangle
- `pixel(&ctx, x:, y:, color)` — draw one `px × px` pixel
- `skyGradient(&ctx, w:, h:)` — draw the theme's gradient background
- `drawSineHills(&ctx, w:, baseY:, amplitude:, freq:, phase:, color:)` — wavy hills
- `drawPixelTreeSilhouette(&ctx, x:, baseY:, color:)` — generic tree shape
- `drawPixelPine(&ctx, x:, baseY:, height:, dark:, light:)` — pine tree
- `prng(seed, index)` — deterministic random 0..1 (for star/particle positions)

**Design principles for preview cards:**
- Make it *instantly* recognizable — use the theme's most iconic elements
- Cave/indoor themes: skip `skyGradient()`, draw your own dark background
- Include 2–3 signature elements (e.g., Western = mesa + cactus + saloon)
- Use `theme.previewGroundColor` for the ground strip
- Keep it simple but distinctive at small sizes

---

## Step 4: Music (Optional)

If you want custom music:

1. Add an `.m4a` file to the Xcode project bundle
2. Set `gameplayMusicFile` to return the filename (no extension)
3. For synthesized music, add a case in `SoundManager.synthesizeThemeMusic(for:)`

If you return `nil` from `gameplayMusicFile`, the default action music plays.

---

## Step 5: Test Checklist

- [ ] App compiles with no warnings on the new switch cases
- [ ] Theme appears in Shop with correct name, price, and preview
- [ ] Theme appears in Collection view with correct preview
- [ ] Gameplay shows correct sky gradient, hills, trees, bushes, ground
- [ ] Ground detail tiles render without visual glitches
- [ ] Preview card is visually distinct and recognizable
- [ ] Music plays (or falls through to default gracefully)
- [ ] Cloud sprites look correct with your `cloudTint`

---

## Architecture Diagram

```
BackgroundTheme.swift          ← enum + visual palette
        │
        ├─► TextureFactory.swift    ← 5 parallax layer renderers
        │       ├── renderThemedHills()
        │       ├── renderThemedTrees()
        │       ├── renderThemedBushes()
        │       ├── renderThemedGround()
        │       └── renderThemedGroundDetail()
        │
        ├─► ThemePreviewView.swift  ← Canvas mini-scene for UI cards
        │
        ├─► ParallaxManager.swift   ← consumes textures (no theme logic)
        │
        ├─► SoundManager.swift      ← optional per-theme music
        │
        └─► ShopView / CollectionView ← auto-discover via allCases
```

---

## Example: Adding a "Swamp" Theme

1. **BackgroundTheme.swift:** Add `case swamp` with murky green gradients, muddy ground colors
2. **TextureFactory.swift:**
   - `renderSwampHills()` — dead tree silhouettes, fog
   - `renderSwampMidground()` — cypress trees with hanging moss
   - `renderSwampStrip()` — lily pads, frogs
   - `renderSwampGround()` — dark mud with algae
   - `renderSwampGroundDetail()` — bubbles, mosquitoes, reeds
3. **ThemePreviewView.swift:** `drawSwamp()` — murky water, cypress silhouette, fireflies
4. **Music:** `nil` initially → add `theme_swamp.m4a` later

Total: ~300–500 lines of new code across 3 files.
