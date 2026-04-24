import SwiftUI

// MARK: - Purchase Kind (shared with DuckSkin)

enum ThemePurchaseKind: String, Codable, Hashable {
    case free
    case normal      // Bread currency
    case premium     // Real money IAP
}

// MARK: - Background Theme

/// Selectable background themes for gameplay. Each defines a complete visual palette:
/// sky gradient, ground, cloud tint, and accent color. Purchasable in the shop.
enum BackgroundTheme: String, CaseIterable, Identifiable, Codable {
    // Free (the original three)
    case day
    case sunset
    case night

    // Normal (bread currency)
    case neonCity
    case underwater
    case volcano
    case arctic
    case western
    case jungle
    case cave
    case mountain

    // Premium (IAP)
    case space
    case pixelTokyo
    case egypt

    var id: String { rawValue }

    // MARK: - Display

    var displayName: String {
        switch self {
        case .day:         return "DAY"
        case .sunset:      return "SUNSET"
        case .night:       return "NIGHT"
        case .neonCity:    return "NEON CITY"
        case .underwater:  return "DEEP SEA"
        case .volcano:     return "VOLCANO"
        case .arctic:      return "ARCTIC"
        case .western:     return "WESTERN"
        case .jungle:      return "JUNGLE"
        case .cave:        return "CAVE"
        case .mountain:    return "MOUNTAIN"
        case .space:       return "SPACE"
        case .pixelTokyo:  return "TOKYO"
        case .egypt:       return "EGYPT"
        }
    }

    var subtitle: String {
        switch self {
        case .day:         return "Clear Skies"
        case .sunset:      return "Golden Hour"
        case .night:       return "Starlit Flight"
        case .neonCity:    return "Synthwave Vibes"
        case .underwater:  return "Bubble Time"
        case .volcano:     return "Hot Wings"
        case .arctic:      return "Chill Out"
        case .western:     return "High Noon"
        case .jungle:      return "Canopy Run"
        case .cave:        return "Deep Below"
        case .mountain:    return "Summit Rush"
        case .space:       return "To The Moon"
        case .pixelTokyo:  return "Neon Nights"
        case .egypt:       return "Pharaoh's Flight"
        }
    }

    // MARK: - Purchase

    var purchaseKind: ThemePurchaseKind {
        switch self {
        case .day, .sunset, .night:
            return .free
        case .neonCity, .underwater, .volcano, .arctic,
             .western, .jungle, .cave, .mountain:
            return .normal
        case .space, .pixelTokyo, .egypt:
            return .premium
        }
    }

    var isFree: Bool { purchaseKind == .free }
    var isNormal: Bool { purchaseKind == .normal }
    var isPremium: Bool { purchaseKind == .premium }

    var breadPrice: Int? {
        switch self {
        case .neonCity:    return 150
        case .underwater:  return 200
        case .volcano:     return 250
        case .arctic:      return 200
        case .western:     return 175
        case .jungle:      return 200
        case .cave:        return 225
        case .mountain:    return 175
        default:           return nil
        }
    }

    var premiumProductID: String? {
        guard isPremium else { return nil }
        return "com.floppyduck.theme.\(rawValue)"
    }

    var priceDisplay: String {
        switch purchaseKind {
        case .free:    return "FREE"
        case .normal:  return "\(breadPrice ?? 0) BREAD"
        case .premium: return "$0.99"
        }
    }

    // MARK: - Visual Palette

