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

    // MARK: - Ground Scrolling

    private var groundTiles: [SKSpriteNode] = []
    private let groundTileWidth: CGFloat = GK.worldWidth * 2

    // MARK: - Ground Detail (grass blades, pebbles)

    private var groundDetailTiles: [SKNode] = []

    // MARK: - Stars (night / space themes)

    private var starNodes: [SKShapeNode] = []

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
        setupBackground()
        setupClouds()
        setupHills()
        setupTrees()
        setupGroundTiles()
        setupGroundDetails()

        if theme.showStars {
            setupStars()
        }
    }

    /// Drive all scrolling. Call every frame from `update(_:)` while the game is playing.
    func update(dt: TimeInterval) {
        let dtF = CGFloat(dt)

        scrollGroundTiles(dtF)
        scrollGroundDetails(dtF)
        scrollClouds(dtF)
        scrollHills(dtF)
        scrollTrees(dtF)
    }

    // MARK: - Sky Gradient

    private func setupBackground() {
        let skyNode = SKSpriteNode(color: .clear,
                                    size: CGSize(width: GK.worldWidth, height: GK.worldHeight))
        skyNode.position = CGPoint(x: GK.worldWidth / 2, y: GK.worldHeight / 2)
        skyNode.zPosition = -100

        skyNode.texture = createSkyGradientTexture()
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
        for i in 0..<2 {
            let hillNode = SKSpriteNode(texture: hillTex,
                                         size: CGSize(width: GK.worldWidth * 2, height: 120))
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
        for i in 0..<2 {
            let treeNode = SKSpriteNode(texture: treeTex,
                                         size: CGSize(width: GK.worldWidth * 2, height: 160))
            treeNode.anchorPoint = CGPoint(x: 0, y: 0)
            treeNode.position = CGPoint(x: CGFloat(i) * GK.worldWidth * 2, y: GK.groundHeight - 5)
            treeNode.zPosition = -50
            treeNode.alpha = 0.7
            backgroundLayer.addChild(treeNode)
            trees.append(treeNode)
        }
    }

    // MARK: - Ground Tiles (visual only — physics stays in GameScene)

    private func setupGroundTiles() {
        let groundTex = factory.groundTexture()
        let tilesNeeded = 3
        for i in 0..<tilesNeeded {
            let tile = SKSpriteNode(texture: groundTex,
                                     size: CGSize(width: groundTileWidth, height: GK.groundHeight))
            tile.anchorPoint = CGPoint(x: 0, y: 0)
            tile.position = CGPoint(x: CGFloat(i) * groundTileWidth, y: 0)
            tile.zPosition = 50
            groundLayer.addChild(tile)
            groundTiles.append(tile)
        }
    }

    // MARK: - Ground Details (grass blades & pebbles)

    private func setupGroundDetails() {
        for i in 0..<3 {
            let tile = SKNode()
            tile.position = CGPoint(x: CGFloat(i) * groundTileWidth, y: 0)
            tile.zPosition = 55

            // Small animated grass blades
            for _ in 0..<14 {
                let x = CGFloat.random(in: 0..<groundTileWidth)
                let height = CGFloat.random(in: 6...14)
                let halfW: CGFloat = 1.5

                let path = CGMutablePath()
                path.move(to: CGPoint(x: -halfW, y: 0))
                path.addLine(to: CGPoint(x: 0, y: height))
                path.addLine(to: CGPoint(x: halfW, y: 0))
                path.closeSubpath()

                let blade = SKShapeNode(path: path)
                blade.fillColor = UIColor(
                    red: CGFloat.random(in: 0.25...0.45),
                    green: CGFloat.random(in: 0.55...0.75),
                    blue: CGFloat.random(in: 0.10...0.22),
                    alpha: 1
                )
                blade.strokeColor = .clear
                blade.position = CGPoint(x: x, y: GK.groundHeight)

                // Gentle sway animation
                let swayAngle = CGFloat.random(in: 0.05...0.12)
                let swayDur = Double.random(in: 0.7...1.3)
                let sway = SKAction.sequence([
                    SKAction.rotate(byAngle: swayAngle, duration: swayDur),
                    SKAction.rotate(byAngle: -swayAngle * 2, duration: swayDur * 2),
                    SKAction.rotate(byAngle: swayAngle, duration: swayDur),
                ])
                blade.run(SKAction.repeatForever(sway))

                tile.addChild(blade)
            }

            // Pebble sprites
            for _ in 0..<8 {
                let x = CGFloat.random(in: 0..<groundTileWidth)
                let radius = CGFloat.random(in: 1.5...3.5)
                let pebble = SKShapeNode(circleOfRadius: radius)
                let gray = CGFloat.random(in: 0.45...0.65)
                pebble.fillColor = UIColor(red: gray, green: gray - 0.05, blue: gray - 0.10, alpha: 0.8)
                pebble.strokeColor = .clear
                pebble.position = CGPoint(x: x, y: GK.groundHeight - 2)
                tile.addChild(pebble)
            }

            foregroundLayer.addChild(tile)
            groundDetailTiles.append(tile)
        }
    }

    // MARK: - Stars (night / space themes)

    private func setupStars() {
        for _ in 0..<40 {
            let star = SKShapeNode(circleOfRadius: CGFloat.random(in: 1...2.5))
            star.fillColor = .white
            star.strokeColor = .clear
            star.position = CGPoint(
                x: CGFloat.random(in: 0...GK.worldWidth),
                y: CGFloat.random(in: (GK.worldHeight * 0.4)...GK.worldHeight)
            )
            star.zPosition = -95
            star.alpha = CGFloat.random(in: 0.3...0.9)

            // Twinkle animation
            let twinkle = SKAction.sequence([
                SKAction.fadeAlpha(to: CGFloat.random(in: 0.2...0.5), duration: Double.random(in: 0.8...2.0)),
                SKAction.fadeAlpha(to: CGFloat.random(in: 0.6...1.0), duration: Double.random(in: 0.8...2.0)),
            ])
            star.run(SKAction.repeatForever(twinkle))

            backgroundLayer.addChild(star)
            starNodes.append(star)
        }
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
}
