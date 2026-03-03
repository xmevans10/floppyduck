import Foundation
import CoreGraphics

/// All game physics and layout constants — single source of truth.
enum GK {
    // MARK: - World
    static let worldWidth: CGFloat  = 400
    static let worldHeight: CGFloat = 700
    static let groundHeight: CGFloat = 80
    static let playableHeight: CGFloat = worldHeight - groundHeight
    
    // MARK: - Duck Physics
    static let gravity: CGFloat     = -900       // pts/s² (SpriteKit Y-up)
    static let flapImpulse: CGFloat = 320        // upward velocity on tap
    static let duckRadius: CGFloat  = 18
    static let duckX: CGFloat       = 100        // fixed X position
    static let duckStartY: CGFloat  = 400
    
    // MARK: - Pipes
    static let pipeWidth: CGFloat   = 60
    static let pipeGap: CGFloat     = 170
    static let pipeSpeed: CGFloat   = 150        // pts/s (rightward movement negated)
    static let pipeSpawnInterval: Double = 1.6   // seconds between pipes
    static let pipeMinY: CGFloat    = 130        // min gap center from ground
    static let pipeMaxY: CGFloat    = 530        // max gap center from top
    
    // MARK: - Scrolling
    static let groundSpeed: CGFloat = 150        // matches pipe speed
    static let cloudSpeed: CGFloat  = 20
    static let buildingSpeed: CGFloat = 45       // parallax city
    
    // MARK: - Collision Bitmasks
    static let duckCategory: UInt32    = 0x1 << 0
    static let pipeCategory: UInt32    = 0x1 << 1
    static let groundCategory: UInt32  = 0x1 << 2
    static let scoreCategory: UInt32   = 0x1 << 3
    
    // MARK: - PRNG / Multiplayer
    static let maxPregenPipes: Int = 600
    static let roomCodeChars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    static let roomCodeLength = 5
    
    // MARK: - Colors
    static let skyTopColor    = (r: 77, g: 201, b: 246)    // #4dc9f6
    static let skyMidColor    = (r: 125, g: 211, b: 252)   // #7dd3fc
    static let horizonColor   = (r: 194, g: 230, b: 164)   // #c2e6a4
    static let grassGreen     = (r: 137, g: 206, b: 86)    // #89ce56
    static let grassHighlight = (r: 160, g: 224, b: 104)   // #a0e068
    static let dirtColor      = (r: 222, g: 216, b: 149)   // #ded895
    static let pipeGreen      = (r: 99, g: 194, b: 59)     // #63c23b
    static let pipeDarkGreen  = (r: 56, g: 143, b: 28)     // #388f1c
    static let pipeCapGreen   = (r: 79, g: 168, b: 44)     // #4fa82c
}
