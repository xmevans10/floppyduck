import SpriteKit

// MARK: - BotController

/// Encapsulates all bot (AI opponent) logic: sprite creation, AI flap
/// decisions, death handling, and score tracking.
///
/// Physics, collision, and scoring are handled by the same SpriteKit
/// infrastructure as the player duck — the bot has a real SKPhysicsBody
/// with `botCategory` and shares the same pipe/ground/scoreTrigger contact
/// detection in `GameScene.didBegin(_:)`.
///
/// This eliminates the separate manual physics loop that previously ran
/// every frame (gravity, position, per-pipe collision iteration) and caused
/// lag in bot mode vs classic mode.
///
/// Usage:
///   1. Create after the world node exists:
///      ```
///      botController = BotController(worldNode: worldNode, hudLayer: hudLayer)
///      ```
///   2. Setup in `didMove(to:)`:
///      ```
///      botController.setup(skin: playerSkin, difficulty: botDiff)
///      botController.setupScoreHUD(mode: .vsBot, opponentName: name)
///      ```
///   3. When gameplay begins:
///      ```
///      botController.startPlaying()
///      ```
///   4. Every frame while `.playing`:
///      ```
///      botController.update(pipeNodes: pipeLayer.children)
///      ```
///   5. On game reset:
///      ```
///      botController.reset(skin: playerSkin)
///      ```
final class BotController {

    // MARK: - Callbacks

    /// Fired every time the bot scores a point. Parameter is the new total.
    var onScoreChanged: ((Int) -> Void)?

    /// Fired when the bot dies (hit ground, pipe, or reached deathScore).
    var onBotDied: (() -> Void)?

    // MARK: - Public Read-Only State

    /// The bot's current score.
    private(set) var score: Int = 0

    /// Whether the bot has died this round.
    var isDead: Bool { !alive }

    /// The bot sprite node (nil before `setup` is called).
    private(set) var sprite: SKSpriteNode?

    // MARK: - Injected Nodes (unowned – scene keeps them alive)

    private let worldNode: SKNode
    private let hudLayer: SKNode

    // MARK: - Internal State

    private let factory = TextureFactory.shared
    private var textures: [SKTexture] = []
    private var alive: Bool = false
    private var pipesPassed: Set<String> = []

    /// Active difficulty parameters; set during `setup`.
    private var diff = BotDifficulty(noiseRange: 12, flapStrength: 0.88, errorRate: 0)

    /// If set, the bot will deterministically die upon reaching this score.
    /// Used in bot-ladder mode so each bot has a fixed score ceiling.
    private var deathScore: Int?

    /// When true the bot's AI is disabled — it stops flapping and gravity
    /// naturally pulls it into the next pipe or the ground.
    private var doomed: Bool = false

    /// Whether the bot reached its ceiling score before dying.
    /// Used by GameScene to distinguish a ceiling death (→ player wins)
    /// from a premature collision (→ game continues).
    private(set) var reachedCeiling: Bool = false

    /// Skin used for the current bot sprite (needed for reset).
    private var currentSkin: DuckSkin?

    // MARK: - Score HUD

    private var scoreLabel: SKLabelNode?
    private var scoreShadow: SKLabelNode?
    private var displayName: String = "BOT"

    // MARK: - Init

    /// - Parameters:
    ///   - worldNode: The scene's world node; the bot sprite is added here.
    ///   - hudLayer: The scene's HUD layer; the bot score label is added here.
    init(worldNode: SKNode, hudLayer: SKNode) {
        self.worldNode = worldNode
        self.hudLayer = hudLayer
    }

    // MARK: - Setup

