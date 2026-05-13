import XCTest
import SpriteKit
@testable import FloppyDuck

@MainActor
final class GamePerformanceTests: XCTestCase {

    func testGameLoopPerformance() {
        // Arrange: Setup a basic headless scene
        let scene = GameScene(seed: 12345, mode: .classic, skin: .classic, botDifficulty: nil, opponentName: nil, targetScore: nil)

        // We create an SKView just to simulate a render pass lifecycle, but we don't present it on screen
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        scene.scaleMode = .aspectFill
        view.presentScene(scene)

        let delta: TimeInterval = 1.0 / 60.0 // 60fps delta

        // Act & Assert: Measure the time it takes to run 1000 frames (~16 seconds of gameplay)
        var absoluteTime: TimeInterval = 0
        measure {
            for _ in 0..<1000 {
                absoluteTime += delta
                scene.update(absoluteTime)
            }
        }
    }

    func testExportThemeParallaxQAFrames() throws {
        let markerPath = "/Users/xanderevans/Documents/floppyduck/.export-theme-qa"
        guard ProcessInfo.processInfo.environment["EXPORT_THEME_QA"] == "1"
                || FileManager.default.fileExists(atPath: markerPath) else {
            throw XCTSkip("Set EXPORT_THEME_QA=1 to export gameplay parallax QA frames.")
        }

        let output = URL(fileURLWithPath: ProcessInfo.processInfo.environment["THEME_QA_OUTPUT"]
                         ?? "/Users/xanderevans/Documents/floppyduck/artifacts/theme_recipe_previews/game_rendered",
                         isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

        for theme in BackgroundTheme.allCases {
            let scene = SKScene(size: CGSize(width: GK.worldWidth, height: GK.worldHeight))
            scene.scaleMode = .aspectFit
            scene.backgroundColor = theme.backgroundColor

            let backgroundLayer = SKNode()
            let groundLayer = SKNode()
            let foregroundLayer = SKNode()
            scene.addChild(backgroundLayer)
            scene.addChild(groundLayer)
            scene.addChild(foregroundLayer)

            let parallax = ParallaxManager(backgroundLayer: backgroundLayer,
                                           groundLayer: groundLayer,
                                           foregroundLayer: foregroundLayer,
                                           theme: theme)
            parallax.setup()

            let view = SKView(frame: CGRect(x: 0, y: 0, width: GK.worldWidth, height: GK.worldHeight))
            view.presentScene(scene)
            view.layoutIfNeeded()

            guard let texture = view.texture(from: scene) else {
                XCTFail("Failed to snapshot theme \(theme.rawValue)")
                continue
            }

            let image = UIImage(cgImage: texture.cgImage())
            let file = output.appendingPathComponent("\(theme.rawValue).png")
            try XCTUnwrap(image.pngData(), "Missing PNG data for \(theme.rawValue)")
                .write(to: file, options: .atomic)
        }
    }
}
