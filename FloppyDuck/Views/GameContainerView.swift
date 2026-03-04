import SwiftUI
import SpriteKit

/// Hosts the SpriteKit GameScene inside SwiftUI with retro-styled overlays.
struct GameContainerView: View {
    @EnvironmentObject var gameManager: GameManager
    @StateObject private var bridge = GameBridge()

    let mode: GameMode

    var body: some View {
        ZStack {
            // SpriteKit game
            SpriteView(scene: bridge.scene, options: [.allowsTransparency])
                .ignoresSafeArea()
                .onTapGesture {
                    if bridge.phase == .gameOver {
                        // handled by overlay
                    } else {
                        bridge.scene.flap()
                    }
                }

            // Ready overlay
            if bridge.phase == .ready {
                readyOverlay
                    .transition(.opacity)
            }

            // Game Over overlay
            if bridge.phase == .gameOver {
                gameOverOverlay
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.9).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: bridge.phase == .gameOver)
        .navigationBarBackButtonHidden(true)
        .statusBarHidden()
        .onAppear {
            bridge.scene.gameDelegate = bridge
        }
    }

    // MARK: - Ready Overlay

    private var readyOverlay: some View {
        VStack(spacing: 16) {
            Spacer()

            ZStack {
                Text("Get Ready!")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundColor(GK.Colors.panelBorder)
                    .offset(x: 2, y: 2)
                Text("Get Ready!")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundColor(.white)
            }

            Text("👆")
                .font(.system(size: 40))
                .opacity(0.8)

            Text("Tap to flap!")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)

            Spacer()
            Spacer()
        }
    }

    // MARK: - Game Over

    private var gameOverOverlay: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                // "Game Over" title
                ZStack {
                    Text("Game Over")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundStyle(GK.Colors.panelBorder)
                        .offset(x: 2, y: 2)
                    Text("Game Over")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }

                // Score card (retro panel)
                VStack(spacing: 6) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("SCORE")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(GK.Colors.panelBorder.opacity(0.6))
                            Text("\(bridge.score)")
                                .font(.system(size: 36, weight: .black, design: .rounded))
                                .foregroundStyle(GK.Colors.panelBorder)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("BEST")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(GK.Colors.panelBorder.opacity(0.6))
                            Text("\(max(bridge.score, gameManager.bestScore))")
                                .font(.system(size: 36, weight: .black, design: .rounded))
                                .foregroundStyle(GK.Colors.panelBorder)
                        }
                    }

                    if bridge.score >= gameManager.bestScore && bridge.score > 0 {
                        Text("★ NEW BEST! ★")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundStyle(GK.Colors.buttonOrange)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(GK.Colors.panelCream)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(GK.Colors.panelBorder, lineWidth: 3)
                        )
                        .shadow(color: GK.Colors.panelBorder.opacity(0.3), radius: 0, x: 2, y: 3)
                )

                // Medal area (placeholder for future medal logic)

                // Buttons
                HStack(spacing: 12) {
                    Button {
                        Haptic.buttonTap()
                        gameManager.reportScore(bridge.score)
                        bridge.reset()
                    } label: {
                        Text("↻ Retry")
                            .font(.system(size: 17, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(GK.Colors.buttonGreen)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.black.opacity(0.3), lineWidth: 3)
                                    )
                                    .shadow(color: .black.opacity(0.25), radius: 0, x: 2, y: 3)
                            )
                    }
                    .buttonStyle(RetroPress())

                    Button {
                        Haptic.buttonTap()
                        gameManager.reportScore(bridge.score)
                        gameManager.popToRoot()
                    } label: {
                        Text("🏠 Home")
                            .font(.system(size: 17, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(GK.Colors.buttonOrange)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.black.opacity(0.3), lineWidth: 3)
                                    )
                                    .shadow(color: .black.opacity(0.25), radius: 0, x: 2, y: 3)
                            )
                    }
                    .buttonStyle(RetroPress())
                }
            }
            .padding(24)
            .padding(.top, 8)
        }
    }
}

// MARK: - Bridge (connects SpriteKit → SwiftUI)

@MainActor
final class GameBridge: ObservableObject, GameSceneDelegate {
    @Published var phase: GamePhase = .ready
    @Published var score: Int = 0

    let scene: GameScene

    init() {
        self.scene = GameScene()
    }

    func gameDidStart() {
        phase = .playing
    }

    func gameDidScore(_ score: Int) {
        self.score = score
    }

    func gameDidEnd(score: Int) {
        self.score = score
        phase = .gameOver
    }

    func reset() {
        scene.resetGame()
        phase = .ready
        score = 0
    }
}
