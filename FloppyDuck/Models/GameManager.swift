import SwiftUI

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

    private let multiplayerSession = MultiplayerSession(client: .shared)

    init() {
        if let data = UserDefaults.standard.data(forKey: "playerStats"),
           let decoded = try? JSONDecoder().decode(PlayerStats.self, from: data) {
            stats = decoded
        } else {
            stats = PlayerStats()
        }
    }

    func navigate(to route: AppRoute) {
        path.append(route)
    }

    func goHome() {
        path = NavigationPath()
    }

    /// Launch a game via fullScreenCover
    func startGame(_ config: GameModeConfig) {
        activeGameConfig = config
    }

    /// Dismiss the game overlay and return home
    func dismissGame() {
        activeGameConfig = nil
    }

    // MARK: - Multiplayer Navigation

    func startMatchmaking(mode: MatchmakingMode) {
        path.append(AppRoute.matchmaking(mode))
    }

    func startHeadToHead(matchAssignment: MultiplayerMatchAssignment) {
        let config = GameModeConfig(
            mode: .headToHead,
            seed: matchAssignment.seed,
            opponentName: matchAssignment.opponentName,
            matchId: matchAssignment.matchId,
            matchmakingMode: matchAssignment.mode,
            isRanked: matchAssignment.isRanked,
            roomCode: matchAssignment.roomCode
        )
        startGame(config)
    }

    // MARK: - Multiplayer Session

    func queueForMatch(mode: MatchmakingMode) async throws -> MultiplayerMatchAssignment {
        let rating = stats.elo
        return try await multiplayerSession.queueForMatch(mode: mode, rating: rating, timeout: mode.queueTimeout)
    }

    func createPrivateRoom() async throws -> String {
        let rating = stats.elo
        return try await multiplayerSession.createPrivateRoom(rating: rating)
    }

    func joinPrivateRoom(code: String) async throws {
        let rating = stats.elo
        try await multiplayerSession.joinPrivateRoom(code: code, rating: rating)
    }

    func waitForPrivateRoomMatch() async throws -> MultiplayerMatchAssignment {
        try await multiplayerSession.waitForPrivateRoomMatch(timeout: MatchmakingMode.privateRoom.queueTimeout)
    }

    func cancelMatchmaking() async {
        await multiplayerSession.cancelMatchmaking()
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
        do {
            let result = try await multiplayerSession.finishMatch(
                matchId: matchId,
                score: score,
                mode: mode,
                fallbackOpponentScore: fallbackOpponentScore,
                opponentName: opponentName
            )
            applyMatchResult(result)
            return result
        } catch {
            let didWin = score > fallbackOpponentScore
            let didDraw = score == fallbackOpponentScore
            let fallback = MultiplayerMatchResult(
                matchId: matchId,
                mode: mode,
                opponentName: opponentName ?? "OPPONENT",
                localScore: score,
                opponentScore: fallbackOpponentScore,
                didWin: didWin,
                didDraw: didDraw,
                ratingDelta: nil,
                newRating: nil,
                isRanked: mode.isRanked
            )
            applyMatchResult(fallback)
            return fallback
        }
    }

    func applyMatchResult(_ result: MultiplayerMatchResult) {
        stats.applyMatchResult(result)
        saveStats()
    }

    // MARK: - Existing Stats APIs

    func recordGame(score: Int, won: Bool? = nil) {
        stats.recordGame(score: score, won: won)
        saveStats()
    }

    /// Mark a bot ladder bot as beaten
    func beatBot(_ botId: String) {
        stats.beatBot(botId)
        saveStats()
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

    /// Start a bot ladder match
    func startBotLadderMatch(_ bot: BotCharacter) {
        let config = GameModeConfig(
            mode: .vsBot,
            opponentName: bot.name,
            botDifficulty: bot.difficulty,
            botCharacterId: bot.id,
            targetScore: bot.targetScore
        )
        startGame(config)
    }

    func resetStats() {
        stats = PlayerStats()
        saveStats()
    }

    private func saveStats() {
        if let data = try? JSONEncoder().encode(stats) {
            UserDefaults.standard.set(data, forKey: "playerStats")
        }
    }
}

