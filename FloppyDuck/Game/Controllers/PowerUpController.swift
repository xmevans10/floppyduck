import SpriteKit

// MARK: - PowerUpController

/// Owns all power-up logic: spawning collectibles, activating/deactivating effects,
/// managing the `activePowerUps` array, and exposing gameplay modifiers that
/// `GameScene` reads each frame to adjust physics and pipe generation.
///
/// Usage:
///   1. Create after scene setup:
///      ```
///      powerUpCtrl = PowerUpController(worldNode: worldNode,
///                                      pipeLayer: pipeLayer,
///                                      duck: duck,
///                                      difficulty: difficulty)
///      ```
///   2. Call `powerUpCtrl.update(dt:currentTime:)` every frame.
///   3. Read modifiers (`effectiveGravity`, `effectivePipeGap`, etc.) when building
///      pipes or applying physics.
///   4. Call `collectPowerUp(node:)` from `didBegin(contact:)`.
///   5. Call `onPipeScored(...)` each score event.
///   6. Call `reset()` on retry.
final class PowerUpController {

    // MARK: - Dependencies (unowned – scene keeps these alive)

    private unowned let worldNode: SKNode
    private unowned let pipeLayer: SKNode
    private weak var duck: SKSpriteNode?
    private unowned let difficulty: DifficultyManager

    // MARK: - State

    private(set) var activePowerUps: [ActivePowerUp] = []

    /// Kind queued by the spawn manager, attached to the next pipe.
    private(set) var pendingPowerUpKind: PowerUpKind?

    private let spawner = PowerUpSpawnManager()

    // Shield
    private var shieldNode: SKShapeNode?
    private var shieldCooldown: Bool = false
    private var shieldCooldownAction: SKAction?

    // Ghost duck
    private var ghostGlowNode: SKShapeNode?

    // Speed modifier grace period — smooth lerp instead of snap-back
    // when slowMotion or speedBurst expires.
    private var speedModifier: CGFloat = 1.0

    // MARK: - Callbacks

    /// Called when a power-up is collected (before activation). Use for achievement tracking.
    var onPowerUpCollected: ((PowerUpKind) -> Void)?

    /// Called when a shield absorbs a hit. Use for shield-usage stats.
    var onShieldConsumed: (() -> Void)?

    /// Override for collected-label parent node. When set, labels are added here
    /// instead of worldNode — prevents shake during death screen-shake.
    weak var labelParentOverride: SKNode?

    // MARK: - Init

    init(worldNode: SKNode,
         pipeLayer: SKNode,
         duck: SKSpriteNode?,
         difficulty: DifficultyManager) {
        self.worldNode = worldNode
        self.pipeLayer = pipeLayer
        self.duck = duck
        self.difficulty = difficulty
    }

    /// Re-bind after a duck is recreated (e.g. quick-retry resets the sprite).
    func setDuck(_ duck: SKSpriteNode?) {
        self.duck = duck
    }

    // MARK: - Per-Frame Update

    /// Tick power-up timers and speed modifier; call once per frame from the game update loop.
    func update(dt: TimeInterval, currentTime: TimeInterval) {
        tickExpiry(currentTime: currentTime)
        updateSpeedModifier(dt: dt)
    }

    /// Smooth lerp for speed modifier transitions.
    /// Ramp-off (back to 1.0) is slow (0.25/s) for graceful transitions.
    /// Ramp-on (to target) is fast (2.0/s) so effects feel immediate.
    private func updateSpeedModifier(dt: TimeInterval) {
        var target: CGFloat = 1.0
        if hasActive(.slowMotion) { target = 0.65 }
        if hasActive(.speedBurst) { target = 1.4 }

        let isRampingOff = target == 1.0 && speedModifier != 1.0
        let rate: CGFloat = isRampingOff ? 0.25 : 2.0

        if abs(speedModifier - target) < 0.01 {
            speedModifier = target
        } else {
            let dir: CGFloat = target > speedModifier ? 1.0 : -1.0
            speedModifier += dir * rate * CGFloat(dt)
            speedModifier = dir > 0
                ? min(speedModifier, target)
                : max(speedModifier, target)
        }
    }

