import SwiftUI
import GameKit

/// Manages navigation, stats persistence, and multiplayer session coordination.
@MainActor
final class GameManager: ObservableObject {
    @Published var path = NavigationPath()
    @Published var stats: PlayerStats
    @Published var activeGameConfig: GameModeConfig? = nil

    // Settings
    @AppStorage("playerName") var playerName: String = "Player"
    @AppStorage("soundEnabled") var soundEnabled: Bool = true
    @AppStorage("hapticsEnabled") var hapticsEnabled: Bool = true
    @AppStorage("musicVolume") var musicVolume: Double = 1.0
    @AppStorage("sfxVolume") var sfxVolume: Double = 1.0

    // Daily streak
    @AppStorage("lastPlayDate") private var lastPlayDateString: String = ""
    @AppStorage("currentStreak") var currentStreak: Int = 0

    weak var authManager: AuthManager?

    private let multiplayerSession: MultiplayerSession
    private let headToHeadFinalizationPollInterval: TimeInterval
    private let headToHeadFinalizationTimeout: TimeInterval

    init(initialStats: PlayerStats? = nil,
         multiplayerClient: any MultiplayerBackendClient = ConvexClient.shared,
         headToHeadFinalizationPollInterval: TimeInterval = 1,
         headToHeadFinalizationTimeout: TimeInterval = 20) {
        self.multiplayerSession = MultiplayerSession(client: multiplayerClient)
        self.headToHeadFinalizationPollInterval = headToHeadFinalizationPollInterval
        self.headToHeadFinalizationTimeout = headToHeadFinalizationTimeout

        if let initialStats {
            stats = initialStats
        } else if let data = UserDefaults.standard.data(forKey: "playerStats"),
                  let decoded = try? JSONDecoder().decode(PlayerStats.self, from: data) {
            stats = decoded
        } else {
            stats = PlayerStats()
        }

        AchievementManager.shared.register(gameManager: self)

        // Sync battle banner & pipe skin unlocks with already-beaten bots
        BannerManager.shared.syncWithBeatenBots(stats.beatenBots)
        PipeSkinManager.shared.syncWithBeatenBots(stats.beatenBots)
    }

    func navigate(to route: AppRoute) {
        path.append(route)

        // Analytics: track navigation-based events
        switch route {
        case .shop: AnalyticsManager.shared.trackShopViewed()
        case .stats: AnalyticsManager.shared.trackStatsViewed()
        case .leaderboard: AnalyticsManager.shared.trackLeaderboardViewed()
        case .botLadder: AnalyticsManager.shared.trackModeSelected(mode: "botLadder")
        case .multiplayerModes: AnalyticsManager.shared.trackModeSelected(mode: "multiplayer")
        default: break
        }
    }

    func goHome() {
        path = NavigationPath()
    }

    /// Launch a game via fullScreenCover
    func startGame(_ config: GameModeConfig) {
        activeGameConfig = config
        AnalyticsManager.shared.trackGameStarted(
            mode: config.mode.rawValue,
            seed: config.seed,
            isRanked: config.isRanked
        )
    }

    /// Dismiss the game overlay and return home
    func dismissGame() {
        activeGameConfig = nil
    }

    // MARK: - Multiplayer Navigation

    @discardableResult
    func startMatchmaking(mode: MatchmakingMode) -> Bool {
        print("[Multiplayer] Starting matchmaking route — mode:\(mode.rawValue)")
        MultiplayerDiagnostics.record(
            category: "matchmaking",
            event: "start_route",
            message: "Opening matchmaking route.",
            mode: mode.rawValue
        )
        path.append(AppRoute.matchmaking(mode))
        AnalyticsManager.shared.trackMultiplayerQueueStarted(mode: mode.rawValue)
        return true
    }

