import SpriteKit

// MARK: - Difficulty Tier

/// Progressive difficulty tiers that scale gameplay challenge.
/// Speed increases are paired with proportional control sensitivity
/// boosts so that scoring remains consistently possible.
enum DifficultyTier: Int, CaseIterable, Comparable {
    case easy   = 0   // score 0–9
    case medium = 1   // score 10–19
    case hard   = 2   // score 20–29
    case expert = 3   // score 30+

    static func forScore(_ score: Int) -> DifficultyTier {
        switch score {
        case 0..<10:  return .easy
        case 10..<20: return .medium
        case 20..<30: return .hard
        default:      return .expert
        }
    }

    static func < (lhs: DifficultyTier, rhs: DifficultyTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var displayName: String {
        switch self {
        case .easy:   return "EASY"
        case .medium: return "MEDIUM"
        case .hard:   return "HARD"
        case .expert: return "EXPERT"
        }
    }

    // MARK: - Speed Scaling

    /// Base pipe speed multiplier for this tier.
    var pipeSpeedMultiplier: CGFloat {
        switch self {
        case .easy:   return 1.0
        case .medium: return 1.15
        case .hard:   return 1.30
        case .expert: return 1.45
        }
    }

    /// Additional per-pipe speed ramp within this tier (pts/s per pipe).
    var inTierSpeedRamp: CGFloat {
        switch self {
        case .easy:   return 0.8
        case .medium: return 0.6
        case .hard:   return 0.4
        case .expert: return 0.3
        }
    }

    // MARK: - Gap Scaling

    /// Pipe gap multiplier — smaller gaps at higher tiers.
    var pipeGapMultiplier: CGFloat {
        switch self {
        case .easy:   return 1.0
        case .medium: return 0.92
        case .hard:   return 0.85
        case .expert: return 0.80
        }
    }

    // MARK: - Control Scaling (KEY: maintains consistent scoring feel)

    /// Flap impulse multiplier — stronger flap at higher speeds
    /// so the duck can navigate tighter windows at faster speeds.
    var flapImpulseMultiplier: CGFloat {
        switch self {
        case .easy:   return 1.0
        case .medium: return 1.08
        case .hard:   return 1.14
        case .expert: return 1.18
        }
    }

    /// Gravity multiplier — slightly stronger to match faster flap,
    /// keeping the flight arc proportional.
    var gravityMultiplier: CGFloat {
        switch self {
        case .easy:   return 1.0
        case .medium: return 1.04
        case .hard:   return 1.08
        case .expert: return 1.12
        }
    }

    /// Max vertical speed cap multiplier.
    var maxUpSpeedMultiplier: CGFloat {
        switch self {
        case .easy:   return 1.0
        case .medium: return 1.05
        case .hard:   return 1.10
        case .expert: return 1.14
        }
    }

    /// Max gap-center delta between consecutive pipes — tighter at higher tiers
    /// to create more challenging pipe sequences.
    var maxPipeDeltaMultiplier: CGFloat {
        switch self {
        case .easy:   return 1.0
        case .medium: return 1.10
        case .hard:   return 1.20
        case .expert: return 1.25
        }
    }
}

// MARK: - DifficultyManager

/// Manages progressive difficulty state during a game session.
/// Call `update(score:)` each time the score changes.
final class DifficultyManager {
    private(set) var currentTier: DifficultyTier = .easy
    private(set) var currentScore: Int = 0

    /// Returns the effective pipe speed for the given score.
    var effectivePipeSpeed: CGFloat {
        let baseSpeed = GK.pipeSpeed * currentTier.pipeSpeedMultiplier
        let tierStartScore = tierStartScore(for: currentTier)
        let pipesInTier = CGFloat(max(0, currentScore - tierStartScore))
        let inTierBonus = pipesInTier * currentTier.inTierSpeedRamp
        return min(baseSpeed + inTierBonus, GK.pipeSpeed * 1.6)  // hard cap
    }

    /// Returns the effective pipe gap for the current tier.
    var effectivePipeGap: CGFloat {
        GK.pipeGap * currentTier.pipeGapMultiplier
    }

    /// Returns the effective flap impulse for the current tier.
    var effectiveFlapImpulse: CGFloat {
        GK.flapImpulse * currentTier.flapImpulseMultiplier
    }

    /// Returns the effective gravity for the current tier.
    var effectiveGravity: CGFloat {
        GK.gravity * currentTier.gravityMultiplier
    }

    /// Returns the effective max upward speed for the current tier.
    var effectiveMaxUpSpeed: CGFloat {
        GK.maxUpSpeed * currentTier.maxUpSpeedMultiplier
    }

    /// Returns the effective max pipe delta for the current tier.
    var effectiveMaxPipeDelta: CGFloat {
        GK.maxPipeDelta * currentTier.maxPipeDeltaMultiplier
    }

    /// Update difficulty based on new score. Returns true if tier changed.
    @discardableResult
    func update(score: Int) -> Bool {
        currentScore = score
        let newTier = DifficultyTier.forScore(score)
        if newTier != currentTier {
            currentTier = newTier
            return true
        }
        return false
    }

    /// Reset to initial state for a new game.
    func reset() {
        currentTier = .easy
        currentScore = 0
    }

    // MARK: - Helpers

    private func tierStartScore(for tier: DifficultyTier) -> Int {
        switch tier {
        case .easy:   return 0
        case .medium: return 10
        case .hard:   return 20
        case .expert: return 30
        }
    }
}
