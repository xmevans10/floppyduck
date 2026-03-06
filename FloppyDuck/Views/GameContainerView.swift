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

    // Game-over animation states
    @State private var displayedScore: Int = 0
    @State private var previousBest: Int = 0
    @State private var countingDone: Bool = false
    @State private var showMedal: Bool = false
    @State private var showNewBest: Bool = false
    @State private var showBread: Bool = false
    @State private var countUpTimer: Timer?

    private let icons = PixelIconFactory.shared

    /// True if this game is a bot-ladder match with a target score.
    private var isBotLadder: Bool { config.botCharacterId != nil }

    /// For bot ladder: did the player reach the target score?
    private var ladderWon: Bool {
        guard let target = config.targetScore else { return score > botFinalScore }
        return score >= target
    }

    private var isNewBest: Bool { score > previousBest && score > 0 }

    private var medal: Medal { Medal.from(score: score) }

    var body: some View {
        ZStack {
            if let scene {
                SpriteView(scene: scene, preferredFramesPerSecond: 60)
                    .ignoresSafeArea()
            }

            switch phase {
            case .ready:
                getReadyOverlay
            case .countdown:
                countdownOverlay
            case .gameOver:
                // Darkened backdrop — 0.65 for clean separation
                Color.black.opacity(0.65)
                    .ignoresSafeArea()
                    .transition(.opacity)

                gameOverOverlay
                    .transition(.scale.combined(with: .opacity))
            default:
                EmptyView()
            }
        }
        .onAppear { setupScene() }
        .onDisappear { countUpTimer?.invalidate() }
        .statusBarHidden(true)
    }

    // MARK: - Scene Setup

    private func setupScene() {
        let skin = SkinManager.shared.selectedSkin
        let newScene = GameScene(
            seed: config.seed,
            mode: config.mode,
            skin: skin,
            botDifficulty: config.botDifficulty,
            opponentName: config.opponentName
        )
        let newBridge = GameSceneBridge(
            onStart: { phase = .playing },
            onScore: { score = $0 },
            onEnd: { finalScore in
                score = finalScore
                previousBest = manager.stats.bestScore   // capture BEFORE recording
                botFinalScore = newScene.botScore

                let won: Bool?
                if config.mode == .vsBot {
                    if isBotLadder {
                        won = ladderWon
                    } else {
                        won = finalScore > newScene.botScore
                    }
                } else {
                    won = nil
                }

                manager.recordGame(score: finalScore, won: won)

                // Bot ladder: mark bot beaten on win
                if isBotLadder, let botId = config.botCharacterId, score >= (config.targetScore ?? 0) {
                    manager.beatBot(botId)
                }

                // Play win/lose sound
                if let won {
                    if won { SoundManager.shared.play(.win); Haptic.win() }
                    else   { SoundManager.shared.play(.lose); Haptic.lose() }
                }

                withAnimation(.easeOut(duration: 0.35)) {
                    phase = .gameOver
                }

                // Start animated reveal sequence
                startGameOverAnimation()
            },
            onBotScore: { bs in botFinalScore = bs }
        )
        newScene.gameDelegate = newBridge
        bridge = newBridge
        scene = newScene
    }

    // MARK: - Game Over Animation Sequence

    private func startGameOverAnimation() {
        displayedScore = 0
        countingDone = false
        showMedal = false
        showNewBest = false
        showBread = false

        let final = score
        if final == 0 {
            displayedScore = 0
            finishCountUp()
            return
        }

        // Tick up from 0 → final over ~1.2s (min 40ms per tick)
        let interval = min(1.2 / Double(final), 0.04)

        countUpTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
            DispatchQueue.main.async {
                displayedScore += 1
                SoundManager.shared.play(.countTick)

                if displayedScore >= final {
                    timer.invalidate()
                    countUpTimer = nil
                    displayedScore = final
                    finishCountUp()
                }
            }
        }
    }

    private func finishCountUp() {
        countingDone = true

        // Medal bounce-in after short pause
        if medal != .none {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                    showMedal = true
                }
                SoundManager.shared.play(.medal)
            }
        }

        // New best celebration
        if isNewBest {
            let delay: Double = medal != .none ? 0.7 : 0.3
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) {
                    showNewBest = true
                }
                SoundManager.shared.play(.newBest)
                Haptic.newBest()
            }
        }

        // Bread earned slides in
        let breadDelay: Double = isNewBest ? 1.1 : (medal != .none ? 0.65 : 0.3)
        DispatchQueue.main.asyncAfter(deadline: .now() + breadDelay) {
            withAnimation(.easeOut(duration: 0.3)) {
                showBread = true
            }
        }
    }

    private func resetGameOverState() {
        countUpTimer?.invalidate()
        countUpTimer = nil
        displayedScore = 0
        countingDone = false
        showMedal = false
        showNewBest = false
        showBread = false
    }

    // MARK: - Get Ready Overlay

    private var getReadyOverlay: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                Text("GET READY")
                    .font(.custom(GK.pixelFontName, size: 20))
                    .foregroundColor(GK.Colors.panelBorder)

                if isBotLadder, let botId = config.botCharacterId,
                   let bot = BotCharacter.find(botId) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(bot.accentColor)
                            .frame(width: 20, height: 20)
                        Text("VS \(bot.name)")
                            .font(.custom(GK.pixelFontName, size: 10))
                            .foregroundColor(GK.Colors.panelBorder.opacity(0.7))
                    }
                    Text("SCORE \(bot.targetScore) TO WIN")
                        .font(.custom(GK.pixelFontName, size: 8))
                        .foregroundColor(GK.Colors.panelBorder.opacity(0.5))
                } else if config.mode == .vsBot {
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
            // Title
            gameOverTitle

            // Score panel with animated counter
            scorePanel
                .padding(.horizontal, 40)

            // Action buttons (appear after count-up)
            if countingDone {
                HStack(spacing: 16) {
                    actionButton(icon: .retry, label: "RETRY", color: GK.Colors.buttonGreen) {
                        SoundManager.shared.play(.button)
                        resetGameOverState()
                        score = 0
                        botFinalScore = 0
                        withAnimation(.easeOut(duration: 0.2)) {
                            phase = .ready
                        }
                        scene?.resetGame()
                    }

                    actionButton(icon: .home, label: "HOME", color: GK.Colors.buttonOrange) {
                        SoundManager.shared.play(.button)
                        resetGameOverState()
                        manager.dismissGame()
                    }
                }
                .padding(.horizontal, 40)
                .transition(.opacity.combined(with: .move(edge: .bottom)))

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
                .transition(.opacity)
            }
        }
    }

    // MARK: - Game Over Title

    @ViewBuilder
    private var gameOverTitle: some View {
        if config.mode == .vsBot {
            let playerWon = isBotLadder ? ladderWon : score > botFinalScore
            Text(playerWon ? "YOU WIN!" : "TRY AGAIN")
                .font(.custom(GK.pixelFontName, size: 22))
                .foregroundColor(playerWon ? GK.Colors.scoreYellow : .white)
                .shadow(color: GK.Colors.pipeBorder, radius: 0, x: 3, y: 3)

            if isBotLadder, let target = config.targetScore {
                Text(playerWon ? "TARGET: \(target) ✓" : "NEED: \(target)")
                    .font(.custom(GK.pixelFontName, size: 8))
                    .foregroundColor(playerWon ? GK.Colors.scoreYellow.opacity(0.8) : .white.opacity(0.6))
            }
        } else {
            Text("GAME OVER")
                .font(.custom(GK.pixelFontName, size: 22))
                .foregroundColor(.white)
                .shadow(color: GK.Colors.pipeBorder, radius: 0, x: 3, y: 3)
        }
    }

    // MARK: - Score Panel (animated)

    private var scorePanel: some View {
        VStack(spacing: 14) {
            // Score row — animated counter
            HStack {
                Text(config.mode == .vsBot ? "YOU" : "SCORE")
                    .font(.custom(GK.pixelFontName, size: 10))
                    .foregroundColor(GK.Colors.panelBorder)
                Spacer()
                Text("\(displayedScore)")
                    .font(.custom(GK.pixelFontName, size: 18))
                    .foregroundColor(GK.Colors.panelBorder)
                    .contentTransition(.numericText())
            }

            // Bot score (VS mode only)
            if config.mode == .vsBot {
                Divider()
                HStack {
                    HStack(spacing: 6) {
                        pixelIcon(.bot, size: 14)
                        Text(config.opponentName ?? "BOT")
                            .font(.custom(GK.pixelFontName, size: 10))
                            .foregroundColor(GK.Colors.panelBorder)
                    }
                    Spacer()
                    Text("\(botFinalScore)")
                        .font(.custom(GK.pixelFontName, size: 18))
                        .foregroundColor(Color(red: 0.85, green: 0.30, blue: 0.30))
                }
            }

            Divider()

            // Best score + medal
            HStack {
                Text("BEST")
                    .font(.custom(GK.pixelFontName, size: 10))
                    .foregroundColor(GK.Colors.panelBorder)
                Spacer()

                // Medal badge
                if showMedal && medal != .none {
                    medalBadge
                        .transition(.scale.combined(with: .opacity))
                }

                Text("\(manager.stats.bestScore)")
                    .font(.custom(GK.pixelFontName, size: 18))
                    .foregroundColor(GK.Colors.scoreYellow)
            }

            // NEW BEST! banner
            if showNewBest {
                HStack(spacing: 6) {
                    Text("★")
                        .font(.custom(GK.pixelFontName, size: 10))
                        .foregroundColor(GK.Colors.scoreYellow)
                    Text("NEW BEST!")
                        .font(.custom(GK.pixelFontName, size: 12))
                        .foregroundColor(GK.Colors.scoreYellow)
                    Text("★")
                        .font(.custom(GK.pixelFontName, size: 10))
                        .foregroundColor(GK.Colors.scoreYellow)
                }
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.15))
                )
                .transition(.scale.combined(with: .opacity))
            }

            // Bread earned
            if showBread {
                Divider()
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
                .transition(.move(edge: .bottom).combined(with: .opacity))
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
    }

    // MARK: - Medal Badge

    private var medalBadge: some View {
        let m = medal
        return Text(m.emoji)
            .font(.system(size: 18))
            .padding(.trailing, 4)
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
        let medalText = medal != .none ? " \(medal.emoji) \(medal.displayName) medal!" : ""
        let text = "I scored \(score) in Floppy Duck!\(medalText) 🦆 Can you beat that?"
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
