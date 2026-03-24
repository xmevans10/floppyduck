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

    /// Bot/opponent score — delegates to BotController when available.
    var botScore: Int { botController?.score ?? 0 }

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

    // Controllers
    private var parallax: ParallaxManager!
    private var botController: BotController?
    private var powerUpCtrl: PowerUpController!

    // Duck (Item 2: optional safety)
    private var duck: SKSpriteNode?
    private var duckTextures: [SKTexture] = []

    // Score (Item 2: optional safety)
    private var scoreLabel: SKLabelNode?
    private var scoreShadow: SKLabelNode?
    private var scoreOutlines: [SKLabelNode] = []

    // Ground tile width (used by ground physics only; visual tiles owned by ParallaxManager)
    private let groundTileWidth: CGFloat = GK.worldWidth * 2

    // Pipe spawning
    private var pipeTimer: TimeInterval = 0
    private var lastUpdate: TimeInterval = 0

    // Progressive difficulty
    private let difficulty = DifficultyManager()
    private var currentPipeSpeed: CGFloat = GK.pipeSpeed

    // Bread collectibles
    private var breadCollected: Int = 0

    /// Public accessor for views to display bread count.
    var totalBreadCollected: Int { breadCollected }

    // Achievement tracking — per-game power-up stats
    private(set) var shieldsUsed: Int = 0
    private(set) var ghostPipesPhased: Int = 0
    private(set) var magnetBreadCollected: Int = 0
    private(set) var debuffScoreAtStart: Int? = nil  // score when a debuff activated

    // Sky theme (Item 9)
    private let backgroundTheme: BackgroundTheme

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

    // Bread "+1" popup pool — same pattern as scorePopupPool
    private var breadPopupPool: [SKLabelNode] = []
    private var breadPopupPoolIndex: Int = 0

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
        hudLayer.zPosition = 1000   // Ensure HUD always renders above worldNode (pipes, duck, etc.)
        addChild(hudLayer)

        // Parallax: sky gradient, clouds, hills, trees, ground tiles, details, stars
        parallax = ParallaxManager(
            backgroundLayer: backgroundLayer,
            groundLayer: groundLayer,
            foregroundLayer: foregroundLayer,
            theme: backgroundTheme
        )
        parallax.setup()

        setupGroundPhysics()
        setupDuck()
        setupHUD()

        // Power-up controller
        powerUpCtrl = PowerUpController(
            worldNode: worldNode,
            pipeLayer: pipeLayer,
            duck: duck,
            difficulty: difficulty
        )
        powerUpCtrl.labelParentOverride = self
        powerUpCtrl.onPowerUpCollected = { [weak self] kind in
            guard let self else { return }
            if !kind.isPositive && self.debuffScoreAtStart == nil {
                self.debuffScoreAtStart = self.score
            }
        }
        powerUpCtrl.onShieldConsumed = { [weak self] in
            self?.shieldsUsed += 1
        }

        // Bot controller (vsBot = sprite + AI, headToHead = score HUD only)
        if mode == .vsBot || mode == .headToHead {
            let bc = BotController(worldNode: worldNode, hudLayer: hudLayer)
            if mode == .vsBot {
                bc.setup(skin: playerSkin, difficulty: botDiff)
            }
            bc.setupScoreHUD(mode: mode, opponentName: opponentName)
            bc.onScoreChanged = { [weak self] newScore in
                self?.gameDelegate?.botDidScore(newScore)
            }
            botController = bc
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

    // MARK: - Ground Physics (visual ground tiles owned by ParallaxManager)

    private func setupGroundPhysics() {
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

    // MARK: - Duck (skin-aware, tighter hitbox)

    private func setupDuck() {
        duckTextures = (0...2).map { factory.skinDuckTexture(skin: playerSkin, wingPhase: $0) }

        let sprite = SKSpriteNode(texture: duckTextures[1], size: playerSkin.spriteSize)
        sprite.position = CGPoint(x: GK.duckStartX, y: GK.duckStartY)
        sprite.zPosition = 40

        sprite.physicsBody = SKPhysicsBody(circleOfRadius: GK.duckRadius * 0.68)
        sprite.physicsBody?.categoryBitMask = GK.duckCategory
        sprite.physicsBody?.contactTestBitMask = GK.pipeCategory | GK.groundCategory | GK.powerUpCategory | GK.breadCategory
        // Only collide with ground — pipe contacts trigger game over via didBegin(_:)
        // but must NOT physically push the duck (causes progressive leftward drift).
        sprite.physicsBody?.collisionBitMask = GK.groundCategory
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

        // Bot/opponent score HUD is now managed by BotController
        // (created in didMove after this method)

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

        // Pre-allocate bread "+1" popup pool (avoids per-collection SKLabelNode allocs)
        breadPopupPool = (0..<4).map { _ in
            let node = SKLabelNode(fontNamed: GK.pixelFontName)
            node.text = "+1"
            node.fontSize = 12
            node.fontColor = UIColor(red: 0.85, green: 0.68, blue: 0.30, alpha: 1)
            node.zPosition = 300
            node.isHidden = true
            worldNode.addChild(node)
            return node
        }
        breadPopupPoolIndex = 0
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

    /// Multiplayer-only update hook used by GameContainerView polling.
    func setOpponentScore(_ score: Int) {
        guard mode == .headToHead else { return }
        botController?.setScore(max(0, score))
    }

    // MARK: - Pipes

    private func spawnPipe() {
        guard pipeIndex < gapPositions.count else { return }
        let gapY = gapPositions[pipeIndex]
        let currentPipeIndex = pipeIndex
        pipeIndex += 1

        let effectiveGap = powerUpCtrl.effectivePipeGap

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

        // No SKAction for horizontal movement — update() drives all pipe-layer
        // nodes at currentPipeSpeed so speed changes apply instantly to all.
        pipeLayer.addChild(pipeNode)

        // Spawn pending power-up collectible between pipes (free-floating in pipeLayer)
        if let kind = powerUpCtrl.consumePendingKind() {
            spawnPowerUpCollectible(afterPipeX: pipeNode.position.x, gapY: gapY, gapHeight: effectiveGap, kind: kind)
        }

        // Spawn bread collectibles between pipes (~60% chance)
        if CGFloat.random(in: 0...1) < 0.6 {
            spawnBreadGroup(afterPipeX: GK.worldWidth + GK.pipeWidth, gapY: gapY)
        }
    }

    // MARK: - Power-Up Collectible Spawning

    /// Spawns a collectible power-up somewhere in the open space between pipes.
    /// Positioning logic lives in GameScene (knows about pipe layout); the
    /// PowerUpController handles activation, effects, and lifecycle.
    private func spawnPowerUpCollectible(afterPipeX: CGFloat, gapY: CGFloat, gapHeight: CGFloat, kind: PowerUpKind) {
        let spacing = max(currentPipeSpeed * CGFloat(GK.pipeSpawnInterval), GK.pipeWidth * 2)
        let xOffset = CGFloat.random(in: (spacing * 0.22)...(spacing * 0.78))

        let minY = GK.groundHeight + 48
        let maxY = GK.worldHeight - 52
        let gapInset = min(30, max(18, gapHeight * 0.18))
        let gapBottom = max(minY, gapY - gapHeight / 2 + gapInset)
        let gapTop = min(maxY, gapY + gapHeight / 2 - gapInset)

        let y: CGFloat
        if Bool.random(), gapBottom < gapTop {
            y = CGFloat.random(in: gapBottom...gapTop)
        } else {
            y = CGFloat.random(in: minY...maxY)
        }

        let collectible = makePowerUpCollectible(kind: kind)
        collectible.position = CGPoint(x: afterPipeX + xOffset, y: y)
        pipeLayer.addChild(collectible)
    }

    private func makePowerUpCollectible(kind: PowerUpKind) -> SKNode {
        let collectible = SKNode()
        collectible.name = "powerUp_\(kind.rawValue)"
        collectible.zPosition = 30

        // Pixel icon visual
        let iconTexture = PixelIconFactory.shared.skTexture(for: kind.pixelIcon)
        let iconSprite = SKSpriteNode(texture: iconTexture)
        iconSprite.setScale(0.8)
        collectible.addChild(iconSprite)

        // Glow ring — pre-rendered texture instead of SKShapeNode
        let glowTex = TextureFactory.shared.glowCircleTexture(
            radius: PowerUpKind.collectibleSize * 0.7,
            color: kind.glowColor
        )
        let glow = SKSpriteNode(texture: glowTex)
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

        return collectible
    }

    // MARK: - Bread Collectibles

    /// Spawns 1–3 bread slices between the current pipe and the next expected pipe position.
    private func spawnBreadGroup(afterPipeX: CGFloat, gapY: CGFloat) {
        let breadCount = Int.random(in: 1...3)
        let spacing = currentPipeSpeed * CGFloat(GK.pipeSpawnInterval)
        let minBreadY = GK.groundHeight + 40
        let maxBreadY = GK.worldHeight * 0.80

        for i in 0..<breadCount {
            let xOffset = CGFloat.random(in: (spacing * 0.25)...(spacing * 0.75))
            let breadX = afterPipeX + xOffset + CGFloat(i) * 20
            let breadY = CGFloat.random(in: minBreadY...maxBreadY)

            let breadTexture = PixelIconFactory.shared.skTexture(for: .bread)
            let breadNode = SKSpriteNode(texture: breadTexture)
            breadNode.setScale(0.8)  // Bug #7 fix: larger bread for visibility
            breadNode.position = CGPoint(x: breadX, y: breadY)
            breadNode.zPosition = 25
            breadNode.name = "bread"

            // Physics body for collection
            breadNode.physicsBody = SKPhysicsBody(circleOfRadius: 10)
            breadNode.physicsBody?.isDynamic = false
            breadNode.physicsBody?.categoryBitMask = GK.breadCategory
            breadNode.physicsBody?.contactTestBitMask = GK.duckCategory
            breadNode.physicsBody?.collisionBitMask = 0

            // Gentle bob animation (Y-axis only — horizontal movement driven by update())
            let bob = SKAction.sequence([
                SKAction.moveBy(x: 0, y: 5, duration: 0.4),
                SKAction.moveBy(x: 0, y: -5, duration: 0.4),
            ])
            breadNode.run(SKAction.repeatForever(bob))

            // Horizontal movement handled by update() loop — no SKAction.moveBy.
            pipeLayer.addChild(breadNode)
        }
    }

    /// Called when duck contacts a bread node.
    private func collectBread(node: SKNode) {
        node.removeFromParent()
        breadCollected += 1
        SoundManager.shared.play(.score)
        Haptic.score()

        // Track bread collected while magnet is active (for achievement)
        if powerUpCtrl.isBreadMagnetActive {
            magnetBreadCollected += 1
        }

        // "+1" bread popup — uses pre-allocated pool to avoid per-collection allocs
        guard let duck, !breadPopupPool.isEmpty else { return }
        let popup = breadPopupPool[breadPopupPoolIndex % breadPopupPool.count]
        breadPopupPoolIndex += 1

        popup.removeAllActions()
        popup.alpha = 1.0
        popup.isHidden = false
        popup.setScale(1.0)
        popup.position = CGPoint(x: duck.position.x + 28, y: duck.position.y + 28)

        let floatUp = SKAction.moveBy(x: 0, y: 35, duration: 0.5)
        let fadeOut = SKAction.fadeOut(withDuration: 0.5)
        popup.run(SKAction.sequence([
            SKAction.group([floatUp, fadeOut]),
            SKAction.run { popup.isHidden = true }
        ]))
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

        let impulse = powerUpCtrl.effectiveFlapImpulse

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
            botController?.startPlaying()
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

        // --- Power-up tick: expire finished effects, update speed modifier ---
        powerUpCtrl.update(dt: dt, currentTime: currentTime)

        // --- Difficulty-driven gravity (with power-up modifiers) ---
        physicsWorld.gravity = CGVector(dx: 0, dy: powerUpCtrl.effectiveGravity / 60)

        // --- Pipe speed (grace period handled by PowerUpController) ---
        currentPipeSpeed = powerUpCtrl.effectivePipeSpeed

        // --- GhostDuck visual: maintain alpha while active ---
        powerUpCtrl.applyGhostAlpha()

        // --- BreadMagnet: attract nearby bread each frame ---
        if powerUpCtrl.isBreadMagnetActive {
            powerUpCtrl.applyBreadMagnetEffect()
        }

        // Spawn pipes
        pipeTimer += dt
        if pipeTimer >= GK.pipeSpawnInterval {
            pipeTimer -= GK.pipeSpawnInterval
            spawnPipe()
        }

        // Move all pipe-layer children (pipes + bread) at the current speed.
        // This replaces per-node SKAction.moveBy so speed changes from difficulty
        // ramp and power-ups apply instantly to EVERY node on screen.
        let dx = currentPipeSpeed * CGFloat(dt)
        for child in pipeLayer.children {
            child.position.x -= dx
            if child.position.x < -(GK.pipeWidth * 2) {
                child.removeFromParent()
            }
        }

        // Parallax scrolling (ground tiles, details, clouds, hills, trees)
        parallax.update(dt: dt)

        // Item 2: Duck rotation with safe optional + horizontal position clamp
        if let duck, let vy = duck.physicsBody?.velocity.dy {
            let flapRef = difficulty.effectiveFlapImpulse
            let target = vy > 0
                ? min(vy / flapRef * 0.4, 0.4)
                : max(vy / 400, -CGFloat.pi / 2)
            duck.zRotation += (target - duck.zRotation) * 0.10

            // Pin horizontal position — duck should only move vertically.
            // Prevents any residual horizontal drift from physics resolution.
            if duck.position.x != GK.duckStartX {
                duck.position.x = GK.duckStartX
                duck.physicsBody?.velocity.dx = 0
            }
        }

        if mode == .vsBot {
            botController?.update(
                dt: dt,
                pipeNodes: pipeLayer.children,
                activePowerUps: powerUpCtrl.activePowerUps,
                effectivePipeGap: difficulty.effectivePipeGap
            )
        }
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

            // --- Power-up: spawn check + decrement pipe-count trackers ---
            powerUpCtrl.onPipeScored(currentScore: score, tier: difficulty.currentTier)

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
                powerUpCtrl.collectPowerUp(node: powerUpNode)
            }
            return
        }

        // --- Pipe / ground collision ---
        if phase == .playing {
            // GhostDuck: ignore pipe collisions entirely
            let isPipeHit = masks.contains(GK.pipeCategory)
            if isPipeHit && powerUpCtrl.isGhostActive {
                ghostPipesPhased += 1
                return
            }

            // Shield absorbs pipe collisions (not ground)
            if isPipeHit && (powerUpCtrl.hasActiveShield || powerUpCtrl.isShieldOnCooldown) {
                if powerUpCtrl.hasActiveShield {
                    powerUpCtrl.consumeShield(scene: self)
                }
                return
            }
            die()
        }
    }

    // MARK: - Death

    private func die() {
        phase = .dead
        // Item 6: Enhanced death haptic
        Haptic.enhancedDeath()
        SoundManager.shared.play(.death)
        SoundManager.shared.stopPlayMusic()

        guard let duck else { return }

        // Bump duck above ground layers so it doesn't clip behind them
        duck.zPosition = 60

        // Restore duck alpha and remove power-up visuals (ghost glow, shield ring)
        powerUpCtrl.cleanupDuckVisuals()

        // Freeze all scrolling layers — parallax stops immediately on death
        pipeLayer.isPaused = true
        groundLayer.isPaused = true
        backgroundLayer.isPaused = true
        foregroundLayer.isPaused = true

        // Item 6: Brief slowmo pause (freeze scene for death impact)
        self.isPaused = true
        DispatchQueue.main.asyncAfter(deadline: .now() + GK.Animation.deathFreezeDuration) { [weak self] in
            self?.isPaused = false
        }

        // Item 6: Camera zoom-in
        let zoomIn = SKAction.scale(to: GK.Animation.zoomInScale, duration: GK.Animation.zoomInDuration)
        let zoomOut = SKAction.scale(to: 1.0, duration: GK.Animation.zoomOutDuration)
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
        let vignette = SKSpriteNode(color: UIColor(red: 0.8, green: 0.0, blue: 0.0, alpha: 0.45), size: self.size)
        vignette.position = CGPoint(x: size.width / 2, y: size.height / 2)
        vignette.zPosition = 499
        vignette.alpha = 0
        addChild(vignette)
        deathVignette = vignette
        vignette.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.2),
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

        // --- Death particle burst: 12–15 pixel-art particles radiating outward ---
        spawnDeathParticles(at: duck.position)

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
        let fallDuration = max(GK.Animation.deathFallMinDuration,
                               min(Double(fallDistance / GK.Animation.deathFallSpeed),
                                   GK.Animation.deathFallMaxDuration))
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
                // Hide the SpriteKit HUD so the score doesn't bleed through
                // the SwiftUI game-over overlay (Bug #10)
                self.hudLayer.run(SKAction.fadeOut(withDuration: 0.2))
                self.phase = .gameOver
                self.gameDelegate?.gameDidEnd(score: self.score)
            }
        ]))
    }

    // MARK: - Death Particle Burst

    /// Spawns 12–15 small pixel-art particle nodes radiating outward from the
    /// duck's position. Uses duck palette colors (green, brown, gray) to match
    /// the existing 8-bit visual style.
    private func spawnDeathParticles(at position: CGPoint) {
        let particleCount = Int.random(in: 12...15)

        let colors: [UIColor] = [
            UIColor(GK.Colors.duckGreen),
            UIColor(GK.Colors.duckGreen),
            UIColor(GK.Colors.duckBrown),
            UIColor(GK.Colors.duckBrown),
            UIColor(GK.Colors.duckGray),
            .white,
        ]

        for _ in 0..<particleCount {
            let size = CGFloat.random(in: 3...7)
            let particle = SKSpriteNode(color: colors.randomElement()!, size: CGSize(width: size, height: size))
            particle.position = position
            particle.zPosition = 450  // above duck but below flash

            let angle = CGFloat.random(in: 0...(2 * .pi))
            let distance = CGFloat.random(in: 40...100)
            let dx = cos(angle) * distance
            let dy = sin(angle) * distance

            worldNode.addChild(particle)

            particle.run(SKAction.sequence([
                SKAction.group([
                    SKAction.moveBy(x: dx, y: dy, duration: 0.5),
                    SKAction.fadeOut(withDuration: 0.5),
                    SKAction.rotate(byAngle: CGFloat.random(in: -2...2), duration: 0.5),
                ]),
                SKAction.removeFromParent(),
            ]))
        }
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
        // PERF: Uses pre-rendered glow textures instead of 20 SKShapeNodes
        let celebColors: [UIColor] = [
            UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1),   // gold
            UIColor.white,
            UIColor(red: 1.0, green: 0.60, blue: 0.0, alpha: 1),   // orange
            UIColor(red: 0.42, green: 0.73, blue: 0.20, alpha: 1), // green
        ]
        for i in 0..<20 {
            let color = celebColors[i % celebColors.count]
            let radius = CGFloat.random(in: 2...5)
            let tex = TextureFactory.shared.glowCircleTexture(radius: radius, color: color)
            let star = SKSpriteNode(texture: tex)
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
                self.hudLayer.run(SKAction.fadeOut(withDuration: 0.2))
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

        // Restore HUD visibility (hidden during game-over transition)
        hudLayer.alpha = 1.0

        pipeIndex = 0
        pipeTimer = 0
        lastUpdate = 0
        score = 0
        currentPipeSpeed = GK.pipeSpeed
        phase = .ready

        let newSeed = Int.random(in: 1...999999)
        prng = SeededRandom(seed: newSeed)
        gapPositions = prng.generateGapPositions()

        // Reset progressive difficulty
        difficulty.reset()

        // Clear power-up state (also resets speed modifier)
        powerUpCtrl.reset()

        // Reset bread collectibles & per-game achievement counters
        breadCollected = 0
        shieldsUsed = 0
        ghostPipesPhased = 0
        magnetBreadCollected = 0
        debuffScoreAtStart = nil

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
        let body = SKPhysicsBody(circleOfRadius: GK.duckRadius * 0.68)
        body.categoryBitMask = GK.duckCategory
        body.contactTestBitMask = GK.pipeCategory | GK.groundCategory | GK.powerUpCategory | GK.breadCategory
        body.collisionBitMask = GK.groundCategory   // Ground only — no pipe collision (prevents drift)
        body.allowsRotation = false
        body.restitution = 0
        body.linearDamping = 0
        body.usesPreciseCollisionDetection = true
        body.isDynamic = false
        body.velocity = .zero
        duck.physicsBody = body

        // Re-bind duck reference in PowerUpController after physics body reset
        powerUpCtrl.setDuck(duck)

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

        // Reset bot controller
        if mode == .vsBot {
            botController?.reset(skin: playerSkin)
        } else if mode == .headToHead {
            botController?.setScore(0)
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

    // MARK: - Floating Score Popups (Item 5)

    private func spawnFloatingScorePopup(isMilestone: Bool) {
        guard let duck else { return }

        // All popups show "+1" (score increments by 1 per pipe).
        // Milestones (every 5) get a gold, larger treatment.
        // Regular points reuse the pre-allocated pool to avoid per-frame allocs.
        let popup: SKLabelNode
        if isMilestone {
            let fresh = SKLabelNode(fontNamed: GK.pixelFontName)
            fresh.text = "+1"
            fresh.fontSize = 18
            fresh.fontColor = UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0)
            fresh.zPosition = 300
            fresh.position = CGPoint(x: duck.position.x + 30, y: duck.position.y + 28)
            worldNode.addChild(fresh)
            let floatUp = SKAction.moveBy(x: 0, y: 50, duration: 0.6)
            let fadeOut = SKAction.fadeOut(withDuration: 0.6)
            let scaleUp = SKAction.scale(to: 1.4, duration: 0.15)
            let scaleBack = SKAction.scale(to: 1.0, duration: 0.45)
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
        popup.position = CGPoint(x: duck.position.x + 30, y: duck.position.y + 28)

        let floatUp = SKAction.moveBy(x: 0, y: 50, duration: 0.6)
        let fadeOut = SKAction.fadeOut(withDuration: 0.6)
        let scaleUp = SKAction.scale(to: 1.1, duration: 0.2)
        let scaleBack = SKAction.scale(to: 1.0, duration: 0.4)
        popup.run(SKAction.sequence([
            SKAction.group([floatUp, fadeOut, SKAction.sequence([scaleUp, scaleBack])]),
            SKAction.run { popup.isHidden = true }
        ]))
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
        let handTexture = PixelIconFactory.shared.skTexture(for: .tapHand, pixelScale: 5.0)
        let hand = SKSpriteNode(texture: handTexture)
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
