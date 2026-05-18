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

    // Normal (bread currency) — first group
    case candy
    case sandCastle
    case bamboo
    case steel
    case pixel
    case turret
    case cactus
    case arcade
    case trafficCone
    case breadLoaf

    // Normal (bread currency) — former premium, now bread-purchasable
    case neon
    case royal
    case gold

    // Normal (bread currency) — second group
    case sodaCan
    case mailbox
    case totem
    case castleTower
    case pharaoh
    case submarine
    case rocket
    case mushroom
    case crystal
    case bone
    case bookshelf

    // Bot rewards
    case lava
    case ice
    case toxic

    var id: String { rawValue }

    // MARK: - Display

    var displayName: String {
        switch self {
        case .classic:  return "BREADBOX"
        case .candy:    return "CANDY"
        case .sandCastle: return "SANDCASTLE"
        case .bamboo:   return "BAMBOO"
        case .steel:    return "STEEL"
        case .pixel:    return "RETRO"
        case .turret:   return "TURRET"
        case .cactus:   return "CACTUS"
        case .arcade:   return "ARCADE"
        case .trafficCone: return "CONE"
        case .breadLoaf: return "BREAD"
        case .sodaCan:  return "SODA"
        case .mailbox:  return "MAILBOX"
        case .totem:    return "TOTEM"
        case .castleTower: return "CASTLE"
        case .pharaoh:  return "PHARAOH"
        case .submarine: return "SUBMARINE"
        case .rocket:   return "ROCKET"
        case .mushroom: return "MUSHROOM"
        case .crystal:  return "CRYSTAL"
        case .bone:     return "BONE"
        case .bookshelf: return "BOOKS"
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
        case .classic:  return "House Style"
        case .candy:    return "Sweet Tooth"
        case .sandCastle: return "Beach Fort"
        case .bamboo:   return "Zen Garden"
        case .steel:    return "Heavy Metal"
        case .pixel:    return "Old School"
        case .turret:   return "Tower Defense"
        case .cactus:   return "Prickly Path"
        case .arcade:   return "Insert Coin"
        case .trafficCone: return "Road Work"
        case .breadLoaf: return "Fresh Baked"
        case .sodaCan:  return "Fizz Stack"
        case .mailbox:  return "Air Mail"
        case .totem:    return "Carved Guard"
        case .castleTower: return "Stone Keep"
        case .pharaoh:  return "Desert Gold"
        case .submarine: return "Deep Brass"
        case .rocket:   return "Liftoff"
        case .mushroom: return "Spore Zone"
        case .crystal:  return "Sharp Shine"
        case .bone:     return "Fossil Flight"
        case .bookshelf: return "Stacked Lore"
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
        case .candy, .sandCastle, .bamboo, .steel, .pixel,
             .turret, .cactus, .arcade, .trafficCone, .breadLoaf,
             .neon, .royal, .gold,
             .sodaCan, .mailbox, .totem, .castleTower, .pharaoh,
             .submarine, .rocket, .mushroom, .crystal, .bone,
             .bookshelf:
            return .normal
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
        case .sandCastle: return 175
        case .bamboo:  return 150
        case .steel:   return 200
        case .pixel:   return 250
        case .turret:  return 300
        case .cactus:  return 180
        case .arcade:  return 325
        case .trafficCone: return 160
        case .breadLoaf: return 220
        case .neon:    return 350
        case .royal:   return 350
        case .gold:    return 400
        case .sodaCan: return 190
        case .mailbox: return 210
        case .totem:   return 280
        case .castleTower: return 300
        case .pharaoh: return 340
        case .submarine: return 320
        case .rocket:  return 360
        case .mushroom: return 240
        case .crystal: return 300
        case .bone:    return 260
        case .bookshelf: return 280
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
        case .classic:  return UIColor(red: 0.29, green: 0.16, blue: 0.07, alpha: 1)
        case .candy:    return UIColor(red: 0.60, green: 0.15, blue: 0.25, alpha: 1)
        case .sandCastle: return UIColor(red: 0.27, green: 0.17, blue: 0.07, alpha: 1)
        case .bamboo:   return UIColor(red: 0.25, green: 0.30, blue: 0.10, alpha: 1)
        case .steel:    return UIColor(red: 0.20, green: 0.22, blue: 0.25, alpha: 1)
        case .pixel:    return UIColor(red: 0.10, green: 0.10, blue: 0.10, alpha: 1)
        case .turret:   return UIColor(red: 0.18, green: 0.18, blue: 0.20, alpha: 1)
        case .cactus:   return UIColor(red: 0.08, green: 0.28, blue: 0.12, alpha: 1)
        case .arcade:   return UIColor(red: 0.08, green: 0.06, blue: 0.18, alpha: 1)
        case .trafficCone: return UIColor(red: 0.45, green: 0.18, blue: 0.04, alpha: 1)
        case .breadLoaf: return UIColor(red: 0.38, green: 0.20, blue: 0.08, alpha: 1)
        case .sodaCan:  return UIColor(red: 0.16, green: 0.18, blue: 0.23, alpha: 1)
        case .mailbox:  return UIColor(red: 0.20, green: 0.04, blue: 0.06, alpha: 1)
        case .totem:    return UIColor(red: 0.24, green: 0.13, blue: 0.06, alpha: 1)
        case .castleTower: return UIColor(red: 0.24, green: 0.24, blue: 0.26, alpha: 1)
        case .pharaoh:  return UIColor(red: 0.36, green: 0.24, blue: 0.08, alpha: 1)
        case .submarine: return UIColor(red: 0.20, green: 0.18, blue: 0.08, alpha: 1)
        case .rocket:   return UIColor(red: 0.18, green: 0.18, blue: 0.24, alpha: 1)
        case .mushroom: return UIColor(red: 0.38, green: 0.12, blue: 0.14, alpha: 1)
        case .crystal:  return UIColor(red: 0.08, green: 0.20, blue: 0.32, alpha: 1)
        case .bone:     return UIColor(red: 0.38, green: 0.32, blue: 0.22, alpha: 1)
        case .bookshelf: return UIColor(red: 0.20, green: 0.11, blue: 0.05, alpha: 1)
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
        case .classic:  return UIColor(red: 0.58, green: 0.34, blue: 0.14, alpha: 1)
        case .candy:    return UIColor(red: 0.95, green: 0.45, blue: 0.60, alpha: 1)
        case .sandCastle: return UIColor(red: 0.92, green: 0.65, blue: 0.26, alpha: 1)
        case .bamboo:   return UIColor(red: 0.55, green: 0.68, blue: 0.30, alpha: 1)
        case .steel:    return UIColor(red: 0.55, green: 0.58, blue: 0.62, alpha: 1)
        case .pixel:    return UIColor(red: 0.35, green: 0.35, blue: 0.35, alpha: 1)
        case .turret:   return UIColor(red: 0.48, green: 0.50, blue: 0.55, alpha: 1)
        case .cactus:   return UIColor(red: 0.28, green: 0.62, blue: 0.26, alpha: 1)
        case .arcade:   return UIColor(red: 0.20, green: 0.14, blue: 0.42, alpha: 1)
        case .trafficCone: return UIColor(red: 0.95, green: 0.36, blue: 0.08, alpha: 1)
        case .breadLoaf: return UIColor(red: 0.82, green: 0.50, blue: 0.20, alpha: 1)
        case .sodaCan:  return UIColor(red: 0.78, green: 0.12, blue: 0.18, alpha: 1)
        case .mailbox:  return UIColor(red: 0.78, green: 0.10, blue: 0.14, alpha: 1)
        case .totem:    return UIColor(red: 0.55, green: 0.30, blue: 0.14, alpha: 1)
        case .castleTower: return UIColor(red: 0.55, green: 0.55, blue: 0.58, alpha: 1)
        case .pharaoh:  return UIColor(red: 0.82, green: 0.58, blue: 0.20, alpha: 1)
        case .submarine: return UIColor(red: 0.72, green: 0.58, blue: 0.18, alpha: 1)
        case .rocket:   return UIColor(red: 0.78, green: 0.82, blue: 0.88, alpha: 1)
        case .mushroom: return UIColor(red: 0.82, green: 0.22, blue: 0.28, alpha: 1)
        case .crystal:  return UIColor(red: 0.22, green: 0.70, blue: 0.95, alpha: 1)
        case .bone:     return UIColor(red: 0.82, green: 0.74, blue: 0.56, alpha: 1)
        case .bookshelf: return UIColor(red: 0.48, green: 0.24, blue: 0.10, alpha: 1)
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
        case .classic:  return UIColor(red: 0.82, green: 0.54, blue: 0.24, alpha: 1)
        case .candy:    return UIColor(red: 1.00, green: 0.65, blue: 0.75, alpha: 1)
        case .sandCastle: return UIColor(red: 1.00, green: 0.82, blue: 0.42, alpha: 1)
        case .bamboo:   return UIColor(red: 0.70, green: 0.80, blue: 0.45, alpha: 1)
        case .steel:    return UIColor(red: 0.72, green: 0.75, blue: 0.80, alpha: 1)
        case .pixel:    return UIColor(red: 0.50, green: 0.50, blue: 0.50, alpha: 1)
        case .turret:   return UIColor(red: 0.70, green: 0.72, blue: 0.76, alpha: 1)
        case .cactus:   return UIColor(red: 0.42, green: 0.78, blue: 0.34, alpha: 1)
        case .arcade:   return UIColor(red: 0.08, green: 0.85, blue: 0.95, alpha: 1)
        case .trafficCone: return UIColor(red: 1.00, green: 0.64, blue: 0.20, alpha: 1)
        case .breadLoaf: return UIColor(red: 1.00, green: 0.70, blue: 0.32, alpha: 1)
        case .sodaCan:  return UIColor(red: 1.00, green: 0.34, blue: 0.36, alpha: 1)
        case .mailbox:  return UIColor(red: 1.00, green: 0.28, blue: 0.30, alpha: 1)
        case .totem:    return UIColor(red: 0.78, green: 0.48, blue: 0.22, alpha: 1)
        case .castleTower: return UIColor(red: 0.72, green: 0.72, blue: 0.76, alpha: 1)
        case .pharaoh:  return UIColor(red: 1.00, green: 0.78, blue: 0.28, alpha: 1)
        case .submarine: return UIColor(red: 0.90, green: 0.74, blue: 0.28, alpha: 1)
        case .rocket:   return UIColor(red: 1.00, green: 1.00, blue: 0.96, alpha: 1)
        case .mushroom: return UIColor(red: 1.00, green: 0.46, blue: 0.48, alpha: 1)
        case .crystal:  return UIColor(red: 0.55, green: 0.92, blue: 1.00, alpha: 1)
        case .bone:     return UIColor(red: 0.96, green: 0.88, blue: 0.66, alpha: 1)
        case .bookshelf: return UIColor(red: 0.72, green: 0.38, blue: 0.16, alpha: 1)
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
        case .classic:  return UIColor(red: 0.38, green: 0.20, blue: 0.08, alpha: 1)
        case .candy:    return UIColor(red: 0.75, green: 0.30, blue: 0.45, alpha: 1)
        case .sandCastle: return UIColor(red: 0.63, green: 0.42, blue: 0.14, alpha: 1)
        case .bamboo:   return UIColor(red: 0.40, green: 0.50, blue: 0.22, alpha: 1)
        case .steel:    return UIColor(red: 0.38, green: 0.40, blue: 0.45, alpha: 1)
        case .pixel:    return UIColor(red: 0.22, green: 0.22, blue: 0.22, alpha: 1)
        case .turret:   return UIColor(red: 0.34, green: 0.35, blue: 0.40, alpha: 1)
        case .cactus:   return UIColor(red: 0.18, green: 0.44, blue: 0.20, alpha: 1)
        case .arcade:   return UIColor(red: 0.12, green: 0.08, blue: 0.28, alpha: 1)
        case .trafficCone: return UIColor(red: 0.72, green: 0.22, blue: 0.04, alpha: 1)
        case .breadLoaf: return UIColor(red: 0.62, green: 0.34, blue: 0.12, alpha: 1)
        case .sodaCan:  return UIColor(red: 0.48, green: 0.06, blue: 0.10, alpha: 1)
        case .mailbox:  return UIColor(red: 0.54, green: 0.04, blue: 0.08, alpha: 1)
        case .totem:    return UIColor(red: 0.36, green: 0.18, blue: 0.08, alpha: 1)
        case .castleTower: return UIColor(red: 0.40, green: 0.40, blue: 0.44, alpha: 1)
        case .pharaoh:  return UIColor(red: 0.60, green: 0.38, blue: 0.12, alpha: 1)
        case .submarine: return UIColor(red: 0.50, green: 0.40, blue: 0.12, alpha: 1)
        case .rocket:   return UIColor(red: 0.48, green: 0.52, blue: 0.60, alpha: 1)
        case .mushroom: return UIColor(red: 0.58, green: 0.12, blue: 0.18, alpha: 1)
        case .crystal:  return UIColor(red: 0.12, green: 0.44, blue: 0.68, alpha: 1)
        case .bone:     return UIColor(red: 0.62, green: 0.52, blue: 0.36, alpha: 1)
        case .bookshelf: return UIColor(red: 0.32, green: 0.16, blue: 0.07, alpha: 1)
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
        case .classic:  return Color(red: 0.58, green: 0.34, blue: 0.14)
        case .candy:    return Color(red: 0.95, green: 0.45, blue: 0.60)
        case .sandCastle: return Color(red: 0.92, green: 0.65, blue: 0.26)
        case .bamboo:   return Color(red: 0.55, green: 0.68, blue: 0.30)
        case .steel:    return Color(red: 0.55, green: 0.58, blue: 0.62)
        case .pixel:    return Color(red: 0.35, green: 0.35, blue: 0.35)
        case .turret:   return Color(red: 0.48, green: 0.50, blue: 0.55)
        case .cactus:   return Color(red: 0.28, green: 0.62, blue: 0.26)
        case .arcade:   return Color(red: 0.20, green: 0.14, blue: 0.42)
        case .trafficCone: return Color(red: 0.95, green: 0.36, blue: 0.08)
        case .breadLoaf: return Color(red: 0.82, green: 0.50, blue: 0.20)
        case .sodaCan:  return Color(red: 0.78, green: 0.12, blue: 0.18)
        case .mailbox:  return Color(red: 0.78, green: 0.10, blue: 0.14)
        case .totem:    return Color(red: 0.55, green: 0.30, blue: 0.14)
        case .castleTower: return Color(red: 0.55, green: 0.55, blue: 0.58)
        case .pharaoh:  return Color(red: 0.82, green: 0.58, blue: 0.20)
        case .submarine: return Color(red: 0.72, green: 0.58, blue: 0.18)
        case .rocket:   return Color(red: 0.78, green: 0.82, blue: 0.88)
        case .mushroom: return Color(red: 0.82, green: 0.22, blue: 0.28)
        case .crystal:  return Color(red: 0.22, green: 0.70, blue: 0.95)
        case .bone:     return Color(red: 0.82, green: 0.74, blue: 0.56)
        case .bookshelf: return Color(red: 0.48, green: 0.24, blue: 0.10)
        case .neon:     return Color(red: 0.90, green: 0.10, blue: 0.60)
        case .royal:    return Color(red: 0.50, green: 0.22, blue: 0.70)
        case .gold:     return Color(red: 0.85, green: 0.70, blue: 0.20)
        case .lava:     return Color(red: 0.85, green: 0.25, blue: 0.10)
        case .ice:      return Color(red: 0.40, green: 0.75, blue: 0.90)
        case .toxic:    return Color(red: 0.55, green: 0.85, blue: 0.10)
        }
    }
}
