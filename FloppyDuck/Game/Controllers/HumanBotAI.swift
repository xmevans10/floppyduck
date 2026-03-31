import SpriteKit

// MARK: - Human Bot Profile

/// Replaces the old `BotDifficulty` (noiseRange/flapStrength/errorRate) with
/// parameters modelled on real human motor-control research.
///
/// Key insight from Isaksen et al. (Flappy Bird game-space analysis):
/// humans fail on **timing** (reaction delay + motor imprecision), not aim.
/// They know where the gap is — they mistime when to flap.
///
/// Parameters map to real human data (WPI study, AAMAS 2025):
///   Elite gamers: 150-200 ms reaction time
///   Average gamers: ~300 ms
///   Non-gamers: ~350 ms
struct HumanBotProfile: Hashable, Codable {

    // -- Reaction & Motor --

    /// Base reaction time in seconds. The bot cannot make a new decision
    /// until this much time has passed since the last one.
    let reactionBase: TimeInterval          // 0.15 (expert) → 0.40 (newbie)

    /// Standard deviation of reaction time jitter (gaussian).
    let reactionσ: TimeInterval             // 0.02 → 0.08

    /// Motor noise σ in seconds — once the bot decides to flap, execution
    /// is delayed by |N(0, motorσ)|.  (Isaksen: σ ≈ 0.030 for average player.)
    let motorσ: TimeInterval                // 0.015 → 0.080

    // -- Spatial Perception --

    /// How far ahead (in points) the bot starts reacting to the next pipe.
    /// Experts scan further ahead; beginners only react when pipes are close.
    let perceptionRange: CGFloat            // 320 (expert) → 180 (newbie)

    /// Vertical aim bias σ (points) — slight random offset from true gap center.
    /// Much smaller than old noiseRange because timing is the primary error source.
    let aimBiasσ: CGFloat                   // 2 → 12

    // -- Panic --

    /// Horizontal distance (points) to pipe at which panic triggers.
    let panicDistance: CGFloat              // 50 → 120

    /// Vertical misalignment (points) from gap center required to panic.
    let panicMisalignment: CGFloat          // 40 → 25

    /// Probability of a panic double-flap when panicking.
    let panicFlapChance: Double             // 0.05 → 0.35

    // -- Fatigue / Attention --

    /// Per-second attention decay (1.0 → lower = slower reactions, worse aim).
    let fatigueRate: Double                 // 0.001 → 0.010

    /// Attention recovered when scoring a point (dopamine hit).
    let scoreRecovery: Double               // 0.02 → 0.08

    /// Minimum attention level (floor).
    let attentionFloor: Double              // 0.60 → 0.45

    // -- Death --

    /// When score reaches this, the bot's skill starts degrading toward
    /// a natural-looking death.  Replaces the old "doomed = stop flapping" model.
    let targetScore: Int

    /// How aggressively skill degrades past targetScore.
    /// 0 = no degradation (only used for replay bots), 1.0 = rapid collapse.
    let deathPressureRate: Double           // 0.15 → 0.35
}

// MARK: - Human Bot AI

/// Per-frame decision engine that models human motor control.
///
/// Instead of the old approach (every frame: aim at gap ± noise → flap if below),
/// this system:
///   1. Only perceives pipes within a perception range
///   2. Waits for reaction time before making each decision
///   3. Adds motor noise to flap *timing* (not spatial aim)
///   4. Panics near pipes (double-flaps, rushed decisions)
///   5. Fatigues over a session (slower reactions, worse timing)
///   6. Dies naturally via gradual skill degradation (no "doomed" flag)
final class HumanBotAI {

    // MARK: - Profile (immutable per match)

    let profile: HumanBotProfile

    // MARK: - Mutable State

    /// Time of the last decision point.
    private var lastDecisionTime: TimeInterval = 0

    /// If set, a flap is queued to execute at this time.
    private var queuedFlapTime: TimeInterval?

    /// Current attention level (1.0 = fresh, decays over time).
    private var attention: Double = 1.0

    /// Whether the bot is currently in a panic state.
    private var panicking: Bool = false

