import Foundation
import SwiftUI

// MARK: - Navigation

enum AppRoute: Hashable {
    case multiplayerModes
    case matchmaking(MatchmakingMode)
    case stats
    case settings
    case shop
    case botLadder
    case collection
    case leaderboard
    case achievements
}

struct GameModeConfig: Identifiable, Hashable {
    let id: UUID
    let mode: GameMode
    let seed: Int
    let opponentName: String?
    let opponentSkinId: String?
    let botDifficulty: BotDifficulty?
    let botCharacterId: String?
    let botSkin: DuckSkin?
    let targetScore: Int?

    // Multiplayer metadata
    let matchId: String?
    let matchmakingMode: MatchmakingMode?
    let isRanked: Bool
    let roomCode: String?
    let gameKitSessionCode: String?

    init(mode: GameMode,
         seed: Int = Int.random(in: 1...999999),
         opponentName: String? = nil,
         opponentSkinId: String? = nil,
         botDifficulty: BotDifficulty? = nil,
         botCharacterId: String? = nil,
         botSkin: DuckSkin? = nil,
         targetScore: Int? = nil,
         matchId: String? = nil,
         matchmakingMode: MatchmakingMode? = nil,
         isRanked: Bool = false,
         roomCode: String? = nil,
         gameKitSessionCode: String? = nil) {
        self.id = UUID()
        self.mode = mode
        self.seed = seed
        self.opponentName = opponentName
        self.opponentSkinId = opponentSkinId
        self.botDifficulty = botDifficulty
        self.botCharacterId = botCharacterId
        self.botSkin = botSkin
        self.targetScore = targetScore
        self.matchId = matchId
        self.matchmakingMode = matchmakingMode
        self.isRanked = isRanked
        self.roomCode = roomCode
        self.gameKitSessionCode = gameKitSessionCode
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

    var shareDisplayName: String {
        switch self {
        case .classic:    return "Classic"
        case .headToHead: return "Head to Head"
        case .vsBot:      return "VS Bot"
        }
    }
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

// MARK: - Auth

enum AuthProvider: String, Hashable, Codable {
    case guest
    case apple
}

enum AuthState: Hashable {
    case bootstrapping
    case onboardingRequired
    case authenticated(AuthProvider)
    case failed(String)
}

struct PlayerIdentity: Hashable, Codable {
    let userId: String
    let provider: AuthProvider
    let deviceId: String
    let appleUserId: String?
    let sessionToken: String?
    let sessionExpiresAt: Date?
}

struct LocalStatsSnapshot: Hashable, Codable {
    let username: String
    let gamesPlayed: Int
    let wins: Int
    let losses: Int
    let bestScore: Int
    let totalScore: Int
    let elo: Int
    let bread: Int
    let totalBreadCollected: Int
    let recentScores: [Int]
    let beatenBots: [String]
    let peakElo: Int
    let winStreak: Int
    let bestWinStreak: Int

    enum CodingKeys: String, CodingKey {
        case username
        case gamesPlayed
        case wins
        case losses
        case bestScore
        case totalScore
        case elo
        case bread
        case totalBreadCollected
        case recentScores
        case beatenBots
        case peakElo
        case winStreak
        case bestWinStreak
    }

    init(username: String, stats: PlayerStats) {
        self.username = username
        self.gamesPlayed = stats.gamesPlayed
        self.wins = stats.wins
        self.losses = stats.losses
        self.bestScore = stats.bestScore
        self.totalScore = stats.totalScore
        self.elo = stats.elo
        self.bread = stats.bread
        self.totalBreadCollected = stats.totalBreadCollected
        self.recentScores = stats.recentScores
        self.beatenBots = stats.beatenBots
        self.peakElo = stats.peakElo
        self.winStreak = stats.winStreak
        self.bestWinStreak = stats.bestWinStreak
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let username = try container.decode(String.self, forKey: .username)
        let gamesPlayed = try container.decodeIfPresent(Int.self, forKey: .gamesPlayed) ?? 0
        let wins = try container.decodeIfPresent(Int.self, forKey: .wins) ?? 0
        let losses = try container.decodeIfPresent(Int.self, forKey: .losses) ?? 0
        let bestScore = try container.decodeIfPresent(Int.self, forKey: .bestScore) ?? 0
        let totalScore = try container.decodeIfPresent(Int.self, forKey: .totalScore) ?? 0
        let elo = try container.decodeIfPresent(Int.self, forKey: .elo) ?? 1200
        let bread = try container.decodeIfPresent(Int.self, forKey: .bread) ?? 0
        let totalBreadCollected = try container.decodeIfPresent(Int.self, forKey: .totalBreadCollected) ?? 0
        let recentScores = try container.decodeIfPresent([Int].self, forKey: .recentScores) ?? []
        let beatenBots = try container.decodeIfPresent([String].self, forKey: .beatenBots) ?? []
        let winStreak = try container.decodeIfPresent(Int.self, forKey: .winStreak) ?? 0
        let bestWinStreak = PlayerStats.normalizedBestWinStreak(
            winStreak: winStreak,
            bestWinStreak: try container.decodeIfPresent(Int.self, forKey: .bestWinStreak)
        )

        self.init(
            username: username,
            stats: PlayerStats(
                gamesPlayed: gamesPlayed,
                wins: wins,
                losses: losses,
                bestScore: bestScore,
                totalScore: totalScore,
                elo: elo,
                bread: bread,
                totalBreadCollected: totalBreadCollected,
                recentScores: recentScores,
                beatenBots: beatenBots,
                peakElo: PlayerStats.normalizedPeakElo(
                    elo: elo,
                    peakElo: try container.decodeIfPresent(Int.self, forKey: .peakElo)
                ),
                winStreak: winStreak,
                bestWinStreak: bestWinStreak
            )
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(username, forKey: .username)
        try container.encode(gamesPlayed, forKey: .gamesPlayed)
        try container.encode(wins, forKey: .wins)
        try container.encode(losses, forKey: .losses)
        try container.encode(bestScore, forKey: .bestScore)
        try container.encode(totalScore, forKey: .totalScore)
        try container.encode(elo, forKey: .elo)
        try container.encode(bread, forKey: .bread)
        try container.encode(totalBreadCollected, forKey: .totalBreadCollected)
        try container.encode(recentScores, forKey: .recentScores)
        try container.encode(beatenBots, forKey: .beatenBots)
        try container.encode(peakElo, forKey: .peakElo)
        try container.encode(winStreak, forKey: .winStreak)
        try container.encode(bestWinStreak, forKey: .bestWinStreak)
    }

    var asPlayerStats: PlayerStats {
        PlayerStats(
            gamesPlayed: gamesPlayed,
            wins: wins,
            losses: losses,
            bestScore: bestScore,
            totalScore: totalScore,
            elo: elo,
            bread: bread,
            totalBreadCollected: totalBreadCollected,
            recentScores: recentScores,
            beatenBots: beatenBots,
            peakElo: peakElo,
            winStreak: winStreak,
            bestWinStreak: bestWinStreak
        )
    }
}

struct RemotePlayerProfile: Hashable, Codable {
    let userId: String
    let username: String
    let provider: AuthProvider
    let stats: PlayerStats
}

struct AuthBootstrapResponse: Hashable, Codable {
    let profile: RemotePlayerProfile
    let didMergeStats: Bool
}

struct AuthLinkResponse: Hashable, Codable {
    let profile: RemotePlayerProfile
    let sessionToken: String
    let sessionExpiresAt: Date?
    let appleUserId: String?
    let didMergeStats: Bool
}

enum AuthError: LocalizedError {
    case canceled
    case missingIdentityToken
    case invalidIdentityToken
    case signInFailed(String)

    var errorDescription: String? {
        switch self {
        case .canceled:
            return "Sign in canceled."
        case .missingIdentityToken:
            return "Missing Apple identity token."
        case .invalidIdentityToken:
            return "Invalid Apple identity token."
        case .signInFailed(let message):
            return message
        }
    }
}

// MARK: - Announcements (CMS)

struct Announcement: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let body: [String]
    let color: String

    var colorValue: Color {
        Color(hexString: color) ?? GK.Colors.buttonGreen
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
    let opponentSkinId: String?
    let gameKitSessionCode: String?
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
    let opponentSkinId: String?
    var didWin: Bool? = nil
    var didDraw: Bool? = nil
    var ratingDelta: Int? = nil
    var newRating: Int? = nil
    var isRanked: Bool? = nil

    func finalizedResult(mode: MatchmakingMode,
                         fallbackOpponentName: String?) -> MultiplayerMatchResult? {
        guard isFinished else { return nil }

        let resolvedDidDraw = didDraw ?? (localScore == opponentScore)
        let resolvedDidWin = didWin ?? (localScore > opponentScore)

        return MultiplayerMatchResult(
            matchId: matchId,
            mode: mode,
            opponentName: opponentName ?? fallbackOpponentName ?? "OPPONENT",
            localScore: localScore,
            opponentScore: opponentScore,
            didWin: resolvedDidWin,
            didDraw: resolvedDidDraw,
            ratingDelta: ratingDelta,
            newRating: newRating,
            isRanked: isRanked ?? mode.isRanked,
            isFinalized: true
        )
    }
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
    var isFinalized: Bool = true
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

    var pixelIcon: PixelIcon? {
        switch self {
        case .none:     return nil
        case .bronze:   return .medalBronze
        case .silver:   return .medalSilver
        case .gold:     return .medalGold
        case .platinum: return .medalPlatinum
        }
    }

    var themeColor: Color {
        switch self {
        case .none:     return .white
        case .bronze:   return Color(red: 0.80, green: 0.50, blue: 0.20)
        case .silver:   return Color(red: 0.75, green: 0.75, blue: 0.80)
        case .gold:     return Color(red: 1.0, green: 0.84, blue: 0.0)
        case .platinum: return Color(red: 0.55, green: 0.80, blue: 1.0)
        }
    }
}

// MARK: - Leaderboard

struct LeaderboardEntry: Identifiable, Codable, Hashable {
    let id: String
    let username: String
    let rating: Int
    let rank: Int
}

// MARK: - Stats

struct PlayerStats: Codable, Hashable {
    var gamesPlayed: Int = 0
    var wins: Int = 0
    var losses: Int = 0
    var bestScore: Int = 0
    var totalScore: Int = 0
    var elo: Int = 1200
    var bread: Int = 0
    var totalBreadCollected: Int = 0  // lifetime total (never decremented)
    var recentScores: [Int] = []  // last 20
    var beatenBots: [String] = [] // ids of beaten bot ladder bots
    var peakElo: Int = 1200       // all-time highest elo
    var winStreak: Int = 0        // current consecutive wins
    var bestWinStreak: Int = 0    // best ever win streak

    enum CodingKeys: String, CodingKey {
        case gamesPlayed
        case wins
        case losses
        case bestScore
        case totalScore
        case elo
        case bread
        case totalBreadCollected
        case recentScores
        case beatenBots
        case peakElo
        case winStreak
        case bestWinStreak
    }

    init(gamesPlayed: Int = 0,
         wins: Int = 0,
         losses: Int = 0,
         bestScore: Int = 0,
         totalScore: Int = 0,
         elo: Int = 1200,
         bread: Int = 0,
         totalBreadCollected: Int = 0,
         recentScores: [Int] = [],
         beatenBots: [String] = [],
         peakElo: Int = 1200,
         winStreak: Int = 0,
         bestWinStreak: Int = 0) {
        self.gamesPlayed = gamesPlayed
        self.wins = wins
        self.losses = losses
        self.bestScore = bestScore
        self.totalScore = totalScore
        self.elo = elo
        self.bread = bread
        self.totalBreadCollected = totalBreadCollected
        self.recentScores = recentScores
        self.beatenBots = beatenBots
        self.peakElo = Self.normalizedPeakElo(elo: elo, peakElo: peakElo)
        self.winStreak = winStreak
        self.bestWinStreak = Self.normalizedBestWinStreak(
            winStreak: winStreak,
            bestWinStreak: bestWinStreak
        )
    }

    static func normalizedPeakElo(elo: Int, peakElo: Int?) -> Int {
        max(elo, peakElo ?? elo)
    }

    static func normalizedBestWinStreak(winStreak: Int, bestWinStreak: Int?) -> Int {
        max(winStreak, bestWinStreak ?? winStreak)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let gamesPlayed = try container.decodeIfPresent(Int.self, forKey: .gamesPlayed) ?? 0
        let wins = try container.decodeIfPresent(Int.self, forKey: .wins) ?? 0
        let losses = try container.decodeIfPresent(Int.self, forKey: .losses) ?? 0
        let bestScore = try container.decodeIfPresent(Int.self, forKey: .bestScore) ?? 0
        let totalScore = try container.decodeIfPresent(Int.self, forKey: .totalScore) ?? 0
        let elo = try container.decodeIfPresent(Int.self, forKey: .elo) ?? 1200
        let bread = try container.decodeIfPresent(Int.self, forKey: .bread) ?? 0
        let totalBreadCollected = try container.decodeIfPresent(Int.self, forKey: .totalBreadCollected) ?? 0
        let recentScores = try container.decodeIfPresent([Int].self, forKey: .recentScores) ?? []
        let beatenBots = try container.decodeIfPresent([String].self, forKey: .beatenBots) ?? []
        let winStreak = try container.decodeIfPresent(Int.self, forKey: .winStreak) ?? 0

        self.init(
            gamesPlayed: gamesPlayed,
            wins: wins,
            losses: losses,
            bestScore: bestScore,
            totalScore: totalScore,
            elo: elo,
            bread: bread,
            totalBreadCollected: totalBreadCollected,
            recentScores: recentScores,
            beatenBots: beatenBots,
            peakElo: Self.normalizedPeakElo(
                elo: elo,
                peakElo: try container.decodeIfPresent(Int.self, forKey: .peakElo)
            ),
            winStreak: winStreak,
            bestWinStreak: Self.normalizedBestWinStreak(
                winStreak: winStreak,
                bestWinStreak: try container.decodeIfPresent(Int.self, forKey: .bestWinStreak)
            )
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(gamesPlayed, forKey: .gamesPlayed)
        try container.encode(wins, forKey: .wins)
        try container.encode(losses, forKey: .losses)
        try container.encode(bestScore, forKey: .bestScore)
        try container.encode(totalScore, forKey: .totalScore)
        try container.encode(elo, forKey: .elo)
        try container.encode(bread, forKey: .bread)
        try container.encode(totalBreadCollected, forKey: .totalBreadCollected)
        try container.encode(recentScores, forKey: .recentScores)
        try container.encode(beatenBots, forKey: .beatenBots)
        try container.encode(peakElo, forKey: .peakElo)
        try container.encode(winStreak, forKey: .winStreak)
        try container.encode(bestWinStreak, forKey: .bestWinStreak)
    }

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
                winStreak += 1
                if winStreak > bestWinStreak { bestWinStreak = winStreak }
                bread += max(3, score)
            } else {
                losses += 1
                winStreak = 0
                bread += max(1, score / 2)
            }
        } else {
            bread += max(1, score)
        }
    }

    /// Records bread collected from a single game into lifetime total.
    mutating func addBreadCollected(_ amount: Int) {
        totalBreadCollected += amount
    }

    mutating func applyMatchResult(_ result: MultiplayerMatchResult) {
        guard result.isFinalized else { return }

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
            if elo > peakElo { peakElo = elo }
        }
    }

    mutating func beatBot(_ botId: String) {
        if !beatenBots.contains(botId) {
            beatenBots.append(botId)
        }
    }
}
