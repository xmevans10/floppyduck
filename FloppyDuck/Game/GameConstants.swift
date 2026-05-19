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
    static let pipeGap:     CGFloat = 189        // 5% wider for easier play
    static let pipeSpeed:   CGFloat = 150
    static let pipeSpawnInterval: TimeInterval = 1.6

    // MARK: - Physics (floatier feel)
    static let gravity:     CGFloat = -600       // was -900 — 33% less = more hang time
    static let flapImpulse: CGFloat = 330        // was 320
    static let maxUpSpeed:  CGFloat = 400

    // MARK: - Speed Ramp (progressive difficulty)
    static let pipeSpeedMax:      CGFloat = 195     // cap speed
    static let speedRampPerPipe:  CGFloat = 1.2     // +1.2 pts/s per pipe scored — gentler early ramp

    // MARK: - Medal Thresholds
    static let medalBronze:   Int = 5
    static let medalSilver:   Int = 15
    static let medalGold:     Int = 30
    static let medalPlatinum: Int = 50

    // MARK: - Parallax Speed

    /// Base scroll speed for ground, pipes, and recipe-scaling. Pts/sec.
    static let groundSpeed: CGFloat = 150

    // MARK: - Duck positioning
    static let duckStartY:  CGFloat = 400

    // MARK: - Pipe generation
    static let pipeMinY: CGFloat = groundHeight + pipeGap / 2 + 50   // tighter floor bound
    static let pipeMaxY: CGFloat = worldHeight - pipeGap / 2 - 50    // tighter ceiling bound
    static let maxPipeDelta: CGFloat = 140   // max vertical jump between consecutive gaps
    static let maxPregenPipes: Int = 200

    // MARK: - Animation Timings (death sequence, popups, etc.)
    enum Animation {
        static let deathFreezeDuration:     TimeInterval = 0.08
        static let deathFlashFadeDuration:  TimeInterval = 0.3
        static let deathVignetteFadeIn:     TimeInterval = 0.12
        static let deathVignetteFadeOut:    TimeInterval = 0.9
        static let deathFallMinDuration:    TimeInterval = 0.25
        static let deathFallMaxDuration:    TimeInterval = 0.65
        static let deathFallSpeed:          CGFloat = 500
        static let deathDuckFadeDuration:   TimeInterval = 0.3
        static let deathToGameOverDelay:    TimeInterval = 1.2
        static let zoomInScale:             CGFloat = 1.03
        static let zoomInDuration:          TimeInterval = 0.15
        static let zoomOutDuration:         TimeInterval = 0.4
        static let tierLabelHoldDuration:   TimeInterval = 0.8
        static let popupFloatHeight:        CGFloat = 50
        static let popupDuration:           TimeInterval = 0.6
    }

    // MARK: - Font
    static let pixelFontName = "PressStart2P-Regular"

    // MARK: - Multiplayer
    static let roomCodeLength = 5

    // MARK: - App Store

    static let appStoreID = "6768735513"
    static var appStoreURL: URL? {
        makeAppStoreURL(appID: appStoreID)
    }

    static func makeAppStoreURL(appID: String) -> URL? {
        let sanitizedID = appID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitizedID.isEmpty, sanitizedID != "000000000" else { return nil }
        guard CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: sanitizedID)) else { return nil }
        return URL(string: "https://apps.apple.com/app/floppy-duck/id\(sanitizedID)")
    }

    // MARK: - Collision Bitmasks
    static let duckCategory:    UInt32 = 0x1 << 0
    static let pipeCategory:    UInt32 = 0x1 << 1
    static let groundCategory:  UInt32 = 0x1 << 2
    static let scoreCategory:   UInt32 = 0x1 << 3
    static let powerUpCategory: UInt32 = 0x1 << 4
    static let breadCategory:   UInt32 = 0x1 << 5
    static let botCategory:     UInt32 = 0x1 << 6
    static let ceilingCategory: UInt32 = 0x1 << 7

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

        // Wood — park sign boards
        static let woodSurface  = Color(red: 0.55, green: 0.40, blue: 0.20)
        static let woodGrain    = Color(red: 0.42, green: 0.28, blue: 0.12)

        // Pixel typography
        static let titleCream        = Color(red: 1.0,   green: 0.965, blue: 0.847)  // #FFF6D8
        static let cardTextPrimary   = Color(red: 0.29,  green: 0.226, blue: 0.141)  // #4A3A24
        static let cardTextSecondary = Color(red: 0.43,  green: 0.376, blue: 0.298)  // #6E604C
        static let outlineShadow     = Color(red: 0.063, green: 0.165, blue: 0.094)  // #102A18
    }
}

extension Color {
    init?(hexString: String) {
        let sanitized = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        guard sanitized.count == 6,
              let value = UInt64(sanitized, radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
