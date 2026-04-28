import SpriteKit
import SwiftUI

// MARK: - ParallaxManager

/// Owns all background/foreground parallax layers: sky gradient, clouds, hills,
/// trees, ground tiles, ground-detail decorations, and stars.
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

    // MARK: - Layers (unowned – the scene's worldNode keeps them alive)

    private let backgroundLayer: SKNode
    private let groundLayer: SKNode
    private let foregroundLayer: SKNode

    // MARK: - Theme / Textures

    private let theme: BackgroundTheme
    private let factory: TextureFactory

    // MARK: - Parallax Sprites

    private var clouds: [SKSpriteNode] = []
    private var hills: [SKSpriteNode] = []
    private var trees: [SKSpriteNode] = []
    private var bushes: [SKSpriteNode] = []

    // MARK: - Ground Scrolling

    private var groundTiles: [SKSpriteNode] = []
    private let groundTileWidth: CGFloat = GK.worldWidth * 2

    // MARK: - Ground Detail (grass blades, pebbles)

    private var groundDetailTiles: [SKNode] = []

    // MARK: - Stars (night / space themes) — single batched sprite

    private var starSprite: SKSpriteNode?

    // MARK: - Init

    /// - Parameters:
    ///   - backgroundLayer: Node for far-distance elements (sky, clouds, hills, trees, stars).
    ///   - groundLayer: Node for ground tiles.
    ///   - foregroundLayer: Node for decorative ground details (grass blades, pebbles).
    ///   - theme: The active `BackgroundTheme` for palette/tinting.
    ///   - factory: Texture factory instance (defaults to `.shared`).
    init(backgroundLayer: SKNode,
         groundLayer: SKNode,
         foregroundLayer: SKNode,
         theme: BackgroundTheme,
         factory: TextureFactory = .shared) {
        self.backgroundLayer = backgroundLayer
        self.groundLayer = groundLayer
        self.foregroundLayer = foregroundLayer
        self.theme = theme
        self.factory = factory
    }

    // MARK: - Public API

    /// Call once during `didMove(to:)` after layers are added to the scene.
    func setup() {
        // Cache accessibility state once to avoid per-frame system queries
        reduceMotionEnabled = UIAccessibility.isReduceMotionEnabled

        setupBackground()
        if theme.showClouds {
            setupClouds()
        }
        setupHills()
        setupTrees()
        setupBushes()
        setupGroundTiles()
        setupGroundDetails()

        if theme.showStars {
            setupStars()
        }
    }

    // MARK: - Cached Accessibility State

    /// Cached at setup() time to avoid querying UIAccessibility every frame.
    private var reduceMotionEnabled: Bool = false

    /// Drive all scrolling. Call every frame from `update(_:)` while the game is playing.
    ///
    /// When Reduce Motion is enabled (Settings → Accessibility → Motion), decorative
    /// parallax layers (clouds, hills, trees) stop scrolling. Ground tiles and details
    /// always scroll because they provide gameplay-relevant motion cues.
    func update(dt: TimeInterval) {
        let dtF = CGFloat(dt)

        // Ground is gameplay-relevant — always scrolls
        scrollGroundTiles(dtF)
        scrollGroundDetails(dtF)

        // Decorative layers respect Reduce Motion preference (cached at setup)
        if !reduceMotionEnabled {
            if !clouds.isEmpty { scrollClouds(dtF) }
            scrollHills(dtF)
            scrollTrees(dtF)
            scrollBushes(dtF)
        }
    }

    // MARK: - Sky Gradient

    private func setupBackground() {
        let skyNode = SKSpriteNode(color: .clear,
                                    size: CGSize(width: GK.worldWidth, height: GK.worldHeight))
        skyNode.position = CGPoint(x: GK.worldWidth / 2, y: GK.worldHeight / 2)
        skyNode.zPosition = -100

        skyNode.texture = createSkyGradientTexture()
        // PERF: Sky is fully opaque — skip alpha blending to save GPU fill-rate.
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
                start: CGPoint(x: 0, y: size.height),   // top
                end:   CGPoint(x: 0, y: 0),              // bottom
                options: []
            )
        }
        let tex = SKTexture(image: image)
        tex.filteringMode = .linear
        return tex
    }

    // MARK: - Clouds

    private func setupClouds() {
        let cloudTex = factory.cloudTexture()
        let tint = theme.cloudTint
        for _ in 0..<5 {
            let scale = CGFloat.random(in: 0.6...1.2)
            let cloud = SKSpriteNode(texture: cloudTex,
                                      size: CGSize(width: 80 * scale, height: 35 * scale))
            cloud.position = CGPoint(
                x: CGFloat.random(in: 0...GK.worldWidth),
                y: CGFloat.random(in: (GK.worldHeight * 0.55)...(GK.worldHeight - 40))
            )
            cloud.color = tint
            cloud.colorBlendFactor = 0.6
            cloud.alpha = CGFloat.random(in: 0.5...0.8)
            cloud.zPosition = -90
            backgroundLayer.addChild(cloud)
            clouds.append(cloud)
        }
    }

    // MARK: - Hills

    private func setupHills() {
        let hillTex = factory.themedHillsTexture(theme: theme)
        hillTex.filteringMode = .nearest
        for i in 0..<2 {
            let hillNode = SKSpriteNode(texture: hillTex,
                                         size: CGSize(width: GK.worldWidth * 2, height: 300))
            hillNode.anchorPoint = CGPoint(x: 0, y: 0)
            hillNode.position = CGPoint(x: CGFloat(i) * GK.worldWidth * 2, y: GK.groundHeight + 10)
            hillNode.zPosition = -60
            hillNode.alpha = 0.8
            backgroundLayer.addChild(hillNode)
            hills.append(hillNode)
        }
    }

    // MARK: - Trees

    private func setupTrees() {
        let treeTex = factory.themedTreesTexture(theme: theme)
        // Nearest-neighbor filtering keeps pixel art crisp when texture (160px)
        // is displayed at 300px (1.875× upscale).
        treeTex.filteringMode = .nearest
        for i in 0..<2 {
            let treeNode = SKSpriteNode(texture: treeTex,
                                         size: CGSize(width: GK.worldWidth * 2, height: 300))
            treeNode.anchorPoint = CGPoint(x: 0, y: 0)
            treeNode.position = CGPoint(x: CGFloat(i) * GK.worldWidth * 2, y: GK.groundHeight - 5)
            treeNode.zPosition = -50
            treeNode.alpha = 0.7
            backgroundLayer.addChild(treeNode)
            trees.append(treeNode)
        }
    }

    // MARK: - Bushes / Foreground Strip
    //
    // Themed bush/fern/debris strip rendered by TextureFactory.  Sits between
    // the tree layer and the ground, scrolling at bush speed to add an extra
    // layer of parallax depth.

    private func setupBushes() {
        let bushTex = factory.themedBushTexture(theme: theme)
        // Nearest-neighbor filtering keeps pixel art crisp when texture (36px)
        // is displayed at 60px (1.67× upscale).
        bushTex.filteringMode = .nearest
        for i in 0..<2 {
            let bushNode = SKSpriteNode(texture: bushTex,
                                         size: CGSize(width: GK.worldWidth * 2, height: 60))
            bushNode.anchorPoint = CGPoint(x: 0, y: 0)
            bushNode.position = CGPoint(x: CGFloat(i) * GK.worldWidth * 2, y: GK.groundHeight - 2)
            bushNode.zPosition = -40
            bushNode.alpha = 0.85
            backgroundLayer.addChild(bushNode)
            bushes.append(bushNode)
        }
    }

    // MARK: - Ground Tiles (visual only — physics stays in GameScene)

    private func setupGroundTiles() {
        let groundTex = factory.themedGroundTexture(theme: theme)
        let tilesNeeded = 3
        for i in 0..<tilesNeeded {
            let tile = SKSpriteNode(texture: groundTex,
                                     size: CGSize(width: groundTileWidth, height: GK.groundHeight))
            tile.anchorPoint = CGPoint(x: 0, y: 0)
            tile.position = CGPoint(x: CGFloat(i) * groundTileWidth, y: 0)
            tile.zPosition = 50
            // PERF: Ground tiles are fully opaque — skip alpha blending.
            tile.blendMode = .replace
            groundLayer.addChild(tile)
            groundTiles.append(tile)
        }
    }

    // MARK: - Ground Details (grass blades & pebbles)
    //
    // PERF: Replaced 66 individual SKShapeNodes (42 grass + 24 pebbles) with 3
    //       pre-rendered SKSpriteNodes.  Each tile's grass and pebbles are baked
    //       into a single texture via TextureFactory.groundDetailTexture().
    //       Eliminates 66 CPU-rendered draw calls and 42 sway SKActions per frame.

    private func setupGroundDetails() {
        let factory = TextureFactory.shared
        for i in 0..<3 {
            let tex = factory.themedGroundDetailTexture(
                theme: theme,
                tileWidth: groundTileWidth,
                groundHeight: GK.groundHeight,
                seed: i * 1337  // deterministic, visually distinct per tile
            )
            let sprite = SKSpriteNode(texture: tex)
            sprite.anchorPoint = CGPoint(x: 0, y: 0)
            sprite.position = CGPoint(x: CGFloat(i) * groundTileWidth, y: 0)
            sprite.zPosition = 55
            foregroundLayer.addChild(sprite)
            groundDetailTiles.append(sprite)
        }
    }

    // MARK: - Stars (night / space themes)
    //
    // PERF: Replaced 40 individual SKShapeNodes (each with its own twinkle
    //       SKAction) with a single pre-rendered SKSpriteNode.  A single subtle
    //       twinkle action on the whole sprite keeps the visual effect while
    //       eliminating 40 draw calls and 40 action evaluations per frame.

    private func setupStars() {
        let factory = TextureFactory.shared
        let starH = GK.worldHeight * 0.6  // stars cover top 60%
        let tex = factory.starFieldTexture(
            width: GK.worldWidth,
            height: starH,
            count: 40,
            seed: 42
        )
        let sprite = SKSpriteNode(texture: tex)
        sprite.anchorPoint = CGPoint(x: 0, y: 0)
        sprite.position = CGPoint(x: 0, y: GK.worldHeight * 0.4)
        sprite.zPosition = -95

        // Single gentle twinkle on the whole star field (replaces 40 individual actions)
        let twinkle = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.65, duration: 2.0),
            SKAction.fadeAlpha(to: 1.0, duration: 2.0),
        ])
        sprite.run(SKAction.repeatForever(twinkle))

        backgroundLayer.addChild(sprite)
        starSprite = sprite
    }

    // MARK: - Scroll Updates (private)

    private func scrollGroundTiles(_ dt: CGFloat) {
        for tile in groundTiles {
            tile.position.x -= GK.groundSpeed * dt
            if tile.position.x <= -groundTileWidth {
                tile.position.x += groundTileWidth * CGFloat(groundTiles.count)
            }
        }
    }

    private func scrollGroundDetails(_ dt: CGFloat) {
        for tile in groundDetailTiles {
            tile.position.x -= GK.groundSpeed * dt
            if tile.position.x <= -groundTileWidth {
                tile.position.x += groundTileWidth * CGFloat(groundDetailTiles.count)
            }
        }
    }

    private func scrollClouds(_ dt: CGFloat) {
        for cloud in clouds {
            cloud.position.x -= GK.cloudSpeed * dt
            if cloud.position.x < -80 {
                cloud.position.x = GK.worldWidth + 80
                cloud.position.y = CGFloat.random(in: (GK.worldHeight * 0.55)...(GK.worldHeight - 40))
            }
        }
    }

    private func scrollHills(_ dt: CGFloat) {
        for hill in hills {
            hill.position.x -= GK.hillSpeed * dt
            if hill.position.x < -(GK.worldWidth * 2) {
                hill.position.x += GK.worldWidth * 4
            }
        }
    }

    private func scrollTrees(_ dt: CGFloat) {
        for tree in trees {
            tree.position.x -= GK.treeSpeed * dt
            if tree.position.x < -(GK.worldWidth * 2) {
                tree.position.x += GK.worldWidth * 4
            }
        }
    }

    private func scrollBushes(_ dt: CGFloat) {
        for bush in bushes {
            bush.position.x -= GK.bushSpeed * dt
            if bush.position.x < -(GK.worldWidth * 2) {
                bush.position.x += GK.worldWidth * 4
            }
        }
    }
}
