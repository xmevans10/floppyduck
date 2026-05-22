import XCTest
import SpriteKit
@testable import FloppyDuck

final class GameSceneTests: XCTestCase {

    @MainActor
    func testGameSceneDoesNotCrashOnPipeSpawn() {
        // Arrange
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let scene = GameScene(seed: 12345, mode: .classic, skin: .classic, botDifficulty: nil, opponentName: nil, targetScore: nil)
        scene.scaleMode = .aspectFill
        view.presentScene(scene)
        
        // Act - Simulate a few frames of update to trigger pipe spawn if any,
        // or just forcefully call the initial updates
        scene.update(0.0)
        scene.update(1.0)
        scene.update(2.0)
        scene.update(3.0)
        
        // Assert
        // We just want to ensure it compiles (no scope errors) and doesn't crash at runtime
        XCTAssertNotNil(scene.scene)
        
        // Verify pipes exist in the layer
        let pipeLayer = scene.childNode(withName: "worldNode")?.childNode(withName: "pipeLayer")
        XCTAssertNotNil(pipeLayer, "Pipe layer should exist")
    }

    @MainActor
    func testHeadToHeadUsesScoreHudWithoutGhostSprite() {
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let scene = GameScene(
            seed: 12345,
            mode: .headToHead,
            powerUpsEnabled: false,
            skin: .classic,
            botDifficulty: nil,
            opponentName: "Rival",
            targetScore: nil
        )

        view.presentScene(scene)

        XCTAssertEqual(scene.debugDuckAlpha(), 1.0)
        XCTAssertNil(scene.debugGhostDuckAlpha())
    }
}
