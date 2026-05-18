import SpriteKit
import SwiftUI

// MARK: - ParallaxManager

/// Owns parallax layers: recipe-driven sprite layers + runtime particle overlays.
///
/// Layer architecture is defined by `ThemeRecipeCatalog`. The manager compiles
/// a theme's recipe into concrete sprite layers at setup time. No theme-specific
/// conditionals exist in this class — all theme identity lives in the catalog.
///
/// Usage:
///   1. Create in `didMove(to:)`:
///      ```
///      parallax = ParallaxManager(backgroundLayer: backgroundLayer,
///                                 groundLayer: groundLayer,
///                                 foregroundLayer: foregroundLayer,
///                                 theme: backgroundTheme)
///      parallax.setup()
///      ```
///   2. Call `parallax.update(dt:)` every frame from the game's `update(_:)`.
final class ParallaxManager {

    // MARK: - Properties

    private let backgroundLayer: SKNode
    private let groundLayer: SKNode
    private let foregroundLayer: SKNode
    private let theme: BackgroundTheme
    private let factory: TextureFactory

    /// Compiled sprite layer definitions (from recipe).
    private var layerDefs: [SpriteLayerDef] = []

    /// All layer tile arrays, keyed by asset name for O(1) lookup.
    private var layerTiles: [String: [SKSpriteNode]] = [:]

    /// Pre-filtered moving layers — avoids per-frame dict lookups.
    private var movingLayers: [MovingLayer] = []
    private struct MovingLayer {
        let tiles: [SKSpriteNode]
        let speed: CGFloat
        let tileWidth: CGFloat
    }

    /// Cached accessibility state (avoid per-frame system queries).
    private var reduceMotionEnabled: Bool = false

    /// Whether low-power mode is active — disables overlays, reduces FPS downstream.
    private var lowPowerMode: Bool = false

    // MARK: - Scattered Midground

    /// Config for the scattered midground spawner (nil = use tiled strip instead).
    private var midgroundSpawnConfig: MidgroundSpawnConfig?
    /// Active scattered midground sprites with tree status for overlap logic.
    private var scatteredSprites: [(sprite: SKSpriteNode, isTree: Bool)] = []
    /// Cached midground scroll speed in pts/sec.
    private var midgroundSpeed: CGFloat = 0
    /// Distance remaining before next spawn (in pts).
    private var nextSpawnDistance: CGFloat = 0
    /// Global visual bump for individual midground/foreground props.
    private let scatteredPropDisplayMultiplier: CGFloat = 1.8

#if DEBUG
    private var debugOverlapChecks: Int = 0
    private var debugOverlapSkips: Int = 0
    private var debugTreeSpawns: Int = 0
    private var debugSoloSpawns: Int = 0
    private var debugReportCounter: Int = 0
    /// Only log scatter stats when `-DebugFrameLog` is passed as a launch argument.
    private let debugLogEnabled: Bool = {
        ProcessInfo.processInfo.arguments.contains("-DebugFrameLog")
            || ProcessInfo.processInfo.environment["DEBUG_FRAME_LOG"] == "1"
    }()

    func debugScatteredCount() -> Int { scatteredSprites.count }
#endif

    /// GPU-driven overlay emitters — one per effect type.
    private var overlayEmitters: [SKEmitterNode] = []

    /// Tiny white textures for emitter particles (tinted via particleColor).
    private var emitterTextureCache: [String: SKTexture] = [:]    // MARK: - Tile widths

    /// Above-ground layers tile at 2× world width for seamless wrap.
    private let aboveGroundTileWidth: CGFloat = GK.worldWidth * 2

    /// Ground layers tile at 2× world width for seamless wrap.
    private let groundTileWidth: CGFloat = GK.worldWidth * 2

    // MARK: - Init

    init(backgroundLayer: SKNode,
         groundLayer: SKNode,
         foregroundLayer: SKNode,
         theme: BackgroundTheme,
         factory: TextureFactory = .shared) {
        self.backgroundLayer = backgroundLayer
        self.groundLayer = groundLayer
        self.foregroundLayer = foregroundLayer
        self.theme = theme
        self.factory = factory
    }

