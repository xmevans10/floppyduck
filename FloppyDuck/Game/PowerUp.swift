import SpriteKit
import SwiftUI

// MARK: - Power-Up Types

/// Collectible items that spawn in pipe gaps during gameplay.
/// Power-ups grant temporary buffs; debuffs impose temporary penalties.
enum PowerUpKind: String, CaseIterable {
    // Power-ups (positive)
    case shield        // Absorbs one pipe collision
    case pipeExpander  // Widens gap for next 3 pipes by 30%
    case breadMagnet   // Attracts bread collectibles within larger radius for next 5 pipes
    case slowMotion    // Reduces pipe speed by 35% for 5 seconds
    case ghostDuck     // Phase through pipes for 3 seconds
    case doublePoints  // Score 2× per pipe for next 5 pipes

    // Debuffs (negative)
    case pipeSqueeze   // Narrows gap for next 3 pipes by 16%
    case speedBurst    // Pipes 40% faster for 5 seconds
    case dizzyDuck     // Controls invert for 3 seconds
    case heavyDuck     // Gravity +50% for 4 seconds — duck drops faster
    case jumboDuck     // Duck grows 150% for 4 seconds — bigger hitbox

    // More power-ups
    case tinyDuck      // Duck shrinks to 50% for 5 seconds — tiny hitbox
    case megaFlap      // Flap impulse +30% for next pipe — super bouncy

    var isPositive: Bool {
        switch self {
        case .shield, .pipeExpander, .breadMagnet, .slowMotion, .ghostDuck, .doublePoints,
             .tinyDuck, .megaFlap:
            return true
        case .pipeSqueeze, .speedBurst, .dizzyDuck, .heavyDuck, .jumboDuck:
            return false
        }
    }

    var displayName: String {
        switch self {
        case .shield:       return "SHIELD"
        case .pipeExpander: return "EXPAND"
        case .breadMagnet:  return "MAGNET"
        case .slowMotion:   return "SLOW-MO"
        case .ghostDuck:    return "GHOST"
        case .doublePoints: return "2× PTS"
        case .pipeSqueeze:  return "SQUEEZE"
        case .speedBurst:   return "SPEED!"
        case .dizzyDuck:    return "DIZZY"
        case .heavyDuck:    return "HEAVY"
        case .jumboDuck:    return "JUMBO"
        case .tinyDuck:     return "TINY"
        case .megaFlap:     return "MEGA"
        }
    }

    var pixelIcon: PixelIcon {
        switch self {
        case .shield:       return .shield
        case .pipeExpander: return .pipeExpander
        case .breadMagnet:  return .breadMagnet
        case .slowMotion:   return .slowMotion
        case .ghostDuck:    return .ghost
        case .doublePoints: return .doublePoints
        case .pipeSqueeze:  return .pipeSqueeze
        case .speedBurst:   return .speedBurst
        case .dizzyDuck:    return .dizzyDuck
        case .heavyDuck:    return .heavyDuck
        case .jumboDuck:    return .jumboDuck
        case .tinyDuck:     return .tinyDuck
        case .megaFlap:     return .megaFlap
        }
    }

    /// Duration in seconds (0 = instant/permanent until consumed or pipe-count based).
    var duration: TimeInterval {
        switch self {
        case .shield:       return 0      // until hit
        case .pipeExpander: return 0      // next 3 pipes
        case .breadMagnet:  return 0      // next 5 pipes
        case .slowMotion:   return 5.0
        case .ghostDuck:    return 3.0
        case .doublePoints: return 0      // next 5 pipes
        case .pipeSqueeze:  return 0      // next 3 pipes
        case .speedBurst:   return 5.0
        case .dizzyDuck:    return 3.0
        case .heavyDuck:    return 4.0
        case .jumboDuck:    return 4.0
        case .tinyDuck:     return 5.0
        case .megaFlap:     return 0      // next 1 pipe
        }
    }

    /// Initial remaining-pipe count for pipe-count based power-ups, nil otherwise.
    var initialPipeCount: Int? {
        switch self {
        case .pipeExpander: return 3
        case .breadMagnet:  return 5
        case .doublePoints: return 5
        case .pipeSqueeze:  return 3
        case .megaFlap:     return 2
        default:            return nil
        }
    }

    /// Whether this power-up expires by pipe count rather than time.
    var isPipeCountBased: Bool { initialPipeCount != nil }

