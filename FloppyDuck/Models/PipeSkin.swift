import SwiftUI

// MARK: - Pipe Skin Purchase Kind

enum PipeSkinPurchaseKind: String, Codable, Hashable {
    case free
    case normal       // Bread currency
    case premium      // Real money IAP
    case botReward    // Unlocked by beating a specific bot
}

// MARK: - Pipe Skin

/// Selectable cosmetic pipe skins. Each defines a complete pipe colour palette
/// (border, body, highlight, shadow) used by `TextureFactory` to render pipe textures.
enum PipeSkin: String, CaseIterable, Identifiable, Codable {

    // Free (default)
    case classic

    // Normal (bread currency)
    case candy
    case bamboo
    case steel
    case pixel

    // Premium (IAP)
    case neon
    case royal
    case gold

    // Bot rewards
    case lava
    case ice
    case toxic

    var id: String { rawValue }

    // MARK: - Display

    var displayName: String {
        switch self {
        case .classic:  return "CLASSIC"
        case .candy:    return "CANDY"
        case .bamboo:   return "BAMBOO"
        case .steel:    return "STEEL"
        case .pixel:    return "RETRO"
        case .neon:     return "NEON"
        case .royal:    return "ROYAL"
        case .gold:     return "GOLD"
        case .lava:     return "LAVA"
        case .ice:      return "ICE"
        case .toxic:    return "TOXIC"
        }
    }

    var subtitle: String {
        switch self {
        case .classic:  return "The OG Pipes"
        case .candy:    return "Sweet Tooth"
        case .bamboo:   return "Zen Garden"
        case .steel:    return "Heavy Metal"
        case .pixel:    return "Old School"
        case .neon:     return "Glow Up"
        case .royal:    return "Royalty"
        case .gold:     return "Midas Touch"
        case .lava:     return "Hot Pipes"
        case .ice:      return "Brain Freeze"
        case .toxic:    return "Radioactive"
        }
    }

    // MARK: - Purchase

    var purchaseKind: PipeSkinPurchaseKind {
        switch self {
        case .classic:
            return .free
        case .candy, .bamboo, .steel, .pixel:
            return .normal
        case .neon, .royal, .gold:
            return .premium
        case .lava, .ice, .toxic:
            return .botReward
        }
    }

    var isFree: Bool { purchaseKind == .free }
    var isNormal: Bool { purchaseKind == .normal }
    var isPremium: Bool { purchaseKind == .premium }
    var isBotReward: Bool { purchaseKind == .botReward }

    var breadPrice: Int? {
        switch self {
        case .candy:   return 120
        case .bamboo:  return 150
        case .steel:   return 200
        case .pixel:   return 250
        default:       return nil
        }
    }

    var premiumProductID: String? {
        guard isPremium else { return nil }
        return "com.floppyduck.pipe.\(rawValue)"
    }

    var priceDisplay: String {
        switch purchaseKind {
        case .free:      return "FREE"
        case .normal:    return "\(breadPrice ?? 0) BREAD"
        case .premium:   return "$0.49"
        case .botReward: return "BOT REWARD"
        }
    }

    /// The bot ID that must be beaten to unlock this pipe skin (nil if not a bot reward).
    var requiredBotId: String? {
        switch self {
        case .lava:   return "goose"
        case .ice:    return "puddles"
        case .toxic:  return "quackers"
        default:      return nil
        }
    }

    // MARK: - Pipe Colour Palette (UIColor for CoreGraphics rendering)

    /// Dark border/outline colour.
    var borderColor: UIColor {
        switch self {
        case .classic:  return UIColor(red: 0.20, green: 0.33, blue: 0.10, alpha: 1)
        case .candy:    return UIColor(red: 0.60, green: 0.15, blue: 0.25, alpha: 1)
        case .bamboo:   return UIColor(red: 0.25, green: 0.30, blue: 0.10, alpha: 1)
        case .steel:    return UIColor(red: 0.20, green: 0.22, blue: 0.25, alpha: 1)
        case .pixel:    return UIColor(red: 0.10, green: 0.10, blue: 0.10, alpha: 1)
        case .neon:     return UIColor(red: 0.20, green: 0.00, blue: 0.30, alpha: 1)
        case .royal:    return UIColor(red: 0.20, green: 0.10, blue: 0.30, alpha: 1)
        case .gold:     return UIColor(red: 0.45, green: 0.35, blue: 0.10, alpha: 1)
        case .lava:     return UIColor(red: 0.40, green: 0.10, blue: 0.05, alpha: 1)
        case .ice:      return UIColor(red: 0.10, green: 0.25, blue: 0.40, alpha: 1)
        case .toxic:    return UIColor(red: 0.20, green: 0.30, blue: 0.05, alpha: 1)
        }
    }