    // MARK: - Public API

    func setup() {
        reduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
        lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled

        // Compile recipe into sprite layer definitions
        let recipe = ThemeRecipeCatalog.recipe(for: theme)
        layerDefs = recipe.spriteLayers()

        // Sky gradient only needed if the hero doesn't fully cover the background
        // (kept as a safety net for themes with transparent hero edges)
        setupSkyGradient()

        // Create sprite tiles for each layer
        for def in layerDefs {
            guard let image = UIImage(named: def.assetName) else {
                print("⚠️ ParallaxManager: missing asset \(def.assetName)")
                continue
            }
            let tex = SKTexture(image: image)
            tex.filteringMode = .nearest

            let tileWidth = def.isGround ? groundTileWidth : aboveGroundTileWidth
            var tiles: [SKSpriteNode] = []

            for i in 0..<def.tileCount {
                let sprite = SKSpriteNode(texture: tex,
                                           size: CGSize(width: tileWidth, height: def.height))
                sprite.anchorPoint = CGPoint(x: 0, y: 0)
                sprite.position = CGPoint(x: CGFloat(i) * tileWidth, y: def.yPosition)
                sprite.zPosition = def.zPosition

                // Ground surface is fully opaque — skip alpha blending for GPU savings
                if def.isGround {
                    sprite.blendMode = .replace
                }

                // Choose appropriate parent layer
                let parentNode: SKNode = def.isGround ? groundLayer : backgroundLayer
                parentNode.addChild(sprite)
                tiles.append(sprite)
            }

            layerTiles[def.assetName] = tiles
        }

        // Set up scattered midground sprites (if the recipe uses them)
        if let spawnConfig = recipe.midgroundSprites {
            setupScatteredMidground(spawnConfig)
        }

        setupRuntimeOverlays()

        // Pre-filter moving layers for O(1) per-frame iteration — avoids
        // per-frame dict lookups + Reduce Motion checks on static tiles.
        movingLayers = []
        for def in layerDefs {
            guard def.isGround || !reduceMotionEnabled else { continue }
            guard def.speed > 0 else { continue }
            guard let tiles = layerTiles[def.assetName] else { continue }
            movingLayers.append(MovingLayer(
                tiles: tiles,
                speed: def.speed,
                tileWidth: def.isGround ? groundTileWidth : aboveGroundTileWidth
            ))
        }
    }

    /// Drive all scrolling. Call every frame from `update(_:)` while the game is playing.
    ///
    /// When Reduce Motion is enabled (Settings → Accessibility → Motion), decorative
    /// parallax layers stop scrolling. Ground layers always scroll because they provide
    /// gameplay-relevant motion cues.
    func update(dt: TimeInterval) {
        let dtF = CGFloat(dt)

        for layer in movingLayers {
            let totalWidth = layer.tileWidth * CGFloat(layer.tiles.count)
            for tile in layer.tiles {
                tile.position.x -= layer.speed * dtF
                if tile.position.x <= -layer.tileWidth {
                    tile.position.x += totalWidth
                }
            }
        }

        updateScatteredMidground(dt: dtF)
        updateRuntimeOverlays(dt: dtF)
    }

    // MARK: - Scattered Midground

    private func setupScatteredMidground(_ config: MidgroundSpawnConfig) {
        midgroundSpawnConfig = config
        midgroundSpeed = config.scrollSpeed * GK.groundSpeed

        guard !config.props.isEmpty else { return }

        var x: CGFloat = CGFloat.random(in: 30...80)
        var initialClusters = 0
        while x < GK.worldWidth + 100 {
            spawnMidgroundCluster(at: x, config: config)
            x += CGFloat.random(in: config.spacingRange)
            initialClusters += 1
        }
        nextSpawnDistance = CGFloat.random(in: config.spacingRange)

#if DEBUG
        if debugLogEnabled {
            print("[Parallax] init: \(scatteredSprites.count) sprites from \(initialClusters) clusters (trees:\(config.treeProps.count) nonTrees:\(config.nonTreeProps.count))")
        }
#endif
    }

