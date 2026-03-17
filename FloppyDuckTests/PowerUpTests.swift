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

    func testAllPowerUpKindsHaveEmoji() {
        for kind in PowerUpKind.allCases {
            XCTAssertFalse(kind.emoji.isEmpty,
                "\(kind.rawValue) should have a non-empty emoji")
        }
    }

    func testPositiveNegativeClassification() {
        let expectedPositive: Set<PowerUpKind> = [
            .shield, .pipeExpander, .breadMagnet, .slowMotion, .ghostDuck
        ]
        let expectedNegative: Set<PowerUpKind> = [
            .pipeSqueeze, .speedBurst, .dizzyDuck
        ]

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

    func testBreadMagnetHasHigherWeight() {
        let magnetWeight = PowerUpKind.breadMagnet.spawnWeight
        for kind in PowerUpKind.allCases where kind != .breadMagnet {
            XCTAssertGreaterThanOrEqual(magnetWeight, kind.spawnWeight,
                "breadMagnet should have highest or equal spawn weight, but \(kind.rawValue) has \(kind.spawnWeight)")
        }
    }

    func testGhostDuckHasLowerWeight() {
        let ghostWeight = PowerUpKind.ghostDuck.spawnWeight
        XCTAssertLessThan(ghostWeight, 1.0,
            "ghostDuck should have a lower spawn weight")
    }

    // MARK: - Pipe-Count Based Power-Ups

    func testPipeCountBasedKinds() {
        // pipeExpander, breadMagnet, pipeSqueeze should be pipe-count based
        XCTAssertTrue(PowerUpKind.pipeExpander.isPipeCountBased)
        XCTAssertTrue(PowerUpKind.breadMagnet.isPipeCountBased)
        XCTAssertTrue(PowerUpKind.pipeSqueeze.isPipeCountBased)

        // These should NOT be pipe-count based
        XCTAssertFalse(PowerUpKind.shield.isPipeCountBased)
        XCTAssertFalse(PowerUpKind.slowMotion.isPipeCountBased)
        XCTAssertFalse(PowerUpKind.ghostDuck.isPipeCountBased)
        XCTAssertFalse(PowerUpKind.speedBurst.isPipeCountBased)
        XCTAssertFalse(PowerUpKind.dizzyDuck.isPipeCountBased)
    }

    func testInitialPipeCounts() {
        XCTAssertEqual(PowerUpKind.pipeExpander.initialPipeCount, 3)
        XCTAssertEqual(PowerUpKind.breadMagnet.initialPipeCount, 5)
        XCTAssertEqual(PowerUpKind.pipeSqueeze.initialPipeCount, 3)

        XCTAssertNil(PowerUpKind.shield.initialPipeCount)
        XCTAssertNil(PowerUpKind.ghostDuck.initialPipeCount)
    }

    // MARK: - ActivePowerUp Expiration

    func testTimeBasedExpiration() {
        // slowMotion has duration 5.0s
        let powerUp = ActivePowerUp(kind: .slowMotion, startTime: 10.0)

        XCTAssertFalse(powerUp.isExpired(currentTime: 10.5),
            "Should not be expired 0.5s after start")
        XCTAssertFalse(powerUp.isExpired(currentTime: 14.9),
            "Should not be expired at 4.9s (duration is 5.0)")
        XCTAssertTrue(powerUp.isExpired(currentTime: 15.0),
            "Should be expired at exactly 5.0s")
        XCTAssertTrue(powerUp.isExpired(currentTime: 20.0),
            "Should be expired well past duration")
    }

    func testGhostDuckExpiration() {
        // ghostDuck has duration 3.0s
        let ghost = ActivePowerUp(kind: .ghostDuck, startTime: 5.0)

        XCTAssertEqual(PowerUpKind.ghostDuck.duration, 3.0)
        XCTAssertFalse(ghost.isExpired(currentTime: 5.0))
        XCTAssertFalse(ghost.isExpired(currentTime: 7.9))
        XCTAssertTrue(ghost.isExpired(currentTime: 8.0),
            "Ghost duck should expire after 3 seconds")
    }

    func testDizzyDuckExpiration() {
        // dizzyDuck has duration 3.0s
        let dizzy = ActivePowerUp(kind: .dizzyDuck, startTime: 0.0)

        XCTAssertEqual(PowerUpKind.dizzyDuck.duration, 3.0)
        XCTAssertFalse(dizzy.isExpired(currentTime: 2.5))
        XCTAssertTrue(dizzy.isExpired(currentTime: 3.0),
            "Dizzy duck should expire after 3 seconds")
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

    func testPipeCountBasedExpiry() {
        // pipeExpander starts with 3 remaining pipes
        var expander = ActivePowerUp(kind: .pipeExpander, startTime: 0.0, remainingPipes: 3)

        XCTAssertFalse(expander.isExpired(currentTime: 0.0))

        expander.remainingPipes = 1
        XCTAssertFalse(expander.isExpired(currentTime: 0.0))

        expander.remainingPipes = 0
        XCTAssertTrue(expander.isExpired(currentTime: 0.0),
            "Pipe expander should expire when remaining pipes reaches 0")

        // pipeSqueeze also pipe-count based
        var squeeze = ActivePowerUp(kind: .pipeSqueeze, startTime: 0.0, remainingPipes: 3)
        XCTAssertFalse(squeeze.isExpired(currentTime: 0.0))
        squeeze.remainingPipes = 0
        XCTAssertTrue(squeeze.isExpired(currentTime: 0.0),
            "Pipe squeeze should expire when remaining pipes reaches 0")
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
        // slowMotion has duration 5.0s
        let powerUp = ActivePowerUp(kind: .slowMotion, startTime: 10.0)

        // At start → 1.0
        XCTAssertEqual(powerUp.progress(currentTime: 10.0), 1.0, accuracy: 0.001)
        // Halfway → 0.5
        XCTAssertEqual(powerUp.progress(currentTime: 12.5), 0.5, accuracy: 0.001)
        // At end → 0.0
        XCTAssertEqual(powerUp.progress(currentTime: 15.0), 0.0, accuracy: 0.001)
        // Past end → clamped to 0.0
        XCTAssertEqual(powerUp.progress(currentTime: 20.0), 0.0, accuracy: 0.001)

        // Shield (duration 0) always returns 1.0
        let shield = ActivePowerUp(kind: .shield, startTime: 0.0)
        XCTAssertEqual(shield.progress(currentTime: 100.0), 1.0, accuracy: 0.001)
    }

    func testPipeCountProgressCalculation() {
        // pipeExpander: 3 initial pipes
        let expander = ActivePowerUp(kind: .pipeExpander, startTime: 0.0, remainingPipes: 3)
        XCTAssertEqual(expander.progress(currentTime: 0.0), 1.0, accuracy: 0.001)

        var mid = ActivePowerUp(kind: .pipeExpander, startTime: 0.0, remainingPipes: 1)
        XCTAssertEqual(mid.progress(currentTime: 0.0), 1.0 / 3.0, accuracy: 0.001)

        mid.remainingPipes = 0
        XCTAssertEqual(mid.progress(currentTime: 0.0), 0.0, accuracy: 0.001)
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

    func testShieldDoesNotSpawnAtEasyTier() {
        let manager = PowerUpSpawnManager()
        var shieldSpawned = false

        // Run many iterations at easy tier
        for run in 0..<50 {
            manager.reset()
            for i in 1...20 {
                if let kind = manager.onPipeScored(currentScore: i, tier: .easy) {
                    if kind == .shield {
                        shieldSpawned = true
                    }
                }
            }
        }

        XCTAssertFalse(shieldSpawned,
            "Shield should never spawn at easy tier")
    }
}