    func startHeadToHead(matchAssignment: MultiplayerMatchAssignment) {
        AnalyticsManager.shared.trackMultiplayerMatchFound(mode: matchAssignment.mode.rawValue)

        print("[HeadToHead] Match assigned — matchId:\(matchAssignment.matchId) mode:\(matchAssignment.mode.rawValue) seed:\(matchAssignment.seed) host:\(matchAssignment.isGameKitHost) room:\(matchAssignment.roomCode ?? "nil") opponentSkin:\(matchAssignment.opponentSkinId ?? "nil")")
        MultiplayerDiagnostics.record(
            category: "matchmaking",
            event: "head_to_head_assignment",
            message: "Head-to-head assignment received.",
            matchId: matchAssignment.matchId,
            sessionCode: matchAssignment.gameKitSessionCode,
            mode: matchAssignment.mode.rawValue,
            metadata: [
                "seed": String(matchAssignment.seed),
                "isGameKitHost": String(matchAssignment.isGameKitHost),
                "isRanked": String(matchAssignment.isRanked),
                "roomCode": matchAssignment.roomCode ?? "nil",
                "opponentSkinId": matchAssignment.opponentSkinId ?? "nil",
            ]
        )

        let config = GameModeConfig(
            mode: .headToHead,
            seed: matchAssignment.seed,
            powerUpsEnabled: true,
            opponentName: matchAssignment.opponentName,
            opponentSkinId: matchAssignment.opponentSkinId,
            matchId: matchAssignment.matchId,
            matchmakingMode: matchAssignment.mode,
            isRanked: matchAssignment.isRanked,
            roomCode: matchAssignment.roomCode,
            gameKitSessionCode: matchAssignment.gameKitSessionCode,
            isGameKitHost: matchAssignment.isGameKitHost
        )
        startGame(config)
    }

    func startBattleRoyale(assignment: BattleRoyaleAssignment) {
        stats.bread = assignment.bread
        saveStats()

        let config = GameModeConfig(
            mode: .battleRoyale,
            seed: assignment.seed,
            matchmakingMode: .battleRoyale,
            battleRoyaleLobbyId: assignment.lobbyId,
            battleRoyaleEntrantId: assignment.entrantId
        )
        startGame(config)
    }

    // MARK: - Multiplayer Session

    func queueForMatch(mode: MatchmakingMode) async throws -> MultiplayerMatchAssignment {
        try await multiplayerSession.queueForMatch(mode: mode, timeout: mode.queueTimeout)
    }

    func createPrivateRoom() async throws -> String {
        try await multiplayerSession.createPrivateRoom()
    }

    func joinPrivateRoom(code: String) async throws {
        try await multiplayerSession.joinPrivateRoom(code: code)
    }

    func waitForPrivateRoomMatch() async throws -> MultiplayerMatchAssignment {
        try await multiplayerSession.waitForPrivateRoomMatch(timeout: MatchmakingMode.privateRoom.queueTimeout)
    }

    func cancelMatchmaking() async {
        await multiplayerSession.cancelMatchmaking()
    }

    func joinBattleRoyaleLobby() async throws -> BattleRoyaleAssignment {
        let assignment = try await multiplayerSession.joinBattleRoyaleLobby()
        stats.bread = assignment.bread
        saveStats()
        return assignment
    }

    func leaveBattleRoyaleLobby(lobbyId: String) async {
        if let bread = try? await multiplayerSession.leaveBattleRoyaleLobby(lobbyId: lobbyId) {
            stats.bread = bread
            saveStats()
        }
    }

    func startBattleRoyaleIfReady(lobbyId: String) async throws -> BattleRoyaleState {
        try await multiplayerSession.startBattleRoyaleIfReady(lobbyId: lobbyId)
    }

    func fetchBattleRoyaleState(lobbyId: String) async throws -> BattleRoyaleState {
        try await multiplayerSession.fetchBattleRoyaleState(lobbyId: lobbyId)
    }

    func reportBattleRoyaleState(lobbyId: String,
                                  score: Int,
                                  y: Double,
                                  rotation: Double,
                                  wingPhase: Int) async {
        await multiplayerSession.reportBattleRoyaleState(
            lobbyId: lobbyId,
            score: score,
            y: y,
            rotation: rotation,
            wingPhase: wingPhase
        )
    }

    func finishBattleRoyaleRun(lobbyId: String, score: Int) async -> BattleRoyaleState? {
        try? await multiplayerSession.finishBattleRoyaleRun(lobbyId: lobbyId, score: score)
    }

    func fetchHeadToHeadState(matchId: String) async throws -> MultiplayerMatchState {
        try await multiplayerSession.fetchMatchState(matchId: matchId)
    }

