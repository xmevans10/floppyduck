import Foundation
import SwiftUI

// MARK: - Achievement Definition

enum AchievementId: String, CaseIterable, Codable {
    // Score milestones
    case firstFlight      // Score 1 point
    case gettingStarted   // Score 10 in one game
    case pipeHero         // Score 25 in one game
    case skyMaster        // Score 50 in one game
    case legendary        // Score 100 in one game

    // Cumulative
    case breadWinner      // Collect 100 bread total
    case breadBaron       // Collect 1000 bread total
    case marathon         // Play 50 games
    case dedicated        // Play 100 games
    case veteran          // Play 500 games

    // Bot ladder
    case botSlayer        // Beat first bot
    case ladderClimber    // Beat 4 bots
    case topDuck          // Beat all 8 bots

    // Power-ups
    case shieldBreaker    // Use 10 shields total
    case ghostRider       // Phase through 5 pipes in one ghost duck
    case magnetMogul      // Collect 50 bread with magnet active

    // Streaks
    case streakStarter    // 3 day play streak
    case committed        // 7 day play streak
    case obsessed         // 30 day play streak

    // Special
    case survivalist      // Survive a debuff and score 5 more
    case collector        // Own 5 skins
    case fashionista      // Own all skins

    // Multiplayer
    case socialDuck           // Play a private room match
    case competitiveSpirit    // Play your first ranked match
    case winStreak3           // Win 3 multiplayer matches in a row
    case winStreak5           // Win 5 multiplayer matches in a row
    case rankedRookie         // Play 10 ranked matches
    case rankedVeteran        // Play 50 ranked matches
    case eloPro               // Reach 1500 ELO
    case eloElite             // Reach 2000 ELO
    case drawGame             // Draw a match
    case winFarmer            // Win 25 head-to-head matches

    // MARK: - Display Properties

    var title: String {
        switch self {
        case .firstFlight:    return "First Flight"
        case .gettingStarted: return "Getting Started"
        case .pipeHero:       return "Pipe Hero"
        case .skyMaster:      return "Sky Master"
        case .legendary:      return "Legendary"
        case .breadWinner:    return "Bread Winner"
        case .breadBaron:     return "Bread Baron"
        case .marathon:       return "Marathon"
        case .dedicated:      return "Dedicated"
        case .veteran:        return "Veteran"
        case .botSlayer:      return "Bot Slayer"
        case .ladderClimber:  return "Ladder Climber"
        case .topDuck:        return "Top Duck"
        case .shieldBreaker:  return "Shield Breaker"
        case .ghostRider:     return "Ghost Rider"
        case .magnetMogul:    return "Magnet Mogul"
        case .streakStarter:  return "Streak Starter"
        case .committed:      return "Committed"
        case .obsessed:       return "Obsessed"
        case .survivalist:       return "Survivalist"
        case .collector:         return "Collector"
        case .fashionista:       return "Fashionista"
        case .socialDuck:        return "Social Duck"
        case .competitiveSpirit: return "Competitive Spirit"
        case .winStreak3:        return "Heating Up"
        case .winStreak5:        return "On Fire"
        case .rankedRookie:      return "Ranked Rookie"
        case .rankedVeteran:     return "Ranked Veteran"
        case .eloPro:            return "ELO Pro"
        case .eloElite:          return "ELO Elite"
        case .drawGame:          return "Stalemate"
        case .winFarmer:         return "Win Farmer"
        }
    }