    /// Creates the bot ghost-duck sprite with wing animation, idle float,
    /// and a real SKPhysicsBody (same collision infrastructure as the player).
    ///
    /// - Parameters:
    ///   - skin: Duck skin used for the ghost textures.
    ///   - difficulty: AI tuning parameters (noise, flap strength, error rate).
    ///                 Defaults to a mid-tier difficulty if `nil`.
    ///   - deathScore: If set, the bot will die deterministically when it
    ///                 reaches this score. Used in bot-ladder mode.
    func setup(skin: DuckSkin, difficulty: BotDifficulty? = nil, deathScore: Int? = nil) {
        self.diff = difficulty ?? BotDifficulty(noiseRange: 12, flapStrength: 0.88, errorRate: 0)
        self.deathScore = deathScore
        self.currentSkin = skin

        // Ghost-duck sprite: desaturated, translucent, with soft glow (XAN-6)
        textures = (0...2).map { factory.skinDuckTexture(skin: skin, wingPhase: $0) }

        let bot = SKSpriteNode(texture: textures[1], size: skin.spriteSize)
        bot.position = CGPoint(x: GK.duckStartX, y: GK.duckStartY)
        bot.zPosition = 35
        bot.alpha = 0.45
        bot.colorBlendFactor = 0.35
        bot.color = .white

        // Soft outer glow to reinforce the ghost look (XAN-6)
        let glow = SKSpriteNode(texture: textures[1], size: skin.spriteSize)
        glow.alpha = 0.18
        glow.colorBlendFactor = 1.0
        glow.color = SKColor(white: 1.0, alpha: 1.0)
        glow.setScale(1.25)
        glow.zPosition = -1
        glow.blendMode = .add
        bot.addChild(glow)

        // SKPhysicsBody — same collision infrastructure as the player duck.
        // Uses contactTest for pipe/ground/score detection but collisionBitMask = 0
        // so the ghost visually passes through everything.
        let body = SKPhysicsBody(circleOfRadius: GK.duckRadius * 0.72)
        body.categoryBitMask = GK.botCategory
        body.contactTestBitMask = GK.pipeCategory | GK.groundCategory | GK.scoreCategory
        body.collisionBitMask = 0          // Ghost — no physical collisions
        body.allowsRotation = false
        body.restitution = 0
        body.linearDamping = 0
        body.isDynamic = false             // Disabled until gameplay starts
        body.velocity = .zero
        bot.physicsBody = body

        // Wing flap loop
        let wingAction = SKAction.animate(with: textures, timePerFrame: 0.10)
        bot.run(SKAction.repeatForever(wingAction), withKey: "botWings")

        // Idle float (removed when gameplay starts)
        let float = SKAction.sequence([
            SKAction.moveBy(x: 0, y: 10, duration: 0.5),
            SKAction.moveBy(x: 0, y: -10, duration: 0.5)
        ])
        bot.run(SKAction.repeatForever(float), withKey: "botFloat")

        worldNode.addChild(bot)
        sprite = bot
        alive = true
    }

    /// Creates the bot-score HUD labels (used in both vsBot and headToHead modes).
    func setupScoreHUD(mode: GameMode, opponentName: String? = nil) {
        if mode == .headToHead {
            displayName = opponentName ?? "OPPONENT"
        } else {
            displayName = opponentName ?? "BOT"
        }

        let shadow = SKLabelNode(fontNamed: GK.pixelFontName)
        shadow.fontSize = 14
        shadow.fontColor = UIColor(red: 0.42, green: 0.12, blue: 0.12, alpha: 0.7)
        shadow.position = CGPoint(x: GK.worldWidth / 2 + 1, y: GK.worldHeight - 108)
        shadow.zPosition = 200
        shadow.text = "\(displayName): 0"
        shadow.verticalAlignmentMode = .center
        shadow.horizontalAlignmentMode = .center
        hudLayer.addChild(shadow)
        scoreShadow = shadow

        let label = SKLabelNode(fontNamed: GK.pixelFontName)
        label.fontSize = 14
        label.fontColor = UIColor(red: 0.95, green: 0.60, blue: 0.60, alpha: 0.9)
        label.position = CGPoint(x: GK.worldWidth / 2, y: GK.worldHeight - 107)
        label.zPosition = 201
        label.text = "\(displayName): 0"
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        hudLayer.addChild(label)
        scoreLabel = label
    }

    // MARK: - Gameplay Transitions

    /// Call when gameplay begins — enables physics (gravity) and stops the idle float.
    func startPlaying() {
        sprite?.removeAction(forKey: "botFloat")
        sprite?.physicsBody?.isDynamic = true   // Enable gravity + physics
    }

    // MARK: - Per-Frame Update (AI only)

