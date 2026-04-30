import SpriteKit
import SwiftUI

// MARK: - ParallaxManager (9-Layer System)

/// Owns all parallax layers: sky gradient + 9 themed sprite layers.
///
/// Layer architecture (back → front):
///   bg1, bg2, bg3      — background (furthest, slowest)
///   mid1, mid2, mid3   — midground
///   fg1, fg2, fg3      — foreground (closest, fastest)
///
/// bg1–fg1 are full above-ground panels (200×155 pixel art → 800×620 game).
/// fg2 is the ground surface tile (200×20 → 800×80).
/// fg3 is the ground overlay (200×25 → 800×100).
///
/// Usage:
///   1. Create in `didMove(to:)`:
///      ```
///      parallax = ParallaxManager(backgroundLayer: backgroundLayer,
///                                 groundLayer: groundLayer,
///                                 foregroundLayer: foregroundLayer,
///                                 theme: backgroundTheme)
///      parallax.setup()
///      ```
///   2. Call `parallax.update(dt:)` every frame from the game's `update(_:)`.
final class ParallaxManager {

    // MARK: - Layer Definition

    /// Describes one parallax layer's rendering parameters.
    private struct LayerDef {
        let suffix: String      // asset catalog suffix, e.g. "background1"
        let speed: CGFloat      // scroll speed (pts/sec)
        let zPosition: CGFloat  // depth ordering
        let tileCount: Int      // number of tiles for seamless wrap
        let height: CGFloat     // display height in game points
        let yPosition: CGFloat  // bottom edge Y in game coordinates
        let isGround: Bool      // true = always scrolls (gameplay-relevant)
    }

    // MARK: - Properties

    private let backgroundLayer: SKNode
    private let groundLayer: SKNode
    private let foregroundLayer: SKNode
    private let theme: BackgroundTheme

    /// All 9 layer tile arrays, keyed by suffix for O(1) lookup.
    private var layerTiles: [String: [SKSpriteNode]] = [:]

    /// Layer definitions (computed once at setup).
    private var layerDefs: [LayerDef] = []

    /// Cached accessibility state (avoid per-frame system queries).
    private var reduceMotionEnabled: Bool = false

    // MARK: - Tile widths

    /// Above-ground layers tile at 2× world width for seamless wrap.
    private let aboveGroundTileWidth: CGFloat = GK.worldWidth * 2

    /// Ground layers tile at 2× world width for seamless wrap.
    private let groundTileWidth: CGFloat = GK.worldWidth * 2

    // MARK: - Init

    init(backgroundLayer: SKNode,
         groundLayer: SKNode,
         foregroundLayer: SKNode,
         theme: BackgroundTheme,
         factory: TextureFactory = .shared) {
        self.backgroundLayer = backgroundLayer
        self.groundLayer = groundLayer
        self.foregroundLayer = foregroundLayer
        self.theme = theme
    }

    // MARK: - Public API