    /// Sky gradient colors (top to bottom).
    var gradientColors: [Color] {
        switch self {
        case .day:
            return [
                Color(red: 0.22, green: 0.50, blue: 0.85),
                Color(red: 0.58, green: 0.80, blue: 0.94),
                Color(red: 0.78, green: 0.92, blue: 0.97),
            ]
        case .sunset:
            return [
                Color(red: 0.15, green: 0.10, blue: 0.30),
                Color(red: 0.65, green: 0.25, blue: 0.40),
                Color(red: 0.95, green: 0.55, blue: 0.20),
                Color(red: 1.0, green: 0.80, blue: 0.35),
            ]
        case .night:
            return [
                Color(red: 0.02, green: 0.02, blue: 0.08),
                Color(red: 0.06, green: 0.08, blue: 0.18),
                Color(red: 0.12, green: 0.15, blue: 0.30),
            ]
        case .neonCity:
            return [
                Color(red: 0.05, green: 0.02, blue: 0.15),
                Color(red: 0.15, green: 0.05, blue: 0.30),
                Color(red: 0.40, green: 0.10, blue: 0.50),
                Color(red: 0.80, green: 0.20, blue: 0.60),
            ]
        case .underwater:
            return [
                Color(red: 0.02, green: 0.08, blue: 0.25),
                Color(red: 0.05, green: 0.20, blue: 0.45),
                Color(red: 0.10, green: 0.40, blue: 0.60),
                Color(red: 0.20, green: 0.55, blue: 0.65),
            ]
        case .volcano:
            return [
                Color(red: 0.15, green: 0.05, blue: 0.02),
                Color(red: 0.40, green: 0.10, blue: 0.05),
                Color(red: 0.70, green: 0.20, blue: 0.05),
                Color(red: 0.95, green: 0.45, blue: 0.10),
            ]
        case .arctic:
            return [
                Color(red: 0.45, green: 0.60, blue: 0.80),
                Color(red: 0.65, green: 0.78, blue: 0.90),
                Color(red: 0.82, green: 0.90, blue: 0.95),
                Color(red: 0.92, green: 0.96, blue: 0.98),
            ]
        case .western:
            return [
                Color(red: 0.85, green: 0.60, blue: 0.30),
                Color(red: 0.92, green: 0.72, blue: 0.42),
                Color(red: 0.70, green: 0.48, blue: 0.28),
                Color(red: 0.55, green: 0.35, blue: 0.18),
            ]
        case .jungle:
            return [
                Color(red: 0.10, green: 0.28, blue: 0.12),
                Color(red: 0.18, green: 0.42, blue: 0.15),
                Color(red: 0.30, green: 0.58, blue: 0.22),
                Color(red: 0.50, green: 0.72, blue: 0.35),
            ]
        case .cave:
            return [
                Color(red: 0.04, green: 0.03, blue: 0.06),
                Color(red: 0.10, green: 0.08, blue: 0.14),
                Color(red: 0.18, green: 0.14, blue: 0.22),
                Color(red: 0.28, green: 0.22, blue: 0.30),
            ]
        case .mountain:
            return [
                Color(red: 0.30, green: 0.45, blue: 0.65),
                Color(red: 0.50, green: 0.65, blue: 0.82),
                Color(red: 0.70, green: 0.80, blue: 0.90),
                Color(red: 0.85, green: 0.90, blue: 0.95),
            ]
        case .space:
            return [
                Color(red: 0.0, green: 0.0, blue: 0.02),
                Color(red: 0.02, green: 0.02, blue: 0.08),
                Color(red: 0.05, green: 0.03, blue: 0.15),
            ]
        case .pixelTokyo:
            return [
                Color(red: 0.08, green: 0.05, blue: 0.18),
                Color(red: 0.20, green: 0.08, blue: 0.35),
                Color(red: 0.50, green: 0.15, blue: 0.45),
                Color(red: 0.85, green: 0.30, blue: 0.50),
            ]
        case .egypt:
            return [
                Color(red: 0.92, green: 0.78, blue: 0.45),
                Color(red: 0.85, green: 0.65, blue: 0.30),
                Color(red: 0.75, green: 0.50, blue: 0.20),
                Color(red: 0.60, green: 0.38, blue: 0.15),
            ]
        }
    }

    /// UIColor version for SpriteKit scene background.
    var backgroundColor: UIColor {
        switch self {
        case .day:         return UIColor(red: 0.35, green: 0.65, blue: 0.90, alpha: 1)
        case .sunset:      return UIColor(red: 0.85, green: 0.45, blue: 0.25, alpha: 1)
        case .night:       return UIColor(red: 0.08, green: 0.10, blue: 0.22, alpha: 1)
        case .neonCity:    return UIColor(red: 0.10, green: 0.03, blue: 0.22, alpha: 1)
        case .underwater:  return UIColor(red: 0.03, green: 0.12, blue: 0.35, alpha: 1)
        case .volcano:     return UIColor(red: 0.50, green: 0.12, blue: 0.05, alpha: 1)
        case .arctic:      return UIColor(red: 0.55, green: 0.70, blue: 0.85, alpha: 1)
        case .western:     return UIColor(red: 0.78, green: 0.56, blue: 0.30, alpha: 1)
        case .jungle:      return UIColor(red: 0.15, green: 0.35, blue: 0.14, alpha: 1)
        case .cave:        return UIColor(red: 0.08, green: 0.06, blue: 0.12, alpha: 1)
        case .mountain:    return UIColor(red: 0.40, green: 0.55, blue: 0.72, alpha: 1)
        case .space:       return UIColor(red: 0.01, green: 0.01, blue: 0.05, alpha: 1)
        case .pixelTokyo:  return UIColor(red: 0.14, green: 0.06, blue: 0.26, alpha: 1)
        case .egypt:       return UIColor(red: 0.82, green: 0.65, blue: 0.32, alpha: 1)
        }
    }