    /// Spawn either a tree patch (2–4 trees, max 20% overlap) or a solo non-tree prop
    /// (zero overlap with anything). Trees layer subtly; non-trees stand alone.
    private func spawnMidgroundCluster(at x: CGFloat, config: MidgroundSpawnConfig) {
        let hasTrees = !config.treeProps.isEmpty
        let hasNonTrees = !config.nonTreeProps.isEmpty

        // If only one category exists, always use that mode.
        let useTreePatch: Bool
        if hasTrees && !hasNonTrees {
            useTreePatch = true
        } else if hasNonTrees && !hasTrees {
            useTreePatch = false
        } else {
            // ~60% tree patches, ~40% solo non-tree
            useTreePatch = Bool.random()
        }

        if useTreePatch, hasTrees {
            let clusterSize = Int.random(in: 1...3)
            for i in 0..<clusterSize {
                let offsetX = CGFloat(i) * CGFloat.random(in: 30...60)
                let treeX = x + offsetX
                let prop = weightedRandomProp(config.treeProps)
#if DEBUG
                debugOverlapChecks += 1
#endif
                guard maxOverlapFraction(at: treeX, prop: prop, margin: 0) <= 0.30 else {
#if DEBUG
                    debugOverlapSkips += 1
#endif
                    continue
                }
                spawnScatteredProp(at: treeX, prop: prop, isTree: true)
#if DEBUG
                debugTreeSpawns += 1
#endif
            }
        } else if hasNonTrees {
            let prop = weightedRandomProp(config.nonTreeProps)
#if DEBUG
            debugOverlapChecks += 1
#endif
            guard maxOverlapFraction(at: x, prop: prop, margin: 20) <= 0 else {
#if DEBUG
                debugOverlapSkips += 1
#endif
                return
            }
            spawnScatteredProp(at: x, prop: prop, isTree: false)
#if DEBUG
            debugSoloSpawns += 1
#endif
        }
    }

    /// Returns the highest overlap fraction (0…1) between the candidate prop at `x`
    /// and any existing scattered sprite. 0 = no overlap, 1 = fully overlapping.
    /// `margin` expands the candidate bounds outward for extra clearance.
    private func maxOverlapFraction(at x: CGFloat, prop: MidgroundProp, margin: CGFloat) -> CGFloat {
        let estScale = (prop.scaleRange.lowerBound + prop.scaleRange.upperBound) / 2
        let estWidth = prop.heightPoints * estScale * scatteredPropDisplayMultiplier * 0.5
        let halfWidth = max(estWidth / 2, 1)  // minimum 1pt to avoid degenerate bounds

        let newMin = x - halfWidth - margin
        let newMax = x + halfWidth + margin
        guard newMax > newMin else { return 1 }  // degenerate bounds → treat as full overlap

        var maxFrac: CGFloat = 0
        for (sprite, _) in scatteredSprites {
            let sx = sprite.position.x
            let sw = sprite.size.width / 2
            let existMin = sx - sw
            let existMax = sx + sw

            let overlapMin = max(newMin, existMin)
            let overlapMax = min(newMax, existMax)
            if overlapMin < overlapMax {
                let overlapWidth = overlapMax - overlapMin
                let frac = overlapWidth / (newMax - newMin)
                if frac > maxFrac { maxFrac = frac }
            }
        }
        return maxFrac
    }