    func reportHeadToHeadScore(matchId: String, score: Int) async {
        await multiplayerSession.reportScore(matchId: matchId, score: score)
    }

    func finishHeadToHeadMatch(matchId: String,
                               score: Int,
                               fallbackOpponentScore: Int,
                               mode: MatchmakingMode,
                               opponentName: String?) async -> MultiplayerMatchResult {
        let pendingFallback = pendingHeadToHeadResult(
            matchId: matchId,
            score: score,
            opponentScore: fallbackOpponentScore,
            mode: mode,
            opponentName: opponentName
        )

        do {
            let result = try await multiplayerSession.finishMatch(
                matchId: matchId,
                score: score,
                mode: mode,
                fallbackOpponentScore: fallbackOpponentScore,
                opponentName: opponentName
            )

            if result.isFinalized {
                applyMatchResult(result)
                return result
            }

            return await awaitAuthoritativeHeadToHeadResult(
                matchId: matchId,
                mode: mode,
                opponentName: opponentName,
                latestKnownResult: result
            )
        } catch {
            return await awaitAuthoritativeHeadToHeadResult(
                matchId: matchId,
                mode: mode,
                opponentName: opponentName,
                latestKnownResult: pendingFallback
            )
        }
    }

    func abandonHeadToHeadMatch(matchId: String) async {
        await multiplayerSession.abandonMatch(matchId: matchId)
    }

    func applyMatchResult(_ result: MultiplayerMatchResult) {
        guard result.isFinalized else { return }
        stats.applyMatchResult(result)
        saveStats()
        AnalyticsManager.shared.trackMultiplayerMatchFinished(
            mode: result.mode.rawValue,
            won: result.didWin,
            score: result.localScore,
            opponentScore: result.opponentScore
        )
        syncStatsToServer()
    }

    func applyBattleRoyaleResult(_ state: BattleRoyaleState, score: Int, collectedBread: Int = 0) {
        stats.gamesPlayed += 1
        stats.bestScore = max(stats.bestScore, score)
        stats.totalScore += score
        stats.recentScores.append(score)
        if stats.recentScores.count > 20 {
            stats.recentScores = Array(stats.recentScores.suffix(20))
        }
        let reward = state.local.prize + max(0, collectedBread)
        stats.bread += reward
        stats.totalBreadCollected += reward
        saveStats()
        AnalyticsManager.shared.trackGameCompleted(mode: GameMode.battleRoyale.rawValue, score: score, won: state.local.placement == 1)
        syncStatsToServer()
    }

    func applyRemoteProfile(_ profile: RemotePlayerProfile) {
        playerName = profile.username
        var mergedStats = profile.stats
        mergedStats.bread = max(stats.bread, profile.stats.bread)
        mergedStats.totalBreadCollected = max(stats.totalBreadCollected, profile.stats.totalBreadCollected)
        mergedStats.bestScore = max(stats.bestScore, profile.stats.bestScore)
        mergedStats.gamesPlayed = max(stats.gamesPlayed, profile.stats.gamesPlayed)
        mergedStats.wins = max(stats.wins, profile.stats.wins)
        mergedStats.losses = max(stats.losses, profile.stats.losses)
        mergedStats.rankedWins = max(stats.rankedWins, profile.stats.rankedWins)
        mergedStats.rankedLosses = max(stats.rankedLosses, profile.stats.rankedLosses)
        mergedStats.totalScore = max(stats.totalScore, profile.stats.totalScore)
        mergedStats.elo = max(stats.elo, profile.stats.elo)
        mergedStats.peakElo = max(stats.peakElo, profile.stats.peakElo)
        mergedStats.winStreak = max(stats.winStreak, profile.stats.winStreak)
        mergedStats.bestWinStreak = max(stats.bestWinStreak, profile.stats.bestWinStreak)
        mergedStats.beatenBots = Array(Set(stats.beatenBots + profile.stats.beatenBots))
        mergedStats.recentScores = mergeRecentScores(stats.recentScores, profile.stats.recentScores)
        stats = mergedStats
        saveStats()
    }

    private func mergeRecentScores(_ local: [Int], _ remote: [Int]) -> [Int] {
        Array(Set(local + remote))
            .filter { $0 > 0 }
            .sorted(by: >)
            .prefix(20)
            .map { $0 }
    }

