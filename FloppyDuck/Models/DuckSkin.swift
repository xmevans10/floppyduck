import SwiftUI

/// All available duck skins. Each skin keeps the base 16-wide mallard body shape
/// and adds pixel-art accessories (hat, horns, spikes, etc.).
enum DuckSkin: String, CaseIterable, Identifiable, Codable {
    case classic    // Default mallard — free
    case cowboy
    case alien
    case dinosaur
    case wizard
    case devil

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .classic:   return "MALLARD"
        case .cowboy:    return "COWBOY"
        case .alien:     return "ALIEN"
        case .dinosaur:  return "DINO"
        case .wizard:    return "WIZARD"
        case .devil:     return "DEVIL"
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
        }
    }

    var isFree: Bool { self == .classic }

    var productID: String { "com.floppyduck.skin.\(rawValue)" }

    var priceDisplay: String { isFree ? "FREE" : "$0.49" }

    /// Pixel canvas: width × height. Body is always 16 wide; height varies with accessories.
    var canvasSize: (w: Int, h: Int) {
        switch self {
        case .classic:   return (16, 11)
        case .cowboy:    return (16, 15)
        case .alien:     return (16, 14)
        case .dinosaur:  return (16, 14)
        case .wizard:    return (16, 17)
        case .devil:     return (16, 14)
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
        }
    }
}