    private func spawnScatteredProp(at x: CGFloat, prop: MidgroundProp, isTree: Bool) {
        let scale = CGFloat.random(in: prop.scaleRange)

        let texture = factory.themedLayerTexture(theme: theme, assetName: prop.assetName)
        texture.filteringMode = .nearest

        let frameCount = CGFloat(prop.animation?.frameCount ?? 1)
        let aspectRatio = (texture.size().width / frameCount) / texture.size().height
        let baseHeight = prop.heightPoints * scale
        let height = baseHeight * scatteredPropDisplayMultiplier
        let width = height * aspectRatio
        let spawnX = x >= GK.worldWidth ? max(x, GK.worldWidth + width / 2 + 20) : x

        guard width > 0, height > 0, spawnX.isFinite else { return }

        let sprite = SKSpriteNode(texture: texture,
                                   size: CGSize(width: width, height: height))
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
        // Bury the base inside the ground strip so props always read as "rooted"
        // rather than "perched on top of" the ground line. The ground tile renders
        // above midground sprites (zPosition 50 vs ~-38 with ignoresSiblingOrder),
        // so the buried portion is hidden behind the strip and the visible portion
        // scales up above it.
        //   • Default bury: 30% of display height, clamped to 25...55pt.
        //   • prop.yOffset shifts vertically (positive = less buried / further back,
        //     negative = more buried / closer in).
        //   • Hard floor of 8pt keeps the base inside the strip even at extreme
        //     positive yOffset — prevents "floating above the ground" by construction.
        let baseBury = min(max(height * 0.30, 25), 55)
        let bury = max(baseBury - prop.yOffset, 8)
        sprite.position = CGPoint(x: spawnX, y: GK.groundHeight - bury)
        // Smaller scale → further back → lower z; larger → closer → higher z
        sprite.zPosition = -42 + scale * 4

        backgroundLayer.addChild(sprite)
        scatteredSprites.append((sprite, isTree))

        if let animation = prop.animation, animation.frameCount > 1 {
            let frames = (0..<animation.frameCount).map { frameIndex -> SKTexture in
                let frame = SKTexture(
                    rect: CGRect(
                        x: CGFloat(frameIndex) / CGFloat(animation.frameCount),
                        y: 0,
                        width: 1 / CGFloat(animation.frameCount),
                        height: 1
                    ),
                    in: texture
                )
                frame.filteringMode = .nearest
                return frame
            }
            let delay = 1.0 / max(animation.framesPerSecond, 1.0)
            sprite.run(.repeatForever(.animate(with: frames, timePerFrame: delay)))
        }
    }

    private func updateScatteredMidground(dt: CGFloat) {
        guard let config = midgroundSpawnConfig else { return }
        guard !reduceMotionEnabled else { return }

        let dx = midgroundSpeed * dt

        for entry in scatteredSprites {
            entry.sprite.position.x -= dx
        }

        scatteredSprites.removeAll { entry in
            guard let _ = entry.sprite.parent else {
                // Already detached — remove from tracking
                return true
            }
            if entry.sprite.position.x < -(entry.sprite.size.width / 2) - 10
                || !entry.sprite.position.x.isFinite {
                entry.sprite.removeFromParent()
                return true
            }
            return false
        }

        nextSpawnDistance -= dx
        if nextSpawnDistance <= 0 {
            let spawnX = GK.worldWidth + 50
            spawnMidgroundCluster(at: spawnX, config: config)
            nextSpawnDistance = CGFloat.random(in: config.spacingRange)
        }

#if DEBUG
        debugReportCounter += 1
        if debugReportCounter >= 180 && debugLogEnabled { // every ~3s at 60fps
            let skipRate = debugOverlapChecks > 0
                ? Int(Double(debugOverlapSkips) / Double(debugOverlapChecks) * 100)
                : 0
            print("[Parallax] sprites:\(scatteredSprites.count)  trees:\(debugTreeSpawns)  solos:\(debugSoloSpawns)  overlapChecks:\(debugOverlapChecks)  skipped(\(skipRate)%)")
            debugOverlapChecks = 0
            debugOverlapSkips = 0
            debugTreeSpawns = 0
            debugSoloSpawns = 0
            debugReportCounter = 0
        }
#endif
    }