    var description: String {
        switch self {
        case .firstFlight:    return "Score your first point"
        case .gettingStarted: return "Score 10 in a single game"
        case .pipeHero:       return "Score 25 in a single game"
        case .skyMaster:      return "Score 50 in a single game"
        case .legendary:      return "Score 100 in a single game"
        case .breadWinner:    return "Collect 100 bread total"
        case .breadBaron:     return "Collect 1,000 bread total"
        case .marathon:       return "Play 50 games"
        case .dedicated:      return "Play 100 games"
        case .veteran:        return "Play 500 games"
        case .botSlayer:      return "Beat your first bot"
        case .ladderClimber:  return "Beat 4 bots on the ladder"
        case .topDuck:        return "Beat all 8 bots on the ladder"
        case .shieldBreaker:  return "Use 10 shields total"
        case .ghostRider:     return "Phase through 5 pipes in one ghost duck"
        case .magnetMogul:    return "Collect 50 bread with magnet active"
        case .streakStarter:  return "Play 3 days in a row"
        case .committed:      return "Play 7 days in a row"
        case .obsessed:       return "Play 30 days in a row"
        case .survivalist:    return "Survive a debuff and score 5 more points"
        case .collector:      return "Own 5 skins"
        case .fashionista:    return "Own all skins"
        case .socialDuck:        return "Play a private room match"
        case .competitiveSpirit: return "Play your first ranked match"
        case .winStreak3:        return "Win 3 matches in a row"
        case .winStreak5:        return "Win 5 matches in a row"
        case .rankedRookie:      return "Play 10 ranked matches"
        case .rankedVeteran:     return "Play 50 ranked matches"
        case .eloPro:            return "Reach 1500 ELO"
        case .eloElite:          return "Reach 2000 ELO"
        case .drawGame:          return "Draw a match"
        case .winFarmer:         return "Win 25 head-to-head matches"
        }
    }

    var pixelIcon: PixelIcon {
        switch self {
        case .firstFlight:    return .chick
        case .gettingStarted: return .duck
        case .pipeHero:       return .star
        case .skyMaster:      return .crown
        case .legendary:      return .crown
        case .breadWinner:    return .bread
        case .breadBaron:     return .bread
        case .marathon:       return .ribbon
        case .dedicated:      return .muscle
        case .veteran:        return .ribbon
        case .botSlayer:      return .swords
        case .ladderClimber:  return .ladder
        case .topDuck:        return .trophy
        case .shieldBreaker:  return .shield
        case .ghostRider:     return .ghost
        case .magnetMogul:    return .breadMagnet
        case .streakStarter:  return .flame
        case .committed:      return .calendar
        case .obsessed:       return .flame
        case .survivalist:    return .skull
        case .collector:      return .palette
        case .fashionista:    return .palette
        case .socialDuck:        return .share
        case .competitiveSpirit: return .trophy
        case .winStreak3:        return .flame
        case .winStreak5:        return .flame
        case .rankedRookie:      return .ribbon
        case .rankedVeteran:     return .ribbon
        case .eloPro:            return .star
        case .eloElite:          return .crown
        case .drawGame:          return .checkmark
        case .winFarmer:         return .swords
        }
    }

    /// Bread reward for unlocking (10 for easy → 500 for hard).
    var breadReward: Int {
        switch self {
        case .firstFlight:    return 10
        case .gettingStarted: return 25
        case .pipeHero:       return 50
        case .skyMaster:      return 150
        case .legendary:      return 500
        case .breadWinner:    return 25
        case .breadBaron:     return 200
        case .marathon:       return 50
        case .dedicated:      return 100
        case .veteran:        return 300
        case .botSlayer:      return 25
        case .ladderClimber:  return 100
        case .topDuck:        return 500
        case .shieldBreaker:  return 50
        case .ghostRider:     return 100
        case .magnetMogul:    return 75
        case .streakStarter:  return 25
        case .committed:      return 75
        case .obsessed:       return 400
        case .survivalist:    return 100
        case .collector:      return 50
        case .fashionista:    return 300
        case .socialDuck:        return 25
        case .competitiveSpirit: return 50
        case .winStreak3:        return 75
        case .winStreak5:        return 150
        case .rankedRookie:      return 100
        case .rankedVeteran:     return 250
        case .eloPro:            return 150
        case .eloElite:          return 500
        case .drawGame:          return 50
        case .winFarmer:         return 200
        }
    }

    /// Secret achievements are hidden until unlocked.
    var isSecret: Bool {
        switch self {
        case .legendary, .topDuck, .obsessed, .fashionista, .rankedVeteran, .eloElite:
            return true
        default:
            return false
        }
    }
}

// MARK: - Achievement Events

enum AchievementEvent {
    case gameEnded(score: Int)
    case breadCollected(total: Int)
    case botBeaten(totalBeaten: Int)
    case shieldUsed
    case ghostPipePhased
    case magnetBreadCollected(count: Int)
    case debuffSurvivedWithScore(extraPoints: Int)
    case streakUpdated(days: Int)
    case skinPurchased(totalOwned: Int)
    case privateRoomMatch
    case rankedMatch
    case matchWinStreak(streak: Int)
    case ratingUpdated(elo: Int, peakElo: Int)
    case matchDraw
    case h2hWin(total: Int)
}

