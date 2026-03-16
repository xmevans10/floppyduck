import XCTest
@testable import FloppyDuck

final class PowerUpTests: XCTestCase {

    // MARK: - PowerUpKind Properties

    func testAllPowerUpKindsHaveDisplayNames() {
        for kind in PowerUpKind.allCases {
            XCTAssertFalse(kind.displayName.isEmpty,
                "\(kind.rawValue) should have a non-empty display name")
        }
    }

    func testPositiveNegativeClassification() {
        let expectedPositive: Set<PowerUpKind> = [.shield, .slowMo, .miniDuck, .breadMagnet]
        let expectedNegative: Set<PowerUpKind> = [.heavyWings, .windGust, .fatDuck]

        for kind in PowerUpKind.allCases {
            if expectedPositive.contains(kind) {
                XCTAssertTrue(kind.isPositive, "\(kind.rawValue) should be positive")
            } else if expectedNegative.contains(kind) {
                XCTAssertFalse(kind.isPositive, "\(kind.rawValue) should be negative")
            } else {
                XCTFail("Unclassified power-up kind: \(kind.rawValue)")
            }
        }

        // Every kind is accounted for
        XCTAssertEqual(expectedPositive.count + expectedNegative.count, PowerUpKind.allCases.count)
    }

    func testSpawnWeightsArePositive() {
        for kind in PowerUpKind.allCases {
            XCTAssertGreaterThan(kind.spawnWeight, 0,
                "\(kind.rawValue) spawn weight should be positive")
        }
    }

    // MARK: - ActivePowerUp Expiration

    func testActivePowerUpExpiration() {
        // slowMo has duration 4.0s
        let powerUp = ActivePowerUp(kind: .slowMo, startTime: 10.0)

        XCTAssertFalse(powerUp.isExpired(currentTime: 10.5),
            "Should not be expired 0.5s after start")
        XCTAssertFalse(powerUp.isExpired(currentTime: 13.9),
            "Should not be expired at 3.9s (duration is 4.0)")
        XCTAssertTrue(powerUp.isExpired(currentTime: 14.0),
            "Should be expired at exactly 4.0s")
        XCTAssertTrue(powerUp.isExpired(currentTime: 20.0),
            "Should be expired well past duration")
    }

    func testShieldNeverExpiresByTime() {
        let shield = ActivePowerUp(kind: .shield, startTime: 0.0)

        XCTAssertEqual(PowerUpKind.shield.duration, 0,
            "Shield duration should be 0 (until consumed)")
        XCTAssertFalse(shield.isExpired(currentTime: 0.0))
        XCTAssertFalse(shield.isExpired(currentTime: 100.0))
        XCTAssertFalse(shield.isExpired(currentTime: 99999.0),
            "Shield should never expire by time alone")
    }

    func testBreadMagnetExpiresWhenPipesRunOut() {
        var magnet = ActivePowerUp(kind: .breadMagnet, startTime: 0.0, remainingPipes: 5)

        XCTAssertFalse(magnet.isExpired(currentTime: 0.0))

        magnet.remainingPipes = 1
        XCTAssertFalse(magnet.isExpired(currentTime: 0.0))

        magnet.remainingPipes = 0
        XCTAssertTrue(magnet.isExpired(currentTime: 0.0),
            "Bread magnet should expire when remaining pipes reaches 0")
    }

    // MARK: - Progress

    func testProgressCalculation() {
        // slowMo has duration 4.0s
        let powerUp = ActivePowerUp(kind: .slowMo, startTime: 10.0)

        // At start → 1.0
        XCTAssertEqual(powerUp.progress(currentTime: 10.0), 1.0, accuracy: 0.001)
        // Halfway → 0.5
        XCTAssertEqual(powerUp.progress(currentTime: 12.0), 0.5, accuracy: 0.001)
        // At end → 0.0
        XCTAssertEqual(powerUp.progress(currentTime: 14.0), 0.0, accuracy: 0.001)
        // Past end → clamped to 0.0
        XCTAssertEqual(powerUp.progress(currentTime: 20.0), 0.0, accuracy: 0.001)

        // Shield (duration 0) always returns 1.0
        let shield = ActivePowerUp(kind: .shield, startTime: 0.0)
        XCTAssertEqual(shield.progress(currentTime: 100.0), 1.0, accuracy: 0.001)
    }

    // MARK: - SpawnManager

    func testSpawnManagerRespectsMinInterval() {
        let manager = PowerUpSpawnManager()

        // Drain the initial countdown (random 3–6 pipes)
        var firstSpawnPipe = -1
        for i in 1...10 {
            if manager.onPipeScored(currentScore: i, tier: .easy) != nil {
                firstSpawnPipe = i
                break
            }
        }

        guard firstSpawnPipe > 0 else {
            XCTFail("Spawn manager should spawn within first 10 pipes")
            return
        }

        // After spawning, next countdown is random(4...8).
        // The next 3 calls must NOT produce a spawn (min interval is 4).
        for offset in 1...3 {
            let result = manager.onPipeScored(currentScore: firstSpawnPipe + offset, tier: .easy)
            XCTAssertNil(result,
                "Should not spawn within \(offset) pipes of previous spawn (min interval is 4)")
        }
    }

    func testSpawnManagerEventuallySpawns() {
        let manager = PowerUpSpawnManager()
        var spawned = false

        for i in 1...20 {
            if manager.onPipeScored(currentScore: i, tier: .medium) != nil {
                spawned = true
                break
            }
        }

        XCTAssertTrue(spawned,
            "Spawn manager should produce at least one power-up within 20 pipes")
    }

    func testSpawnManagerReset() {
        let manager = PowerUpSpawnManager()

        // Advance state by scoring many pipes
        for i in 1...15 {
            _ = manager.onPipeScored(currentScore: i, tier: .easy)
        }

        manager.reset()

        // After reset, initial countdown is random(3...6) so a spawn must
        // occur within 6 calls.
        var spawnedWithin6 = false
        for i in 1...6 {
            if manager.onPipeScored(currentScore: i, tier: .easy) != nil {
                spawnedWithin6 = true
                break
            }
        }

        XCTAssertTrue(spawnedWithin6,
            "After reset, should spawn within the initial 3–6 pipe window")
    }
}