    /// Running score (updated externally via `onScored()`).
    private var currentScore: Int = 0

    /// Death pressure multiplier — increases past targetScore.
    private var deathPressure: Double = 0

    /// Elapsed game time (for fatigue calculation).
    private var elapsed: TimeInterval = 0

    /// Set to true once deathPressure has made the bot unrecoverable.
    /// Used externally to know the bot is in its death spiral.
    private(set) var isInDeathSpiral: Bool = false

    // MARK: - Init

    init(profile: HumanBotProfile) {
        self.profile = profile
    }

    // MARK: - Reset

    func reset() {
        lastDecisionTime = 0
        queuedFlapTime = nil
        attention = 1.0
        panicking = false
        currentScore = 0
        deathPressure = 0
        elapsed = 0
        isInDeathSpiral = false
    }

    // MARK: - Score Callback

    func onScored() {
        currentScore += 1

        // Brief attention recovery from dopamine hit
        attention = min(1.0, attention + profile.scoreRecovery)

        // Start death pressure once past target score
        if currentScore >= profile.targetScore {
            let overshoot = Double(currentScore - profile.targetScore + 1)
            deathPressure = min(1.0, overshoot * profile.deathPressureRate)
        }
    }

    // MARK: - Per-Frame Update

    /// Returns `true` if the bot should flap this frame.
    ///
    /// - Parameters:
    ///   - currentTime: Scene time (seconds since game start).
    ///   - dt: Delta time since last frame.
    ///   - birdY: Bot's current Y position.
    ///   - velocity: Bot's current Y velocity.
    ///   - nextGapY: Y center of the nearest upcoming pipe gap.
    ///   - nextGapDist: Horizontal distance to the nearest upcoming pipe.
    ///   - pipeGap: Current effective pipe gap size (includes power-up modifiers).
    func update(currentTime: TimeInterval,
                dt: TimeInterval,
                birdY: CGFloat,
                velocity: CGFloat,
                nextGapY: CGFloat,
                nextGapDist: CGFloat,
                pipeGap: CGFloat) -> Bool {

        elapsed += dt

        // --- Fatigue: attention decays over time ---
        let effectiveFatigueRate = profile.fatigueRate * (1.0 + deathPressure)
        attention = max(profile.attentionFloor,
                        attention - effectiveFatigueRate * dt)

        // --- Death spiral check ---
        if deathPressure >= 0.9 {
            isInDeathSpiral = true
        }

        // --- Execute queued flap ---
        if let flapTime = queuedFlapTime, currentTime >= flapTime {
            queuedFlapTime = nil

            // Panic: chance of an involuntary double-flap
            if panicking && Double.random(in: 0...1) < effectivePanicFlapChance {
                queuedFlapTime = currentTime + 0.04 + abs(gaussian(σ: 0.02))
            }

            return true
        }

        // --- Perception gate: only react to visible pipes ---
        let effectivePerception = profile.perceptionRange * CGFloat(attention)
        guard nextGapDist < effectivePerception else { return false }

        // --- Reaction time gate ---
        let jitter = gaussian(σ: profile.reactionσ)
        let effectiveReaction = (profile.reactionBase + abs(jitter)) / attention
        // Under death pressure, reactions get sluggish
        let pressuredReaction = effectiveReaction * (1.0 + deathPressure * 0.6)
        guard currentTime - lastDecisionTime >= pressuredReaction else { return false }
        lastDecisionTime = currentTime

        // --- Panic detection ---
        let verticalMiss = abs(birdY - nextGapY)
        panicking = nextGapDist < profile.panicDistance
                    && verticalMiss > profile.panicMisalignment

        // --- Aim: where does the bot think it should be? ---
        let aimBias = CGFloat(gaussian(σ: Double(profile.aimBiasσ)))
        // Under death pressure, aim gets worse
        let pressureBias = CGFloat(deathPressure * 15.0 * gaussian(σ: 1.0))
        let targetY = nextGapY + aimBias + pressureBias

        // --- Flap decision ---
        // The bot wants to flap if it's below its target and falling or level.
        // "Below" in SpriteKit means birdY < targetY (Y-up coordinate system).
        let needsFlap: Bool
        if panicking {
            // Panicking: more aggressive flapping — flap if below target OR
            // if falling fast even when near target
            needsFlap = birdY < targetY + 15 && velocity < GK.flapImpulse * 0.3
        } else {
            // Normal: flap if below target with some buffer, and not already rising fast
            needsFlap = birdY < targetY - 8 && velocity < GK.flapImpulse * 0.4
        }

        if needsFlap {
            // Queue the flap with motor noise delay
            let motorDelay = abs(gaussian(σ: profile.motorσ * (1.0 + deathPressure * 0.5)))
            queuedFlapTime = currentTime + motorDelay
        }

        return false
    }

