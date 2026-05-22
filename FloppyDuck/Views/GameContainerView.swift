import SwiftUI
import SpriteKit
import StoreKit
import GameKit
import UIKit

struct GameContainerView: View {
    let config: GameModeConfig
    @EnvironmentObject var manager: GameManager

    @State private var scene: GameScene?
    @State private var bridge: GameSceneBridge?
    @State private var phase: GamePhase = .ready  // overridden to .versusIntro for VS modes
    @State private var score: Int = 0
    @State private var botFinalScore: Int = 0
    @State private var showBotLadderCelebration: Bool = false
    @State private var celebrationPulse: Bool = false
    @State private var countdownValue: Int = 3
    @State private var countdownScale: CGFloat = 0.001
    @State private var countdownFlashOpacity: Double = 0
    @State private var countdownLabel: String = "3"
    @State private var showCountdownOverlay: Bool = false
    @State private var countdownOverlayOpacity: Double = 1.0

    // Match sync states (head-to-head)
    @State private var matchResult: MultiplayerMatchResult?
    @State private var finishingMatch: Bool = false
    @State private var opponentPollTask: Task<Void, Never>?
    @State private var lastReportedScore: Int = -1
    @State private var lastReportTime: Date = .distantPast
    @State private var battleRoyaleState: BattleRoyaleState?
    @State private var battleRoyalePollTask: Task<Void, Never>?
    @State private var battleRoyaleReportTask: Task<Void, Never>?
    @State private var battleRoyaleResultApplied: Bool = false

    // Game-over animation states
    @State private var displayedScore: Int = 0
    @State private var previousBest: Int = 0
    @State private var countingDone: Bool = false
    @State private var showMedal: Bool = false
    @State private var showNewBest: Bool = false
    @State private var showBread: Bool = false
    @State private var countUpTimer: Timer?
    @State private var sharePayload: SharePayload?
    @State private var headToHeadIntroFinished: Bool = false
    @State private var headToHeadReadySent: Bool = false
    @State private var headToHeadBothReady: Bool = false
    @State private var headToHeadCountdownScheduled: Bool = false
    @State private var headToHeadAbandoned: Bool = false
    @State private var headToHeadGateMessage: String = "MATCHING..."
    @State private var headToHeadFailureMessage: String?
    @State private var headToHeadStartTask: Task<Void, Never>?
    @State private var headToHeadReadyPollTask: Task<Void, Never>?

    private var isBotLadder: Bool { config.botCharacterId != nil }
    private var isHeadToHead: Bool { config.mode == .headToHead }
    private var isBattleRoyale: Bool { config.mode == .battleRoyale }
    private var showsVersusScore: Bool { config.mode == .vsBot || config.mode == .headToHead }
    private var headToHeadOutcomeReady: Bool { !isHeadToHead || (matchResult?.isFinalized ?? false) }
    private var headToHeadPending: Bool { isHeadToHead && !headToHeadOutcomeReady }
    private var battleRoyalePlacement: Int? { battleRoyaleState?.local.placement }
    private var battleRoyalePrize: Int { battleRoyaleState?.local.prize ?? 0 }
    private var battleRoyalePending: Bool { isBattleRoyale && battleRoyalePlacement == nil }
    private let headToHeadStartDelay: TimeInterval = 0.6
    private var collectedBreadEarned: Int { scene?.totalBreadCollected ?? 0 }

    private var ladderWon: Bool {
        // The player wins a bot-ladder match only when the bot died FIRST
        // (while the player was still alive).  showBotLadderCelebration is
        // set exclusively in handleBotLadderWin, which only fires via the
        // celebrateBotLadderWin → gameDidWinBotLadder path — i.e. when the
        // bot's physics contact triggered its death before the player died.
        //
        // Checking botFinalScore >= target alone is wrong because the bot
        // may have reached its ceiling (became doomed / stopped flapping)
        // before the player died — that's still a player loss.
        return showBotLadderCelebration
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
        if isBattleRoyale {
            return battleRoyalePrize + collectedBreadEarned
        }

        if config.mode == .headToHead {
            if headToHeadDidDraw {
                return BreadEconomy.gameReward(score: score, won: nil, collectedBread: collectedBreadEarned)
            }
            return BreadEconomy.gameReward(score: score, won: headToHeadDidWin, collectedBread: collectedBreadEarned)
        }

        if config.mode == .vsBot {
            let won = isBotLadder ? ladderWon : score > botFinalScore
            return BreadEconomy.gameReward(score: score, won: won, collectedBread: collectedBreadEarned)
        }

        return BreadEconomy.gameReward(score: score, won: nil, collectedBread: collectedBreadEarned)
    }