    func awardAchievementBread(_ amount: Int) {
        guard amount > 0 else { return }
        stats.bread += amount
        saveStats()
    }

    // MARK: - Auth Convenience APIs

    func bootstrapIdentity() {
        guard let authManager else { return }
        Task { await authManager.bootstrapIdentityIfNeeded() }
    }

    func continueAsGuest() {
        guard let authManager else { return }
        Task { await authManager.continueAsGuest() }
    }

    func signInWithApple() {
        guard let authManager else { return }
        Task { await authManager.signInWithApple() }
    }

    func signOut() {
        guard let authManager else { return }
        Task { await authManager.signOut() }
    }

    @discardableResult
    func ensureRankedAccess() -> Bool {
        authManager?.ensureRankedAccess() ?? false
    }

    // MARK: - Existing Stats APIs

    private func syncStatsToServer() {
        Task { [weak self] in
            guard let self else { return }
            let snapshot = LocalStatsSnapshot(
                username: playerName,
                stats: stats
            )
            try? await ConvexClient.shared.syncStats(snapshot)
        }
    }

    func recordGame(score: Int, won: Bool? = nil, collectedBread: Int = 0) {
        stats.recordGame(score: score, won: won, collectedBread: collectedBread)
        checkDailyStreak()
        saveStats()
        let mode = activeGameConfig?.mode.rawValue ?? "classic"
        AnalyticsManager.shared.trackGameCompleted(mode: mode, score: score, won: won)
        syncStatsToServer()
    }

    func checkDailyStreak() {
        let today = Calendar.current.startOfDay(for: Date())
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]

        let todayStr = formatter.string(from: today)

        if lastPlayDateString == todayStr { return } // Already counted today

