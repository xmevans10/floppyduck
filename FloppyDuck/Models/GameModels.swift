import Foundation

// MARK: - Navigation

enum AppRoute: Hashable {
    case multiplayerModes
    case matchmaking(MatchmakingMode)
    case stats
    case settings
    case shop
    case botLadder
}

struct GameModeConfig: Identifiable, Hashable {
    let id: UUID
    let mode: GameMode
    let seed: Int
    let opponentName: String?
    let botDifficulty: BotDifficulty?
    let botCharacterId: String?
    let targetScore: Int?

    // Multiplayer metadata
    let matchId: String?
    let matchmakingMode: MatchmakingMode?
    let isRanked: Bool
    let roomCode: String?

    init(mode: GameMode,
         seed: Int = Int.random(in: 1...999999),
         opponentName: String? = nil,
         botDifficulty: BotDifficulty? = nil,
         botCharacterId: String? = nil,
         targetScore: Int? = nil,
         matchId: String? = nil,
         matchmakingMode: MatchmakingMode? = nil,
         isRanked: Bool = false,
         roomCode: String? = nil) {
        self.id = UUID()
        self.mode = mode
        self.seed = seed
        self.opponentName = opponentName
        self.botDifficulty = botDifficulty
        self.botCharacterId = botCharacterId
        self.targetScore = targetScore
        self.matchId = matchId
        self.matchmakingMode = matchmakingMode
        self.isRanked = isRanked
        self.roomCode = roomCode
    }

    static func == (lhs: GameModeConfig, rhs: GameModeConfig) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

enum GameMode: String, Hashable {
    case classic
    case headToHead
    case vsBot
}

enum MatchmakingMode: String, Hashable, Codable, CaseIterable {
    case quickPlay
    case ranked
    case privateRoom

    var queueValue: String {
        switch self {
        case .quickPlay: return "quick"
        case .ranked: return "ranked"
        case .privateRoom: return "private"
        }
    }

    var isRanked: Bool {
        self == .ranked
    }

    var queueTimeout: TimeInterval {
        switch self {
        case .quickPlay, .ranked:
            return 30
        case .privateRoom:
            return 120
        }
    }
}

// MARK: - Multiplayer

struct QueueTicket: Hashable, Codable {
    let ticketId: String
    let mode: MatchmakingMode
    let roomCode: String?
}

struct MultiplayerMatchAssignment: Hashable, Codable {
    let matchId: String
    let seed: Int
    let opponentName: String
    let mode: MatchmakingMode
    let isRanked: Bool
    let roomCode: String?
}

struct MultiplayerMatchState: Hashable, Codable {
    let matchId: String
    let localScore: Int
    let opponentScore: Int
    let isFinished: Bool
    let opponentName: String?
}

struct MultiplayerMatchResult: Hashable, Codable {
    let matchId: String
    let mode: MatchmakingMode
    let opponentName: String
    let localScore: Int
    let opponentScore: Int
    let didWin: Bool
    let didDraw: Bool
    let ratingDelta: Int?
    let newRating: Int?
    let isRanked: Bool
}

// MARK: - Medals

enum Medal: String {
    case none
    case bronze
    case silver
    case gold
    case platinum

    static func from(score: Int) -> Medal {
        if score >= GK.medalPlatinum { return .platinum }
        if score >= GK.medalGold     { return .gold }
        if score >= GK.medalSilver   { return .silver }
        if score >= GK.medalBronze   { return .bronze }
        return .none
    }

    var displayName: String {
        switch self {
        case .none:     return ""
        case .bronze:   return "BRONZE"
        case .silver:   return "SILVER"
        case .gold:     return "GOLD"
        case .platinum: return "PLATINUM"
        }
    }

    var emoji: String {
        switch self {
        case .none:     return ""
        case .bronze:   return "🥉"
        case .silver:   return "🥈"
        case .gold:     return "🥇"
        case .platinum: return "💎"
        }
    }
}

// MARK: - Leaderboard

struct LeaderboardEntry: Identifiable, Codable {
    let id: String
    let username: String
    let rating: Int
    let rank: Int
}

// MARK: - Stats

struct PlayerStats: Codable {
    var gamesPlayed: Int = 0
    var wins: Int = 0
    var losses: Int = 0
    var bestScore: Int = 0
    var totalScore: Int = 0
    var elo: Int = 1200
    var bread: Int = 0
    var recentScores: [Int] = []  // last 20
    var beatenBots: [String] = [] // ids of beaten bot ladder bots

    var winRate: Double {
        guard gamesPlayed > 0 else { return 0 }
        return Double(wins) / Double(gamesPlayed)
    }

    var averageScore: Double {
        guard gamesPlayed > 0 else { return 0 }
        return Double(totalScore) / Double(gamesPlayed)
    }

    mutating func recordGame(score: Int, won: Bool? = nil) {
        gamesPlayed += 1
        totalScore += score
        if score > bestScore { bestScore = score }

        recentScores.append(score)
        if recentScores.count > 20 { recentScores.removeFirst() }

        if let won {
            if won {
                wins += 1
                bread += max(3, score)
            } else {
                losses += 1
                bread += max(1, score / 2)
            }
        } else {
            bread += max(1, score)
        }
    }

    mutating func applyMatchResult(_ result: MultiplayerMatchResult) {
        if result.didDraw {
            recordGame(score: result.localScore, won: nil)
        } else {
            recordGame(score: result.localScore, won: result.didWin)
        }

        if result.isRanked {
            if let newRating = result.newRating {
                elo = newRating
            } else if let delta = result.ratingDelta {
                elo += delta
            }
        }
    }

    mutating func beatBot(_ botId: String) {
        if !beatenBots.contains(botId) {
            beatenBots.append(botId)
        }
    }
}
