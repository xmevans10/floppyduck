import SpriteKit
import SwiftUI
import GameKit

// MARK: - Performance Record Types

/// Cached pipe record — maintained at spawn/cleanup instead of scanning pipeLayer.children.
/// Eliminates repeated SpriteKit child-tree iteration with string-name checks every frame.
struct ActivePipeRecord {
    weak var node: SKNode?
    let gapCenterY: CGFloat    // Y of the scoreTrigger center (for BotController AI targeting)
    let name: String            // pipe name (e.g. "pipe_3") for score dedup in didBegin
}

/// Cached bread record — maintained at spawn/collect/cleanup instead of scanning pipeLayer.children.
/// Eliminates per-frame string-name checks and userData dictionary lookups.
struct ActiveBreadRecord {
    weak var node: SKNode?
    let baseY: CGFloat          // Original Y position for absolute sine-bob
}

/// Cached power-up collectible record — maintained at spawn/collect/cleanup.
/// Without explicit tracking, power-up nodes in pipeLayer are stationary
/// (only activePipes and activeBreads are moved in the update loop).
struct ActivePowerUpRecord {
    weak var node: SKNode?
}

// MARK: - Game Phase

enum GamePhase {
    case versusIntro   // MK-style VS splash (bot/live matches only)
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

@MainActor
final class GameScene: SKScene, SKPhysicsContactDelegate {

    // MARK: - Properties

    weak var gameDelegate: GameSceneDelegate?

    private(set) var phase: GamePhase = .ready
    var isReadyToStart: Bool = false
    private(set) var score: Int = 0

    /// Bot/opponent score — delegates to BotController when available.
    var botScore: Int { botController?.score ?? 0 }

    private var prng: SeededRandom
    private var gapPositions: [CGFloat] = []
    private var pipeIndex: Int = 0

    private let factory = TextureFactory.shared
    private let mode: GameMode
    private let powerUpsEnabled: Bool
    private let playerSkin: DuckSkin
    private let botSkin: DuckSkin?
    private let botDiff: BotDifficulty?
    private let opponentName: String?
    private let targetScore: Int?
    private var opponentDuckSkin: DuckSkin?

    // Layers
    private let worldNode = SKNode()
    private let backgroundLayer = SKNode()
    private let pipeLayer = SKNode()
    private let groundLayer = SKNode()
    private let foregroundLayer = SKNode()   // Enhanced ground decorations (grass blades, pebbles)

    // PERF: Cached records — maintained at spawn/collect/cleanup to avoid per-frame
    // pipeLayer.children scans, string-name checks, and userData dictionary lookups.
    private var activePipes: [ActivePipeRecord] = []
    private var activeBreads: [ActiveBreadRecord] = []
    private var activePowerUpCollectibles: [ActivePowerUpRecord] = []
    private let hudLayer = SKNode()

    // Controllers
    private var parallax: ParallaxManager!
    private var botController: BotController?
    private var battleRoyaleGhostRenderer: GhostDuckRenderer?
    private var powerUpCtrl: PowerUpController!

    // Duck (Item 2: optional safety)
    private var duck: SKSpriteNode?
    private var duckTextures: [SKTexture] = []

    // Player-only gravity field (power-up modifiers applied only to player)
    private var playerGravityField: SKFieldNode?

    // Score (Item 2: optional safety)
    private var scoreLabel: SKLabelNode?
    private var scoreOutlines: [SKLabelNode] = []

    // Pipe spawning
    private var pipeTimer: TimeInterval = 0
    private var lastUpdate: TimeInterval = 0

#if DEBUG
    private var debugFrameTimes: [Double] = []
    /// Only log frames when `-DebugFrameLog` is passed as a launch argument.
    /// Keeps local debug play smooth by default.
    private var debugFrameLogEnabled: Bool = {
        ProcessInfo.processInfo.arguments.contains("-DebugFrameLog")
            || ProcessInfo.processInfo.environment["DEBUG_FRAME_LOG"] == "1"
    }()
#endif

    private let performanceSessionId = UUID().uuidString
    private var performanceStartedAt: TimeInterval = 0
    private var performanceLastSampleAt: TimeInterval = 0
    private var performanceFrameCount: Int = 0
    private var performanceIntervalSum: TimeInterval = 0
    private var performanceWorstInterval: TimeInterval = 0
    private var performanceSlowFrames: Int = 0
    private var performanceDroppedFrames: Int = 0
    private var performanceSevereFrames: Int = 0
    private var performanceWindowFrameCount: Int = 0
    private var performanceWindowIntervalSum: TimeInterval = 0
    private var performanceWindowWorstInterval: TimeInterval = 0
    private var performanceWindowSlowFrames: Int = 0
    private var performanceWindowDroppedFrames: Int = 0
    private var performanceWindowSevereFrames: Int = 0
    private var performanceSummarySent: Bool = false

    private static let performanceSampleInterval: TimeInterval = 10
    private static let slowFrameThreshold: TimeInterval = 1.0 / 50.0
    private static let droppedFrameThreshold: TimeInterval = 1.0 / 30.0
    private static let severeFrameThreshold: TimeInterval = 1.0 / 20.0

    // Tap-correlated performance counters (added to game-over summary)
    private var performanceTapCount: Int = 0
    private var performanceTapTimestamps: [TimeInterval] = []  // last 20 tap times
    private var performanceSlowFramesAfterTap: Int = 0
    private var performanceDroppedFramesAfterTap: Int = 0
    /// Frames following a tap within this window are counted as tap-correlated.
    private static let tapCorrelationWindow: TimeInterval = 1.0 / 15.0  // ~66ms / ~4 frames

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
    private var fogOverlay: SKSpriteNode?

    // Bot ladder win guard
    private var botLadderWinTriggered = false

    // Floating score popup pool (pre-allocated to avoid per-point allocations)
    private var scorePopupPool: [SKLabelNode] = []
    private var scorePopupPoolIndex: Int = 0

    // Bread "+1" popup pool — same pattern as scorePopupPool
    private var breadPopupPool: [SKLabelNode] = []
    private var breadPopupPoolIndex: Int = 0

    // PERF: Cached gravity to avoid setting physicsWorld.gravity every frame
    private var lastAppliedGravity: CGFloat = 0

    // PERF: Running time for bread sine-bob (replaces per-node SKActions)
    private var breadBobTime: TimeInterval = 0

    // Track which pipes the player has scored from (dedup — triggers persist for bot too)
    private var playerPipesPassed: Set<String> = Set()

    // PERF: Pre-allocated flutter animation — reused every tap instead of
    // creating 7 new SKAction objects per flap (eliminates ~7 allocs/tap).
    private lazy var cachedFlutterAction: SKAction = {
        guard duckTextures.count >= 3 else {
            return SKAction.run { [weak self] in self?.startWingAnimation() }
        }
        let flutter = SKAction.sequence([
            SKAction.setTexture(duckTextures[2]),
            SKAction.wait(forDuration: 0.05),
            SKAction.setTexture(duckTextures[0]),
            SKAction.wait(forDuration: 0.05),
            SKAction.setTexture(duckTextures[1]),
        ])
        let restartWings = SKAction.run { [weak self] in
            self?.startWingAnimation()
        }
        return SKAction.sequence([flutter, restartWings])
    }()

    // MARK: - Init

    init(seed: Int = Int.random(in: 1...999999),
         mode: GameMode = .classic,
         powerUpsEnabled: Bool = true,
         skin: DuckSkin = .classic,
         botSkin: DuckSkin? = nil,
         botDifficulty: BotDifficulty? = nil,
         opponentName: String? = nil,
         targetScore: Int? = nil) {
        self.prng = SeededRandom(seed: seed)
        self.mode = mode
        self.powerUpsEnabled = powerUpsEnabled
        self.playerSkin = skin
        self.botSkin = botSkin
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

        // Item 11: Set active skin for per-skin sound variants
        SoundManager.shared.setActiveSkin(playerSkin)
        // Set active theme so music matches the selected background
        SoundManager.shared.setActiveTheme(backgroundTheme)

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

        // Player-only gravity field — applies power-up gravity modifiers
        // (dizzyDuck, heavyDuck, featherweight) only to the player duck.
        // The bot duck is excluded via fieldBitMask = 0 in BotController.
        let field = SKFieldNode.linearGravityField(withVector: vector_float3(0, 1, 0))
        field.strength = 0
        field.categoryBitMask = GK.playerGravityFieldCategory
        field.isEnabled = true
        worldNode.addChild(field)
        playerGravityField = field

        setupGroundPhysics()
        setupDuck()
        setupHUD()

        // Reset frame clock when returning from background so the first
        // update(currentTime:) frame doesn't see a multi-second delta.
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.lastUpdate = 0
        }

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
        powerUpCtrl.onFoggyStateChanged = { [weak self] isActive in
            guard let self else { return }
            if isActive {
                self.showFogOverlay()
            } else {
                self.removeFogOverlay()
            }
        }
        powerUpCtrl.onMysteryBoxCollected = { [weak self] resolvedKind, completion in
            self?.showMysteryBoxAnimation(resolvedKind: resolvedKind, completion: completion)
        }
        powerUpCtrl.setDuckTextures(duckTextures)