        if let lastDate = formatter.date(from: lastPlayDateString) {
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today) ?? today
            if Calendar.current.isDate(lastDate, inSameDayAs: yesterday) {
                currentStreak += 1
            } else {
                currentStreak = 1
            }
        } else {
            currentStreak = 1
        }

        lastPlayDateString = todayStr

        // Bonus bread for streaks (3 per day, capped at 21 — rewards consistency without flooding)
        let bonus = min(currentStreak * 3, 21) // 3, 6, 9... up to 21
        stats.bread += bonus
        saveStats()

        // Fire streak achievement event
        AchievementManager.shared.process(
            event: .streakUpdated(days: currentStreak),
            stats: stats,
            skinsOwned: SkinManager.shared.ownedSkins.count,
            manager: self
        )
    }

    /// Mark a bot ladder bot as beaten and sync to backend immediately (XAN-9)
    func beatBot(_ botId: String) {
        stats.beatBot(botId)
        saveStats()
        AnalyticsManager.shared.trackBotMatchCompleted(botId: botId, won: true, score: 0)
        // Auto-unlock any battle banner or pipe skin tied to this bot
        BannerManager.shared.checkBotRewardUnlock(beatenBotId: botId)
        PipeSkinManager.shared.checkBotRewardUnlock(beatenBotId: botId)

        // Sync to backend immediately so progress persists even if the
        // player replays the level without returning home. (XAN-9)
        Task {
            do {
                try await ConvexClient.shared.syncBeatenBots(stats.beatenBots)
            } catch {
                // Best-effort — local save already succeeded.
                // Will re-sync on next bootstrapGuest.
                print("[GameManager] Bot sync failed (will retry on next bootstrap): \(error)")
            }
        }
    }

    /// Check if a bot has been beaten
    func isBotBeaten(_ botId: String) -> Bool {
        stats.beatenBots.contains(botId)
    }

    /// Next bot index the player can challenge (0-based)
    var nextBotIndex: Int {
        let beaten = Set(stats.beatenBots)
        for (i, bot) in BotCharacter.all.enumerated() {
            if !beaten.contains(bot.id) { return i }
        }
        return BotCharacter.all.count // all beaten
    }

    /// Start a bot ladder match — uses the bot's fixed seed so the same
    /// pipe course is generated every attempt against this bot.
    func startBotLadderMatch(_ bot: BotCharacter) {
        AnalyticsManager.shared.trackBotMatchStarted(botId: bot.id, botName: bot.name, targetScore: bot.targetScore)
        let config = GameModeConfig(
            mode: .vsBot,
            seed: bot.seed,
            opponentName: bot.name,
            botDifficulty: bot.difficulty,
            botCharacterId: bot.id,
            botSkin: bot.skin,
            backgroundTheme: bot.theme,
            targetScore: bot.targetScore
        )
        startGame(config)
    }

    func resetStats() {
        stats = PlayerStats()
        saveStats()
    }

    @discardableResult
    func spendBread(_ amount: Int) -> Bool {
        guard amount > 0 else { return true }
        guard stats.bread >= amount else { return false }
        stats.bread -= amount
        saveStats()

        // Sync the deduction to the Convex backend so the remote
        // value doesn't overwrite local on next profile load.
        let localBalanceAfterSpend = stats.bread
        Task { [weak self, amount, localBalanceAfterSpend] in
            guard let remoteBread = try? await ConvexClient.shared.spendBread(amount) else { return }
            await MainActor.run {
                guard let self, self.stats.bread == localBalanceAfterSpend else { return }
                self.stats.bread = remoteBread
                self.saveStats()
            }
        }

        return true
    }

    private func saveStats() {
        if let data = try? JSONEncoder().encode(stats) {
            UserDefaults.standard.set(data, forKey: "playerStats")
        }
    }

    private func pendingHeadToHeadResult(matchId: String,
                                         score: Int,
                                         opponentScore: Int,
                                         mode: MatchmakingMode,
                                         opponentName: String?) -> MultiplayerMatchResult {
        MultiplayerMatchResult(
            matchId: matchId,
            mode: mode,
            opponentName: opponentName ?? "OPPONENT",
            localScore: score,
            opponentScore: opponentScore,
            didWin: score > opponentScore,
            didDraw: score == opponentScore,
            ratingDelta: nil,
            newRating: nil,
            isRanked: mode.isRanked,
            isFinalized: false
        )
    }

    private func awaitAuthoritativeHeadToHeadResult(matchId: String,
                                                    mode: MatchmakingMode,
                                                    opponentName: String?,
                                                    latestKnownResult: MultiplayerMatchResult) async -> MultiplayerMatchResult {
        var latestResult = latestKnownResult
        let deadline = Date().addingTimeInterval(headToHeadFinalizationTimeout)

        while Date() < deadline {
            do {
                let state = try await multiplayerSession.fetchMatchState(matchId: matchId)
                if let finalized = state.finalizedResult(mode: mode, fallbackOpponentName: opponentName) {
                    applyMatchResult(finalized)
                    return finalized
                }

                latestResult = pendingHeadToHeadResult(
                    matchId: matchId,
                    score: state.localScore,
                    opponentScore: state.opponentScore,
                    mode: mode,
                    opponentName: state.opponentName ?? opponentName ?? latestResult.opponentName
                )
            } catch is CancellationError {
                return latestResult
            } catch {
                // Leave the latest pending state in place and try again until timeout.
            }

            let interval = max(headToHeadFinalizationPollInterval, 0.1)
            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
        }

        return latestResult
    }
}

// MARK: - Multiplayer Session Coordinator