    private func weightedRandomProp(_ props: [MidgroundProp]) -> MidgroundProp {
        guard !props.isEmpty else { return MidgroundProp(assetName: "", heightPoints: 0) }
        let totalWeight = props.reduce(0) { $0 + $1.weight }
        guard totalWeight > 0 else { return props[0] }
        var roll = Int.random(in: 0..<totalWeight)
        for prop in props {
            roll -= prop.weight
            if roll < 0 { return prop }
        }
        return props.last!
    }

    // MARK: - Runtime Overlays

    private func setupRuntimeOverlays() {
        guard !theme.overlayEffects.isEmpty else { return }
        guard !reduceMotionEnabled else { return }

        for effect in theme.overlayEffects {
            if effect == .mist {
                setupMistBands()
                continue
            }

            let emitter = createEmitter(for: effect)
            emitter.position = emitterOrigin(for: effect)
            emitter.particleZPosition = zPosition(for: effect)
            emitter.advanceSimulationTime(4)
            backgroundLayer.addChild(emitter)
            overlayEmitters.append(emitter)
        }
    }

    private func updateRuntimeOverlays(dt: CGFloat) {
        // SKEmitterNode runs entirely on the GPU — zero per-frame CPU work.
    }

    // MARK: Emitter Configuration

    private func createEmitter(for effect: ThemeOverlayEffect) -> SKEmitterNode {
        let e = SKEmitterNode()
        e.particleTexture = particleTexture(for: effect)
        e.particleBlendMode = .alpha
        e.numParticlesToEmit = 0
        e.particleColorBlendFactor = 1.0

        let hp = lowPowerMode

        switch effect {
        case .rain:
            e.particleBirthRate = CGFloat(hp ? 7 : 15)
            e.particleLifetime = 3.5; e.particleLifetimeRange = 0.5
            e.particlePositionRange = CGVector(dx: GK.worldWidth, dy: 0)
            e.emissionAngle = 4.62; e.emissionAngleRange = 0.05
            e.particleSpeed = 211; e.particleSpeedRange = 35
            e.particleScale = 1.0
            e.particleAlpha = 0.35; e.particleAlphaRange = 0.1; e.particleAlphaSpeed = 0
            e.particleColor = UIColor(red: 0.65, green: 0.80, blue: 0.88, alpha: 1.0)

        case .snow:
            e.particleBirthRate = CGFloat(hp ? 0.8 : 1.5)
            e.particleLifetime = 28; e.particleLifetimeRange = 5
            e.particlePositionRange = CGVector(dx: GK.worldWidth, dy: 40)
            e.emissionAngle = 4.71; e.emissionAngleRange = 0.5
            e.particleSpeed = 25; e.particleSpeedRange = 4
            e.particleScale = 1.0
            e.particleAlpha = 0.75; e.particleAlphaRange = 0.15; e.particleAlphaSpeed = -0.01
            e.particleColor = UIColor.white

        case .embers:
            e.particleBirthRate = CGFloat(hp ? 0.8 : 1.5)
            e.particleLifetime = 22; e.particleLifetimeRange = 5
            e.particlePositionRange = CGVector(dx: GK.worldWidth, dy: 20)
            e.emissionAngle = 1.57; e.emissionAngleRange = 0.5
            e.particleSpeed = 30; e.particleSpeedRange = 6
            e.particleScale = 1.0
            e.particleAlpha = 0.75; e.particleAlphaRange = 0.2; e.particleAlphaSpeed = -0.02
            e.particleColor = UIColor(red: 1.0, green: 0.45, blue: 0.12, alpha: 1.0)

        case .bubbles:
            e.particleBirthRate = CGFloat(hp ? 0.6 : 1.2)
            e.particleLifetime = 22; e.particleLifetimeRange = 5
            e.particlePositionRange = CGVector(dx: GK.worldWidth, dy: 20)
            e.emissionAngle = 1.57; e.emissionAngleRange = 0.45
            e.particleSpeed = 28; e.particleSpeedRange = 8
            e.particleScale = 1.0
            e.particleAlpha = 0.45; e.particleAlphaRange = 0.15; e.particleAlphaSpeed = -0.02
            e.particleColor = UIColor(red: 0.75, green: 0.95, blue: 1.0, alpha: 1.0)

        case .dust:
            e.particleBirthRate = CGFloat(hp ? 0.4 : 0.8)
            e.particleLifetime = 25; e.particleLifetimeRange = 6
            e.particlePositionRange = CGVector(dx: GK.worldWidth, dy: 200)
            e.emissionAngle = 2.95; e.emissionAngleRange = 0.1
            e.particleSpeed = 16; e.particleSpeedRange = 3
            e.particleScale = 1.0
            e.particleAlpha = 0.35; e.particleAlphaRange = 0.15; e.particleAlphaSpeed = -0.005
            e.particleColor = UIColor(red: 0.95, green: 0.78, blue: 0.45, alpha: 1.0)

        case .petals:
            e.particleBirthRate = CGFloat(hp ? 1.5 : 3)
            e.particleLifetime = 7; e.particleLifetimeRange = 2
            e.particlePositionRange = CGVector(dx: GK.worldWidth, dy: 300)
            e.emissionAngle = 3.36; e.emissionAngleRange = 0.35
            e.particleSpeed = 38; e.particleSpeedRange = 10
            e.particleScale = 1.0
            e.particleAlpha = 0.85; e.particleAlphaRange = 0.1; e.particleAlphaSpeed = -0.02
            e.particleColor = UIColor(red: 1.0, green: 0.55, blue: 0.72, alpha: 1.0)
            e.particleRotationSpeed = 1.2

        case .seaSpray:
            e.particleBirthRate = CGFloat(hp ? 0.6 : 1.2)
            e.particleLifetime = 20; e.particleLifetimeRange = 5
            e.particlePositionRange = CGVector(dx: GK.worldWidth, dy: 20)
            e.emissionAngle = 2.54; e.emissionAngleRange = 0.3
            e.particleSpeed = 35; e.particleSpeedRange = 12
            e.particleScale = 1.0
            e.particleAlpha = 0.45; e.particleAlphaRange = 0.15; e.particleAlphaSpeed = -0.01
            e.particleColor = UIColor(red: 0.75, green: 0.92, blue: 0.95, alpha: 1.0)

        case .stars:
            e.particleBirthRate = CGFloat(hp ? 0.3 : 0.6)
            e.particleLifetime = 60; e.particleLifetimeRange = 15
            e.particlePositionRange = CGVector(dx: GK.worldWidth, dy: GK.worldHeight - GK.groundHeight)
            e.emissionAngle = 3.14; e.emissionAngleRange = 0
            e.particleSpeed = 2; e.particleSpeedRange = 0.5
            e.particleScale = 1.0
            e.particleAlpha = 0.65; e.particleAlphaRange = 0.2; e.particleAlphaSpeed = 0
            e.particleColor = UIColor.white
            // Twinkling via alpha sequence
            let seq = SKKeyframeSequence(keyframeValues: [0.3, 1.0, 0.3, 1.0, 0.3] as [NSNumber],
                                          times: [0, 0.25, 0.5, 0.75, 1])
            seq.repeatMode = .loop
            e.particleAlphaSequence = seq

        case .shootingStar:
            e.particleBirthRate = CGFloat(hp ? 0.03 : 0.06)
            e.particleLifetime = 3; e.particleLifetimeRange = 1
            e.particlePositionRange = CGVector(dx: 20, dy: 40)
            e.emissionAngle = 3.46; e.emissionAngleRange = 0.05
            e.particleSpeed = 221; e.particleSpeedRange = 10
            e.particleScale = 1.0
            e.particleAlpha = 0.58; e.particleAlphaRange = 0.1; e.particleAlphaSpeed = -0.1
            e.particleColor = UIColor(red: 0.85, green: 0.92, blue: 1.0, alpha: 1.0)
            e.particleRotation = -0.35

        case .mist:
            break
        }

        return e
    }

