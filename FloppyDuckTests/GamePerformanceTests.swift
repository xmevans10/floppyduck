import XCTest
import SpriteKit
@testable import FloppyDuck

final class GamePerformanceTests: XCTestCase {

    func testGameLoopPerformance() {
        // Arrange: Setup a basic headless scene
        let scene = GameScene(seed: 12345, mode: .classic, skin: .default, botDifficulty: nil, opponentName: nil, targetScore: nil)
        
        // We create an SKView just to simulate a render pass lifecycle, but we don't present it on screen
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        scene.scaleMode = .aspectFill
        view.presentScene(scene)
        
        let delta: TimeInterval = 1.0 / 60.0 // 60fps delta
        
        // Act & Assert: Measure the time it takes to run 1000 frames (~16 seconds of gameplay)
        measure {
            var time: TimeInterval = 0
            for _ in 0..<1000 {
                time += delta
                scene.update(time)
            }
        }
    }
}
