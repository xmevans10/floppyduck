import SpriteKit
import SwiftUI

// MARK: - Game Phase

enum GamePhase {
    case ready
    case countdown
    case playing
    case dead
    case gameOver
}

// MARK: - Delegate

protocol GameSceneDelegate: AnyObject {
    func gameDidStart()
    func gameDidScore(_ score: Int)
    func gameDidEnd(score: Int)
    func botDidScore(_ botScore: Int)
    func gameDidWinBotLadder(score: Int)
    func gameDidQuickRetry(score: Int)
}

// MARK: - GameScene

final class GameScene: SKScene, SKPhysicsContactDelegate {

    // MARK: - Properties

    weak var gameDelegate: GameSceneDelegate?

    private(set) var phase: GamePhase = .ready
    private(set) var score: Int = 0
    private(set) var botScore: Int = 0

    private var prng: SeededRandom
    private var gapPositions: [CGFloat] = []
    private var pipeIndex: Int = 0

    private let factory = TextureFactory.shared
    private let mode: GameMode
    private let playerSkin: DuckSkin
    private let botDiff: BotDifficulty?
    private let opponentName: String?
    private let targetScore: Int?

    // Layers
    private let worldNode = SKNode()
    private let backgroundLayer = SKNode()
    private let pipeLayer = SKNode()
    private let groundLayer = SKNode()
    private let foregroundLayer = SKNode()   // Enhanced ground decorations (grass blades, pebbles)
    private let hudLayer = SKNode()

    // Duck (Item 2: optional safety)
    private var duck: SKSpriteNode?
    private var duckTextures: [SKTexture] = []

    // Bot / opponent score HUD state (Item 2: already optional)
    private var botDuck: SKSpriteNode?
    private var botTextures: [SKTexture] = []
    private var botY: CGFloat = GK.duckStartY
    private var botVelocity: CGFloat = 0
    private var botAlive: Bool = true
    private var botPipesPassed: Set<String> = []
    private var botScoreLabel: SKLabelNode?
    private var botScoreShadow: SKLabelNode?

    // Score (Item 2: optional safety)
    private var scoreLabel: SKLabelNode?
    private var scoreShadow: SKLabelNode?
    private var scoreOutlines: [SKLabelNode] = []

    // Ground scrolling
    private var groundTiles: [SKSpriteNode] = []
    private let groundTileWidth: CGFloat = GK.worldWidth * 2

    // Ground detail decoration (grass blades, pebbles)
    private var groundDetailTiles: [SKNode] = []

    // Pipe spawning
    private var pipeTimer: TimeInterval = 0
    private var lastUpdate: TimeInterval = 0

    // Progressive difficulty
    private let difficulty = DifficultyManager()
    private var currentPipeSpeed: CGFloat = GK.pipeSpeed

    // Power-up system
    private let powerUpSpawner = PowerUpSpawnManager()
    private var activePowerUps: [ActivePowerUp] = []
    private var shieldNode: SKShapeNode?
    private var pendingPowerUpKind: PowerUpKind?
    private var shieldCooldown: Bool = false

    // Ghost duck visual
    private var ghostGlowNode: SKShapeNode?

    // Bread collectibles
    private var breadCollected: Int = 0

    /// Public accessor for views to display bread count.
    var totalBreadCollected: Int { breadCollected }

    // Parallax layers
    private var clouds: [SKSpriteNode] = []
    private var hills: [SKSpriteNode] = []
    private var trees: [SKSpriteNode] = []

    // Sky theme (Item 9)
    private let backgroundTheme: BackgroundTheme
    private var starNodes: [SKShapeNode] = []

    // Tutorial (Item 8)
    private var tutorialOverlay: SKNode?
    private var tutorialDismissed: Bool = false

    // Death effects (Item 6)
    private var deathVignette: SKSpriteNode?

    // Bot ladder win guard
    private var botLadderWinTriggered = false

    // Floating score popup pool (pre-allocated to avoid per-point allocations)
    private var scorePopupPool: [SKLabelNode] = []
    private var scorePopupPoolIndex: Int = 0

    // MARK: - Init