        // In bot-ladder mode, doublePoints is suppressed (score stays 1:1 with pipes)
        if mode == .vsBot {
            powerUpCtrl.excludedKinds = [.doublePoints]
        }

        // Classic (no power-ups) mode: exclude all power-up kinds
        if !powerUpsEnabled {
            powerUpCtrl.excludedKinds = Set(PowerUpKind.allCases)
        }

        // Bot controller (vsBot = sprite + AI, headToHead = score HUD only)
        if mode == .vsBot || mode == .headToHead {
            let bc = BotController(worldNode: worldNode, hudLayer: hudLayer)
            if mode == .vsBot {
                // In bot-ladder mode, pass targetScore as deathScore so the
                // bot deterministically dies at its ceiling score.
                // Use the bot's own skin if provided, otherwise fall back to player skin.
                let effectiveBotSkin = botSkin ?? playerSkin
                bc.setup(skin: effectiveBotSkin, difficulty: botDiff, deathScore: targetScore)
            }
            bc.setupScoreHUD(mode: mode, opponentName: opponentName)
            bc.onScoreChanged = { [weak self] newScore in
                self?.gameDelegate?.botDidScore(newScore)
            }
            bc.onBotDied = { [weak self] in
                guard let self, self.mode == .vsBot, self.targetScore != nil else { return }
                // Only celebrate a win if the bot actually reached its ceiling
                // score (became doomed).  A premature collision — e.g. the bot
                // hitting a pipe before reaching targetScore — shouldn't award
                // a ladder win because the player hasn't proven they can survive
                // that many pipes.
                guard self.botController?.reachedCeiling == true else { return }
                self.celebrateBotLadderWin()
            }
            botController = bc
        }

