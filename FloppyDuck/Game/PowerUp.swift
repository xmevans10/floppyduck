import SpriteKit
import SwiftUI

// MARK: - Power-Up Types

/// Collectible items that spawn in pipe gaps during gameplay.
/// Power-ups grant temporary buffs; weaknesses impose temporary debuffs.
enum PowerUpKind: String, CaseIterable {
    // Power-ups (positive)
    case shield      // Absorbs one collision
    case slowMo      // Reduces pipe speed by 35% for 4 seconds
    case miniDuck    // Shrinks hitbox by 35% for 5 seconds
    case breadMagnet // 3× bread multiplier for next 5 pipes

    // Weaknesses (negative)
    case heavyWings  // Gravity +40% for 4 seconds
    case windGust    // Random horizontal push for 3 seconds
    case fatDuck     // Hitbox +40% for 4 seconds

    var isPositive: Bool {
        switch self {
        case .shield, .slowMo, .miniDuck, .breadMagnet:
            return true
        case .heavyWings, .windGust, .fatDuck:
            return false
        }
    }

    var displayName: String {
        switch self {
        case .shield:      return "SHIELD"
        case .slowMo:      return "SLOW-MO"
        case .miniDuck:    return "MINI"
        case .breadMagnet: return "BREAD x3"
        case .heavyWings:  return "HEAVY"
        case .windGust:    return "WIND"
        case .fatDuck:     return "THICC"
        }
    }

    var emoji: String {
        switch self {
        case .shield:      return "🛡️"
        case .slowMo:      return "⏳"
        case .miniDuck:    return "🔬"
        case .breadMagnet: return "🍞"
        case .heavyWings:  return "🪨"
        case .windGust:    return "💨"
        case .fatDuck:     return "🎈"
        }
    }

    /// Duration in seconds (0 = instant/permanent until consumed).
    var duration: TimeInterval {
        switch self {
        case .shield:      return 0     // until hit
        case .slowMo:      return 4.0
        case .miniDuck:    return 5.0
        case .breadMagnet: return 0     // next 5 pipes
        case .heavyWings:  return 4.0
        case .windGust:    return 3.0
        case .fatDuck:     return 4.0
        }
    }

    /// Spawn probability weight (higher = more likely).
    var spawnWeight: Double {
        switch self {
        case .shield:      return 1.0
        case .slowMo:      return 1.5
        case .miniDuck:    return 1.2
        case .breadMagnet: return 2.0
        case .heavyWings:  return 1.8
        case .windGust:    return 1.5
        case .fatDuck:     return 1.2
        }
    }

    /// Particle color for the collectible glow.
    var glowColor: UIColor {
        switch self {
        case .shield:      return UIColor(red: 0.3, green: 0.7, blue: 1.0, alpha: 1)
        case .slowMo:      return UIColor(red: 0.5, green: 0.9, blue: 0.5, alpha: 1)
        case .miniDuck:    return UIColor(red: 0.8, green: 0.5, blue: 1.0, alpha: 1)
        case .breadMagnet: return UIColor(red: 0.85, green: 0.68, blue: 0.3, alpha: 1)
        case .heavyWings:  return UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
        case .windGust:    return UIColor(red: 0.7, green: 0.85, blue: 0.95, alpha: 1)
        case .fatDuck:     return UIColor(red: 1.0, green: 0.4, blue: 0.4, alpha: 1)
        }
    }

    /// SpriteKit node size for the collectible.
    static let collectibleSize: CGFloat = 24
}

// MARK: - Active Power-Up State

/// Tracks an active (collected) power-up effect.
struct ActivePowerUp: Identifiable {
    let id = UUID()
    let kind: PowerUpKind
    let startTime: TimeInterval
    var remainingPipes: Int?   // for breadMagnet

    var isTimeBased: Bool { kind.duration > 0 }

    func isExpired(currentTime: TimeInterval) -> Bool {
        if let remaining = remainingPipes {
            return remaining <= 0
        }
        guard kind.duration > 0 else { return false }  // shield never expires by time
        return currentTime - startTime >= kind.duration
    }

    /// Progress 0→1 for UI display (1 = just started, 0 = about to expire).
    func progress(currentTime: TimeInterval) -> CGFloat {
        guard kind.duration > 0 else { return 1.0 }
        let elapsed = currentTime - startTime
        return max(0, 1.0 - CGFloat(elapsed / kind.duration))
    }
}

// MARK: - Power-Up Spawn Manager

/// Controls when and which power-ups spawn in pipe gaps.
final class PowerUpSpawnManager {
    /// Minimum pipes between power-up spawns.
    private let minSpawnInterval: Int = 4
    /// Maximum pipes between power-up spawns.
    private let maxSpawnInterval: Int = 8

    private var pipesUntilNextSpawn: Int
    private var lastSpawnedKind: PowerUpKind?

    init() {
        pipesUntilNextSpawn = Int.random(in: 3...6)  // first spawn comes early
    }

    /// Called each time a pipe is scored. Returns a PowerUpKind to spawn, or nil.
    func onPipeScored(currentScore: Int, tier: DifficultyTier) -> PowerUpKind? {
        pipesUntilNextSpawn -= 1
        guard pipesUntilNextSpawn <= 0 else { return nil }

        // Reset countdown
        pipesUntilNextSpawn = Int.random(in: minSpawnInterval...maxSpawnInterval)

        // Choose a power-up using weighted random selection
        let kind = weightedRandomPowerUp(tier: tier)
        lastSpawnedKind = kind
        return kind
    }

    /// Reset for a new game.
    func reset() {
        pipesUntilNextSpawn = Int.random(in: 3...6)
        lastSpawnedKind = nil
    }

    // MARK: - Weighted Random

    private func weightedRandomPowerUp(tier: DifficultyTier) -> PowerUpKind {
        // At higher tiers, weaknesses become more common
        let weaknessBoost: Double = {
            switch tier {
            case .easy:   return 0.3
            case .medium: return 0.7
            case .hard:   return 1.0
            case .expert: return 1.3
            }
        }()

        var weights: [(PowerUpKind, Double)] = PowerUpKind.allCases.map { kind in
            var w = kind.spawnWeight
            if !kind.isPositive {
                w *= weaknessBoost
            }
            // Don't spawn the same kind twice in a row
            if kind == lastSpawnedKind {
                w *= 0.3
            }
            return (kind, w)
        }

        // Don't spawn shield at easy tier (too generous early)
        if tier == .easy {
            weights = weights.map { ($0.0, $0.0 == .shield ? 0 : $0.1) }
        }

        let totalWeight = weights.reduce(0.0) { $0 + $1.1 }
        guard totalWeight > 0 else { return .breadMagnet }

        var roll = Double.random(in: 0..<totalWeight)
        for (kind, weight) in weights {
            roll -= weight
            if roll <= 0 { return kind }
        }

        return weights.last?.0 ?? .breadMagnet
    }
}
