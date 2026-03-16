import XCTest
@testable import FloppyDuck

final class DifficultyManagerTests: XCTestCase {

    // MARK: - Initial State

    func testInitialTierIsEasy() {
        let dm = DifficultyManager()
        XCTAssertEqual(dm.currentTier, .easy)
        XCTAssertEqual(dm.currentScore, 0)
    }

    // MARK: - Tier Transitions

    func testTierTransitions() {
        // Easy: 0–9
        XCTAssertEqual(DifficultyTier.forScore(0), .easy)
        XCTAssertEqual(DifficultyTier.forScore(5), .easy)
        XCTAssertEqual(DifficultyTier.forScore(9), .easy)

        // Medium: 10–19
        XCTAssertEqual(DifficultyTier.forScore(10), .medium)
        XCTAssertEqual(DifficultyTier.forScore(15), .medium)
        XCTAssertEqual(DifficultyTier.forScore(19), .medium)

        // Hard: 20–29
        XCTAssertEqual(DifficultyTier.forScore(20), .hard)
        XCTAssertEqual(DifficultyTier.forScore(25), .hard)
        XCTAssertEqual(DifficultyTier.forScore(29), .hard)

        // Expert: 30+
        XCTAssertEqual(DifficultyTier.forScore(30), .expert)
        XCTAssertEqual(DifficultyTier.forScore(100), .expert)
    }

    func testUpdateReturnsTrueOnTierChange() {
        let dm = DifficultyManager()

        let changed = dm.update(score: 10)

        XCTAssertTrue(changed, "update should return true when tier changes from easy to medium")
        XCTAssertEqual(dm.currentTier, .medium)
    }

    func testUpdateReturnsFalseWithinSameTier() {
        let dm = DifficultyManager()

        let changed = dm.update(score: 5)

        XCTAssertFalse(changed, "update should return false when remaining in easy tier")
        XCTAssertEqual(dm.currentTier, .easy)
    }

    // MARK: - Speed Scaling

    func testEffectivePipeSpeedIncreasesWithTier() {
        let dm = DifficultyManager()

        dm.update(score: 0)
        let easySpeed = dm.effectivePipeSpeed

        dm.update(score: 10)
        let mediumSpeed = dm.effectivePipeSpeed

        dm.update(score: 20)
        let hardSpeed = dm.effectivePipeSpeed

        dm.update(score: 30)
        let expertSpeed = dm.effectivePipeSpeed

        XCTAssertLessThan(easySpeed, mediumSpeed)
        XCTAssertLessThan(mediumSpeed, hardSpeed)
        XCTAssertLessThan(hardSpeed, expertSpeed)
    }

    // MARK: - Gap Scaling

    func testEffectivePipeGapDecreasesWithTier() {
        let dm = DifficultyManager()

        dm.update(score: 0)
        let easyGap = dm.effectivePipeGap

        dm.update(score: 10)
        let mediumGap = dm.effectivePipeGap

        dm.update(score: 20)
        let hardGap = dm.effectivePipeGap

        dm.update(score: 30)
        let expertGap = dm.effectivePipeGap

        XCTAssertGreaterThan(easyGap, mediumGap)
        XCTAssertGreaterThan(mediumGap, hardGap)
        XCTAssertGreaterThan(hardGap, expertGap)
    }

    // MARK: - Control Scaling

    func testEffectiveFlapImpulseScalesWithSpeed() {
        let dm = DifficultyManager()

        dm.update(score: 0)
        let easyFlap = dm.effectiveFlapImpulse

        dm.update(score: 10)
        let mediumFlap = dm.effectiveFlapImpulse

        dm.update(score: 20)
        let hardFlap = dm.effectiveFlapImpulse

        dm.update(score: 30)
        let expertFlap = dm.effectiveFlapImpulse

        XCTAssertLessThan(easyFlap, mediumFlap)
        XCTAssertLessThan(mediumFlap, hardFlap)
        XCTAssertLessThan(hardFlap, expertFlap)
    }

    func testGravityScalesWithTier() {
        let dm = DifficultyManager()

        dm.update(score: 0)
        let easyGravity = dm.effectiveGravity

        dm.update(score: 10)
        let mediumGravity = dm.effectiveGravity

        dm.update(score: 20)
        let hardGravity = dm.effectiveGravity

        dm.update(score: 30)
        let expertGravity = dm.effectiveGravity

        // Gravity is negative; stronger gravity is more negative
        XCTAssertGreaterThan(easyGravity, mediumGravity)
        XCTAssertGreaterThan(mediumGravity, hardGravity)
        XCTAssertGreaterThan(hardGravity, expertGravity)
    }

    // MARK: - Reset

    func testResetRestoresInitialState() {
        let dm = DifficultyManager()
        dm.update(score: 25)
        XCTAssertEqual(dm.currentTier, .hard)
        XCTAssertEqual(dm.currentScore, 25)

        dm.reset()

        XCTAssertEqual(dm.currentTier, .easy)
        XCTAssertEqual(dm.currentScore, 0)
    }

    // MARK: - Hard Cap

    func testSpeedHasHardCap() {
        let dm = DifficultyManager()
        let hardCap = GK.pipeSpeed * 1.6

        // Push score high enough that the in-tier ramp would exceed the cap
        dm.update(score: 200)

        XCTAssertLessThanOrEqual(dm.effectivePipeSpeed, hardCap,
            "Pipe speed should never exceed 1.6× base (\(hardCap) pts/s)")
    }

    // MARK: - Proportional Controls

    func testControlScalingMaintainsRatio() {
        let dm = DifficultyManager()

        // Base ratio at easy tier: |impulse / gravity|
        dm.update(score: 0)
        let baseRatio = dm.effectiveFlapImpulse / abs(dm.effectiveGravity)

        // Each higher tier should keep the ratio within 10% of the base
        for score in [10, 20, 30] {
            dm.update(score: score)
            let ratio = dm.effectiveFlapImpulse / abs(dm.effectiveGravity)
            let deviation = abs(ratio - baseRatio) / baseRatio

            XCTAssertLessThan(deviation, 0.10,
                "Impulse/gravity ratio at score \(score) deviates \(String(format: "%.1f%%", deviation * 100)) from base — should be <10%")
        }
    }
}