    /// Tint for cloud sprites. Lighter on dark themes for visibility.
    var cloudTint: UIColor {
        switch self {
        case .day:         return .white
        case .sunset:      return UIColor(red: 0.95, green: 0.75, blue: 0.65, alpha: 0.8)
        case .night:       return UIColor(red: 0.25, green: 0.28, blue: 0.40, alpha: 0.5)
        case .neonCity:    return UIColor(red: 0.60, green: 0.20, blue: 0.80, alpha: 0.4)
        case .underwater:  return UIColor(red: 0.30, green: 0.60, blue: 0.80, alpha: 0.3)
        case .volcano:     return UIColor(red: 0.50, green: 0.25, blue: 0.15, alpha: 0.6)
        case .arctic:      return UIColor(red: 0.95, green: 0.97, blue: 1.0, alpha: 0.9)
        case .western:     return UIColor(red: 0.90, green: 0.80, blue: 0.60, alpha: 0.5)
        case .jungle:      return UIColor(red: 0.50, green: 0.70, blue: 0.40, alpha: 0.4)
        case .cave:        return UIColor(red: 0.20, green: 0.18, blue: 0.25, alpha: 0.3)
        case .mountain:    return UIColor(red: 0.85, green: 0.88, blue: 0.95, alpha: 0.7)
        case .space:       return UIColor(red: 0.15, green: 0.10, blue: 0.30, alpha: 0.3)
        case .pixelTokyo:  return UIColor(red: 0.70, green: 0.25, blue: 0.50, alpha: 0.4)
        case .egypt:       return UIColor(red: 0.90, green: 0.75, blue: 0.50, alpha: 0.4)
        }
    }

    /// Whether to show star particles (night/space themes).
    var showStars: Bool {
        switch self {
        case .night, .space, .neonCity, .pixelTokyo, .cave:
            return true
        default:
            return false
        }
    }

    /// Accent color for UI elements (shop cards, etc.)
    var accentColor: Color {
        switch self {
        case .day:         return Color(red: 0.35, green: 0.65, blue: 0.90)
        case .sunset:      return Color(red: 0.95, green: 0.55, blue: 0.20)
        case .night:       return Color(red: 0.25, green: 0.30, blue: 0.60)
        case .neonCity:    return Color(red: 0.80, green: 0.20, blue: 0.60)
        case .underwater:  return Color(red: 0.10, green: 0.45, blue: 0.65)
        case .volcano:     return Color(red: 0.85, green: 0.30, blue: 0.10)
        case .arctic:      return Color(red: 0.55, green: 0.75, blue: 0.90)
        case .western:     return Color(red: 0.75, green: 0.50, blue: 0.22)
        case .jungle:      return Color(red: 0.22, green: 0.55, blue: 0.18)
        case .cave:        return Color(red: 0.35, green: 0.28, blue: 0.45)
        case .mountain:    return Color(red: 0.45, green: 0.60, blue: 0.80)
        case .space:       return Color(red: 0.20, green: 0.15, blue: 0.40)
        case .pixelTokyo:  return Color(red: 0.70, green: 0.20, blue: 0.45)
        case .egypt:       return Color(red: 0.85, green: 0.65, blue: 0.25)
        }
    }

    // MARK: - Per-Theme Music

    /// Preferred bundled gameplay music file name (without extension).
    /// `SoundManager` loads this instead of picking a random Action track.
    /// All themes now have dedicated bundled tracks — no more synthesized fallbacks.
    var gameplayMusicFile: String? {
        switch self {
        case .day:         return "action_level_1"
        case .sunset:      return "action_level_2"
        case .night:       return "action_level_3"
        case .neonCity:    return "theme_neonCity"
        case .underwater:  return "theme_underwater"
        case .volcano:     return "theme_volcano"
        case .arctic:      return "theme_arctic"
        case .western:     return "theme_western"
        case .jungle:      return "theme_jungle"
        case .cave:        return "theme_cave"
        case .mountain:    return "theme_mountain"
        case .space:       return "theme_space"
        case .pixelTokyo:  return "theme_pixelTokyo"
        case .egypt:       return "theme_egypt"
        }
    }

    /// Menu music is always the same regardless of theme — "adventure_stage_select".
    var menuMusicFile: String? {
        return "adventure_stage_select"
    }

    /// Identifier for synthesized per-theme music (used by SoundManager).
    var themeID: String { rawValue }
}
