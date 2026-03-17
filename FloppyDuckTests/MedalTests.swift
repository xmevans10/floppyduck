import XCTest
@testable import FloppyDuck

final class MedalTests: XCTestCase {

    // MARK: - Thresholds

    func testMedalThresholds() {
        // Below bronze
        XCTAssertEqual(Medal.from(score: 0), .none)
        XCTAssertEqual(Medal.from(score: 4), .none)

        // Bronze: >= 5
        XCTAssertEqual(Medal.from(score: 5), .bronze)
        XCTAssertEqual(Medal.from(score: 14), .bronze)

        // Silver: >= 15
        XCTAssertEqual(Medal.from(score: 15), .silver)
        XCTAssertEqual(Medal.from(score: 29), .silver)

        // Gold: >= 30
        XCTAssertEqual(Medal.from(score: 30), .gold)
        XCTAssertEqual(Medal.from(score: 49), .gold)

        // Platinum: >= 50
        XCTAssertEqual(Medal.from(score: 50), .platinum)
        XCTAssertEqual(Medal.from(score: 100), .platinum)
    }

    // MARK: - Display Names

    func testMedalDisplayNames() {
        XCTAssertEqual(Medal.none.displayName, "")

        XCTAssertFalse(Medal.bronze.displayName.isEmpty)
        XCTAssertFalse(Medal.silver.displayName.isEmpty)
        XCTAssertFalse(Medal.gold.displayName.isEmpty)
        XCTAssertFalse(Medal.platinum.displayName.isEmpty)
    }

    // MARK: - Pixel Icons

    func testMedalPixelIcons() {
        XCTAssertNil(Medal.none.pixelIcon)
        XCTAssertEqual(Medal.bronze.pixelIcon, .medalBronze)
        XCTAssertEqual(Medal.silver.pixelIcon, .medalSilver)
        XCTAssertEqual(Medal.gold.pixelIcon, .medalGold)
        XCTAssertEqual(Medal.platinum.pixelIcon, .medalPlatinum)
    }

    // MARK: - Ordering

    func testMedalOrdering() {
        // Threshold constants must be strictly increasing
        XCTAssertLessThan(GK.medalBronze, GK.medalSilver)
        XCTAssertLessThan(GK.medalSilver, GK.medalGold)
        XCTAssertLessThan(GK.medalGold, GK.medalPlatinum)

        // Successive boundary scores must yield distinct (better) medals
        let boundaryScores = [0, GK.medalBronze, GK.medalSilver, GK.medalGold, GK.medalPlatinum]
        let expectedMedals: [Medal] = [.none, .bronze, .silver, .gold, .platinum]

        for (score, expected) in zip(boundaryScores, expectedMedals) {
            XCTAssertEqual(Medal.from(score: score), expected,
                "Score \(score) should yield \(expected.rawValue)")
        }
    }
}