// MARK: - Achievement Progress

struct AchievementProgress: Codable, Equatable {
    var unlocked: Set<AchievementId> = []
    var shieldsUsed: Int = 0
    var ghostPipesPhased: Int = 0
    var magnetBreadCollected: Int = 0
    var debuffSurvivalScore: Int? = nil  // tracks score when debuff started
    var h2hWins: Int = 0
    var rankedMatches: Int = 0
    var draws: Int = 0

    // MARK: - Check & Unlock

    /// Checks all relevant achievements for the given event and returns newly-unlocked IDs.
    mutating func check(event: AchievementEvent, stats: PlayerStats, skinsOwned: Int) -> [AchievementId] {
        var newlyUnlocked: [AchievementId] = []

        switch event {
        case .gameEnded(let score):
            // Score milestones
            if score >= 1   { newlyUnlocked.append(contentsOf: tryUnlock(.firstFlight)) }
            if score >= 10  { newlyUnlocked.append(contentsOf: tryUnlock(.gettingStarted)) }
            if score >= 25  { newlyUnlocked.append(contentsOf: tryUnlock(.pipeHero)) }
            if score >= 50  { newlyUnlocked.append(contentsOf: tryUnlock(.skyMaster)) }
            if score >= 100 { newlyUnlocked.append(contentsOf: tryUnlock(.legendary)) }

            // Cumulative games
            if stats.gamesPlayed >= 50  { newlyUnlocked.append(contentsOf: tryUnlock(.marathon)) }
            if stats.gamesPlayed >= 100 { newlyUnlocked.append(contentsOf: tryUnlock(.dedicated)) }
            if stats.gamesPlayed >= 500 { newlyUnlocked.append(contentsOf: tryUnlock(.veteran)) }

        case .breadCollected(let total):
            if total >= 100  { newlyUnlocked.append(contentsOf: tryUnlock(.breadWinner)) }
            if total >= 1000 { newlyUnlocked.append(contentsOf: tryUnlock(.breadBaron)) }

        case .botBeaten(let totalBeaten):
            if totalBeaten >= 1 { newlyUnlocked.append(contentsOf: tryUnlock(.botSlayer)) }
            if totalBeaten >= 4 { newlyUnlocked.append(contentsOf: tryUnlock(.ladderClimber)) }
            if totalBeaten >= 8 { newlyUnlocked.append(contentsOf: tryUnlock(.topDuck)) }

        case .shieldUsed:
            shieldsUsed += 1
            if shieldsUsed >= 10 { newlyUnlocked.append(contentsOf: tryUnlock(.shieldBreaker)) }

        case .ghostPipePhased:
            ghostPipesPhased += 1
            if ghostPipesPhased >= 5 { newlyUnlocked.append(contentsOf: tryUnlock(.ghostRider)) }

        case .magnetBreadCollected(let count):
            magnetBreadCollected += count
            if magnetBreadCollected >= 50 { newlyUnlocked.append(contentsOf: tryUnlock(.magnetMogul)) }

        case .debuffSurvivedWithScore(let extraPoints):
            if extraPoints >= 5 { newlyUnlocked.append(contentsOf: tryUnlock(.survivalist)) }

        case .streakUpdated(let days):
            if days >= 3  { newlyUnlocked.append(contentsOf: tryUnlock(.streakStarter)) }
            if days >= 7  { newlyUnlocked.append(contentsOf: tryUnlock(.committed)) }
            if days >= 30 { newlyUnlocked.append(contentsOf: tryUnlock(.obsessed)) }

        case .skinPurchased(let totalOwned):
            if totalOwned >= 5 { newlyUnlocked.append(contentsOf: tryUnlock(.collector)) }
            // Total skins in DuckSkin.allCases — fashionista requires owning all
            let totalSkins = DuckSkin.allCases.count
            if totalOwned >= totalSkins { newlyUnlocked.append(contentsOf: tryUnlock(.fashionista)) }

        case .privateRoomMatch:
            newlyUnlocked.append(contentsOf: tryUnlock(.socialDuck))

        case .rankedMatch:
            rankedMatches += 1
            newlyUnlocked.append(contentsOf: tryUnlock(.competitiveSpirit))
            if rankedMatches >= 10 { newlyUnlocked.append(contentsOf: tryUnlock(.rankedRookie)) }
            if rankedMatches >= 50 { newlyUnlocked.append(contentsOf: tryUnlock(.rankedVeteran)) }

        case .matchWinStreak(let streak):
            if streak >= 3 { newlyUnlocked.append(contentsOf: tryUnlock(.winStreak3)) }
            if streak >= 5 { newlyUnlocked.append(contentsOf: tryUnlock(.winStreak5)) }

        case .ratingUpdated(let elo, let peakElo):
            let effective = max(elo, peakElo)
            if effective >= 1500 { newlyUnlocked.append(contentsOf: tryUnlock(.eloPro)) }
            if effective >= 2000 { newlyUnlocked.append(contentsOf: tryUnlock(.eloElite)) }

        case .matchDraw:
            draws += 1
            if draws >= 1 { newlyUnlocked.append(contentsOf: tryUnlock(.drawGame)) }

        case .h2hWin(let total):
            h2hWins = total
            if h2hWins >= 25 { newlyUnlocked.append(contentsOf: tryUnlock(.winFarmer)) }
        }

        return newlyUnlocked
    }

