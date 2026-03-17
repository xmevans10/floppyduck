import SpriteKit

// MARK: - Difficulty Tier

/// Display-only tier labels shown at score milestones.
/// Gameplay parameters use a continuous logarithmic curve — no discrete jumps.
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
}

// MARK: - DifficultyManager

/// Manages progressive difficulty using a continuous logarithmic curve.
///
/// Formula:  `t = log(1 + score × k) / log(1 + refScore × k)`
///
/// - Difficulty ramps steeply at low scores (each pipe matters more).
/// - Plateaus at high scores (diminishing returns).
/// - All parameters interpolate smoothly — no abrupt tier jumps.
/// - Tier labels remain as display-only flavor text at score milestones.
final class DifficultyManager {
    private(set) var currentTier: DifficultyTier = .easy
    private(set) var currentScore: Int = 0

    // MARK: - Curve Tuning

    /// Steepness of the log curve.  Higher → faster initial ramp.
    private let k: CGFloat = 0.08
    /// Score at which difficulty reaches 100 %.
    private let refScore: CGFloat = 50

    // MARK: - Parameter Ranges  (min at score 0 → max at refScore)

    private let speedRange:   (lo: CGFloat, hi: CGFloat) = (1.0,  1.55)
    private let gapRange:     (lo: CGFloat, hi: CGFloat) = (1.0,  0.78)
    private let flapRange:    (lo: CGFloat, hi: CGFloat) = (1.0,  1.20)
    private let gravityRange: (lo: CGFloat, hi: CGFloat) = (1.0,  1.14)

    // MARK: - Logarithmic Curve

    /// Normalised difficulty in `[0, 1]`.
    private var t: CGFloat {
        guard currentScore > 0 else { return 0 }
        let s = CGFloat(currentScore)
        return min(log(1 + s * k) / log(1 + refScore * k), 1.0)
    }

    private func lerp(_ lo: CGFloat, _ hi: CGFloat) -> CGFloat {
        lo + (hi - lo) * t
    }

    // MARK: - Effective Parameters

    var effectivePipeSpeed: CGFloat {
        GK.pipeSpeed * lerp(speedRange.lo, speedRange.hi)
    }

    var effectivePipeGap: CGFloat {
        GK.pipeGap * lerp(gapRange.lo, gapRange.hi)
    }

    var effectiveFlapImpulse: CGFloat {
        GK.flapImpulse * lerp(flapRange.lo, flapRange.hi)
    }

    var effectiveGravity: CGFloat {
        GK.gravity * lerp(gravityRange.lo, gravityRange.hi)
    }

    // MARK: - Update

    /// Call each time the score changes.  Returns `true` when the display tier changes
    /// (so the scene can show "MEDIUM!", "HARD!", etc.).
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

    /// Reset for a new game.
    func reset() {
        currentTier = .easy
        currentScore = 0
    }
}
