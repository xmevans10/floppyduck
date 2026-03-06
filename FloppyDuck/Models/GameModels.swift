import Foundation

// MARK: - Navigation

enum AppRoute: Hashable {
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

    init(mode: GameMode,
         seed: Int = Int.random(in: 1...999999),
         opponentName: String? = nil,
         botDifficulty: BotDifficulty? = nil,
         botCharacterId: String? = nil,
         targetScore: Int? = nil) {
        self.id = UUID()
        self.mode = mode
        self.seed = seed
        self.opponentName = opponentName
        self.botDifficulty = botDifficulty
        self.botCharacterId = botCharacterId
        self.targetScore = targetScore
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

enum MatchmakingMode: Hashable {
    case quickPlay
    case ranked
    case privateRoom
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

    mutating func beatBot(_ botId: String) {
        if !beatenBots.contains(botId) {
            beatenBots.append(botId)
        }
    }
}
