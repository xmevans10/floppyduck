import SpriteKit
import XCTest
@testable import FloppyDuck

final class BotCharacterTests: XCTestCase {

    // MARK: - Ladder Integrity

    func testEightBotsInLadder() {
        XCTAssertEqual(BotCharacter.all.count, 8)
    }

    func testAllBotsHaveUniqueIds() {
        let ids = BotCharacter.all.map { $0.id }
        XCTAssertEqual(ids.count, Set(ids).count, "Bot IDs must all be unique")
    }

    func testAllBotsHaveUniqueSkins() {
        let skins = BotCharacter.all.map { $0.skin }
        XCTAssertEqual(skins.count, Set(skins).count, "Each bot must have a different skin")
    }

    // MARK: - Difficulty Progression

    func testBotLadderDifficultyIncreases() {
        let bots = BotCharacter.all

        for i in 1..<bots.count {
            let prev = bots[i - 1].difficulty
            let curr = bots[i].difficulty

            XCTAssertLessThanOrEqual(curr.noiseRange, prev.noiseRange,
                "\(bots[i].id) noise should be ≤ \(bots[i-1].id) noise")
            XCTAssertGreaterThanOrEqual(curr.flapStrength, prev.flapStrength,
                "\(bots[i].id) flapStrength should be ≥ \(bots[i-1].id) flapStrength")
            XCTAssertLessThanOrEqual(curr.errorRate, prev.errorRate,
                "\(bots[i].id) errorRate should be ≤ \(bots[i-1].id) errorRate")
        }
    }

    func testBotTargetScoresIncrease() {
        let bots = BotCharacter.all

        for i in 1..<bots.count {
            XCTAssertGreaterThan(bots[i].targetScore, bots[i - 1].targetScore,
                "\(bots[i].id) target score should exceed \(bots[i-1].id)")
        }
    }

    // MARK: - Lookup

    func testFindByIdReturnsCorrectBot() {
        let bot = BotCharacter.find("drake")

        XCTAssertNotNil(bot)
        XCTAssertEqual(bot?.name, "DRAKE")
        XCTAssertEqual(bot?.title, "Competitor")
        XCTAssertEqual(bot?.skin, .dinosaur)
    }

    func testFindByIdReturnsNilForInvalid() {
        XCTAssertNil(BotCharacter.find("nonexistent"))
        XCTAssertNil(BotCharacter.find(""))
    }

    // MARK: - Controller Parity

    func testBotControllerUsesSamePhysicsContactEnvelopeAsPlayer() throws {
        let worldNode = SKNode()
        let hudLayer = SKNode()
        let controller = BotController(worldNode: worldNode, hudLayer: hudLayer)
        controller.setup(skin: .classic)

        let body = try XCTUnwrap(controller.sprite?.physicsBody)

        XCTAssertEqual(body.categoryBitMask, GK.botCategory)
        XCTAssertEqual(body.contactTestBitMask, GK.pipeCategory | GK.groundCategory | GK.scoreCategory)
        XCTAssertEqual(body.collisionBitMask, 0)
    }
}
