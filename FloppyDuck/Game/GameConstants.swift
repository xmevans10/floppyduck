import SpriteKit
import SwiftUI

/// Global constants — physics, sizing, collision masks, retro color palette.
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
    static let pipeGap:     CGFloat = 170
    static let pipeSpeed:   CGFloat = 150
    static let pipeSpawnInterval: TimeInterval = 1.6

    // MARK: - Physics
    static let gravity:     CGFloat = -900
    static let flapImpulse: CGFloat = 320
    static let maxUpSpeed:  CGFloat = 400

    // MARK: - Speeds
    static let groundSpeed: CGFloat = 150    // same as pipe speed
    static let cloudSpeed:  CGFloat = 20     // slow parallax
    static let buildingSpeed: CGFloat = 40   // medium parallax

    // MARK: - Duck positioning
    static let duckStartY:  CGFloat = 400    // starting height

    // MARK: - Multiplayer
    static let roomCodeLength = 5

    // MARK: - Collision Bitmasks
    static let duckCategory:   UInt32 = 0x1 << 0
    static let pipeCategory:   UInt32 = 0x1 << 1
    static let groundCategory: UInt32 = 0x1 << 2
    static let scoreCategory:  UInt32 = 0x1 << 3

    // MARK: - Retro Color Palette (Flappy Bird style)
    enum Colors {
        // Sky
        static let skyTop    = Color(red: 0.31, green: 0.75, blue: 0.79)  // #4EC0CA
        static let skyBottom = Color(red: 0.72, green: 0.91, blue: 0.92)  // #B8E9EC

        // Ground
        static let groundTan   = Color(red: 0.87, green: 0.85, blue: 0.58) // #DED895
        static let grassGreen  = Color(red: 0.33, green: 0.55, blue: 0.18) // #558B2F
        static let grassLight  = Color(red: 0.51, green: 0.76, blue: 0.24) // #82C23D

        // Pipes
        static let pipeGreen     = Color(red: 0.45, green: 0.75, blue: 0.18)  // #74BF2E
        static let pipeDarkGreen = Color(red: 0.34, green: 0.54, blue: 0.13)  // #578A22
        static let pipeBorder    = Color(red: 0.20, green: 0.33, blue: 0.10)  // #335419

        // UI Buttons & Panels
        static let panelCream    = Color(red: 0.96, green: 0.93, blue: 0.84) // #F5ECD5
        static let panelBorder   = Color(red: 0.31, green: 0.24, blue: 0.14) // #503E23
        static let buttonOrange  = Color(red: 0.90, green: 0.55, blue: 0.16) // #E68D29
        static let buttonGreen   = Color(red: 0.42, green: 0.73, blue: 0.20) // #6BBA33

        // Text
        static let titleWhite   = Color.white
        static let titleOutline  = Color(red: 0.31, green: 0.24, blue: 0.14) // #503E23
        static let scoreYellow   = Color(red: 1.0, green: 0.84, blue: 0.0)   // #FFD700

        // Duck
        static let duckYellow   = Color(red: 0.98, green: 0.80, blue: 0.18) // #FACC2E
        static let duckOrange   = Color(red: 0.93, green: 0.49, blue: 0.13) // #ED7D21
        static let duckWhite    = Color.white

        // CGColor versions for SpriteKit texture rendering
        static let skyTopCG    = CGColor(red: 0.31, green: 0.75, blue: 0.79, alpha: 1)
        static let skyBottomCG = CGColor(red: 0.72, green: 0.91, blue: 0.92, alpha: 1)
    }
}
