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
    case lumberquack
    case spider
    case squirrel
    case bearskin
    case mermaid
    case princess
    case unicorn

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
        case .lumberquack: return "LUMBERQUACK"
        case .spider:      return "SPIDER"
        case .squirrel:    return "SQUIRREL"
        case .bearskin:    return "GUARD"
        case .mermaid:     return "MERMAID"
        case .princess:    return "PRINCESS"
        case .unicorn:     return "UNICORN"
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
        case .lumberquack: return "Timber!"
        case .spider:      return "Web Slinger"
        case .squirrel:    return "Nutty"
        case .bearskin:    return "Quack, innit?"
        case .mermaid:     return "Under The Sea"
        case .princess:    return "Royal Flutter"
        case .unicorn:     return "Magical Quack"
        }
    }

    var purchaseKind: SkinPurchaseKind {
        switch self {
        case .classic:
            return .free
        case .cowboy, .dinosaur, .robot, .king, .lumberquack, .squirrel, .bearskin, .mermaid, .princess, .unicorn:
            return .normal
        case .alien, .wizard, .devil, .ninja, .astronaut, .pharaoh, .spider:
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
        case .bearskin:
            return 185
        case .mermaid:
            return 200
        case .princess:
            return 200
        case .unicorn:
            return 185
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
        case .lumberquack: return (16, 15)
        case .spider:      return (16, 14)
        case .squirrel:    return (16, 15)
        case .bearskin:    return (16, 17)
        case .mermaid:     return (16, 15)
        case .princess:    return (16, 15)
        case .unicorn:     return (16, 14)
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
        case .lumberquack: return 4
        case .spider:      return 3
        case .squirrel:    return 4
        case .bearskin:    return 6
        case .mermaid:     return 0
        case .princess:    return 4
        case .unicorn:     return 3
        }
    }

    /// SpriteKit sprite size (points). Physics hitbox is independent of this.
    var spriteSize: CGSize {
        let bodyWidth = GK.duckRadius * 2.8
        if let frameSize = productionFrameSize {
            let scale = bodyWidth / Self.productionBodyPixelWidth
            return CGSize(
                width: CGFloat(frameSize.w) * scale,
                height: CGFloat(frameSize.h) * scale
            )
        }
        return CGSize(width: bodyWidth, height: bodyWidth * CGFloat(canvasSize.h) / CGFloat(canvasSize.w))
    }

    /// Finalized PNG frames are transparent canvases around the duck. Scale them by
    /// the shared body width so hats, tails, and other cosmetics never resize the body.
    private static let productionBodyPixelWidth: CGFloat = 253

    private var productionFrameSize: (w: Int, h: Int)? {
        switch self {
        case .alien:       return (339, 357)
        case .astronaut:   return (253, 237)
        case .cowboy:      return (400, 322)
        case .devil:       return (333, 302)
        case .dinosaur:    return (332, 284)
        case .king:        return (341, 363)
        case .lumberquack: return (335, 340)
        case .mermaid:     return (579, 333)
        case .ninja:       return (389, 297)
        case .pharaoh:     return (410, 328)
        case .pirate:      return (333, 281)
        case .princess:    return (355, 338)
        case .robot:       return (333, 266)
        case .squirrel:    return (337, 347)
        case .unicorn:     return (333, 315)
        case .wizard:      return (411, 416)
        case .bearskin:    return (253, 268)
        case .classic:     return (315, 231)
        case .sailor:      return (315, 294)
        case .golden:      return (315, 294)
        case .spider:      return (315, 294)
        }
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
        case .lumberquack: return Color(red: 0.85, green: 0.25, blue: 0.20)
        case .spider:      return Color(red: 0.40, green: 0.15, blue: 0.50)
        case .squirrel:    return Color(red: 0.60, green: 0.38, blue: 0.20)
        case .bearskin:    return Color(red: 0.82, green: 0.10, blue: 0.14)
        case .mermaid:     return Color(red: 0.15, green: 0.70, blue: 0.65)
        case .princess:    return Color(red: 0.88, green: 0.45, blue: 0.65)
        case .unicorn:     return Color(red: 0.75, green: 0.45, blue: 0.85)
        }
    }

    /// The bot ID that must be beaten to unlock this skin (nil if not a bot reward).
    var rewardBotId: String? {
        switch self {
        case .sailor: return "puddles"
        case .pirate: return "goose"
        case .golden: return "the_duck"
        default:      return nil
        }
    }
}