    // MARK: - Queries

    /// Whether a power-up of the given kind is currently active.
    func hasActive(_ kind: PowerUpKind) -> Bool {
        activePowerUps.contains { $0.kind == kind }
    }

    /// Whether a pipe-count-based power-up still has remaining pipes.
    func hasActivePipeCounted(_ kind: PowerUpKind) -> Bool {
        activePowerUps.contains { $0.kind == kind && ($0.remainingPipes ?? 0) > 0 }
    }

    /// Whether the shield is active (not yet consumed).
    var hasActiveShield: Bool { hasActive(.shield) }

    /// Whether the shield was just consumed and the brief invincibility window is active.
    var isShieldOnCooldown: Bool { shieldCooldown }

    // MARK: - Gameplay Modifiers

    /// Gravity adjusted for active power-ups (dizzyDuck inverts it).
    var effectiveGravity: CGFloat {
        var gravity = difficulty.effectiveGravity
        if hasActive(.dizzyDuck) {
            gravity = -gravity
        }
        return gravity
    }

    /// Pipe gap adjusted for pipeExpander / pipeSqueeze.
    var effectivePipeGap: CGFloat {
        var gap = difficulty.effectivePipeGap
        if hasActivePipeCounted(.pipeExpander) {
            gap *= 1.3
        }
        if hasActivePipeCounted(.pipeSqueeze) {
            gap *= 0.8
        }
        return gap
    }

    /// Pipe scroll speed with smooth speed modifier grace period.
    var effectivePipeSpeed: CGFloat {
        difficulty.effectivePipeSpeed * speedModifier
    }

    /// Flap impulse adjusted for dizzyDuck (inverted controls).
    var effectiveFlapImpulse: CGFloat {
        let base = difficulty.effectiveFlapImpulse
        return hasActive(.dizzyDuck) ? -base : base
    }

    /// Whether the duck should phase through pipes (ghostDuck).
    var isGhostActive: Bool { hasActive(.ghostDuck) }

    /// Whether the bread magnet is active and has remaining pipe charges.
    var isBreadMagnetActive: Bool { hasActivePipeCounted(.breadMagnet) }

    // MARK: - Spawn Flow

    /// Called each time a pipe is scored. Returns a `PowerUpKind` to queue, or nil.
    @discardableResult
    func onPipeScored(currentScore: Int, tier: DifficultyTier) -> PowerUpKind? {
        // Decrement remaining-pipe counters on active power-ups
        for i in activePowerUps.indices {
            if activePowerUps[i].remainingPipes != nil {
                activePowerUps[i].remainingPipes! -= 1
            }
        }

        // Ask the spawn manager if a new power-up should appear
        if let kind = spawner.onPipeScored(currentScore: currentScore, tier: tier) {
            pendingPowerUpKind = kind
            return kind
        }
        return nil
    }

    /// Consumes and returns the pending power-up kind, or nil if none queued.
    /// GameScene uses this to position the collectible in the gap between pipes.
    func consumePendingKind() -> PowerUpKind? {
        guard let kind = pendingPowerUpKind else { return nil }
        pendingPowerUpKind = nil
        return kind
    }

    /// Consumes the pending kind and attaches a collectible node to the given pipe.
    /// Call this inside `spawnPipe()` right after building the pipe geometry.
    ///
    /// - Returns: `true` if a collectible was added.
    @discardableResult
    func attachPendingCollectible(to pipeNode: SKNode, gapY: CGFloat) -> Bool {
        guard let kind = pendingPowerUpKind else { return false }
        pendingPowerUpKind = nil
        addCollectibleNode(to: pipeNode, gapY: gapY, kind: kind)
        return true
    }

    // MARK: - Collection

    /// Handle contact with a power-up collectible node. Call from `didBegin(contact:)`.
    func collectPowerUp(node: SKNode) {
        guard let name = node.name, name.hasPrefix("powerUp_") else { return }
        let kindStr = String(name.dropFirst("powerUp_".count))
        guard let kind = PowerUpKind(rawValue: kindStr) else { return }

        node.removeFromParent()

        onPowerUpCollected?(kind)
        showCollectedLabel(kind: kind)
        activate(kind: kind)

        Haptic.score()

        if kind.isPositive {
            SoundManager.shared.play(.powerUp)
        } else {
            SoundManager.shared.play(.debuff)
        }
    }

