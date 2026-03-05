import SwiftUI
import SpriteKit

struct GameContainerView: View {
    let config: GameModeConfig
    @EnvironmentObject var manager: GameManager

    @State private var scene: GameScene?
    @State private var bridge: GameSceneBridge?
    @State private var phase: GamePhase = .ready
    @State private var score: Int = 0
    @State private var botFinalScore: Int = 0
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
                // Dim layer behind game over
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .transition(.opacity)

                gameOverOverlay
                    .transition(.scale.combined(with: .opacity))
            default:
                EmptyView()
            }
        }
        .onAppear { setupScene() }
        .statusBarHidden(true)
    }

    // MARK: - Scene Setup

    private func setupScene() {
        let newScene = GameScene(seed: config.seed, mode: config.mode)
        let newBridge = GameSceneBridge(
            onStart: { phase = .playing },
            onScore: { score = $0 },
            onEnd: { finalScore in
                score = finalScore
                // Grab bot score from scene before showing overlay
                botFinalScore = newScene.botScore

                let won: Bool?
                if config.mode == .vsBot {
                    won = finalScore > newScene.botScore
                } else {
                    won = nil
                }

                manager.recordGame(score: finalScore, won: won)
                withAnimation(.easeOut(duration: 0.35)) {
                    phase = .gameOver
                }
            },
            onBotScore: { bs in
                botFinalScore = bs
            }
        )
        newScene.gameDelegate = newBridge
        bridge = newBridge
        scene = newScene
    }

    // MARK: - Get Ready Overlay

    private var getReadyOverlay: some View {
        VStack(spacing: 16) {
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
            // Title: VS Bot shows WIN/LOSE, classic shows GAME OVER
            if config.mode == .vsBot {
                let playerWon = score > botFinalScore
                Text(playerWon ? "YOU WIN!" : "BOT WINS")
                    .font(.custom(GK.pixelFontName, size: 22))
                    .foregroundColor(playerWon ? GK.Colors.scoreYellow : .white)
                    .shadow(color: GK.Colors.pipeBorder, radius: 0, x: 3, y: 3)
            } else {
                Text("GAME OVER")
                    .font(.custom(GK.pixelFontName, size: 22))
                    .foregroundColor(.white)
                    .shadow(color: GK.Colors.pipeBorder, radius: 0, x: 3, y: 3)
            }

            // Score panel
            VStack(spacing: 14) {
                // Player score
                HStack {
                    Text(config.mode == .vsBot ? "YOU" : "SCORE")
                        .font(.custom(GK.pixelFontName, size: 10))
                        .foregroundColor(GK.Colors.panelBorder)
                    Spacer()
                    Text("\(score)")
                        .font(.custom(GK.pixelFontName, size: 18))
                        .foregroundColor(GK.Colors.panelBorder)
                }

                // Bot score (VS Bot only)
                if config.mode == .vsBot {
                    Divider()
                    HStack {
                        HStack(spacing: 6) {
                            pixelIcon(.bot, size: 14)
                            Text("BOT")
                                .font(.custom(GK.pixelFontName, size: 10))
                                .foregroundColor(GK.Colors.panelBorder)
                        }
                        Spacer()
                        Text("\(botFinalScore)")
                            .font(.custom(GK.pixelFontName, size: 18))
                            .foregroundColor(UIColor(red: 0.85, green: 0.30, blue: 0.30, alpha: 1).asSwiftUI)
                    }
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
                    botFinalScore = 0
                    withAnimation(.easeOut(duration: 0.2)) {
                        phase = .ready
                    }
                    scene?.resetGame()
                }

                // Home
                actionButton(icon: .home, label: "HOME", color: GK.Colors.buttonOrange) {
                    manager.dismissGame()
                }
            }
            .padding(.horizontal, 40)

            // Share
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
    let onBotScore: (Int) -> Void

    init(onStart: @escaping () -> Void,
         onScore: @escaping (Int) -> Void,
         onEnd: @escaping (Int) -> Void,
         onBotScore: @escaping (Int) -> Void = { _ in }) {
        self.onStart = onStart
        self.onScore = onScore
        self.onEnd = onEnd
        self.onBotScore = onBotScore
    }

    func gameDidStart() { onStart() }
    func gameDidScore(_ score: Int) { onScore(score) }
    func gameDidEnd(score: Int) { onEnd(score) }
    func botDidScore(_ botScore: Int) { onBotScore(botScore) }
}

// MARK: - UIColor → SwiftUI Color

private extension UIColor {
    var asSwiftUI: Color {
        Color(self)
    }
}
