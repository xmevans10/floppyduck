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

    // Premium (IAP)
    case space
    case pixelTokyo

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
        case .space:       return "SPACE"
        case .pixelTokyo:  return "TOKYO"
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
        case .space:       return "To The Moon"
        case .pixelTokyo:  return "Neon Nights"
        }
    }

    // MARK: - Purchase

    var purchaseKind: ThemePurchaseKind {
        switch self {
        case .day, .sunset, .night:
            return .free
        case .neonCity, .underwater, .volcano, .arctic:
            return .normal
        case .space, .pixelTokyo:
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
        case .space:       return UIColor(red: 0.01, green: 0.01, blue: 0.05, alpha: 1)
        case .pixelTokyo:  return UIColor(red: 0.14, green: 0.06, blue: 0.26, alpha: 1)
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
        case .space:       return UIColor(red: 0.15, green: 0.10, blue: 0.30, alpha: 0.3)
        case .pixelTokyo:  return UIColor(red: 0.70, green: 0.25, blue: 0.50, alpha: 0.4)
        }
    }

    /// Whether to show star particles (night/space themes).
    var showStars: Bool {
        switch self {
        case .night, .space, .neonCity, .pixelTokyo:
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
        case .space:       return Color(red: 0.20, green: 0.15, blue: 0.40)
        case .pixelTokyo:  return Color(red: 0.70, green: 0.20, blue: 0.45)
        }
    }

}