    init(seed: Int = Int.random(in: 1...999999),
         mode: GameMode = .classic,
         skin: DuckSkin = .classic,
         botDifficulty: BotDifficulty? = nil,
         opponentName: String? = nil,
         targetScore: Int? = nil) {
        self.prng = SeededRandom(seed: seed)
        self.mode = mode
        self.playerSkin = skin
        self.botDiff = botDifficulty
        self.opponentName = opponentName
        self.targetScore = targetScore
        // Use player's selected background theme (purchased in shop)
        self.backgroundTheme = ThemeManager.shared.selectedTheme
        super.init(size: CGSize(width: GK.worldWidth, height: GK.worldHeight))
        self.scaleMode = .aspectFill
        self.gapPositions = prng.generateGapPositions()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    // MARK: - Scene Setup

    override func didMove(to view: SKView) {
        // Apply selected background theme color
        let bgColor = backgroundTheme.backgroundColor
        backgroundColor = bgColor
        physicsWorld.gravity = CGVector(dx: 0, dy: GK.gravity / 60)
        physicsWorld.contactDelegate = self

        // Pre-warm haptics + audio so first trigger has zero latency
        Haptic.warmUp()
        SoundManager.shared.prepare()
        // Item 11: Set active skin for per-skin sound variants
        SoundManager.shared.setActiveSkin(playerSkin)

        addChild(worldNode)
        worldNode.addChild(backgroundLayer)
        worldNode.addChild(pipeLayer)
        worldNode.addChild(groundLayer)
        worldNode.addChild(foregroundLayer)
        addChild(hudLayer)

        setupBackground()
        setupClouds()
        setupHills()
        setupTrees()
        setupGround()
        setupGroundDetails()
        setupDuck()
        setupHUD()

        if backgroundTheme.showStars {
            setupStars()
        }

        if mode == .vsBot {
            setupBotDuck()
        }

        // Duck floats gently before first tap
        guard let duck else { return }
        let float = SKAction.sequence([
            SKAction.moveBy(x: 0, y: 10, duration: 0.5),
            SKAction.moveBy(x: 0, y: -10, duration: 0.5)
        ])
        duck.run(SKAction.repeatForever(float), withKey: "float")
        duck.physicsBody?.isDynamic = false

        // Item 8: First-launch tutorial
        showTutorialIfNeeded()
    }

    // MARK: - Background

    private func setupBackground() {
        // Background gradient from selected theme
        let skyNode = SKSpriteNode(color: .clear,
                                    size: CGSize(width: GK.worldWidth, height: GK.worldHeight))
        skyNode.position = CGPoint(x: GK.worldWidth / 2, y: GK.worldHeight / 2)
        skyNode.zPosition = -100

        let gradientTex = createSkyGradientTexture(theme: backgroundTheme)
        skyNode.texture = gradientTex
        backgroundLayer.addChild(skyNode)
    }

    /// Renders a vertical gradient texture for the background theme.
    private func createSkyGradientTexture(theme: BackgroundTheme) -> SKTexture {
        let size = CGSize(width: 1, height: Int(GK.worldHeight))
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let colors = theme.gradientColors.map { UIColor($0).cgColor } as CFArray
            let space = CGColorSpaceCreateDeviceRGB()
            guard let gradient = CGGradient(colorsSpace: space, colors: colors, locations: nil) else { return }
            ctx.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: size.height),  // top
                end: CGPoint(x: 0, y: 0),                // bottom
                options: []
            )
        }
        let tex = SKTexture(image: image)
        tex.filteringMode = .linear
        return tex
    }

    private func setupClouds() {
        let cloudTex = factory.cloudTexture()
        let tint = backgroundTheme.cloudTint
        for _ in 0..<5 {
            let scale = CGFloat.random(in: 0.6...1.2)
            let cloud = SKSpriteNode(texture: cloudTex,
                                      size: CGSize(width: 80 * scale, height: 35 * scale))
            cloud.position = CGPoint(
                x: CGFloat.random(in: 0...GK.worldWidth),
                y: CGFloat.random(in: (GK.worldHeight * 0.55)...(GK.worldHeight - 40))
            )
            // Tint clouds to match background theme
            cloud.color = tint
            cloud.colorBlendFactor = 0.6
            cloud.alpha = CGFloat.random(in: 0.5...0.8)
            cloud.zPosition = -90
            backgroundLayer.addChild(cloud)
            clouds.append(cloud)
        }
    }

    private func setupHills() {
        let hillTex = factory.themedHillsTexture(theme: backgroundTheme)
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

    private func setupTrees() {
        let treeTex = factory.themedTreesTexture(theme: backgroundTheme)
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

    // MARK: - Ground

    private func setupGround() {
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

        // Ground physics
        let groundBody = SKNode()
        groundBody.position = CGPoint(x: GK.worldWidth / 2, y: GK.groundHeight)
        groundBody.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: GK.worldWidth * 2, height: 2))
        groundBody.physicsBody?.isDynamic = false
        groundBody.physicsBody?.categoryBitMask = GK.groundCategory
        groundBody.physicsBody?.contactTestBitMask = GK.duckCategory
        worldNode.addChild(groundBody)

        // Ceiling
        let ceiling = SKNode()
        ceiling.position = CGPoint(x: GK.worldWidth / 2, y: GK.worldHeight + 20)
        ceiling.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: GK.worldWidth * 2, height: 2))
        ceiling.physicsBody?.isDynamic = false
        worldNode.addChild(ceiling)
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

    // MARK: - Duck (skin-aware, tighter hitbox)

    private func setupDuck() {
        duckTextures = (0...2).map { factory.skinDuckTexture(skin: playerSkin, wingPhase: $0) }

        let sprite = SKSpriteNode(texture: duckTextures[1], size: playerSkin.spriteSize)
        sprite.position = CGPoint(x: GK.duckStartX, y: GK.duckStartY)
        sprite.zPosition = 40

        sprite.physicsBody = SKPhysicsBody(circleOfRadius: GK.duckRadius * 0.80)
        sprite.physicsBody?.categoryBitMask = GK.duckCategory
        sprite.physicsBody?.contactTestBitMask = GK.pipeCategory | GK.groundCategory | GK.powerUpCategory | GK.breadCategory
        sprite.physicsBody?.collisionBitMask = GK.groundCategory | GK.pipeCategory
        sprite.physicsBody?.allowsRotation = false
        sprite.physicsBody?.restitution = 0
        sprite.physicsBody?.linearDamping = 0
        sprite.physicsBody?.usesPreciseCollisionDetection = true

        worldNode.addChild(sprite)
        duck = sprite
        startWingAnimation()
    }

    // Item 2: Safe optional chaining
    private func startWingAnimation() {
        let wingAction = SKAction.animate(with: duckTextures, timePerFrame: 0.10)
        duck?.run(SKAction.repeatForever(wingAction), withKey: "wings")
    }

    // MARK: - Bot Ghost Duck

    private func setupBotDuck() {
        botTextures = (0...2).map { factory.skinBotDuckTexture(skin: playerSkin, wingPhase: $0) }

        let bot = SKSpriteNode(texture: botTextures[1],
                               size: playerSkin.spriteSize)
        bot.position = CGPoint(x: GK.duckStartX, y: GK.duckStartY)
        bot.zPosition = 35

        let wingAction = SKAction.animate(with: botTextures, timePerFrame: 0.10)
        bot.run(SKAction.repeatForever(wingAction), withKey: "botWings")

        let float = SKAction.sequence([
            SKAction.moveBy(x: 0, y: 10, duration: 0.5),
            SKAction.moveBy(x: 0, y: -10, duration: 0.5)
        ])
        bot.run(SKAction.repeatForever(float), withKey: "botFloat")

        worldNode.addChild(bot)
        botDuck = bot
        botY = GK.duckStartY
        botVelocity = 0
        botAlive = true
    }

    // MARK: - HUD

    private func setupHUD() {
        // 4 diagonal outlines only (down from 8 cardinal+diagonal) — visually identical at game scale,
        // half the SKLabelNode mutations per score point.
        let outlineOffsets: [(CGFloat, CGFloat)] = [
            (-2, -2), (-2, 2), (2, -2), (2, 2)
        ]
        scoreOutlines.removeAll()
        for offset in outlineOffsets {
            let outline = SKLabelNode(fontNamed: GK.pixelFontName)
            outline.fontSize = 36
            outline.fontColor = UIColor(red: 0.20, green: 0.33, blue: 0.10, alpha: 0.9)
            outline.position = CGPoint(x: GK.worldWidth / 2 + offset.0, y: GK.worldHeight - 76 + offset.1)
            outline.zPosition = 199
            outline.text = "0"
            outline.verticalAlignmentMode = .center
            outline.horizontalAlignmentMode = .center
            hudLayer.addChild(outline)
            scoreOutlines.append(outline)
        }

        // Shadow node removed — diagonal outlines give sufficient legibility,
        // eliminating one more text mutation per point.

        let label = SKLabelNode(fontNamed: GK.pixelFontName)
        label.fontSize = 36
        label.fontColor = .white
        label.position = CGPoint(x: GK.worldWidth / 2, y: GK.worldHeight - 76)
        label.zPosition = 201
        label.text = "0"
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        hudLayer.addChild(label)
        scoreLabel = label

        if mode == .vsBot || mode == .headToHead {
            setupBotScoreHUD()
        }

        // Pre-allocate floating score popup pool (avoids addChild/removeFromParent per point)
        scorePopupPool = (0..<3).map { _ in
            let node = SKLabelNode(fontNamed: GK.pixelFontName)
            node.fontSize = 14
            node.fontColor = .white
            node.zPosition = 300
            node.isHidden = true
            worldNode.addChild(node)
            return node
        }
        scorePopupPoolIndex = 0
    }

    // Item 2: Force unwrap safety — all bot score HUD uses safe optional chaining
    private func setupBotScoreHUD() {
        let labelText: String
        if mode == .headToHead {
            labelText = opponentName ?? "OPPONENT"
        } else {
            labelText = opponentName ?? "BOT"
        }

        let shadow = SKLabelNode(fontNamed: GK.pixelFontName)
        shadow.fontSize = 14
        shadow.fontColor = UIColor(red: 0.42, green: 0.12, blue: 0.12, alpha: 0.7)
        shadow.position = CGPoint(x: GK.worldWidth / 2 + 1, y: GK.worldHeight - 108)
        shadow.zPosition = 200
        shadow.text = "\(labelText): 0"
        shadow.verticalAlignmentMode = .center
        shadow.horizontalAlignmentMode = .center
        hudLayer.addChild(shadow)
        botScoreShadow = shadow

        let label = SKLabelNode(fontNamed: GK.pixelFontName)
        label.fontSize = 14
        label.fontColor = UIColor(red: 0.95, green: 0.60, blue: 0.60, alpha: 0.9)
        label.position = CGPoint(x: GK.worldWidth / 2, y: GK.worldHeight - 107)
        label.zPosition = 201
        label.text = "\(labelText): 0"
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        hudLayer.addChild(label)
        botScoreLabel = label
    }

    private func updateScore() {
        let text = "\(score)"
        scoreLabel?.text = text
        for outline in scoreOutlines {
            outline.text = text
        }

        // Only post VoiceOver announcement when VoiceOver is actually running —
        // UIAccessibility.post() stalls the main thread even when VO is disabled.
        if UIAccessibility.isVoiceOverRunning {
            UIAccessibility.post(notification: .announcement, argument: "Score: \(score)")
        }
    }

    private func updateBotScoreHUD() {
        let label: String
        if mode == .headToHead {
            label = opponentName ?? "OPPONENT"
        } else {
            label = opponentName ?? "BOT"
        }
        let text = "\(label): \(botScore)"
        botScoreLabel?.text = text
        botScoreShadow?.text = text
    }

    /// Multiplayer-only update hook used by GameContainerView polling.
    func setOpponentScore(_ score: Int) {
        guard mode == .headToHead else { return }
        botScore = max(0, score)
        updateBotScoreHUD()
    }

    // MARK: - Pipes

    private func spawnPipe() {
        guard pipeIndex < gapPositions.count else { return }
        let gapY = gapPositions[pipeIndex]
        let currentPipeIndex = pipeIndex
        pipeIndex += 1

        var effectiveGap = difficulty.effectivePipeGap

        // Power-up gap modifiers
        if activePowerUps.contains(where: { $0.kind == .pipeExpander && ($0.remainingPipes ?? 0) > 0 }) {
            effectiveGap *= 1.3
        }
        if activePowerUps.contains(where: { $0.kind == .pipeSqueeze && ($0.remainingPipes ?? 0) > 0 }) {
            effectiveGap *= 0.8
        }

        let pipeNode = SKNode()
        pipeNode.position = CGPoint(x: GK.worldWidth + GK.pipeWidth, y: 0)
        pipeNode.zPosition = 20
        pipeNode.name = "pipe_\(currentPipeIndex)"

        // Bottom pipe
        let bottomH = gapY - effectiveGap / 2 - GK.groundHeight
        if bottomH > 0 {
            let bottomBody = SKSpriteNode(
                texture: factory.pipeTexture(height: bottomH),
                size: CGSize(width: GK.pipeWidth, height: bottomH)
            )
            bottomBody.anchorPoint = CGPoint(x: 0.5, y: 0)
            bottomBody.position = CGPoint(x: 0, y: GK.groundHeight)
            pipeNode.addChild(bottomBody)

            let bottomCap = SKSpriteNode(
                texture: factory.pipeCapTexture(),
                size: CGSize(width: GK.pipeWidth + 10, height: 30)
            )
            bottomCap.anchorPoint = CGPoint(x: 0.5, y: 0)
            bottomCap.position = CGPoint(x: 0, y: GK.groundHeight + bottomH - 4)
            pipeNode.addChild(bottomCap)
        }

        // Top pipe
        let topY = gapY + effectiveGap / 2
        let topH = GK.worldHeight - topY
        if topH > 0 {
            let topBody = SKSpriteNode(
                texture: factory.pipeTexture(height: topH),
                size: CGSize(width: GK.pipeWidth, height: topH)
            )
            topBody.anchorPoint = CGPoint(x: 0.5, y: 1)
            topBody.position = CGPoint(x: 0, y: GK.worldHeight)
            pipeNode.addChild(topBody)

            let topCap = SKSpriteNode(
                texture: factory.pipeCapTexture(),
                size: CGSize(width: GK.pipeWidth + 10, height: 30)
            )
            topCap.anchorPoint = CGPoint(x: 0.5, y: 1)
            topCap.position = CGPoint(x: 0, y: topY + 4)
            pipeNode.addChild(topCap)
        }

        // Collision bodies
        if bottomH > 0 {
            let bCollider = SKNode()
            bCollider.position = CGPoint(x: 0, y: GK.groundHeight + bottomH / 2)
            bCollider.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: GK.pipeWidth, height: bottomH))
            bCollider.physicsBody?.isDynamic = false
            bCollider.physicsBody?.categoryBitMask = GK.pipeCategory
            bCollider.physicsBody?.contactTestBitMask = GK.duckCategory
            pipeNode.addChild(bCollider)

            let bCapCollider = SKNode()
            bCapCollider.position = CGPoint(x: 0, y: GK.groundHeight + bottomH - 2)
            bCapCollider.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: GK.pipeWidth + 10, height: 30))
            bCapCollider.physicsBody?.isDynamic = false
            bCapCollider.physicsBody?.categoryBitMask = GK.pipeCategory
            bCapCollider.physicsBody?.contactTestBitMask = GK.duckCategory
            pipeNode.addChild(bCapCollider)
        }

        let topH2 = GK.worldHeight - topY
        if topH2 > 0 {
            let tCollider = SKNode()
            tCollider.position = CGPoint(x: 0, y: topY + topH2 / 2)
            tCollider.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: GK.pipeWidth, height: topH2))
            tCollider.physicsBody?.isDynamic = false
            tCollider.physicsBody?.categoryBitMask = GK.pipeCategory
            tCollider.physicsBody?.contactTestBitMask = GK.duckCategory
            pipeNode.addChild(tCollider)

            let tCapCollider = SKNode()
            tCapCollider.position = CGPoint(x: 0, y: topY + 2)
            tCapCollider.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: GK.pipeWidth + 10, height: 30))
            tCapCollider.physicsBody?.isDynamic = false
            tCapCollider.physicsBody?.categoryBitMask = GK.pipeCategory
            tCapCollider.physicsBody?.contactTestBitMask = GK.duckCategory
            pipeNode.addChild(tCapCollider)
        }

        // Score trigger
        let scoreTrigger = SKNode()
        scoreTrigger.position = CGPoint(x: GK.pipeWidth / 2 + 10, y: gapY)
        scoreTrigger.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 2, height: effectiveGap))
        scoreTrigger.physicsBody?.isDynamic = false
        scoreTrigger.physicsBody?.categoryBitMask = GK.scoreCategory
        scoreTrigger.physicsBody?.contactTestBitMask = GK.duckCategory
        scoreTrigger.name = "scoreTrigger"
        pipeNode.addChild(scoreTrigger)

        // Attach pending power-up collectible to this pipe
        if let kind = pendingPowerUpKind {
            pendingPowerUpKind = nil
            addPowerUpCollectible(to: pipeNode, gapY: gapY, kind: kind)
        }

        let moveDistance = GK.worldWidth + GK.pipeWidth * 3
        let moveDuration = TimeInterval(moveDistance / currentPipeSpeed)
        pipeNode.run(SKAction.sequence([
            SKAction.moveBy(x: -moveDistance, y: 0, duration: moveDuration),
            SKAction.removeFromParent()
        ]))

        pipeLayer.addChild(pipeNode)

        // Spawn bread collectibles between pipes (~60% chance)
        if CGFloat.random(in: 0...1) < 0.6 {
            spawnBreadGroup(afterPipeX: GK.worldWidth + GK.pipeWidth, gapY: gapY, moveDuration: moveDuration, moveDistance: moveDistance)
        }
    }

    // MARK: - Bread Collectibles

    /// Spawns 1–3 bread slices between the current pipe and the next expected pipe position.
    private func spawnBreadGroup(afterPipeX: CGFloat, gapY: CGFloat, moveDuration: TimeInterval, moveDistance: CGFloat) {
        let breadCount = Int.random(in: 1...3)
        let spacing = currentPipeSpeed * CGFloat(GK.pipeSpawnInterval)
        let minBreadY = GK.groundHeight + 40
        let maxBreadY = GK.worldHeight * 0.80

        for i in 0..<breadCount {
            let xOffset = CGFloat.random(in: (spacing * 0.25)...(spacing * 0.75))
            let breadX = afterPipeX + xOffset + CGFloat(i) * 20
            let breadY = CGFloat.random(in: minBreadY...maxBreadY)

            let breadNode = SKLabelNode(text: "🍞")
            breadNode.fontSize = 16
            breadNode.verticalAlignmentMode = .center
            breadNode.horizontalAlignmentMode = .center
            breadNode.position = CGPoint(x: breadX, y: breadY)
            breadNode.zPosition = 25
            breadNode.name = "bread"

            // Physics body for collection
            breadNode.physicsBody = SKPhysicsBody(circleOfRadius: 10)
            breadNode.physicsBody?.isDynamic = false
            breadNode.physicsBody?.categoryBitMask = GK.breadCategory
            breadNode.physicsBody?.contactTestBitMask = GK.duckCategory
            breadNode.physicsBody?.collisionBitMask = 0

            // Gentle bob animation
            let bob = SKAction.sequence([
                SKAction.moveBy(x: 0, y: 5, duration: 0.4),
                SKAction.moveBy(x: 0, y: -5, duration: 0.4),
            ])
            breadNode.run(SKAction.repeatForever(bob))

            // Move left with pipe speed + auto-remove
            let breadMoveDistance = breadX + GK.pipeWidth
            let breadMoveDuration = TimeInterval(breadMoveDistance / currentPipeSpeed)
            breadNode.run(SKAction.sequence([
                SKAction.moveBy(x: -breadMoveDistance, y: 0, duration: breadMoveDuration),
                SKAction.removeFromParent()
            ]))

            pipeLayer.addChild(breadNode)
        }
    }

    /// Called when duck contacts a bread node.
    private func collectBread(node: SKNode) {
        node.removeFromParent()
        breadCollected += 1
        SoundManager.shared.play(.score)
        Haptic.score()

        // Tiny "+1 🍞" popup
        guard let duck else { return }
        let popup = SKLabelNode(fontNamed: GK.pixelFontName)
        popup.text = "+1 🍞"
        popup.fontSize = 10
        popup.fontColor = UIColor(red: 0.85, green: 0.68, blue: 0.30, alpha: 1)
        popup.position = CGPoint(x: duck.position.x + 15, y: duck.position.y + 20)
        popup.zPosition = 300
        worldNode.addChild(popup)

        let floatUp = SKAction.moveBy(x: 0, y: 35, duration: 0.5)
        let fadeOut = SKAction.fadeOut(withDuration: 0.5)
        popup.run(SKAction.sequence([
            SKAction.group([floatUp, fadeOut]),
            SKAction.removeFromParent()
        ]))
    }

    // MARK: - Bread Magnet Effect

    /// Attracts nearby bread nodes toward the duck each frame when breadMagnet is active.
    private func applyBreadMagnetEffect() {
        guard let duck else { return }
        let magnetRadius: CGFloat = 120
        let magnetStrength: CGFloat = 3.0

        for child in pipeLayer.children where child.name == "bread" {
            let breadWorldPos = child.convert(CGPoint.zero, to: worldNode)
            let dx = duck.position.x - breadWorldPos.x
            let dy = duck.position.y - breadWorldPos.y
            let distance = sqrt(dx * dx + dy * dy)

            if distance < magnetRadius && distance > 1 {
                let factor = magnetStrength * (1.0 - distance / magnetRadius)
                child.position.x += dx / distance * factor
                child.position.y += dy / distance * factor
            }
        }
    }

    // MARK: - Touch / Flap

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Item 8: Dismiss tutorial on first tap
        dismissTutorial()

        switch phase {
        case .ready:
            startPlaying()
            flap()
        case .playing:
            flap()
        case .dead:
            // Quick retry — tap during death animation to skip game-over and restart instantly.
            // Disabled for head-to-head (match finalization required).
            guard mode != .headToHead else { break }
            // Don't allow quick-retry during bot ladder win celebration —
            // the celebration callback needs to fire to register the win.
            guard !botLadderWinTriggered else { break }
            self.removeAllActions()
            duck?.removeAllActions()
            deathVignette?.removeFromParent()
            deathVignette = nil
            gameDelegate?.gameDidQuickRetry(score: score)
            resetGame()
        default:
            break
        }
    }

    // Item 2: Safe optional chaining for duck
    func flap() {
        guard phase == .playing, let duck else { return }

        // DizzyDuck: invert flap direction (push down instead of up)
        let impulse: CGFloat
        if activePowerUps.contains(where: { $0.kind == .dizzyDuck }) {
            impulse = -difficulty.effectiveFlapImpulse
        } else {
            impulse = difficulty.effectiveFlapImpulse
        }

        duck.physicsBody?.velocity = CGVector(dx: 0, dy: impulse)
        Haptic.flap()
        SoundManager.shared.play(.flap)

        duck.removeAction(forKey: "wings")
        let flutter = SKAction.sequence([
            SKAction.setTexture(duckTextures[2]),
            SKAction.wait(forDuration: 0.05),
            SKAction.setTexture(duckTextures[0]),
            SKAction.wait(forDuration: 0.05),
            SKAction.setTexture(duckTextures[1]),
        ])
        duck.run(SKAction.sequence([flutter, SKAction.run { [weak self] in
            self?.startWingAnimation()
        }]), withKey: "wings")
    }

    private func startPlaying() {
        phase = .playing
        duck?.removeAction(forKey: "float")
        duck?.physicsBody?.isDynamic = true

        if mode == .vsBot {
            botDuck?.removeAction(forKey: "botFloat")
        }

        gameDelegate?.gameDidStart()
    }

    // MARK: - Update Loop

    override func update(_ currentTime: TimeInterval) {
        // Item 2: Safe optional access for duck
        if phase == .dead, let duck {
            // Smooth nose-down rotation during scripted death fall
            let target: CGFloat = -.pi / 2
            duck.zRotation += (target - duck.zRotation) * 0.08
        }

        guard phase == .playing else {
            lastUpdate = currentTime
            return
        }

        let dt = lastUpdate == 0 ? 0 : currentTime - lastUpdate
        lastUpdate = currentTime

        // --- Power-up tick: expire finished effects ---
        tickPowerUps(currentTime: currentTime)

        // --- Difficulty-driven gravity ---
        var gravity = difficulty.effectiveGravity

        // DizzyDuck: invert gravity direction
        if activePowerUps.contains(where: { $0.kind == .dizzyDuck }) {
            gravity = -gravity
        }

        physicsWorld.gravity = CGVector(dx: 0, dy: gravity / 60)

        // --- Difficulty-driven pipe speed ---
        var speed = difficulty.effectivePipeSpeed

        // SlowMotion: reduce pipe speed by 35%
        if activePowerUps.contains(where: { $0.kind == .slowMotion }) {
            speed *= 0.65
        }
        // SpeedBurst: increase pipe speed by 40%
        if activePowerUps.contains(where: { $0.kind == .speedBurst }) {
            speed *= 1.4
        }

        currentPipeSpeed = speed

        // --- GhostDuck visual: maintain alpha while active ---
        if activePowerUps.contains(where: { $0.kind == .ghostDuck }) {
            duck?.alpha = 0.4
        }

        // --- BreadMagnet: attract nearby bread each frame ---
        if activePowerUps.contains(where: { $0.kind == .breadMagnet && ($0.remainingPipes ?? 0) > 0 }) {
            applyBreadMagnetEffect()
        }

        // Spawn pipes
        pipeTimer += dt
        if pipeTimer >= GK.pipeSpawnInterval {
            pipeTimer -= GK.pipeSpawnInterval
            spawnPipe()
        }

        // Scroll ground
        for tile in groundTiles {
            tile.position.x -= GK.groundSpeed * CGFloat(dt)
            if tile.position.x <= -groundTileWidth {
                tile.position.x += groundTileWidth * CGFloat(groundTiles.count)
            }
        }

        // Scroll ground details (grass blades, pebbles)
        for tile in groundDetailTiles {
            tile.position.x -= GK.groundSpeed * CGFloat(dt)
            if tile.position.x <= -groundTileWidth {
                tile.position.x += groundTileWidth * CGFloat(groundDetailTiles.count)
            }
        }

        // Parallax clouds
        for cloud in clouds {
            cloud.position.x -= GK.cloudSpeed * CGFloat(dt)
            if cloud.position.x < -80 {
                cloud.position.x = GK.worldWidth + 80
                cloud.position.y = CGFloat.random(in: (GK.worldHeight * 0.55)...(GK.worldHeight - 40))
            }
        }

        for hill in hills {
            hill.position.x -= GK.hillSpeed * CGFloat(dt)
            if hill.position.x < -(GK.worldWidth * 2) {
                hill.position.x += GK.worldWidth * 4
            }
        }

        for tree in trees {
            tree.position.x -= GK.treeSpeed * CGFloat(dt)
            if tree.position.x < -(GK.worldWidth * 2) {
                tree.position.x += GK.worldWidth * 4
            }
        }

        // Item 2: Duck rotation with safe optional
        if let duck, let vy = duck.physicsBody?.velocity.dy {
            let flapRef = difficulty.effectiveFlapImpulse
            let target = vy > 0
                ? min(vy / flapRef * 0.4, 0.4)
                : max(vy / 400, -CGFloat.pi / 2)
            duck.zRotation += (target - duck.zRotation) * 0.10
        }

        if mode == .vsBot {
            updateBot(dt: dt)
        }
    }

    // MARK: - Bot AI (configurable difficulty)

    private func updateBot(dt: TimeInterval) {
        guard botAlive, let bot = botDuck else { return }

        let diff = botDiff ?? BotDifficulty(noiseRange: 12, flapStrength: 0.88, errorRate: 0)

        // Apply gravity
        botVelocity += GK.gravity / 60 * CGFloat(dt) * 60
        botY += botVelocity * CGFloat(dt)

        let botR = GK.duckRadius * 0.85

        // Ground collision
        if botY <= GK.groundHeight + botR {
            botY = GK.groundHeight + botR
            botDied()
            return
        }

        // Ceiling clamp
        if botY >= GK.worldHeight - botR {
            botY = GK.worldHeight - botR
            botVelocity = 0
        }

        // Single-pass pipe iteration: find nearest pipe, check collision, check scoring all at once
        var targetGapY: CGFloat = GK.duckStartY
        var nearestDist: CGFloat = CGFloat.greatestFiniteMagnitude

        let effectiveBotGap = difficulty.effectivePipeGap

        for child in pipeLayer.children {
            let pipeX = child.position.x
            let dist = pipeX - GK.duckStartX

            // Find nearest pipe ahead
            if dist > -(GK.pipeWidth / 2) && dist < nearestDist {
                if let trigger = child.childNode(withName: "scoreTrigger") {
                    targetGapY = trigger.position.y
                    nearestDist = dist
                }
            }

            // Pipe collision (only check pipes near the bot)
            if abs(dist) < GK.pipeWidth / 2 + botR * 0.6 {
                if let trigger = child.childNode(withName: "scoreTrigger") {
                    let gapY = trigger.position.y
                    let gapTop = gapY + effectiveBotGap / 2 - 5
                    let gapBottom = gapY - effectiveBotGap / 2 + 5
                    if botY + botR > gapTop || botY - botR < gapBottom {
                        botDied()
                        return
                    }
                }
            }

            // Bot scoring
            if let pipeName = child.name, pipeX < GK.duckStartX - GK.pipeWidth / 2 {
                if !botPipesPassed.contains(pipeName) {
                    botPipesPassed.insert(pipeName)
                    botScore += 1
                    updateBotScoreHUD()
                    gameDelegate?.botDidScore(botScore)
                }
            }
        }

        // Noise based on difficulty
        let noise = CGFloat.random(in: -diff.noiseRange...diff.noiseRange)
        let adjustedTarget = targetGapY + noise

        // Error rate: sometimes fail to flap
        let shouldError = CGFloat.random(in: 0...1) < diff.errorRate

        // Flap when below target (unless error)
        if !shouldError && botY < adjustedTarget - 8 && botVelocity < GK.flapImpulse * 0.5 {
            botVelocity = GK.flapImpulse * diff.flapStrength
        }

        bot.position.y = botY

        let target = botVelocity > 0
            ? min(botVelocity / GK.flapImpulse * 0.4, 0.4)
            : max(botVelocity / 400, -CGFloat.pi / 2)
        bot.zRotation += (target - bot.zRotation) * 0.10
    }

    private func botDied() {
        botAlive = false
        guard let bot = botDuck else { return }
        bot.removeAction(forKey: "botWings")
        bot.run(SKAction.sequence([
            SKAction.group([
                SKAction.moveBy(x: 0, y: 30, duration: 0.3),
                SKAction.rotate(byAngle: -CGFloat.pi / 2, duration: 0.3),
            ]),
            SKAction.group([
                SKAction.moveTo(y: GK.groundHeight, duration: 0.5),
                SKAction.rotate(byAngle: -CGFloat.pi, duration: 0.5),
            ]),
            SKAction.fadeOut(withDuration: 0.3),
        ]))
    }

    // MARK: - Collision

    func didBegin(_ contact: SKPhysicsContact) {
        let bodies = [contact.bodyA, contact.bodyB]
        let masks = bodies.map { $0.categoryBitMask }

        // --- Bread collectible contact ---
        if masks.contains(GK.breadCategory) && masks.contains(GK.duckCategory) {
            if let breadNode = bodies.first(where: { $0.categoryBitMask == GK.breadCategory })?.node {
                collectBread(node: breadNode)
            }
            return
        }

        // --- Score trigger contact ---
        if masks.contains(GK.scoreCategory) && masks.contains(GK.duckCategory) {
            bodies.first { $0.categoryBitMask == GK.scoreCategory }?.node?.removeFromParent()
            score += 1
            updateScore()
            Haptic.score()
            SoundManager.shared.play(.score)

            // Item 5: Floating score popup
            let isMilestone = score % 5 == 0
            spawnFloatingScorePopup(isMilestone: isMilestone)

            // --- Progressive difficulty update ---
            let tierChanged = difficulty.update(score: score)
            if tierChanged {
                showTierChangeLabel(tier: difficulty.currentTier)
            }

            // --- Power-up spawn check ---
            if let kind = powerUpSpawner.onPipeScored(currentScore: score, tier: difficulty.currentTier) {
                pendingPowerUpKind = kind
            }

            // --- Pipe-count-based power-up tracking (breadMagnet, pipeExpander, pipeSqueeze) ---
            for i in activePowerUps.indices {
                if activePowerUps[i].remainingPipes != nil {
                    activePowerUps[i].remainingPipes! -= 1
                }
            }

            // Milestone haptic every 5 pipes
            if isMilestone {
                Haptic.milestone()
                SoundManager.shared.play(.milestone)
            }

            gameDelegate?.gameDidScore(score)

            // Check if bot ladder target score is reached — trigger win!
            if mode == .vsBot,
               let target = targetScore,
               score >= target,
               !botLadderWinTriggered {
                celebrateBotLadderWin()
            }

            return
        }

        // --- Power-up collectible contact ---
        if masks.contains(GK.powerUpCategory) && masks.contains(GK.duckCategory) {
            if let powerUpNode = bodies.first(where: { $0.categoryBitMask == GK.powerUpCategory })?.node {
                collectPowerUp(node: powerUpNode)
            }
            return
        }

        // --- Pipe / ground collision ---
        if phase == .playing {
            // GhostDuck: ignore pipe collisions entirely
            let isPipeHit = masks.contains(GK.pipeCategory)
            if isPipeHit && activePowerUps.contains(where: { $0.kind == .ghostDuck }) {
                return
            }

            // Shield absorbs pipe collisions (not ground)
            if isPipeHit && (hasActiveShield() || shieldCooldown) {
                if hasActiveShield() {
                    consumeShield()
                }
                return
            }
            die()
        }
    }

    private func die() {
        phase = .dead
        // Item 6: Enhanced death haptic
        Haptic.enhancedDeath()
        SoundManager.shared.play(.death)
        SoundManager.shared.stopPlayMusic()

        guard let duck else { return }

        // Bump duck above ground layers so it doesn't clip behind them
        duck.zPosition = 60

        // Restore duck alpha in case ghostDuck was active
        duck.alpha = 1.0
        removeGhostGlow()

        // Freeze all scrolling layers — parallax stops immediately on death
        pipeLayer.isPaused = true
        groundLayer.isPaused = true
        backgroundLayer.isPaused = true
        foregroundLayer.isPaused = true

        // Item 6: Brief slowmo pause (freeze scene for 0.08s)
        self.isPaused = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            self?.isPaused = false
        }

        // Item 6: Camera zoom-in (1.03x)
        let zoomIn = SKAction.scale(to: 1.03, duration: 0.15)
        let zoomOut = SKAction.scale(to: 1.0, duration: 0.4)
        worldNode.run(SKAction.sequence([zoomIn, zoomOut]))

        let flash = SKSpriteNode(color: .white, size: self.size)
        flash.position = CGPoint(x: size.width / 2, y: size.height / 2)
        flash.zPosition = 500
        flash.alpha = 0.8
        addChild(flash)
        flash.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.3),
            SKAction.removeFromParent()
        ]))

        // Item 6: Red vignette overlay that fades
        // Delay start until white flash recedes so the red tint is actually visible
        let vignette = SKSpriteNode(color: UIColor(red: 0.8, green: 0.0, blue: 0.0, alpha: 0.45), size: self.size)
        vignette.position = CGPoint(x: size.width / 2, y: size.height / 2)
        vignette.zPosition = 499
        vignette.alpha = 0
        addChild(vignette)
        deathVignette = vignette
        vignette.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.2),          // wait for flash to fade
            SKAction.fadeAlpha(to: 0.5, duration: 0.12),
            SKAction.fadeOut(withDuration: 0.9),
            SKAction.removeFromParent()
        ]))

        // Item 6: Stronger/longer screen shake
        worldNode.run(SKAction.sequence([
            SKAction.moveBy(x: 8, y: 5, duration: 0.025),
            SKAction.moveBy(x: -16, y: -10, duration: 0.025),
            SKAction.moveBy(x: 12, y: 7, duration: 0.025),
            SKAction.moveBy(x: -8, y: -4, duration: 0.025),
            SKAction.moveBy(x: 6, y: 3, duration: 0.025),
            SKAction.moveBy(x: -4, y: -2, duration: 0.025),
            SKAction.moveBy(x: 2, y: 1, duration: 0.025),
            SKAction.move(to: .zero, duration: 0.03),
        ]))

        duck.removeAction(forKey: "wings")
        duck.texture = duckTextures[0]

        // Disable physics — scripted fall only, no collision-based movement.
        duck.physicsBody?.velocity = .zero
        duck.physicsBody?.isDynamic = false

        // Reparent duck from worldNode → scene root so screen shake / zoom
        // on worldNode doesn't move the duck sideways during the death fall.
        let worldPos = duck.convert(CGPoint.zero, to: self)
        duck.removeFromParent()
        duck.position = worldPos
        duck.zPosition = 500  // above everything including flash/vignette
        addChild(duck)

        // Straight-down fall to ground level
        let groundY = GK.groundHeight + (duck.size.height / 2)
        let fallDistance = max(duck.position.y - groundY, 0)
        let fallDuration = max(0.25, min(Double(fallDistance / 500), 0.65))
        let fallAction = SKAction.moveTo(y: groundY, duration: fallDuration)
        fallAction.timingMode = .easeIn
        duck.run(fallAction, withKey: "deathFall")

        duck.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.8),
            SKAction.fadeAlpha(to: 0.3, duration: 0.3)
        ]))

        run(SKAction.sequence([
            SKAction.wait(forDuration: 1.2),
            SKAction.run { [weak self] in
                guard let self else { return }
                self.phase = .gameOver
                self.gameDelegate?.gameDidEnd(score: self.score)
            }
        ]))
    }

    // MARK: - Bot Ladder Win Celebration

    private func celebrateBotLadderWin() {
        guard !botLadderWinTriggered else { return }
        botLadderWinTriggered = true

        phase = .dead  // Stop gameplay
        SoundManager.shared.stopPlayMusic()
        SoundManager.shared.play(.win)
        Haptic.win()

        // Freeze world
        pipeLayer.isPaused = true
        groundLayer.isPaused = true
        backgroundLayer.isPaused = true
        foregroundLayer.isPaused = true

        guard let duck else { return }

        // Duck victory flight — float upward triumphantly
        duck.physicsBody?.isDynamic = false
        duck.removeAction(forKey: "wings")
        startWingAnimation()
        duck.zPosition = 100
        duck.zRotation = 0

        let victoryFlight = SKAction.sequence([
            SKAction.group([
                SKAction.moveBy(x: 0, y: 60, duration: 0.5),
                SKAction.scale(to: 1.3, duration: 0.5),
            ]),
            SKAction.group([
                SKAction.moveBy(x: 0, y: -20, duration: 0.3),
                SKAction.scale(to: 1.0, duration: 0.3),
            ]),
        ])
        duck.run(victoryFlight)

        // Celebratory pixel particles — burst of stars/sparkles
        for i in 0..<20 {
            let star = SKShapeNode(circleOfRadius: CGFloat.random(in: 2...5))
            star.fillColor = [
                UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1),   // gold
                UIColor.white,
                UIColor(red: 1.0, green: 0.60, blue: 0.0, alpha: 1),   // orange
                UIColor(red: 0.42, green: 0.73, blue: 0.20, alpha: 1), // green
            ].randomElement()!
            star.strokeColor = .clear
            star.position = duck.position
            star.zPosition = 99

            let angle = CGFloat.random(in: 0...(2 * .pi))
            let distance = CGFloat.random(in: 80...200)
            let dx = cos(angle) * distance
            let dy = sin(angle) * distance
            let delay = Double(i) * 0.03

            addChild(star)

            star.run(SKAction.sequence([
                SKAction.wait(forDuration: delay),
                SKAction.group([
                    SKAction.moveBy(x: dx, y: dy, duration: 0.8),
                    SKAction.fadeOut(withDuration: 0.8),
                    SKAction.scale(to: 0.1, duration: 0.8),
                ]),
                SKAction.removeFromParent(),
            ]))
        }

        // Golden flash
        let flash = SKSpriteNode(color: UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 0.4),
                                 size: self.size)
        flash.position = CGPoint(x: size.width / 2, y: size.height / 2)
        flash.zPosition = 500
        addChild(flash)
        flash.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.5),
            SKAction.removeFromParent(),
        ]))

        // Trigger game over after celebration
        run(SKAction.sequence([
            SKAction.wait(forDuration: 1.5),
            SKAction.run { [weak self] in
                guard let self else { return }
                self.phase = .gameOver
                self.gameDelegate?.gameDidWinBotLadder(score: self.score)
            }
        ]))
    }

    // MARK: - Reset

    func resetGame() {
        pipeLayer.removeAllChildren()
        pipeLayer.isPaused = false
        groundLayer.isPaused = false
        backgroundLayer.isPaused = false
        foregroundLayer.isPaused = false

        pipeIndex = 0
        pipeTimer = 0
        lastUpdate = 0
        score = 0
        botScore = 0
        currentPipeSpeed = GK.pipeSpeed
        botPipesPassed.removeAll()
        phase = .ready

        let newSeed = Int.random(in: 1...999999)
        prng = SeededRandom(seed: newSeed)
        gapPositions = prng.generateGapPositions()

        // Reset progressive difficulty
        difficulty.reset()

        // Clear power-up state
        activePowerUps.removeAll()
        removeShieldVisual()
        removeGhostGlow()
        shieldCooldown = false
        pendingPowerUpKind = nil
        powerUpSpawner.reset()

        // Reset bread collectibles
        breadCollected = 0

        // Reset bot ladder win guard
        botLadderWinTriggered = false

        // Item 2: Safe optional chaining for duck
        guard let duck else { return }

        // Reparent duck back into worldNode if it was moved to scene root during death
        if duck.parent === self {
            duck.removeFromParent()
            worldNode.addChild(duck)
        }

        duck.position = CGPoint(x: GK.duckStartX, y: GK.duckStartY)
        duck.zRotation = 0
        duck.alpha = 1.0
        duck.zPosition = 40  // restore original z after death bump
        duck.setScale(1.0)

        // Restore base physics body
        let body = SKPhysicsBody(circleOfRadius: GK.duckRadius * 0.80)
        body.categoryBitMask = GK.duckCategory
        body.contactTestBitMask = GK.pipeCategory | GK.groundCategory | GK.powerUpCategory | GK.breadCategory
        body.collisionBitMask = GK.groundCategory | GK.pipeCategory
        body.allowsRotation = false
        body.restitution = 0
        body.linearDamping = 0
        body.usesPreciseCollisionDetection = true
        body.isDynamic = false
        body.velocity = .zero
        duck.physicsBody = body

        worldNode.setScale(1.0)  // Reset zoom from death effect
        worldNode.position = .zero  // Reset shake offset

        // Reset gravity to base
        physicsWorld.gravity = CGVector(dx: 0, dy: GK.gravity / 60)

        let float = SKAction.sequence([
            SKAction.moveBy(x: 0, y: 10, duration: 0.5),
            SKAction.moveBy(x: 0, y: -10, duration: 0.5)
        ])
        duck.run(SKAction.repeatForever(float), withKey: "float")
        startWingAnimation()
        updateScore()

        // Clean up death vignette if still present
        deathVignette?.removeFromParent()
        deathVignette = nil

        if mode == .vsBot {
            botDuck?.removeFromParent()
            setupBotDuck()
            updateBotScoreHUD()
        } else if mode == .headToHead {
            updateBotScoreHUD()
        }
    }

    // MARK: - Difficulty Tier UI

    private func showTierChangeLabel(tier: DifficultyTier) {
        guard tier != .easy else { return }

        let label = SKLabelNode(fontNamed: GK.pixelFontName)
        label.text = "\(tier.displayName)!"
        label.fontSize = 24
        label.zPosition = 300
        label.position = CGPoint(x: GK.worldWidth / 2, y: GK.worldHeight / 2 + 80)

        switch tier {
        case .medium:
            label.fontColor = UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1)
        case .hard:
            label.fontColor = UIColor(red: 1.0, green: 0.6, blue: 0.0, alpha: 1)
        case .expert:
            label.fontColor = UIColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1)
        default:
            label.fontColor = .white
        }

        hudLayer.addChild(label)

        let scaleUp = SKAction.scale(to: 1.3, duration: 0.15)
        let scaleBack = SKAction.scale(to: 1.0, duration: 0.1)
        let hold = SKAction.wait(forDuration: 0.8)
        let fadeOut = SKAction.fadeOut(withDuration: 0.3)

        label.run(SKAction.sequence([
            scaleUp, scaleBack, hold, fadeOut,
            SKAction.removeFromParent()
        ]))

        Haptic.milestone()
    }

    // MARK: - Power-Up System

    /// Attaches a collectible power-up node to a pipe at the gap center.
    private func addPowerUpCollectible(to pipeNode: SKNode, gapY: CGFloat, kind: PowerUpKind) {
        let collectible = SKNode()
        collectible.name = "powerUp_\(kind.rawValue)"
        collectible.position = CGPoint(x: 0, y: gapY)
        collectible.zPosition = 30

        // Emoji visual
        let emoji = SKLabelNode(text: kind.emoji)
        emoji.fontSize = PowerUpKind.collectibleSize
        emoji.verticalAlignmentMode = .center
        emoji.horizontalAlignmentMode = .center
        collectible.addChild(emoji)

        // Glow ring
        let glow = SKShapeNode(circleOfRadius: PowerUpKind.collectibleSize * 0.7)
        glow.fillColor = kind.glowColor.withAlphaComponent(0.25)
        glow.strokeColor = kind.glowColor.withAlphaComponent(0.6)
        glow.lineWidth = 1.5
        glow.zPosition = -1
        collectible.addChild(glow)

        // Pulse animation
        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.15, duration: 0.4),
            SKAction.scale(to: 0.9, duration: 0.4),
        ])
        collectible.run(SKAction.repeatForever(pulse))

        // Physics
        collectible.physicsBody = SKPhysicsBody(circleOfRadius: PowerUpKind.collectibleSize * 0.6)
        collectible.physicsBody?.isDynamic = false
        collectible.physicsBody?.categoryBitMask = GK.powerUpCategory
        collectible.physicsBody?.contactTestBitMask = GK.duckCategory
        collectible.physicsBody?.collisionBitMask = 0

        pipeNode.addChild(collectible)
    }

    /// Called when the duck contacts a power-up collectible node.
    private func collectPowerUp(node: SKNode) {
        guard let name = node.name, name.hasPrefix("powerUp_") else { return }
        let kindStr = String(name.dropFirst("powerUp_".count))
        guard let kind = PowerUpKind(rawValue: kindStr) else { return }

        node.removeFromParent()

        showPowerUpCollectedLabel(kind: kind)
        activatePowerUp(kind: kind)

        Haptic.score()

        // Play appropriate sound: positive power-ups get .powerUp, negative get .debuff
        if kind.isPositive {
            SoundManager.shared.play(.powerUp)
        } else {
            SoundManager.shared.play(.debuff)
        }
    }

    /// Activates a power-up effect.
    private func activatePowerUp(kind: PowerUpKind) {
        let pipeCountKinds: Set<PowerUpKind> = [.breadMagnet, .pipeExpander, .pipeSqueeze]
        let powerUp = ActivePowerUp(
            kind: kind,
            startTime: lastUpdate,
            remainingPipes: pipeCountKinds.contains(kind) ? 5 : nil
        )
        activePowerUps.append(powerUp)

        switch kind {
        case .shield:
            addShieldVisual()
        case .ghostDuck:
            activateGhostDuck()
        default:
            break
        }
    }

    /// Deactivates an expired power-up and removes its visual effects.
    private func deactivatePowerUp(_ powerUp: ActivePowerUp) {
        switch powerUp.kind {
        case .shield:
            removeShieldVisual()
        case .ghostDuck:
            deactivateGhostDuck()
        default:
            break
        }
    }

    /// Expires finished power-ups each frame.
    private func tickPowerUps(currentTime: TimeInterval) {
        var expired: [ActivePowerUp] = []
        activePowerUps.removeAll { powerUp in
            if powerUp.isExpired(currentTime: currentTime) {
                expired.append(powerUp)
                return true
            }
            return false
        }
        for powerUp in expired {
            deactivatePowerUp(powerUp)
        }
    }

    // MARK: Shield Visual

    private func addShieldVisual() {
        guard shieldNode == nil, let duck else { return }
        let shield = SKShapeNode(circleOfRadius: GK.duckRadius * 1.5)
        shield.strokeColor = UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 0.8)
        shield.fillColor = UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 0.15)
        shield.lineWidth = 2.5
        shield.zPosition = 1
        shield.name = "shieldRing"
        duck.addChild(shield)
        shieldNode = shield

        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.1, duration: 0.5),
            SKAction.scale(to: 0.95, duration: 0.5),
        ])
        shield.run(SKAction.repeatForever(pulse))
    }

    private func removeShieldVisual() {
        shieldNode?.removeFromParent()
        shieldNode = nil
    }

    private func hasActiveShield() -> Bool {
        activePowerUps.contains { $0.kind == .shield }
    }

    private func consumeShield() {
        activePowerUps.removeAll { $0.kind == .shield }
        removeShieldVisual()
        shieldCooldown = true

        // Reset cooldown after 0.5s so repeated contacts don't kill immediately
        run(SKAction.sequence([
            SKAction.wait(forDuration: 0.5),
            SKAction.run { [weak self] in
                self?.shieldCooldown = false
            }
        ]), withKey: "shieldCooldown")

        Haptic.score()
        SoundManager.shared.play(.powerUp)

        // Visual: golden burst on duck
        guard let duck else { return }
        let burst = SKShapeNode(circleOfRadius: GK.duckRadius * 2)
        burst.fillColor = UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 0.5)
        burst.strokeColor = .clear
        burst.zPosition = 2
        duck.addChild(burst)
        burst.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.3),
            SKAction.removeFromParent()
        ]))

        // Duck blinks briefly to show invincibility
        let blink = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.3, duration: 0.1),
            SKAction.fadeAlpha(to: 1.0, duration: 0.1),
        ])
        duck.run(SKAction.repeat(blink, count: 3), withKey: "shieldBlink")
    }

    // MARK: Ghost Duck Visual

    private func activateGhostDuck() {
        guard let duck else { return }

        // Semi-transparent duck
        duck.alpha = 0.4

        // Disable pipe collision while ghost is active
        duck.physicsBody?.contactTestBitMask = GK.groundCategory | GK.powerUpCategory | GK.breadCategory
        duck.physicsBody?.collisionBitMask = GK.groundCategory

        // Add subtle white glow behind duck
        guard ghostGlowNode == nil else { return }
        let glow = SKShapeNode(circleOfRadius: GK.duckRadius * 1.8)
        glow.fillColor = UIColor(white: 1.0, alpha: 0.15)
        glow.strokeColor = UIColor(white: 1.0, alpha: 0.3)
        glow.lineWidth = 1.5
        glow.zPosition = -1
        glow.name = "ghostGlow"

        let pulse = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.08, duration: 0.6),
            SKAction.fadeAlpha(to: 0.2, duration: 0.6),
        ])
        glow.run(SKAction.repeatForever(pulse))

        duck.addChild(glow)
        ghostGlowNode = glow
    }

    private func deactivateGhostDuck() {
        guard let duck else { return }

        // Restore full opacity
        duck.alpha = 1.0

        // Re-enable pipe collisions
        duck.physicsBody?.contactTestBitMask = GK.pipeCategory | GK.groundCategory | GK.powerUpCategory | GK.breadCategory
        duck.physicsBody?.collisionBitMask = GK.groundCategory | GK.pipeCategory

        // Remove glow
        removeGhostGlow()
    }

    private func removeGhostGlow() {
        ghostGlowNode?.removeFromParent()
        ghostGlowNode = nil
    }

    // MARK: Power-Up Collected Label

    private func showPowerUpCollectedLabel(kind: PowerUpKind) {
        guard let duck else { return }

        let container = SKNode()
        container.position = CGPoint(x: duck.position.x, y: duck.position.y + 30)
        container.zPosition = 300

        let emoji = SKLabelNode(text: kind.emoji)
        emoji.fontSize = 28
        emoji.verticalAlignmentMode = .center
        emoji.position = CGPoint(x: 0, y: 12)
        container.addChild(emoji)

        let name = SKLabelNode(fontNamed: GK.pixelFontName)
        name.text = kind.displayName
        name.fontSize = 10
        name.fontColor = kind.isPositive
            ? .white
            : UIColor(red: 1.0, green: 0.5, blue: 0.5, alpha: 1)
        name.verticalAlignmentMode = .center
        name.position = CGPoint(x: 0, y: -8)
        container.addChild(name)

        worldNode.addChild(container)

        let floatUp = SKAction.moveBy(x: 0, y: 60, duration: 0.8)
        let fadeOut = SKAction.fadeOut(withDuration: 0.8)
        container.run(SKAction.sequence([
            SKAction.group([floatUp, fadeOut]),
            SKAction.removeFromParent()
        ]))
    }

    // MARK: - Floating Score Popups (Item 5)

    private func spawnFloatingScorePopup(isMilestone: Bool) {
        guard let duck else { return }

        // Milestones get a fresh node (rare, so allocation is acceptable).
        // Regular +1 points reuse the pre-allocated pool to avoid per-frame addChild/removeFromParent.
        let popup: SKLabelNode
        if isMilestone {
            let fresh = SKLabelNode(fontNamed: GK.pixelFontName)
            fresh.text = "+5★"
            fresh.fontSize = 18
            fresh.fontColor = UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0)
            fresh.zPosition = 300
            fresh.position = CGPoint(x: duck.position.x + 20, y: duck.position.y + 15)
            worldNode.addChild(fresh)
            let floatUp = SKAction.moveBy(x: 0, y: 50, duration: 0.6)
            let fadeOut = SKAction.fadeOut(withDuration: 0.6)
            let scaleUp = SKAction.scale(to: 1.3, duration: 0.2)
            let scaleBack = SKAction.scale(to: 1.0, duration: 0.4)
            fresh.run(SKAction.sequence([
                SKAction.group([floatUp, fadeOut, SKAction.sequence([scaleUp, scaleBack])]),
                SKAction.removeFromParent()
            ]))
            return
        }

        guard !scorePopupPool.isEmpty else { return }
        popup = scorePopupPool[scorePopupPoolIndex % scorePopupPool.count]
        scorePopupPoolIndex += 1

        popup.removeAllActions()
        popup.text = "+1"
        popup.fontSize = 14
        popup.fontColor = .white
        popup.alpha = 1.0
        popup.setScale(1.0)
        popup.isHidden = false
        popup.position = CGPoint(x: duck.position.x + 20, y: duck.position.y + 15)

        let floatUp = SKAction.moveBy(x: 0, y: 50, duration: 0.6)
        let fadeOut = SKAction.fadeOut(withDuration: 0.6)
        let scaleUp = SKAction.scale(to: 1.1, duration: 0.2)
        let scaleBack = SKAction.scale(to: 1.0, duration: 0.4)
        popup.run(SKAction.sequence([
            SKAction.group([floatUp, fadeOut, SKAction.sequence([scaleUp, scaleBack])]),
            SKAction.run { popup.isHidden = true }
        ]))
    }

    // MARK: - Night Sky Stars (Item 9)

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

    // MARK: - First-Launch Tutorial (Item 8)

    private func showTutorialIfNeeded() {
        let key = "hasSeenTutorial"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)

        let overlay = SKNode()
        overlay.zPosition = 400
        overlay.name = "tutorialOverlay"

        // Semi-transparent backdrop
        let backdrop = SKSpriteNode(color: UIColor(white: 0, alpha: 0.35), size: self.size)
        backdrop.position = CGPoint(x: size.width / 2, y: size.height / 2)
        overlay.addChild(backdrop)

        // Pixel hand icon (simple tap indicator)
        let hand = SKLabelNode(text: "👆")
        hand.fontSize = 48
        hand.position = CGPoint(x: size.width / 2, y: size.height / 2 - 20)

        // Animated tapping motion
        let tapDown = SKAction.moveBy(x: 0, y: -12, duration: 0.2)
        let tapUp = SKAction.moveBy(x: 0, y: 12, duration: 0.2)
        let tapSeq = SKAction.sequence([tapDown, tapUp, SKAction.wait(forDuration: 0.3)])
        hand.run(SKAction.repeatForever(tapSeq))
        overlay.addChild(hand)

        // "TAP TO FLAP" text with pulse
        let label = SKLabelNode(fontNamed: GK.pixelFontName)
        label.text = "TAP TO FLAP"
        label.fontSize = 16
        label.fontColor = .white
        label.position = CGPoint(x: size.width / 2, y: size.height / 2 + 50)

        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.1, duration: 0.4),
            SKAction.scale(to: 0.95, duration: 0.4),
        ])
        label.run(SKAction.repeatForever(pulse))
        overlay.addChild(label)

        addChild(overlay)
        tutorialOverlay = overlay

        // Auto-dismiss after 2 seconds
        run(SKAction.sequence([
            SKAction.wait(forDuration: 2.0),
            SKAction.run { [weak self] in
                self?.dismissTutorial()
            }
        ]), withKey: "tutorialAutoDismiss")
    }

    private func dismissTutorial() {
        guard let overlay = tutorialOverlay, !tutorialDismissed else { return }
        tutorialDismissed = true
        removeAction(forKey: "tutorialAutoDismiss")
        overlay.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.2),
            SKAction.removeFromParent()
        ]))
        tutorialOverlay = nil
    }
}