    /// Runs the bot's AI flap decision for one frame.
    ///
    /// All physics (gravity, movement), collision detection, and scoring are
    /// handled by SpriteKit's physics engine — same as the player duck.
    /// This method only decides *when* to flap.
    ///
    /// - Parameter pipeNodes: All current pipe nodes from the pipe layer
    ///   (used only to find the nearest gap center for targeting).
    func update(pipeNodes: [SKNode]) {
        guard alive, let bot = sprite else { return }

        // --- Find nearest pipe gap center for AI targeting ---
        var targetGapY: CGFloat = GK.duckStartY
        var nearestDist: CGFloat = .greatestFiniteMagnitude

        for child in pipeNodes {
            let dist = child.position.x - GK.duckStartX
            // Only consider pipes ahead of (or at) the bot
            if dist > -(GK.pipeWidth / 2) && dist < nearestDist {
                if let trigger = child.childNode(withName: "scoreTrigger") {
                    targetGapY = trigger.position.y
                    nearestDist = dist
                }
            }
        }

        // --- AI decision: aim at exact gap center ---
        // When doomed the bot simply stops flapping and gravity takes over.
        if !doomed {
            let botY = bot.position.y
            let currentVelocity = bot.physicsBody?.velocity.dy ?? 0
            let botImpulse = GK.flapImpulse * 0.65
            if botY < targetGapY - 15 && currentVelocity < botImpulse * 0.4 {
                bot.physicsBody?.velocity = CGVector(dx: 0, dy: botImpulse)
            }
        }

        // --- Rotation (visual only — same logic as player duck) ---
        let vy = bot.physicsBody?.velocity.dy ?? 0
        let rotTarget = vy > 0
            ? min(vy / GK.flapImpulse * 0.4, 0.4)
            : max(vy / 400, -CGFloat.pi / 2)
        bot.zRotation += (rotTarget - bot.zRotation) * 0.10

        // Pin horizontal position (physics contacts can nudge the bot)
        if bot.position.x != GK.duckStartX {
            bot.position.x = GK.duckStartX
            bot.physicsBody?.velocity.dx = 0
        }
    }

    // MARK: - Scoring (called by GameScene.didBegin)

    /// Called when the bot's physics body contacts a score trigger.
    /// Deduplicates via pipe name and fires `onScoreChanged`.
    func scoreFromPipe(_ pipeName: String) {
        guard alive, !pipesPassed.contains(pipeName) else { return }
        pipesPassed.insert(pipeName)
        score += 1
        updateScoreHUD()
        onScoreChanged?(score)

        // Once the bot reaches its ceiling score, stop flapping.
        // Gravity will pull it into the next pipe for a natural death.
        if let cap = deathScore, score >= cap {
            doomed = true
            reachedCeiling = true
        }
    }

    // MARK: - Collision (called by GameScene.didBegin)

    /// Called when the bot's physics body contacts a pipe or ground.
    func handleCollision() {
        guard alive else { return }
        die()
    }

    // MARK: - Death

    /// Plays the bot death animation (tumble + fall + fade) and fires `onBotDied`.
    private func die() {
        alive = false
        guard let bot = sprite else { return }

        // Disable physics so the death animation isn't affected by gravity
        bot.physicsBody?.isDynamic = false

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

        onBotDied?()
    }

    // MARK: - Ghost Position Sync (GameKit)

    func setGhostPosition(x: CGFloat, y: CGFloat, velY: CGFloat, rotation: CGFloat, wingPhase: Int) {
        guard let bot = sprite else { return }
        bot.position = CGPoint(x: x, y: y)
        bot.zRotation = rotation
        let idx = min(max(wingPhase, 0), 2)
        if idx < textures.count {
            bot.texture = textures[idx]
        }
    }

    // MARK: - Score HUD

    /// Refreshes the on-screen bot score label text.
    func updateScoreHUD() {
        let text = "\(displayName): \(score)"
        scoreLabel?.text = text
        scoreShadow?.text = text
    }

    /// Sets the score directly (used in headToHead mode for remote opponent scores).
    func setScore(_ newScore: Int) {
        score = max(0, newScore)
        updateScoreHUD()
    }

    // MARK: - Reset

    /// Tears down the current bot sprite and re-creates it for a new round.
    func reset(skin: DuckSkin) {
        sprite?.removeFromParent()
        sprite = nil
        score = 0
        doomed = false
        reachedCeiling = false
        pipesPassed.removeAll()
        setup(skin: skin, difficulty: diff, deathScore: deathScore)
        updateScoreHUD()
    }
}