    private func emitterOrigin(for effect: ThemeOverlayEffect) -> CGPoint {
        switch effect {
        case .rain, .snow, .petals, .shootingStar:
            return CGPoint(x: GK.worldWidth / 2, y: GK.worldHeight + 20)
        case .embers, .bubbles, .seaSpray:
            return CGPoint(x: GK.worldWidth / 2, y: GK.groundHeight + 5)
        case .dust:
            return CGPoint(x: GK.worldWidth / 2, y: GK.groundHeight + 5)
        case .stars:
            return CGPoint(x: GK.worldWidth / 2, y: GK.groundHeight + (GK.worldHeight - GK.groundHeight) / 2)
        case .mist:
            return .zero
        }
    }

    private func particleTexture(for effect: ThemeOverlayEffect) -> SKTexture {
        let size: CGSize
        switch effect {
        case .rain:         size = CGSize(width: 1, height: 18)
        case .snow:         size = CGSize(width: 3, height: 3)
        case .embers:       size = CGSize(width: 3, height: 3)
        case .bubbles:      size = CGSize(width: 4, height: 4)
        case .dust:         size = CGSize(width: 2, height: 2)
        case .petals:       size = CGSize(width: 5, height: 3)
        case .seaSpray:     size = CGSize(width: 2, height: 2)
        case .stars:        size = CGSize(width: 2, height: 2)
        case .shootingStar: size = CGSize(width: 48, height: 2)
        case .mist:         size = CGSize(width: 2, height: 2)
        }
        let key = "\(Int(size.width))x\(Int(size.height))"
        if let tex = emitterTextureCache[key] { return tex }
        let img = UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
        let tex = SKTexture(image: img)
        tex.filteringMode = .nearest
        emitterTextureCache[key] = tex
        return tex
    }

