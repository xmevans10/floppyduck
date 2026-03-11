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
    private let foregroundLayer = SKNode()   // Item 10: parallax bushes/flowers
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

    // Pipe spawning
    private var pipeTimer: TimeInterval = 0
    private var lastUpdate: TimeInterval = 0

    // Progressive difficulty
    private var currentPipeSpeed: CGFloat = GK.pipeSpeed

    // Parallax layers
    private var clouds: [SKSpriteNode] = []
    private var hills: [SKSpriteNode] = []
    private var trees: [SKSpriteNode] = []
    private var bushes: [SKSpriteNode] = []     // Item 10: foreground parallax

    // Sky theme (Item 9)
    private let skyTheme: SkyTheme
    private var starNodes: [SKShapeNode] = []

    // Tutorial (Item 8)
    private var tutorialOverlay: SKNode?
    private var tutorialDismissed: Bool = false

    // Death effects (Item 6)
    private var deathVignette: SKSpriteNode?

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
        // Item 9: Random sky theme per game
        self.skyTheme = SkyTheme.allCases.randomElement() ?? .day
        super.init(size: CGSize(width: GK.worldWidth, height: GK.worldHeight))
        self.scaleMode = .aspectFill
        self.gapPositions = prng.generateGapPositions()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    // MARK: - Scene Setup

    override func didMove(to view: SKView) {
        // Item 9: Apply sky theme color
        let bgColor = skyTheme.backgroundColor
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
        worldNode.addChild(foregroundLayer)   // Item 10
        addChild(hudLayer)

        setupBackground()
        setupClouds()
        setupHills()
        setupTrees()
        setupForegroundBushes()   // Item 10
        setupGround()
        setupDuck()
        setupHUD()

        if skyTheme == .night {
            setupStars()   // Item 9
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
        // Item 9: Use theme-aware sky gradient
        let skyNode = SKSpriteNode(color: .clear,
                                    size: CGSize(width: GK.worldWidth, height: GK.worldHeight))
        skyNode.position = CGPoint(x: GK.worldWidth / 2, y: GK.worldHeight / 2)
        skyNode.zPosition = -100

        // Create gradient effect using the sky theme colors
        let gradientTex = createSkyGradientTexture(theme: skyTheme)
        skyNode.texture = gradientTex
        backgroundLayer.addChild(skyNode)
    }

    /// Renders a vertical gradient texture for the sky theme.
    private func createSkyGradientTexture(theme: SkyTheme) -> SKTexture {
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
        for _ in 0..<5 {
            let scale = CGFloat.random(in: 0.6...1.2)
            let cloud = SKSpriteNode(texture: cloudTex,
                                      size: CGSize(width: 80 * scale, height: 35 * scale))
            cloud.position = CGPoint(
                x: CGFloat.random(in: 0...GK.worldWidth),
                y: CGFloat.random(in: (GK.worldHeight * 0.55)...(GK.worldHeight - 40))
            )
            cloud.alpha = CGFloat.random(in: 0.5...0.8)
            cloud.zPosition = -90
            backgroundLayer.addChild(cloud)
            clouds.append(cloud)
        }
    }

    private func setupHills() {
        let hillTex = factory.hillsTexture()
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
        let treeTex = factory.treesTexture()
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

    // MARK: - Duck (skin-aware)

    private func setupDuck() {
        duckTextures = (0...2).map { factory.skinDuckTexture(skin: playerSkin, wingPhase: $0) }

        let sprite = SKSpriteNode(texture: duckTextures[1], size: playerSkin.spriteSize)
        sprite.position = CGPoint(x: GK.duckStartX, y: GK.duckStartY)
        sprite.zPosition = 40

        sprite.physicsBody = SKPhysicsBody(circleOfRadius: GK.duckRadius * 0.85)
        sprite.physicsBody?.categoryBitMask = GK.duckCategory
        sprite.physicsBody?.contactTestBitMask = GK.pipeCategory | GK.groundCategory
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
        let wingAction = SKAction.animate(with: duckTextures, timePerFrame: 0.12)
        duck?.run(SKAction.repeatForever(wingAction), withKey: "wings")
    }

    // MARK: - Bot Ghost Duck

    private func setupBotDuck() {
        botTextures = (0...2).map { factory.skinBotDuckTexture(skin: playerSkin, wingPhase: $0) }

        let bot = SKSpriteNode(texture: botTextures[1],
                               size: playerSkin.spriteSize)
        bot.position = CGPoint(x: GK.duckStartX, y: GK.duckStartY)
        bot.zPosition = 35

        let wingAction = SKAction.animate(with: botTextures, timePerFrame: 0.12)
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
        // Item 1: scoreBacking circle removed — score already has outline + shadow for legibility

        // 4 cardinal outlines (N/S/E/W) + 4 diagonal — 8 total
        let outlineOffsets: [(CGFloat, CGFloat)] = [
            (0, -3), (0, 3), (-3, 0), (3, 0),
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

        let shadow = SKLabelNode(fontNamed: GK.pixelFontName)
        shadow.fontSize = 36
        shadow.fontColor = UIColor(red: 0.15, green: 0.25, blue: 0.08, alpha: 0.8)
        shadow.position = CGPoint(x: GK.worldWidth / 2 + 3, y: GK.worldHeight - 79)
        shadow.zPosition = 200
        shadow.text = "0"
        shadow.verticalAlignmentMode = .center
        shadow.horizontalAlignmentMode = .center
        hudLayer.addChild(shadow)
        scoreShadow = shadow

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
        scoreShadow?.text = text
        for outline in scoreOutlines {
            outline.text = text
        }

        // Item 4: Accessibility — announce score changes
        UIAccessibility.post(notification: .announcement, argument: "Score: \(score)")
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

        let pipeNode = SKNode()
        pipeNode.position = CGPoint(x: GK.worldWidth + GK.pipeWidth, y: 0)
        pipeNode.zPosition = 20
        pipeNode.name = "pipe_\(currentPipeIndex)"

        // Bottom pipe
        let bottomH = gapY - GK.pipeGap / 2 - GK.groundHeight
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
        let topY = gapY + GK.pipeGap / 2
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
        scoreTrigger.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 2, height: GK.pipeGap))
        scoreTrigger.physicsBody?.isDynamic = false
        scoreTrigger.physicsBody?.categoryBitMask = GK.scoreCategory
        scoreTrigger.physicsBody?.contactTestBitMask = GK.duckCategory
        scoreTrigger.name = "scoreTrigger"
        pipeNode.addChild(scoreTrigger)

        let moveDistance = GK.worldWidth + GK.pipeWidth * 3
        let moveDuration = TimeInterval(moveDistance / currentPipeSpeed)
        pipeNode.run(SKAction.sequence([
            SKAction.moveBy(x: -moveDistance, y: 0, duration: moveDuration),
            SKAction.removeFromParent()
        ]))

        pipeLayer.addChild(pipeNode)
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
        duck.physicsBody?.velocity = CGVector(dx: 0, dy: GK.flapImpulse)
        Haptic.flap()
        SoundManager.shared.play(.flap)

        duck.removeAction(forKey: "wings")
        let flutter = SKAction.sequence([
            SKAction.setTexture(duckTextures[2]),
            SKAction.wait(forDuration: 0.06),
            SKAction.setTexture(duckTextures[0]),
            SKAction.wait(forDuration: 0.06),
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

        // Item 10: Foreground bushes scroll faster than ground (1.2x)
        let bushSpeed = GK.groundSpeed * 1.2
        for bush in bushes {
            bush.position.x -= bushSpeed * CGFloat(dt)
            if bush.position.x < -(GK.worldWidth * 2) {
                bush.position.x += GK.worldWidth * 4
            }
        }

        // Item 2: Duck rotation with safe optional
        if let duck, let vy = duck.physicsBody?.velocity.dy {
            let target = vy > 0
                ? min(vy / GK.flapImpulse * 0.4, 0.4)
                : max(vy / 400, -CGFloat.pi / 2)
            duck.zRotation += (target - duck.zRotation) * 0.15
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
                    let gapTop = gapY + GK.pipeGap / 2 - 5
                    let gapBottom = gapY - GK.pipeGap / 2 + 5
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
        bot.zRotation += (target - bot.zRotation) * 0.15
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

        if masks.contains(GK.scoreCategory) && masks.contains(GK.duckCategory) {
            bodies.first { $0.categoryBitMask == GK.scoreCategory }?.node?.removeFromParent()
            score += 1
            updateScore()
            Haptic.score()
            SoundManager.shared.play(.score)

            // Item 5: Floating score popup
            let isMilestone = score % 5 == 0
            spawnFloatingScorePopup(isMilestone: isMilestone)

            // Progressive speed ramp
            currentPipeSpeed = min(GK.pipeSpeedMax,
                                   GK.pipeSpeed + CGFloat(score) * GK.speedRampPerPipe)

            // Milestone haptic every 5 pipes
            if isMilestone {
                Haptic.milestone()
                SoundManager.shared.play(.milestone)
            }

            gameDelegate?.gameDidScore(score)

            // Check if bot ladder target score is reached — trigger win!
            if mode == .vsBot,
               let target = targetScore,
               score >= target {
                celebrateBotLadderWin()
            }

            return
        }

        if phase == .playing {
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

        // Bump duck above ground + bush layers so it doesn't clip behind them
        duck.zPosition = 60

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

        // Fix: Disable physics and use a scripted fall to prevent duck clipping through pipes.
        // Previously removed pipeCategory from collisionBitMask, which let the duck
        // ghost through pipes during the death fall.
        duck.physicsBody?.velocity = .zero
        duck.physicsBody?.isDynamic = false

        // Animate straight-down fall to ground level
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

        // Item 2: Safe optional chaining for duck
        guard let duck else { return }
        duck.position = CGPoint(x: GK.duckStartX, y: GK.duckStartY)
        duck.zRotation = 0
        duck.alpha = 1.0
        duck.zPosition = 40  // restore original z after death bump
        duck.physicsBody?.isDynamic = false
        duck.physicsBody?.velocity = .zero
        duck.physicsBody?.collisionBitMask = GK.groundCategory | GK.pipeCategory
        worldNode.setScale(1.0)  // Reset zoom from death effect

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

    // MARK: - Floating Score Popups (Item 5)

    private func spawnFloatingScorePopup(isMilestone: Bool) {
        guard let duck else { return }
        let popup = SKLabelNode(fontNamed: GK.pixelFontName)
        popup.text = isMilestone ? "+5★" : "+1"
        popup.fontSize = isMilestone ? 18 : 14
        popup.fontColor = isMilestone
            ? UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0)
            : UIColor.white
        popup.position = CGPoint(x: duck.position.x + 20, y: duck.position.y + 15)
        popup.zPosition = 300

        worldNode.addChild(popup)

        let floatUp = SKAction.moveBy(x: 0, y: 50, duration: 0.6)
        let fadeOut = SKAction.fadeOut(withDuration: 0.6)
        let scaleUp = SKAction.scale(to: isMilestone ? 1.3 : 1.1, duration: 0.2)
        let scaleBack = SKAction.scale(to: 1.0, duration: 0.4)

        popup.run(SKAction.sequence([
            SKAction.group([floatUp, fadeOut, SKAction.sequence([scaleUp, scaleBack])]),
            SKAction.removeFromParent()
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

    // MARK: - Foreground Parallax Bushes (Item 10)

    private func setupForegroundBushes() {
        for i in 0..<2 {
            let bushNode = SKSpriteNode(color: .clear,
                                         size: CGSize(width: GK.worldWidth * 2, height: 36))
            bushNode.anchorPoint = CGPoint(x: 0, y: 0)
            // Position base at ground top so bushes grow UP from grass. z=55 = above ground (50).
            bushNode.position = CGPoint(x: CGFloat(i) * GK.worldWidth * 2, y: GK.groundHeight - 6)
            bushNode.zPosition = 55

            let tex = renderBushTexture()
            bushNode.texture = tex
            foregroundLayer.addChild(bushNode)
            bushes.append(bushNode)
        }
    }

    /// Renders a pixel-art bush/flower strip texture.
    /// Texture origin (0,0) is top-left in UIKit → maps to TOP of sprite in SpriteKit.
    /// We draw upward (bushes at top of texture → top of sprite → visually above ground).
    private func renderBushTexture() -> SKTexture {
        let w = Int(GK.worldWidth * 2)
        let h = 36
        let size = CGSize(width: w, height: h)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let c = ctx.cgContext

            // Draw pixel bushes at random intervals — bottom of texture = base (grass level)
            var x = 0
            while x < w {
                let bushW = Int.random(in: 18...32)
                let bushH = Int.random(in: 14...24)
                let gap = Int.random(in: 20...40)

                let ps = 4  // pixel size for blocky look
                // y=0 is top of texture; bushes grow DOWN from top of texture
                // (since texture top = sprite top = farthest from ground)
                // So we draw from bottom: y = h - bushH to y = h
                let baseY = h - ps  // very bottom row

                // Bush body — slightly transparent so duck peeks through near ground
                let bodyColor = UIColor(red: 0.20, green: 0.48, blue: 0.14, alpha: 0.8)
                c.setFillColor(bodyColor.cgColor)

                // Rounded top → wide middle → narrowing base
                let topY = h - bushH
                c.fill(CGRect(x: x + ps * 2, y: topY, width: bushW - ps * 4, height: ps))
                c.fill(CGRect(x: x + ps, y: topY + ps, width: bushW - ps * 2, height: ps))
                c.fill(CGRect(x: x, y: topY + ps * 2, width: bushW, height: bushH - ps * 3))
                // Slight base narrowing
                c.fill(CGRect(x: x + ps, y: baseY, width: bushW - ps * 2, height: ps))

                // Highlight on top of bush (lighter green)
                let hlColor = UIColor(red: 0.32, green: 0.62, blue: 0.20, alpha: 0.6)
                c.setFillColor(hlColor.cgColor)
                c.fill(CGRect(x: x + ps * 2, y: topY + ps, width: bushW - ps * 4, height: ps))

                // Occasional flower on top
                if Int.random(in: 0...2) == 0 {
                    let flowerColors: [UIColor] = [
                        UIColor(red: 1.0, green: 0.35, blue: 0.35, alpha: 1.0),
                        UIColor(red: 1.0, green: 0.85, blue: 0.2, alpha: 1.0),
                        UIColor(red: 0.80, green: 0.40, blue: 0.85, alpha: 1.0),
                    ]
                    let fc = flowerColors.randomElement()!
                    c.setFillColor(fc.cgColor)
                    let fx = x + Int.random(in: ps...(max(ps + 1, bushW - ps * 2)))
                    c.fill(CGRect(x: fx, y: topY - ps, width: ps + 2, height: ps + 2))
                }

                x += bushW + gap
            }
        }
        let tex = SKTexture(image: image)
        tex.filteringMode = .nearest
        return tex
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