// MARK: - Sky Theme (Item 9)

enum SkyTheme: String, CaseIterable {
    case day
    case sunset
    case night

    var backgroundColor: UIColor {
        switch self {
        case .day:    return UIColor(red: 0.35, green: 0.65, blue: 0.90, alpha: 1)
        case .sunset: return UIColor(red: 0.85, green: 0.45, blue: 0.25, alpha: 1)
        case .night:  return UIColor(red: 0.08, green: 0.10, blue: 0.22, alpha: 1)
        }
    }

    var gradientColors: [Color] {
        switch self {
        case .day:
            return [
                Color(red: 0.22, green: 0.50, blue: 0.85),
                Color(red: 0.58, green: 0.80, blue: 0.94),
                Color(red: 0.78, green: 0.92, blue: 0.97),
            ]
        case .sunset:
            return [
                Color(red: 0.15, green: 0.10, blue: 0.30),
                Color(red: 0.65, green: 0.25, blue: 0.40),
                Color(red: 0.95, green: 0.55, blue: 0.20),
                Color(red: 1.0, green: 0.80, blue: 0.35),
            ]
        case .night:
            return [
                Color(red: 0.02, green: 0.02, blue: 0.08),
                Color(red: 0.06, green: 0.08, blue: 0.18),
                Color(red: 0.12, green: 0.15, blue: 0.30),
            ]
        }
    }
}