    private func setupMistBands() {
        for i in 0..<3 {
            let band = SKSpriteNode(color: UIColor(white: 0.75, alpha: 0.08),
                                    size: CGSize(width: GK.worldWidth * 1.4, height: 46))
            band.anchorPoint = CGPoint(x: 0, y: 0.5)
            band.position = CGPoint(x: CGFloat(i) * GK.worldWidth * 0.55,
                                    y: GK.groundHeight + 150 + CGFloat(i) * 70)
            band.zPosition = -18
            backgroundLayer.addChild(band)

            let move = SKAction.moveBy(x: -GK.worldWidth * 0.55, y: 0, duration: 12 + Double(i) * 4)
            let reset = SKAction.moveBy(x: GK.worldWidth * 0.55, y: 0, duration: 0)
            band.run(.repeatForever(.sequence([move, reset])))
        }
    }

    private func zPosition(for effect: ThemeOverlayEffect) -> CGFloat {
        switch effect {
        case .stars:
            return -75
        case .shootingStar:
            return -74
        case .mist:
            return -18
        default:
            return -10
        }
    }

    // MARK: - Sky Gradient (procedural safety net)

    private func setupSkyGradient() {
        let skyNode = SKSpriteNode(color: .clear,
                                    size: CGSize(width: GK.worldWidth, height: GK.worldHeight))
        skyNode.position = CGPoint(x: GK.worldWidth / 2, y: GK.worldHeight / 2)
        skyNode.zPosition = -100
        skyNode.texture = createSkyGradientTexture()
        skyNode.blendMode = .replace
        backgroundLayer.addChild(skyNode)
    }

    private func createSkyGradientTexture() -> SKTexture {
        let size = CGSize(width: 1, height: Int(GK.worldHeight))
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let colors = theme.gradientColors.map { UIColor($0).cgColor } as CFArray
            let space = CGColorSpaceCreateDeviceRGB()
            guard let gradient = CGGradient(colorsSpace: space, colors: colors, locations: nil) else { return }
            ctx.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: size.height),
                end:   CGPoint(x: 0, y: 0),
                options: []
            )
        }
        let tex = SKTexture(image: image)
        tex.filteringMode = .linear
        return tex
    }
}
