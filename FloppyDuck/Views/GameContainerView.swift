import SwiftUI
import SpriteKit
import StoreKit

struct GameContainerView: View {
    let config: GameModeConfig
    @EnvironmentObject var manager: GameManager

    @State private var scene: GameScene?
    @State private var bridge: GameSceneBridge?
    @State private var phase: GamePhase = .ready
    @State private var score: Int = 0
    @State private var botFinalScore: Int = 0
    @State private var showBotLadderCelebration: Bool = false
    @State private var celebrationPulse: Bool = false
    @State private var countdownValue: Int = 3

    // Match sync states (head-to-head)
    @State private var matchResult: MultiplayerMatchResult?
    @State private var finishingMatch: Bool = false
    @State private var opponentPollTask: Task<Void, Never>?

    // Game-over animation states
    @State private var displayedScore: Int = 0
    @State private var previousBest: Int = 0
    @State private var countingDone: Bool = false
    @State private var showMedal: Bool = false
    @State private var showNewBest: Bool = false
    @State private var showBread: Bool = false
    @State private var countUpTimer: Timer?

    private let icons = PixelIconFactory.shared

    private var isBotLadder: Bool { config.botCharacterId != nil }
    private var isHeadToHead: Bool { config.mode == .headToHead }
    private var showsVersusScore: Bool { config.mode == .vsBot || config.mode == .headToHead }

    private var ladderWon: Bool {
        guard let target = config.targetScore else { return score > botFinalScore }
        return score >= target
    }

    private var isNewBest: Bool { score > previousBest && score > 0 }
    private var medal: Medal { Medal.from(score: score) }

    private var opponentName: String {
        matchResult?.opponentName ?? config.opponentName ?? (isHeadToHead ? "OPPONENT" : "BOT")
    }

    private var headToHeadDidWin: Bool {
        matchResult?.didWin ?? (score > botFinalScore)
    }

    private var headToHeadDidDraw: Bool {
        matchResult?.didDraw ?? (score == botFinalScore)
    }

