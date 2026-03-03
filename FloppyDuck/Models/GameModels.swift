import Foundation

// MARK: - Game Mode

enum GameMode: Hashable {
    case solo
    case multiplayer(matchId: String)
}

// MARK: - Player Stats

struct PlayerStats {
    var rating: Int = 1000
    var bestScore: Int = 0
    var gamesPlayed: Int = 0
    var wins: Int = 0
    
    var winRate: Double {
        guard gamesPlayed > 0 else { return 0 }
        return Double(wins) / Double(gamesPlayed)
    }
}

// MARK: - Match

struct Match: Identifiable {
    let id: String
    let seed: Int
    let mode: MatchType
    var hostScore: Int = 0
    var guestScore: Int = 0
    var status: MatchStatus = .waiting
    
    var roomCode: String?
}

enum MatchType: String {
    case quickPlay = "quick"
    case ranked = "ranked"
    case privateRoom = "private"
}

enum MatchStatus: String {
    case waiting
    case countdown
    case playing
    case finished
}

// MARK: - Leaderboard Entry

struct LeaderboardEntry: Identifiable {
    let id: String
    let username: String
    let rating: Int
    let rank: Int
}
