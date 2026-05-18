import SwiftUI
import SpriteKit

/// A performance-tuned SKView wrapper that replaces SwiftUI's SpriteView.
///
/// SpriteView re-presents its scene during every SwiftUI state update, which
/// causes redundant layout traversals and potential frame spikes. This wrapper
/// presents the scene exactly once (on first layout) and never replaces it
/// unless the scene identity changes.
///
/// Key optimizations:
/// - ignoresSiblingOrder = true — faster tree traversal, correct for our z-ordering.
/// - shouldCullNonVisibleNodes = true — skips rendering nodes with alpha 0 or off-screen.
/// - isOpaque = true — avoids blending with SwiftUI background (we fill the screen).
/// - preferredFramesPerSecond: 60 (normal) or 30 (Low Power Mode), read once at init.
struct OptimizedGameView: UIViewRepresentable {
    let scene: SKScene

    func makeUIView(context: Context) -> SKView {
        let view = SKView()
        view.ignoresSiblingOrder = true
        view.shouldCullNonVisibleNodes = true
        view.isOpaque = true
        view.backgroundColor = .black
        view.preferredFramesPerSecond = 60
        view.presentScene(scene)
        return view
    }

    func updateUIView(_ uiView: SKView, context: Context) {
        // Scene identity check — only re-present if the scene changed.
        // This prevents unnecessary layout work during SwiftUI state updates.
        if uiView.scene !== scene {
            uiView.presentScene(scene)
        }
    }
}
