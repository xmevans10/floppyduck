import XCTest
@testable import FloppyDuck

final class PRNGTests: XCTestCase {

    // MARK: - Determinism

    func testSameSeedProducesSameSequence() {
        var rng1 = SeededRandom(seed: 42)
        var rng2 = SeededRandom(seed: 42)

        for _ in 0..<100 {
            XCTAssertEqual(rng1.next(), rng2.next(),
                "Same seed should produce identical sequence")
        }
    }

    func testDifferentSeedsProduceDifferentSequences() {
        var rng1 = SeededRandom(seed: 42)
        var rng2 = SeededRandom(seed: 99)

        var allSame = true
        for _ in 0..<20 {
            if rng1.next() != rng2.next() {
                allSame = false
                break
            }
        }

        XCTAssertFalse(allSame,
            "Different seeds should produce different sequences")
    }

    // MARK: - Float Range

    func testNextFloatInUnitRange() {
        var rng = SeededRandom(seed: 12345)

        for _ in 0..<200 {
            let val = rng.nextFloat()
            XCTAssertGreaterThanOrEqual(val, 0.0)
            XCTAssertLessThan(val, 1.0)
        }
    }

    func testNextInRangeRespectsMinMax() {
        var rng = SeededRandom(seed: 77)

        for _ in 0..<200 {
            let val = rng.nextInRange(min: 100, max: 300)
            XCTAssertGreaterThanOrEqual(val, 100)
            XCTAssertLessThanOrEqual(val, 300)
        }
    }

    // MARK: - Gap Positions

    func testGapPositionsWithinBounds() {
        var rng = SeededRandom(seed: 42)
        let gaps = rng.generateGapPositions()

        XCTAssertEqual(gaps.count, GK.maxPregenPipes)

        for (i, gap) in gaps.enumerated() {
            XCTAssertGreaterThanOrEqual(gap, GK.pipeMinY,
                "Gap \(i) below minimum Y")
            XCTAssertLessThanOrEqual(gap, GK.pipeMaxY,
                "Gap \(i) above maximum Y")
        }
    }

    func testGapPositionsRespectMaxDelta() {
        var rng = SeededRandom(seed: 42)
        let gaps = rng.generateGapPositions()

        for i in 1..<gaps.count {
            let delta = abs(gaps[i] - gaps[i - 1])
            XCTAssertLessThanOrEqual(delta, GK.maxPipeDelta + 0.001,
                "Gap \(i) jumps \(delta) from previous (max is \(GK.maxPipeDelta))")
        }
    }

    func testGapPositionsDeterministicForSameSeed() {
        var rng1 = SeededRandom(seed: 42)
        var rng2 = SeededRandom(seed: 42)

        let gaps1 = rng1.generateGapPositions()
        let gaps2 = rng2.generateGapPositions()

        XCTAssertEqual(gaps1, gaps2,
            "Same seed must produce identical gap positions (multiplayer fairness)")
    }

    // MARK: - Zero Seed Edge Case

    func testZeroSeedDoesNotDeadlock() {
        var rng = SeededRandom(seed: 0)
        // Seed 0 is normalized to 1 in init — verify it still produces values
        let val = rng.next()
        XCTAssertNotEqual(val, 0,
            "Zero seed should be normalized to avoid xorshift deadlock")
    }
}
