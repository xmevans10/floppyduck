import SwiftUI
import SpriteKit

/// Hosts the SpriteKit GameScene inside SwiftUI with overlays for game state.
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
            
            Text("Tap to Start")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
                .opacity(0.9)
            
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 36))
                .foregroundColor(.white.opacity(0.7))
                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
            
            Spacer()
            Spacer()
        }
    }
    
    // MARK: - Game Over
    
    private var gameOverOverlay: some View {
        ZStack {
            // Blur backdrop
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("Game Over")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                // Score card
                VStack(spacing: 8) {
                    Text("SCORE")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .tracking(1)
                    
                    Text("\(bridge.score)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    if bridge.score >= gameManager.bestScore && bridge.score > 0 {
                        Label("New Best!", systemImage: "crown.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.yellow)
                    }
                }
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
                .background(Color(white: 0.15), in: RoundedRectangle(cornerRadius: 16))
                
                // Buttons
                VStack(spacing: 12) {
                    Button {
                        Haptic.buttonTap()
                        gameManager.reportScore(bridge.score)
                        bridge.reset()
                    } label: {
                        Text("Play Again")
                            .font(.system(size: 17, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(14)
                    }
                    
                    Button {
                        Haptic.buttonTap()
                        gameManager.reportScore(bridge.score)
                        gameManager.popToRoot()
                    } label: {
                        Text("Home")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(white: 0.2))
                            .foregroundColor(.white)
                            .cornerRadius(14)
                    }
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .padding(.horizontal, 32)
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