    func setup() {
        reduceMotionEnabled = UIAccessibility.isReduceMotionEnabled

        // Sky gradient (procedural — always present)
        setupSkyGradient()

        // Define the 9 layers
        let groundH = GK.groundHeight  // 80

        layerDefs = [
            // Background layers — full above-ground panels
            LayerDef(suffix: "background1", speed: GK.bg1Speed, zPosition: -80,
                     tileCount: 2, height: 620, yPosition: groundH, isGround: false),
            LayerDef(suffix: "background2", speed: GK.bg2Speed, zPosition: -70,
                     tileCount: 2, height: 620, yPosition: groundH, isGround: false),
            LayerDef(suffix: "background3", speed: GK.bg3Speed, zPosition: -60,
                     tileCount: 2, height: 620, yPosition: groundH, isGround: false),

            // Midground layers — full above-ground panels
            LayerDef(suffix: "midground1", speed: GK.mid1Speed, zPosition: -50,
                     tileCount: 2, height: 620, yPosition: groundH, isGround: false),
            LayerDef(suffix: "midground2", speed: GK.mid2Speed, zPosition: -40,
                     tileCount: 2, height: 620, yPosition: groundH, isGround: false),
            LayerDef(suffix: "midground3", speed: GK.mid3Speed, zPosition: -30,
                     tileCount: 2, height: 620, yPosition: groundH, isGround: false),

            // Foreground 1 — full above-ground panel (closest scenery)
            LayerDef(suffix: "foreground1", speed: GK.fg1Speed, zPosition: -20,
                     tileCount: 3, height: 620, yPosition: groundH, isGround: false),

            // Foreground 2 — ground surface
            LayerDef(suffix: "foreground2", speed: GK.fg2Speed, zPosition: 50,
                     tileCount: 3, height: GK.groundHeight, yPosition: 0, isGround: true),

            // Foreground 3 — ground overlay / detail
            LayerDef(suffix: "foreground3", speed: GK.fg3Speed, zPosition: 55,
                     tileCount: 3, height: GK.groundHeight + 20, yPosition: 0, isGround: true),
        ]

        // Create sprite tiles for each layer
        for def in layerDefs {
            let assetName = "\(theme.rawValue)_\(def.suffix)"
            guard let image = UIImage(named: assetName) else {
                print("⚠️ ParallaxManager: missing asset \(assetName)")
                continue
            }
            let tex = SKTexture(image: image)
            tex.filteringMode = .nearest

            let tileWidth = def.isGround ? groundTileWidth : aboveGroundTileWidth
            var tiles: [SKSpriteNode] = []

            for i in 0..<def.tileCount {
                let sprite = SKSpriteNode(texture: tex,
                                           size: CGSize(width: tileWidth, height: def.height))
                sprite.anchorPoint = CGPoint(x: 0, y: 0)
                sprite.position = CGPoint(x: CGFloat(i) * tileWidth, y: def.yPosition)
                sprite.zPosition = def.zPosition

                // Ground surface is fully opaque — skip alpha blending for GPU savings
                if def.suffix == "foreground2" {
                    sprite.blendMode = .replace
                }

                // Choose appropriate parent layer
                let parentNode: SKNode
                if def.isGround {
                    parentNode = def.suffix == "foreground3" ? foregroundLayer : groundLayer
                } else {
                    parentNode = backgroundLayer
                }
                parentNode.addChild(sprite)
                tiles.append(sprite)
            }

            layerTiles[def.suffix] = tiles
        }
    }

    /// Drive all scrolling. Call every frame from `update(_:)` while the game is playing.
    ///
    /// When Reduce Motion is enabled (Settings → Accessibility → Motion), decorative
    /// parallax layers (bg1–fg1) stop scrolling. Ground layers (fg2, fg3) always scroll
    /// because they provide gameplay-relevant motion cues.
    func update(dt: TimeInterval) {
        let dtF = CGFloat(dt)

        for def in layerDefs {
            // Ground layers always scroll; decorative layers respect Reduce Motion
            guard def.isGround || !reduceMotionEnabled else { continue }
            guard let tiles = layerTiles[def.suffix] else { continue }

            let tileWidth = def.isGround ? groundTileWidth : aboveGroundTileWidth
            let totalWidth = tileWidth * CGFloat(tiles.count)

            for tile in tiles {
                tile.position.x -= def.speed * dtF
                if tile.position.x <= -tileWidth {
                    tile.position.x += totalWidth
                }
            }
        }
    }

    // MARK: - Sky Gradient (procedural)

    private func setupSkyGradient() {
        let skyNode = SKSpriteNode(color: .clear,
                                    size: CGSize(width: GK.worldWidth, height: GK.worldHeight))
        skyNode.position = CGPoint(x: GK.worldWidth / 2, y: GK.worldHeight / 2)
        skyNode.zPosition = -100
        skyNode.texture = createSkyGradientTexture()
        skyNode.blendMode = .replace
        backgroundLayer.addChild(skyNode)
    }

    private func createSkyGradientTexture() -> SKTexture {
        let size = CGSize(width: 1, height: Int(GK.worldHeight))
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let colors = theme.gradientColors.map { UIColor($0).cgColor } as CFArray
            let space = CGColorSpaceCreateDeviceRGB()
            guard let gradient = CGGradient(colorsSpace: space, colors: colors, locations: nil) else { return }
            ctx.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: size.height),
                end:   CGPoint(x: 0, y: 0),
                options: []
            )
        }
        let tex = SKTexture(image: image)
        tex.filteringMode = .linear
        return tex
    }
}