    /// Spawn probability weight (higher = more likely).
    var spawnWeight: Double {
        switch self {
        case .shield:       return 1.0
        case .pipeExpander: return 1.2
        case .breadMagnet:  return 2.0
        case .slowMotion:   return 1.5
        case .ghostDuck:    return 0.8
        case .doublePoints: return 1.0
        case .pipeSqueeze:  return 1.5
        case .speedBurst:   return 1.2
        case .dizzyDuck:    return 1.0
        case .heavyDuck:    return 1.2
        case .jumboDuck:    return 1.4
        case .tinyDuck:     return 1.6
        case .megaFlap:     return 1.4
        }
    }

    /// Particle color for the collectible glow.
    var glowColor: UIColor {
        switch self {
        case .shield:       return UIColor(red: 0.3, green: 0.7, blue: 1.0, alpha: 1)   // blue
        case .pipeExpander: return UIColor(red: 0.3, green: 0.8, blue: 0.3, alpha: 1)   // green
        case .breadMagnet:  return UIColor(red: 0.85, green: 0.68, blue: 0.3, alpha: 1) // warm gold
        case .slowMotion:   return UIColor(red: 0.5, green: 0.9, blue: 0.5, alpha: 1)   // light green
        case .ghostDuck:    return UIColor(red: 0.9, green: 0.9, blue: 0.95, alpha: 1)  // white/silver
        case .doublePoints: return UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1)  // bright gold
        case .pipeSqueeze:  return UIColor(red: 0.35, green: 0.35, blue: 0.4, alpha: 1) // dark gray
        case .speedBurst:   return UIColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1)   // red
        case .dizzyDuck:    return UIColor(red: 0.7, green: 0.3, blue: 0.9, alpha: 1)   // purple
        case .heavyDuck:    return UIColor(red: 0.5, green: 0.25, blue: 0.1, alpha: 1)  // dark brown
        case .jumboDuck:    return UIColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 1)   // orange
        case .tinyDuck:     return UIColor(red: 0.4, green: 0.8, blue: 1.0, alpha: 1)   // light blue
        case .megaFlap:     return UIColor(red: 1.0, green: 0.7, blue: 0.2, alpha: 1)   // amber
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
    var remainingPipes: Int?   // for pipeExpander, breadMagnet, pipeSqueeze

    var isTimeBased: Bool { kind.duration > 0 }
    var isPipeCountBased: Bool { kind.isPipeCountBased }

    func isExpired(currentTime: TimeInterval) -> Bool {
        if let remaining = remainingPipes {
            return remaining <= 0
        }
        guard kind.duration > 0 else { return false }  // shield never expires by time
        return currentTime - startTime >= kind.duration
    }

    /// Progress 0→1 for UI display (1 = just started, 0 = about to expire).
    func progress(currentTime: TimeInterval) -> CGFloat {
        if let remaining = remainingPipes, let initial = kind.initialPipeCount {
            return CGFloat(remaining) / CGFloat(initial)
        }
        guard kind.duration > 0 else { return 1.0 }
        let elapsed = currentTime - startTime
        return max(0, 1.0 - CGFloat(elapsed / kind.duration))
    }

    /// Whether the power-up is in the "wearing off" warning phase.
    /// Time-based: last 30% of duration. Pipe-count-based: last pipe remaining.
    func isWearingOff(currentTime: TimeInterval) -> Bool {
        if let remaining = remainingPipes {
            return remaining <= 1 && remaining > 0
        }
        guard kind.duration > 0 else { return false }
        let elapsed = currentTime - startTime
        return elapsed >= kind.duration * 0.7 && elapsed < kind.duration
    }
}

// MARK: - Power-Up Spawn Manager

/// Controls when and which power-ups spawn in pipe gaps.
final class PowerUpSpawnManager {
    /// Minimum pipes between power-up spawns.
    private let minSpawnInterval: Int = 1
    /// Maximum pipes between power-up spawns.
    private let maxSpawnInterval: Int = 3

    private var pipesUntilNextSpawn: Int
    private var lastSpawnedKind: PowerUpKind?

    init() {
        pipesUntilNextSpawn = Int.random(in: 1...2)  // first spawn comes early
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
        pipesUntilNextSpawn = Int.random(in: 1...2)
        lastSpawnedKind = nil
    }

    // MARK: - Weighted Random

    private func weightedRandomPowerUp(tier: DifficultyTier) -> PowerUpKind {
        // At higher tiers, debuffs become more common
        let debuffBoost: Double = {
            switch tier {
            case .easy:   return 0.5
            case .medium: return 0.9
            case .hard:   return 1.3
            case .expert: return 1.6
            }
        }()

        var weights: [(PowerUpKind, Double)] = PowerUpKind.allCases.map { kind in
            var w = kind.spawnWeight
            if !kind.isPositive {
                w *= debuffBoost
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
