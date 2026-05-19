import SwiftUI
import AVFoundation

/// A small looping video player for onboarding previews.
/// Plays silently, loops forever, with rounded corners.
struct LoopingVideoView: UIViewRepresentable {
    let resourceName: String
    let fileExtension: String

    func makeUIView(context: Context) -> LoopingPlayerUIView {
        let view = LoopingPlayerUIView(resourceName: resourceName, fileExtension: fileExtension)
        return view
    }

    func updateUIView(_ uiView: LoopingPlayerUIView, context: Context) {}
}

final class LoopingPlayerUIView: UIView {
    private var player: AVQueuePlayer?
    private var playerLayer: AVPlayerLayer?
    private var looper: AVPlayerLooper?

    init(resourceName: String, fileExtension: String) {
        super.init(frame: .zero)
        backgroundColor = .clear

        guard let url = Bundle.main.url(forResource: resourceName, withExtension: fileExtension) else {
            return
        }

        let item = AVPlayerItem(url: url)
        let queuePlayer = AVQueuePlayer(items: [item])
        queuePlayer.isMuted = true

        let looper = AVPlayerLooper(player: queuePlayer, templateItem: item)

        let layer = AVPlayerLayer(player: queuePlayer)
        layer.videoGravity = .resizeAspectFill

        self.layer.addSublayer(layer)
        self.player = queuePlayer
        self.playerLayer = layer
        self.looper = looper

        queuePlayer.play()
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = bounds
    }
}
