import SpriteKit
import SwiftUI

/// Global constants — physics, sizing, collision masks, park-theme palette.
enum GK {
    // MARK: - World
    static let worldWidth:  CGFloat = 400
    static let worldHeight: CGFloat = 700
    static let groundHeight: CGFloat = 80

    // MARK: - Duck
    static let duckRadius:  CGFloat = 18
    static let duckStartX:  CGFloat = 100

    // MARK: - Pipes
    static let pipeWidth:   CGFloat = 60
    static let pipeGap:     CGFloat = 180        // was 170 — slightly wider for forgiveness
    static let pipeSpeed:   CGFloat = 150
    static let pipeSpawnInterval: TimeInterval = 1.6

    // MARK: - Physics (floatier feel)
    static let gravity:     CGFloat = -600       // was -900 — 33% less = more hang time
    static let flapImpulse: CGFloat = 330        // was 320
    static let maxUpSpeed:  CGFloat = 400

    // MARK: - Speed Ramp (progressive difficulty)
    static let pipeSpeedMax:      CGFloat = 195     // cap speed
    static let speedRampPerPipe:  CGFloat = 1.5     // +1.5 pts/s per pipe scored → 195 at pipe 30

    // MARK: - Medal Thresholds
    static let medalBronze:   Int = 5
    static let medalSilver:   Int = 15
    static let medalGold:     Int = 30
    static let medalPlatinum: Int = 50

    // MARK: - Speeds
    static let groundSpeed:   CGFloat = 150
    static let cloudSpeed:    CGFloat = 20
    static let hillSpeed:     CGFloat = 15
    static let treeSpeed:     CGFloat = 40

    // MARK: - Duck positioning
    static let duckStartY:  CGFloat = 400

    // MARK: - Pipe generation
    static let pipeMinY: CGFloat = groundHeight + pipeGap / 2 + 50   // tighter floor bound
    static let pipeMaxY: CGFloat = worldHeight - pipeGap / 2 - 50    // tighter ceiling bound
    static let maxPipeDelta: CGFloat = 140   // max vertical jump between consecutive gaps
    static let maxPregenPipes: Int = 200

    // MARK: - Font
    static let pixelFontName = "PressStart2P-Regular"

    // MARK: - Multiplayer
    static let roomCodeLength = 5

    // MARK: - Collision Bitmasks
    static let duckCategory:   UInt32 = 0x1 << 0
    static let pipeCategory:   UInt32 = 0x1 << 1
    static let groundCategory: UInt32 = 0x1 << 2
    static let scoreCategory:  UInt32 = 0x1 << 3

    // MARK: - Park Color Palette

    enum Colors {
        // Sky (warm blue)
        static let skyTop    = Color(red: 0.35, green: 0.65, blue: 0.90)
        static let skyBottom = Color(red: 0.75, green: 0.90, blue: 0.95)

        // Ground
        static let groundTan   = Color(red: 0.78, green: 0.70, blue: 0.50)
        static let grassGreen  = Color(red: 0.28, green: 0.52, blue: 0.16)
        static let grassLight  = Color(red: 0.40, green: 0.72, blue: 0.22)

        // Pipes
        static let pipeGreen     = Color(red: 0.45, green: 0.75, blue: 0.18)
        static let pipeDarkGreen = Color(red: 0.34, green: 0.54, blue: 0.13)
        static let pipeBorder    = Color(red: 0.20, green: 0.33, blue: 0.10)

        // UI — warm cream panels
        static let panelCream    = Color(red: 0.96, green: 0.93, blue: 0.84)
        static let panelBorder   = Color(red: 0.31, green: 0.24, blue: 0.14)
        static let buttonGreen   = Color(red: 0.42, green: 0.73, blue: 0.20)
        static let buttonOrange  = Color(red: 0.90, green: 0.55, blue: 0.16)
        static let buttonRed     = Color(red: 0.85, green: 0.30, blue: 0.30)
        static let buttonBlue    = Color(red: 0.30, green: 0.55, blue: 0.85)

        // Text
        static let titleWhite   = Color.white
        static let titleOutline  = Color(red: 0.31, green: 0.24, blue: 0.14)
        static let scoreYellow   = Color(red: 1.0, green: 0.84, blue: 0.0)

        // Duck (mallard)
        static let duckGreen    = Color(red: 0.08, green: 0.42, blue: 0.22)
        static let duckBrown    = Color(red: 0.55, green: 0.22, blue: 0.10)
        static let duckGray     = Color(red: 0.60, green: 0.60, blue: 0.60)

        // Bread currency
        static let breadGold    = Color(red: 0.85, green: 0.68, blue: 0.30)
    }

    // MARK: - Sky Themes

    enum SkyTheme: String, CaseIterable {
        case day
        case sunset
        case night

        /// Pick a random theme, weighted toward day.
        static func random() -> SkyTheme {
            let roll = Int.random(in: 0..<10)
            if roll < 5 { return .day }      // 50%
            if roll < 8 { return .sunset }   // 30%
            return .night                     // 20%
        }

        var skyTopColor: UIColor {
            switch self {
            case .day:    return UIColor(red: 0.35, green: 0.65, blue: 0.90, alpha: 1)
            case .sunset: return UIColor(red: 0.95, green: 0.45, blue: 0.25, alpha: 1)
            case .night:  return UIColor(red: 0.08, green: 0.10, blue: 0.25, alpha: 1)
            }
        }

        var skyBottomColor: UIColor {
            switch self {
            case .day:    return UIColor(red: 0.75, green: 0.90, blue: 0.95, alpha: 1)
            case .sunset: return UIColor(red: 1.00, green: 0.75, blue: 0.40, alpha: 1)
            case .night:  return UIColor(red: 0.12, green: 0.15, blue: 0.35, alpha: 1)
            }
        }

        var cloudTint: UIColor {
            switch self {
            case .day:    return .white
            case .sunset: return UIColor(red: 1.0, green: 0.85, blue: 0.70, alpha: 1)
            case .night:  return UIColor(red: 0.45, green: 0.50, blue: 0.65, alpha: 1)
            }
        }

        var hillColor: UIColor {
            switch self {
            case .day:    return UIColor(red: 0.22, green: 0.60, blue: 0.25, alpha: 1)
            case .sunset: return UIColor(red: 0.35, green: 0.35, blue: 0.20, alpha: 1)
            case .night:  return UIColor(red: 0.10, green: 0.18, blue: 0.12, alpha: 1)
            }
        }

        var swiftUIColors: (top: Color, bottom: Color) {
            switch self {
            case .day:    return (Colors.skyTop, Colors.skyBottom)
            case .sunset: return (Color(red: 0.95, green: 0.45, blue: 0.25), Color(red: 1.00, green: 0.75, blue: 0.40))
            case .night:  return (Color(red: 0.08, green: 0.10, blue: 0.25), Color(red: 0.12, green: 0.15, blue: 0.35))
            }
        }

        /// Stars visible only at night.
        var showStars: Bool { self == .night }
    }
}
