import XCTest
@testable import FloppyDuck

final class GameConstantsTests: XCTestCase {

    // MARK: - Physics Sanity Checks

    func testGravityIsNegative() {
        XCTAssertLessThan(GK.gravity, 0, "Gravity should pull downward (negative)")
    }

    func testFlapImpulseIsPositive() {
        XCTAssertGreaterThan(GK.flapImpulse, 0, "Flap impulse should push upward (positive)")
    }

    func testFlapImpulseOvercomesGravity() {
        // Duck should gain altitude per flap: impulse must exceed one-frame gravity pull
        let gravityPerFrame = abs(GK.gravity) / 60.0
        XCTAssertGreaterThan(GK.flapImpulse, gravityPerFrame,
            "Flap impulse (\(GK.flapImpulse)) must exceed single-frame gravity (\(gravityPerFrame))")
    }

    // MARK: - World Geometry

    func testGroundHeightBelowDuckStart() {
        XCTAssertLessThan(GK.groundHeight, GK.duckStartY,
            "Duck start Y must be above ground")
    }

    func testDuckStartWithinWorld() {
        XCTAssertGreaterThan(GK.duckStartX, 0)
        XCTAssertLessThan(GK.duckStartX, GK.worldWidth)
        XCTAssertGreaterThan(GK.duckStartY, GK.groundHeight)
        XCTAssertLessThan(GK.duckStartY, GK.worldHeight)
    }

    func testPipeMinMaxValidRange() {
        XCTAssertLessThan(GK.pipeMinY, GK.pipeMaxY,
            "Pipe min Y must be less than max Y")
        XCTAssertGreaterThan(GK.pipeMinY, GK.groundHeight,
            "Pipe gaps must be above ground")
        XCTAssertLessThan(GK.pipeMaxY, GK.worldHeight,
            "Pipe gaps must be below ceiling")
    }

    func testPipeGapFitsInWorld() {
        // Gap center at min/max Y must still have room for both pipes
        let minGapBottom = GK.pipeMinY - GK.pipeGap / 2
        let maxGapTop = GK.pipeMaxY + GK.pipeGap / 2

        XCTAssertGreaterThanOrEqual(minGapBottom, GK.groundHeight,
            "Gap at minimum Y must leave room for bottom pipe above ground")
        XCTAssertLessThanOrEqual(maxGapTop, GK.worldHeight,
            "Gap at maximum Y must leave room for top pipe below ceiling")
    }

    // MARK: - Collision Bitmasks

    func testBitmasksCategoriesAreUnique() {
        let masks: [UInt32] = [
            GK.duckCategory,
            GK.pipeCategory,
            GK.groundCategory,
            GK.scoreCategory,
            GK.powerUpCategory,
            GK.breadCategory,
        ]

        // Each mask should be a unique power of 2
        for mask in masks {
            XCTAssertEqual(mask & (mask - 1), 0,
                "Bitmask \(mask) should be a power of 2")
        }

        // No overlaps
        let combined = masks.reduce(UInt32(0)) { $0 | $1 }
        var sum = UInt32(0)
        for mask in masks { sum += mask }
        XCTAssertEqual(combined, sum,
            "Bitmask categories should not overlap")
    }

    // MARK: - Speeds

    func testSpeedHierarchy() {
        // 9-layer parallax: bg1 slowest → fg3 fastest
        XCTAssertLessThan(GK.bg1Speed, GK.bg2Speed)
        XCTAssertLessThan(GK.bg2Speed, GK.bg3Speed)
        XCTAssertLessThan(GK.bg3Speed, GK.mid1Speed)
        XCTAssertLessThan(GK.mid1Speed, GK.mid2Speed)
        XCTAssertLessThan(GK.mid2Speed, GK.mid3Speed)
        XCTAssertLessThan(GK.mid3Speed, GK.fg1Speed)
        XCTAssertLessThanOrEqual(GK.fg1Speed, GK.fg2Speed)
        XCTAssertEqual(GK.fg2Speed, GK.fg3Speed)  // both match ground/pipe speed
        XCTAssertEqual(GK.fg2Speed, GK.groundSpeed)
    }

    // MARK: - Medal Thresholds

    func testMedalThresholdsAscending() {
        XCTAssertLessThan(GK.medalBronze, GK.medalSilver)
        XCTAssertLessThan(GK.medalSilver, GK.medalGold)
        XCTAssertLessThan(GK.medalGold, GK.medalPlatinum)
    }

    // MARK: - Animation Constants

    func testAnimationTimingsPositive() {
        XCTAssertGreaterThan(GK.Animation.deathFreezeDuration, 0)
        XCTAssertGreaterThan(GK.Animation.deathFallMinDuration, 0)
        XCTAssertGreaterThan(GK.Animation.deathToGameOverDelay, 0)
        XCTAssertGreaterThan(GK.Animation.popupDuration, 0)
    }

    func testDeathFallMinLessThanMax() {
        XCTAssertLessThan(GK.Animation.deathFallMinDuration,
                          GK.Animation.deathFallMaxDuration)
    }
}