// MARK: - Multiplayer Session Coordinator

actor MultiplayerSession {
    private let client: ConvexClient

    private var currentMode: MatchmakingMode?
    private var currentTicket: QueueTicket?
    private var currentRoomCode: String?

    init(client: ConvexClient) {
        self.client = client
    }

    func queueForMatch(mode: MatchmakingMode,
                       rating: Int,
                       timeout: TimeInterval) async throws -> MultiplayerMatchAssignment {
        guard mode != .privateRoom else {
            throw MultiplayerSessionError.invalidMode
        }

        currentMode = mode
        currentTicket = try await client.joinMatchmakingQueue(mode: mode, rating: rating)
        currentRoomCode = nil
        return try await waitForMatch(timeout: timeout)
    }

    func createPrivateRoom(rating: Int) async throws -> String {
        currentMode = .privateRoom
        let ticket = try await client.createRoom(rating: rating)
        currentTicket = ticket
        currentRoomCode = ticket.roomCode

        guard let code = ticket.roomCode, code.count == GK.roomCodeLength else {
            throw MultiplayerSessionError.invalidRoomCode
        }
        return code
    }

    func joinPrivateRoom(code: String, rating: Int) async throws {
        let normalized = String(code.prefix(GK.roomCodeLength)).uppercased()
        guard normalized.count == GK.roomCodeLength else {
            throw MultiplayerSessionError.invalidRoomCode
        }

        currentMode = .privateRoom
        currentRoomCode = normalized
        currentTicket = try await client.joinRoom(code: normalized, rating: rating)
    }

    func waitForPrivateRoomMatch(timeout: TimeInterval) async throws -> MultiplayerMatchAssignment {
        guard currentMode == .privateRoom else {
            throw MultiplayerSessionError.invalidMode
        }
        return try await waitForMatch(timeout: timeout)
    }

    func cancelMatchmaking() async {
        do {
            if let code = currentRoomCode {
                try await client.leaveRoom(code: code)
            } else {
                try await client.leaveMatchmakingQueue(ticketId: currentTicket?.ticketId)
            }
        } catch {
            // Best-effort cancellation.
        }

        currentMode = nil
        currentTicket = nil
        currentRoomCode = nil
    }

    func fetchMatchState(matchId: String) async throws -> MultiplayerMatchState {
        try await client.getMatchState(matchId: matchId)
    }

    func reportScore(matchId: String, score: Int) async {
        do {
            try await client.reportScore(matchId: matchId, score: score)
        } catch {
            // Score reporting should be non-fatal to local gameplay.
        }
    }

    func finishMatch(matchId: String,
                     score: Int,
                     mode: MatchmakingMode,
                     fallbackOpponentScore: Int,
                     opponentName: String?) async throws -> MultiplayerMatchResult {
        let result = try await client.finishMatch(
            matchId: matchId,
            score: score,
            mode: mode,
            fallbackOpponentScore: fallbackOpponentScore,
            opponentName: opponentName
        )

        currentMode = nil
        currentTicket = nil
        currentRoomCode = nil
        return result
    }

    private func waitForMatch(timeout: TimeInterval) async throws -> MultiplayerMatchAssignment {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            try Task.checkCancellation()

            let assignment: MultiplayerMatchAssignment?
            if let roomCode = currentRoomCode {
                assignment = try await client.checkRoom(code: roomCode)
            } else {
                assignment = try await client.checkQueue(ticketId: currentTicket?.ticketId, mode: currentMode)
            }

            if let assignment {
                return assignment
            }

            try await Task.sleep(nanoseconds: 1_000_000_000)
        }

        throw MultiplayerSessionError.timeout
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
