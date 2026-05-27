import SwiftUI

// MARK: - Battle Banner Purchase Kind

enum BannerPurchaseKind: String, Codable, Hashable {
    case free
    case normal       // Bread currency
    case botReward    // Unlocked by beating a specific bot
    case premium      // Real money IAP
}

// MARK: - Battle Banner Pattern

/// Defines the visual pattern rendered on each player's half of the VS intro screen.
/// Inspired by Clash Royale battle banners — collectible, unlockable, and purchasable.
enum BannerPattern: String, Codable, Hashable {
    case diagonalStripes   // Original default
    case chevrons          // Repeating V shapes
    case diamonds          // Diamond grid
    case zigzag            // Zigzag horizontal bands
    case crosshatch        // Cross-hatched lines
    case hexGrid           // Honeycomb pattern
    case flames            // Rising flame shapes
    case circuit           // Circuit-board traces
    case waves             // Rolling wave lines
    case skulls            // Skull & crossbones repeating (pixel art)
}

// MARK: - Battle Banner

/// A collectible cosmetic for the VS intro screen. Each banner defines a background
/// pattern, primary and secondary colors, and a glow effect for the player's half.
enum BattleBanner: String, CaseIterable, Identifiable, Codable {

    // Free (default banners)
    case classic           // Original diagonal stripes, green/teal
    case crimson           // Red diagonal stripes
    case midnight          // Dark blue chevrons

    // Normal (bread currency)
    case solar             // Orange/gold diamonds
    case toxic             // Neon green zigzag
    case frostbite         // Icy blue crosshatch
    case ultraviolet       // Purple hexagons

    // Bot rewards (unlocked by beating specific bots)
    case ducklingBadge     // Beat Quackers — cute yellow chevrons
    case pirateFlag        // Beat Puddles — skull & crossbones
    case infernoWings      // Beat Goose — flame pattern
    case goldenCrown       // Beat The Duck — gold diamond royalty

    // Premium (IAP)
    case neonTokyo         // Circuit board neon pink/cyan
    case cosmicRift        // Space waves purple/blue

    var id: String { rawValue }

    // MARK: - Display

    var displayName: String {
        switch self {
        case .classic:        return "CLASSIC"
        case .crimson:        return "CRIMSON"
        case .midnight:       return "MIDNIGHT"
        case .solar:          return "SOLAR FLARE"
        case .toxic:          return "TOXIC"
        case .frostbite:      return "FROSTBITE"
        case .ultraviolet:    return "ULTRAVIOLET"
        case .ducklingBadge:  return "DUCKLING"
        case .pirateFlag:     return "JOLLY ROGER"
        case .infernoWings:   return "INFERNO"
        case .goldenCrown:    return "GOLDEN CROWN"
        case .neonTokyo:      return "NEON TOKYO"
        case .cosmicRift:     return "COSMIC RIFT"
        }
    }

    var subtitle: String {
        switch self {
        case .classic:        return "The Original"
        case .crimson:        return "Blood Red"
        case .midnight:       return "Night Ops"
        case .solar:          return "Blinding Light"
        case .toxic:          return "Radioactive"
        case .frostbite:      return "Sub Zero"
        case .ultraviolet:    return "Beyond Visible"
        case .ducklingBadge:  return "Beat Quackers"
        case .pirateFlag:     return "Beat Puddles"
        case .infernoWings:   return "Beat Goose"
        case .goldenCrown:    return "Beat The Duck"
        case .neonTokyo:      return "Digital Dreams"
        case .cosmicRift:     return "Star Stuff"
        }
    }

    // MARK: - Pattern & Colors

    var pattern: BannerPattern {
        switch self {
        case .classic:        return .diagonalStripes
        case .crimson:        return .diagonalStripes
        case .midnight:       return .chevrons
        case .solar:          return .diamonds
        case .toxic:          return .zigzag
        case .frostbite:      return .crosshatch
        case .ultraviolet:    return .hexGrid
        case .ducklingBadge:  return .chevrons
        case .pirateFlag:     return .skulls
        case .infernoWings:   return .flames
        case .goldenCrown:    return .diamonds
        case .neonTokyo:      return .circuit
        case .cosmicRift:     return .waves
        }
    }

