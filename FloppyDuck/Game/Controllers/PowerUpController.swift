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

    private let spawner: PowerUpSpawnManager

    // Shield (visual node managed by addShieldVisual/removeShieldVisual)
    private var shieldCooldown: Bool = false

    // Speed modifier grace period — smooth lerp instead of snap-back
    // when slowMotion or speedBurst expires.
    private var speedModifier: CGFloat = 1.0

    // Expiry warning state — tracks which power-ups are in "wearing off" phase
    // so we only trigger the warning animation once per power-up.
    private var expiryWarningActive: Set<UUID> = []
    private let duckExpiryBlinkKey = "expiryWarn_duckBlink"

    // MARK: - Callbacks

    /// Called when a power-up is collected (before activation). Use for achievement tracking.
    var onPowerUpCollected: ((PowerUpKind) -> Void)?

    /// Called when a shield absorbs a hit. Use for shield-usage stats.
    var onShieldConsumed: (() -> Void)?

    /// Called when a power-up enters the "wearing off" warning phase.
    var onPowerUpWearingOff: ((PowerUpKind) -> Void)?

    /// Called when foggy activates (true) or deactivates (false).
    /// GameScene uses this to add/remove the fog overlay sprite.
    var onFoggyStateChanged: ((Bool) -> Void)?

    /// Called when a mystery box is collected. The callback receives the
    /// pre-selected `PowerUpKind` and a `completion` block. The receiver
    /// should play the slot-machine animation and then call `completion()`
    /// to apply the power-up.
    var onMysteryBoxCollected: ((PowerUpKind, @escaping () -> Void) -> Void)?

    /// Override for collected-label parent node. When set, labels are added here
    /// instead of worldNode — prevents shake during death screen-shake.
    weak var labelParentOverride: SKNode?

    // MARK: - Init

    init(worldNode: SKNode,
         pipeLayer: SKNode,
         duck: SKSpriteNode?,
         difficulty: DifficultyManager,
         seed: Int? = nil) {
        self.worldNode = worldNode
        self.pipeLayer = pipeLayer
        self.duck = duck
        self.difficulty = difficulty
        self.spawner = PowerUpSpawnManager(seed: seed)
    }

    /// Re-bind after a duck is recreated (e.g. quick-retry resets the sprite).
    func setDuck(_ duck: SKSpriteNode?) {
        self.duck = duck
    }

    /// Power-up kinds that should never spawn (forwarded to the spawn manager).
    var excludedKinds: Set<PowerUpKind> {
        get { spawner.excludedKinds }
        set { spawner.excludedKinds = newValue }
    }

    func debugQueuePowerUpForNextPipe(_ kind: PowerUpKind) {
        pendingPowerUpKind = kind
    }

    // MARK: - Per-Frame Update

    /// Tick power-up timers and speed modifier; call once per frame from the game update loop.
    func update(dt: TimeInterval, currentTime: TimeInterval) {
        tickExpiryWarnings(currentTime: currentTime)
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

    /// Base gravity from difficulty tier without any player power-up modifiers.
    /// This is used for the global `physicsWorld.gravity` so bots and other
    /// physics bodies are never affected by the player's power-ups.
    var baseGravity: CGFloat { difficulty.effectiveGravity }

    /// Gravity adjusted for active power-ups (dizzyDuck inverts, heavyDuck amplifies).
    /// Applied only to the player duck's velocity each frame, never globally.
    var effectiveGravity: CGFloat {
        var gravity = baseGravity
        if hasActive(.heavyDuck) {
            gravity *= 1.5
        }
        if hasActive(.featherweight) {
            gravity *= 0.6
        }
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
            gap *= 0.84
        }
        return gap
    }

    /// Pipe scroll speed with smooth speed modifier grace period.
    var effectivePipeSpeed: CGFloat {
        difficulty.effectivePipeSpeed * speedModifier
    }

    /// Flap impulse adjusted for dizzyDuck (inverted controls) and megaFlap.
    var effectiveFlapImpulse: CGFloat {
        let base = difficulty.effectiveFlapImpulse
        var impulse = hasActive(.dizzyDuck) ? -base : base
        if hasActive(.megaFlap) { impulse *= 1.3 }
        return impulse
    }

    /// Whether the duck should phase through pipes (ghostDuck).
    var isGhostActive: Bool { hasActive(.ghostDuck) }

    /// Whether the bread magnet is active and has remaining pipe charges.
    var isBreadMagnetActive: Bool { hasActivePipeCounted(.breadMagnet) }

    /// Whether double-points is active and has remaining pipe charges.
    var isDoublePointsActive: Bool { hasActivePipeCounted(.doublePoints) }

    /// Whether heavy duck gravity boost is active.
    var isHeavyDuckActive: Bool { hasActive(.heavyDuck) }

    /// Whether the foggy debuff (visibility reduction) is active.
    var isFoggyActive: Bool { hasActive(.foggy) }

    /// Whether the featherweight buff (reduced gravity) is active.
    var isFeatherweightActive: Bool { hasActive(.featherweight) }

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

        // Mystery box: resolve to a random power-up, but defer activation
        // so the slot-machine animation can play first.
        if kind == .mysteryBox {
            let resolvedKind = spawner.randomMysteryBoxReward()

            if let callback = onMysteryBoxCollected {
                callback(resolvedKind) { [weak self] in
                    guard let self else { return }
                    self.showCollectedLabel(kind: resolvedKind)
                    self.activate(kind: resolvedKind)
                    Haptic.score()
                    SoundManager.shared.play(resolvedKind.isPositive ? .powerUp : .debuff)
                }
            } else {
                // Fallback: instant if no animation callback registered
                showCollectedLabel(kind: resolvedKind)
                activate(kind: resolvedKind)
                Haptic.score()
                SoundManager.shared.play(resolvedKind.isPositive ? .powerUp : .debuff)
            }
            return
        }

        // Non-mystery-box: resolve and activate immediately
        let resolvedKind = kind
        showCollectedLabel(kind: resolvedKind)
        activate(kind: resolvedKind)

        Haptic.score()

        if resolvedKind.isPositive {
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

        // Golden burst on duck — pre-rendered texture instead of SKShapeNode
        guard let duck else { return }
        let burstTex = TextureFactory.shared.glowCircleTexture(
            radius: GK.duckRadius * 2,
            color: UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1)
        )
        let burst = SKSpriteNode(texture: burstTex)
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

    /// Attracts nearby bread toward the duck using cached bread records.
    /// Call every frame while `isBreadMagnetActive`.
    /// - Parameter breadRecords: Cached active bread records from the scene
    ///   (avoids per-frame child-tree scans with string-name checks).
    func applyBreadMagnetEffect(breadRecords: [ActiveBreadRecord]) {
        guard let duck else { return }
        let magnetRadius: CGFloat = 120
        let magnetStrength: CGFloat = 3.0

        for record in breadRecords {
            guard let breadNode = record.node else { continue }
            let breadWorldPos = breadNode.convert(CGPoint.zero, to: worldNode)
            let dx = duck.position.x - breadWorldPos.x
            let dy = duck.position.y - breadWorldPos.y
            let distance = sqrt(dx * dx + dy * dy)

            if distance < magnetRadius && distance > 1 {
                let factor = magnetStrength * (1.0 - distance / magnetRadius)
                breadNode.position.x += dx / distance * factor
                breadNode.position.y += dy / distance * factor
            }
        }
    }

    // MARK: - Ghost Duck Per-Frame Visual

    /// Maintains ghost transparency each frame while ghostDuck is active.
    func applyGhostAlpha() {
        if hasActive(.ghostDuck), duck?.action(forKey: duckExpiryBlinkKey) == nil {
            duck?.alpha = 0.4
        }
    }

    // MARK: - Death Cleanup

    /// Restores duck alpha and removes power-up visuals (shield ring, ghost glow)
    /// during death without resetting the full power-up state. Call from `die()`.
    func cleanupDuckVisuals() {
        for powerUp in activePowerUps {
            stopExpiryWarning(for: powerUp.kind)
        }
        expiryWarningActive.removeAll()

        // Remove fog overlay on death
        if hasActive(.foggy) {
            onFoggyStateChanged?(false)
        }

        duck?.alpha = 1.0
        duck?.colorBlendFactor = 0
        duck?.removeAction(forKey: duckExpiryBlinkKey)
        duck?.removeAction(forKey: "duckScaleAnim")
        duck?.setScale(1.0)
        removeShieldVisual()
        removeGhostGlow()
    }

    // MARK: - Reset

    /// Clear all power-up state for a new game / retry.
    func reset() {
        for powerUp in activePowerUps {
            stopExpiryWarning(for: powerUp.kind)
        }
        // Remove foggy overlay if active
        if hasActive(.foggy) {
            onFoggyStateChanged?(false)
        }
        activePowerUps.removeAll()
        expiryWarningActive.removeAll()
        removeShieldVisual()
        removeGhostGlow()
        duck?.removeAction(forKey: duckExpiryBlinkKey)
        duck?.alpha = 1.0
        duck?.removeAction(forKey: "duckScaleAnim")
        duck?.setScale(1.0)
        shieldCooldown = false
        pendingPowerUpKind = nil
        speedModifier = 1.0
        spawner.reset()
    }

    // MARK: - Activation

    private func activate(kind: PowerUpKind) {
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
        case .tinyDuck, .jumboDuck:
            applyDuckScale()
        case .foggy:
            onFoggyStateChanged?(true)
        default:
            break  // featherweight, mysteryBox (resolved before here), etc. — modifier-only
        }
    }

    // MARK: - Deactivation

    private func deactivate(_ powerUp: ActivePowerUp) {
        expiryWarningActive.remove(powerUp.id)
        stopExpiryWarning(for: powerUp.kind)

        switch powerUp.kind {
        case .shield:
            removeShieldVisual()
        case .dizzyDuck:
            applyDizzyTransition()
        case .ghostDuck:
            deactivateGhostDuck()
        case .tinyDuck, .jumboDuck:
            applyDuckScale()
        case .foggy:
            onFoggyStateChanged?(false)
        default:
            break  // featherweight — gravity modifier auto-stops when removed from activePowerUps
        }
    }

    // MARK: - Expiry Warning Animations

    /// Checks all active power-ups for the "wearing off" phase and triggers
    /// per-type visual warnings exactly once per power-up instance.
    private func tickExpiryWarnings(currentTime: TimeInterval) {
        for powerUp in activePowerUps {
            guard powerUp.isWearingOff(currentTime: currentTime),
                  !expiryWarningActive.contains(powerUp.id) else { continue }

            expiryWarningActive.insert(powerUp.id)
            startExpiryWarning(for: powerUp)
            onPowerUpWearingOff?(powerUp.kind)
        }
    }

    /// Dispatches to the correct per-type warning animation.
    private func startExpiryWarning(for powerUp: ActivePowerUp) {
        guard let duck else { return }
        startDuckExpiryBlink(on: duck)

        switch powerUp.kind {
        case .dizzyDuck:
            break  // Shared duck blink handles opacity warning.

        case .slowMotion:
            // Speed up wing flap to signal normal speed returning
            let fastWing = SKAction.animate(with: duckTexturesForWarning(), timePerFrame: 0.04)
            duck.removeAction(forKey: "wings")
            duck.run(SKAction.repeatForever(fastWing), withKey: "expiryWarn_slowMotion")

        case .ghostDuck:
            break  // Shared duck blink handles opacity warning.

        case .speedBurst:
            // Vibrate/shake horizontally
            let shake = SKAction.sequence([
                SKAction.moveBy(x: 2, y: 0, duration: 0.03),
                SKAction.moveBy(x: -4, y: 0, duration: 0.03),
                SKAction.moveBy(x: 2, y: 0, duration: 0.03),
            ])
            duck.run(SKAction.repeatForever(shake), withKey: "expiryWarn_speedBurst")

        case .shield:
            break  // Shield is consumed on hit, no time-based expiry

        case .pipeExpander:
            // Green tint blink on the duck
            let tintOn = SKAction.colorize(with: UIColor(red: 0.3, green: 0.8, blue: 0.3, alpha: 1), colorBlendFactor: 0.4, duration: 0.15)
            let tintOff = SKAction.colorize(withColorBlendFactor: 0.0, duration: 0.15)
            duck.run(SKAction.repeatForever(SKAction.sequence([tintOn, tintOff])), withKey: "expiryWarn_pipeExpander")

        case .breadMagnet:
            // Gold glow blink
            let tintOn = SKAction.colorize(with: UIColor(red: 0.85, green: 0.68, blue: 0.3, alpha: 1), colorBlendFactor: 0.4, duration: 0.15)
            let tintOff = SKAction.colorize(withColorBlendFactor: 0.0, duration: 0.15)
            duck.run(SKAction.repeatForever(SKAction.sequence([tintOn, tintOff])), withKey: "expiryWarn_breadMagnet")

        case .doublePoints:
            // Bright gold pulse blink
            let tintOn = SKAction.colorize(with: UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1), colorBlendFactor: 0.4, duration: 0.15)
            let tintOff = SKAction.colorize(withColorBlendFactor: 0.0, duration: 0.15)
            duck.run(SKAction.repeatForever(SKAction.sequence([tintOn, tintOff])), withKey: "expiryWarn_doublePoints")

        case .pipeSqueeze:
            // Red warning blink
            let tintOn = SKAction.colorize(with: UIColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1), colorBlendFactor: 0.4, duration: 0.15)
            let tintOff = SKAction.colorize(withColorBlendFactor: 0.0, duration: 0.15)
            duck.run(SKAction.repeatForever(SKAction.sequence([tintOn, tintOff])), withKey: "expiryWarn_pipeSqueeze")

        case .heavyDuck:
            // Brown tint blink + slight vertical shake
            let shake = SKAction.sequence([
                SKAction.moveBy(x: 0, y: -2, duration: 0.04),
                SKAction.moveBy(x: 0, y: 4, duration: 0.04),
                SKAction.moveBy(x: 0, y: -2, duration: 0.04),
            ])
            duck.run(SKAction.repeatForever(shake), withKey: "expiryWarn_heavyDuck")

        case .tinyDuck:
            // Light blue pulse as duck begins to regrow
            let tintOn = SKAction.colorize(with: UIColor(red: 0.4, green: 0.8, blue: 1.0, alpha: 1), colorBlendFactor: 0.3, duration: 0.15)
            let tintOff = SKAction.colorize(withColorBlendFactor: 0.0, duration: 0.15)
            duck.run(SKAction.repeatForever(SKAction.sequence([tintOn, tintOff])), withKey: "expiryWarn_tinyDuck")

        case .megaFlap:
            // Amber burst pulse
            let tintOn = SKAction.colorize(with: UIColor(red: 1.0, green: 0.7, blue: 0.2, alpha: 1), colorBlendFactor: 0.4, duration: 0.12)
            let tintOff = SKAction.colorize(withColorBlendFactor: 0.0, duration: 0.12)
            duck.run(SKAction.repeatForever(SKAction.sequence([tintOn, tintOff])), withKey: "expiryWarn_megaFlap")

        case .jumboDuck:
            // Orange shake as duck begins to shrink back
            let shrinkShake = SKAction.sequence([
                SKAction.moveBy(x: 2, y: 2, duration: 0.04),
                SKAction.moveBy(x: -4, y: -2, duration: 0.04),
                SKAction.moveBy(x: 2, y: 0, duration: 0.04),
            ])
            duck.run(SKAction.repeatForever(shrinkShake), withKey: "expiryWarn_jumboDuck")

        case .featherweight:
            // Sky blue pulse as gravity returns to normal
            let tintOn = SKAction.colorize(with: UIColor(red: 0.55, green: 0.76, blue: 0.94, alpha: 1), colorBlendFactor: 0.3, duration: 0.15)
            let tintOff = SKAction.colorize(withColorBlendFactor: 0.0, duration: 0.15)
            duck.run(SKAction.repeatForever(SKAction.sequence([tintOn, tintOff])), withKey: "expiryWarn_featherweight")

        case .foggy:
            // Gray blink as fog starts to lift
            let tintOn = SKAction.colorize(with: UIColor(red: 0.5, green: 0.53, blue: 0.59, alpha: 1), colorBlendFactor: 0.3, duration: 0.12)
            let tintOff = SKAction.colorize(withColorBlendFactor: 0.0, duration: 0.12)
            duck.run(SKAction.repeatForever(SKAction.sequence([tintOn, tintOff])), withKey: "expiryWarn_foggy")

        case .mysteryBox:
            break  // Mystery box is resolved instantly — never has an active duration
        }
    }

    /// Cleans up the expiry warning animation for a specific power-up kind.
    private func stopExpiryWarning(for kind: PowerUpKind) {
        guard let duck else { return }

        duck.removeAction(forKey: "expiryWarn_\(kind.rawValue)")
        if expiryWarningActive.isEmpty {
            duck.removeAction(forKey: duckExpiryBlinkKey)
            restoreDuckAlphaAfterExpiryBlink()
        }

        switch kind {
        case .dizzyDuck:
            if !hasActive(.ghostDuck) {
                duck.alpha = 1.0
            }
        case .slowMotion:
            // Restore normal wing animation speed
            restoreNormalWingAnimation()
        case .ghostDuck:
            // deactivateGhostDuck handles alpha restore
            break
        case .speedBurst:
            // Reset position in case shake left it offset
            break
        case .pipeExpander, .breadMagnet, .doublePoints, .pipeSqueeze:
            duck.colorBlendFactor = 0
        case .heavyDuck:
            // Reset position in case shake left it offset
            break
        case .shield:
            break
        case .tinyDuck, .megaFlap, .jumboDuck:
            duck.colorBlendFactor = 0
        case .featherweight, .foggy:
            duck.colorBlendFactor = 0
        case .mysteryBox:
            break  // instant — no warning to stop
        }
    }

    /// Every expiring power-up gets the same readable duck blink when it reaches
    /// the warning phase. Per-kind warnings below can layer extra color, shake,
    /// or wing-speed cues on top of this shared signal.
    private func startDuckExpiryBlink(on duck: SKSpriteNode) {
        guard duck.action(forKey: duckExpiryBlinkKey) == nil else { return }

        let blink = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.2, duration: 0.09),
            SKAction.fadeAlpha(to: 1.0, duration: 0.09),
        ])
        duck.run(SKAction.repeatForever(blink), withKey: duckExpiryBlinkKey)
    }

    private func restoreDuckAlphaAfterExpiryBlink() {
        guard let duck else { return }
        duck.alpha = hasActive(.ghostDuck) ? 0.4 : 1.0
    }

    /// Returns duck textures for the fast-wing warning animation.
    /// Uses cached textures from the GameScene via a stored reference.
    private func duckTexturesForWarning() -> [SKTexture] {
        return cachedDuckTextures
    }

    /// Duck wing textures — set by GameScene after setup so we can
    /// run modified wing animations during expiry warnings.
    private(set) var cachedDuckTextures: [SKTexture] = []

    /// Store duck textures for expiry warning wing animations.
    func setDuckTextures(_ textures: [SKTexture]) {
        cachedDuckTextures = textures
    }

    /// Restores the normal wing animation (0.10s per frame).
    private func restoreNormalWingAnimation() {
        guard let duck, !cachedDuckTextures.isEmpty else { return }
        let normalWing = SKAction.animate(with: cachedDuckTextures, timePerFrame: 0.10)
        duck.run(SKAction.repeatForever(normalWing), withKey: "wings")
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

        // Physics body
        collectible.physicsBody = SKPhysicsBody(circleOfRadius: PowerUpKind.collectibleSize * 0.85)
        collectible.physicsBody?.isDynamic = false
        collectible.physicsBody?.categoryBitMask = GK.powerUpCategory
        collectible.physicsBody?.contactTestBitMask = GK.duckCategory
        collectible.physicsBody?.collisionBitMask = 0

        pipeNode.addChild(collectible)
    }

    // MARK: - Shield Visual
    //
    // PERF: Replaced SKShapeNode with pre-rendered glow texture sprite.

    private var shieldSpriteNode: SKSpriteNode?

    private func addShieldVisual() {
        guard shieldSpriteNode == nil, let duck else { return }
        let tex = TextureFactory.shared.glowCircleTexture(
            radius: GK.duckRadius * 1.5,
            color: UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1)
        )
        let shield = SKSpriteNode(texture: tex)
        shield.zPosition = 1
        shield.name = "shieldRing"
        duck.addChild(shield)
        shieldSpriteNode = shield

        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.1, duration: 0.5),
            SKAction.scale(to: 0.95, duration: 0.5),
        ])
        shield.run(SKAction.repeatForever(pulse))
    }

    private func removeShieldVisual() {
        shieldSpriteNode?.removeFromParent()
        shieldSpriteNode = nil
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
    //
    // PERF: Replaced SKShapeNode with pre-rendered glow texture sprite.

    private var ghostGlowSpriteNode: SKSpriteNode?

    private func activateGhostDuck() {
        guard let duck else { return }

        // Semi-transparent
        duck.alpha = 0.4

        // Disable pipe collision while ghost is active
        duck.physicsBody?.contactTestBitMask = GK.groundCategory | GK.powerUpCategory | GK.breadCategory
        duck.physicsBody?.collisionBitMask = GK.groundCategory

        // Subtle white glow behind duck — pre-rendered texture
        guard ghostGlowSpriteNode == nil else { return }
        let tex = TextureFactory.shared.glowCircleTexture(
            radius: GK.duckRadius * 1.8,
            color: .white
        )
        let glow = SKSpriteNode(texture: tex)
        glow.alpha = 0.15
        glow.zPosition = -1
        glow.name = "ghostGlow"

        let pulse = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.08, duration: 0.6),
            SKAction.fadeAlpha(to: 0.2, duration: 0.6),
        ])
        glow.run(SKAction.repeatForever(pulse))

        duck.addChild(glow)
        ghostGlowSpriteNode = glow
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
        ghostGlowSpriteNode?.removeFromParent()
        ghostGlowSpriteNode = nil
    }

    // MARK: - Duck Scale (TinyDuck / JumboDuck)

    /// Compute the target duck scale from active size-modifying power-ups.
    /// If both tinyDuck and jumboDuck are active, they cancel out to 1.0.
    private var targetDuckScale: CGFloat {
        let tiny = hasActive(.tinyDuck)
        let jumbo = hasActive(.jumboDuck)
        if tiny && jumbo { return 1.0 }
        if tiny { return 0.5 }
        if jumbo { return 1.3 }
        return 1.0
    }

    /// Apply the current duck scale with a smooth animation.
    private func applyDuckScale() {
        guard let duck else { return }
        let target = targetDuckScale
        duck.removeAction(forKey: "duckScaleAnim")
        duck.run(SKAction.scale(to: target, duration: 0.15), withKey: "duckScaleAnim")

        let scaledRadius = GK.duckRadius * 0.72 * target
        let body = SKPhysicsBody(circleOfRadius: scaledRadius)
        body.categoryBitMask = GK.duckCategory
        body.contactTestBitMask = duck.physicsBody?.contactTestBitMask ?? (GK.pipeCategory | GK.groundCategory | GK.powerUpCategory)
        body.collisionBitMask = duck.physicsBody?.collisionBitMask ?? GK.groundCategory
        body.allowsRotation = false
        body.restitution = 0
        body.linearDamping = 0
        body.fieldBitMask = duck.physicsBody?.fieldBitMask ?? GK.playerGravityFieldCategory
        body.isDynamic = duck.physicsBody?.isDynamic ?? true
        if let velocity = duck.physicsBody?.velocity {
            body.velocity = velocity
        }
        duck.physicsBody = body
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
