import SpriteKit

// MARK: - BotController

/// Encapsulates all bot (AI opponent) logic: sprite creation, per-frame AI
/// update loop, collision / death handling, and score tracking.
///
/// v2: Uses `HumanBotAI` for human-like behavioral decisions, or
///     `ReplayBotAI` for replaying recorded human runs. Both provide
///     more authentic play than the original noise+error model.
///
/// Extracted from `GameScene` to keep the scene file focused on player + world
/// logic.  Follows the same pattern as `ParallaxManager`.
///
/// Usage:
///   1. Create after the world node exists:
///      ```
///      botController = BotController(worldNode: worldNode, hudLayer: hudLayer)
///      ```
///   2. Setup in `didMove(to:)`:
///      ```
///      botController.setup(skin: playerSkin,
///                          profile: botProfile,
///                          targetScore: score)
///      ```
///   3. When gameplay begins:
///      ```
///      botController.startPlaying()
///      ```
///   4. Every frame while `.playing`:
///      ```
///      botController.update(dt: dt,
///                           pipeNodes: pipeLayer.children,
///                           activePowerUps: activePowerUps,
///                           effectivePipeGap: difficulty.effectivePipeGap)
///      ```
///   5. On game reset:
///      ```
///      botController.reset(skin: playerSkin)
///      ```
final class BotController {

    // MARK: - Callbacks

    /// Fired every time the bot scores a point. Parameter is the new total.
    var onScoreChanged: ((Int) -> Void)?

    /// Fired when the bot dies (hit ground, pipe, or natural death from skill collapse).
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
    private var posY: CGFloat = GK.duckStartY
    private var velocity: CGFloat = 0
    private var alive: Bool = false
    private var pipesPassed: Set<String> = []

    /// Human-like AI engine (behavioral or replay).
    private var ai: BotAIMode?

    /// Legacy difficulty — kept for backwards compatibility with existing setup calls.
    private var legacyDiff = BotDifficulty(noiseRange: 12, flapStrength: 0.88, errorRate: 0)

    /// Human-like profile for behavioral AI.
    private var profile: HumanBotProfile?

    /// If set, the bot gets plot armor until this score (only in behavioral mode
    /// as a safety net — should rarely trigger with well-tuned profiles).
    private var plotArmorUntil: Int?

    /// Elapsed game time since `startPlaying()`.
    private var gameTime: TimeInterval = 0

    /// Whether gameplay has started (for timing purposes).
    private var isPlaying: Bool = false

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

    /// Creates the bot ghost-duck sprite with human-like AI.
    ///
    /// - Parameters:
    ///   - skin: Duck skin used for the ghost textures.
    ///   - difficulty: Legacy AI parameters (used as fallback if profile is nil).
    ///   - profile: Human-like AI profile. If provided, uses the new behavioral model.
    ///   - deathScore: Target score for plot armor safety net.
    ///   - replay: If provided, uses replay mode instead of behavioral AI.
    func setup(skin: DuckSkin,
               difficulty: BotDifficulty? = nil,
               profile: HumanBotProfile? = nil,
               deathScore: Int? = nil,
               replay: ReplayBotAI.ReplayData? = nil) {

        self.legacyDiff = difficulty ?? BotDifficulty(noiseRange: 12, flapStrength: 0.88, errorRate: 0)
        self.profile = profile
        self.plotArmorUntil = deathScore.map { max(0, $0 - 5) }  // Plot armor until 5 below target

        // Choose AI mode
        if let replay = replay {
            ai = .replay(ReplayBotAI(replay: replay))
        } else if let profile = profile {
            ai = .behavioral(HumanBotAI(profile: profile))
        } else {
            // Fallback: create a basic profile from legacy difficulty
            let fallbackProfile = HumanBotProfile(
                reactionBase: 0.25,
                reactionσ: 0.04,
                motorσ: 0.035,
                perceptionRange: 280,
                aimBiasσ: legacyDiff.noiseRange * 0.3,
                panicDistance: 80,
                panicMisalignment: 30,
                panicFlapChance: 0.15,
                fatigueRate: 0.004,
                scoreRecovery: 0.05,
                attentionFloor: 0.55,
                targetScore: deathScore ?? 30,
                deathPressureRate: 0.22
            )
            ai = .behavioral(HumanBotAI(profile: fallbackProfile))
        }

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
        posY = GK.duckStartY
        velocity = 0
        alive = true
        gameTime = 0
        isPlaying = false
    }

    /// Creates the bot-score HUD labels (used in both vsBot and headToHead modes).
    ///
    /// - Parameters:
    ///   - mode: Current game mode (affects label text).
    ///   - opponentName: Optional custom name; defaults to "BOT" / "OPPONENT".
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

    /// Call when gameplay begins — stops the idle float animation.
    func startPlaying() {
        sprite?.removeAction(forKey: "botFloat")
        isPlaying = true
    }

    // MARK: - Per-Frame Update (AI)

