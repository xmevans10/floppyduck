import XCTest
import SpriteKit
@testable import FloppyDuck

final class HumanBotAITests: XCTestCase {

    // MARK: - Profile Ladder Progression

    /// Every bot's HumanBotProfile must get strictly harder up the ladder:
    /// faster reactions, tighter motor noise, longer attention span.
    func testProfileDifficultyProgresses() {
        let bots = BotCharacter.all

        for i in 1..<bots.count {
            let prev = bots[i - 1].profile
            let curr = bots[i].profile

            XCTAssertLessThanOrEqual(curr.reactionBase, prev.reactionBase,
                "\(bots[i].id) reactionBase should be ≤ \(bots[i-1].id)")
            XCTAssertLessThanOrEqual(curr.motorσ, prev.motorσ,
                "\(bots[i].id) motorσ should be ≤ \(bots[i-1].id)")
            XCTAssertGreaterThanOrEqual(curr.perceptionRange, prev.perceptionRange,
                "\(bots[i].id) perceptionRange should be ≥ \(bots[i-1].id)")
            XCTAssertLessThanOrEqual(curr.aimBiasσ, prev.aimBiasσ,
                "\(bots[i].id) aimBiasσ should be ≤ \(bots[i-1].id)")
            XCTAssertGreaterThan(curr.targetScore, prev.targetScore,
                "\(bots[i].id) targetScore should exceed \(bots[i-1].id)")
        }
    }

    /// Profiles should have sane value ranges (no accidental negatives, etc.)
    func testProfileValuesInRange() {
        for bot in BotCharacter.all {
            let p = bot.profile
            XCTAssertGreaterThan(p.reactionBase, 0, "\(bot.id) reactionBase > 0")
            XCTAssertGreaterThan(p.reactionσ, 0, "\(bot.id) reactionσ > 0")
            XCTAssertGreaterThan(p.motorσ, 0, "\(bot.id) motorσ > 0")
            XCTAssertGreaterThan(p.perceptionRange, 100, "\(bot.id) perceptionRange > 100")
            XCTAssertGreaterThan(p.aimBiasσ, 0, "\(bot.id) aimBiasσ > 0")
            XCTAssertGreaterThan(p.panicDistance, 0, "\(bot.id) panicDistance > 0")
            XCTAssertGreaterThan(p.targetScore, 0, "\(bot.id) targetScore > 0")
            XCTAssertTrue(p.panicFlapChance >= 0 && p.panicFlapChance <= 1,
                "\(bot.id) panicFlapChance in [0,1]")
            XCTAssertTrue(p.attentionFloor > 0 && p.attentionFloor < 1,
                "\(bot.id) attentionFloor in (0,1)")
            XCTAssertTrue(p.deathPressureRate > 0 && p.deathPressureRate < 1,
                "\(bot.id) deathPressureRate in (0,1)")
        }
    }

    // MARK: - Behavioral AI Unit Tests

    /// The AI should not flap before its reaction time elapses.
    func testReactionTimeGating() {
        let profile = HumanBotProfile(
            reactionBase: 0.30, reactionσ: 0.001, motorσ: 0.001,
            perceptionRange: 500, aimBiasσ: 1,
            panicDistance: 50, panicMisalignment: 30, panicFlapChance: 0,
            fatigueRate: 0, scoreRecovery: 0, attentionFloor: 1.0,
            targetScore: 100, deathPressureRate: 0
        )
        let ai = HumanBotAI(profile: profile)

        // First call at t=0 should be allowed (lastDecisionTime starts at 0)
        _ = ai.update(currentTime: 0.01, dt: 0.016,
                      birdY: 200, velocity: -50,
                      nextGapY: 350, nextGapDist: 100, pipeGap: 200)

        // Call at t=0.1 should be gated (< 0.30 reaction base)
        let flap = ai.update(currentTime: 0.10, dt: 0.016,
                             birdY: 200, velocity: -50,
                             nextGapY: 350, nextGapDist: 100, pipeGap: 200)
        XCTAssertFalse(flap, "Should not flap before reaction time elapses")
    }

    /// The AI should not react to pipes outside perception range.
    func testPerceptionGating() {
        let profile = HumanBotProfile(
            reactionBase: 0.01, reactionσ: 0.001, motorσ: 0.001,
            perceptionRange: 200, aimBiasσ: 1,
            panicDistance: 50, panicMisalignment: 30, panicFlapChance: 0,
            fatigueRate: 0, scoreRecovery: 0, attentionFloor: 1.0,
            targetScore: 100, deathPressureRate: 0
        )
        let ai = HumanBotAI(profile: profile)

        // Pipe at 300pts away should be outside 200pt perception
        let flap = ai.update(currentTime: 1.0, dt: 0.016,
                             birdY: 200, velocity: -100,
                             nextGapY: 350, nextGapDist: 300, pipeGap: 200)
        XCTAssertFalse(flap, "Should not react to pipes outside perception range")
    }

    /// Death pressure should activate past targetScore.
    func testDeathPressureActivates() {
        let profile = HumanBotProfile(
            reactionBase: 0.01, reactionσ: 0.001, motorσ: 0.001,
            perceptionRange: 500, aimBiasσ: 1,
            panicDistance: 50, panicMisalignment: 30, panicFlapChance: 0,
            fatigueRate: 0, scoreRecovery: 0, attentionFloor: 1.0,
            targetScore: 5, deathPressureRate: 0.50
        )
        let ai = HumanBotAI(profile: profile)

        XCTAssertFalse(ai.isInDeathSpiral)

        // Score past target
        for _ in 0..<8 {
            ai.onScored()
        }

        // deathPressure = min(1.0, 4 * 0.50) = 1.0 ≥ 0.9 → death spiral
        // Need to call update to trigger the check
        _ = ai.update(currentTime: 10.0, dt: 0.016,
                      birdY: 300, velocity: 0,
                      nextGapY: 300, nextGapDist: 100, pipeGap: 200)

        XCTAssertTrue(ai.isInDeathSpiral, "Should enter death spiral past targetScore")
    }

