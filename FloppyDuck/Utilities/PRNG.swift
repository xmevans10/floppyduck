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
    /// Consecutive gaps are clamped to maxPipeDelta so no impossible jumps occur.
    mutating func generateGapPositions(count: Int = GK.maxPregenPipes) -> [CGFloat] {
        var positions: [CGFloat] = []
        var lastY = (GK.pipeMinY + GK.pipeMaxY) / 2  // start near center

        for _ in 0..<count {
            let rawY = nextInRange(min: GK.pipeMinY, max: GK.pipeMaxY)
            // Clamp so gap doesn't jump more than maxPipeDelta from previous
            let clamped = max(lastY - GK.maxPipeDelta,
                              min(lastY + GK.maxPipeDelta, rawY))
            let finalY = max(GK.pipeMinY, min(GK.pipeMaxY, clamped))
            positions.append(finalY)
            lastY = finalY
        }
        return positions
    }
}