    /// Runs the bot's AI for one frame: gravity, movement, pipe collision,
    /// scoring, and flap decisions.
    ///
    /// - Parameters:
    ///   - dt: Delta-time since last frame (seconds).
    ///   - pipeNodes: All current pipe nodes from the pipe layer.
    ///   - activePowerUps: Currently active power-ups (for gap-size modifiers).
    ///   - effectivePipeGap: Base effective gap from the `DifficultyManager`.
    func update(dt: TimeInterval,
                pipeNodes: [SKNode],
                activePowerUps: [ActivePowerUp],
                effectivePipeGap: CGFloat) {
        guard alive, let bot = sprite else { return }

        if isPlaying {
            gameTime += dt
        }

        // --- Gravity & position ---
        velocity += GK.gravity / 60 * CGFloat(dt) * 60
        posY += velocity * CGFloat(dt)

        // Use same collision radius as player duck (GK.duckRadius * 0.72)
        // so bots and player have identical hitboxes. (XAN-5)
        let botR = GK.duckRadius * 0.72

        // Ground collision → die (or bounce if plot-armored)
        if posY <= GK.groundHeight + botR {
            posY = GK.groundHeight + botR
            if hasPlotArmor {
                // Plot armor: bounce the bot back up
                velocity = GK.flapImpulse * 0.6
            } else {
                die()
                return
            }
        }

        // Ceiling clamp
        if posY >= GK.worldHeight - botR {
            posY = GK.worldHeight - botR
            velocity = 0
        }

        // --- Effective gap (including power-up modifiers) ---
        var gap = effectivePipeGap
        if activePowerUps.contains(where: { $0.kind == .pipeExpander && ($0.remainingPipes ?? 0) > 0 }) {
            gap *= 1.3
        }
        if activePowerUps.contains(where: { $0.kind == .pipeSqueeze && ($0.remainingPipes ?? 0) > 0 }) {
            gap *= 0.8
        }

        // --- Single-pass pipe iteration: target tracking, collision, scoring ---
        var targetGapY: CGFloat = GK.duckStartY
        var nearestDist: CGFloat = .greatestFiniteMagnitude

        for child in pipeNodes {
            let pipeX = child.position.x
            let dist = pipeX - GK.duckStartX

            // Find nearest pipe ahead of the bot
            if dist > -(GK.pipeWidth / 2) && dist < nearestDist {
                if let trigger = child.childNode(withName: "scoreTrigger") {
                    targetGapY = trigger.position.y
                    nearestDist = dist
                }
            }

            // Pipe collision (only check pipes near the bot's X)
            if abs(dist) < GK.pipeWidth / 2 + botR * 0.6 {
                if let trigger = child.childNode(withName: "scoreTrigger") {
                    let gapY = trigger.position.y
                    let gapTop = gapY + gap / 2 - 14
                    let gapBottom = gapY - gap / 2 + 14
                    if posY + botR > gapTop || posY - botR < gapBottom {
                        if hasPlotArmor {
                            // Safety net: nudge into gap
                            if posY + botR > gapTop {
                                posY = gapTop - botR
                            }
                            if posY - botR < gapBottom {
                                posY = gapBottom + botR
                            }
                            velocity = 0
                        } else {
                            die()
                            return
                        }
                    }
                }
            }

            // Bot scoring — pipe passed behind the bot
            if let pipeName = child.name, pipeName.hasPrefix("pipe_"),
               pipeX < GK.duckStartX - GK.pipeWidth / 2 {
                if !pipesPassed.contains(pipeName) {
                    pipesPassed.insert(pipeName)
                    score += 1
                    updateScoreHUD()
                    onScoreChanged?(score)

                    // Notify AI of scoring (for fatigue recovery & death pressure)
                    ai?.onScored()
                }
            }
        }

        // --- AI decision ---
        if let ai = ai {
            let shouldFlap = ai.shouldFlap(
                currentTime: gameTime,
                dt: dt,
                birdY: posY,
                velocity: velocity,
                nextGapY: targetGapY,
                nextGapDist: nearestDist,
                pipeGap: gap
            )

            if shouldFlap {
                velocity = GK.flapImpulse
            }
        }

        // --- Apply position & rotation ---
        bot.position.y = posY

        let rotTarget = velocity > 0
            ? min(velocity / GK.flapImpulse * 0.4, 0.4)
            : max(velocity / 400, -CGFloat.pi / 2)
        bot.zRotation += (rotTarget - bot.zRotation) * 0.10
    }

    // MARK: - Plot Armor

    /// Plot armor is active only when the bot is below a safe score threshold
    /// and hasn't entered its death spiral yet. This is a safety net for the
    /// behavioral model — well-tuned profiles should rarely trigger it.
    private var hasPlotArmor: Bool {
        guard let threshold = plotArmorUntil else { return false }
        if ai?.isInDeathSpiral == true { return false }
        return score < threshold
    }

    // MARK: - Death

    /// Plays the bot death animation (tumble + fall + fade) and fires `onBotDied`.
    private func die() {
        alive = false
        guard let bot = sprite else { return }

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
    ///
    /// - Parameter skin: Duck skin for the new bot sprite textures.
    func reset(skin: DuckSkin) {
        sprite?.removeFromParent()
        sprite = nil
        score = 0
        pipesPassed.removeAll()
        ai?.reset()
        setup(skin: skin, difficulty: legacyDiff, profile: profile, deathScore: plotArmorUntil.map { $0 + 5 })
        updateScoreHUD()
    }
}
