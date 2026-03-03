import Foundation

/// Seeded pseudo-random number generator (xorshift32).
/// Both players use the same seed → identical pipe positions for multiplayer fairness.
struct SeededRandom {
    private var state: UInt32
    
    init(seed: Int) {
        self.state = UInt32(truncatingIfNeeded: seed == 0 ? 1 : seed)
    }
    
    mutating func next() -> UInt32 {
        state ^= state << 13
        state ^= state >> 17
        state ^= state << 5
        return state
    }
    
    /// Returns a float in [0, 1)
    mutating func nextFloat() -> CGFloat {
        CGFloat(next()) / CGFloat(UInt32.max)
    }
    
    /// Returns a value in [min, max]
    mutating func nextInRange(min: CGFloat, max: CGFloat) -> CGFloat {
        min + nextFloat() * (max - min)
    }
    
    /// Pre-generate gap Y positions for all pipes in a match.
    mutating func generateGapPositions(count: Int = GK.maxPregenPipes) -> [CGFloat] {
        (0..<count).map { _ in
            nextInRange(min: GK.pipeMinY, max: GK.pipeMaxY)
        }
    }
}