    private var breadEarned: Int {
        if config.mode == .headToHead {
            if headToHeadDidDraw { return max(1, score) }
            return headToHeadDidWin ? max(3, score) : max(1, score / 2)
        }

        if config.mode == .vsBot {
            let won = isBotLadder ? ladderWon : score > botFinalScore
            return won ? max(3, score) : max(1, score / 2)
        }

        return max(1, score)
    }

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
        .onDisappear {
            countUpTimer?.invalidate()
            opponentPollTask?.cancel()
        }
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
            opponentName: config.opponentName,
            targetScore: config.targetScore
        )

        let newBridge = GameSceneBridge(
            onStart: {
                phase = .playing
                SoundManager.shared.startPlayMusic()
            },
            onScore: { newScore in
                score = newScore

                if isHeadToHead, let matchId = config.matchId {
                    Task {
                        await manager.reportHeadToHeadScore(matchId: matchId, score: newScore)
                    }
                }
            },
            onEnd: { finalScore in
                handleGameEnd(finalScore: finalScore, scene: newScene)
            },
            onBotScore: { bs in
                botFinalScore = bs
            },
            onBotLadderWin: { finalScore in
                handleBotLadderWin(finalScore: finalScore, scene: newScene)
            }
        )

        newScene.gameDelegate = newBridge
        bridge = newBridge
        scene = newScene

        if isHeadToHead,
           let matchId = config.matchId {
            startOpponentPolling(matchId: matchId, scene: newScene)
            newScene.setOpponentScore(0)
        }
    }

    private func handleBotLadderWin(finalScore: Int, scene: GameScene) {
        score = finalScore
        previousBest = manager.stats.bestScore
        botFinalScore = scene.botScore

        manager.recordGame(score: finalScore, won: true)

        if let botId = config.botCharacterId,
           let bot = BotCharacter.find(botId) {
            manager.beatBot(botId)
            SkinManager.shared.unlockBotReward(bot.skin)
        }

        SoundManager.shared.play(.win)
        Haptic.win()

        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
            phase = .gameOver
            showBotLadderCelebration = true
        }
        startGameOverAnimation()
    }

    private func handleGameEnd(finalScore: Int, scene: GameScene) {
        score = finalScore
        previousBest = manager.stats.bestScore
        botFinalScore = scene.botScore

        SoundManager.shared.stopPlayMusic()
        opponentPollTask?.cancel()

        if isHeadToHead {
            finalizeHeadToHeadResult(finalScore: finalScore, scene: scene)
            return
        }

        let won: Bool?
        if config.mode == .vsBot {
            if isBotLadder {
                won = ladderWon
            } else {
                won = finalScore > scene.botScore
            }
        } else {
            won = nil
        }

        manager.recordGame(score: finalScore, won: won)

        if isBotLadder,
           let botId = config.botCharacterId,
           score >= (config.targetScore ?? 0) {
            manager.beatBot(botId)
            if let bot = BotCharacter.find(botId) {
                SkinManager.shared.unlockBotReward(bot.skin)
            }
        }

        // Prompt for review after 5th or 25th game
        if manager.stats.gamesPlayed == 5 || manager.stats.gamesPlayed == 25 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    SKStoreReviewController.requestReview(in: scene)
                }
            }
        }

        if let won {
            if won {
                SoundManager.shared.play(.win)
                Haptic.win()
            } else {
                SoundManager.shared.play(.lose)
                Haptic.lose()
            }
        }

        withAnimation(.easeOut(duration: 0.35)) {
            phase = .gameOver
        }
        startGameOverAnimation()
    }

    private func finalizeHeadToHeadResult(finalScore: Int, scene: GameScene) {
        guard let matchId = config.matchId else {
            // Defensive fallback if metadata is missing.
            let fallbackWin = finalScore > botFinalScore
            let fallbackDraw = finalScore == botFinalScore
            let fallback = MultiplayerMatchResult(
                matchId: UUID().uuidString,
                mode: config.matchmakingMode ?? (config.isRanked ? .ranked : .quickPlay),
                opponentName: opponentName,
                localScore: finalScore,
                opponentScore: botFinalScore,
                didWin: fallbackWin,
                didDraw: fallbackDraw,
                ratingDelta: nil,
                newRating: nil,
                isRanked: config.isRanked
            )
            manager.applyMatchResult(fallback)
            matchResult = fallback

            withAnimation(.easeOut(duration: 0.35)) {
                phase = .gameOver
            }
            startGameOverAnimation()
            return
        }

        let mode = config.matchmakingMode ?? (config.isRanked ? .ranked : .quickPlay)
        finishingMatch = true

        Task {
            let result = await manager.finishHeadToHeadMatch(
                matchId: matchId,
                score: finalScore,
                fallbackOpponentScore: botFinalScore,
                mode: mode,
                opponentName: config.opponentName
            )

            await MainActor.run {
                matchResult = result
                botFinalScore = result.opponentScore
                scene.setOpponentScore(result.opponentScore)
                finishingMatch = false

                if result.didDraw {
                    SoundManager.shared.play(.milestone)
                } else if result.didWin {
                    SoundManager.shared.play(.win)
                    Haptic.win()
                } else {
                    SoundManager.shared.play(.lose)
                    Haptic.lose()
                }

                withAnimation(.easeOut(duration: 0.35)) {
                    phase = .gameOver
                }
                startGameOverAnimation()
            }
        }
    }

    private func startOpponentPolling(matchId: String, scene: GameScene) {
        opponentPollTask?.cancel()
        opponentPollTask = Task {
            while !Task.isCancelled {
                do {
                    let state = try await manager.fetchHeadToHeadState(matchId: matchId)
                    await MainActor.run {
                        botFinalScore = state.opponentScore
                        scene.setOpponentScore(state.opponentScore)
                    }
                } catch {
                    // Polling should be resilient; transient failures are ignored.
                }

                try? await Task.sleep(nanoseconds: 400_000_000)
            }
        }
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

        if medal != .none {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                    showMedal = true
                }
                SoundManager.shared.play(.medal)
            }
        }

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
        matchResult = nil
        finishingMatch = false
    }

    // MARK: - Get Ready Overlay

    private var getReadyOverlay: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                Text("GET READY")
                    .font(.custom(GK.pixelFontName, size: 20))
                    .foregroundColor(GK.Colors.panelBorder)

                if isBotLadder,
                   let botId = config.botCharacterId,
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
                } else if config.mode == .headToHead {
                    HStack(spacing: 8) {
                        pixelIcon(.headToHead, size: 18)
                        Text("VS \(opponentName)")
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
            gameOverTitle

            scorePanel
                .padding(.horizontal, 40)

            if finishingMatch {
                Text("FINALIZING MATCH...")
                    .font(.custom(GK.pixelFontName, size: 8))
                    .foregroundColor(.white.opacity(0.85))
            }

            if countingDone && !finishingMatch {
                HStack(spacing: 16) {
                    if !isHeadToHead {
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
                    }

                    actionButton(icon: .home, label: "HOME", color: GK.Colors.buttonOrange) {
                        SoundManager.shared.play(.button)
                        resetGameOverState()
                        manager.dismissGame()
                    }
                }
                .padding(.horizontal, 40)
                .transition(.opacity.combined(with: .move(edge: .bottom)))

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
                .accessibilityLabel("Share score")
                .transition(.opacity)
            }
        }
    }

    // MARK: - Game Over Title

    @ViewBuilder
    private var gameOverTitle: some View {
        if config.mode == .headToHead {
            if headToHeadDidDraw {
                Text("DRAW")
                    .font(.custom(GK.pixelFontName, size: 22))
                    .foregroundColor(.white)
                    .shadow(color: GK.Colors.pipeBorder, radius: 0, x: 3, y: 3)
            } else if headToHeadDidWin {
                Text("YOU WIN!")
                    .font(.custom(GK.pixelFontName, size: 22))
                    .foregroundColor(GK.Colors.scoreYellow)
                    .shadow(color: GK.Colors.pipeBorder, radius: 0, x: 3, y: 3)
            } else {
                Text("YOU LOSE")
                    .font(.custom(GK.pixelFontName, size: 22))
                    .foregroundColor(.white)
                    .shadow(color: GK.Colors.pipeBorder, radius: 0, x: 3, y: 3)
            }
        } else if config.mode == .vsBot {
            let playerWon = isBotLadder ? ladderWon : score > botFinalScore

            if playerWon && showBotLadderCelebration {
                // Celebration title with golden pulse
                VStack(spacing: 6) {
                    Text("⭐ YOU WIN! ⭐")
                        .font(.custom(GK.pixelFontName, size: 24))
                        .foregroundColor(GK.Colors.scoreYellow)
                        .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.8), radius: 8, x: 0, y: 0)
                        .shadow(color: GK.Colors.pipeBorder, radius: 0, x: 3, y: 3)
                        .scaleEffect(celebrationPulse ? 1.08 : 0.95)
                        .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: celebrationPulse)
                        .onAppear { celebrationPulse = true }

                    Text("BOT DEFEATED!")
                        .font(.custom(GK.pixelFontName, size: 10))
                        .foregroundColor(GK.Colors.scoreYellow.opacity(0.9))
                        .shadow(color: GK.Colors.pipeBorder, radius: 0, x: 2, y: 2)
                }
                .transition(.scale.combined(with: .opacity))
            } else {
                Text(playerWon ? "YOU WIN!" : "TRY AGAIN")
                    .font(.custom(GK.pixelFontName, size: 22))
                    .foregroundColor(playerWon ? GK.Colors.scoreYellow : .white)
                    .shadow(color: GK.Colors.pipeBorder, radius: 0, x: 3, y: 3)
            }

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
            HStack {
                Text(showsVersusScore ? "YOU" : "SCORE")
                    .font(.custom(GK.pixelFontName, size: 10))
                    .foregroundColor(GK.Colors.panelBorder)
                Spacer()

                if showMedal && medal != .none {
                    medalBadge
                        .transition(.scale.combined(with: .opacity))
                }

                Text("\(displayedScore)")
                    .font(.custom(GK.pixelFontName, size: 18))
                    .foregroundColor(GK.Colors.panelBorder)
                    .contentTransition(.numericText())
            }

            if showsVersusScore {
                Divider()
                HStack {
                    HStack(spacing: 6) {
                        pixelIcon(isHeadToHead ? .headToHead : .bot, size: 14)
                        Text(opponentName)
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

            HStack {
                Text("BEST")
                    .font(.custom(GK.pixelFontName, size: 10))
                    .foregroundColor(GK.Colors.panelBorder)
                Spacer()
                Text("\(manager.stats.bestScore)")
                    .font(.custom(GK.pixelFontName, size: 18))
                    .foregroundColor(GK.Colors.scoreYellow)
            }

            if showNewBest {
                HStack(spacing: 6) {
                    Text("★")
                        .font(.custom(GK.pixelFontName, size: 10))
                        .foregroundColor(GK.Colors.scoreYellow)
                    Text("NEW BEST!")
                        .font(.custom(GK.pixelFontName, size: 12))
                        .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0))
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
                .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.5), radius: 8, x: 0, y: 0)
                .scaleEffect(celebrationPulse ? 1.05 : 0.95)
                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: celebrationPulse)
                .onAppear { celebrationPulse = true }
                .transition(.scale.combined(with: .opacity))
            }

            if showBread {
                Divider()
                HStack {
                    Image(uiImage: TextureFactory.shared.breadUIImage(pixelScale: 3.0))
                        .interpolation(.none)
                        .resizable()
                        .frame(width: 20, height: 16)
                    Text("+\(breadEarned)")
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

    private func actionButton(icon: PixelIcon,
                              label: String,
                              color: Color,
                              action: @escaping () -> Void) -> some View {
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
        .accessibilityLabel(label)
    }

    private func pixelIcon(_ icon: PixelIcon, size: CGFloat) -> some View {
        Image(uiImage: icons.image(for: icon))
            .interpolation(.none)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
    }

    private func shareScore() {
        // Item 7: Generate pixel-art share card image
        let shareCard = ShareCardView(
            score: score,
            medal: medal,
            bestScore: manager.stats.bestScore,
            mode: config.mode
        )
        let cardImage = shareCard.renderToImage()

        // Item 14: App Store link placeholder
        let appStoreURL = URL(string: "https://apps.apple.com/app/floppy-duck/id000000000")!

        let medalText = medal != .none ? " \(medal.emoji) \(medal.displayName) medal!" : ""
        let modeText = isHeadToHead ? " in Head to Head" : ""
        let text = "I scored \(score)\(modeText) in Floppy Duck!\(medalText) 🦆 Can you beat that?"

        let vc = UIActivityViewController(activityItems: [cardImage, text, appStoreURL], applicationActivities: nil)
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
    let onBotLadderWin: (Int) -> Void

    init(onStart: @escaping () -> Void,
         onScore: @escaping (Int) -> Void,
         onEnd: @escaping (Int) -> Void,
         onBotScore: @escaping (Int) -> Void = { _ in },
         onBotLadderWin: @escaping (Int) -> Void = { _ in }) {
        self.onStart = onStart
        self.onScore = onScore
        self.onEnd = onEnd
        self.onBotScore = onBotScore
        self.onBotLadderWin = onBotLadderWin
    }

    func gameDidStart() { onStart() }
    func gameDidScore(_ score: Int) { onScore(score) }
    func gameDidEnd(score: Int) { onEnd(score) }
    func botDidScore(_ botScore: Int) { onBotScore(botScore) }
    func gameDidWinBotLadder(score: Int) { onBotLadderWin(score) }
}