    /// Primary color for the banner pattern.
    var primaryColor: Color {
        switch self {
        case .classic:        return Color(red: 0.20, green: 0.70, blue: 0.50)
        case .crimson:        return Color(red: 0.85, green: 0.15, blue: 0.15)
        case .midnight:       return Color(red: 0.12, green: 0.15, blue: 0.40)
        case .solar:          return Color(red: 0.95, green: 0.65, blue: 0.10)
        case .toxic:          return Color(red: 0.20, green: 0.90, blue: 0.20)
        case .frostbite:      return Color(red: 0.40, green: 0.75, blue: 0.95)
        case .ultraviolet:    return Color(red: 0.55, green: 0.20, blue: 0.85)
        case .ducklingBadge:  return Color(red: 0.95, green: 0.85, blue: 0.30)
        case .pirateFlag:     return Color(red: 0.20, green: 0.20, blue: 0.20)
        case .infernoWings:   return Color(red: 0.95, green: 0.35, blue: 0.10)
        case .goldenCrown:    return Color(red: 0.90, green: 0.75, blue: 0.20)
        case .neonTokyo:      return Color(red: 0.90, green: 0.20, blue: 0.60)
        case .cosmicRift:     return Color(red: 0.30, green: 0.15, blue: 0.70)
        }
    }

    /// Secondary color (background base behind the pattern).
    var secondaryColor: Color {
        switch self {
        case .classic:        return Color(red: 0.08, green: 0.30, blue: 0.20)
        case .crimson:        return Color(red: 0.35, green: 0.05, blue: 0.05)
        case .midnight:       return Color(red: 0.05, green: 0.05, blue: 0.18)
        case .solar:          return Color(red: 0.40, green: 0.25, blue: 0.05)
        case .toxic:          return Color(red: 0.05, green: 0.25, blue: 0.05)
        case .frostbite:      return Color(red: 0.10, green: 0.25, blue: 0.40)
        case .ultraviolet:    return Color(red: 0.18, green: 0.05, blue: 0.30)
        case .ducklingBadge:  return Color(red: 0.40, green: 0.35, blue: 0.10)
        case .pirateFlag:     return Color(red: 0.08, green: 0.08, blue: 0.08)
        case .infernoWings:   return Color(red: 0.35, green: 0.10, blue: 0.02)
        case .goldenCrown:    return Color(red: 0.35, green: 0.28, blue: 0.05)
        case .neonTokyo:      return Color(red: 0.15, green: 0.05, blue: 0.20)
        case .cosmicRift:     return Color(red: 0.08, green: 0.04, blue: 0.22)
        }
    }

    /// Glow color used for edge glow and shadow effects.
    var glowColor: Color {
        primaryColor.opacity(0.6)
    }

    /// Asset catalog name for the seamless pattern tile (Kenney CC0).
    var patternTileName: String {
        "pattern_\(rawValue)"
    }

    // MARK: - Purchase

    var purchaseKind: BannerPurchaseKind {
        switch self {
        case .classic, .crimson, .midnight:
            return .free
        case .solar, .toxic, .frostbite, .ultraviolet:
            return .normal
        case .ducklingBadge, .pirateFlag, .infernoWings, .goldenCrown:
            return .botReward
        case .neonTokyo, .cosmicRift:
            return .premium
        }
    }

    var isFree: Bool { purchaseKind == .free }
    var isNormal: Bool { purchaseKind == .normal }
    var isBotReward: Bool { purchaseKind == .botReward }
    var isPremium: Bool { purchaseKind == .premium }

    var breadPrice: Int? {
        switch self {
        case .solar:       return 100   // Tier 1 — cheapest item in the shop
        case .toxic:       return 200   // Tier 1
        case .frostbite:   return 350   // Tier 2
        case .ultraviolet: return 500   // Tier 3
        default:           return nil
        }
    }

    var premiumProductID: String? {
        guard isPremium else { return nil }
        return "com.floppyduck.banner.\(rawValue)"
    }

    var priceDisplay: String {
        switch purchaseKind {
        case .free:      return "FREE"
        case .normal:    return "\(breadPrice ?? 0) BREAD"
        case .botReward: return "BOT REWARD"
        case .premium:   return "$0.99"
        }
    }

    /// The bot ID that must be beaten to unlock this banner (nil if not a bot reward).
    var requiredBotId: String? {
        switch self {
        case .ducklingBadge:  return "quackers"
        case .pirateFlag:     return "puddles"
        case .infernoWings:   return "goose"
        case .goldenCrown:    return "the_duck"
        default:              return nil
        }
    }
}