        if mode == .battleRoyale {
            battleRoyaleGhostRenderer = GhostDuckRenderer(worldNode: worldNode)
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
        groundBody.physicsBody?.contactTestBitMask = GK.duckCategory | GK.botCategory
        worldNode.addChild(groundBody)

        // Ceiling — physical barrier only, no death contact
        let ceiling = SKNode()
        ceiling.position = CGPoint(x: GK.worldWidth / 2, y: GK.worldHeight + 20)
        ceiling.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: GK.worldWidth * 2, height: 2))
        ceiling.physicsBody?.isDynamic = false
        ceiling.physicsBody?.categoryBitMask = GK.ceilingCategory
        ceiling.physicsBody?.contactTestBitMask = 0
        ceiling.physicsBody?.collisionBitMask = GK.duckCategory | GK.botCategory
        worldNode.addChild(ceiling)
    }

    // MARK: - Duck (skin-aware, tighter hitbox)

    private func setupDuck() {
        duckTextures = (0...2).map { factory.skinDuckTexture(skin: playerSkin, wingPhase: $0) }

        let sprite = SKSpriteNode(texture: duckTextures[1], size: playerSkin.spriteSize)
        sprite.position = CGPoint(x: GK.duckStartX, y: GK.duckStartY)
        sprite.zPosition = 40

        sprite.physicsBody = SKPhysicsBody(circleOfRadius: GK.duckRadius * 0.72)
        sprite.physicsBody?.categoryBitMask = GK.duckCategory
        sprite.physicsBody?.contactTestBitMask = GK.pipeCategory | GK.groundCategory | GK.powerUpCategory
        // Only collide with ground — pipe contacts trigger game over via didBegin(_:)
        // but must NOT physically push the duck (causes progressive leftward drift).
        sprite.physicsBody?.collisionBitMask = GK.groundCategory | GK.ceilingCategory
        sprite.physicsBody?.fieldBitMask = GK.playerGravityFieldCategory   // player-only gravity field
        sprite.physicsBody?.allowsRotation = false
        sprite.physicsBody?.restitution = 0
        sprite.physicsBody?.linearDamping = 0
        // PERF: Standard collision detection is sufficient with the 72% hitbox radius.
        // usesPreciseCollisionDetection = true was triggering expensive swept tests every frame.

        worldNode.addChild(sprite)
        duck = sprite
        startWingAnimation()
    }

    // Item 2: Safe optional chaining
    private func startWingAnimation() {
        guard !duckTextures.isEmpty else { return }
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

    weak var gameKitSession: GameKitSession?

    /// Multiplayer-only update hook used by GameContainerView polling.
    func setOpponentScore(_ score: Int) {
        guard mode == .headToHead else { return }
        botController?.setScore(max(0, score))
    }

    func setGhostPosition(x: CGFloat, y: CGFloat, velY: CGFloat, rotation: CGFloat, wingPhase: Int) {
        botController?.setGhostPosition(x: x, y: y, velY: velY, rotation: rotation, wingPhase: wingPhase)
    }

    func spawnGhostDuck() {
        guard mode == .headToHead, botController?.sprite == nil else { return }
        let skin = opponentDuckSkin ?? playerSkin
        botController?.setup(skin: skin)
    }

    func setGhostDuckSkin(_ skin: DuckSkin) {
        opponentDuckSkin = skin
        botController?.setup(skin: skin)
    }

    func sendGhostPosition() {
        guard let duck = duck, let session = gameKitSession, session.connected else { return }
        let pos = GhostDuckPosition(
            x: Float(duck.position.x),
            y: Float(duck.position.y),
            velY: Float(duck.physicsBody?.velocity.dy ?? 0),
            rotation: Float(duck.zRotation),
            wingPhase: currentWingPhase
        )
        session.sendPosition(pos)
    }

    func battleRoyaleSnapshot() -> (y: CGFloat, rotation: CGFloat, wingPhase: Int)? {
        guard let duck else { return nil }
        return (duck.position.y, duck.zRotation, Int(currentWingPhase))
    }

    func updateBattleRoyaleGhosts(_ ghosts: [BattleRoyaleGhost]) {
        battleRoyaleGhostRenderer?.update(ghosts)
    }

    private var currentWingPhase: UInt8 {
        guard let duck else { return 1 }
        let tex = duck.texture
        if tex == duckTextures[0] { return 0 }
        if tex == duckTextures[2] { return 2 }
        return 1
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
        // PERF: Merged pipe body + cap into a single compound physics body per side
        // (2 bodies per pipe pair instead of 4 — halves physics contact evaluations).
        let bottomH = gapY - effectiveGap / 2 - GK.groundHeight
        if bottomH > 0 {
            let bottomBody = SKSpriteNode(
                texture: factory.pipeTexture(height: bottomH, skinOverride: PipeSkinManager.shared.selectedSkin),
                size: CGSize(width: GK.pipeWidth, height: bottomH)
            )
            bottomBody.anchorPoint = CGPoint(x: 0.5, y: 0)
            bottomBody.position = CGPoint(x: 0, y: GK.groundHeight)
            pipeNode.addChild(bottomBody)

            let bottomCap = SKSpriteNode(
                texture: factory.pipeCapTexture(skinOverride: PipeSkinManager.shared.selectedSkin),
                size: CGSize(width: GK.pipeWidth + 10, height: 30)
            )
            bottomCap.anchorPoint = CGPoint(x: 0.5, y: 0)
            bottomCap.position = CGPoint(x: 0, y: GK.groundHeight + bottomH - 4)
            pipeNode.addChild(bottomCap)

            // Single compound physics body covering pipe shaft + cap
            let shaftBody = SKPhysicsBody(rectangleOf: CGSize(width: GK.pipeWidth - 4, height: bottomH),
                                          center: CGPoint(x: 0, y: GK.groundHeight + bottomH / 2))
            let capBody = SKPhysicsBody(rectangleOf: CGSize(width: GK.pipeWidth + 4, height: 26),
                                        center: CGPoint(x: 0, y: GK.groundHeight + bottomH - 4 + 15))
            let bottomCompound = SKPhysicsBody(bodies: [shaftBody, capBody])
            bottomCompound.isDynamic = false
            bottomCompound.categoryBitMask = GK.pipeCategory
            bottomCompound.contactTestBitMask = GK.duckCategory | GK.botCategory
            pipeNode.physicsBody = bottomCompound
        }

        // Top pipe
        let topY = gapY + effectiveGap / 2
        let topH = GK.worldHeight - topY
        if topH > 0 {
            let topBody = SKSpriteNode(
                texture: factory.pipeTexture(height: topH, skinOverride: PipeSkinManager.shared.selectedSkin),
                size: CGSize(width: GK.pipeWidth, height: topH)
            )
            topBody.anchorPoint = CGPoint(x: 0.5, y: 1)
            topBody.position = CGPoint(x: 0, y: GK.worldHeight)
            pipeNode.addChild(topBody)

            let topCap = SKSpriteNode(
                texture: factory.pipeCapTexture(skinOverride: PipeSkinManager.shared.selectedSkin),
                size: CGSize(width: GK.pipeWidth + 10, height: 30)
            )
            topCap.anchorPoint = CGPoint(x: 0.5, y: 1)
            topCap.position = CGPoint(x: 0, y: topY + 4)
            pipeNode.addChild(topCap)

            // Single compound physics body covering pipe shaft + cap.
            // Only assign if pipeNode doesn't already have one from bottom;
            // otherwise merge into a second compound on a child node.
            let tShaftBody = SKPhysicsBody(rectangleOf: CGSize(width: GK.pipeWidth - 4, height: topH),
                                           center: CGPoint(x: 0, y: GK.worldHeight - topH / 2))
            let tCapBody = SKPhysicsBody(rectangleOf: CGSize(width: GK.pipeWidth + 4, height: 26),
                                         center: CGPoint(x: 0, y: topY + 4 - 15))
            let topCompound = SKPhysicsBody(bodies: [tShaftBody, tCapBody])
            topCompound.isDynamic = false
            topCompound.categoryBitMask = GK.pipeCategory
            topCompound.contactTestBitMask = GK.duckCategory | GK.botCategory

            // Merge top + bottom into one compound on the pipeNode
            if let existing = pipeNode.physicsBody {
                let merged = SKPhysicsBody(bodies: [existing, topCompound])
                merged.isDynamic = false
                merged.categoryBitMask = GK.pipeCategory
                merged.contactTestBitMask = GK.duckCategory | GK.botCategory
                pipeNode.physicsBody = merged
            } else {
                pipeNode.physicsBody = topCompound
            }
        }

        // Score trigger
        // Score trigger — detected by both player and bot via physics contacts.
        // Not removed on contact; dedup is handled via playerPipesPassed / BotController.pipesPassed sets.
        let scoreTrigger = SKNode()
        scoreTrigger.position = CGPoint(x: GK.pipeWidth / 2 + 10, y: gapY)
        scoreTrigger.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 2, height: effectiveGap))
        scoreTrigger.physicsBody?.isDynamic = false
        scoreTrigger.physicsBody?.categoryBitMask = GK.scoreCategory
        scoreTrigger.physicsBody?.contactTestBitMask = GK.duckCategory | GK.botCategory
        scoreTrigger.name = "scoreTrigger"
        pipeNode.addChild(scoreTrigger)

        // No SKAction for horizontal movement — update() drives all pipe-layer
        // nodes at currentPipeSpeed so speed changes apply instantly to all.
        pipeLayer.addChild(pipeNode)

        // PERF: Cache pipe record for O(1) lookup in update loop & Bot AI — avoids
        // scanning pipeLayer.children with string-name checks every frame.
        activePipes.append(ActivePipeRecord(node: pipeNode, gapCenterY: gapY, name: pipeNode.name ?? "pipe_\(currentPipeIndex)"))

        // Spawn pending power-up collectible between pipes (free-floating in pipeLayer)
        if let kind = powerUpCtrl.consumePendingKind() {
            spawnPowerUpCollectible(afterPipeX: pipeNode.position.x, gapY: gapY, gapHeight: effectiveGap, kind: kind)
        }

        // Spawn bread collectibles between pipes (~40% chance, reduced from 60%)
        if CGFloat.random(in: 0...1) < 0.4 {
            spawnBreadGroup(afterPipeX: GK.worldWidth + GK.pipeWidth, gapY: gapY, gapHeight: effectiveGap)
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

        // 75% in the pipe gap (flight corridor), 25% weighted toward gap region
        let y: CGFloat
        if CGFloat.random(in: 0...1) < 0.75, gapBottom < gapTop {
            y = CGFloat.random(in: gapBottom...gapTop)
        } else {
            let nearBottom = max(minY, gapY - gapHeight * 0.8)
            let nearTop = min(maxY, gapY + gapHeight * 0.8)
            if nearBottom < nearTop {
                y = CGFloat.random(in: nearBottom...nearTop)
            } else if gapBottom < gapTop {
                y = CGFloat.random(in: gapBottom...gapTop)
            } else {
                y = gapY  // fallback dead center
            }
        }

        let collectible = makePowerUpCollectible(kind: kind)
        collectible.position = CGPoint(x: afterPipeX + xOffset, y: y)
        pipeLayer.addChild(collectible)
        activePowerUpCollectibles.append(ActivePowerUpRecord(node: collectible))
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
        collectible.physicsBody = SKPhysicsBody(circleOfRadius: PowerUpKind.collectibleSize * 0.85)
        collectible.physicsBody?.isDynamic = false
        collectible.physicsBody?.categoryBitMask = GK.powerUpCategory
        collectible.physicsBody?.contactTestBitMask = GK.duckCategory
        collectible.physicsBody?.collisionBitMask = 0

        return collectible
    }

    // MARK: - Foggy Overlay

    private func showFogOverlay() {
        guard fogOverlay == nil else { return }
        let fog = SKSpriteNode(color: UIColor(red: 0.12, green: 0.12, blue: 0.16, alpha: 0.65), size: self.size)
        fog.position = CGPoint(x: size.width / 2, y: size.height / 2)
        fog.zPosition = 450   // above game content, below death overlay / HUD
        fog.alpha = 0
        addChild(fog)
        fogOverlay = fog
        fog.run(SKAction.fadeAlpha(to: 1.0, duration: 0.3))
    }

    private func removeFogOverlay() {
        guard let fog = fogOverlay else { return }
        fog.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.4),
            SKAction.removeFromParent()
        ]))
        fogOverlay = nil
    }

    // MARK: - Mystery Box Slot Animation

    /// Plays a compact slot-machine roulette near the top of the screen
    /// so it doesn't block gameplay. Cycles through power-up icons (fast → slow),
    /// lands on `resolvedKind`, fires `completion` instantly at reveal.
    private func showMysteryBoxAnimation(resolvedKind: PowerUpKind, completion: @escaping () -> Void) {
        let goldColor = UIColor(red: 0.96, green: 0.78, blue: 0.20, alpha: 1)
        // 25% smaller overall
        let pixelScale: CGFloat = 3.0
        let anchorY = size.height - 150

        // --- Slot window (gold border) ---
        let boxSize = CGSize(width: 58, height: 68)
        let boxBg = SKSpriteNode(color: goldColor, size: boxSize)
        boxBg.zPosition = 1

        // --- Inner dark face ---
        let innerSize = CGSize(width: 51, height: 60)
        let inner = SKSpriteNode(color: UIColor(red: 0.10, green: 0.10, blue: 0.14, alpha: 1), size: innerSize)
        inner.zPosition = 2

        // --- Icon sprite (cycled) ---
        let iconTexture = PixelIconFactory.shared.skTexture(for: .mysteryBox, pixelScale: pixelScale)
        let iconSprite = SKSpriteNode(texture: iconTexture)
        iconSprite.setScale(1.2)
        iconSprite.zPosition = 3

        // --- Container ---
        let container = SKNode()
        container.position = CGPoint(x: size.width / 2, y: anchorY)
        container.zPosition = 999
        container.addChild(boxBg)
        container.addChild(inner)
        container.addChild(iconSprite)
        container.alpha = 0
        hudLayer.addChild(container)

        // --- Show: drop-in from above ---
        container.setScale(0.6)
        container.run(SKAction.group([
            SKAction.fadeAlpha(to: 1.0, duration: 0.18),
            SKAction.sequence([
                SKAction.scale(to: 1.08, duration: 0.12),
                SKAction.scale(to: 0.94, duration: 0.08),
                SKAction.scale(to: 1.0, duration: 0.06),
            ]),
        ]))

        // --- Build cycling sequence ---
        let candidates = PowerUpKind.allCases.filter { $0 != .mysteryBox }
        let displayOrder = candidates.shuffled()
        var cycleTextures: [SKTexture] = []
        let fastFrames = 14
        let mediumFrames = 7
        let slowFrames = 5

        for i in 0..<fastFrames {
            cycleTextures.append(PixelIconFactory.shared.skTexture(for: displayOrder[i % displayOrder.count].pixelIcon, pixelScale: pixelScale))
        }
        for i in 0..<mediumFrames {
            cycleTextures.append(PixelIconFactory.shared.skTexture(for: displayOrder[i % displayOrder.count].pixelIcon, pixelScale: pixelScale))
        }
        for i in 0..<(slowFrames - 1) {
            cycleTextures.append(PixelIconFactory.shared.skTexture(for: displayOrder[i % displayOrder.count].pixelIcon, pixelScale: pixelScale))
        }
        cycleTextures.append(PixelIconFactory.shared.skTexture(for: resolvedKind.pixelIcon, pixelScale: pixelScale))

        // Build sequence with variable delays + SFX + haptics
        var actions: [SKAction] = []
        for (i, tex) in cycleTextures.enumerated() {
            let isFast = i < fastFrames
            let isMedium = i < fastFrames + mediumFrames && i >= fastFrames
            let delay: TimeInterval = isFast ? 0.06 : (isMedium ? 0.10 : 0.16)
            let isLast = i == cycleTextures.count - 1

            actions.append(SKAction.run { iconSprite.texture = tex })

            if !isLast {
                actions.append(SKAction.wait(forDuration: delay))
                // Tick SFX every 2nd frame + light haptic each tick
                if i % 2 == 0 {
                    actions.append(SKAction.run {
                        SoundManager.shared.play(.countTick)
                        Haptic.light()
                    })
                }
            }
        }

        // Reveal: flash + bounce + immediate activation + coin sound + haptic
        let revealFlash = SKAction.run {
            let flash = SKSpriteNode(color: goldColor.withAlphaComponent(0.4), size: innerSize)
            flash.position = .zero
            flash.zPosition = 5
            container.addChild(flash)
            flash.run(SKAction.sequence([
                SKAction.fadeOut(withDuration: 0.3),
                SKAction.removeFromParent()
            ]))
            iconSprite.run(SKAction.sequence([
                SKAction.scale(to: 1.6, duration: 0.12),
                SKAction.scale(to: 1.1, duration: 0.18),
            ]))
            SoundManager.shared.play(.coin)
            Haptic.medium()
            // Activate power-up immediately — no delay
            completion()
        }
        actions.append(revealFlash)

        // Dismiss after a brief hold so the player sees what they got
        let dismiss = SKAction.group([
            SKAction.fadeAlpha(to: 0.0, duration: 0.25),
            SKAction.scale(to: 0.5, duration: 0.25),
        ])
        let cleanup = SKAction.run {
            container.removeFromParent()
        }

        iconSprite.run(SKAction.sequence(actions))
        container.run(SKAction.sequence([
            SKAction.wait(forDuration: 2.2),
            dismiss,
            cleanup,
        ]))
    }

    // MARK: - Bread Collectibles

    /// Spawns 1–2 bread slices between the current pipe and the next expected pipe position.
    /// Bread Y is constrained to the pipe gap so it never visually overlaps pipes.
    private func spawnBreadGroup(afterPipeX: CGFloat, gapY: CGFloat, gapHeight: CGFloat) {
        let breadCount = Int.random(in: 1...2)
        let spacing = currentPipeSpeed * CGFloat(GK.pipeSpawnInterval)

        // Constrain bread Y to the open gap between pipes (with margin for bread size)
        let breadMargin: CGFloat = 14  // half bread visual size
        let minBreadY = max(GK.groundHeight + 40, gapY - gapHeight / 2 + breadMargin)
        let maxBreadY = min(GK.worldHeight * 0.80, gapY + gapHeight / 2 - breadMargin)
        guard minBreadY < maxBreadY else { return }  // gap too narrow for bread

        for i in 0..<breadCount {
            let xOffset = CGFloat.random(in: (spacing * 0.25)...(spacing * 0.75))
            let breadX = afterPipeX + xOffset + CGFloat(i) * 20
            let breadY = CGFloat.random(in: minBreadY...maxBreadY)

            // 7% chance: golden loaf worth 10 bread
            let isLoaf = CGFloat.random(in: 0...1) < PowerUpKind.loafChance
            let breadTexture = PixelIconFactory.shared.skTexture(for: isLoaf ? .loafBread : .bread)
            let breadNode = SKSpriteNode(texture: breadTexture)
            breadNode.setScale(isLoaf ? 0.9 : 0.8)  // loaf slightly larger
            breadNode.position = CGPoint(x: breadX, y: breadY)
            breadNode.zPosition = 25
            breadNode.name = isLoaf ? "loaf" : "bread"

            // Store base Y for absolute sine-bob in update() — no drift over time.
            breadNode.userData = breadNode.userData ?? NSMutableDictionary()
            breadNode.userData?["baseY"] = breadY
            if isLoaf { breadNode.userData?["loaf"] = true }

            // PERF: No physics body on bread — collection uses distance checks in
            // update() (eliminates ~6 physics bodies from the simulation per frame).
            // Bob animation is also driven from update() via sine wave instead of
            // per-node SKActions (eliminates ~6 action evaluations per frame).

            pipeLayer.addChild(breadNode)

            // PERF: Cache bread record — avoids per-frame string-name checks and
            // userData dictionary lookups in the update loop.
            activeBreads.append(ActiveBreadRecord(node: breadNode, baseY: breadY))
        }
    }

    /// Called when duck contacts a bread node.
    private func collectBread(node: SKNode) {
        node.removeFromParent()
        let isLoaf = node.userData?["loaf"] as? Bool == true
        let value = isLoaf ? PowerUpKind.loafBreadValue : 1
        breadCollected += value
        SoundManager.shared.play(.bread)
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
        popup.text = isLoaf ? "+\(PowerUpKind.loafBreadValue)" : "+1"
        popup.fontColor = isLoaf ? UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1) : .white
        popup.alpha = 1.0
        popup.isHidden = false
        popup.setScale(isLoaf ? 1.3 : 1.0)
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
            guard isReadyToStart else { break }
            startPlaying()
            flap()
        case .playing:
            flap()
        case .dead:
            // Quick retry — tap during death animation to skip game-over and restart instantly.
            // Disabled for head-to-head (match finalization required) and bot-ladder wins
            // (player is still tapping to stay alive when bot dies — grace period prevents
            // accidental restart before the win modal loads).
            guard mode != .headToHead else { break }
            guard !botLadderWinTriggered else { break }
            self.removeAllActions()
            duck?.removeAllActions()
            deathVignette?.removeFromParent()
            deathVignette = nil
            fogOverlay?.removeFromParent()
            fogOverlay = nil
            gameDelegate?.gameDidQuickRetry(score: score)
            resetGame()
        default:
            break
        }
    }

    // Item 2: Safe optional chaining for duck
    // PERF: Uses cachedFlutterAction — zero allocations per tap.
    func flap() {
        guard phase == .playing, let duck else { return }

        let impulse = powerUpCtrl.effectiveFlapImpulse
        duck.physicsBody?.velocity = CGVector(dx: 0, dy: impulse)
        Haptic.flap()
        SoundManager.shared.play(.flap)
        duck.removeAction(forKey: "wings")
        duck.run(cachedFlutterAction, withKey: "wings")

        // Track tap timing for post-game performance correlation
        performanceTapCount += 1
        performanceTapTimestamps.append(CACurrentMediaTime())
        if performanceTapTimestamps.count > 20 {
            performanceTapTimestamps.removeFirst()
        }
    }

    func startPlaying() {
        phase = .playing
        duck?.removeAction(forKey: "float")
        duck?.physicsBody?.isDynamic = true
        resetPerformanceTracking()

        if mode == .vsBot {
            botController?.startPlaying()
        }

#if DEBUG
        if debugFrameLogEnabled {
            let totalNodes = children.reduce(0) { $0 + $1.children.count + 1 }
            let midgroundNodes = parallax.debugScatteredCount()
            let physicsCount = countPhysicsBodies()
            print("[Scene] ▶️ GAME START — nodes:\(totalNodes) midground:\(midgroundNodes) physicsBodies:\(physicsCount) pipes:0 mode:\(mode.rawValue)")
        }
#endif

        gameDelegate?.gameDidStart()
    }

    // MARK: - Update Loop

    override func update(_ currentTime: TimeInterval) {
#if DEBUG
        let frameStart = debugFrameLogEnabled ? CACurrentMediaTime() : 0
        defer {
            if debugFrameLogEnabled {
                let elapsed = CACurrentMediaTime() - frameStart
                debugFrameTimes.append(elapsed)
                if debugFrameTimes.count >= 60 {
                    let avg = debugFrameTimes.reduce(0, +) / Double(debugFrameTimes.count)
                    let maxT = debugFrameTimes.max() ?? 0
                    let minT = debugFrameTimes.min() ?? 0

                    let totalNodes = children.reduce(0) { $0 + $1.children.count + 1 }
                    let pipeCount = activePipes.count
                    let fps = 1.0 / avg

                    print("[Scene] FPS:\(String(format: "%.1f", fps))  avg:\(String(format: "%.2f", avg*1000))ms  min:\(String(format: "%.2f", minT*1000))ms  max:\(String(format: "%.2f", maxT*1000))ms  nodes:\(totalNodes)  pipes:\(pipeCount)")

                    if maxT > 0.016 {
                        print("[Scene] ⚠️ SLOW FRAME: \(String(format: "%.2f", maxT*1000))ms — nodes:\(totalNodes) pipes:\(pipeCount)")
                    }
                    if maxT > 0.033 {
                        print("[Scene] 🔴 DROPPED FRAME: \(String(format: "%.2f", maxT*1000))ms (>30ms)")
                    }

                    debugFrameTimes.removeAll(keepingCapacity: true)
                }
            }
        }
#endif
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

        let rawDt = lastUpdate == 0 ? 0 : currentTime - lastUpdate
        recordPerformanceFrame(interval: rawDt, currentTime: currentTime)

        var dt = rawDt
        lastUpdate = currentTime

        // Cap delta time to prevent physics & spawning chaos when returning
        // from background — a large dt would spawn dozens of pipes and move
        // everything off-screen in a single frame.
        dt = min(dt, 1.0 / 30.0)

        // --- Power-up tick: expire finished effects, update speed modifier ---
        powerUpCtrl.update(dt: dt, currentTime: currentTime)

        // --- Gravity: apply base (no power-up effects) to physics world ---
        // Uses baseGravity so the bot is never affected by the player's
        // dizzyDuck / heavyDuck / featherweight power-ups.
        let baseG = powerUpCtrl.baseGravity
        if baseG != lastAppliedGravity {
            physicsWorld.gravity = CGVector(dx: 0, dy: baseG / 60)
            lastAppliedGravity = baseG
        }

        // Player-only power-up gravity modifier via SKFieldNode.
        // The field's categoryBitMask only matches the player duck's
        // fieldBitMask, so the bot is never affected.
        let gravityDelta = Float(powerUpCtrl.effectiveGravity - baseG) / 60
        playerGravityField?.strength = gravityDelta

        // --- Pipe speed (grace period handled by PowerUpController) ---
        currentPipeSpeed = powerUpCtrl.effectivePipeSpeed

        // --- GhostDuck visual: maintain alpha while active ---
        powerUpCtrl.applyGhostAlpha()

        // --- BreadMagnet: attract nearby bread using cached records ---
        if powerUpCtrl.isBreadMagnetActive {
            powerUpCtrl.applyBreadMagnetEffect(breadRecords: activeBreads)
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
        //
        // PERF: Bread collection uses distance checks here instead of physics bodies
        // (eliminates ~6 physics bodies + contact evaluations from the simulation).
        // Bread bob uses a shared sine wave instead of per-node SKActions.
        let dx = currentPipeSpeed * CGFloat(dt)
        breadBobTime += dt
        let bobPhase = CGFloat(sin(breadBobTime * 7.5)) * 5  // ~1.2 Hz, ±5 pt amplitude
        let duckPos = duck?.position ?? .zero
        let breadCollectRadius: CGFloat = 30
        let cleanupX = -(GK.pipeWidth + 20)

        // PERF: Iterate cached records instead of scanning pipeLayer.children.
        // Pipes and bread are tracked separately — no string-name checks per frame.
        // Remove records when nodes are cleaned up or (bread) collected.

        // --- Move pipes ---
        var pipeIdx = 0
        while pipeIdx < activePipes.count {
            guard let pipeNode = activePipes[pipeIdx].node else {
                activePipes.remove(at: pipeIdx)
                continue
            }
            pipeNode.position.x -= dx

            if pipeNode.position.x < cleanupX {
                pipeNode.removeFromParent()
                activePipes.remove(at: pipeIdx)
            } else {
                pipeIdx += 1
            }
        }

        // --- Move & collect bread ---
        var breadIdx = 0
        while breadIdx < activeBreads.count {
            guard let breadNode = activeBreads[breadIdx].node else {
                activeBreads.remove(at: breadIdx)
                continue
            }
            breadNode.position.x -= dx

            // Absolute sine bob using stored base Y — no drift over time
            breadNode.position.y = activeBreads[breadIdx].baseY + bobPhase

            // Distance-based collection (no physics body)
            let bx = breadNode.position.x - duckPos.x
            let by = breadNode.position.y - duckPos.y
            if bx * bx + by * by < breadCollectRadius * breadCollectRadius {
                collectBread(node: breadNode)
                activeBreads.remove(at: breadIdx)
                continue
            }

            if breadNode.position.x < cleanupX {
                breadNode.removeFromParent()
                activeBreads.remove(at: breadIdx)
            } else {
                breadIdx += 1
            }
        }

        // --- Move power-up collectibles ---
        var puIdx = 0
        while puIdx < activePowerUpCollectibles.count {
            guard let puNode = activePowerUpCollectibles[puIdx].node else {
                // Node was collected (removeFromParent in PowerUpController) or deallocated
                activePowerUpCollectibles.remove(at: puIdx)
                continue
            }
            puNode.position.x -= dx

            if puNode.position.x < cleanupX {
                puNode.removeFromParent()
                activePowerUpCollectibles.remove(at: puIdx)
            } else {
                puIdx += 1
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

        // Bot AI — uses cached pipe records instead of scanning children.
        if mode == .vsBot {
            botController?.update(pipeRecords: activePipes)
        }

        // Stream position to opponent via GameKit
        if mode == .headToHead, phase == .playing {
            sendGhostPosition()
        }
    }

    // MARK: - Performance Tracking

    private func resetPerformanceTracking() {
        performanceStartedAt = 0
        performanceLastSampleAt = 0
        performanceFrameCount = 0
        performanceIntervalSum = 0
        performanceWorstInterval = 0
        performanceSlowFrames = 0
        performanceDroppedFrames = 0
        performanceSevereFrames = 0
        performanceTapCount = 0
        performanceTapTimestamps.removeAll(keepingCapacity: true)
        performanceSlowFramesAfterTap = 0
        performanceDroppedFramesAfterTap = 0
        resetPerformanceWindow()
        performanceSummarySent = false
    }

    private func resetPerformanceWindow() {
        performanceWindowFrameCount = 0
        performanceWindowIntervalSum = 0
        performanceWindowWorstInterval = 0
        performanceWindowSlowFrames = 0
        performanceWindowDroppedFrames = 0
        performanceWindowSevereFrames = 0
    }

    private func recordPerformanceFrame(interval: TimeInterval, currentTime: TimeInterval) {
        if performanceStartedAt == 0 {
            performanceStartedAt = currentTime
            performanceLastSampleAt = currentTime
        }

        guard interval > 0, interval < 1 else { return }

        performanceFrameCount += 1
        performanceIntervalSum += interval
        performanceWorstInterval = max(performanceWorstInterval, interval)

        performanceWindowFrameCount += 1
        performanceWindowIntervalSum += interval
        performanceWindowWorstInterval = max(performanceWindowWorstInterval, interval)

        // Classify frame performance
        let isSlow = interval > Self.slowFrameThreshold
        let isDropped = interval > Self.droppedFrameThreshold
        let isSevere = interval > Self.severeFrameThreshold

        if isSlow { performanceSlowFrames += 1; performanceWindowSlowFrames += 1 }
        if isDropped { performanceDroppedFrames += 1; performanceWindowDroppedFrames += 1 }
        if isSevere { performanceSevereFrames += 1; performanceWindowSevereFrames += 1 }

        // Tap correlation: check if the current frame follows a recent tap
        if isSlow || isDropped {
            let now = currentTime
            let isAfterTap = performanceTapTimestamps.contains { now - $0 < Self.tapCorrelationWindow }
            if isAfterTap {
                if isSlow { performanceSlowFramesAfterTap += 1 }
                if isDropped { performanceDroppedFramesAfterTap += 1 }
            }
        }

        // PERF: No more per-interval PostHog samples during gameplay — accumulate
        // counters in memory and send only the game-over summary.
        guard currentTime - performanceLastSampleAt >= Self.performanceSampleInterval,
              performanceWindowFrameCount > 0 else { return }

        performanceLastSampleAt = currentTime
        resetPerformanceWindow()
    }

    private func sendPerformanceSummary() {
        guard !performanceSummarySent, performanceFrameCount > 0 else { return }
        performanceSummarySent = true

        let duration = max(performanceIntervalSum, 0.001)
        AnalyticsManager.shared.trackGamePerformanceSummary(properties: performanceProperties(
            duration: duration,
            frameCount: performanceFrameCount,
            intervalSum: performanceIntervalSum,
            worstInterval: performanceWorstInterval,
            slowFrames: performanceSlowFrames,
            droppedFrames: performanceDroppedFrames,
            severeFrames: performanceSevereFrames,
            eventKind: "summary"
        ))
    }

    private func performanceProperties(duration: TimeInterval,
                                       frameCount: Int,
                                       intervalSum: TimeInterval,
                                       worstInterval: TimeInterval,
                                       slowFrames: Int,
                                       droppedFrames: Int,
                                       severeFrames: Int,
                                       eventKind: String) -> [String: Any] {
        let avgFrameMs = frameCount > 0 ? (intervalSum / Double(frameCount)) * 1000 : 0
        let avgFps = duration > 0 ? Double(frameCount) / duration : 0

        return [
            "event_kind": eventKind,
            "perf_session_id": performanceSessionId,
            "mode": mode.rawValue,
            "theme_id": backgroundTheme.rawValue,
            "skin_id": playerSkin.rawValue,
            "score": score,
            "duration_seconds": duration,
            "frame_count": frameCount,
            "avg_fps": avgFps,
            "avg_frame_ms": avgFrameMs,
            "worst_frame_ms": worstInterval * 1000,
            "slow_frame_count": slowFrames,
            "dropped_frame_count": droppedFrames,
            "severe_frame_count": severeFrames,
            "slow_frame_rate": Double(slowFrames) / Double(max(frameCount, 1)),
            "dropped_frame_rate": Double(droppedFrames) / Double(max(frameCount, 1)),
            "node_count": totalNodeCount(),
            "physics_body_count": countPhysicsBodies(),
            "pipe_layer_count": activePipes.count,
            "power_up_active": !powerUpCtrl.activePowerUps.isEmpty,
            "tap_count": performanceTapCount,
            "slow_frames_after_tap": performanceSlowFramesAfterTap,
            "dropped_frames_after_tap": performanceDroppedFramesAfterTap,
            "os_version": UIDevice.current.systemVersion
        ]
    }

    // MARK: - Collision

    func didBegin(_ contact: SKPhysicsContact) {
        let bodies = [contact.bodyA, contact.bodyB]
        let masks = bodies.map { $0.categoryBitMask }

        // NOTE: Bread collection is handled via distance checks in update() — no physics body needed.

        // --- Bot score trigger contact ---
        // Bot uses the same score triggers as the player (shared physics infrastructure).
        if masks.contains(GK.scoreCategory) && masks.contains(GK.botCategory) {
            if let pipeName = bodies.first(where: { $0.categoryBitMask == GK.scoreCategory })?.node?.parent?.name {
                botController?.scoreFromPipe(pipeName)
            }
            return
        }

        // --- Player score trigger contact ---
        if masks.contains(GK.scoreCategory) && masks.contains(GK.duckCategory) {
            // Dedup via pipe name — triggers persist so the bot can also score from them.
            if let pipeName = bodies.first(where: { $0.categoryBitMask == GK.scoreCategory })?.node?.parent?.name {
                guard !playerPipesPassed.contains(pipeName) else { return }
                playerPipesPassed.insert(pipeName)
            }

            let points = (powerUpCtrl.isDoublePointsActive && mode != .vsBot) ? 2 : 1
            score += points
            updateScore()
            Haptic.score()
            SoundManager.shared.play(.score)

            // Every 10 pipes — play a random duck quack
            if score % 10 == 0 {
                SoundManager.shared.playRandomQuack()
            }

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
            return
        }

        // --- Power-up collectible contact ---
        if masks.contains(GK.powerUpCategory) && masks.contains(GK.duckCategory) {
            if let powerUpNode = bodies.first(where: { $0.categoryBitMask == GK.powerUpCategory })?.node {
                powerUpCtrl.collectPowerUp(node: powerUpNode)
            }
            return
        }

        // --- Bot pipe / ground collision → bot dies ---
        if masks.contains(GK.botCategory) && (masks.contains(GK.pipeCategory) || masks.contains(GK.groundCategory)) {
            botController?.handleCollision()
            return
        }

        // --- Player pipe / ground collision ---
        if phase == .playing && masks.contains(GK.duckCategory) {
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
        sendPerformanceSummary()

        // Item 6: Enhanced death haptic
        Haptic.enhancedDeath()
        SoundManager.shared.play(.death)
        SoundManager.shared.stopPlayMusic()

        // Disable bot physics immediately so gravity can't pull it into a
        // pipe/ground during the death animation — prevents the late
        // onBotDied callback from firing a false win celebration.
        botController?.sprite?.physicsBody?.isDynamic = false

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
        if !duckTextures.isEmpty { duck.texture = duckTextures[0] }

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
        // Only celebrate if the player is still alive — if they already died,
        // the bot dying afterwards doesn't count as a win.
        guard phase == .playing else { return }
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
        // PERF: Uses pre-rendered glow textures instead of SKShapeNodes
        let celebCount = 20
        let celebColors: [UIColor] = [
            UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1),   // gold
            UIColor.white,
            UIColor(red: 1.0, green: 0.60, blue: 0.0, alpha: 1),   // orange
            UIColor(red: 0.42, green: 0.73, blue: 0.20, alpha: 1), // green
        ]
        for i in 0..<celebCount {
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
        activePipes.removeAll()
        activeBreads.removeAll()
        activePowerUpCollectibles.removeAll()
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
        playerPipesPassed.removeAll()
        currentPipeSpeed = GK.pipeSpeed
        phase = .ready

        let newSeed = Int.random(in: 1...999999)
        prng = SeededRandom(seed: newSeed)
        gapPositions = prng.generateGapPositions()

        // Reset progressive difficulty
        difficulty.reset()

        // Clear power-up state (also resets speed modifier)
        powerUpCtrl.reset()

        // Reset cached physics / animation state
        lastAppliedGravity = 0
        breadBobTime = 0

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

        // Restore base physics body (bread uses distance checks — no physics needed)
        let body = SKPhysicsBody(circleOfRadius: GK.duckRadius * 0.72)
        body.categoryBitMask = GK.duckCategory
        body.contactTestBitMask = GK.pipeCategory | GK.groundCategory | GK.powerUpCategory
        body.collisionBitMask = GK.groundCategory   // Ground only — no pipe collision (prevents drift)
        body.fieldBitMask = GK.playerGravityFieldCategory   // player-only gravity field
        body.allowsRotation = false
        body.restitution = 0
        body.linearDamping = 0
        body.isDynamic = false
        body.velocity = .zero
        duck.physicsBody = body

        // Re-bind duck reference in PowerUpController after physics body reset
        powerUpCtrl.setDuck(duck)
        powerUpCtrl.setDuckTextures(duckTextures)

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

        // Clean up death vignette and fog overlay if still present
        deathVignette?.removeFromParent()
        deathVignette = nil
        fogOverlay?.removeFromParent()
        fogOverlay = nil

        // Reset bot controller
        if mode == .vsBot {
            botController?.reset(skin: botSkin ?? playerSkin)
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
        guard !scorePopupPool.isEmpty else { return }

        let popup = scorePopupPool[scorePopupPoolIndex % scorePopupPool.count]
        scorePopupPoolIndex += 1

        popup.removeAllActions()
        popup.text = "+1"
        popup.alpha = 1.0
        popup.setScale(1.0)
        popup.isHidden = false
        popup.position = CGPoint(x: duck.position.x + 30, y: duck.position.y + 28)

        if isMilestone {
            popup.fontSize = 18
            popup.fontColor = UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0)
            let floatUp = SKAction.moveBy(x: 0, y: 50, duration: 0.6)
            let fadeOut = SKAction.fadeOut(withDuration: 0.6)
            let scaleUp = SKAction.scale(to: 1.4, duration: 0.15)
            let scaleBack = SKAction.scale(to: 1.0, duration: 0.45)
            popup.run(SKAction.sequence([
                SKAction.group([floatUp, fadeOut, SKAction.sequence([scaleUp, scaleBack])]),
                SKAction.run { popup.isHidden = true }
            ]))
        } else {
            popup.fontSize = 14
            popup.fontColor = .white

            let floatUp = SKAction.moveBy(x: 0, y: 50, duration: 0.6)
            let fadeOut = SKAction.fadeOut(withDuration: 0.6)
            let scaleUp = SKAction.scale(to: 1.1, duration: 0.2)
            let scaleBack = SKAction.scale(to: 1.0, duration: 0.4)
            popup.run(SKAction.sequence([
                SKAction.group([floatUp, fadeOut, SKAction.sequence([scaleUp, scaleBack])]),
                SKAction.run { popup.isHidden = true }
            ]))
        }
    }

    // MARK: - First-Launch Tutorial (Item 8)

    private func showTutorialIfNeeded() {
        let key = "hasSeenTutorial"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        DispatchQueue.global(qos: .utility).async {
            UserDefaults.standard.set(true, forKey: key)
        }
        // Defer overlay creation to after first frame render to avoid main-thread hitch
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.createTutorialOverlay()
        }
    }

    private func createTutorialOverlay() {

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

    private func totalNodeCount() -> Int {
        var count = 1
        enumerateChildNodes(withName: "//*") { _, _ in
            count += 1
        }
        return count
    }

    private func countPhysicsBodies() -> Int {
        var count = 0
        enumerateChildNodes(withName: "//*") { node, _ in
            if node.physicsBody != nil { count += 1 }
        }
        return count
    }
}

// MARK: - Battle Royale Ghosts

@MainActor
final class GhostDuckRenderer {
    private let worldNode: SKNode
    private let factory = TextureFactory.shared
    private var sprites: [String: SKSpriteNode] = [:]

    init(worldNode: SKNode) {
        self.worldNode = worldNode
    }

    func update(_ snapshots: [BattleRoyaleGhost]) {
        let activeIds = Set(snapshots.map(\.playerId))
        for (playerId, sprite) in sprites where !activeIds.contains(playerId) {
            sprite.removeFromParent()
            sprites[playerId] = nil
        }

        for snapshot in snapshots {
            let phase = max(0, min(2, snapshot.wingPhase))
            let skin = snapshot.skinId.flatMap(DuckSkin.init(rawValue:)) ?? .classic
            let sprite = sprites[snapshot.playerId] ?? makeSprite(playerId: snapshot.playerId)
            sprite.texture = factory.skinBotDuckTexture(skin: skin, wingPhase: phase)
            sprite.position = CGPoint(
                x: GK.duckStartX + CGFloat(Self.stableLane(for: snapshot.playerId)) * 18 + 28,
                y: CGFloat(snapshot.y)
            )
            sprite.zRotation = CGFloat(snapshot.rotation)
            sprite.alpha = 0.48
        }
    }

    private func makeSprite(playerId: String) -> SKSpriteNode {
        let sprite = SKSpriteNode(texture: factory.skinBotDuckTexture(skin: .classic, wingPhase: 1))
        sprite.name = "battle_royale_ghost_\(playerId)"
        sprite.zPosition = 98
        sprite.setScale(1.0)
        sprite.alpha = 0.48
        worldNode.addChild(sprite)
        sprites[playerId] = sprite
        return sprite
    }

    private static func stableLane(for value: String) -> Int {
        var hash: UInt32 = 2_166_136_261
        for byte in value.utf8 {
            hash ^= UInt32(byte)
            hash &*= 16_777_619
        }
        return Int(hash % 7)
    }
}

// MARK: - GameKit Session (P2P multiplayer)

struct GhostDuckPosition {
    let x: Float
    let y: Float
    let velY: Float
    let rotation: Float
    let wingPhase: UInt8
}

struct GhostDuckEvent {
    enum Kind: UInt8 {
        case started = 0
        case finished = 1
        case disconnected = 2
    }
    let kind: Kind
    let finalScore: UInt16?
}

protocol GameKitSessionDelegate: AnyObject {
    func gameKitSessionDidConnect()
    func gameKitSessionDidDisconnect(error: Error?)
    func gameKitSession(didReceivePosition position: GhostDuckPosition)
    func gameKitSession(didReceiveScore score: UInt16)
    func gameKitSession(didReceiveEvent event: GhostDuckEvent)
    func gameKitSession(didReceiveSkinId skinId: String)
}

final class GameKitSession: NSObject {
    weak var delegate: GameKitSessionDelegate?

    private var match: GKMatch?
    private let sendInterval: TimeInterval = 1.0 / 20.0
    private var lastSendTime: TimeInterval = 0
    private var isConnected = false
    private var isConnecting = false
    private var activeSessionCode: String?
    private var connectTask: Task<Void, Never>?

    /// Maximum number of matchmaking attempts before giving up.
    private static let maxRetries = 3
    /// Seconds to wait for `findMatch` on each attempt before retrying.
    private static let perAttemptTimeout: TimeInterval = 8

    /// Dedicated queue for encoding + sending — moves serialization and
    /// GameKit IPC off the SpriteKit render thread.
    private let sendQueue = DispatchQueue(label: "com.floppyduck.gksession", qos: .userInitiated)

    var connected: Bool { isConnected && match != nil }

    /// Whether GameKit matchmaking failed after all retries, so the caller
    /// can fall back to Convex-based ghost sync.
    private(set) var didFailPermanently = false

    func connect(sessionCode: String, timeout: TimeInterval = 15) {
        if activeSessionCode == sessionCode, isConnecting || connected {
            return
        }

        if activeSessionCode != sessionCode {
            disconnect()
        }

        activeSessionCode = sessionCode
        didFailPermanently = false

        guard GKLocalPlayer.local.isAuthenticated else {
            delegate?.gameKitSessionDidDisconnect(error: SessionError.notAuthenticated)
            return
        }

        isConnecting = true

        let groupId = Self.playerGroup(for: sessionCode)
        print("[GameKit] Starting matchmaking with group \(groupId) (code: \(sessionCode))")

        connectTask = Task { [weak self] in
            guard let self else { return }

            for attempt in 1...Self.maxRetries {
                guard !Task.isCancelled else { break }
                print("[GameKit] Attempt \(attempt)/\(Self.maxRetries) — finding match…")

                do {
                    let foundMatch = try await self.findMatchWithTimeout(
                        groupId: groupId,
                        timeout: Self.perAttemptTimeout
                    )

                    guard !Task.isCancelled else { break }

                    // Verify all expected players are connected.
                    if foundMatch.expectedPlayerCount != 0 {
                        print("[GameKit] Match returned with \(foundMatch.expectedPlayerCount) expected player(s) still pending — retrying")
                        foundMatch.disconnect()
                        GKMatchmaker.shared().cancel()
                        continue
                    }

                    await MainActor.run {
                        self.match = foundMatch
                        foundMatch.delegate = self
                        self.isConnected = true
                        self.isConnecting = false
                        print("[GameKit] Connected — players: \(foundMatch.players.count)")
                        self.delegate?.gameKitSessionDidConnect()
                    }
                    return  // Success — exit retry loop
                } catch is CancellationError {
                    break
                } catch {
                    print("[GameKit] Attempt \(attempt) failed: \(error.localizedDescription)")
                    GKMatchmaker.shared().cancel()

                    if attempt < Self.maxRetries, !Task.isCancelled {
                        // Brief pause before retrying so both players' requests
                        // have a chance to overlap on Apple's servers.
                        try? await Task.sleep(nanoseconds: 500_000_000)
                    }
                }
            }

            guard !Task.isCancelled else { return }

            // All retries exhausted — notify delegate so the view can fall back.
            await MainActor.run {
                self.isConnecting = false
                self.didFailPermanently = true
                print("[GameKit] All \(Self.maxRetries) attempts exhausted — matchmaking failed")
                self.delegate?.gameKitSessionDidDisconnect(error: SessionError.noMatch)
            }
        }
    }

    /// Calls the modern async `findMatch(for:)` API with a per-attempt timeout.
    private func findMatchWithTimeout(groupId: Int, timeout: TimeInterval) async throws -> GKMatch {
        let request = GKMatchRequest()
        request.minPlayers = 2
        request.maxPlayers = 2
        request.playerGroup = groupId
        request.defaultNumberOfPlayers = 2

        return try await withThrowingTaskGroup(of: GKMatch.self) { group in
            group.addTask {
                try await GKMatchmaker.shared().findMatch(for: request)
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                GKMatchmaker.shared().cancel()
                throw SessionError.timeout
            }

            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    func sendPosition(_ pos: GhostDuckPosition) {
        sendQueue.async { [weak self] in
            guard let self else { return }
            let now = CACurrentMediaTime()
            guard now - self.lastSendTime >= self.sendInterval else { return }
            self.lastSendTime = now
            self.send(data: self.encodePosition(pos), mode: .unreliable)
        }
    }

    func sendScore(_ score: UInt16) {
        send(data: encodeScore(score), mode: .reliable)
    }

    func sendEvent(_ event: GhostDuckEvent) {
        send(data: encodeEvent(event), mode: .reliable)
    }

    func sendSkinId(_ skinId: String) {
        send(data: encodeSkinId(skinId), mode: .reliable)
    }

    func disconnect() {
        connectTask?.cancel()
        connectTask = nil
        if isConnecting {
            GKMatchmaker.shared().cancel()
        }
        match?.disconnect()
        match?.delegate = nil
        match = nil
        isConnected = false
        isConnecting = false
        activeSessionCode = nil
    }

    private func send(data: Data, mode: GKMatch.SendDataMode) {
        guard let match, isConnected else { return }
        do {
            try match.sendData(toAllPlayers: data, with: mode)
        } catch {
            print("[GameKit] Send error: \(error.localizedDescription)")
        }
    }

    static func playerGroup(for sessionCode: String) -> Int {
        let positiveMask = UInt32(Int32.max)
        if let numericCode = UInt32(sessionCode) {
            return Int(numericCode & positiveMask)
        }

        var hash: UInt32 = 2_166_136_261
        for byte in sessionCode.utf8 {
            hash ^= UInt32(byte)
            hash = hash &* 16_777_619
        }
        return Int(hash & positiveMask)
    }

    // MARK: - Encoding

    private func encodePosition(_ pos: GhostDuckPosition) -> Data {
        var data = Data()
        data.append(0)
        data.append(contentsOf: withUnsafeBytes(of: pos.x) { Data($0) })
        data.append(contentsOf: withUnsafeBytes(of: pos.y) { Data($0) })
        data.append(contentsOf: withUnsafeBytes(of: pos.velY) { Data($0) })
        data.append(contentsOf: withUnsafeBytes(of: pos.rotation) { Data($0) })
        data.append(pos.wingPhase)
        return data
    }

    private func encodeScore(_ score: UInt16) -> Data {
        var data = Data()
        data.append(1)
        data.append(contentsOf: withUnsafeBytes(of: score.littleEndian) { Data($0) })
        return data
    }

    private func encodeEvent(_ event: GhostDuckEvent) -> Data {
        var data = Data()
        data.append(2)
        data.append(event.kind.rawValue)
        let score = event.finalScore ?? 0
        data.append(contentsOf: withUnsafeBytes(of: score.littleEndian) { Data($0) })
        return data
    }

    private func encodeSkinId(_ skinId: String) -> Data {
        var data = Data()
        data.append(3)
        if let bytes = skinId.data(using: .utf8) {
            data.append(UInt8(min(bytes.count, 255)))
            data.append(bytes.prefix(255))
        } else {
            data.append(0)
        }
        return data
    }
}

extension GameKitSession: GKMatchDelegate {
    func match(_ match: GKMatch, didReceive data: Data, fromRemotePlayer player: GKPlayer) {
        guard data.count > 0 else { return }
        let type = data[0]
        let payload = data.dropFirst()

        switch type {
        case 0:
            if let pos = decodePosition(payload) {
                delegate?.gameKitSession(didReceivePosition: pos)
            }
        case 1:
            if let score = decodeScore(payload) {
                delegate?.gameKitSession(didReceiveScore: score)
            }
        case 2:
            if let event = decodeEvent(payload) {
                delegate?.gameKitSession(didReceiveEvent: event)
            }
        case 3:
            if let skinId = decodeSkinId(payload) {
                delegate?.gameKitSession(didReceiveSkinId: skinId)
            }
        default:
            break
        }
    }

    func match(_ match: GKMatch, player: GKPlayer, didChange state: GKPlayerConnectionState) {
        print("[GameKit] Player \(player.alias) — state: \(state.rawValue)")
        if state == .disconnected {
            isConnected = false
            delegate?.gameKitSessionDidDisconnect(error: nil)
        }
    }

    func match(_ match: GKMatch, didFailWithError error: (any Error)?) {
        print("[GameKit] Match failed: \(error?.localizedDescription ?? "unknown")")
        isConnected = false
        delegate?.gameKitSessionDidDisconnect(error: error)
    }
}

extension GameKitSession {
    private func decodePosition(_ data: Data) -> GhostDuckPosition? {
        guard data.count >= 17 else { return nil }
        let x: Float = data.subdata(in: 0..<4).withUnsafeBytes { $0.load(as: Float.self) }
        let y: Float = data.subdata(in: 4..<8).withUnsafeBytes { $0.load(as: Float.self) }
        let velY: Float = data.subdata(in: 8..<12).withUnsafeBytes { $0.load(as: Float.self) }
        let rotation: Float = data.subdata(in: 12..<16).withUnsafeBytes { $0.load(as: Float.self) }
        let wingPhase = data[16]
        return GhostDuckPosition(x: x, y: y, velY: velY, rotation: rotation, wingPhase: wingPhase)
    }

    private func decodeScore(_ data: Data) -> UInt16? {
        guard data.count >= 2 else { return nil }
        return data.withUnsafeBytes { $0.load(as: UInt16.self).littleEndian }
    }

    private func decodeEvent(_ data: Data) -> GhostDuckEvent? {
        guard data.count >= 1 else { return nil }
        guard let kind = GhostDuckEvent.Kind(rawValue: data[0]) else { return nil }
        let finalScore: UInt16? = data.count >= 3
            ? data.subdata(in: 1..<3).withUnsafeBytes { $0.load(as: UInt16.self).littleEndian }
            : nil
        return GhostDuckEvent(kind: kind, finalScore: finalScore)
    }

    private func decodeSkinId(_ data: Data) -> String? {
        guard data.count >= 2 else { return nil }
        let len = Int(data[0])
        guard data.count >= 1 + len else { return nil }
        return String(data: data.subdata(in: 1..<1+len), encoding: .utf8)
    }
}

extension GameKitSession {
    enum SessionError: Error, LocalizedError {
        case notAuthenticated
        case noMatch
        case timeout

        var errorDescription: String? {
            switch self {
            case .notAuthenticated: return "Sign in to Game Center to play multiplayer."
            case .noMatch: return "Could not find a match."
            case .timeout: return "Matchmaking timed out."
            }
        }
    }
}
