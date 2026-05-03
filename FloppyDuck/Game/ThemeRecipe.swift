import SpriteKit

// MARK: - Theme Recipe Types

/// Declarative recipe for a theme's visual layer stack.
/// The recipe is the single source of truth — runtime behavior derives from it,
/// not from filenames, switch statements, or hardcoded constants.
struct ThemeRecipe {
    let hero: LayerRecipe
    let clouds: LayerRecipe?
    let midground: LayerRecipe?
    let horizon: LayerRecipe?
    let ground: LayerRecipe?
    let overlays: [OverlayRecipe]
    let contrastBudget: ContrastBudget
}

/// Describes one parallax layer's rendering parameters.
struct LayerRecipe {
    /// Asset catalog name — validated against the catalog at load time.
    let assetName: String
    /// Scroll speed as a fraction of ground speed: 0.0 = static, 1.0 = full speed.
    let scrollSpeed: CGFloat
    /// Display height in game points.
    let heightPoints: CGFloat
    /// Vertical anchor strategy.
    let yAnchor: LayerYAnchor
    /// Whether this layer tiles horizontally for seamless wrap.
    let tiles: Bool
}

/// Vertical anchor strategy for a layer.
enum LayerYAnchor {
    /// Anchored to the top of the play area (sky layers).
    case top
    /// Anchored at the horizon line with an optional offset.
    case horizon(offset: CGFloat)
    /// Anchored at y = 0 (ground layers).
    case ground
}

/// Describes a sprite-sheet overlay (clouds, birds, etc.).
struct OverlayRecipe {
    /// Asset name for the sprite sheet (multiple variants in one sheet).
    let spriteSheet: String
    /// How densely the overlay spawns.
    let density: OverlayDensity
    /// Scroll speed as a fraction of ground speed.
    let scrollSpeed: CGFloat
    /// Whether this overlay freezes when Reduce Motion is enabled.
    let respectsReduceMotion: Bool
}

/// Overlay spawn density.
enum OverlayDensity: Int {
    case none       = 0
    case occasional = 1
    case sparse     = 2
    case moderate   = 3
}

/// Readability / contrast constraints for a theme.
struct ContrastBudget {
    /// Maximum luminance variance allowed in the hero layer (e.g. 0.15).
    let maxLuminanceVariance: CGFloat
    /// Maximum fraction of overlay pixels that may be opaque (e.g. 0.30).
    let maxOpaquePixelDensity: CGFloat
    /// Fraction of screen height reserved as a clear flight corridor (e.g. 0.50).
    let corridorHeightFraction: CGFloat
}

// MARK: - Recipe → Sprite Layer Conversion

extension ThemeRecipe {

    /// Compile the recipe into an array of `SpriteLayerDef` that `ParallaxManager`
    /// can iterate without any theme-specific conditionals.
    func spriteLayers() -> [SpriteLayerDef] {
        var defs: [SpriteLayerDef] = []

        // Hero — sky / atmosphere, sits above ground, furthest back
        let heroY = yPosition(for: hero.yAnchor)
        defs.append(SpriteLayerDef(
            assetName: hero.assetName,
            speed: hero.scrollSpeed * GK.groundSpeed,
            zPosition: -85,
            tileCount: hero.tiles ? 2 : 1,
            height: hero.heightPoints,
            yPosition: heroY,
            isGround: false
        ))

        // Clouds — optional cloud layer, scrolls independently
        if let cl = clouds {
            let clY = yPosition(for: cl.yAnchor)
            defs.append(SpriteLayerDef(
                assetName: cl.assetName,
                speed: cl.scrollSpeed * GK.groundSpeed,
                zPosition: -70,
                tileCount: cl.tiles ? 2 : 1,
                height: cl.heightPoints,
                yPosition: clY,
                isGround: false
            ))
        }

        // Horizon — optional distant silhouette strip
        if let hz = horizon {
            let hzY = yPosition(for: hz.yAnchor)
            defs.append(SpriteLayerDef(
                assetName: hz.assetName,
                speed: hz.scrollSpeed * GK.groundSpeed,
                zPosition: -50,
                tileCount: hz.tiles ? 2 : 1,
                height: hz.heightPoints,
                yPosition: hzY,
                isGround: false
            ))
        }

        // Midground — optional trees/foliage layer
        if let mg = midground {
            let mgY = yPosition(for: mg.yAnchor)
            defs.append(SpriteLayerDef(
                assetName: mg.assetName,
                speed: mg.scrollSpeed * GK.groundSpeed,
                zPosition: -40,
                tileCount: mg.tiles ? 2 : 1,
                height: mg.heightPoints,
                yPosition: mgY,
                isGround: false
            ))
        }

        // Ground — gameplay ground tile (optional: some themes omit it)
        if let gnd = ground {
            defs.append(SpriteLayerDef(
                assetName: gnd.assetName,
                speed: gnd.scrollSpeed * GK.groundSpeed,
                zPosition: 50,
                tileCount: gnd.tiles ? 3 : 1,
                height: gnd.heightPoints,
                yPosition: 0,
                isGround: true
            ))
        }

        return defs
    }

    /// Convert a `LayerYAnchor` to a concrete Y coordinate.
    private func yPosition(for anchor: LayerYAnchor) -> CGFloat {
        switch anchor {
        case .top:
            return GK.groundHeight
        case .horizon(let offset):
            return GK.groundHeight + offset
        case .ground:
            return 0
        }
    }
}

/// Flattened layer definition consumed by `ParallaxManager` at runtime.
/// No theme-specific information — purely rendering data.
struct SpriteLayerDef {
    let assetName: String       // full asset catalog name (e.g. "day_hero")
    let speed: CGFloat          // scroll speed in pts/sec
    let zPosition: CGFloat      // depth ordering
    let tileCount: Int          // number of tiles for seamless wrap
    let height: CGFloat         // display height in game points
    let yPosition: CGFloat      // bottom edge Y in game coordinates
    let isGround: Bool          // true → always scrolls, false → respects Reduce Motion
}