    // MARK: - Helpers

    private var effectivePanicFlapChance: Double {
        profile.panicFlapChance * (1.0 + deathPressure * 0.5)
    }

    /// Box-Muller gaussian random with given standard deviation.
    private func gaussian(σ: Double) -> Double {
        let u1 = Double.random(in: 1e-10...1.0)
        let u2 = Double.random(in: 1e-10...1.0)
        return σ * sqrt(-2.0 * log(u1)) * cos(2.0 * .pi * u2)
    }
}

// MARK: - Replay Bot AI

/// Plays back a recorded human run by replaying flap timestamps.
/// Zero algorithmic decisions — every flap comes from real human input.
///
/// Requires that the game uses the same pipe seed as the recording,
/// so pipes appear in the exact same positions.
final class ReplayBotAI {

    /// Compact replay data: just a seed and flap times.
    struct ReplayData: Codable {
        let pipeSeed: Int
        let flapTimestamps: [Float]     // seconds since game start
        let finalScore: Int
    }

    private let replay: ReplayData
    private var nextFlapIndex: Int = 0

    /// The pipe seed this replay was recorded with.
    /// The game MUST use this seed for pipes to line up correctly.
    var pipeSeed: Int { replay.pipeSeed }

    var finalScore: Int { replay.finalScore }

    /// True when all flaps have been played (the bot should die naturally).
    var isFinished: Bool { nextFlapIndex >= replay.flapTimestamps.count }

    init(replay: ReplayData) {
        self.replay = replay
    }

    func reset() {
        nextFlapIndex = 0
    }

    /// Returns `true` if a flap should happen this frame.
    func update(currentTime: TimeInterval) -> Bool {
        guard nextFlapIndex < replay.flapTimestamps.count else { return false }

        let nextTime = TimeInterval(replay.flapTimestamps[nextFlapIndex])
        if currentTime >= nextTime {
            nextFlapIndex += 1
            return true
        }
        return false
    }
}

// MARK: - Bot AI Mode

/// Unifies behavioral and replay-based AI behind a single interface.
enum BotAIMode {
    case behavioral(HumanBotAI)
    case replay(ReplayBotAI)

    func reset() {
        switch self {
        case .behavioral(let ai): ai.reset()
        case .replay(let ai): ai.reset()
        }
    }

    func onScored() {
        switch self {
        case .behavioral(let ai): ai.onScored()
        case .replay: break // Replay ignores scoring
        }
    }

    /// Returns true if the bot should flap this frame.
    func shouldFlap(currentTime: TimeInterval,
                    dt: TimeInterval,
                    birdY: CGFloat,
                    velocity: CGFloat,
                    nextGapY: CGFloat,
                    nextGapDist: CGFloat,
                    pipeGap: CGFloat) -> Bool {
        switch self {
        case .behavioral(let ai):
            return ai.update(currentTime: currentTime,
                             dt: dt,
                             birdY: birdY,
                             velocity: velocity,
                             nextGapY: nextGapY,
                             nextGapDist: nextGapDist,
                             pipeGap: pipeGap)
        case .replay(let ai):
            return ai.update(currentTime: currentTime)
        }
    }

    /// Whether the bot is past recovery and should die naturally.
    var isInDeathSpiral: Bool {
        switch self {
        case .behavioral(let ai): return ai.isInDeathSpiral
        case .replay(let ai): return ai.isFinished
        }
    }
}