    /// Attempts to unlock an achievement. Returns an array containing the ID if newly unlocked, empty otherwise.
    private mutating func tryUnlock(_ id: AchievementId) -> [AchievementId] {
        guard !unlocked.contains(id) else { return [] }
        unlocked.insert(id)
        return [id]
    }

    /// Reset ghost pipe counter (called when ghost duck expires or new ghost starts).
    mutating func resetGhostPipesPhased() {
        ghostPipesPhased = 0
    }

    /// Total bread earned from achievements.
    var totalBreadFromAchievements: Int {
        unlocked.reduce(0) { $0 + $1.breadReward }
    }
}

// MARK: - Achievement Manager (persistence & event handling)

@MainActor
final class AchievementManager {
    static let shared = AchievementManager()

    private let storageKey: String
    private let playerStatsKey = "playerStats"
    private let userDefaults: UserDefaults
    private weak var gameManager: GameManager?

    private(set) var progress: AchievementProgress

    init(userDefaults: UserDefaults = .standard,
         storageKey: String = "achievementProgress") {
        self.userDefaults = userDefaults
        self.storageKey = storageKey

        if let data = userDefaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(AchievementProgress.self, from: data) {
            progress = decoded
        } else {
            progress = AchievementProgress()
        }
    }

    func register(gameManager: GameManager) {
        self.gameManager = gameManager
    }

    /// Save current progress to UserDefaults.
    func save() {
        if let data = try? JSONEncoder().encode(progress) {
            userDefaults.set(data, forKey: storageKey)
        }
    }

    /// Process an achievement event. Returns newly unlocked achievement IDs (empty if none).
    /// Automatically saves progress and awards bread for new unlocks.
    @discardableResult
    func process(event: AchievementEvent, stats: PlayerStats, skinsOwned: Int, manager: GameManager? = nil) -> [AchievementId] {
        let previousProgress = progress
        let newlyUnlocked = progress.check(event: event, stats: stats, skinsOwned: skinsOwned)

        if !newlyUnlocked.isEmpty {
            // Award bread for each newly unlocked achievement
            let breadEarned = newlyUnlocked.reduce(0) { $0 + $1.breadReward }
            awardBread(breadEarned, manager: manager ?? gameManager)
        }

        if progress != previousProgress {
            save()
        }

        return newlyUnlocked
    }

    /// Reset all achievement progress (for "Reset All Stats").
    func reset() {
        progress = AchievementProgress()
        save()
    }

    private func awardBread(_ amount: Int, manager: GameManager?) {
        guard amount > 0 else { return }

        if let manager {
            manager.awardAchievementBread(amount)
            return
        }

        var storedStats: PlayerStats
        if let data = userDefaults.data(forKey: playerStatsKey),
           let decoded = try? JSONDecoder().decode(PlayerStats.self, from: data) {
            storedStats = decoded
        } else {
            storedStats = PlayerStats()
        }

        storedStats.bread += amount

        if let data = try? JSONEncoder().encode(storedStats) {
            userDefaults.set(data, forKey: playerStatsKey)
        }
    }
}
