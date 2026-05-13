import SwiftUI

enum SkinPurchaseKind: String, Codable, Hashable {
    case free
    case normal
    case premium
    case botReward
}

/// All available duck skins. Each skin keeps the base 16-wide mallard body shape
/// and adds pixel-art accessories (hat, horns, spikes, etc.).
enum DuckSkin: String, CaseIterable, Identifiable, Codable {
    case classic    // Default mallard — free
    case cowboy
    case alien
    case dinosaur
    case wizard
    case devil
    case sailor
    case pirate
    case golden
    case ninja
    case astronaut
    case pharaoh
    case robot
    case king
    case mogul
    case lumberquack
    case spider
    case squirrel

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .classic:   return "MALLARD"
        case .cowboy:    return "COWBOY"
        case .alien:     return "ALIEN"
        case .dinosaur:  return "DINO"
        case .wizard:    return "WIZARD"
        case .devil:     return "DEVIL"
        case .sailor:    return "BUCCANEER"
        case .pirate:    return "PIRATE"
        case .golden:    return "GOLDEN"
        case .ninja:     return "NINJA"
        case .astronaut: return "ASTRONAUT"
        case .pharaoh:   return "PHARAOH"
        case .robot:     return "ROBOT"
        case .king:        return "KING"
        case .mogul:       return "PREZ"
        case .lumberquack: return "LUMBERQUACK"
        case .spider:      return "SPIDER"
        case .squirrel:    return "SQUIRREL"
        }
    }

    var subtitle: String {
        switch self {
        case .classic:   return "The OG"
        case .cowboy:    return "Yeehaw!"
        case .alien:     return "Phone Home"
        case .dinosaur:  return "Rawr XD"
        case .wizard:    return "Yer a Duck"
        case .devil:     return "Wicked Quack"
        case .sailor:    return "Shiver Me Timbers"
        case .pirate:    return "Yarr!"
        case .golden:    return "Legendary"
        case .ninja:     return "Silent Quack"
        case .astronaut: return "Lift Off"
        case .pharaoh:   return "Royal Wings"
        case .robot:     return "Beep Boop"
        case .king:        return "Long Live the Quack"
        case .mogul:       return "You're Hired!"
        case .lumberquack: return "Timber!"
        case .spider:      return "Web Slinger"
        case .squirrel:    return "Nutty"
        }
    }

    var purchaseKind: SkinPurchaseKind {
        switch self {
        case .classic:
            return .free
        case .cowboy, .dinosaur, .robot, .king, .lumberquack, .squirrel:
            return .normal
        case .alien, .wizard, .devil, .ninja, .astronaut, .pharaoh, .mogul, .spider:
            return .premium
        case .sailor, .pirate, .golden:
            return .botReward
        }
    }

    var isFree: Bool { purchaseKind == .free }
    var isPremium: Bool { purchaseKind == .premium }
    var isNormal: Bool { purchaseKind == .normal }
    var isBotReward: Bool { purchaseKind == .botReward }

    var premiumProductID: String? {
        guard isPremium else { return nil }
        return "com.floppyduck.skin.\(rawValue)"
    }

    var breadPrice: Int? {
        switch self {
        case .cowboy:
            return 120
        case .dinosaur:
            return 180
        case .robot:
            return 200
        case .king:
            return 175
        case .lumberquack:
            return 150
        case .squirrel:
            return 175
        default:
            return nil
        }
    }

    var priceDisplay: String {
        switch purchaseKind {
        case .free:
            return "FREE"
        case .normal:
            return "\(breadPrice ?? 0) BREAD"
        case .premium:
            return "$0.49"
        case .botReward:
            return "BOT REWARD"
        }
    }

    /// Pixel canvas: width × height. Body is always 16 wide; height varies with accessories.
    var canvasSize: (w: Int, h: Int) {
        switch self {
        case .classic:   return (16, 11)
        case .cowboy:    return (16, 15)
        case .alien:     return (16, 14)
        case .dinosaur:  return (16, 14)
        case .wizard:    return (16, 17)
        case .devil:     return (16, 14)
        case .sailor:    return (16, 14)
        case .pirate:    return (16, 15)
        case .golden:    return (16, 14)
        case .ninja:     return (16, 14)
        case .astronaut: return (16, 15)
        case .pharaoh:   return (16, 15)
        case .robot:     return (16, 14)
        case .king:        return (16, 15)
        case .mogul:       return (16, 15)
        case .lumberquack: return (16, 15)
        case .spider:      return (16, 14)
        case .squirrel:    return (16, 15)
        }
    }

    /// Which row in the canvas the 16×11 body starts at.
    var bodyRowOffset: Int {
        switch self {
        case .classic:   return 0
        case .cowboy:    return 4
        case .alien:     return 3
        case .dinosaur:  return 3
        case .wizard:    return 6
        case .devil:     return 3
        case .sailor:    return 3
        case .pirate:    return 4
        case .golden:    return 3
        case .ninja:     return 3
        case .astronaut: return 4
        case .pharaoh:   return 4
        case .robot:     return 3
        case .king:        return 4
        case .mogul:       return 4
        case .lumberquack: return 4
        case .spider:      return 3
        case .squirrel:    return 4
        }
    }

    /// SpriteKit sprite size (points). Physics hitbox is independent of this.
    var spriteSize: CGSize {
        let baseW = GK.duckRadius * 2.8          // matches the 16-pixel width
        let ratio = CGFloat(canvasSize.h) / CGFloat(canvasSize.w)
        return CGSize(width: baseW, height: baseW * ratio)
    }

    var accentColor: Color {
        switch self {
        case .classic:   return GK.Colors.buttonGreen
        case .cowboy:    return Color(red: 0.65, green: 0.40, blue: 0.20)
        case .alien:     return Color(red: 0.30, green: 0.85, blue: 0.30)
        case .dinosaur:  return Color(red: 0.55, green: 0.68, blue: 0.22)
        case .wizard:    return Color(red: 0.55, green: 0.30, blue: 0.80)
        case .devil:     return Color(red: 0.85, green: 0.25, blue: 0.25)
        case .sailor:    return Color(red: 0.80, green: 0.18, blue: 0.18)
        case .pirate:    return Color(red: 0.45, green: 0.30, blue: 0.15)
        case .golden:    return Color(red: 0.90, green: 0.75, blue: 0.20)
        case .ninja:     return Color(red: 0.15, green: 0.15, blue: 0.18)
        case .astronaut: return Color(red: 0.85, green: 0.88, blue: 0.92)
        case .pharaoh:   return Color(red: 0.85, green: 0.70, blue: 0.20)
        case .robot:     return Color(red: 0.55, green: 0.65, blue: 0.75)
        case .king:        return Color(red: 0.80, green: 0.15, blue: 0.20)
        case .mogul:       return Color(red: 0.90, green: 0.65, blue: 0.10)
        case .lumberquack: return Color(red: 0.85, green: 0.25, blue: 0.20)
        case .spider:      return Color(red: 0.40, green: 0.15, blue: 0.50)
        case .squirrel:    return Color(red: 0.60, green: 0.38, blue: 0.20)
        }
    }
}