actor MultiplayerSession {
    private let client: any MultiplayerBackendClient

    private var currentMode: MatchmakingMode?
    private var currentTicket: QueueTicket?
    private var currentRoomCode: String?
    private var currentBattleRoyaleLobbyId: String?

    init(client: any MultiplayerBackendClient) {
        self.client = client
    }

    func queueForMatch(mode: MatchmakingMode,
                       timeout: TimeInterval) async throws -> MultiplayerMatchAssignment {
        guard mode != .privateRoom else {
            throw MultiplayerSessionError.invalidMode
        }

        currentMode = mode
        let ticket = try await client.joinMatchmakingQueue(mode: mode)
        currentTicket = ticket
        currentRoomCode = nil
        currentBattleRoyaleLobbyId = nil
#if DEBUG
        print("[Multiplayer] 🎫 Joined queue — ticketId:\(ticket.ticketId) mode:\(mode.rawValue) timeout:\(timeout)s")
#endif
        MultiplayerDiagnostics.record(
            category: "matchmaking",
            event: "queue_joined",
            message: "Joined Convex matchmaking queue.",
            mode: mode.rawValue,
            metadata: ["ticketId": ticket.ticketId, "timeout": String(timeout)]
        )
        let assignment = try await waitForMatch(timeout: timeout)
#if DEBUG
        print("[Multiplayer] ⚔️ Match found! \(describeAssignment(assignment))")
#endif
        MultiplayerDiagnostics.record(
            category: "matchmaking",
            event: "assignment_found",
            message: "Convex returned a head-to-head assignment.",
            matchId: assignment.matchId,
            sessionCode: assignment.gameKitSessionCode,
            playerGroup: nil,
            mode: assignment.mode.rawValue,
            metadata: assignmentDiagnosticMetadata(assignment)
        )
        return assignment
    }

    func createPrivateRoom() async throws -> String {
        currentMode = .privateRoom
        let ticket = try await client.createRoom()
        currentTicket = ticket
        currentRoomCode = ticket.roomCode
        currentBattleRoyaleLobbyId = nil

        guard let code = ticket.roomCode, code.count == GK.roomCodeLength else {
            throw MultiplayerSessionError.invalidRoomCode
        }
#if DEBUG
        print("[Multiplayer] 🏠 Room created — code:\(code)")
#endif
        MultiplayerDiagnostics.record(
            category: "matchmaking",
            event: "private_room_created",
            message: "Private room created.",
            mode: MatchmakingMode.privateRoom.rawValue,
            metadata: ["roomCode": code, "ticketId": ticket.ticketId]
        )
        return code
    }

    func joinPrivateRoom(code: String) async throws {
        let normalized = String(code.prefix(GK.roomCodeLength)).uppercased()
        guard normalized.count == GK.roomCodeLength else {
            throw MultiplayerSessionError.invalidRoomCode
        }

        currentMode = .privateRoom
        currentRoomCode = normalized
        currentBattleRoyaleLobbyId = nil
        currentTicket = try await client.joinRoom(code: normalized)
#if DEBUG
        print("[Multiplayer] 🚪 Joined room — code:\(normalized)")
#endif
        MultiplayerDiagnostics.record(
            category: "matchmaking",
            event: "private_room_joined",
            message: "Private room joined.",
            mode: MatchmakingMode.privateRoom.rawValue,
            metadata: ["roomCode": normalized, "ticketId": currentTicket?.ticketId ?? "nil"]
        )
    }

    func waitForPrivateRoomMatch(timeout: TimeInterval) async throws -> MultiplayerMatchAssignment {
        guard currentMode == .privateRoom else {
            throw MultiplayerSessionError.invalidMode
        }
        return try await waitForMatch(timeout: timeout)
    }

    func cancelMatchmaking() async {
#if DEBUG
        print("[Multiplayer] ❌ Cancelling — mode:\(currentMode?.rawValue ?? "?") room:\(currentRoomCode ?? "none")")
#endif
        MultiplayerDiagnostics.record(
            category: "matchmaking",
            event: "cancel_requested",
            level: "warning",
            message: "Cancelling matchmaking session.",
            mode: currentMode?.rawValue,
            metadata: [
                "ticketId": currentTicket?.ticketId ?? "nil",
                "roomCode": currentRoomCode ?? "nil",
                "battleRoyaleLobbyId": currentBattleRoyaleLobbyId ?? "nil",
            ]
        )
        guard currentMode != nil || currentTicket != nil || currentRoomCode != nil || currentBattleRoyaleLobbyId != nil else {
            return
        }

        do {
            if let code = currentRoomCode {
                try await client.leaveRoom(code: code)
            } else if let lobbyId = currentBattleRoyaleLobbyId {
                _ = try await client.leaveBattleRoyaleLobby(lobbyId: lobbyId)
            } else {
                try await client.leaveMatchmakingQueue(ticketId: currentTicket?.ticketId)
            }
        } catch {
            // Best-effort cancellation.
        }

        currentMode = nil
        currentTicket = nil
        currentRoomCode = nil
        currentBattleRoyaleLobbyId = nil
    }

    func joinBattleRoyaleLobby() async throws -> BattleRoyaleAssignment {
        currentMode = .battleRoyale
        currentTicket = nil
        currentRoomCode = nil
        let assignment = try await client.joinBattleRoyaleLobby()
        currentBattleRoyaleLobbyId = assignment.lobbyId
        return assignment
    }

    func leaveBattleRoyaleLobby(lobbyId: String) async throws -> Int? {
        let bread = try await client.leaveBattleRoyaleLobby(lobbyId: lobbyId)
        if currentBattleRoyaleLobbyId == lobbyId {
            currentMode = nil
            currentBattleRoyaleLobbyId = nil
        }
        return bread
    }

    func startBattleRoyaleIfReady(lobbyId: String) async throws -> BattleRoyaleState {
        try await client.startBattleRoyaleIfReady(lobbyId: lobbyId)
    }

    func fetchBattleRoyaleState(lobbyId: String) async throws -> BattleRoyaleState {
        try await client.getBattleRoyaleState(lobbyId: lobbyId)
    }

    func reportBattleRoyaleState(lobbyId: String,
                                  score: Int,
                                  y: Double,
                                  rotation: Double,
                                  wingPhase: Int) async {
        do {
            try await client.reportBattleRoyaleState(
                lobbyId: lobbyId,
                score: score,
                y: y,
                rotation: rotation,
                wingPhase: wingPhase
            )
        } catch {
#if DEBUG
            print("[BattleRoyale] ⚠️ State report failed (non-fatal): \(error)")
#endif
        }
    }

    func finishBattleRoyaleRun(lobbyId: String, score: Int) async throws -> BattleRoyaleState {
        let state = try await client.finishBattleRoyaleRun(lobbyId: lobbyId, score: score)
        if currentBattleRoyaleLobbyId == lobbyId {
            currentMode = nil
            currentBattleRoyaleLobbyId = nil
        }
        return state
    }

    func fetchMatchState(matchId: String) async throws -> MultiplayerMatchState {
        try await client.getMatchState(matchId: matchId)
    }

    func reportScore(matchId: String, score: Int) async {
        do {
#if DEBUG
            print("[Multiplayer] 📊 Reporting score \(score) → matchId:\(matchId)")
#endif
            try await client.reportScore(matchId: matchId, score: score)
        } catch {
#if DEBUG
            print("[Multiplayer] ⚠️ Score report failed (non-fatal): \(error)")
#endif
        }
    }

    func finishMatch(matchId: String,
                     score: Int,
                     mode: MatchmakingMode,
                     fallbackOpponentScore: Int,
                     opponentName: String?) async throws -> MultiplayerMatchResult {
#if DEBUG
        print("[Multiplayer] 🏁 Finishing match \(matchId) — score:\(score) fallbackOpp:\(fallbackOpponentScore)")
#endif
        let result = try await client.finishMatch(
            matchId: matchId,
            score: score,
            mode: mode,
            fallbackOpponentScore: fallbackOpponentScore,
            opponentName: opponentName
        )
#if DEBUG
        print("[Multiplayer] 🏆 Result — finalized:\(result.isFinalized) you:\(result.localScore) them:\(result.opponentScore) draw:\(result.didDraw) delta:\(result.ratingDelta ?? 0)")
#endif

        currentMode = nil
        currentTicket = nil
        currentRoomCode = nil
        currentBattleRoyaleLobbyId = nil
        return result
    }

    func abandonMatch(matchId: String) async {
        do {
            try await client.abandonMatch(matchId: matchId)
        } catch {
#if DEBUG
            print("[Multiplayer] ⚠️ Match abandon failed (non-fatal): \(error)")
#endif
        }

        currentMode = nil
        currentTicket = nil
        currentRoomCode = nil
        currentBattleRoyaleLobbyId = nil
    }

    private func waitForMatch(timeout: TimeInterval) async throws -> MultiplayerMatchAssignment {
        let deadline = Date().addingTimeInterval(timeout)
        var pollCount = 0

        while Date() < deadline {
            try Task.checkCancellation()
            pollCount += 1

            let assignment: MultiplayerMatchAssignment?
            do {
                if let roomCode = currentRoomCode {
                    print("[Multiplayer] Poll \(pollCount) checkRoom code:\(roomCode)")
                    assignment = try await client.checkRoom(code: roomCode)
                } else {
                    print("[Multiplayer] Poll \(pollCount) checkQueue ticket:\(currentTicket?.ticketId ?? "nil") mode:\(currentMode?.rawValue ?? "nil")")
                    if let ticketId = currentTicket?.ticketId {
                        do {
                            let _ = try await client.heartbeatQueue(ticketId: ticketId)
                        } catch {
                            // best-effort heartbeat; continue polling
                        }
                    }
                    assignment = try await client.checkQueue(ticketId: currentTicket?.ticketId, mode: currentMode)
                }
            } catch let error as CancellationError {
                throw error
            } catch {
                print("[Multiplayer] Poll \(pollCount) failed: \(error.localizedDescription)")
                MultiplayerDiagnostics.record(
                    category: "matchmaking",
                    event: "poll_failed",
                    level: "warning",
                    message: error.localizedDescription,
                    mode: currentMode?.rawValue,
                    metadata: [
                        "pollCount": String(pollCount),
                        "ticketId": currentTicket?.ticketId ?? "nil",
                        "roomCode": currentRoomCode ?? "nil",
                    ]
                )
                guard shouldRetryMatchPolling(after: error) else {
                    throw error
                }

                try await Task.sleep(nanoseconds: 1_000_000_000)
                continue
            }

            if let assignment {
                print("[Multiplayer] Poll \(pollCount) returned assignment — \(describeAssignment(assignment))")
                return assignment
            }

            if pollCount == 1 || pollCount % 5 == 0 {
                MultiplayerDiagnostics.record(
                    category: "matchmaking",
                    event: "poll_waiting",
                    message: "No Convex assignment yet.",
                    mode: currentMode?.rawValue,
                    metadata: [
                        "pollCount": String(pollCount),
                        "ticketId": currentTicket?.ticketId ?? "nil",
                        "roomCode": currentRoomCode ?? "nil",
                        "remainingSeconds": String(format: "%.1f", max(0, deadline.timeIntervalSinceNow)),
                    ]
                )
            }

            try await Task.sleep(nanoseconds: 1_000_000_000)
        }

        MultiplayerDiagnostics.record(
            category: "matchmaking",
            event: "poll_timeout",
            level: "error",
            message: "Timed out waiting for Convex assignment.",
            mode: currentMode?.rawValue,
            metadata: [
                "pollCount": String(pollCount),
                "ticketId": currentTicket?.ticketId ?? "nil",
                "roomCode": currentRoomCode ?? "nil",
            ]
        )
        throw MultiplayerSessionError.timeout
    }

    private func describeAssignment(_ assignment: MultiplayerMatchAssignment) -> String {
        return "matchId:\(assignment.matchId) mode:\(assignment.mode.rawValue) ranked:\(assignment.isRanked) seed:\(assignment.seed) host:\(assignment.isGameKitHost) room:\(assignment.roomCode ?? "nil") opponent:\(assignment.opponentName) skin:\(assignment.opponentSkinId ?? "nil")"
    }

    private func assignmentDiagnosticMetadata(_ assignment: MultiplayerMatchAssignment) -> [String: String] {
        [
            "seed": String(assignment.seed),
            "opponentName": assignment.opponentName,
            "opponentSkinId": assignment.opponentSkinId ?? "nil",
            "isRanked": String(assignment.isRanked),
            "roomCode": assignment.roomCode ?? "nil",
            "isGameKitHost": String(assignment.isGameKitHost),
        ]
    }

    private func shouldRetryMatchPolling(after error: Error) -> Bool {
        if let convexError = error as? ConvexError {
            switch convexError {
            case .requestFailed:
                return true
            case .server(let message):
                let lowered = message.lowercased()
                return lowered.contains("resolve user identity")
                    || lowered.contains("missing device identity")
                    || lowered.contains("request failed")
                    || lowered.contains("timed out")
            case .invalidResponse, .authFailed:
                return false
            }
        }

        let lowered = error.localizedDescription.lowercased()
        return lowered.contains("network")
            || lowered.contains("offline")
            || lowered.contains("timed out")
    }
}

enum MultiplayerSessionError: LocalizedError {
    case timeout
    case invalidMode
    case invalidRoomCode

    var errorDescription: String? {
        switch self {
        case .timeout:
            return "Matchmaking timed out."
        case .invalidMode:
            return "Invalid matchmaking mode for this action."
        case .invalidRoomCode:
            return "Room code must be 5 characters."
        }
    }
}