    // MARK: - Shield Consumption

    /// Consumes the shield, plays the visual burst, and starts the brief cooldown
    /// window during which repeated pipe contacts are ignored.
    /// Call from `didBegin(contact:)` when a pipe hit occurs while shielded.
    func consumeShield(scene: SKScene) {
        activePowerUps.removeAll { $0.kind == .shield }
        removeShieldVisual()
        shieldCooldown = true
        onShieldConsumed?()

        // Brief invincibility after shield break
        scene.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.5),
            SKAction.run { [weak self] in
                self?.shieldCooldown = false
            }
        ]), withKey: "shieldCooldown")

        Haptic.score()
        SoundManager.shared.play(.powerUp)

        // Golden burst on duck
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

        // Duck blinks to indicate brief invincibility
        let blink = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.3, duration: 0.1),
            SKAction.fadeAlpha(to: 1.0, duration: 0.1),
        ])
        duck.run(SKAction.repeat(blink, count: 3), withKey: "shieldBlink")
    }

    // MARK: - Bread Magnet

    /// Attracts nearby bread toward the duck. Call every frame while `isBreadMagnetActive`.
    func applyBreadMagnetEffect() {
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

    // MARK: - Ghost Duck Per-Frame Visual

    /// Maintains ghost transparency each frame while ghostDuck is active.
    func applyGhostAlpha() {
        if hasActive(.ghostDuck) {
            duck?.alpha = 0.4
        }
    }

    // MARK: - Death Cleanup

    /// Restores duck alpha and removes power-up visuals (shield ring, ghost glow)
    /// during death without resetting the full power-up state. Call from `die()`.
    func cleanupDuckVisuals() {
        duck?.alpha = 1.0
        removeShieldVisual()
        removeGhostGlow()
    }

    // MARK: - Reset

    /// Clear all power-up state for a new game / retry.
    func reset() {
        activePowerUps.removeAll()
        removeShieldVisual()
        removeGhostGlow()
        shieldCooldown = false
        pendingPowerUpKind = nil
        speedModifier = 1.0
        spawner.reset()
    }

    // MARK: - Activation

    private func activate(kind: PowerUpKind) {
        // Use lastUpdate == 0 before first frame; callers provide currentTime via update()
        // but activation happens during contact, so we store the time from the active run loop.
        let now = CACurrentMediaTime()
        let powerUp = ActivePowerUp(
            kind: kind,
            startTime: now,
            remainingPipes: kind.initialPipeCount
        )
        activePowerUps.append(powerUp)

        switch kind {
        case .shield:
            addShieldVisual()
        case .dizzyDuck:
            applyDizzyTransition()
        case .ghostDuck:
            activateGhostDuck()
        default:
            break
        }
    }

    // MARK: - Deactivation

    private func deactivate(_ powerUp: ActivePowerUp) {
        switch powerUp.kind {
        case .shield:
            removeShieldVisual()
        case .dizzyDuck:
            applyDizzyTransition()
        case .ghostDuck:
            deactivateGhostDuck()
        default:
            break
        }
    }

    // MARK: - Expiry Tick

    private func tickExpiry(currentTime: TimeInterval) {
        var expired: [ActivePowerUp] = []
        activePowerUps.removeAll { powerUp in
            if powerUp.isExpired(currentTime: currentTime) {
                expired.append(powerUp)
                return true
            }
            return false
        }
        for powerUp in expired {
            deactivate(powerUp)
        }
    }

    // MARK: - Collectible Node

    private func addCollectibleNode(to pipeNode: SKNode, gapY: CGFloat, kind: PowerUpKind) {
        let collectible = SKNode()
        collectible.name = "powerUp_\(kind.rawValue)"
        collectible.position = CGPoint(x: 0, y: gapY)
        collectible.zPosition = 30

        // Pixel icon visual
        let iconTexture = PixelIconFactory.shared.skTexture(for: kind.pixelIcon)
        let iconSprite = SKSpriteNode(texture: iconTexture)
        iconSprite.setScale(0.8)
        collectible.addChild(iconSprite)

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

        // Physics body
        collectible.physicsBody = SKPhysicsBody(circleOfRadius: PowerUpKind.collectibleSize * 0.6)
        collectible.physicsBody?.isDynamic = false
        collectible.physicsBody?.categoryBitMask = GK.powerUpCategory
        collectible.physicsBody?.contactTestBitMask = GK.duckCategory
        collectible.physicsBody?.collisionBitMask = 0

        pipeNode.addChild(collectible)
    }

    // MARK: - Shield Visual

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

    // MARK: - DizzyDuck Transition

    /// Flips the duck's velocity when dizzyDuck activates or deactivates,
    /// clamped to maxUpSpeed. Also clamps duck Y to safe bounds.
    private func applyDizzyTransition() {
        guard let duck, let body = duck.physicsBody else { return }

        let flippedVelocity = max(min(-body.velocity.dy * 0.85, GK.maxUpSpeed), -GK.maxUpSpeed)
        body.velocity = CGVector(dx: 0, dy: flippedVelocity)

        let safeMinY = GK.groundHeight + GK.duckRadius * 2
        let safeMaxY = GK.worldHeight - GK.duckRadius * 2
        duck.position.y = min(max(duck.position.y, safeMinY), safeMaxY)
    }

    // MARK: - Ghost Duck Visual

    private func activateGhostDuck() {
        guard let duck else { return }

        // Semi-transparent
        duck.alpha = 0.4

        // Disable pipe collision while ghost is active
        duck.physicsBody?.contactTestBitMask = GK.groundCategory | GK.powerUpCategory | GK.breadCategory
        duck.physicsBody?.collisionBitMask = GK.groundCategory

        // Subtle white glow behind duck
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

        // Re-enable pipe contact detection, but keep physical collision disabled
        // to avoid SpriteKit pushing the duck left during pipe contacts.
        duck.physicsBody?.contactTestBitMask = GK.pipeCategory | GK.groundCategory | GK.powerUpCategory | GK.breadCategory
        duck.physicsBody?.collisionBitMask = GK.groundCategory

        // Remove glow
        removeGhostGlow()
    }

    private func removeGhostGlow() {
        ghostGlowNode?.removeFromParent()
        ghostGlowNode = nil
    }

    // MARK: - Collected Label Popup

    private func showCollectedLabel(kind: PowerUpKind) {
        guard let duck else { return }

        let container = SKNode()
        // Position horizontally centered in the scene (not relative to duck)
        // to prevent clipping at screen edges
        let parentNode = labelParentOverride ?? worldNode
        let centerX = labelParentOverride != nil
            ? (labelParentOverride?.frame.width ?? 0) / 2
            : duck.position.x
        container.position = CGPoint(x: centerX, y: duck.position.y + 40)
        container.zPosition = 300

        let iconTexture = PixelIconFactory.shared.skTexture(for: kind.pixelIcon, pixelScale: 5.0)
        let iconSprite = SKSpriteNode(texture: iconTexture)
        iconSprite.setScale(1.4)  // Larger icon for better visibility
        iconSprite.position = CGPoint(x: 0, y: 14)
        container.addChild(iconSprite)

        let name = SKLabelNode(fontNamed: GK.pixelFontName)
        name.text = kind.displayName
        name.fontSize = 12   // Larger text for readability
        name.fontColor = kind.isPositive
            ? .white
            : UIColor(red: 1.0, green: 0.5, blue: 0.5, alpha: 1)
        name.verticalAlignmentMode = .center
        name.position = CGPoint(x: 0, y: -10)
        container.addChild(name)

        parentNode.addChild(container)

        let floatUp = SKAction.moveBy(x: 0, y: 60, duration: 0.8)
        let fadeOut = SKAction.fadeOut(withDuration: 0.8)
        container.run(SKAction.sequence([
            SKAction.group([floatUp, fadeOut]),
            SKAction.removeFromParent()
        ]))
    }
}
