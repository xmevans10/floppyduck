import SwiftUI
import SpriteKit

struct GameContainerView: View {
    let config: GameModeConfig
    @EnvironmentObject var manager: GameManager

    @State private var scene: GameScene?
    @State private var bridge: GameSceneBridge?
    @State private var phase: GamePhase = .ready
    @State private var score: Int = 0
    @State private var countdownValue: Int = 3

    private let icons = PixelIconFactory.shared

    var body: some View {
        ZStack {
            // SpriteKit scene
            if let scene {
                SpriteView(scene: scene, preferredFramesPerSecond: 60)
                    .ignoresSafeArea()
            }

            // Overlays
            switch phase {
            case .ready:
                getReadyOverlay
            case .countdown:
                countdownOverlay
            case .gameOver:
                gameOverOverlay
            default:
                EmptyView()
            }
        }
        .onAppear { setupScene() }
        .navigationBarHidden(true)
    }

    // MARK: - Scene Setup

    private func setupScene() {
        let newScene = GameScene(seed: config.seed)
        let newBridge = GameSceneBridge(
            onStart: { phase = .playing },
            onScore: { score = $0 },
            onEnd: { finalScore in
                score = finalScore
                manager.recordGame(
                    score: finalScore,
                    won: config.mode == .vsBot ? (finalScore > 5) : nil
                )
                phase = .gameOver
            }
        )
        newScene.gameDelegate = newBridge
        bridge = newBridge
        scene = newScene
    }

    // MARK: - Get Ready Overlay

    private var getReadyOverlay: some View {
        VStack(spacing: 16) {
            // Panel
            VStack(spacing: 12) {
                Text("GET READY")
                    .font(.custom(GK.pixelFontName, size: 20))
                    .foregroundColor(GK.Colors.panelBorder)

                if config.mode == .vsBot {
                    HStack(spacing: 8) {
                        pixelIcon(.bot, size: 18)
                        Text("VS BOT")
                            .font(.custom(GK.pixelFontName, size: 10))
                            .foregroundColor(GK.Colors.panelBorder.opacity(0.7))
                    }
                } else if config.mode == .classic {
                    HStack(spacing: 8) {
                        pixelIcon(.classic, size: 18)
                        Text("CLASSIC")
                            .font(.custom(GK.pixelFontName, size: 10))
                            .foregroundColor(GK.Colors.panelBorder.opacity(0.7))
                    }
                }

                // Tap to play
                HStack(spacing: 8) {
                    pixelIcon(.tapHand, size: 22)
                    Text("TAP TO FLAP")
                        .font(.custom(GK.pixelFontName, size: 9))
                        .foregroundColor(GK.Colors.panelBorder.opacity(0.6))
                }
                .padding(.top, 6)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(GK.Colors.panelCream)
                    .shadow(color: Color.black.opacity(0.2), radius: 8, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(GK.Colors.panelBorder, lineWidth: 3)
            )
        }
    }

    // MARK: - Countdown

    private var countdownOverlay: some View {
        Text("\(countdownValue)")
            .font(.custom(GK.pixelFontName, size: 56))
            .foregroundColor(.white)
            .shadow(color: GK.Colors.pipeBorder, radius: 0, x: 3, y: 3)
    }

    // MARK: - Game Over Overlay

    private var gameOverOverlay: some View {
        VStack(spacing: 16) {
            Text("GAME OVER")
                .font(.custom(GK.pixelFontName, size: 22))
                .foregroundColor(.white)
                .shadow(color: GK.Colors.pipeBorder, radius: 0, x: 3, y: 3)

            // Score panel
            VStack(spacing: 14) {
                // Score
                HStack {
                    Text("SCORE")
                        .font(.custom(GK.pixelFontName, size: 10))
                        .foregroundColor(GK.Colors.panelBorder)
                    Spacer()
                    Text("\(score)")
                        .font(.custom(GK.pixelFontName, size: 18))
                        .foregroundColor(GK.Colors.panelBorder)
                }

                Divider()

                // Best
                HStack {
                    Text("BEST")
                        .font(.custom(GK.pixelFontName, size: 10))
                        .foregroundColor(GK.Colors.panelBorder)
                    Spacer()
                    Text("\(manager.stats.bestScore)")
                        .font(.custom(GK.pixelFontName, size: 18))
                        .foregroundColor(GK.Colors.scoreYellow)
                }

                Divider()

                // Bread earned
                HStack {
                    Image(uiImage: TextureFactory.shared.breadUIImage(pixelScale: 3.0))
                        .interpolation(.none)
                        .resizable()
                        .frame(width: 20, height: 16)
                    Text("+\(max(1, score))")
                        .font(.custom(GK.pixelFontName, size: 10))
                        .foregroundColor(GK.Colors.breadGold)
                    Spacer()
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(GK.Colors.panelCream)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(GK.Colors.panelBorder, lineWidth: 3)
            )
            .padding(.horizontal, 40)

            // Action buttons
            HStack(spacing: 16) {
                // Retry
                actionButton(icon: .retry, label: "RETRY", color: GK.Colors.buttonGreen) {
                    score = 0
                    phase = .ready
                    scene?.resetGame()
                }

                // Home
                actionButton(icon: .home, label: "HOME", color: GK.Colors.buttonOrange) {
                    manager.goHome()
                }
            }
            .padding(.horizontal, 40)

            // Share score
            Button {
                shareScore()
            } label: {
                HStack(spacing: 8) {
                    pixelIcon(.share, size: 16)
                    Text("SHARE")
                        .font(.custom(GK.pixelFontName, size: 9))
                }
                .foregroundColor(GK.Colors.panelBorder)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(GK.Colors.panelCream)
                        .overlay(Capsule().stroke(GK.Colors.panelBorder, lineWidth: 2))
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Buttons

    private func actionButton(icon: PixelIcon, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                pixelIcon(icon, size: 22)
                Text(label)
                    .font(.custom(GK.pixelFontName, size: 8))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(color)
                    .shadow(color: color.opacity(0.5), radius: 0, x: 0, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.black.opacity(0.3), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private func pixelIcon(_ icon: PixelIcon, size: CGFloat) -> some View {
        Image(uiImage: icons.image(for: icon))
            .interpolation(.none)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
    }

    private func shareScore() {
        let text = "I scored \(score) in Floppy Duck! 🦆 Can you beat that?"
        let vc = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(vc, animated: true)
        }
    }
}

// MARK: - Scene Bridge

private final class GameSceneBridge: GameSceneDelegate {
    let onStart: () -> Void
    let onScore: (Int) -> Void
    let onEnd: (Int) -> Void

    init(onStart: @escaping () -> Void,
         onScore: @escaping (Int) -> Void,
         onEnd: @escaping (Int) -> Void) {
        self.onStart = onStart
        self.onScore = onScore
        self.onEnd = onEnd
    }

    func gameDidStart() { onStart() }
    func gameDidScore(_ score: Int) { onScore(score) }
    func gameDidEnd(score: Int) { onEnd(score) }
}