    var body: some View {
        ZStack {
            if let scene {
                SpriteView(scene: scene,
                           preferredFramesPerSecond: 60,
                           options: [.ignoresSiblingOrder, .shouldCullNonVisibleNodes])
                    .ignoresSafeArea()
            }

            switch phase {
            case .versusIntro:
                versusIntroOverlay
                    .transition(.opacity)
            case .ready:
                getReadyOverlay
            case .countdown:
                EmptyView()
            case .gameOver:
                Color.black.opacity(0.65)
                    .ignoresSafeArea()
                    .transition(.opacity)

                gameOverOverlay
                    .transition(.scale.combined(with: .opacity))
            default:
                EmptyView()
            }

            if showCountdownOverlay {
                countdownOverlay
                    .opacity(countdownOverlayOpacity)
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            // VS modes get the Mortal-Kombat-style intro first
            if config.mode == .vsBot || config.mode == .headToHead {
                phase = .versusIntro
            }
            setupScene()
            if config.mode == .classic {
                scene?.isReadyToStart = true
            }
            if config.mode == .battleRoyale {
                scene?.isReadyToStart = true
            }
        }
        .onDisappear {
            countUpTimer?.invalidate()
            opponentPollTask?.cancel()
            battleRoyalePollTask?.cancel()
            battleRoyaleReportTask?.cancel()
            headToHeadStartTask?.cancel()
            headToHeadReadyPollTask?.cancel()
        }
        .sheet(item: $sharePayload) { payload in
            ActivityView(activityItems: payload.activityItems)
        }
        .statusBarHidden(true)
    }

    // MARK: - Scene Setup

    private func setupScene() {
        if isHeadToHead {
            print("[HeadToHead] setupScene matchId:\(config.matchId ?? "nil") mode:\(config.matchmakingMode?.rawValue ?? "nil") seed:\(config.seed) host:\(config.isGameKitHost)")
            recordHeadToHeadDiagnostic(
                event: "setup_scene",
                message: "Head-to-head scene setup started."
            )
        }

        let skin = SkinManager.shared.selectedSkin
        let newScene = GameScene(
            seed: config.seed,
            mode: config.mode,
            powerUpsEnabled: config.powerUpsEnabled,
            skin: skin,
            botSkin: config.botSkin,
            botDifficulty: config.botDifficulty,
            backgroundTheme: config.backgroundTheme,
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
                    // Debounce: only report if score changed AND at least 0.5s since last report.
                    let now = Date()
                    if newScore != lastReportedScore && now.timeIntervalSince(lastReportTime) >= 0.5 {
                        lastReportedScore = newScore
                        lastReportTime = now
                        Task {
                            await manager.reportHeadToHeadScore(matchId: matchId, score: newScore)
                        }
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
            },
            onQuickRetry: { finalScore in
                // Record the game silently — no overlay, no animation.
                // The scene already called resetGame() so we just need to
                // book-keep stats and reset container state.
                let gameBread = newScene.totalBreadCollected
                manager.recordGame(score: finalScore, won: nil, collectedBread: gameBread)
                resetGameOverState()
                score = 0
                botFinalScore = 0
                withAnimation(.easeOut(duration: 0.15)) {
                    phase = .ready
                }
            }
        )

        newScene.gameDelegate = newBridge
        bridge = newBridge
        scene = newScene

        if isHeadToHead {
            // Start ready-state polling via Convex
            startHeadToHeadReadyPolling()

            // Start opponent score/state polling via Convex
            if let matchId = config.matchId {
                startOpponentPolling(matchId: matchId, scene: newScene)
            }
        }

        if isBattleRoyale,
           let lobbyId = config.battleRoyaleLobbyId {
            startBattleRoyalePolling(lobbyId: lobbyId, scene: newScene)
            startBattleRoyaleReporting(lobbyId: lobbyId, scene: newScene)
        }
    }

    private func sendHeadToHeadReadyIfPossible() {
        guard isHeadToHead,
              headToHeadIntroFinished,
              !headToHeadReadySent,
              headToHeadFailureMessage == nil,
              let matchId = config.matchId else {
            print("[HeadToHead] ready check deferred — intro:\(headToHeadIntroFinished) sent:\(headToHeadReadySent) failed:\(headToHeadFailureMessage ?? "nil") matchId:\(config.matchId ?? "nil")")
            return
        }

        headToHeadReadySent = true
        headToHeadGateMessage = "READY"
        print("[HeadToHead] sending local ready via Convex markReady(matchId:\(matchId))")
        recordHeadToHeadDiagnostic(event: "ready_sent", message: "Local ready sent via Convex.")

        Task {
            do {
                try await ConvexClient.shared.markReady(matchId: matchId)
                print("[HeadToHead] markReady succeeded")
            } catch {
                print("[HeadToHead] markReady FAILED: \(error.localizedDescription)")
                recordHeadToHeadDiagnostic(
                    event: "ready_failed",
                    level: "error",
                    message: error.localizedDescription
                )
            }
        }
    }

    private func startHeadToHeadReadyPolling() {
        guard isHeadToHead, let matchId = config.matchId else {
            print("[HeadToHead] ready polling skipped — isH2H:\(isHeadToHead) matchId:\(config.matchId ?? "nil")")
            return
        }

        print("[HeadToHead] starting ready-state polling for match \(matchId)")
        headToHeadReadyPollTask?.cancel()

        let pollingStart = Date()
        let timeoutSeconds: TimeInterval = 30

        headToHeadReadyPollTask = Task {
            var pollCount = 0
            while !Task.isCancelled {
                pollCount += 1
                do {
                    let state = try await ConvexClient.shared.getReadyState(matchId: matchId)

                    if pollCount <= 3 || pollCount % 10 == 0 {
                        print("[HeadToHead] poll #\(pollCount) — p1Ready:\(state.p1Ready ?? -1) p2Ready:\(state.p2Ready ?? -1) startAtMs:\(state.startAtMs ?? -1) status:\(state.status)")
                    }

                    await MainActor.run {
                        if !headToHeadBothReady && state.p1Ready != nil && state.p2Ready != nil {
                            headToHeadBothReady = true
                            headToHeadGateMessage = "OPPONENT READY"
                            print("[HeadToHead] both players ready!")
                            recordHeadToHeadDiagnostic(event: "both_ready", message: "Both players ready.")

                            if config.isGameKitHost {
                                scheduleHostStartIfReady()
                            }
                        }

                        if let startMs = state.startAtMs, !headToHeadCountdownScheduled {
                            let delay = max(0, (startMs - Date().timeIntervalSince1970 * 1000) / 1000)
                            print("[HeadToHead] startAtMs received: \(startMs), delay: \(delay)s")
                            scheduleHeadToHeadCountdown(after: delay)
                        }
                    }
                } catch is CancellationError {
                    return
                } catch {
                    print("[HeadToHead] ready poll #\(pollCount) error: \(error.localizedDescription)")
                    recordHeadToHeadDiagnostic(
                        event: "ready_poll_error",
                        level: "warning",
                        message: error.localizedDescription
                    )
                }

                // Timeout fallback: if we've been polling >30s with no progress, auto-start
                if !headToHeadCountdownScheduled && Date().timeIntervalSince(pollingStart) > timeoutSeconds {
                    print("[HeadToHead] ready poll timeout (\(timeoutSeconds)s) — force-starting game")
                    await MainActor.run {
                        scheduleHeadToHeadCountdown(after: 0.6)
                    }
                    return
                }

                try? await Task.sleep(nanoseconds: 200_000_000) // 5 Hz
            }
        }
    }

    private func scheduleHostStartIfReady() {
        guard isHeadToHead,
              config.isGameKitHost,
              headToHeadBothReady,
              !headToHeadCountdownScheduled,
              headToHeadFailureMessage == nil,
              let matchId = config.matchId else {
            print("[HeadToHead] host start deferred — host:\(config.isGameKitHost) bothReady:\(headToHeadBothReady) scheduled:\(headToHeadCountdownScheduled) failed:\(headToHeadFailureMessage ?? "nil")")
            return
        }

        let now = Date().timeIntervalSince1970 * 1000
        let startAtMs = now + headToHeadStartDelay * 1000

        print("[HeadToHead] host scheduling startAtMs:\(startAtMs) delay:\(headToHeadStartDelay)s")
        recordHeadToHeadDiagnostic(
            event: "start_scheduled",
            message: "Host scheduled start.",
            metadata: ["startAtMs": String(format: "%.0f", startAtMs), "delay": String(format: "%.3f", headToHeadStartDelay)]
        )

        Task {
            do {
                try await ConvexClient.shared.scheduleStart(matchId: matchId, startAtMs: startAtMs)
                print("[HeadToHead] scheduleStart succeeded")
            } catch {
                print("[HeadToHead] scheduleStart FAILED: \(error.localizedDescription)")
                recordHeadToHeadDiagnostic(
                    event: "schedule_start_failed",
                    level: "error",
                    message: error.localizedDescription
                )
            }
        }

        scheduleHeadToHeadCountdown(after: headToHeadStartDelay)
    }

    private func scheduleHeadToHeadCountdown(after delay: TimeInterval) {
        guard isHeadToHead,
              !headToHeadCountdownScheduled,
              headToHeadFailureMessage == nil else { return }

        headToHeadCountdownScheduled = true
        headToHeadGateMessage = "MATCH STARTING"
        headToHeadReadyPollTask?.cancel()
        print("[HeadToHead] scheduling map countdown after \(delay)s")
        recordHeadToHeadDiagnostic(
            event: "countdown_scheduled",
            message: "Map countdown scheduled.",
            metadata: ["delay": String(format: "%.3f", delay)]
        )
        headToHeadStartTask?.cancel()
        headToHeadStartTask = Task {
            let nanoseconds = UInt64(max(delay, 0) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard phase != .gameOver else { return }
                withAnimation(.easeOut(duration: 0.15)) {
                    phase = .countdown
                }
                runMapCountdown()
            }
        }
    }

    private func handleHeadToHeadPreStartFailure(message: String) {
        guard isHeadToHead, !headToHeadCountdownScheduled else { return }
        headToHeadStartTask?.cancel()
        headToHeadReadyPollTask?.cancel()
        headToHeadFailureMessage = message
        headToHeadGateMessage = message

        recordHeadToHeadDiagnostic(
            event: "pre_start_failed",
            level: "error",
            message: message
        )

        guard !headToHeadAbandoned, let matchId = config.matchId else { return }
        headToHeadAbandoned = true
        Task {
            recordHeadToHeadDiagnostic(
                event: "abandon_match_requested",
                level: "warning",
                message: "Abandoning Convex match after pre-start failure."
            )
            await manager.abandonHeadToHeadMatch(matchId: matchId)
        }
    }

    private func retryHeadToHeadAfterP2PFailure() {
        let mode = config.matchmakingMode ?? (config.isRanked ? .ranked : .quickPlay)
        print("[HeadToHead] retry requested — mode:\(mode.rawValue)")
        recordHeadToHeadDiagnostic(
            event: "retry_requested",
            message: "User requested retry.",
            mode: mode.rawValue
        )
        headToHeadStartTask?.cancel()
        headToHeadReadyPollTask?.cancel()
        manager.dismissGame()

        if !manager.path.isEmpty {
            manager.path.removeLast()
        }
        _ = manager.startMatchmaking(mode: mode)
    }

    private func headToHeadFailureMessage(for error: Error?) -> String {
        guard let error else { return "CONNECTION FAILED" }
        return error.localizedDescription.uppercased()
    }

    private func recordHeadToHeadDiagnostic(event: String,
                                            level: String = "info",
                                            message: String? = nil,
                                            mode: String? = nil,
                                            metadata: [String: String] = [:]) {
        MultiplayerDiagnostics.record(
            category: "head_to_head",
            event: event,
            level: level,
            message: message,
            matchId: config.matchId,
            sessionCode: config.gameKitSessionCode,
            mode: mode ?? config.matchmakingMode?.rawValue,
            metadata: headToHeadDiagnosticMetadata(extra: metadata)
        )
    }

    private func headToHeadDiagnosticMetadata(extra: [String: String] = [:]) -> [String: String] {
        var metadata: [String: String] = [
            "seed": String(config.seed),
            "isGameKitHost": String(config.isGameKitHost),
            "phase": String(describing: phase),
            "introFinished": String(headToHeadIntroFinished),
            "readySent": String(headToHeadReadySent),
            "bothReady": String(headToHeadBothReady),
            "countdownScheduled": String(headToHeadCountdownScheduled),
            "abandoned": String(headToHeadAbandoned),
            "failureMessage": headToHeadFailureMessage ?? "nil",
            "gateMessage": headToHeadGateMessage,
        ]
        extra.forEach { metadata[$0.key] = $0.value }
        return metadata
    }

    private func headToHeadStateSummary() -> String {
        "phase:\(phase) intro:\(headToHeadIntroFinished) readySent:\(headToHeadReadySent) bothReady:\(headToHeadBothReady) countdown:\(headToHeadCountdownScheduled) failed:\(headToHeadFailureMessage ?? "nil") abandoned:\(headToHeadAbandoned)"
    }

    private func handleBotLadderWin(finalScore: Int, scene: GameScene) {
        score = finalScore
        previousBest = manager.stats.bestScore
        botFinalScore = scene.botScore

        // Mark bot as beaten IMMEDIATELY — before recording or animation
        if let botId = config.botCharacterId,
           let bot = BotCharacter.find(botId) {
            manager.beatBot(botId)
            SkinManager.shared.unlockBotReward(bot.skin)
        }

        let gameBread = scene.totalBreadCollected

        manager.recordGame(score: finalScore, won: true, collectedBread: gameBread)

        // Fire achievement events
        processAchievements(score: finalScore, scene: scene)

        // NOTE: Win sound + haptic already fired in GameScene's
        // celebrateBotLadderWin() when the bot died.  Don't play them
        // again here — that caused a double-play 1.5 s apart.

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

        if isHeadToHead {
            finalizeHeadToHeadResult(finalScore: finalScore, scene: scene)
            return
        }

        if isBattleRoyale {
            finalizeBattleRoyaleResult(finalScore: finalScore, scene: scene)
            return
        }

        // NOTE: In bot-ladder mode, handleGameEnd only fires when the PLAYER
        // dies.  If the bot died first the scene routes through
        // handleBotLadderWin instead.  So we never award a bot-ladder win
        // here — the player died, that's a loss.
        //
        // (Previously this checked `ladderWon` which only looked at the
        // bot's score, not whether the player was still alive — causing
        // false "YOU WIN" results when the bot had reached its ceiling
        // score before the player died.)

        let won: Bool?
        if config.mode == .vsBot {
            if isBotLadder {
                won = false  // Player died → always a loss
            } else {
                won = finalScore > scene.botScore
            }
        } else {
            won = nil
        }

        let gameBread = scene.totalBreadCollected

        manager.recordGame(score: finalScore, won: won, collectedBread: gameBread)

        // --- Fire achievement events ---
        processAchievements(score: finalScore, scene: scene)

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
            matchResult = MultiplayerMatchResult(
                matchId: UUID().uuidString,
                mode: config.matchmakingMode ?? (config.isRanked ? .ranked : .quickPlay),
                opponentName: opponentName,
                localScore: finalScore,
                opponentScore: botFinalScore,
                didWin: finalScore > botFinalScore,
                didDraw: finalScore == botFinalScore,
                ratingDelta: nil,
                newRating: nil,
                isRanked: config.isRanked,
                isFinalized: false
            )

            withAnimation(.easeOut(duration: 0.35)) {
                phase = .gameOver
            }
            startGameOverAnimation()
            return
        }

        let mode = config.matchmakingMode ?? (config.isRanked ? .ranked : .quickPlay)
        finishingMatch = true
        matchResult = nil

        withAnimation(.easeOut(duration: 0.35)) {
            phase = .gameOver
        }
        startGameOverAnimation()

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

                if result.isFinalized {
                    if result.didDraw {
                        SoundManager.shared.play(.milestone)
                    } else if result.didWin {
                        SoundManager.shared.play(.win)
                        Haptic.win()
                    } else {
                        SoundManager.shared.play(.lose)
                        Haptic.lose()
                    }

                    let am = AchievementManager.shared
                    let skinsOwned = SkinManager.shared.ownedSkins.count
                    let stats = manager.stats

                    if result.didDraw {
                        am.process(event: .matchDraw, stats: stats, skinsOwned: skinsOwned, manager: manager)
                    }

                    if result.didWin {
                        am.process(event: .h2hWin(total: stats.wins), stats: stats, skinsOwned: skinsOwned, manager: manager)
                    }

                    if mode == .privateRoom {
                        am.process(event: .privateRoomMatch, stats: stats, skinsOwned: skinsOwned, manager: manager)
                    } else if mode == .ranked {
                        am.process(event: .rankedMatch, stats: stats, skinsOwned: skinsOwned, manager: manager)
                        am.process(event: .ratingUpdated(elo: stats.elo, peakElo: stats.peakElo), stats: stats, skinsOwned: skinsOwned, manager: manager)
                    }

                    am.process(event: .matchWinStreak(streak: stats.winStreak), stats: stats, skinsOwned: skinsOwned, manager: manager)
                    am.save()
                }
            }
        }
    }

    private func startOpponentPolling(matchId: String, scene: GameScene) {
        opponentPollTask?.cancel()
        opponentPollTask = Task {
            var consecutiveErrors = 0
            var pollCount = 0
            while !Task.isCancelled {
                do {
                    let state = try await manager.fetchHeadToHeadState(matchId: matchId)
                    await MainActor.run {
                        botFinalScore = state.opponentScore
                        scene.setOpponentScore(state.opponentScore)
                    }
#if DEBUG
                    pollCount += 1
                    if pollCount % 5 == 0,
                       ProcessInfo.processInfo.arguments.contains("-DebugFrameLog")
                        || ProcessInfo.processInfo.environment["DEBUG_FRAME_LOG"] == "1" {
                        print("[Multiplayer] 🔄 Poll #\(pollCount) — oppScore:\(state.opponentScore) you:\(state.localScore) finished:\(state.isFinished)")
                    }
#endif
                    consecutiveErrors = 0  // Reset backoff on success
                } catch is CancellationError {
                    return
                } catch {
                    consecutiveErrors += 1
                    // Polling should be resilient; transient failures are ignored.
                }

                // Exponential backoff: 400ms → 800ms → 1600ms, capped at 3.2s
                let baseInterval: UInt64 = 400_000_000
                let backoffFactor = min(UInt64(1) << min(consecutiveErrors, 3), 8)
                try? await Task.sleep(nanoseconds: baseInterval * backoffFactor)
            }
        }
    }

    private func finalizeBattleRoyaleResult(finalScore: Int, scene: GameScene) {
        guard let lobbyId = config.battleRoyaleLobbyId else {
            withAnimation(.easeOut(duration: 0.35)) {
                phase = .gameOver
            }
            startGameOverAnimation()
            return
        }

        finishingMatch = true
        battleRoyalePollTask?.cancel()
        battleRoyaleReportTask?.cancel()

        withAnimation(.easeOut(duration: 0.35)) {
            phase = .gameOver
        }
        startGameOverAnimation()

        Task {
            let latest = await manager.finishBattleRoyaleRun(lobbyId: lobbyId, score: finalScore)
            await MainActor.run {
                if let latest {
                    battleRoyaleState = latest
                    scene.updateBattleRoyaleGhosts(latest.ghosts)
                    if !battleRoyaleResultApplied {
                        battleRoyaleResultApplied = true
                        manager.applyBattleRoyaleResult(latest, score: finalScore, collectedBread: scene.totalBreadCollected)
                    }
                }
                finishingMatch = false

                if battleRoyalePlacement == 1 {
                    SoundManager.shared.play(.win)
                    Haptic.win()
                } else {
                    SoundManager.shared.play(.lose)
                    Haptic.lose()
                }
            }
        }
    }

    private func startBattleRoyalePolling(lobbyId: String, scene: GameScene) {
        battleRoyalePollTask?.cancel()
        battleRoyalePollTask = Task {
            while !Task.isCancelled {
                do {
                    let latest = try await manager.fetchBattleRoyaleState(lobbyId: lobbyId)
                    await MainActor.run {
                        battleRoyaleState = latest
                        scene.updateBattleRoyaleGhosts(latest.ghosts)
                    }
                } catch is CancellationError {
                    return
                } catch {
                    // Transient polling failures should not interrupt a run.
                }

                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
    }

    private func startBattleRoyaleReporting(lobbyId: String, scene: GameScene) {
        battleRoyaleReportTask?.cancel()
        battleRoyaleReportTask = Task {
            while !Task.isCancelled {
                if phase == .playing,
                   let snapshot = scene.battleRoyaleSnapshot() {
                    await manager.reportBattleRoyaleState(
                        lobbyId: lobbyId,
                        score: score,
                        y: Double(snapshot.y),
                        rotation: Double(snapshot.rotation),
                        wingPhase: snapshot.wingPhase
                    )
                }

                try? await Task.sleep(nanoseconds: 250_000_000)
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

        // Use Task-based delays to ensure withAnimation() fires reliably
        // inside the SwiftUI run-loop (DispatchQueue.main.asyncAfter can
        // miss SwiftUI transaction boundaries, causing transitions to
        // appear without animation — especially the medal badge).
        Task { @MainActor in
            if medal != .none {
                try? await Task.sleep(nanoseconds: 250_000_000)  // 0.25s
                withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                    showMedal = true
                }
                SoundManager.shared.play(.medal)
            }

            if isNewBest {
                let delay: UInt64 = medal != .none ? 450_000_000 : 300_000_000
                try? await Task.sleep(nanoseconds: delay)
                withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) {
                    showNewBest = true
                }
                SoundManager.shared.play(.newBest)
                Haptic.newBest()
            }

            let breadDelay: UInt64 = isNewBest ? 400_000_000 : (medal != .none ? 350_000_000 : 300_000_000)
            try? await Task.sleep(nanoseconds: breadDelay)
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
        showBotLadderCelebration = false
        celebrationPulse = false
        matchResult = nil
        finishingMatch = false
        battleRoyaleState = nil
        battleRoyaleResultApplied = false
    }

    // MARK: - Get Ready Overlay

    // MARK: - VS Intro (Mortal Kombat style)

    @ViewBuilder
    private var versusIntroOverlay: some View {
        let playerSkin = SkinManager.shared.selectedSkin
        let playerBanner = BannerManager.shared.selectedBanner
        let bot = config.botCharacterId.flatMap { BotCharacter.find($0) }

        VersusIntroView(
            playerSkin: playerSkin,
            playerName: (manager.playerName.isEmpty || manager.playerName == "Player") ? "YOU" : manager.playerName.uppercased(),
            playerBanner: playerBanner,
            opponentSkin: resolvedOpponentSkin,
            opponentName: config.opponentName ?? "OPPONENT",
            opponentAccent: bot?.accentColor ?? Color.red
        ) {
            // VS intro done → run 3-2-1-GO countdown on the game map
            if isHeadToHead {
                headToHeadIntroFinished = true
                withAnimation(.easeOut(duration: 0.15)) {
                    phase = .ready
                }
                sendHeadToHeadReadyIfPossible()
            } else {
                withAnimation(.easeOut(duration: 0.15)) {
                    phase = .countdown
                }
                runMapCountdown()
            }
        }
    }

    private var resolvedOpponentSkin: DuckSkin? {
        if let botId = config.botCharacterId, let bot = BotCharacter.find(botId) {
            return bot.skin
        }
        if let skinId = config.opponentSkinId, let skin = DuckSkin(rawValue: skinId) {
            return skin
        }
        return nil
    }

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
                        Image(uiImage: TextureFactory.shared.skinDuckUIImage(skin: bot.skin, pixelScale: 4.0))
                            .interpolation(.none)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 22, height: 22)
                        Text("VS \(bot.name)")
                            .font(.custom(GK.pixelFontName, size: 10))
                            .foregroundColor(GK.Colors.panelBorder.opacity(0.7))
                    }
                    Text("Outlast \(bot.name) to win!")
                        .font(.custom(GK.pixelFontName, size: 7))
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
                } else if config.mode == .battleRoyale {
                    HStack(spacing: 8) {
                        pixelIcon(.trophy, size: 18)
                        Text("BATTLE ROYALE")
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

                if config.mode == .headToHead && !headToHeadCountdownScheduled {
                    Text(headToHeadFailureMessage ?? headToHeadGateMessage)
                        .font(.custom(GK.pixelFontName, size: 8))
                        .foregroundColor(headToHeadFailureMessage == nil ? GK.Colors.panelBorder.opacity(0.6) : GK.Colors.buttonRed)
                        .multilineTextAlignment(.center)
                        .padding(.top, 6)

                    if headToHeadFailureMessage != nil {
                        Button {
                            retryHeadToHeadAfterP2PFailure()
                        } label: {
                            HStack(spacing: 6) {
                                pixelIcon(.retry, size: 13)
                                Text("RETRY")
                                    .font(.custom(GK.pixelFontName, size: 8))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(GK.Colors.buttonBlue))
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    HStack(spacing: 8) {
                        pixelIcon(.tapHand, size: 22)
                        Text("TAP TO FLAP")
                            .font(.custom(GK.pixelFontName, size: 9))
                            .foregroundColor(GK.Colors.panelBorder.opacity(0.6))
                    }
                    .padding(.top, 6)
                }
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
        ZStack {
            // Dim backdrop so numbers read clearly over the map
            Color.black.opacity(0.25)
                .ignoresSafeArea()

            // Number / GO text
            Group {
                if countdownLabel == "GO!" {
                    Text("GO!")
                        .font(.custom(GK.pixelFontName, size: 48))
                        .foregroundColor(GK.Colors.scoreYellow)
                        .shadow(color: Color.red, radius: 6)
                        .shadow(color: Color.red.opacity(0.6), radius: 18)
                        .shadow(color: .black, radius: 0, x: 3, y: 3)
                } else {
                    Text(countdownLabel)
                        .font(.custom(GK.pixelFontName, size: 72))
                        .foregroundColor(.white)
                        .shadow(color: GK.Colors.scoreYellow, radius: 6)
                        .shadow(color: GK.Colors.scoreYellow.opacity(0.5), radius: 16)
                        .shadow(color: .black, radius: 0, x: 4, y: 4)
                }
            }
            .scaleEffect(countdownScale)

            // Screen flash on GO
            Color.white.opacity(countdownFlashOpacity)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }

    /// Runs the "3, 2, 1, GO!" sequence over the game map, then auto-starts gameplay.
    private func runMapCountdown() {
        let goBeat: TimeInterval = 3.0
        let goFadeDuration: TimeInterval = 2.0
        showCountdownOverlay = true
        countdownOverlayOpacity = 1.0
        countdownFlashOpacity = 0
        countdownLabel = "3"
        countdownScale = 0.001

        SoundManager.shared.playMultiplayerCountdown()

        let beats: [(String, TimeInterval)] = [
            ("3", 0.0),
            ("2", 1.0),
            ("1", 2.0),
            ("GO!", goBeat)
        ]

        for (label, delay) in beats {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                countdownLabel = label
                countdownScale = 0.001

                if label == "GO!" {
                    withAnimation(.interactiveSpring(response: 0.25, dampingFraction: 0.4, blendDuration: 0.05)) {
                        countdownScale = 1.0
                    }
                    Haptic.win()
                    scene?.isReadyToStart = true
                    scene?.startPlaying()
                    phase = .playing

                    withAnimation(.easeOut(duration: goFadeDuration)) {
                        countdownOverlayOpacity = 0
                    }

                    // Flash
                    withAnimation(.easeOut(duration: 0.04)) {
                        countdownFlashOpacity = 0.6
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) {
                        withAnimation(.easeOut(duration: 0.25)) {
                            countdownFlashOpacity = 0
                        }
                    }
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5, blendDuration: 0.05)) {
                        countdownScale = 1.0
                    }
                    Haptic.score()
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + goBeat + goFadeDuration) {
            showCountdownOverlay = false
            countdownOverlayOpacity = 1.0
        }
    }

    // MARK: - Game Over Overlay

    private var gameOverOverlay: some View {
        VStack(spacing: 16) {
            gameOverTitle

            scorePanel
                .padding(.horizontal, 40)

            if finishingMatch {
                Text(isBattleRoyale ? "FINALIZING RUN..." : "FINALIZING MATCH...")
                    .font(.custom(GK.pixelFontName, size: 8))
                    .foregroundColor(.white.opacity(0.85))
            } else if headToHeadPending {
                Text("WAITING FOR OPPONENT...")
                    .font(.custom(GK.pixelFontName, size: 8))
                    .foregroundColor(.white.opacity(0.85))
            } else if battleRoyalePending {
                Text("SYNCING PLACEMENT...")
                    .font(.custom(GK.pixelFontName, size: 8))
                    .foregroundColor(.white.opacity(0.85))
            }

            if countingDone && !finishingMatch {
                HStack(spacing: 16) {
                    if !isHeadToHead && !isBattleRoyale {
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

                    if isBotLadder && ladderWon {
                        // After beating a bot, dismiss the fullScreenCover — the
                        // BotLadderView is already underneath in the nav stack,
                        // so no extra navigate() needed (was causing a double-push).
                        actionButton(icon: .ladder, label: "LADDER", color: GK.Colors.buttonOrange) {
                            SoundManager.shared.play(.button)
                            resetGameOverState()
                            manager.dismissGame()
                        }
                    } else {
                        actionButton(icon: .home, label: "HOME", color: GK.Colors.buttonOrange) {
                            SoundManager.shared.play(.button)
                            resetGameOverState()
                            manager.dismissGame()
                            if isHeadToHead || isBattleRoyale {
                                manager.path.removeLast()
                            }
                        }
                    }
                }
                .padding(.horizontal, 40)
                .transition(.opacity.combined(with: .move(edge: .bottom)))

                if (!isHeadToHead || headToHeadOutcomeReady) && !battleRoyalePending {
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
    }

    // MARK: - Game Over Title

    @ViewBuilder
    private var gameOverTitle: some View {
        if config.mode == .headToHead {
            if !headToHeadOutcomeReady {
                Text(finishingMatch ? "FINALIZING..." : "MATCH PENDING")
                    .font(.custom(GK.pixelFontName, size: 18))
                    .foregroundColor(.white)
                    .shadow(color: GK.Colors.pipeBorder, radius: 0, x: 3, y: 3)
            } else if headToHeadDidDraw {
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
        } else if config.mode == .battleRoyale {
            if battleRoyalePending {
                Text(finishingMatch ? "FINALIZING..." : "PLACEMENT PENDING")
                    .font(.custom(GK.pixelFontName, size: 18))
                    .foregroundColor(.white)
                    .shadow(color: GK.Colors.pipeBorder, radius: 0, x: 3, y: 3)
            } else if battleRoyalePlacement == 1 {
                Text("LAST DUCK!")
                    .font(.custom(GK.pixelFontName, size: 22))
                    .foregroundColor(GK.Colors.scoreYellow)
                    .shadow(color: GK.Colors.pipeBorder, radius: 0, x: 3, y: 3)
            } else {
                Text("PLACE #\(battleRoyalePlacement ?? 0)")
                    .font(.custom(GK.pixelFontName, size: 22))
                    .foregroundColor(.white)
                    .shadow(color: GK.Colors.pipeBorder, radius: 0, x: 3, y: 3)
            }
        } else if config.mode == .vsBot {
            let playerWon = isBotLadder ? ladderWon : score > botFinalScore

            if playerWon && showBotLadderCelebration {
                // Celebration title with golden pulse
                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        Image(uiImage: PixelIconFactory.shared.image(for: .star))
                            .interpolation(.none)
                            .resizable()
                            .frame(width: 20, height: 20)
                        Text("YOU WIN!")
                            .font(.custom(GK.pixelFontName, size: 24))
                            .foregroundColor(GK.Colors.scoreYellow)
                        Image(uiImage: PixelIconFactory.shared.image(for: .star))
                            .interpolation(.none)
                            .resizable()
                            .frame(width: 20, height: 20)
                    }
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

            if isBotLadder, let botName = config.opponentName {
                if playerWon {
                    HStack(spacing: 4) {
                        Text("\(botName) DEFEATED")
                            .font(.custom(GK.pixelFontName, size: 8))
                            .foregroundColor(GK.Colors.scoreYellow.opacity(0.8))
                        Image(uiImage: PixelIconFactory.shared.image(for: .checkmark))
                            .interpolation(.none)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 10, height: 10)
                    }
                } else {
                    Text("Outlast \(botName) to win!")
                        .font(.custom(GK.pixelFontName, size: 7))
                        .foregroundColor(.white.opacity(0.6))
                }
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

            if isBattleRoyale {
                Divider()
                HStack {
                    Text("PLACE")
                        .font(.custom(GK.pixelFontName, size: 10))
                        .foregroundColor(GK.Colors.panelBorder)
                    Spacer()
                    Text(battleRoyalePlacement.map { "#\($0)" } ?? "--")
                        .font(.custom(GK.pixelFontName, size: 18))
                        .foregroundColor(GK.Colors.scoreYellow)
                }

                HStack {
                    Text("ALIVE")
                        .font(.custom(GK.pixelFontName, size: 10))
                        .foregroundColor(GK.Colors.panelBorder)
                    Spacer()
                    Text("\(battleRoyaleState?.aliveCount ?? 0)")
                        .font(.custom(GK.pixelFontName, size: 18))
                        .foregroundColor(GK.Colors.panelBorder)
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
                    Image(uiImage: PixelIconFactory.shared.image(for: .star))
                        .interpolation(.none)
                        .resizable()
                        .frame(width: 12, height: 12)
                    Text("NEW BEST!")
                        .font(.custom(GK.pixelFontName, size: 12))
                        .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0))
                    Image(uiImage: PixelIconFactory.shared.image(for: .star))
                        .interpolation(.none)
                        .resizable()
                        .frame(width: 12, height: 12)
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

            if showBread && (!isHeadToHead || headToHeadOutcomeReady) && !battleRoyalePending {
                Divider()
                HStack {
                    Image(uiImage: TextureFactory.shared.breadUIImage(pixelScale: 3.0))
                        .interpolation(.none)
                        .resizable()
                        .frame(width: 20, height: 16)
                    Text(isBattleRoyale ? "+\(breadEarned) BREAD" : "+\(breadEarned)")
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
        return Group {
            if let icon = m.pixelIcon {
                Image(uiImage: PixelIconFactory.shared.image(for: icon))
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 28, height: 28)
                    .padding(.trailing, 4)
            }
        }
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



    private func shareScore() {
        // Item 7: Generate pixel-art share card image
        let shareCard = ShareCardView(
            score: score,
            medal: medal,
            bestScore: manager.stats.bestScore,
            mode: config.mode
        )
        let cardImage = shareCard.renderToImage()

        let medalText = medal != .none ? " \(medal.displayName) medal!" : ""
        let modeText = isHeadToHead ? " in Multiplayer" : ""
        let text = "I scored \(score)\(modeText) in Floppy Duck!\(medalText) Can you beat that?"

        var items: [Any] = [cardImage, text]
        if let appStoreURL = GK.appStoreURL {
            items.append(appStoreURL)
        }
        AnalyticsManager.shared.trackShareSheetOpened(mode: config.mode.rawValue, score: score)
        sharePayload = SharePayload(activityItems: items)
    }

    // MARK: - Achievement Processing

    private func processAchievements(score: Int, scene: GameScene) {
        let am = AchievementManager.shared
        let skinsOwned = SkinManager.shared.ownedSkins.count

        // Core game events
        am.process(event: .gameEnded(score: score), stats: manager.stats, skinsOwned: skinsOwned, manager: manager)
        am.process(event: .breadCollected(total: manager.stats.totalBreadCollected), stats: manager.stats, skinsOwned: skinsOwned, manager: manager)

        // Bot beaten count
        if !manager.stats.beatenBots.isEmpty {
            am.process(event: .botBeaten(totalBeaten: manager.stats.beatenBots.count), stats: manager.stats, skinsOwned: skinsOwned, manager: manager)
        }

        // Shield usage (per-game)
        for _ in 0..<scene.shieldsUsed {
            am.process(event: .shieldUsed, stats: manager.stats, skinsOwned: skinsOwned, manager: manager)
        }

        // Ghost pipe phasing (per-game)
        for _ in 0..<scene.ghostPipesPhased {
            am.process(event: .ghostPipePhased, stats: manager.stats, skinsOwned: skinsOwned, manager: manager)
        }

        // Magnet bread (per-game total)
        if scene.magnetBreadCollected > 0 {
            am.process(event: .magnetBreadCollected(count: scene.magnetBreadCollected), stats: manager.stats, skinsOwned: skinsOwned, manager: manager)
        }

        // Debuff survival: if player collected a debuff and survived extra points beyond it
        if let debuffStart = scene.debuffScoreAtStart, score > debuffStart {
            am.process(event: .debuffSurvivedWithScore(extraPoints: score - debuffStart), stats: manager.stats, skinsOwned: skinsOwned, manager: manager)
        }

        am.save()
    }
}

private struct SharePayload: Identifiable {
    let id = UUID()
    let activityItems: [Any]
}

private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Scene Bridge

private final class GameSceneBridge: GameSceneDelegate {
    let onStart: () -> Void
    let onScore: (Int) -> Void
    let onEnd: (Int) -> Void
    let onBotScore: (Int) -> Void
    let onBotLadderWin: (Int) -> Void
    let onQuickRetry: (Int) -> Void

    init(onStart: @escaping () -> Void,
         onScore: @escaping (Int) -> Void,
         onEnd: @escaping (Int) -> Void,
         onBotScore: @escaping (Int) -> Void = { _ in },
         onBotLadderWin: @escaping (Int) -> Void = { _ in },
         onQuickRetry: @escaping (Int) -> Void = { _ in }) {
        self.onStart = onStart
        self.onScore = onScore
        self.onEnd = onEnd
        self.onBotScore = onBotScore
        self.onBotLadderWin = onBotLadderWin
        self.onQuickRetry = onQuickRetry
    }

    func gameDidStart() { onStart() }
    func gameDidScore(_ score: Int) { onScore(score) }
    func gameDidEnd(score: Int) { onEnd(score) }
    func botDidScore(_ botScore: Int) { onBotScore(botScore) }
    func gameDidWinBotLadder(score: Int) { onBotLadderWin(score) }
    func gameDidQuickRetry(score: Int) { onQuickRetry(score) }
}
