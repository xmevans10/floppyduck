import QuartzCore
import SpriteKit
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

    func testAllPowerUpKindsHavePixelIcon() {
        for kind in PowerUpKind.allCases {
            // Verify pixelIcon is accessible (would crash if missing)
            _ = kind.pixelIcon
        }
    }

    func testPositiveNegativeClassification() {
        let expectedPositive: Set<PowerUpKind> = [
            .shield, .pipeExpander, .breadMagnet, .slowMotion, .ghostDuck, .doublePoints,
            .tinyDuck, .megaFlap, .featherweight, .mysteryBox
        ]
        let expectedNegative: Set<PowerUpKind> = [
            .pipeSqueeze, .speedBurst, .dizzyDuck, .heavyDuck,
            .jumboDuck, .foggy
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

    func testMysteryBoxHasHighestWeight() {
        let mysteryWeight = PowerUpKind.mysteryBox.spawnWeight
        for kind in PowerUpKind.allCases where kind != .mysteryBox {
            XCTAssertGreaterThanOrEqual(mysteryWeight, kind.spawnWeight,
                "mysteryBox should have highest or equal spawn weight, but \(kind.rawValue) has \(kind.spawnWeight)")
        }
    }

    func testGhostDuckHasModerateWeight() {
        let ghostWeight = PowerUpKind.ghostDuck.spawnWeight
        XCTAssertEqual(ghostWeight, 1.0,
            "ghostDuck should have a moderate spawn weight")
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

    func testTimeBasedPowerUpsWearOffAtLastFifteenPercent() {
        let powerUp = ActivePowerUp(kind: .slowMotion, startTime: 10.0)

        XCTAssertFalse(powerUp.isWearingOff(currentTime: 14.24),
            "Slow motion should not warn before the final 15% of its 5s duration")
        XCTAssertTrue(powerUp.isWearingOff(currentTime: 14.25),
            "Slow motion should warn with 15% duration remaining")
        XCTAssertFalse(powerUp.isWearingOff(currentTime: 15.0),
            "Expired power-ups should no longer be in the warning phase")
    }

    func testPipeCountPowerUpsWearOffOnLastUsableCharge() {
        var expander = ActivePowerUp(kind: .pipeExpander, startTime: 0.0, remainingPipes: 2)
        XCTAssertFalse(expander.isWearingOff(currentTime: 0.0))

        expander.remainingPipes = 1
        XCTAssertTrue(expander.isWearingOff(currentTime: 0.0),
            "Pipe-count power-ups should warn on the last usable charge")

        expander.remainingPipes = 0
        XCTAssertFalse(expander.isWearingOff(currentTime: 0.0),
            "Expired pipe-count power-ups should no longer warn")
    }

    // MARK: - SpawnManager

    func testSpawnManagerRespectsMinInterval() {
        let manager = PowerUpSpawnManager()

        // Drain the initial countdown (random 1–2 pipes)
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

        XCTAssertLessThanOrEqual(firstSpawnPipe, 2)
    }

    func testSeededSpawnManagerProducesSameScheduleForSameSeed() {
        let first = powerUpSchedule(seed: 12345)
        let second = powerUpSchedule(seed: 12345)

        XCTAssertEqual(first, second)
    }

    func testSeededSpawnManagerProducesDifferentScheduleForDifferentSeeds() {
        let first = powerUpSchedule(seed: 12345)
        let second = powerUpSchedule(seed: 54321)

        XCTAssertNotEqual(first, second)
    }

    func testSeededMysteryBoxResolutionIsDeterministic() {
        let first = mysteryBoxRewards(seed: 111)
        let second = mysteryBoxRewards(seed: 111)

        XCTAssertEqual(first, second)
        XCTAssertFalse(first.contains(.mysteryBox))
    }

    func testUnseededSpawnManagerEventuallySpawns() {
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

    func testSeededSpawnManagerResetRestoresSchedule() {
        let manager = PowerUpSpawnManager(seed: 999)
        let initial = (1...12).compactMap { pipe in
            manager.onPipeScored(currentScore: pipe, tier: .hard)
        }

        manager.reset()

        let reset = (1...12).compactMap { pipe in
            manager.onPipeScored(currentScore: pipe, tier: .hard)
        }

        XCTAssertEqual(initial, reset)
    }

    func testShieldDoesNotSpawnAtEasyTier() {
        let manager = PowerUpSpawnManager(seed: 777)
        var shieldSpawned = false

        for i in 1...100 {
            if let kind = manager.onPipeScored(currentScore: i, tier: .easy),
               kind == .shield {
                shieldSpawned = true
            }
        }

        XCTAssertFalse(shieldSpawned,
            "Shield should never spawn at easy tier")
    }

    // MARK: - Controller Parity

    func testCollectingPowerUpReportsKindForAchievementTracking() {
        let harness = makePowerUpHarness()
        let controller = harness.controller
        var collectedKinds: [PowerUpKind] = []
        controller.onPowerUpCollected = { collectedKinds.append($0) }

        let node = SKNode()
        node.name = "powerUp_dizzyDuck"
        controller.collectPowerUp(node: node)

        XCTAssertEqual(collectedKinds, [.dizzyDuck])
    }

    func testShieldConsumptionReportsUsageForAchievementTracking() {
        let harness = makePowerUpHarness()
        let controller = harness.controller
        var shieldConsumptions = 0
        controller.onShieldConsumed = { shieldConsumptions += 1 }

        let node = SKNode()
        node.name = "powerUp_shield"
        controller.collectPowerUp(node: node)

        controller.consumeShield(scene: SKScene(size: CGSize(width: GK.worldWidth, height: GK.worldHeight)))

        XCTAssertEqual(shieldConsumptions, 1)
        XCTAssertFalse(controller.hasActiveShield)
    }

    func testGhostDuckExpiryRestoresGroundOnlyCollisionMask() {
        let harness = makePowerUpHarness()
        let duck = harness.duck
        let controller = harness.controller

        let node = SKNode()
        node.name = "powerUp_ghostDuck"
        controller.collectPowerUp(node: node)

        XCTAssertEqual(duck.physicsBody?.collisionBitMask, GK.groundCategory)

        controller.update(
            dt: 0,
            currentTime: CACurrentMediaTime() + PowerUpKind.ghostDuck.duration + 0.1
        )

        XCTAssertEqual(
            duck.physicsBody?.contactTestBitMask,
            GK.pipeCategory | GK.groundCategory | GK.powerUpCategory | GK.breadCategory
        )
        XCTAssertEqual(duck.physicsBody?.collisionBitMask, GK.groundCategory)
    }
}

private struct PowerUpHarness {
    let worldNode: SKNode
    let pipeLayer: SKNode
    let duck: SKSpriteNode
    let controller: PowerUpController
}

private func powerUpSchedule(seed: Int) -> [PowerUpKind] {
    let manager = PowerUpSpawnManager(seed: seed)
    return (1...20).compactMap { pipe in
        manager.onPipeScored(currentScore: pipe, tier: DifficultyTier.forScore(pipe))
    }
}

private func mysteryBoxRewards(seed: Int) -> [PowerUpKind] {
    let manager = PowerUpSpawnManager(seed: seed)
    return (0..<10).map { _ in manager.randomMysteryBoxReward() }
}

private func makePowerUpHarness(duck: SKSpriteNode? = nil) -> PowerUpHarness {
    let worldNode = SKNode()
    let pipeLayer = SKNode()
    let sprite = duck ?? makeTestDuck()
    worldNode.addChild(pipeLayer)
    worldNode.addChild(sprite)
    let controller = PowerUpController(
        worldNode: worldNode,
        pipeLayer: pipeLayer,
        duck: sprite,
        difficulty: DifficultyManager()
    )
    return PowerUpHarness(
        worldNode: worldNode,
        pipeLayer: pipeLayer,
        duck: sprite,
        controller: controller
    )
}

private func makeTestDuck() -> SKSpriteNode {
    let duck = SKSpriteNode(color: .white, size: CGSize(width: 32, height: 32))
    duck.position = CGPoint(x: GK.duckStartX, y: GK.duckStartY)

    let body = SKPhysicsBody(circleOfRadius: GK.duckRadius * 0.68)
    body.categoryBitMask = GK.duckCategory
    body.contactTestBitMask = GK.pipeCategory | GK.groundCategory | GK.powerUpCategory | GK.breadCategory
    body.collisionBitMask = GK.groundCategory
    body.allowsRotation = false
    body.restitution = 0
    body.linearDamping = 0
    body.usesPreciseCollisionDetection = true
    duck.physicsBody = body

    return duck
}
