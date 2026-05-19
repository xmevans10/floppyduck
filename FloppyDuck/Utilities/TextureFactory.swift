import SpriteKit
import UIKit

/// Generates all game textures programmatically using pixel-art style rendering.
/// Park theme with round mallard duck matching Flappy Bird proportions.
final class TextureFactory: @unchecked Sendable {
    static let shared = TextureFactory()

    /// Maximum textures to keep in cache before triggering eviction.
    /// The themed background pass pre-warms substantially more large parallax textures,
    /// so keep a little extra headroom to avoid churning the selected theme on first play.
    private static let maxCacheSize = 260

    private init() {
        // Clear cache on memory warning (iOS background pressure)
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.cacheLock.lock()
            defer { self?.cacheLock.unlock() }
            self?.cache.removeAll()
            self?.cacheOrder.removeAll()
            self?.uiImageCache.removeAll()
        }
    }

    private var cache: [String: SKTexture] = [:]
    private var cacheOrder: [String] = []   // LRU eviction order
    private var uiImageCache: [String: UIImage] = [:]
    private let cacheLock = NSLock()

    /// Thread-safe cache read.
    private func cachedTexture(forKey key: String) -> SKTexture? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return cache[key]
    }


    /// Invalidates only pipe-related cached textures so a new pipe skin takes effect.
    func invalidatePipeCache() {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        let pipeKeys = cache.keys.filter { $0.hasPrefix("pipe_") || $0.hasPrefix("pipecap") }
        for key in pipeKeys {
            cache.removeValue(forKey: key)
            cacheOrder.removeAll { $0 == key }
        }
    }

    /// Whether pre-warming has completed.
    private var _isPreWarmed: Bool = false
    private let preWarmLock = NSLock()
    private(set) var isPreWarmed: Bool {
        get { preWarmLock.lock(); defer { preWarmLock.unlock() }; return _isPreWarmed }
        set { preWarmLock.lock(); defer { preWarmLock.unlock() }; _isPreWarmed = newValue }
    }

    /// Pre-generates the most commonly used textures on a background thread.
    /// Call early (e.g. during SplashView) to avoid hitches on first game start.
    @MainActor
    func preWarm() {
        guard !isPreWarmed else { return }
        // Capture current selections on main thread before dispatching
        let currentSkin = SkinManager.shared.selectedSkin
        let currentPipeSkin = PipeSkinManager.shared.selectedSkin
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            // Pipes (still procedurally rendered)
            _ = pipeTexture(height: 300, skinOverride: .classic)
            _ = pipeCapTexture(skinOverride: .classic)

            // Theme textures: pre-generated PNG layers per theme from asset catalog.
            // UIImage(named:) uses memory-mapped files — fast and cache-friendly.
            // Warm into SKTexture cache to avoid first-frame hitches.
            // Asset names are derived from the recipe catalog — no hardcoded suffixes.
            for theme in BackgroundTheme.allCases {
                for assetName in theme.recipeAssetNames {
                    if UIImage(named: assetName) != nil {
                        _ = self.themedLayerTexture(theme: theme, assetName: assetName)
                    }
                }
            }

            // Pre-warm the player's currently equipped skin textures.
            // Without this, the first flap in-game triggers a UIGraphicsImageRenderer
            // render on the main thread — a hitch right when input latency matters most.
            for phase in 0...2 {
                _ = self.skinDuckTexture(skin: currentSkin, wingPhase: phase)
                _ = self.skinBotDuckTexture(skin: currentSkin, wingPhase: phase)
            }

            // Pre-warm the player's currently equipped pipe skin textures.
            _ = self.pipeTexture(height: 300, skinOverride: currentPipeSkin)
            _ = self.pipeCapTexture(skinOverride: currentPipeSkin)

            // Pre-warm common power-up glow presets (shield, magnet, debuff).
            // Each first-call triggers a UIGraphicsImageRenderer render.
            _ = self.glowCircleTexture(radius: 40, color: UIColor(red: 0.3, green: 1.0, blue: 0.3, alpha: 0.65))
            _ = self.glowCircleTexture(radius: 80, color: UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 0.6))
            _ = self.glowCircleTexture(radius: 30, color: UIColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 0.65))

            // Pre-warm sky gradient textures for all themes.
            // Each first-call triggers UIGraphicsImageRenderer on the background
            // thread; without this, the first game's ParallaxManager.setup() blocks
            // the main thread for ~12-20ms per gradient render.
            for theme in BackgroundTheme.allCases {
                _ = self.skyGradientTexture(theme: theme)
            }

            DispatchQueue.main.async {
                self.isPreWarmed = true
            }
        }
    }

    /// Store a texture in cache with LRU eviction when over capacity.
    private func cacheStore(_ key: String, _ tex: SKTexture) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        cache[key] = tex
        cacheOrder.append(key)
        // Evict oldest entries when over capacity
        while cache.count > Self.maxCacheSize, let oldest = cacheOrder.first {
            cacheOrder.removeFirst()
            cache.removeValue(forKey: oldest)
        }
    }

    private func cachedUIImage(forKey key: String, make: () -> UIImage) -> UIImage {
        cacheLock.lock()
        if let cached = uiImageCache[key] {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()

        let image = make()

        cacheLock.lock()
        uiImageCache[key] = image
        cacheLock.unlock()
        return image
    }



    /// Pipe body with pixel border, coloured by the active pipe skin.
    /// Pre-renders one master texture; subsequent calls crop a sub-region — no per-height rendering.
    /// Pass `skinOverride` when calling off the main thread (e.g. preWarm).
    func pipeTexture(height: CGFloat, skinOverride: PipeSkin? = nil) -> SKTexture {
        let skin: PipeSkin
        if let skinOverride = skinOverride {
            skin = skinOverride
        } else {
            skin = DispatchQueue.main.sync { PipeSkinManager.shared.selectedSkin }
        }
        let masterKey = "pipe_master_\(skin.rawValue)"
        let masterTex: SKTexture
        if let cached = cachedTexture(forKey: masterKey) {
            masterTex = cached
        } else {
            let tex = SKTexture(image: renderPipe(width: GK.pipeWidth, height: GK.worldHeight, skin: skin))
            tex.filteringMode = .nearest
            cacheStore(masterKey, tex)
            masterTex = tex
        }
        // Crop from bottom of master texture (unit coords, origin bottom-left)
        let fraction = min(height / GK.worldHeight, 1.0)
        let cropped = SKTexture(rect: CGRect(x: 0, y: 0, width: 1, height: fraction), in: masterTex)
        cropped.filteringMode = .nearest
        return cropped
    }

    /// Pipe cap with lip, coloured by the active pipe skin.
    /// Pass `skinOverride` when calling off the main thread (e.g. preWarm).
    func pipeCapTexture(skinOverride: PipeSkin? = nil) -> SKTexture {
        let skin: PipeSkin
        if let skinOverride = skinOverride {
            skin = skinOverride
        } else {
            skin = DispatchQueue.main.sync { PipeSkinManager.shared.selectedSkin }
        }
        let key = "pipecap_\(skin.rawValue)"
        if let cached = cachedTexture(forKey: key) { return cached }
        let tex = SKTexture(image: renderPipeCap(skin: skin))
        tex.filteringMode = .nearest
        cacheStore(key, tex)
        return tex
    }






    /// UIImage of duck for SwiftUI views (classic only — use skinDuckUIImage for skins)
    func duckUIImage(pixelScale: CGFloat = 3.0) -> UIImage {
        cachedUIImage(forKey: "ui_duck_\(Int(pixelScale * 100))") {
            renderMallardDuck(wingPhase: 1, pixelSize: pixelScale)
        }
    }

    /// UIImage of pixel cloud for SwiftUI home background
    func cloudUIImage() -> UIImage {
        cachedUIImage(forKey: "ui_cloud") {
            renderPixelCloud()
        }
    }

    /// UIImage preview of a pipe skin for shop / collection cards.
    func pipeSkinPreviewUIImage(skin: PipeSkin, width: CGFloat = 30, height: CGFloat = 80) -> UIImage {
        cachedUIImage(forKey: "ui_pipe_\(skin.rawValue)_\(Int(width * 100))_\(Int(height * 100))") {
            renderPipe(width: width, height: height, skin: skin)
        }
    }

    /// UIImage preview of a pipe cap for shop / collection cards.
    func pipeSkinCapPreviewUIImage(skin: PipeSkin) -> UIImage {
        cachedUIImage(forKey: "ui_pipe_cap_\(skin.rawValue)") {
            renderPipeCap(skin: skin)
        }
    }

    // MARK: - Performance Textures

    /// Pre-rendered glow circle — replaces SKShapeNode glow rings on power-ups
    /// and shields.  Returns a soft radial glow texture.
    func glowCircleTexture(radius: CGFloat, color: UIColor) -> SKTexture {
        let r = Int(radius)
        let key = "glow_\(r)_\(color.description.hashValue)"
        if let cached = cachedTexture(forKey: key) { return cached }
        let tex = SKTexture(image: renderGlowCircle(radius: radius, color: color))
        tex.filteringMode = .linear
        cacheStore(key, tex)
        return tex
    }

    // MARK: - Glow Circle Rendering

    private func renderGlowCircle(radius: CGFloat, color: UIColor) -> UIImage {
        let padding: CGFloat = 4
        let ps: CGFloat = 2  // pixel size for 8-bit stepped look
        let size = CGSize(width: (radius + padding) * 2, height: (radius + padding) * 2)
        let cx = size.width / 2
        let cy = size.height / 2

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let c = ctx.cgContext
            var cr: CGFloat = 0, cg: CGFloat = 0, cb: CGFloat = 0, ca: CGFloat = 0
            color.getRed(&cr, green: &cg, blue: &cb, alpha: &ca)

            // Inner fill — pixelated diamond/octagon shape
            let fillColor = UIColor(red: cr, green: cg, blue: cb, alpha: 0.20)
            c.setFillColor(fillColor.cgColor)
            let innerR = radius - ps
            var py = cy - innerR
            while py <= cy + innerR {
                let dy = abs(py - cy)
                let halfW = innerR * (1.0 - dy / innerR * 0.35)  // slight diamond taper
                let snapW = floor(halfW / ps) * ps
                var px = cx - snapW
                while px <= cx + snapW {
                    c.fill(CGRect(x: floor(px / ps) * ps, y: floor(py / ps) * ps, width: ps, height: ps))
                    px += ps
                }
                py += ps
            }

            // Outer pixel ring — stepped circle outline
            let ringColor = UIColor(red: cr, green: cg, blue: cb, alpha: 0.55)
            c.setFillColor(ringColor.cgColor)
            let steps = Int(2 * .pi * radius / ps)
            for i in 0..<steps {
                let angle = CGFloat(i) / CGFloat(steps) * 2 * .pi
                let px = floor((cx + cos(angle) * radius) / ps) * ps
                let py = floor((cy + sin(angle) * radius) / ps) * ps
                c.fill(CGRect(x: px, y: py, width: ps, height: ps))
            }

            // Corner highlight pixel (top-left sparkle)
            let spark = UIColor(red: min(cr + 0.3, 1), green: min(cg + 0.3, 1), blue: min(cb + 0.3, 1), alpha: 0.4)
            c.setFillColor(spark.cgColor)
            let sparkAngle: CGFloat = -.pi * 0.75
            let spx = floor((cx + cos(sparkAngle) * (radius - ps)) / ps) * ps
            let spy = floor((cy + sin(sparkAngle) * (radius - ps)) / ps) * ps
            c.fill(CGRect(x: spx, y: spy, width: ps, height: ps))
        }
    }


    // MARK: - Themed Parallax Textures

    /// Load any themed layer texture from the asset catalog.
    /// Asset names are derived from `ThemeRecipeCatalog`.
    func themedLayerTexture(theme: BackgroundTheme, assetName: String) -> SKTexture {
        if let cached = cachedTexture(forKey: assetName) { return cached }
        guard let image = UIImage(named: assetName) else {
            fatalError("Missing asset: \(assetName)")
        }
        let tex = SKTexture(image: image)
        tex.filteringMode = .nearest
        cacheStore(assetName, tex)
        return tex
    }

    // MARK: - Skinned Duck API

    /// Duck texture for any skin (SpriteKit).
    func skinDuckTexture(skin: DuckSkin, wingPhase: Int) -> SKTexture {
        let key = "skin_\(skin.rawValue)_\(wingPhase)"
        if let cached = cachedTexture(forKey: key) { return cached }
        let tex = SKTexture(image: renderSkinnedDuck(skin: skin, wingPhase: wingPhase))
        tex.filteringMode = .nearest
        cacheStore(key, tex)
        return tex
    }

    /// Ghost/bot version of any skin.
    func skinBotDuckTexture(skin: DuckSkin, wingPhase: Int) -> SKTexture {
        let key = "skinbot_\(skin.rawValue)_\(wingPhase)"
        if let cached = cachedTexture(forKey: key) { return cached }
        let tex = SKTexture(image: renderSkinnedDuck(skin: skin, wingPhase: wingPhase, ghost: true))
        tex.filteringMode = .nearest
        cacheStore(key, tex)
        return tex
    }

    /// UIImage of a skinned duck for SwiftUI (shop previews, home mascot).
    func skinDuckUIImage(skin: DuckSkin, pixelScale: CGFloat = 7.0) -> UIImage {
        cachedUIImage(forKey: "ui_skin_\(skin.rawValue)_\(Int(pixelScale * 100))") {
            renderSkinnedDuck(skin: skin, wingPhase: 1, pixelSize: pixelScale)
        }
    }


    /// Bread currency icon for SwiftUI (cached per scale)
    func breadUIImage(pixelScale: CGFloat = 4.0) -> UIImage {
        cachedUIImage(forKey: "ui_bread_\(Int(pixelScale * 100))") {
            renderBread(pixelSize: pixelScale)
        }
    }


    // MARK: - Mallard Duck (Pixel Art — FB round proportions)

    /// Round mallard duck matching Flappy Bird body shape.
    /// 16 wide × 11 tall pixel grid. Green head, white collar, chestnut breast, gray body.
    private func renderMallardDuck(wingPhase: Int, pixelSize: CGFloat = 3.0, ghost: Bool = false) -> UIImage {
        let gridW = 16
        let gridH = 11
        let imgSize = CGSize(width: CGFloat(gridW) * pixelSize, height: CGFloat(gridH) * pixelSize)

        // Mallard palette
        let G = UIColor(red: 0.08, green: 0.42, blue: 0.22, alpha: 1)  // dark green (head)
        let g = UIColor(red: 0.15, green: 0.58, blue: 0.35, alpha: 1)  // light green (highlight)
        let W = UIColor.white                                            // white (eye, collar)
        let B = UIColor.black                                            // black (outline, pupil)
        let R = UIColor(red: 0.55, green: 0.22, blue: 0.10, alpha: 1)  // chestnut (breast)
        let A = UIColor(red: 0.58, green: 0.58, blue: 0.58, alpha: 1)  // gray (body)
        let a = UIColor(red: 0.72, green: 0.72, blue: 0.72, alpha: 1)  // light gray
        let O = UIColor(red: 0.93, green: 0.65, blue: 0.10, alpha: 1)  // orange (bill)
        let o = UIColor(red: 0.80, green: 0.55, blue: 0.08, alpha: 1)  // darker bill tip
        let U = UIColor(red: 0.15, green: 0.30, blue: 0.70, alpha: 1)  // blue (speculum)
        let u = UIColor(red: 0.25, green: 0.45, blue: 0.85, alpha: 1)  // light blue
        let C = UIColor.clear

        // Ghost tint: shift green → red for bot duck
        let gG = ghost ? UIColor(red: 0.42, green: 0.12, blue: 0.12, alpha: 1) : G
        let gg = ghost ? UIColor(red: 0.55, green: 0.18, blue: 0.18, alpha: 1) : g

        // Pixel grid — round body, beak right, FB proportions
        var grid: [[UIColor]] = [
            // Row 0: top of head
            [C,C,C,C,B,B,B,B,C,C,C,C,C,C,C,C],
            // Row 1: head
            [C,C,C,B,gG,gG,gg,gG,B,C,C,C,C,C,C,C],
            // Row 2: head wider
            [C,C,B,gG,gG,gg,gG,gG,gG,B,C,C,C,C,C,C],
            // Row 3: head with eye
            [C,B,gG,gG,gg,gG,W,W,gG,gG,B,C,C,C,C,C],
            // Row 4: pupil + beak start
            [C,B,gG,gG,gG,gG,B,C,gG,gG,B,B,B,B,C,C],
            // Row 5: full beak
            [B,gG,gG,gG,gG,gG,gG,gG,gG,gG,B,O,O,o,B,C],
            // Row 6: collar + beak bottom
            [B,W,W,gG,gG,gG,gG,gG,gG,B,O,O,O,B,C,C],
            // Row 7: breast + wing speculum
            [B,R,R,W,A,U,u,A,a,A,B,B,C,C,C,C],
            // Row 8: body
            [C,B,R,A,A,A,a,A,A,B,C,C,C,C,C,C],
            // Row 9: lower body
            [C,C,B,A,A,a,A,A,B,C,C,C,C,C,C,C],
            // Row 10: bottom
            [C,C,C,B,B,B,B,B,C,C,C,C,C,C,C,C],
        ]

        // Wing animation — move speculum
        if wingPhase == 0 {
            // Wing up — speculum shifts to row 5-6
            grid[5][5] = U; grid[5][6] = u; grid[5][7] = U
            grid[7][5] = A; grid[7][6] = A  // clear default position
        } else if wingPhase == 2 {
            // Wing down — speculum shifts to row 9
            grid[7][5] = A; grid[7][6] = A  // clear default position
            grid[9][4] = U; grid[9][5] = u
        }

        let alpha: CGFloat = ghost ? 0.65 : 1.0

        let renderer = UIGraphicsImageRenderer(size: imgSize)
        return renderer.image { ctx in
            for row in 0..<gridH {
                for col in 0..<gridW {
                    let color = grid[row][col]
                    guard color != UIColor.clear else { continue }
                    color.withAlphaComponent(alpha).setFill()
                    ctx.fill(CGRect(
                        x: CGFloat(col) * pixelSize,
                        y: CGFloat(row) * pixelSize,
                        width: pixelSize,
                        height: pixelSize
                    ))
                }
            }
        }
    }

    // MARK: - Bread (Currency Icon)

    private func renderBread(pixelSize: CGFloat = 3.0) -> UIImage {
        let gridW = 10
        let gridH = 8
        let imgSize = CGSize(width: CGFloat(gridW) * pixelSize, height: CGFloat(gridH) * pixelSize)

        let B = UIColor.black
        let L = UIColor(red: 0.85, green: 0.68, blue: 0.30, alpha: 1)
        let D = UIColor(red: 0.65, green: 0.45, blue: 0.18, alpha: 1)
        let I = UIColor(red: 0.95, green: 0.88, blue: 0.60, alpha: 1)
        let H = UIColor(red: 0.98, green: 0.92, blue: 0.72, alpha: 1)
        let C = UIColor.clear

        let grid: [[UIColor]] = [
            [C,C,C,B,B,B,B,C,C,C],
            [C,C,B,L,L,L,L,B,C,C],
            [C,B,L,H,L,L,D,L,B,C],
            [B,L,L,H,I,I,D,D,L,B],
            [B,L,I,I,I,I,I,D,L,B],
            [B,D,I,I,I,I,D,D,D,B],
            [C,B,D,D,D,D,D,D,B,C],
            [C,C,B,B,B,B,B,B,C,C],
        ]

        let renderer = UIGraphicsImageRenderer(size: imgSize)
        return renderer.image { ctx in
            for row in 0..<gridH {
                for col in 0..<gridW {
                    let color = grid[row][col]
                    guard color != UIColor.clear else { continue }
                    color.setFill()
                    ctx.fill(CGRect(
                        x: CGFloat(col) * pixelSize,
                        y: CGFloat(row) * pixelSize,
                        width: pixelSize,
                        height: pixelSize
                    ))
                }
            }
        }
    }

    // MARK: - Pipes

    private func renderPipe(width: CGFloat, height: CGFloat, skin: PipeSkin = .classic) -> UIImage {
        if skin == .sandCastle {
            return renderSandCastlePipe(width: width, height: height, skin: skin)
        }
        return renderThemedPipe(width: width, height: height, skin: skin)
    }

    private func renderPipeCap(skin: PipeSkin = .classic) -> UIImage {
        if skin == .sandCastle {
            return renderSandCastlePipeCap(skin: skin)
        }
        return renderThemedPipeCap(skin: skin)
    }

    private func renderThemedPipe(width: CGFloat, height: CGFloat, skin: PipeSkin) -> UIImage {
        let size = CGSize(width: width, height: height)
        let borderW: CGFloat = 3
        let highlightW: CGFloat = 6

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let c = ctx.cgContext
            c.interpolationQuality = .none

            drawPipeBase(in: c, size: size, skin: skin, borderW: borderW, highlightW: highlightW)

            switch skin {
            case .candy:
                drawCandyPipeDetails(in: c, width: width, height: height, borderW: borderW)
            case .bamboo:
                drawBambooPipeDetails(in: c, width: width, height: height, borderW: borderW)
            case .steel:
                drawSteelPipeDetails(in: c, width: width, height: height, borderW: borderW)
            case .pixel:
                drawRetroPipeDetails(in: c, width: width, height: height, borderW: borderW)
            case .neon:
                drawNeonPipeDetails(in: c, width: width, height: height, borderW: borderW)
            case .royal:
                drawRoyalPipeDetails(in: c, width: width, height: height, borderW: borderW)
            case .gold:
                drawGoldPipeDetails(in: c, width: width, height: height, borderW: borderW)
            case .lava:
                drawLavaPipeDetails(in: c, width: width, height: height, borderW: borderW)
            case .ice:
                drawIcePipeDetails(in: c, width: width, height: height, borderW: borderW)
            case .toxic:
                drawToxicPipeDetails(in: c, width: width, height: height, borderW: borderW)
            case .classic:
                drawBreadboxPipeDetails(in: c, width: width, height: height, borderW: borderW)
            case .turret, .cactus, .arcade, .trafficCone, .breadLoaf,
                 .sodaCan, .mailbox, .totem, .castleTower, .pharaoh,
                 .submarine, .rocket, .mushroom, .crystal, .bone,
                 .bookshelf:
                drawExpandedPipeDetails(in: c, width: width, height: height, borderW: borderW, skin: skin)
            case .sandCastle:
                break
            }
        }
    }

    private func renderThemedPipeCap(skin: PipeSkin) -> UIImage {
        let capW: CGFloat = GK.pipeWidth + 10
        let capH: CGFloat = 30
        let borderW: CGFloat = 3
        let size = CGSize(width: capW, height: capH)

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let c = ctx.cgContext
            c.interpolationQuality = .none

            c.setFillColor(skin.borderColor.cgColor)
            c.fill(CGRect(origin: .zero, size: size))

            let inner = CGRect(x: borderW, y: borderW, width: capW - borderW * 2, height: capH - borderW * 2)
            c.setFillColor(skin.bodyColor.cgColor)
            c.fill(inner)

            c.setFillColor(skin.highlightColor.cgColor)
            c.fill(CGRect(x: borderW + 3, y: borderW, width: 6, height: capH - borderW * 2))
            c.setFillColor(skin.shadowColor.cgColor)
            c.fill(CGRect(x: capW - borderW - 8, y: borderW, width: 6, height: capH - borderW * 2))

            switch skin {
            case .candy:
                drawDiagonalStripes(in: c, color: UIColor.white.withAlphaComponent(0.55), width: capW, height: capH, spacing: 16)
            case .bamboo:
                drawHorizontalBand(in: c, y: 5, width: capW, color: skin.borderColor, height: 3)
                drawHorizontalBand(in: c, y: capH - 8, width: capW, color: skin.borderColor, height: 3)
            case .steel:
                drawRivetRow(in: c, y: 8, width: capW, color: skin.borderColor)
                drawRivetRow(in: c, y: capH - 11, width: capW, color: UIColor(red: 0.78, green: 0.80, blue: 0.84, alpha: 1))
            case .pixel:
                drawPixelNotches(in: c, width: capW, height: capH, color: skin.highlightColor)
            case .neon:
                c.setFillColor(UIColor(red: 0.20, green: 1.00, blue: 0.95, alpha: 1).cgColor)
                c.fill(CGRect(x: 10, y: 13, width: capW - 20, height: 3))
            case .royal:
                drawTinyGems(in: c, y: 10, width: capW)
            case .gold:
                drawGoldBrickLines(in: c, width: capW, height: capH, borderW: borderW)
            case .lava:
                drawLavaCracks(in: c, width: capW, height: capH, borderW: borderW)
            case .ice:
                drawIceShardLines(in: c, width: capW, height: capH, borderW: borderW)
            case .toxic:
                drawHazardBands(in: c, width: capW, height: capH, borderW: borderW)
            case .classic:
                drawBreadboxCapDetails(in: c, width: capW, height: capH, borderW: borderW)
            case .turret, .cactus, .arcade, .trafficCone, .breadLoaf,
                 .sodaCan, .mailbox, .totem, .castleTower, .pharaoh,
                 .submarine, .rocket, .mushroom, .crystal, .bone,
                 .bookshelf:
                drawExpandedCapDetails(in: c, width: capW, height: capH, borderW: borderW, skin: skin)
            case .sandCastle:
                break
            }
        }
    }

    private func drawPipeBase(in c: CGContext, size: CGSize, skin: PipeSkin, borderW: CGFloat, highlightW: CGFloat) {
        c.setFillColor(skin.borderColor.cgColor)
        c.fill(CGRect(origin: .zero, size: size))

        let body = CGRect(x: borderW, y: 0, width: size.width - borderW * 2, height: size.height)
        c.setFillColor(skin.bodyColor.cgColor)
        c.fill(body)

        c.setFillColor(skin.highlightColor.cgColor)
        c.fill(CGRect(x: borderW + 3, y: 0, width: highlightW, height: size.height))

        c.setFillColor(skin.shadowColor.cgColor)
        c.fill(CGRect(x: size.width - borderW - highlightW - 1, y: 0, width: highlightW, height: size.height))
    }

    private func drawCandyPipeDetails(in c: CGContext, width: CGFloat, height: CGFloat, borderW: CGFloat) {
        drawDiagonalStripes(in: c, color: UIColor.white.withAlphaComponent(0.52), width: width, height: height, spacing: 28)
        c.setFillColor(UIColor(red: 0.70, green: 0.12, blue: 0.25, alpha: 1).cgColor)
        var y: CGFloat = 18
        while y < height {
            c.fill(CGRect(x: borderW, y: y, width: width - borderW * 2, height: 2))
            y += 58
        }
    }

    private func drawBambooPipeDetails(in c: CGContext, width: CGFloat, height: CGFloat, borderW: CGFloat) {
        let band = UIColor(red: 0.27, green: 0.34, blue: 0.10, alpha: 1)
        var y: CGFloat = 28
        while y < height {
            drawHorizontalBand(in: c, y: y, width: width, color: band, height: 4)
            c.setFillColor(UIColor(red: 0.82, green: 0.88, blue: 0.48, alpha: 1).cgColor)
            c.fill(CGRect(x: borderW + 7, y: y + 5, width: 5, height: 14))
            y += 64
        }
    }

    private func drawSteelPipeDetails(in c: CGContext, width: CGFloat, height: CGFloat, borderW: CGFloat) {
        let seam = UIColor(red: 0.28, green: 0.30, blue: 0.34, alpha: 1)
        var y: CGFloat = 34
        while y < height {
            c.setFillColor(seam.cgColor)
            c.fill(CGRect(x: borderW, y: y, width: width - borderW * 2, height: 2))
            drawRivetRow(in: c, y: y + 8, width: width, color: seam)
            y += 72
        }
    }

    private func drawRetroPipeDetails(in c: CGContext, width: CGFloat, height: CGFloat, borderW: CGFloat) {
        let cyan = UIColor(red: 0.10, green: 0.78, blue: 0.85, alpha: 1)
        let magenta = UIColor(red: 0.88, green: 0.18, blue: 0.70, alpha: 1)
        var y: CGFloat = 18
        var flip = false
        while y < height {
            c.setFillColor((flip ? magenta : cyan).cgColor)
            c.fill(CGRect(x: borderW + 15, y: y, width: 8, height: 8))
            c.fill(CGRect(x: width - borderW - 25, y: y + 12, width: 8, height: 8))
            flip.toggle()
            y += 48
        }
    }

    private func drawNeonPipeDetails(in c: CGContext, width: CGFloat, height: CGFloat, borderW: CGFloat) {
        let cyan = UIColor(red: 0.05, green: 1.00, blue: 0.95, alpha: 1)
        let dark = UIColor(red: 0.10, green: 0.03, blue: 0.18, alpha: 1)
        c.setFillColor(dark.cgColor)
        c.fill(CGRect(x: borderW + 14, y: 0, width: 6, height: height))
        c.setFillColor(cyan.cgColor)
        var y: CGFloat = 22
        while y < height {
            c.fill(CGRect(x: borderW + 14, y: y, width: 6, height: 18))
            c.fill(CGRect(x: width - borderW - 20, y: y + 28, width: 4, height: 14))
            y += 86
        }
    }

    private func drawRoyalPipeDetails(in c: CGContext, width: CGFloat, height: CGFloat, borderW: CGFloat) {
        let trim = UIColor(red: 0.95, green: 0.76, blue: 0.22, alpha: 1)
        var y: CGFloat = 38
        while y < height {
            c.setFillColor(trim.cgColor)
            c.fill(CGRect(x: borderW + 8, y: y, width: width - borderW * 2 - 16, height: 3))
            drawTinyGems(in: c, y: y + 10, width: width)
            y += 90
        }
    }

    private func drawGoldPipeDetails(in c: CGContext, width: CGFloat, height: CGFloat, borderW: CGFloat) {
        drawGoldBrickLines(in: c, width: width, height: height, borderW: borderW)
        c.setFillColor(UIColor(red: 1.00, green: 0.95, blue: 0.48, alpha: 1).cgColor)
        var y: CGFloat = 28
        while y < height {
            c.fill(CGRect(x: borderW + 8, y: y, width: 4, height: 12))
            c.fill(CGRect(x: borderW + 5, y: y + 4, width: 10, height: 4))
            y += 118
        }
    }

    private func drawLavaPipeDetails(in c: CGContext, width: CGFloat, height: CGFloat, borderW: CGFloat) {
        drawLavaCracks(in: c, width: width, height: height, borderW: borderW)
        c.setFillColor(UIColor(red: 1.00, green: 0.78, blue: 0.10, alpha: 1).cgColor)
        var y: CGFloat = 30
        while y < height {
            c.fill(CGRect(x: width / 2 - 2, y: y, width: 4, height: 22))
            c.fill(CGRect(x: width / 2 + 2, y: y + 18, width: 9, height: 4))
            y += 96
        }
    }

    private func drawIcePipeDetails(in c: CGContext, width: CGFloat, height: CGFloat, borderW: CGFloat) {
        drawIceShardLines(in: c, width: width, height: height, borderW: borderW)
        c.setFillColor(UIColor.white.withAlphaComponent(0.65).cgColor)
        var y: CGFloat = 22
        while y < height {
            c.fill(CGRect(x: borderW + 8, y: y, width: 4, height: 24))
            c.fill(CGRect(x: borderW + 12, y: y + 4, width: 7, height: 4))
            y += 84
        }
    }

    private func drawToxicPipeDetails(in c: CGContext, width: CGFloat, height: CGFloat, borderW: CGFloat) {
        drawHazardBands(in: c, width: width, height: height, borderW: borderW)
        let bubble = UIColor(red: 0.82, green: 1.00, blue: 0.28, alpha: 1)
        var y: CGFloat = 26
        while y < height {
            c.setFillColor(bubble.cgColor)
            c.fill(CGRect(x: borderW + 14, y: y, width: 6, height: 6))
            c.fill(CGRect(x: width - borderW - 25, y: y + 34, width: 8, height: 8))
            y += 92
        }
    }

    private func drawDiagonalStripes(in c: CGContext, color: UIColor, width: CGFloat, height: CGFloat, spacing: CGFloat) {
        c.setFillColor(color.cgColor)
        var x: CGFloat = -height
        while x < width {
            c.saveGState()
            c.translateBy(x: x, y: 0)
            c.rotate(by: -.pi / 8)
            c.fill(CGRect(x: 0, y: 0, width: 8, height: height * 2))
            c.restoreGState()
            x += spacing
        }
    }

    private func drawHorizontalBand(in c: CGContext, y: CGFloat, width: CGFloat, color: UIColor, height: CGFloat) {
        c.setFillColor(color.cgColor)
        c.fill(CGRect(x: 3, y: y, width: width - 6, height: height))
    }

    private func drawRivetRow(in c: CGContext, y: CGFloat, width: CGFloat, color: UIColor) {
        c.setFillColor(color.cgColor)
        var x: CGFloat = 10
        while x < width - 8 {
            c.fill(CGRect(x: x, y: y, width: 5, height: 5))
            x += 18
        }
    }

    private func drawPixelNotches(in c: CGContext, width: CGFloat, height: CGFloat, color: UIColor) {
        c.setFillColor(color.cgColor)
        var x: CGFloat = 8
        while x < width - 8 {
            c.fill(CGRect(x: x, y: 6, width: 6, height: 6))
            c.fill(CGRect(x: x + 6, y: height - 12, width: 6, height: 6))
            x += 18
        }
    }

    private func drawTinyGems(in c: CGContext, y: CGFloat, width: CGFloat) {
        let gem = UIColor(red: 0.25, green: 0.85, blue: 1.00, alpha: 1)
        c.setFillColor(gem.cgColor)
        c.fill(CGRect(x: width / 2 - 3, y: y, width: 6, height: 6))
        c.fill(CGRect(x: width / 2 - 1, y: y - 2, width: 2, height: 10))
    }

    private func drawGoldBrickLines(in c: CGContext, width: CGFloat, height: CGFloat, borderW: CGFloat) {
        let line = UIColor(red: 0.55, green: 0.38, blue: 0.10, alpha: 1)
        c.setFillColor(line.cgColor)
        var y: CGFloat = 20
        var offset: CGFloat = 0
        while y < height {
            c.fill(CGRect(x: borderW, y: y, width: width - borderW * 2, height: 2))
            var x: CGFloat = borderW + offset
            while x < width - borderW {
                c.fill(CGRect(x: x, y: y, width: 2, height: 20))
                x += 22
            }
            offset = offset == 0 ? 11 : 0
            y += 22
        }
    }

    private func drawLavaCracks(in c: CGContext, width: CGFloat, height: CGFloat, borderW: CGFloat) {
        let crack = UIColor(red: 0.24, green: 0.07, blue: 0.04, alpha: 1)
        c.setFillColor(crack.cgColor)
        var y: CGFloat = 18
        while y < height {
            c.fill(CGRect(x: borderW + 18, y: y, width: 4, height: 22))
            c.fill(CGRect(x: borderW + 22, y: y + 18, width: 12, height: 4))
            c.fill(CGRect(x: width - borderW - 18, y: y + 42, width: 4, height: 18))
            y += 108
        }
    }

    private func drawIceShardLines(in c: CGContext, width: CGFloat, height: CGFloat, borderW: CGFloat) {
        let line = UIColor(red: 0.14, green: 0.42, blue: 0.58, alpha: 1)
        c.setFillColor(line.cgColor)
        var y: CGFloat = 18
        while y < height {
            c.fill(CGRect(x: borderW + 22, y: y, width: 3, height: 30))
            c.fill(CGRect(x: borderW + 17, y: y + 8, width: 8, height: 3))
            c.fill(CGRect(x: width - borderW - 24, y: y + 42, width: 3, height: 26))
            y += 104
        }
    }

    private func drawHazardBands(in c: CGContext, width: CGFloat, height: CGFloat, borderW: CGFloat) {
        let dark = UIColor(red: 0.16, green: 0.22, blue: 0.05, alpha: 1)
        c.setFillColor(dark.cgColor)
        var y: CGFloat = 16
        while y < height {
            c.fill(CGRect(x: borderW, y: y, width: width - borderW * 2, height: 4))
            y += 42
        }
    }

    private func drawBreadboxPipeDetails(in c: CGContext, width: CGFloat, height: CGFloat, borderW: CGFloat) {
        let plank = UIColor(red: 0.32, green: 0.17, blue: 0.07, alpha: 1)
        let crumb = UIColor(red: 0.95, green: 0.70, blue: 0.30, alpha: 1)

        var y: CGFloat = 22
        while y < height {
            c.setFillColor(plank.cgColor)
            c.fill(CGRect(x: borderW, y: y, width: width - borderW * 2, height: 3))
            y += 42
        }

        var x: CGFloat = borderW + 16
        while x < width - borderW {
            c.setFillColor(plank.cgColor)
            c.fill(CGRect(x: x, y: 0, width: 2, height: height))
            x += 18
        }

        c.setFillColor(crumb.cgColor)
        y = 36
        while y < height {
            c.fill(CGRect(x: borderW + 10, y: y, width: 5, height: 4))
            c.fill(CGRect(x: width - borderW - 22, y: y + 18, width: 4, height: 4))
            y += 96
        }
    }

    private func drawBreadboxCapDetails(in c: CGContext, width: CGFloat, height: CGFloat, borderW: CGFloat) {
        let plank = UIColor(red: 0.32, green: 0.17, blue: 0.07, alpha: 1)
        c.setFillColor(plank.cgColor)
        c.fill(CGRect(x: borderW, y: height / 2 - 1, width: width - borderW * 2, height: 3))
        c.fill(CGRect(x: width / 2 - 1, y: borderW, width: 3, height: height - borderW * 2))
        c.setFillColor(UIColor(red: 0.95, green: 0.70, blue: 0.30, alpha: 1).cgColor)
        c.fill(CGRect(x: 12, y: 8, width: 5, height: 4))
        c.fill(CGRect(x: width - 18, y: height - 12, width: 4, height: 4))
    }

    private func drawExpandedPipeDetails(in c: CGContext, width: CGFloat, height: CGFloat, borderW: CGFloat, skin: PipeSkin) {
        switch skin {
        case .turret:
            drawSteelPipeDetails(in: c, width: width, height: height, borderW: borderW)
            drawBarrelSlots(in: c, width: width, height: height, color: UIColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1))
        case .cactus:
            drawCactusNeedles(in: c, width: width, height: height, borderW: borderW)
        case .arcade:
            drawArcadeDetails(in: c, width: width, height: height, borderW: borderW)
        case .trafficCone:
            drawTrafficConeDetails(in: c, width: width, height: height, borderW: borderW)
        case .breadLoaf:
            drawBreadLoafDetails(in: c, width: width, height: height, borderW: borderW)
        case .sodaCan:
            drawSodaCanDetails(in: c, width: width, height: height, borderW: borderW)
        case .mailbox:
            drawMailboxDetails(in: c, width: width, height: height, borderW: borderW)
        case .totem:
            drawTotemDetails(in: c, width: width, height: height, borderW: borderW)
        case .castleTower:
            drawStoneBlocks(in: c, width: width, height: height, borderW: borderW)
        case .pharaoh:
            drawPharaohDetails(in: c, width: width, height: height, borderW: borderW)
        case .submarine:
            drawSubmarineDetails(in: c, width: width, height: height, borderW: borderW)
        case .rocket:
            drawRocketDetails(in: c, width: width, height: height, borderW: borderW)
        case .mushroom:
            drawMushroomDetails(in: c, width: width, height: height, borderW: borderW)
        case .crystal:
            drawCrystalDetails(in: c, width: width, height: height, borderW: borderW)
        case .bone:
            drawBoneDetails(in: c, width: width, height: height, borderW: borderW)
        case .bookshelf:
            drawBookshelfDetails(in: c, width: width, height: height, borderW: borderW)
        default:
            break
        }
    }

    private func drawExpandedCapDetails(in c: CGContext, width: CGFloat, height: CGFloat, borderW: CGFloat, skin: PipeSkin) {
        switch skin {
        case .turret:
            drawRivetRow(in: c, y: 8, width: width, color: skin.borderColor)
            drawBarrelSlots(in: c, width: width, height: height, color: UIColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1))
        case .cactus:
            drawCactusNeedles(in: c, width: width, height: height, borderW: borderW)
        case .arcade:
            drawPixelNotches(in: c, width: width, height: height, color: UIColor(red: 1.00, green: 0.20, blue: 0.75, alpha: 1))
        case .trafficCone:
            drawTrafficConeDetails(in: c, width: width, height: height, borderW: borderW)
        case .breadLoaf:
            drawBreadLoafDetails(in: c, width: width, height: height, borderW: borderW)
        case .sodaCan:
            drawRivetRow(in: c, y: 8, width: width, color: UIColor.white.withAlphaComponent(0.55))
        case .mailbox:
            c.setFillColor(UIColor(red: 0.96, green: 0.84, blue: 0.20, alpha: 1).cgColor)
            c.fill(CGRect(x: width - 18, y: 8, width: 9, height: 6))
        case .totem:
            drawTotemFace(in: c, x: width / 2 - 10, y: 6)
        case .castleTower:
            drawStoneBlocks(in: c, width: width, height: height, borderW: borderW)
        case .pharaoh:
            drawTinyGems(in: c, y: 10, width: width)
            drawGoldBrickLines(in: c, width: width, height: height, borderW: borderW)
        case .submarine:
            drawPortholes(in: c, width: width, height: height)
        case .rocket:
            drawHazardBands(in: c, width: width, height: height, borderW: borderW)
        case .mushroom:
            drawMushroomSpots(in: c, width: width, height: height)
        case .crystal:
            drawIceShardLines(in: c, width: width, height: height, borderW: borderW)
        case .bone:
            drawBoneKnuckles(in: c, width: width, height: height, borderW: borderW)
        case .bookshelf:
            drawBookshelfDetails(in: c, width: width, height: height, borderW: borderW)
        default:
            break
        }
    }

    private func drawBarrelSlots(in c: CGContext, width: CGFloat, height: CGFloat, color: UIColor) {
        c.setFillColor(color.cgColor)
        var y: CGFloat = 28
        while y < height {
            c.fill(CGRect(x: width / 2 - 11, y: y, width: 22, height: 5))
            y += 78
        }
    }

    private func drawCactusNeedles(in c: CGContext, width: CGFloat, height: CGFloat, borderW: CGFloat) {
        let needle = UIColor(red: 0.72, green: 0.92, blue: 0.52, alpha: 1)
        c.setFillColor(needle.cgColor)
        var y: CGFloat = 18
        while y < height {
            c.fill(CGRect(x: borderW + 12, y: y, width: 2, height: 8))
            c.fill(CGRect(x: borderW + 19, y: y + 5, width: 2, height: 8))
            c.fill(CGRect(x: width - borderW - 18, y: y + 20, width: 2, height: 8))
            y += 54
        }
    }

    private func drawArcadeDetails(in c: CGContext, width: CGFloat, height: CGFloat, borderW: CGFloat) {
        let screen = UIColor(red: 0.04, green: 0.78, blue: 0.86, alpha: 1)
        let button = UIColor(red: 1.00, green: 0.20, blue: 0.72, alpha: 1)
        var y: CGFloat = 24
        while y < height {
            c.setFillColor(screen.cgColor)
            c.fill(CGRect(x: borderW + 13, y: y, width: width - borderW * 2 - 26, height: 18))
            c.setFillColor(button.cgColor)
            c.fill(CGRect(x: borderW + 16, y: y + 28, width: 6, height: 6))
            c.fill(CGRect(x: borderW + 28, y: y + 28, width: 6, height: 6))
            y += 90
        }
    }

    private func drawTrafficConeDetails(in c: CGContext, width: CGFloat, height: CGFloat, borderW: CGFloat) {
        let white = UIColor.white.withAlphaComponent(0.86)
        var y: CGFloat = 18
        while y < height {
            c.setFillColor(white.cgColor)
            c.fill(CGRect(x: borderW + 5, y: y, width: width - borderW * 2 - 10, height: 7))
            y += 46
        }
    }

    private func drawBreadLoafDetails(in c: CGContext, width: CGFloat, height: CGFloat, borderW: CGFloat) {
        let slash = UIColor(red: 1.00, green: 0.76, blue: 0.38, alpha: 1)
        var y: CGFloat = 20
        while y < height {
            c.setFillColor(slash.cgColor)
            c.fill(CGRect(x: borderW + 18, y: y, width: 18, height: 5))
            c.fill(CGRect(x: borderW + 14, y: y + 5, width: 6, height: 5))
            y += 62
        }
    }

    private func drawSodaCanDetails(in c: CGContext, width: CGFloat, height: CGFloat, borderW: CGFloat) {
        c.setFillColor(UIColor.white.withAlphaComponent(0.72).cgColor)
        c.fill(CGRect(x: borderW + 10, y: 0, width: 6, height: height))
        var y: CGFloat = 35
        while y < height {
            c.fill(CGRect(x: borderW, y: y, width: width - borderW * 2, height: 3))
            y += 80
        }
    }

    private func drawMailboxDetails(in c: CGContext, width: CGFloat, height: CGFloat, borderW: CGFloat) {
        let flag = UIColor(red: 0.96, green: 0.84, blue: 0.20, alpha: 1)
        var y: CGFloat = 34
        while y < height {
            c.setFillColor(flag.cgColor)
            c.fill(CGRect(x: width - borderW - 14, y: y, width: 10, height: 7))
            c.fill(CGRect(x: width - borderW - 6, y: y, width: 3, height: 22))
            y += 92
        }
    }

    private func drawTotemDetails(in c: CGContext, width: CGFloat, height: CGFloat, borderW: CGFloat) {
        var y: CGFloat = 28
        while y < height {
            drawTotemFace(in: c, x: width / 2 - 10, y: y)
            y += 70
        }
    }

    private func drawTotemFace(in c: CGContext, x: CGFloat, y: CGFloat) {
        let eye = UIColor(red: 0.08, green: 0.55, blue: 0.70, alpha: 1)
        let beak = UIColor(red: 0.95, green: 0.62, blue: 0.18, alpha: 1)
        c.setFillColor(eye.cgColor)
        c.fill(CGRect(x: x, y: y, width: 5, height: 5))
        c.fill(CGRect(x: x + 15, y: y, width: 5, height: 5))
        c.setFillColor(beak.cgColor)
        c.fill(CGRect(x: x + 7, y: y + 10, width: 8, height: 5))
    }

    private func drawStoneBlocks(in c: CGContext, width: CGFloat, height: CGFloat, borderW: CGFloat) {
        let line = UIColor(red: 0.28, green: 0.28, blue: 0.30, alpha: 1)
        c.setFillColor(line.cgColor)
        var y: CGFloat = 18
        var offset: CGFloat = 0
        while y < height {
            c.fill(CGRect(x: borderW, y: y, width: width - borderW * 2, height: 2))
            var x = borderW + offset
            while x < width - borderW {
                c.fill(CGRect(x: x, y: y, width: 2, height: 18))
                x += 18
            }
            offset = offset == 0 ? 9 : 0
            y += 20
        }
    }

    private func drawPharaohDetails(in c: CGContext, width: CGFloat, height: CGFloat, borderW: CGFloat) {
        drawGoldBrickLines(in: c, width: width, height: height, borderW: borderW)
        let teal = UIColor(red: 0.06, green: 0.62, blue: 0.72, alpha: 1)
        var y: CGFloat = 34
        while y < height {
            c.setFillColor(teal.cgColor)
            c.fill(CGRect(x: width / 2 - 3, y: y, width: 6, height: 16))
            c.fill(CGRect(x: width / 2 - 8, y: y + 5, width: 16, height: 4))
            y += 104
        }
    }

    private func drawSubmarineDetails(in c: CGContext, width: CGFloat, height: CGFloat, borderW: CGFloat) {
        drawRivetRow(in: c, y: 18, width: width, color: UIColor(red: 0.36, green: 0.28, blue: 0.09, alpha: 1))
        drawPortholes(in: c, width: width, height: height)
    }

    private func drawPortholes(in c: CGContext, width: CGFloat, height: CGFloat) {
        let glass = UIColor(red: 0.22, green: 0.78, blue: 0.92, alpha: 1)
        let rim = UIColor(red: 0.24, green: 0.18, blue: 0.07, alpha: 1)
        var y: CGFloat = 38
        while y < height {
            c.setFillColor(rim.cgColor)
            c.fill(CGRect(x: width / 2 - 9, y: y, width: 18, height: 18))
            c.setFillColor(glass.cgColor)
            c.fill(CGRect(x: width / 2 - 5, y: y + 4, width: 10, height: 10))
            y += 84
        }
    }

    private func drawRocketDetails(in c: CGContext, width: CGFloat, height: CGFloat, borderW: CGFloat) {
        drawHazardBands(in: c, width: width, height: height, borderW: borderW)
        let red = UIColor(red: 0.85, green: 0.12, blue: 0.15, alpha: 1)
        c.setFillColor(red.cgColor)
        var y: CGFloat = 24
        while y < height {
            c.fill(CGRect(x: borderW + 8, y: y, width: 8, height: 22))
            c.fill(CGRect(x: width - borderW - 16, y: y, width: 8, height: 22))
            y += 94
        }
    }

    private func drawMushroomDetails(in c: CGContext, width: CGFloat, height: CGFloat, borderW: CGFloat) {
        drawMushroomSpots(in: c, width: width, height: height)
        c.setFillColor(UIColor(red: 0.62, green: 0.40, blue: 0.22, alpha: 1).cgColor)
        var y: CGFloat = 40
        while y < height {
            c.fill(CGRect(x: borderW, y: y, width: width - borderW * 2, height: 3))
            y += 76
        }
    }

    private func drawMushroomSpots(in c: CGContext, width: CGFloat, height: CGFloat) {
        c.setFillColor(UIColor.white.withAlphaComponent(0.82).cgColor)
        var y: CGFloat = 20
        while y < height {
            c.fill(CGRect(x: width / 2 - 11, y: y, width: 8, height: 8))
            c.fill(CGRect(x: width / 2 + 7, y: y + 20, width: 7, height: 7))
            y += 72
        }
    }

    private func drawCrystalDetails(in c: CGContext, width: CGFloat, height: CGFloat, borderW: CGFloat) {
        drawIceShardLines(in: c, width: width, height: height, borderW: borderW)
        let shine = UIColor.white.withAlphaComponent(0.75)
        c.setFillColor(shine.cgColor)
        var y: CGFloat = 22
        while y < height {
            c.fill(CGRect(x: borderW + 9, y: y, width: 4, height: 18))
            c.fill(CGRect(x: width - borderW - 18, y: y + 36, width: 3, height: 16))
            y += 88
        }
    }

    private func drawBoneDetails(in c: CGContext, width: CGFloat, height: CGFloat, borderW: CGFloat) {
        drawBoneKnuckles(in: c, width: width, height: height, borderW: borderW)
        c.setFillColor(UIColor(red: 0.55, green: 0.45, blue: 0.30, alpha: 1).cgColor)
        var y: CGFloat = 26
        while y < height {
            c.fill(CGRect(x: borderW + 12, y: y, width: width - borderW * 2 - 24, height: 3))
            y += 58
        }
    }

    private func drawBoneKnuckles(in c: CGContext, width: CGFloat, height: CGFloat, borderW: CGFloat) {
        let light = UIColor(red: 0.96, green: 0.88, blue: 0.66, alpha: 1)
        c.setFillColor(light.cgColor)
        var y: CGFloat = 16
        while y < height {
            c.fill(CGRect(x: borderW + 6, y: y, width: 8, height: 8))
            c.fill(CGRect(x: width - borderW - 14, y: y + 9, width: 8, height: 8))
            y += 82
        }
    }

    private func drawBookshelfDetails(in c: CGContext, width: CGFloat, height: CGFloat, borderW: CGFloat) {
        let colors = [
            UIColor(red: 0.85, green: 0.18, blue: 0.18, alpha: 1),
            UIColor(red: 0.18, green: 0.48, blue: 0.82, alpha: 1),
            UIColor(red: 0.92, green: 0.70, blue: 0.18, alpha: 1),
            UIColor(red: 0.20, green: 0.62, blue: 0.30, alpha: 1)
        ]
        var y: CGFloat = 14
        var row = 0
        while y < height {
            c.setFillColor(UIColor(red: 0.22, green: 0.10, blue: 0.04, alpha: 1).cgColor)
            c.fill(CGRect(x: borderW, y: y, width: width - borderW * 2, height: 3))
            var x = borderW + 7
            var i = 0
            while x < width - borderW - 7 {
                c.setFillColor(colors[(row + i) % colors.count].cgColor)
                c.fill(CGRect(x: x, y: y + 5, width: 7, height: 22))
                x += 10
                i += 1
            }
            row += 1
            y += 42
        }
    }

    private func renderSandCastlePipe(width: CGFloat, height: CGFloat, skin: PipeSkin) -> UIImage {
        let size = CGSize(width: width, height: height)
        let outline: CGFloat = 3
        let blockH: CGFloat = 24
        let blockW: CGFloat = 18
        let mortar = UIColor(red: 0.54, green: 0.34, blue: 0.11, alpha: 1)
        let chip = UIColor(red: 0.74, green: 0.49, blue: 0.18, alpha: 1)
        let sparkle = UIColor(red: 1.00, green: 0.90, blue: 0.52, alpha: 1)

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let c = ctx.cgContext
            c.interpolationQuality = .none

            c.setFillColor(skin.borderColor.cgColor)
            c.fill(CGRect(origin: .zero, size: size))

            let body = CGRect(x: outline, y: 0, width: width - outline * 2, height: height)
            c.setFillColor(skin.bodyColor.cgColor)
            c.fill(body)

            c.setFillColor(skin.highlightColor.cgColor)
            c.fill(CGRect(x: outline + 4, y: 0, width: 7, height: height))
            c.setFillColor(skin.shadowColor.cgColor)
            c.fill(CGRect(x: width - outline - 12, y: 0, width: 9, height: height))
            c.setFillColor(UIColor(red: 0.48, green: 0.31, blue: 0.11, alpha: 1).cgColor)
            c.fill(CGRect(x: width - outline - 4, y: 0, width: 2, height: height))

            var y: CGFloat = 8
            var row = 0
            while y < height {
                c.setFillColor(mortar.cgColor)
                c.fill(CGRect(x: outline, y: y, width: body.width, height: 2))

                let offset = row.isMultiple(of: 2) ? 0 : blockW / 2
                var x = outline + offset
                while x < width - outline {
                    c.fill(CGRect(x: x, y: y, width: 2, height: min(blockH, height - y)))
                    x += blockW
                }

                row += 1
                y += blockH
            }

            c.setFillColor(sparkle.cgColor)
            var sparkleY: CGFloat = 18
            while sparkleY < height {
                c.fill(CGRect(x: outline + 7, y: sparkleY, width: 2, height: 8))
                c.fill(CGRect(x: outline + 12, y: sparkleY + 4, width: 2, height: 4))
                sparkleY += 96
            }

            c.setFillColor(chip.cgColor)
            var chipY: CGFloat = 44
            while chipY < height {
                c.fill(CGRect(x: width - outline - 22, y: chipY, width: 6, height: 2))
                c.fill(CGRect(x: width - outline - 18, y: chipY + 2, width: 2, height: 3))
                c.fill(CGRect(x: outline + 22, y: chipY + 40, width: 8, height: 2))
                c.fill(CGRect(x: outline + 20, y: chipY + 42, width: 2, height: 2))
                chipY += 132
            }

            drawSandShell(in: c, origin: CGPoint(x: outline + 13, y: 140), mirrored: false)
            drawSandStarfish(in: c, origin: CGPoint(x: width - outline - 25, y: 250))
            drawSandShell(in: c, origin: CGPoint(x: width - outline - 24, y: 430), mirrored: true)
        }
    }

    private func renderSandCastlePipeCap(skin: PipeSkin) -> UIImage {
        let capW: CGFloat = GK.pipeWidth + 10
        let capH: CGFloat = 30
        let outline: CGFloat = 3
        let lipH: CGFloat = 12
        let merlonW: CGFloat = 11
        let gapW: CGFloat = 8
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: capW, height: capH))

        return renderer.image { ctx in
            let c = ctx.cgContext
            c.interpolationQuality = .none

            c.setFillColor(skin.borderColor.cgColor)
            c.fill(CGRect(x: 0, y: 0, width: capW, height: capH))

            c.setFillColor(skin.bodyColor.cgColor)
            c.fill(CGRect(x: outline, y: capH - lipH - outline, width: capW - outline * 2, height: lipH))

            var x = outline
            while x < capW - outline {
                c.fill(CGRect(x: x, y: outline, width: min(merlonW, capW - outline - x), height: capH - lipH - outline))
                x += merlonW + gapW
            }

            c.setFillColor(skin.highlightColor.cgColor)
            c.fill(CGRect(x: outline + 4, y: outline + 2, width: 5, height: capH - outline * 2))
            c.fill(CGRect(x: outline + 15, y: capH - lipH - outline + 3, width: 18, height: 3))

            c.setFillColor(skin.shadowColor.cgColor)
            c.fill(CGRect(x: capW - outline - 10, y: outline, width: 7, height: capH - outline * 2))

            c.setFillColor(UIColor(red: 0.54, green: 0.34, blue: 0.11, alpha: 1).cgColor)
            c.fill(CGRect(x: outline, y: capH - lipH - outline, width: capW - outline * 2, height: 2))
            c.fill(CGRect(x: outline + 23, y: capH - lipH, width: 2, height: lipH - outline))
            c.fill(CGRect(x: outline + 43, y: capH - lipH, width: 2, height: lipH - outline))
        }
    }

    private func drawSandShell(in c: CGContext, origin: CGPoint, mirrored: Bool) {
        let outline = UIColor(red: 0.36, green: 0.19, blue: 0.12, alpha: 1)
        let shell = UIColor(red: 0.96, green: 0.57, blue: 0.50, alpha: 1)
        let light = UIColor(red: 1.00, green: 0.78, blue: 0.70, alpha: 1)
        let shade = UIColor(red: 0.72, green: 0.32, blue: 0.34, alpha: 1)
        let sx: CGFloat = mirrored ? -1 : 1

        func r(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ color: UIColor) {
            c.setFillColor(color.cgColor)
            c.fill(CGRect(x: origin.x + x * sx - (mirrored ? w : 0), y: origin.y + y, width: w, height: h))
        }

        r(2, 4, 16, 8, outline)
        r(0, 8, 20, 6, outline)
        r(4, 2, 12, 12, shell)
        r(2, 8, 16, 5, shell)
        r(6, 4, 3, 9, light)
        r(11, 4, 3, 9, shade)
        r(4, 13, 14, 2, outline)
    }

    private func drawSandStarfish(in c: CGContext, origin: CGPoint) {
        let outline = UIColor(red: 0.36, green: 0.16, blue: 0.10, alpha: 1)
        let star = UIColor(red: 0.95, green: 0.40, blue: 0.30, alpha: 1)
        let light = UIColor(red: 1.00, green: 0.64, blue: 0.48, alpha: 1)

        func r(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ color: UIColor) {
            c.setFillColor(color.cgColor)
            c.fill(CGRect(x: origin.x + x, y: origin.y + y, width: w, height: h))
        }

        r(8, 0, 5, 22, outline)
        r(0, 8, 21, 5, outline)
        r(3, 3, 15, 15, outline)
        r(9, 3, 3, 16, star)
        r(3, 9, 15, 3, star)
        r(6, 6, 9, 9, star)
        r(7, 5, 3, 3, light)
        r(4, 10, 3, 2, light)
    }



    // MARK: - Pixel Cloud (enhanced with highlights and shading)

    private func renderPixelCloud() -> UIImage {
        let ps: CGFloat = 5  // pixel size
        let W = UIColor(white: 1.0, alpha: 0.95)
        let H = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0) // bright highlight
        let M = UIColor(white: 0.95, alpha: 0.90)   // mid-tone
        let L = UIColor(white: 0.85, alpha: 0.82)   // shadow
        let D = UIColor(white: 0.78, alpha: 0.70)   // deep shadow
        let C = UIColor.clear

        // 18×8 pixel cloud — chunkier with more dimension
        let grid: [[UIColor]] = [
            [C,C,C,C,C,H,H,H,C,C,C,C,C,C,C,C,C,C],
            [C,C,C,C,H,W,W,W,H,C,C,H,H,C,C,C,C,C],
            [C,C,C,H,W,H,W,W,W,H,H,W,W,H,C,C,C,C],
            [C,C,H,W,W,H,H,W,W,W,W,W,W,W,H,C,C,C],
            [C,H,W,W,W,W,W,W,W,W,W,W,W,W,W,H,C,C],
            [H,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,H,C],
            [C,M,M,W,W,W,W,W,W,W,W,W,W,W,M,M,C,C],
            [C,C,C,L,L,D,L,L,L,L,L,L,D,L,C,C,C,C],
        ]

        let gridW = grid[0].count
        let gridH = grid.count
        let imgSize = CGSize(width: CGFloat(gridW) * ps, height: CGFloat(gridH) * ps)

        let renderer = UIGraphicsImageRenderer(size: imgSize)
        return renderer.image { ctx in
            for row in 0..<gridH {
                for col in 0..<gridW {
                    let color = grid[row][col]
                    guard color != UIColor.clear else { continue }
                    color.setFill()
                    ctx.fill(CGRect(x: CGFloat(col) * ps, y: CGFloat(row) * ps, width: ps, height: ps))
                }
            }
        }
    }


    // MARK: - Skinned Duck Rendering

    private struct DuckPalette {
        let head: UIColor; let headHi: UIColor
        let breast: UIColor
        let body: UIColor; let bodyHi: UIColor
        let spec: UIColor; let specHi: UIColor
        let bill: UIColor; let billTip: UIColor
        let collar: UIColor
    }

    private func palette(for skin: DuckSkin, ghost: Bool) -> DuckPalette {
        func c(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> UIColor {
            UIColor(red: r, green: g, blue: b, alpha: 1)
        }
        let p: DuckPalette
        switch skin {
        case .classic, .cowboy, .sailor:
            p = DuckPalette(
                head: c(0.08, 0.42, 0.22), headHi: c(0.15, 0.58, 0.35),
                breast: c(0.55, 0.22, 0.10),
                body: c(0.58, 0.58, 0.58), bodyHi: c(0.72, 0.72, 0.72),
                spec: c(0.15, 0.30, 0.70), specHi: c(0.25, 0.45, 0.85),
                bill: c(0.93, 0.65, 0.10), billTip: c(0.80, 0.55, 0.08),
                collar: .white)
        case .pirate:
            p = DuckPalette(
                head: c(0.08, 0.42, 0.22), headHi: c(0.15, 0.58, 0.35),
                breast: c(0.42, 0.16, 0.08),
                body: c(0.58, 0.58, 0.58), bodyHi: c(0.72, 0.72, 0.72),
                spec: c(0.15, 0.30, 0.70), specHi: c(0.25, 0.45, 0.85),
                bill: c(0.93, 0.65, 0.10), billTip: c(0.80, 0.55, 0.08),
                collar: .white)
        case .golden:
            p = DuckPalette(
                head: c(0.95, 0.80, 0.20), headHi: c(1.00, 0.90, 0.35),
                breast: c(0.85, 0.68, 0.15),
                body: c(0.88, 0.72, 0.18), bodyHi: c(0.95, 0.82, 0.30),
                spec: c(0.92, 0.92, 0.88), specHi: c(1.00, 1.00, 0.95),
                bill: c(0.75, 0.55, 0.10), billTip: c(0.60, 0.42, 0.08),
                collar: .white)
        case .alien:
            // Silver/metallic body with lime-green head — distinct from classic
            p = DuckPalette(
                head: c(0.25, 0.85, 0.25), headHi: c(0.40, 1.0, 0.40),
                breast: c(0.55, 0.60, 0.65),
                body: c(0.68, 0.72, 0.75), bodyHi: c(0.80, 0.84, 0.86),
                spec: c(0.50, 0.95, 0.50), specHi: c(0.65, 1.0, 0.65),
                bill: c(0.93, 0.65, 0.10), billTip: c(0.80, 0.55, 0.08),
                collar: c(0.85, 0.90, 0.92))
        case .dinosaur:
            p = DuckPalette(
                head: c(0.30, 0.50, 0.15), headHi: c(0.42, 0.62, 0.22),
                breast: c(0.60, 0.55, 0.20),
                body: c(0.38, 0.55, 0.18), bodyHi: c(0.50, 0.68, 0.28),
                spec: c(0.35, 0.52, 0.18), specHi: c(0.45, 0.62, 0.25),
                bill: c(0.93, 0.65, 0.10), billTip: c(0.80, 0.55, 0.08),
                collar: c(0.70, 0.65, 0.30))
        case .wizard:
            p = DuckPalette(
                head: c(0.35, 0.20, 0.65), headHi: c(0.50, 0.35, 0.80),
                breast: c(0.25, 0.25, 0.50),
                body: c(0.40, 0.38, 0.55), bodyHi: c(0.55, 0.52, 0.70),
                spec: c(0.85, 0.70, 0.20), specHi: c(0.95, 0.80, 0.30),
                bill: c(0.93, 0.65, 0.10), billTip: c(0.80, 0.55, 0.08),
                collar: c(0.75, 0.70, 0.90))
        case .devil:
            p = DuckPalette(
                head: c(0.70, 0.12, 0.12), headHi: c(0.85, 0.20, 0.20),
                breast: c(0.80, 0.30, 0.10),
                body: c(0.65, 0.15, 0.15), bodyHi: c(0.80, 0.25, 0.25),
                spec: c(0.20, 0.08, 0.08), specHi: c(0.35, 0.12, 0.12),
                bill: c(0.93, 0.65, 0.10), billTip: c(0.80, 0.55, 0.08),
                collar: c(0.95, 0.75, 0.60))
        case .ninja:
            // Dark slate body with red speculum accent
            p = DuckPalette(
                head: c(0.18, 0.18, 0.20), headHi: c(0.28, 0.28, 0.32),
                breast: c(0.45, 0.12, 0.10),
                body: c(0.20, 0.22, 0.28), bodyHi: c(0.32, 0.34, 0.42),
                spec: c(0.65, 0.10, 0.15), specHi: c(0.85, 0.20, 0.25),
                bill: c(0.93, 0.65, 0.10), billTip: c(0.80, 0.55, 0.08),
                collar: c(0.10, 0.10, 0.12))
        case .astronaut:
            // White suit with NASA blue speculum + red collar stripe
            p = DuckPalette(
                head: c(0.92, 0.94, 0.96), headHi: c(1.00, 1.00, 1.00),
                breast: c(0.72, 0.75, 0.80),
                body: c(0.85, 0.88, 0.92), bodyHi: c(0.95, 0.97, 0.98),
                spec: c(0.20, 0.40, 0.85), specHi: c(0.40, 0.60, 1.00),
                bill: c(0.93, 0.65, 0.10), billTip: c(0.80, 0.55, 0.08),
                collar: c(0.85, 0.20, 0.20))
        case .pharaoh:
            // Classic green head, royal gold/blue body
            p = DuckPalette(
                head: c(0.08, 0.42, 0.22), headHi: c(0.15, 0.58, 0.35),
                breast: c(0.85, 0.60, 0.18),
                body: c(0.92, 0.85, 0.55), bodyHi: c(1.00, 0.95, 0.70),
                spec: c(0.10, 0.18, 0.55), specHi: c(0.85, 0.70, 0.20),
                bill: c(0.93, 0.65, 0.10), billTip: c(0.80, 0.55, 0.08),
                collar: c(0.92, 0.78, 0.25))
        case .robot:
            // Chrome/steel body with cyan LED accents
            p = DuckPalette(
                head: c(0.55, 0.62, 0.70), headHi: c(0.72, 0.78, 0.85),
                breast: c(0.32, 0.35, 0.40),
                body: c(0.50, 0.55, 0.62), bodyHi: c(0.68, 0.72, 0.78),
                spec: c(0.20, 0.85, 0.95), specHi: c(0.50, 1.00, 1.00),
                bill: c(0.42, 0.45, 0.48), billTip: c(0.30, 0.32, 0.35),
                collar: c(0.20, 0.85, 0.95))
        case .king:
            // Royal mallard with white royal body + crimson speculum
            p = DuckPalette(
                head: c(0.08, 0.42, 0.22), headHi: c(0.15, 0.58, 0.35),
                breast: c(0.65, 0.10, 0.15),
                body: c(0.92, 0.92, 0.95), bodyHi: c(0.98, 0.98, 1.00),
                spec: c(0.55, 0.08, 0.15), specHi: c(0.85, 0.20, 0.25),
                bill: c(0.93, 0.65, 0.10), billTip: c(0.80, 0.55, 0.08),
                collar: c(0.92, 0.78, 0.20))
        case .lumberquack:
            // Classic mallard head, red flannel body
            p = DuckPalette(
                head: c(0.08, 0.42, 0.22), headHi: c(0.15, 0.58, 0.35),
                breast: c(0.75, 0.15, 0.12),
                body: c(0.55, 0.22, 0.10), bodyHi: c(0.68, 0.30, 0.15),
                spec: c(0.20, 0.08, 0.10), specHi: c(0.35, 0.12, 0.15),
                bill: c(0.93, 0.65, 0.10), billTip: c(0.80, 0.55, 0.08),
                collar: c(0.10, 0.10, 0.10))
        case .spider:
            // Dark purple/black with red hourglass speculum
            p = DuckPalette(
                head: c(0.25, 0.10, 0.35), headHi: c(0.38, 0.18, 0.50),
                breast: c(0.30, 0.08, 0.18),
                body: c(0.15, 0.08, 0.25), bodyHi: c(0.25, 0.12, 0.38),
                spec: c(0.85, 0.10, 0.10), specHi: c(1.00, 0.25, 0.25),
                bill: c(0.40, 0.35, 0.45), billTip: c(0.25, 0.22, 0.30),
                collar: c(0.08, 0.05, 0.12))
        case .squirrel:
            // Warm brown fur with creamy white belly
            p = DuckPalette(
                head: c(0.55, 0.35, 0.18), headHi: c(0.68, 0.48, 0.25),
                breast: c(0.90, 0.85, 0.78),
                body: c(0.50, 0.32, 0.15), bodyHi: c(0.62, 0.42, 0.22),
                spec: c(0.40, 0.28, 0.12), specHi: c(0.52, 0.38, 0.18),
                bill: c(0.93, 0.65, 0.10), billTip: c(0.80, 0.55, 0.08),
                collar: c(0.95, 0.90, 0.82))
        }
        if ghost {
            // Cyan/blue tint for bot ghost — distinct from all skin palettes
            return DuckPalette(
                head: c(0.15, 0.35, 0.55), headHi: c(0.22, 0.48, 0.68),
                breast: c(0.20, 0.30, 0.50),
                body: c(0.25, 0.40, 0.58), bodyHi: c(0.35, 0.52, 0.70),
                spec: c(0.18, 0.38, 0.65), specHi: c(0.28, 0.50, 0.78),
                bill: c(0.50, 0.65, 0.75), billTip: c(0.40, 0.55, 0.65),
                collar: c(0.60, 0.75, 0.88))
        }
        return p
    }

    /// Builds the 16×11 body grid from a palette.
    private func baseBodyGrid(_ p: DuckPalette) -> [[UIColor]] {
        let H = p.head; let h = p.headHi; let K = p.breast
        let Y = p.body; let y = p.bodyHi; let S = p.spec; let s = p.specHi
        let O = p.bill; let o = p.billTip; let W = p.collar
        let B = UIColor.black; let E = UIColor.white; let C = UIColor.clear
        return [
            [C,C,C,C,B,B,B,B,C,C,C,C,C,C,C,C],
            [C,C,C,B,H,H,h,H,B,C,C,C,C,C,C,C],
            [C,C,B,H,H,h,H,H,H,B,C,C,C,C,C,C],
            [C,B,H,H,h,H,E,E,H,H,B,C,C,C,C,C],
            [C,B,H,H,H,H,B,C,H,H,B,B,B,B,C,C],
            [B,H,H,H,H,H,H,H,H,H,B,O,O,o,B,C],
            [B,W,W,H,H,H,H,H,H,B,O,O,O,B,C,C],
            [B,K,K,W,Y,S,s,Y,y,Y,B,B,C,C,C,C],
            [C,B,K,Y,Y,Y,y,Y,Y,B,C,C,C,C,C,C],
            [C,C,B,Y,Y,y,Y,Y,B,C,C,C,C,C,C,C],
            [C,C,C,B,B,B,B,B,C,C,C,C,C,C,C,C],
        ]
    }

    /// Master skin renderer. Builds body + accessories.
    private func renderSkinnedDuck(skin: DuckSkin, wingPhase: Int,
                                    pixelSize: CGFloat = 3.0,
                                    ghost: Bool = false) -> UIImage {
        // For classic, use the original renderer (already battle-tested)
        if skin == .classic && !ghost {
            return renderMallardDuck(wingPhase: wingPhase, pixelSize: pixelSize)
        }
        if skin == .classic && ghost {
            return renderMallardDuck(wingPhase: wingPhase, pixelSize: pixelSize, ghost: true)
        }

        let cs = skin.canvasSize
        let off = skin.bodyRowOffset
        let p = palette(for: skin, ghost: ghost)
        let B = UIColor.black; let C = UIColor.clear

        // Start with transparent canvas
        var grid = [[UIColor]](repeating: [UIColor](repeating: C, count: cs.w), count: cs.h)

        // Place body
        let body = baseBodyGrid(p)
        for r in 0..<11 {
            for c in 0..<16 {
                grid[off + r][c] = body[r][c]
            }
        }

        // Wing animation — shift speculum
        if wingPhase == 0 {
            // Wing up: speculum to row 5 of body
            grid[off + 5][5] = p.spec; grid[off + 5][6] = p.specHi; grid[off + 5][7] = p.spec
            grid[off + 7][5] = p.body; grid[off + 7][6] = p.body
        } else if wingPhase == 2 {
            // Wing down: speculum to row 9 of body
            grid[off + 7][5] = p.body; grid[off + 7][6] = p.body
            grid[off + 9][4] = p.spec; grid[off + 9][5] = p.specHi
        }

        // -- Accessories per skin --
        switch skin {
        case .classic:
            break // handled above
        case .cowboy:
            // Brown cowboy hat — 4 rows above body
            let T = UIColor(red: 0.55, green: 0.35, blue: 0.15, alpha: 1)
            let t = UIColor(red: 0.70, green: 0.50, blue: 0.25, alpha: 1) // highlight
            let d = UIColor(red: 0.42, green: 0.25, blue: 0.10, alpha: 1) // dark band
            //            0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15
            grid[0] = [C, C, C, C, C, C, B, B, B, C, C, C, C, C, C, C]
            grid[1] = [C, C, C, C, C, B, T, t, T, B, C, C, C, C, C, C]
            grid[2] = [C, C, C, C, B, T, t, t, T, T, B, C, C, C, C, C]
            grid[3] = [C, C, B, B, d, T, T, T, T, d, B, B, C, C, C, C]

        case .alien:
            // Antennae with glowing tips — 3 rows above body
            let G = UIColor(red: 0.40, green: 1.0, blue: 0.40, alpha: 1)  // glow
            let g = UIColor(red: 0.25, green: 0.80, blue: 0.25, alpha: 1) // stalk
            grid[0] = [C, C, C, C, G, C, C, C, C, G, C, C, C, C, C, C]
            grid[1] = [C, C, C, C, C, g, C, C, g, C, C, C, C, C, C, C]
            grid[2] = [C, C, C, C, C, C, g, g, C, C, C, C, C, C, C, C]
            // Bigger alien eyes (replace standard eye in body rows 3-4)
            let E = UIColor.white
            // Row 3 of body (off+3): expand eyes
            grid[off + 3][5] = E; grid[off + 3][6] = E
            grid[off + 3][7] = E; grid[off + 3][8] = E
            // Row 4: pupils bigger
            grid[off + 4][6] = B; grid[off + 4][7] = B

        case .dinosaur:
            // Dorsal spikes — 3 rows above body
            let S = UIColor(red: 0.92, green: 0.72, blue: 0.15, alpha: 1)  // spike yellow
            let s = UIColor(red: 0.85, green: 0.58, blue: 0.12, alpha: 1)  // spike orange
            grid[0] = [C, C, C, C, C, C, S, C, C, C, C, C, C, C, C, C]
            grid[1] = [C, C, C, C, S, C, s, S, C, C, S, C, C, C, C, C]
            grid[2] = [C, C, C, C, s, S, s, s, S, S, s, S, C, C, C, C]

        case .wizard:
            // Tall wizard hat — 6 rows above body
            let P = UIColor(red: 0.40, green: 0.18, blue: 0.70, alpha: 1) // hat purple
            let q = UIColor(red: 0.52, green: 0.30, blue: 0.82, alpha: 1) // lighter
            let G = UIColor(red: 0.95, green: 0.82, blue: 0.20, alpha: 1) // gold star
            grid[0] = [C, C, C, C, C, C, C, B, C, C, C, C, C, C, C, C]
            grid[1] = [C, C, C, C, C, C, B, P, B, C, C, C, C, C, C, C]
            grid[2] = [C, C, C, C, C, B, P, G, P, B, C, C, C, C, C, C]
            grid[3] = [C, C, C, C, B, P, q, P, q, P, B, C, C, C, C, C]
            grid[4] = [C, C, C, B, P, P, P, q, P, P, P, B, C, C, C, C]
            grid[5] = [C, C, B, P, P, P, P, P, P, P, P, P, B, C, C, C]

        case .devil:
            // Horns — 3 rows above body
            let R = UIColor(red: 0.55, green: 0.05, blue: 0.05, alpha: 1) // dark horn
            let r = UIColor(red: 0.75, green: 0.10, blue: 0.10, alpha: 1) // lighter horn
            grid[0] = [C, C, C, R, C, C, C, C, C, R, C, C, C, C, C, C]
            grid[1] = [C, C, C, R, r, C, C, C, r, R, C, C, C, C, C, C]
            grid[2] = [C, C, C, C, r, C, C, C, r, C, C, C, C, C, C, C]
            // Pointed tail at bottom-left (extend body rows 8-10)
            let tl = p.head  // tail matches body color
            if off + 10 < cs.h {
                grid[off + 8][0] = tl
                grid[off + 9][0] = B
                grid[off + 10][0] = C  // already clear
                // Shift tail out
                grid[off + 9][1] = tl
                grid[off + 10][1] = B
                grid[off + 10][2] = tl
            }

        case .sailor:
            // Red pirate bandana with skull motif — 3 rows above body
            let R = UIColor(red: 0.85, green: 0.15, blue: 0.15, alpha: 1) // bandana red
            let W = UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1) // skull white
            grid[0] = [C, C, C, C, C, B, B, B, B, C, C, C, C, C, C, C]
            grid[1] = [C, C, C, C, B, R, R, R, R, B, C, B, C, C, C, C]
            grid[2] = [C, C, C, B, R, R, W, R, R, B, B, B, B, C, C, C]

        case .pirate:
            // Pirate tricorn hat — 4 rows above body + eye patch
            let D = UIColor(red: 0.40, green: 0.22, blue: 0.10, alpha: 1) // dark leather brown
            grid[0] = [C, C, C, C, C, C, B, B, C, C, C, C, C, C, C, C]
            grid[1] = [C, C, C, C, B, B, D, D, B, B, C, C, C, C, C, C]
            grid[2] = [C, C, C, B, D, D, D, D, D, D, B, C, C, C, C, C]
            grid[3] = [C, B, B, D, D, D, D, D, D, D, D, B, B, C, C, C]
            // Eye patch on body rows 3-4
            grid[off + 3][6] = B; grid[off + 3][7] = B
            grid[off + 4][6] = B

        case .golden:
            // Small crown — 3 rows above body
            let G = UIColor(red: 0.95, green: 0.80, blue: 0.20, alpha: 1) // bright gold
            grid[0] = [C, C, C, C, G, C, G, C, G, C, C, C, C, C, C, C]
            grid[1] = [C, C, C, C, B, G, G, G, B, C, C, C, C, C, C, C]
            grid[2] = [C, C, C, C, B, G, G, G, B, C, C, C, C, C, C, C]

        case .ninja:
            // Headband band + tied tail + black eye mask
            let R = UIColor(red: 0.85, green: 0.10, blue: 0.10, alpha: 1) // red eye glint
            grid[1] = [C, C, B, B, B, B, B, B, B, B, B, B, C, C, C, C]
            grid[2] = [C, C, C, C, C, C, C, C, C, C, B, B, B, B, C, C]
            // Eye mask band overlays body row 3 (the eye row)
            grid[off + 3][3] = B; grid[off + 3][4] = B
            grid[off + 3][5] = B; grid[off + 3][6] = B
            grid[off + 3][7] = B; grid[off + 3][8] = B
            grid[off + 3][9] = B
            // Red eye glints peek through the mask
            grid[off + 3][6] = R; grid[off + 3][7] = R

        case .astronaut:
            // Domed helmet with gold visor band — 4 rows above body
            let W = UIColor.white
            let G = UIColor(red: 0.95, green: 0.78, blue: 0.20, alpha: 1) // gold visor
            grid[0] = [C, C, C, C, C, B, B, B, B, B, C, C, C, C, C, C]
            grid[1] = [C, C, C, B, W, W, W, W, W, W, B, C, C, C, C, C]
            grid[2] = [C, C, B, W, G, G, G, G, G, G, W, B, C, C, C, C]
            grid[3] = [C, B, W, W, G, G, G, G, G, G, W, W, B, C, C, C]

        case .pharaoh:
            // Striped nemes headdress — 4 rows above body + side flaps
            let G = UIColor(red: 0.95, green: 0.78, blue: 0.20, alpha: 1) // gold stripe
            let U = UIColor(red: 0.10, green: 0.20, blue: 0.55, alpha: 1) // blue stripe
            let g = UIColor(red: 0.78, green: 0.62, blue: 0.10, alpha: 1) // dark gold edge
            grid[0] = [C, C, C, C, C, B, G, B, G, B, C, C, C, C, C, C]
            grid[1] = [C, C, C, C, B, G, U, G, U, G, B, C, C, C, C, C]
            grid[2] = [C, C, C, B, G, U, G, U, G, U, G, B, C, C, C, C]
            grid[3] = [C, C, B, g, U, G, U, G, U, G, U, g, B, C, C, C]
            // Nemes flaps cascade down body sides (cols 0 and 11)
            grid[off + 1][0] = G; grid[off + 1][11] = G
            grid[off + 2][0] = U; grid[off + 2][11] = U
            grid[off + 3][0] = G; grid[off + 3][11] = G
            grid[off + 4][0] = U

        case .robot:
            // Antenna with red tip + cyan LED visor
            let M = UIColor(red: 0.55, green: 0.60, blue: 0.65, alpha: 1) // chrome
            let R = UIColor(red: 0.95, green: 0.20, blue: 0.20, alpha: 1) // red bulb
            let L = UIColor(red: 0.40, green: 1.00, blue: 1.00, alpha: 1) // cyan LED
            grid[0] = [C, C, C, C, C, C, C, C, R, C, C, C, C, C, C, C]
            grid[1] = [C, C, C, C, C, C, C, C, B, C, C, C, C, C, C, C]
            grid[2] = [C, C, C, C, C, C, C, B, M, B, C, C, C, C, C, C]
            // LED visor band overlays body row 3 (eye row)
            grid[off + 3][4] = B
            grid[off + 3][5] = L; grid[off + 3][6] = L
            grid[off + 3][7] = L; grid[off + 3][8] = L
            grid[off + 3][9] = B

        case .king:
            // Crown with gem points + red velvet inset — 4 rows above body
            let G = UIColor(red: 0.95, green: 0.80, blue: 0.20, alpha: 1) // gold
            let g = UIColor(red: 0.78, green: 0.62, blue: 0.10, alpha: 1) // dark gold
            let R = UIColor(red: 0.65, green: 0.10, blue: 0.15, alpha: 1) // red velvet
            grid[0] = [C, C, C, G, C, G, C, G, C, G, C, C, C, C, C, C]
            grid[1] = [C, C, B, G, G, G, G, G, G, G, B, C, C, C, C, C]
            grid[2] = [C, C, B, g, R, R, R, R, R, g, B, C, C, C, C, C]
            grid[3] = [C, C, B, G, G, G, G, G, G, G, B, C, C, C, C, C]

        case .lumberquack:
            // Red beanie with dark band — 4 rows above body
            let R = UIColor(red: 0.88, green: 0.15, blue: 0.15, alpha: 1)
            let D = UIColor(red: 0.30, green: 0.10, blue: 0.10, alpha: 1)
            grid[0] = [C, C, C, C, C, B, B, B, B, C, C, C, C, C, C, C]
            grid[1] = [C, C, C, C, B, R, R, R, R, B, C, C, C, C, C, C]
            grid[2] = [C, C, C, B, R, R, R, R, R, R, B, C, C, C, C, C]
            grid[3] = [C, C, B, D, D, D, D, D, D, D, B, B, C, C, C, C]

        case .spider:
            // Glowing extra eyes + leg tips — 3 rows above body
            let E = UIColor(red: 0.95, green: 0.15, blue: 0.15, alpha: 1)
            let L = UIColor(red: 0.30, green: 0.08, blue: 0.35, alpha: 1)
            grid[0] = [C, C, C, C, E, C, C, C, C, E, C, C, C, C, C, C]
            grid[1] = [C, C, C, C, C, B, C, C, B, C, C, C, C, C, C, C]
            grid[2] = [C, L, C, C, C, C, C, C, C, C, C, C, L, C, C, C]
            grid[off + 3][5] = E; grid[off + 3][6] = E
            grid[off + 3][7] = E; grid[off + 3][8] = E

        case .squirrel:
            // Acorn on head + fluffy cheeks — 4 rows above body
            let T = UIColor(red: 0.55, green: 0.35, blue: 0.15, alpha: 1)
            let t = UIColor(red: 0.75, green: 0.55, blue: 0.25, alpha: 1)
            let F = UIColor(red: 0.80, green: 0.60, blue: 0.38, alpha: 1)
            grid[0] = [C, C, C, C, C, B, T, B, C, C, C, C, C, C, C, C]
            grid[1] = [C, C, C, C, B, T, t, T, B, C, C, C, C, C, C, C]
            grid[2] = [C, C, C, B, T, t, T, t, T, B, C, C, C, C, C, C]
            grid[3] = [C, C, B, t, T, t, T, t, T, t, B, C, C, C, C, C]
            grid[off + 3][3] = F; grid[off + 3][4] = F
            grid[off + 3][9] = F; grid[off + 3][10] = F
        }

        let alpha: CGFloat = ghost ? 0.65 : 1.0
        let imgSize = CGSize(width: CGFloat(cs.w) * pixelSize,
                             height: CGFloat(cs.h) * pixelSize)

        let renderer = UIGraphicsImageRenderer(size: imgSize)
        return renderer.image { ctx in
            for row in 0..<cs.h {
                for col in 0..<cs.w {
                    let color = grid[row][col]
                    guard color != UIColor.clear else { continue }
                    color.withAlphaComponent(alpha).setFill()
                    ctx.fill(CGRect(
                        x: CGFloat(col) * pixelSize,
                        y: CGFloat(row) * pixelSize,
                        width: pixelSize, height: pixelSize
                    ))
                }
            }
        }
    }
    func skyGradientTexture(theme: BackgroundTheme) -> SKTexture {
        let key = "sky_gradient_\(theme.rawValue)"
        if let cached = cachedTexture(forKey: key) { return cached }
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
        cacheStore(key, tex)
        return tex
    }

}