    /// Reset should clear all mutable state.
    func testResetClearsState() {
        let profile = BotCharacter.all[3].profile // Drake
        let ai = HumanBotAI(profile: profile)

        // Accumulate some state
        for _ in 0..<30 { ai.onScored() }
        _ = ai.update(currentTime: 5.0, dt: 0.016,
                      birdY: 300, velocity: 0,
                      nextGapY: 300, nextGapDist: 100, pipeGap: 200)

        ai.reset()
        XCTAssertFalse(ai.isInDeathSpiral, "Reset should clear death spiral")
    }

    // MARK: - Replay Bot Tests

    func testReplayBotPlaysBackTimestamps() {
        let replay = ReplayBotAI.ReplayData(
            pipeSeed: 42,
            flapTimestamps: [0.5, 1.2, 2.0, 3.5],
            finalScore: 4
        )
        let bot = ReplayBotAI(replay: replay)

        XCTAssertFalse(bot.update(currentTime: 0.3))     // Before first flap
        XCTAssertTrue(bot.update(currentTime: 0.5))      // First flap at 0.5
        XCTAssertFalse(bot.update(currentTime: 0.8))     // Between flaps
        XCTAssertTrue(bot.update(currentTime: 1.2))      // Second flap at 1.2
        XCTAssertTrue(bot.update(currentTime: 2.5))      // Third flap (past 2.0)
        XCTAssertTrue(bot.update(currentTime: 3.5))      // Fourth flap
        XCTAssertFalse(bot.update(currentTime: 4.0))     // No more flaps
        XCTAssertTrue(bot.isFinished)
    }

    func testReplayBotResets() {
        let replay = ReplayBotAI.ReplayData(
            pipeSeed: 42, flapTimestamps: [0.5, 1.0], finalScore: 2
        )
        let bot = ReplayBotAI(replay: replay)

        _ = bot.update(currentTime: 0.5)
        _ = bot.update(currentTime: 1.0)
        XCTAssertTrue(bot.isFinished)

        bot.reset()
        XCTAssertFalse(bot.isFinished)
        XCTAssertTrue(bot.update(currentTime: 0.5)) // Replays from start
    }

    // MARK: - Performance Benchmarks

    /// Benchmark: HumanBotAI.update() in isolation.
    /// Budget: must complete 60,000 calls (= 1000 seconds at 60fps) well under 1 second.
    /// The reaction gate means most calls are cheap early-exits.
    func testBotAIPerformance() {
        let profile = BotCharacter.all.last!.profile // The Duck (hardest = most computation)
        let ai = HumanBotAI(profile: profile)
        let dt = 1.0 / 60.0

        measure {
            ai.reset()
            var t: TimeInterval = 0
            for _ in 0..<60_000 {
                t += dt
                _ = ai.update(currentTime: t, dt: dt,
                              birdY: 300 + CGFloat.random(in: -50...50),
                              velocity: CGFloat.random(in: -200...100),
                              nextGapY: 340,
                              nextGapDist: CGFloat.random(in: 30...300),
                              pipeGap: 200)
                // Simulate scoring every ~60 frames
                if Int(t * 60) % 60 == 0 { ai.onScored() }
            }
        }
    }

    /// Benchmark: Full BotController.update() with pipe nodes (end-to-end).
    /// This is what actually runs per frame in GameScene.
    func testBotControllerFullUpdatePerformance() {
        let worldNode = SKNode()
        let hudLayer = SKNode()
        let controller = BotController(worldNode: worldNode, hudLayer: hudLayer)

        let bot = BotCharacter.all.last! // The Duck
        controller.setup(skin: .classic,
                         difficulty: bot.difficulty,
                         profile: bot.profile,
                         deathScore: bot.targetScore)
        controller.startPlaying()

        // Create realistic pipe layout (5 pipes on screen)
        var pipes: [SKNode] = []
        for i in 0..<5 {
            let pipe = SKNode()
            pipe.position = CGPoint(x: CGFloat(200 + i * 180), y: 0)
            pipe.name = "pipe_\(i)"

            let trigger = SKNode()
            trigger.name = "scoreTrigger"
            trigger.position = CGPoint(x: 0, y: CGFloat.random(in: 250...450))
            pipe.addChild(trigger)

            pipes.append(pipe)
        }

        let dt = 1.0 / 60.0

        measure {
            // 6000 frames = 100 seconds of gameplay
            for _ in 0..<6_000 {
                controller.update(
                    dt: dt,
                    pipeNodes: pipes,
                    activePowerUps: [],
                    effectivePipeGap: GK.pipeGap
                )
            }
        }
    }

    /// Benchmark: Full GameScene update with bot active.
    /// This is the ultimate "does it drop FPS?" test.
    func testGameLoopWithBotPerformance() {
        let bot = BotCharacter.all.last!
        let scene = GameScene(
            seed: 12345,
            mode: .vsBot,
            skin: .classic,
            botSkin: .golden,
            botDifficulty: bot.difficulty,
            botProfile: bot.profile,
            opponentName: bot.name,
            targetScore: bot.targetScore
        )

        let view = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        scene.scaleMode = .aspectFill
        view.presentScene(scene)

        let dt = 1.0 / 60.0
        var absoluteTime: TimeInterval = 0

        measure {
            for _ in 0..<1000 {
                absoluteTime += dt
                scene.update(absoluteTime)
            }
        }
    }
}
