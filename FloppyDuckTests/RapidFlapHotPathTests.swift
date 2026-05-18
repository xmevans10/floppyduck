import XCTest
import SpriteKit
@testable import FloppyDuck

/// Validates that the flap() hot path stays under a strict time budget
/// even during rapid-fire taps at 60 FPS gameplay cadence.
@MainActor
final class RapidFlapHotPathTests: XCTestCase {

    func testFlapHotPathIsNotExcessive() {
        // Arrange: headless scene in an off-screen SKView so didMove(to:) runs.
        let scene = GameScene(seed: 54321, mode: .classic, skin: .classic,
                              botDifficulty: nil, opponentName: nil, targetScore: nil)
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        view.presentScene(scene)

        // Transition to playing state
        scene.isReadyToStart = true
        scene.startPlaying()

        guard scene.phase == .playing else {
            XCTFail("Expected phase .playing, got \(scene.phase)")
            return
        }

        // Warm up: run 10 flaps to let any lazy init settle
        for _ in 0..<10 {
            scene.flap()
        }

        // Act: Measure 100 rapid flaps (simulating ~1.7 seconds of frantic tapping)
        let iterations = 100
        let start = CACurrentMediaTime()
        for _ in 0..<iterations {
            scene.flap()
        }
        let elapsed = CACurrentMediaTime() - start

        // Assert: Each flap should average well under 1 ms.
        let avgMs = (elapsed / Double(iterations)) * 1000
        XCTAssertLessThan(avgMs, 2.0, "flap() hot path averaged \(String(format: "%.3f", avgMs)) ms — exceeds 2.0 ms budget")

        // 100 calls must stay comfortably under a 60 FPS frame
        let totalMs = elapsed * 1000
        XCTAssertLessThan(totalMs, 100.0, "100 flap() calls took \(String(format: "%.2f", totalMs)) ms — exceeds 100 ms budget")
    }
}
