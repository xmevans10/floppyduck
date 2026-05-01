import SpriteKit
import SwiftUI

// MARK: - ParallaxManager

/// Owns parallax layers: sky gradient + themed sprite layers.
///
/// Layer architecture (back → front):
///   bg1, bg2, bg3      — background (furthest, slowest)
///   mid1, mid2, mid3   — midground
///   fg1, fg2, fg3      — foreground (closest, fastest)
///
/// Newer themes may use a compact 3-layer architecture:
///   background, midground, foreground
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

    private var overlayParticles: [OverlayParticle] = []

    // MARK: - Tile widths

    /// Above-ground layers tile at 2× world width for seamless wrap.
    private let aboveGroundTileWidth: CGFloat = GK.worldWidth * 2

    /// Ground layers tile at 2× world width for seamless wrap.
    private let groundTileWidth: CGFloat = GK.worldWidth * 2

    private struct OverlayParticle {
        let node: SKSpriteNode
        let effect: ThemeOverlayEffect
        let speed: CGVector
        let spin: CGFloat
    }

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

        let groundH = GK.groundHeight  // 80
        let hasHero = UIImage(named: "\(theme.rawValue)_hero") != nil

        if !hasHero {
            // Sky gradient sits behind legacy transparent parallax layers.
            setupSkyGradient()
        }

        layerDefs = makeLayerDefs(groundH: groundH, hasHero: hasHero)

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

        setupRuntimeOverlays()
    }

    private func makeLayerDefs(groundH: CGFloat, hasHero: Bool) -> [LayerDef] {
        if hasHero {
            return [
                LayerDef(suffix: "hero", speed: GK.bg1Speed, zPosition: -85,
                         tileCount: 2, height: 620, yPosition: groundH, isGround: false),
            ]
        }

        if theme == .roughOcean {
            return [
                LayerDef(suffix: "background", speed: GK.bg1Speed, zPosition: -80,
                         tileCount: 2, height: 620, yPosition: groundH, isGround: false),
                LayerDef(suffix: "midground", speed: GK.bg3Speed, zPosition: -55,
                         tileCount: 2, height: 620, yPosition: groundH, isGround: false),
                LayerDef(suffix: "foreground", speed: GK.fg1Speed, zPosition: -20,
                         tileCount: 3, height: 620, yPosition: groundH, isGround: false),
            ]
        }

        return [
            LayerDef(suffix: "background1", speed: GK.bg1Speed, zPosition: -80,
                     tileCount: 2, height: 620, yPosition: groundH, isGround: false),
            LayerDef(suffix: "background2", speed: GK.bg2Speed, zPosition: -70,
                     tileCount: 2, height: 620, yPosition: groundH, isGround: false),
            LayerDef(suffix: "background3", speed: GK.bg3Speed, zPosition: -60,
                     tileCount: 2, height: 620, yPosition: groundH, isGround: false),
            LayerDef(suffix: "midground1", speed: GK.mid1Speed, zPosition: -50,
                     tileCount: 2, height: 620, yPosition: groundH, isGround: false),
            LayerDef(suffix: "midground2", speed: GK.mid2Speed, zPosition: -40,
                     tileCount: 2, height: 620, yPosition: groundH, isGround: false),
            LayerDef(suffix: "midground3", speed: GK.mid3Speed, zPosition: -30,
                     tileCount: 2, height: 620, yPosition: groundH, isGround: false),
            LayerDef(suffix: "foreground1", speed: GK.fg1Speed, zPosition: -20,
                     tileCount: 3, height: 620, yPosition: groundH, isGround: false),
            LayerDef(suffix: "foreground2", speed: GK.fg2Speed, zPosition: 50,
                     tileCount: 3, height: GK.groundHeight, yPosition: 0, isGround: true),
            LayerDef(suffix: "foreground3", speed: GK.fg3Speed, zPosition: 55,
                     tileCount: 3, height: GK.groundHeight + 20, yPosition: 0, isGround: true),
        ]
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

        updateRuntimeOverlays(dt: dtF)
    }

    // MARK: - Runtime Overlays

    private func setupRuntimeOverlays() {
        guard !theme.overlayEffects.isEmpty else { return }

        for effect in theme.overlayEffects {
            if effect == .mist {
                setupMistBands()
                continue
            }

            for i in 0..<particleCount(for: effect) {
                let node = makeParticleNode(effect: effect, index: i)
                node.position = initialParticlePosition(effect: effect, index: i)
                node.zPosition = zPosition(for: effect)
                backgroundLayer.addChild(node)

                overlayParticles.append(OverlayParticle(
                    node: node,
                    effect: effect,
                    speed: velocity(for: effect, index: i),
                    spin: spin(for: effect, index: i)
                ))
            }
        }
    }

    private func updateRuntimeOverlays(dt: CGFloat) {
        guard !overlayParticles.isEmpty, !reduceMotionEnabled else { return }

        for particle in overlayParticles {
            particle.node.position.x += particle.speed.dx * dt
            particle.node.position.y += particle.speed.dy * dt
            particle.node.zRotation += particle.spin * dt

            if shouldRecycle(particle.node, effect: particle.effect) {
                recycle(particle.node, effect: particle.effect)
            }
        }
    }

    private func particleCount(for effect: ThemeOverlayEffect) -> Int {
        switch effect {
        case .rain: return 44
        case .snow: return 34
        case .embers: return 26
        case .bubbles: return 24
        case .dust: return 18
        case .petals: return 16
        case .seaSpray: return 22
        case .stars: return 28
        case .mist: return 0
        }
    }

    private func makeParticleNode(effect: ThemeOverlayEffect, index: Int) -> SKSpriteNode {
        let size: CGSize
        let color: UIColor

        switch effect {
        case .rain:
            size = CGSize(width: 1, height: 18)
            color = UIColor(red: 0.65, green: 0.80, blue: 0.88, alpha: 0.35)
        case .snow:
            size = CGSize(width: 3, height: 3)
            color = UIColor(white: 1.0, alpha: 0.75)
        case .embers:
            size = CGSize(width: 3, height: 3)
            color = UIColor(red: 1.0, green: 0.45, blue: 0.12, alpha: 0.75)
        case .bubbles:
            size = CGSize(width: 4, height: 4)
            color = UIColor(red: 0.75, green: 0.95, blue: 1.0, alpha: 0.45)
        case .dust:
            size = CGSize(width: 2, height: 2)
            color = UIColor(red: 0.95, green: 0.78, blue: 0.45, alpha: 0.35)
        case .petals:
            size = CGSize(width: 5, height: 3)
            color = index % 3 == 0
                ? UIColor(red: 1.0, green: 0.55, blue: 0.72, alpha: 0.85)
                : UIColor(red: 1.0, green: 0.70, blue: 0.82, alpha: 0.75)
        case .seaSpray:
            size = CGSize(width: 2, height: 2)
            color = UIColor(red: 0.75, green: 0.92, blue: 0.95, alpha: 0.45)
        case .stars:
            size = CGSize(width: 2, height: 2)
            color = UIColor(white: 1.0, alpha: 0.65)
        case .mist:
            size = .zero
            color = .clear
        }

        let node = SKSpriteNode(color: color, size: size)
        node.blendMode = .alpha
        return node
    }

    private func initialParticlePosition(effect: ThemeOverlayEffect, index: Int) -> CGPoint {
        CGPoint(
            x: seeded01(effect: effect, index: index, salt: 1) * GK.worldWidth,
            y: GK.groundHeight + seeded01(effect: effect, index: index, salt: 2) * (GK.worldHeight - GK.groundHeight)
        )
    }

    private func velocity(for effect: ThemeOverlayEffect, index: Int) -> CGVector {
        switch effect {
        case .rain:
            return CGVector(dx: -20, dy: -210 - seeded01(effect: effect, index: index, salt: 3) * 70)
        case .snow:
            return CGVector(dx: -8 + seeded01(effect: effect, index: index, salt: 4) * 16, dy: -24)
        case .embers:
            return CGVector(dx: -8 + seeded01(effect: effect, index: index, salt: 5) * 16, dy: 30)
        case .bubbles:
            return CGVector(dx: -6 + seeded01(effect: effect, index: index, salt: 6) * 12, dy: 28)
        case .dust:
            return CGVector(dx: -16, dy: 3)
        case .petals:
            return CGVector(dx: -28 - seeded01(effect: effect, index: index, salt: 7) * 18, dy: -8)
        case .seaSpray:
            return CGVector(dx: -35, dy: 14 + seeded01(effect: effect, index: index, salt: 8) * 20)
        case .stars:
            return CGVector(dx: -2, dy: 0)
        case .mist:
            return .zero
        }
    }

    private func spin(for effect: ThemeOverlayEffect, index: Int) -> CGFloat {
        effect == .petals ? (-1.2 + seeded01(effect: effect, index: index, salt: 9) * 2.4) : 0
    }

    private func shouldRecycle(_ node: SKSpriteNode, effect: ThemeOverlayEffect) -> Bool {
        switch effect {
        case .rain, .snow, .petals:
            return node.position.y < GK.groundHeight - 30 || node.position.x < -30
        case .embers, .bubbles, .seaSpray:
            return node.position.y > GK.worldHeight + 30 || node.position.x < -30
        case .dust, .stars:
            return node.position.x < -30
        case .mist:
            return false
        }
    }

    private func recycle(_ node: SKSpriteNode, effect: ThemeOverlayEffect) {
        switch effect {
        case .rain, .snow, .petals:
            node.position = CGPoint(
                x: seeded01(effect: effect, index: Int(node.position.x), salt: 10) * GK.worldWidth,
                y: GK.worldHeight + 20
            )
        case .embers, .bubbles, .seaSpray:
            node.position = CGPoint(
                x: seeded01(effect: effect, index: Int(node.position.y), salt: 11) * GK.worldWidth,
                y: GK.groundHeight + 5
            )
        case .dust, .stars:
            node.position = CGPoint(
                x: GK.worldWidth + 20,
                y: GK.groundHeight + seeded01(effect: effect, index: Int(node.position.y), salt: 12) * (GK.worldHeight - GK.groundHeight)
            )
        case .mist:
            break
        }
    }

    private func setupMistBands() {
        for i in 0..<3 {
            let band = SKSpriteNode(color: UIColor(white: 0.75, alpha: 0.08),
                                    size: CGSize(width: GK.worldWidth * 1.4, height: 46))
            band.anchorPoint = CGPoint(x: 0, y: 0.5)
            band.position = CGPoint(x: CGFloat(i) * GK.worldWidth * 0.55,
                                    y: GK.groundHeight + 150 + CGFloat(i) * 70)
            band.zPosition = -18
            backgroundLayer.addChild(band)

            let move = SKAction.moveBy(x: -GK.worldWidth * 0.55, y: 0, duration: 12 + Double(i) * 4)
            let reset = SKAction.moveBy(x: GK.worldWidth * 0.55, y: 0, duration: 0)
            band.run(.repeatForever(.sequence([move, reset])))
        }
    }

    private func zPosition(for effect: ThemeOverlayEffect) -> CGFloat {
        switch effect {
        case .stars:
            return -75
        case .mist:
            return -18
        default:
            return -10
        }
    }

    private func seeded01(effect: ThemeOverlayEffect, index: Int, salt: Int) -> CGFloat {
        var value = UInt64(abs(effect.rawValue.hashValue &+ index &* 1_103_515_245 &+ salt &* 12_345))
        value ^= value >> 13
        value &*= 0xff51afd7ed558ccd
        value ^= value >> 33
        return CGFloat(value % 10_000) / 10_000
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