    /// Main body fill colour.
    var bodyColor: UIColor {
        switch self {
        case .classic:  return UIColor(red: 0.45, green: 0.75, blue: 0.18, alpha: 1)
        case .candy:    return UIColor(red: 0.95, green: 0.45, blue: 0.60, alpha: 1)
        case .bamboo:   return UIColor(red: 0.55, green: 0.68, blue: 0.30, alpha: 1)
        case .steel:    return UIColor(red: 0.55, green: 0.58, blue: 0.62, alpha: 1)
        case .pixel:    return UIColor(red: 0.35, green: 0.35, blue: 0.35, alpha: 1)
        case .neon:     return UIColor(red: 0.90, green: 0.10, blue: 0.60, alpha: 1)
        case .royal:    return UIColor(red: 0.50, green: 0.22, blue: 0.70, alpha: 1)
        case .gold:     return UIColor(red: 0.85, green: 0.70, blue: 0.20, alpha: 1)
        case .lava:     return UIColor(red: 0.85, green: 0.25, blue: 0.10, alpha: 1)
        case .ice:      return UIColor(red: 0.40, green: 0.75, blue: 0.90, alpha: 1)
        case .toxic:    return UIColor(red: 0.55, green: 0.85, blue: 0.10, alpha: 1)
        }
    }

    /// Left-side highlight strip colour.
    var highlightColor: UIColor {
        switch self {
        case .classic:  return UIColor(red: 0.55, green: 0.85, blue: 0.28, alpha: 1)
        case .candy:    return UIColor(red: 1.00, green: 0.65, blue: 0.75, alpha: 1)
        case .bamboo:   return UIColor(red: 0.70, green: 0.80, blue: 0.45, alpha: 1)
        case .steel:    return UIColor(red: 0.72, green: 0.75, blue: 0.80, alpha: 1)
        case .pixel:    return UIColor(red: 0.50, green: 0.50, blue: 0.50, alpha: 1)
        case .neon:     return UIColor(red: 1.00, green: 0.40, blue: 0.85, alpha: 1)
        case .royal:    return UIColor(red: 0.65, green: 0.35, blue: 0.85, alpha: 1)
        case .gold:     return UIColor(red: 1.00, green: 0.85, blue: 0.40, alpha: 1)
        case .lava:     return UIColor(red: 1.00, green: 0.50, blue: 0.20, alpha: 1)
        case .ice:      return UIColor(red: 0.65, green: 0.90, blue: 1.00, alpha: 1)
        case .toxic:    return UIColor(red: 0.75, green: 1.00, blue: 0.30, alpha: 1)
        }
    }

    /// Right-side shadow strip colour.
    var shadowColor: UIColor {
        switch self {
        case .classic:  return UIColor(red: 0.34, green: 0.54, blue: 0.13, alpha: 1)
        case .candy:    return UIColor(red: 0.75, green: 0.30, blue: 0.45, alpha: 1)
        case .bamboo:   return UIColor(red: 0.40, green: 0.50, blue: 0.22, alpha: 1)
        case .steel:    return UIColor(red: 0.38, green: 0.40, blue: 0.45, alpha: 1)
        case .pixel:    return UIColor(red: 0.22, green: 0.22, blue: 0.22, alpha: 1)
        case .neon:     return UIColor(red: 0.60, green: 0.05, blue: 0.40, alpha: 1)
        case .royal:    return UIColor(red: 0.35, green: 0.15, blue: 0.50, alpha: 1)
        case .gold:     return UIColor(red: 0.65, green: 0.50, blue: 0.12, alpha: 1)
        case .lava:     return UIColor(red: 0.60, green: 0.15, blue: 0.05, alpha: 1)
        case .ice:      return UIColor(red: 0.25, green: 0.55, blue: 0.70, alpha: 1)
        case .toxic:    return UIColor(red: 0.40, green: 0.60, blue: 0.05, alpha: 1)
        }
    }

    /// SwiftUI accent colour for shop/collection UI cards.
    var accentColor: Color {
        switch self {
        case .classic:  return Color(red: 0.45, green: 0.75, blue: 0.18)
        case .candy:    return Color(red: 0.95, green: 0.45, blue: 0.60)
        case .bamboo:   return Color(red: 0.55, green: 0.68, blue: 0.30)
        case .steel:    return Color(red: 0.55, green: 0.58, blue: 0.62)
        case .pixel:    return Color(red: 0.35, green: 0.35, blue: 0.35)
        case .neon:     return Color(red: 0.90, green: 0.10, blue: 0.60)
        case .royal:    return Color(red: 0.50, green: 0.22, blue: 0.70)
        case .gold:     return Color(red: 0.85, green: 0.70, blue: 0.20)
        case .lava:     return Color(red: 0.85, green: 0.25, blue: 0.10)
        case .ice:      return Color(red: 0.40, green: 0.75, blue: 0.90)
        case .toxic:    return Color(red: 0.55, green: 0.85, blue: 0.10)
        }
    }
}
