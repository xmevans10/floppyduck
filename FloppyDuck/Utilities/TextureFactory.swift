import SpriteKit
import UIKit

/// Generates all game textures programmatically using pixel-art style rendering.
/// Park theme with round mallard duck matching Flappy Bird proportions.
final class TextureFactory {
    static let shared = TextureFactory()

    /// Maximum textures to keep in cache before triggering eviction.
    /// At ~2KB average per pixel-art texture, 200 entries ≈ 400KB — well within budget.
    private static let maxCacheSize = 200

    private init() {
        // Clear cache on memory warning (iOS background pressure)
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.clearCache()
        }
    }

    private var cache: [String: SKTexture] = [:]
    private var cacheOrder: [String] = []   // LRU eviction order
    private let cacheLock = NSLock()

    /// Thread-safe cache read.
    private func cachedTexture(forKey key: String) -> SKTexture? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return cache[key]
    }

    /// Removes all cached textures. Called automatically on memory warning.
    func clearCache() {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        cache.removeAll()
        cacheOrder.removeAll()
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
    func preWarm() {
        guard !isPreWarmed else { return }
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            // Duck wing phases (used every frame)
            for phase in 0...2 {
                _ = duckTexture(wingPhase: phase)
            }
            // Pipes, ground, sky, parallax layers (classic skin for preWarm — background thread safe)
            _ = pipeTexture(height: 300, skinOverride: .classic)
            _ = pipeCapTexture(skinOverride: .classic)
            _ = groundTexture()
            _ = skyTexture()
            _ = cloudTexture()
            _ = treesTexture()
            _ = hillsTexture()
            // Bread collectible
            _ = breadTexture()

            // Theme-specific textures (avoids first-frame stalls on non-day themes)
            for theme in BackgroundTheme.allCases where theme != .day {
                _ = self.themedHillsTexture(theme: theme)
                _ = self.themedTreesTexture(theme: theme)
                _ = self.themedBushTexture(theme: theme)
                _ = self.themedGroundTexture(theme: theme)
            }

            // Performance textures (batched ground details, star field)
            _ = self.groundDetailTexture(tileWidth: GK.worldWidth + 10,
                                         groundHeight: GK.groundHeight,
                                         seed: 0)
            _ = self.starFieldTexture(width: GK.worldWidth,
                                       height: GK.worldHeight * 0.6,
                                       count: 40, seed: 42)

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

    // MARK: - Public API

    /// Pixel-art mallard duck (wing up, mid, down)
    func duckTexture(wingPhase: Int) -> SKTexture {
        let key = "duck_\(wingPhase)"
        if let cached = cachedTexture(forKey: key) { return cached }
        let tex = SKTexture(image: renderMallardDuck(wingPhase: wingPhase))
        tex.filteringMode = .nearest
        cacheStore(key, tex)
        return tex
    }

    /// Bot ghost duck (tinted, semi-transparent)
    func botDuckTexture(wingPhase: Int) -> SKTexture {
        let key = "botduck_\(wingPhase)"
        if let cached = cachedTexture(forKey: key) { return cached }
        let tex = SKTexture(image: renderMallardDuck(wingPhase: wingPhase, ghost: true))
        tex.filteringMode = .nearest
        cacheStore(key, tex)
        return tex
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

    /// Scrolling ground tile — park grass with flowers (pixel art)
    func groundTexture() -> SKTexture {
        let key = "ground"
        if let cached = cachedTexture(forKey: key) { return cached }
        let tex = SKTexture(image: renderGround())
        tex.filteringMode = .nearest
        cacheStore(key, tex)
        return tex
    }

    /// Theme-aware scrolling ground tile. Each theme gets a unique ground surface.
    func themedGroundTexture(theme: BackgroundTheme) -> SKTexture {
        let key = "ground_\(theme.rawValue)"
        if let cached = cachedTexture(forKey: key) { return cached }
        let tex = SKTexture(image: renderThemedGround(theme: theme))
        tex.filteringMode = .nearest
        cacheStore(key, tex)
        return tex
    }

    /// Sky gradient background
    func skyTexture() -> SKTexture {
        let key = "sky"
        if let cached = cachedTexture(forKey: key) { return cached }
        let tex = SKTexture(image: renderSky())
        tex.filteringMode = .nearest
        cacheStore(key, tex)
        return tex
    }

    /// Pixel-art cloud
    func cloudTexture() -> SKTexture {
        let key = "cloud"
        if let cached = cachedTexture(forKey: key) { return cached }
        let tex = SKTexture(image: renderPixelCloud())
        tex.filteringMode = .nearest
        cacheStore(key, tex)
        return tex
    }

    /// Pixel-art park trees for parallax background
    func treesTexture() -> SKTexture {
        let key = "trees"
        if let cached = cachedTexture(forKey: key) { return cached }
        let tex = SKTexture(image: renderPixelTrees())
        tex.filteringMode = .nearest
        cacheStore(key, tex)
        return tex
    }

    /// Pixel-art distant hills
    func hillsTexture() -> SKTexture {
        let key = "hills"
        if let cached = cachedTexture(forKey: key) { return cached }
        let tex = SKTexture(image: renderPixelHills())
        tex.filteringMode = .nearest
        cacheStore(key, tex)
        return tex
    }

    /// UIImage of duck for SwiftUI views (classic only — use skinDuckUIImage for skins)
    func duckUIImage(pixelScale: CGFloat = 3.0) -> UIImage {
        return renderMallardDuck(wingPhase: 1, pixelSize: pixelScale)
    }

    /// UIImage of pixel cloud for SwiftUI home background
    func cloudUIImage() -> UIImage {
        return renderPixelCloud()
    }

    /// UIImage preview of a pipe skin for shop / collection cards.
    func pipeSkinPreviewUIImage(skin: PipeSkin, width: CGFloat = 30, height: CGFloat = 80) -> UIImage {
        return renderPipe(width: width, height: height, skin: skin)
    }

    /// UIImage preview of a pipe cap for shop / collection cards.
    func pipeSkinCapPreviewUIImage(skin: PipeSkin) -> UIImage {
        return renderPipeCap(skin: skin)
    }

    // MARK: - Performance Textures (batched replacements for SKShapeNodes)

    /// Pre-rendered ground detail tile (grass blades + pebbles) — replaces 22
    /// individual SKShapeNodes per tile with a single SKSpriteNode.
    func groundDetailTexture(tileWidth: CGFloat, groundHeight: CGFloat, seed: Int = 0) -> SKTexture {
        let key = "groundDetail_\(Int(tileWidth))_\(seed)"
        if let cached = cachedTexture(forKey: key) { return cached }
        let tex = SKTexture(image: renderGroundDetail(tileWidth: tileWidth, groundHeight: groundHeight, seed: seed))
        tex.filteringMode = .nearest
        cacheStore(key, tex)
        return tex
    }

    /// Theme-aware ground detail tile — each theme gets unique surface decorations
    /// instead of the generic grass blades + pebbles.
    func themedGroundDetailTexture(theme: BackgroundTheme, tileWidth: CGFloat, groundHeight: CGFloat, seed: Int = 0) -> SKTexture {
        let key = "groundDetail_\(theme.rawValue)_\(Int(tileWidth))_\(seed)"
        if let cached = cachedTexture(forKey: key) { return cached }
        let tex = SKTexture(image: renderThemedGroundDetail(theme: theme, tileWidth: tileWidth, groundHeight: groundHeight, seed: seed))
        tex.filteringMode = .nearest
        cacheStore(key, tex)
        return tex
    }

    /// Pre-rendered star field — replaces 40 individual SKShapeNodes with a
    /// single SKSpriteNode.
    func starFieldTexture(width: CGFloat, height: CGFloat, count: Int = 40, seed: Int = 42) -> SKTexture {
        let key = "starField_\(Int(width))_\(Int(height))_\(count)"
        if let cached = cachedTexture(forKey: key) { return cached }
        let tex = SKTexture(image: renderStarField(width: width, height: height, count: count, seed: seed))
        tex.filteringMode = .nearest
        cacheStore(key, tex)
        return tex
    }

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

    // MARK: - Ground Detail Rendering

    private func renderGroundDetail(tileWidth: CGFloat, groundHeight: CGFloat, seed: Int) -> UIImage {
        // Deterministic PRNG for consistent tiles
        srand48(seed)
        let h: CGFloat = groundHeight + 20  // extra room for grass tips above groundHeight
        let size = CGSize(width: tileWidth, height: h)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let c = ctx.cgContext
            // Grass blades — 14 per tile
            for _ in 0..<14 {
                let x = CGFloat(drand48()) * tileWidth
                let bladeH = CGFloat(drand48()) * 8 + 6  // 6…14
                let halfW: CGFloat = 1.5
                let baseY = h - groundHeight  // ground top, in image coords top-down → this is the Y where grass starts

                // Grass color
                let r = 0.25 + CGFloat(drand48()) * 0.20
                let g = 0.55 + CGFloat(drand48()) * 0.20
                let b = 0.10 + CGFloat(drand48()) * 0.12
                c.setFillColor(UIColor(red: r, green: g, blue: b, alpha: 1).cgColor)

                // Triangle blade (rendered upward from ground top)
                let path = CGMutablePath()
                path.move(to: CGPoint(x: x - halfW, y: baseY))
                path.addLine(to: CGPoint(x: x, y: baseY - bladeH))
                path.addLine(to: CGPoint(x: x + halfW, y: baseY))
                path.closeSubpath()
                c.addPath(path)
                c.fillPath()
            }

            // Pebbles — 8 per tile
            for _ in 0..<8 {
                let x = CGFloat(drand48()) * tileWidth
                let radius = CGFloat(drand48()) * 2.0 + 1.5  // 1.5…3.5
                let gray = CGFloat(drand48()) * 0.20 + 0.45
                c.setFillColor(UIColor(red: gray, green: gray - 0.05, blue: gray - 0.10, alpha: 0.8).cgColor)
                let pebbleY = h - groundHeight + 2  // just below ground line
                c.fillEllipse(in: CGRect(x: x - radius, y: pebbleY - radius, width: radius * 2, height: radius * 2))
            }
        }
    }

    // MARK: - Star Field Rendering

    private func renderStarField(width: CGFloat, height: CGFloat, count: Int, seed: Int) -> UIImage {
        srand48(seed)
        let size = CGSize(width: width, height: height)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let c = ctx.cgContext
            for _ in 0..<count {
                let x = CGFloat(drand48()) * width
                let y = CGFloat(drand48()) * height
                let radius = CGFloat(drand48()) * 1.5 + 1.0  // 1…2.5
                let alpha = CGFloat(drand48()) * 0.6 + 0.3   // 0.3…0.9
                c.setFillColor(UIColor.white.withAlphaComponent(alpha).cgColor)
                c.fillEllipse(in: CGRect(x: x - radius, y: y - radius,
                                          width: radius * 2, height: radius * 2))
            }
        }
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

    /// UIImage of pixel hills for SwiftUI home background
    func hillsUIImage() -> UIImage {
        return renderPixelHills()
    }

    // MARK: - Themed Parallax Textures

    /// Theme-aware hills texture. Free themes reuse the classic park hills
    /// with palette shifts; paid themes get unique silhouettes.
    func themedHillsTexture(theme: BackgroundTheme) -> SKTexture {
        let key = "hills_\(theme.rawValue)"
        if let cached = cachedTexture(forKey: key) { return cached }
        let tex = SKTexture(image: renderThemedHills(theme: theme))
        tex.filteringMode = .nearest
        cacheStore(key, tex)
        return tex
    }

    /// Theme-aware trees / midground texture.
    func themedTreesTexture(theme: BackgroundTheme) -> SKTexture {
        let key = "trees_\(theme.rawValue)"
        if let cached = cachedTexture(forKey: key) { return cached }
        let tex = SKTexture(image: renderThemedTrees(theme: theme))
        tex.filteringMode = .nearest
        cacheStore(key, tex)
        return tex
    }

    /// Theme-aware foreground bush / element strip.
    func themedBushTexture(theme: BackgroundTheme) -> SKTexture {
        let key = "bushes_\(theme.rawValue)"
        if let cached = cachedTexture(forKey: key) { return cached }
        let tex = SKTexture(image: renderThemedBushes(theme: theme))
        tex.filteringMode = .nearest
        cacheStore(key, tex)
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
        return renderSkinnedDuck(skin: skin, wingPhase: 1, pixelSize: pixelScale)
    }

    /// Flush cached textures for a skin (call when skin selection changes).
    func clearSkinCache() {
        cache = cache.filter { !$0.key.hasPrefix("skin") }
    }

    /// Bread currency icon for SwiftUI (cached per scale)
    private var breadUICache: [Int: UIImage] = [:]
    func breadUIImage(pixelScale: CGFloat = 4.0) -> UIImage {
        let key = Int(pixelScale * 100)
        if let cached = breadUICache[key] { return cached }
        let img = renderBread(pixelSize: pixelScale)
        breadUICache[key] = img
        return img
    }

    /// Bread currency texture for SpriteKit
    func breadTexture() -> SKTexture {
        let key = "bread"
        if let cached = cachedTexture(forKey: key) { return cached }
        let tex = SKTexture(image: renderBread())
        tex.filteringMode = .nearest
        cacheStore(key, tex)
        return tex
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

    // MARK: - Pipes (classic green)

    private func renderPipe(width: CGFloat, height: CGFloat, skin: PipeSkin = .classic) -> UIImage {
        let size = CGSize(width: width, height: height)
        let borderW: CGFloat = 3
        let highlightW: CGFloat = 6

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let c = ctx.cgContext
            c.setFillColor(skin.borderColor.cgColor)
            c.fill(CGRect(origin: .zero, size: size))

            let body = CGRect(x: borderW, y: 0, width: width - borderW * 2, height: height)
            c.setFillColor(skin.bodyColor.cgColor)
            c.fill(body)

            let highlight = CGRect(x: borderW + 3, y: 0, width: highlightW, height: height)
            c.setFillColor(skin.highlightColor.cgColor)
            c.fill(highlight)

            let shadow = CGRect(x: width - borderW - highlightW - 1, y: 0, width: highlightW, height: height)
            c.setFillColor(skin.shadowColor.cgColor)
            c.fill(shadow)
        }
    }

    private func renderPipeCap(skin: PipeSkin = .classic) -> UIImage {
        let capW: CGFloat = GK.pipeWidth + 10
        let capH: CGFloat = 30
        let borderW: CGFloat = 3
        let size = CGSize(width: capW, height: capH)

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let c = ctx.cgContext
            c.setFillColor(skin.borderColor.cgColor)
            c.fill(CGRect(origin: .zero, size: size))

            let inner = CGRect(x: borderW, y: borderW, width: capW - borderW * 2, height: capH - borderW * 2)
            c.setFillColor(skin.bodyColor.cgColor)
            c.fill(inner)

            let hl = CGRect(x: borderW + 3, y: borderW, width: 6, height: capH - borderW * 2)
            c.setFillColor(skin.highlightColor.cgColor)
            c.fill(hl)

            let sh = CGRect(x: capW - borderW - 7, y: borderW, width: 6, height: capH - borderW * 2)
            c.setFillColor(skin.shadowColor.cgColor)
            c.fill(sh)
        }
    }

    // MARK: - Ground (pixel-art park grass + dirt)

    private func renderGround() -> UIImage {
        let w: CGFloat = GK.worldWidth * 2
        let h: CGFloat = GK.groundHeight
        let ps: CGFloat = 4  // pixel size for ground texture
        let size = CGSize(width: w, height: h)

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let c = ctx.cgContext

            // Tan/earth base
            c.setFillColor(UIColor(red: 0.78, green: 0.70, blue: 0.50, alpha: 1).cgColor)
            c.fill(CGRect(origin: .zero, size: size))

            // Pixel dirt stripes (diagonal hash marks)
            let stripe = UIColor(red: 0.72, green: 0.64, blue: 0.44, alpha: 1)
            var sx: CGFloat = 0
            while sx < w {
                c.setFillColor(stripe.cgColor)
                // Draw diagonal pixel stripe
                for i in 0..<Int(h / ps) {
                    let px = sx + CGFloat(i) * ps
                    let py = h - CGFloat(i + 1) * ps
                    if px < w && py >= 22 {
                        c.fill(CGRect(x: px, y: py, width: ps, height: ps))
                    }
                }
                sx += ps * 4
            }

            // Bright green grass top — pixel blocks
            let grassH: CGFloat = 22
            c.setFillColor(UIColor(red: 0.40, green: 0.72, blue: 0.22, alpha: 1).cgColor)
            c.fill(CGRect(x: 0, y: 0, width: w, height: grassH))

            // Darker grass line at very top
            c.setFillColor(UIColor(red: 0.28, green: 0.52, blue: 0.16, alpha: 1).cgColor)
            c.fill(CGRect(x: 0, y: 0, width: w, height: ps))

            // Pixel grass tufts
            let tufts = UIColor(red: 0.45, green: 0.78, blue: 0.26, alpha: 1)
            var tx: CGFloat = 0
            while tx < w {
                c.setFillColor(tufts.cgColor)
                let tuftW = Int.random(in: 1...3)
                for t in 0..<tuftW {
                    c.fill(CGRect(x: tx + CGFloat(t) * ps, y: grassH, width: ps, height: ps))
                }
                // Peak pixel
                c.fill(CGRect(x: tx + CGFloat(tuftW / 2) * ps, y: grassH + ps, width: ps, height: ps))
                tx += CGFloat(Int.random(in: 3...6)) * ps
            }

            // Pixel flowers
            let flowerColors: [UIColor] = [
                UIColor(red: 0.95, green: 0.35, blue: 0.35, alpha: 1),
                UIColor(red: 0.95, green: 0.85, blue: 0.20, alpha: 1),
                UIColor(red: 0.90, green: 0.50, blue: 0.80, alpha: 1),
                UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1),
            ]
            var fx: CGFloat = CGFloat.random(in: 5...10) * ps
            while fx < w {
                let fc = flowerColors[Int.random(in: 0..<flowerColors.count)]
                c.setFillColor(fc.cgColor)
                let fy = CGFloat(Int.random(in: 1...4)) * ps
                c.fill(CGRect(x: fx, y: fy, width: ps, height: ps))
                fx += CGFloat(Int.random(in: 6...12)) * ps
            }
        }
    }

    // MARK: - Sky (enhanced 8-bit gradient with dithered color banding)

    private func renderSky() -> UIImage {
        let size = CGSize(width: GK.worldWidth, height: GK.worldHeight)
        let ps: CGFloat = 4  // pixel size for 8-bit feel

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let c = ctx.cgContext

            // Base gradient
            let colors = [
                UIColor(red: 0.25, green: 0.55, blue: 0.88, alpha: 1).cgColor,
                UIColor(red: 0.40, green: 0.68, blue: 0.92, alpha: 1).cgColor,
                UIColor(red: 0.60, green: 0.82, blue: 0.95, alpha: 1).cgColor,
                UIColor(red: 0.78, green: 0.92, blue: 0.97, alpha: 1).cgColor,
            ]
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors as CFArray,
                locations: [0.0, 0.3, 0.65, 1.0]
            )!
            c.drawLinearGradient(gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: 0, y: size.height),
                options: [])

            // 8-bit dithering effect — scattered pixels at band transitions for retro feel
            let ditherColor = UIColor(red: 0.50, green: 0.75, blue: 0.93, alpha: 0.35)
            c.setFillColor(ditherColor.cgColor)
            let bandPositions: [CGFloat] = [size.height * 0.25, size.height * 0.50, size.height * 0.75]
            for bandY in bandPositions {
                var dx: CGFloat = 0
                while dx < size.width {
                    let offset = CGFloat(Int(dx / ps) % 2 == 0 ? 0 : 1) * ps
                    c.fill(CGRect(x: dx, y: bandY + offset, width: ps, height: ps))
                    dx += ps * 3
                }
            }

            // Subtle sun glow in upper right corner
            let sunX = size.width * 0.82
            let sunY = size.height * 0.12
            let sunGlow = UIColor(red: 1.0, green: 0.95, blue: 0.80, alpha: 0.12)
            c.setFillColor(sunGlow.cgColor)
            for ring in stride(from: 40, through: 8, by: -ps) {
                let inset = (40 - ring) / 2
                c.fillEllipse(in: CGRect(x: sunX - ring / 2 + CGFloat(inset),
                                          y: sunY - ring / 2 + CGFloat(inset),
                                          width: ring, height: ring))
            }
        }
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

    // MARK: - Pixel Hills

    private func renderPixelHills() -> UIImage {
        let w: CGFloat = GK.worldWidth * 2
        let h: CGFloat = 300
        let ps: CGFloat = 4
        let gridW = Int(w / ps)

        var heightMap = [Int](repeating: 1, count: gridW)
        let bumps: [(center: Int, radius: Int, peak: Int)] = [
            (20, 25, 25), (50, 20, 18), (80, 30, 32), (110, 15, 14),
            (140, 25, 28), (170, 20, 22), (195, 18, 18),
        ]
        for bump in bumps {
            for x in max(0, bump.center - bump.radius)..<min(gridW, bump.center + bump.radius) {
                let dist = abs(x - bump.center)
                let nd = CGFloat(dist) / CGFloat(bump.radius)
                heightMap[x] = max(heightMap[x], Int(CGFloat(bump.peak) * (1.0 - nd * nd)))
            }
        }

        let hillBase   = UIColor(red: 0.30, green: 0.55, blue: 0.22, alpha: 0.70)
        let hillMid    = UIColor(red: 0.35, green: 0.60, blue: 0.25, alpha: 0.65)
        let hillLight  = UIColor(red: 0.45, green: 0.68, blue: 0.30, alpha: 0.60)
        let hillTop    = UIColor(red: 0.25, green: 0.48, blue: 0.18, alpha: 0.75)
        // Windmill
        let millBrown  = UIColor(red: 0.35, green: 0.22, blue: 0.12, alpha: 0.82)
        let millLight  = UIColor(red: 0.48, green: 0.35, blue: 0.20, alpha: 0.78)
        let millRoof   = UIColor(red: 0.55, green: 0.20, blue: 0.12, alpha: 0.80)
        let bladeC     = UIColor(red: 0.40, green: 0.38, blue: 0.35, alpha: 0.70)
        // Barn
        let barnRed    = UIColor(red: 0.65, green: 0.18, blue: 0.12, alpha: 0.80)
        let barnDark   = UIColor(red: 0.50, green: 0.12, blue: 0.08, alpha: 0.82)
        let barnWhite  = UIColor(red: 0.88, green: 0.85, blue: 0.80, alpha: 0.75)
        // Lake
        let lakeD      = UIColor(red: 0.20, green: 0.45, blue: 0.65, alpha: 0.50)
        let lakeL      = UIColor(red: 0.35, green: 0.58, blue: 0.75, alpha: 0.40)
        // Fence
        let fenceC     = UIColor(red: 0.50, green: 0.38, blue: 0.22, alpha: 0.60)
        // Flowers
        let flowerR    = UIColor(red: 0.85, green: 0.25, blue: 0.20, alpha: 0.65)
        let flowerY    = UIColor(red: 0.95, green: 0.85, blue: 0.25, alpha: 0.65)
        let flowerW    = UIColor(red: 0.90, green: 0.88, blue: 0.85, alpha: 0.60)
        // Sheep
        let sheepW     = UIColor(red: 0.90, green: 0.88, blue: 0.85, alpha: 0.65)
        let sheepD     = UIColor(red: 0.20, green: 0.18, blue: 0.18, alpha: 0.60)

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let c = ctx.cgContext

            func fill(_ fx: Int, _ fy: Int, _ fw: Int, _ fh: Int, _ color: UIColor) {
                guard fw > 0 && fh > 0 else { return }
                c.setFillColor(color.cgColor)
                c.fill(CGRect(x: CGFloat(fx) * ps, y: h - CGFloat(fy + fh) * ps,
                              width: CGFloat(fw) * ps, height: CGFloat(fh) * ps))
            }
            func dot(_ dx: Int, _ dy: Int, _ color: UIColor) { fill(dx, dy, 1, 1, color) }

            // ── HILLS TERRAIN ──
            for x in 0..<gridW {
                let mH = heightMap[x]
                for y in 0..<mH {
                    let yPos = h - CGFloat(y + 1) * ps
                    let ratio = CGFloat(y) / max(1, CGFloat(mH))
                    let color: UIColor
                    if y == mH - 1 { color = hillTop }
                    else if ratio > 0.6 { color = hillLight }
                    else if ratio > 0.3 { color = hillMid }
                    else { color = hillBase }
                    c.setFillColor(color.cgColor)
                    c.fill(CGRect(x: CGFloat(x) * ps, y: yPos, width: ps, height: ps))
                }
            }

            // ── WINDMILL ── (x=85, on hill)
            let wmx = 85, wmy = 20
            fill(wmx + 2, wmy, 4, 25, millBrown)
            fill(wmx + 3, wmy + 1, 2, 23, millLight)
            fill(wmx + 1, wmy + 25, 6, 2, millRoof)
            fill(wmx + 2, wmy + 27, 4, 1, millRoof)
            // Door
            fill(wmx + 3, wmy, 2, 4, barnDark)
            // Window
            fill(wmx + 3, wmy + 14, 2, 2, UIColor(red: 0.85, green: 0.75, blue: 0.45, alpha: 0.70))
            // Blades
            let bcx = wmx + 4, bcy = wmy + 26
            for i in 1..<8 {
                dot(bcx + i, bcy + i, bladeC); dot(bcx + i, bcy + i - 1, bladeC)
                dot(bcx - i, bcy + i, bladeC); dot(bcx - i, bcy + i - 1, bladeC)
                if i < 6 { dot(bcx + i, bcy - i, bladeC) }
                if i < 6 { dot(bcx - i, bcy - i, bladeC) }
            }

            // ── RED BARN ── (x=145)
            let bnx = 145, bny = 5
            fill(bnx, bny, 16, 12, barnRed)
            fill(bnx + 1, bny + 1, 14, 10, barnDark)
            // Barn door
            fill(bnx + 5, bny, 6, 8, barnDark)
            fill(bnx + 7, bny, 2, 8, barnRed)
            // Roof
            for dx in 0..<18 {
                let rh = max(0, 5 - abs(dx - 9) * 2 / 3)
                if rh > 0 { fill(bnx - 1 + dx, bny + 12, 1, rh, barnDark) }
            }
            // White trim
            fill(bnx, bny + 12, 16, 1, barnWhite)
            // Silo
            fill(bnx + 16, bny, 4, 16, barnDark)
            fill(bnx + 17, bny + 1, 2, 14, barnRed)
            fill(bnx + 16, bny + 16, 4, 1, barnWhite)

            // ── SMALL LAKE ── (x=110..130, y=2..5)
            fill(108, 2, 24, 3, lakeD)
            fill(110, 3, 20, 1, lakeL)
            for rx in stride(from: 112, to: 128, by: 5) { dot(rx, 4, lakeL) }

            // ── FENCE ── (x=55..75)
            for fx in stride(from: 55, to: 76, by: 5) { fill(fx, 0, 1, 6, fenceC) }
            fill(55, 2, 20, 1, fenceC); fill(55, 4, 20, 1, fenceC)

            // ── FLOWERS ──
            for (fx, fy, fc) in [(10,3,flowerR),(15,2,flowerY),(45,4,flowerW),
                                  (95,5,flowerR),(130,3,flowerY),(175,4,flowerW),
                                  (188,2,flowerR),(25,3,flowerY)] {
                dot(fx, fy, fc)
                dot(fx, fy + 1, UIColor(red: 0.20, green: 0.45, blue: 0.15, alpha: 0.50))
            }

            // ── SHEEP ──
            for (sx, sy) in [(65, 3), (120, 4), (180, 3)] {
                fill(sx, sy, 3, 2, sheepW)
                dot(sx, sy + 2, sheepW) // Head
                dot(sx, sy - 1, sheepD) // Leg
                dot(sx + 2, sy - 1, sheepD)
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
            // White sailor cap — 3 rows above body
            let W = UIColor.white
            let N = UIColor(red: 0.10, green: 0.15, blue: 0.45, alpha: 1) // navy blue
            grid[0] = [C, C, C, C, C, B, B, B, B, C, C, C, C, C, C, C]
            grid[1] = [C, C, C, C, B, W, W, W, W, B, C, C, C, C, C, C]
            grid[2] = [C, C, C, B, B, W, N, W, W, B, B, C, C, C, C, C]

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

    // MARK: - Pixel Trees

    private func renderPixelTrees() -> UIImage {
        let w: CGFloat = GK.worldWidth * 2
        let h: CGFloat = 160
        let ps: CGFloat = 4  // pixel size

        // Tree templates (relative pixel grids)
        let tG = UIColor(red: 0.25, green: 0.55, blue: 0.20, alpha: 0.75)    // dark green canopy
        let tg = UIColor(red: 0.35, green: 0.70, blue: 0.28, alpha: 0.70)    // light green canopy
        let tD = UIColor(red: 0.20, green: 0.48, blue: 0.18, alpha: 0.75)    // darkest green
        let tT = UIColor(red: 0.45, green: 0.32, blue: 0.18, alpha: 0.70)    // trunk brown
        let tB = UIColor(red: 0.30, green: 0.58, blue: 0.22, alpha: 0.65)    // bush
        let C  = UIColor.clear

        // Round deciduous tree (9 wide × 12 tall)
        let roundTree: [[UIColor]] = [
            [C, C, C, tD,tD,tD, C, C, C],
            [C, C, tD,tG,tG,tG,tD, C, C],
            [C, tD,tG,tG,tg,tG,tG,tD, C],
            [tD,tG,tG,tg,tg,tG,tG,tG,tD],
            [tD,tG,tg,tG,tG,tG,tG,tG,tD],
            [tD,tG,tG,tG,tG,tG,tG,tG,tD],
            [C, tD,tG,tG,tG,tG,tG,tD, C],
            [C, C, tD,tD,tG,tD,tD, C, C],
            [C, C, C, C, tT, C, C, C, C],
            [C, C, C, C, tT, C, C, C, C],
            [C, C, C, C, tT, C, C, C, C],
            [C, C, C, C, tT, C, C, C, C],
        ]

        // Pine tree (7 wide × 14 tall)
        let pineTree: [[UIColor]] = [
            [C, C, C, tD, C, C, C],
            [C, C, tD,tG,tD, C, C],
            [C, C, tD,tG,tD, C, C],
            [C, tD,tG,tG,tG,tD, C],
            [C, tD,tG,tg,tG,tD, C],
            [tD,tG,tG,tG,tG,tG,tD],
            [tD,tG,tG,tg,tG,tG,tD],
            [C, C, tD,tG,tD, C, C],
            [C, tD,tG,tG,tG,tD, C],
            [tD,tG,tG,tg,tG,tG,tD],
            [tD,tG,tG,tG,tG,tG,tD],
            [C, C, C, tT, C, C, C],
            [C, C, C, tT, C, C, C],
            [C, C, C, tT, C, C, C],
        ]

        // Small bush (7 wide × 4 tall)
        let bush: [[UIColor]] = [
            [C, C, tB,tB,tB, C, C],
            [C, tB,tB,tg,tB,tB, C],
            [tB,tB,tg,tB,tB,tB,tB],
            [C, tB,tB,tB,tB,tB, C],
        ]

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let c = ctx.cgContext

            // Place trees at deterministic positions
            let treePositions: [(x: CGFloat, type: Int)] = [
                (30, 0), (110, 1), (170, 2), (230, 0), (290, 1),
                (360, 0), (430, 2), (480, 0), (540, 1), (610, 0),
                (670, 2), (720, 0), (780, 1),
            ]

            for pos in treePositions {
                let template: [[UIColor]]
                switch pos.type {
                case 0: template = roundTree
                case 1: template = pineTree
                default: template = bush
                }

                let templateH = template.count
                let templateW = template[0].count
                let baseY = h - CGFloat(templateH) * ps  // anchor to bottom

                for row in 0..<templateH {
                    for col in 0..<templateW {
                        let color = template[row][col]
                        guard color != UIColor.clear else { continue }
                        c.setFillColor(color.cgColor)
                        c.fill(CGRect(
                            x: pos.x + CGFloat(col) * ps,
                            y: baseY + CGFloat(row) * ps,
                            width: ps,
                            height: ps
                        ))
                    }
                }
            }

            // Pixel-art park benches
            let benchColor = UIColor(red: 0.40, green: 0.28, blue: 0.15, alpha: 0.50)
            let benchPositions: [CGFloat] = [150, 450, 700]
            for bx in benchPositions {
                let by = h - 3 * ps
                c.setFillColor(benchColor.cgColor)
                // Seat
                for i in 0..<6 { c.fill(CGRect(x: bx + CGFloat(i) * ps, y: by, width: ps, height: ps)) }
                // Back
                for i in 0..<6 { c.fill(CGRect(x: bx + CGFloat(i) * ps, y: by - ps, width: ps, height: ps)) }
                // Legs
                c.fill(CGRect(x: bx, y: by + ps, width: ps, height: ps * 2))
                c.fill(CGRect(x: bx + 5 * ps, y: by + ps, width: ps, height: ps * 2))
            }
        }
    }

    // MARK: - Themed Hills Rendering

    private func renderThemedHills(theme: BackgroundTheme) -> UIImage {
        switch theme {
        case .day:                          return renderPixelHills()
        case .sunset:                       return renderSunsetHills()
        case .night:                        return renderNightHills()
        case .neonCity:                     return renderCitySkylineHills(neon: true)
        case .pixelTokyo:                   return renderCitySkylineHills(neon: false)
        case .underwater:                   return renderCoralReefHills()
        case .volcano:                      return renderVolcanoHills()
        case .arctic:                       return renderArcticHills()
        case .western:                      return renderWesternMesaHills()
        case .jungle:                       return renderJungleCanopyHills()
        case .egypt:                        return renderEgyptPyramidHills()
        case .cave:                         return renderCaveFormationHills()
        case .mountain:                     return renderMountainPeakHills()
        case .space:                        return renderSpaceTerrainHills()
        case .lagoon:                       return renderLagoonIslandHills()
        case .losAngeles:                   return renderLosAngelesHollywoodHills()
        case .london:                       return renderLondonSkylineHills()
        }
    }

    // MARK: Sunset Hills — warm amber recolor of classic hills

    private func renderSunsetHills() -> UIImage {
        let w: CGFloat = GK.worldWidth * 2
        let h: CGFloat = 300
        let ps: CGFloat = 4
        let gridW = Int(w / ps)

        var heightMap = [Int](repeating: 1, count: gridW)
        let bumps: [(center: Int, radius: Int, peak: Int)] = [
            (20, 22, 22), (50, 18, 16), (80, 28, 30), (110, 14, 12),
            (140, 24, 26), (170, 18, 20), (195, 16, 16),
        ]
        for bump in bumps {
            for x in max(0, bump.center - bump.radius)..<min(gridW, bump.center + bump.radius) {
                let dist = abs(x - bump.center)
                let nd = CGFloat(dist) / CGFloat(bump.radius)
                heightMap[x] = max(heightMap[x], Int(CGFloat(bump.peak) * (1.0 - nd * nd)))
            }
        }

        let hillBase  = UIColor(red: 0.50, green: 0.32, blue: 0.15, alpha: 0.72)
        let hillMid   = UIColor(red: 0.58, green: 0.38, blue: 0.18, alpha: 0.68)
        let hillLight = UIColor(red: 0.68, green: 0.48, blue: 0.22, alpha: 0.62)
        let hillTop   = UIColor(red: 0.42, green: 0.26, blue: 0.12, alpha: 0.78)
        // Barn
        let barnRed   = UIColor(red: 0.60, green: 0.15, blue: 0.10, alpha: 0.80)
        let barnDark  = UIColor(red: 0.45, green: 0.10, blue: 0.06, alpha: 0.82)
        let barnWhite = UIColor(red: 0.85, green: 0.80, blue: 0.72, alpha: 0.72)
        // Sunflowers
        let sfYellow  = UIColor(red: 0.95, green: 0.82, blue: 0.20, alpha: 0.75)
        let sfCenter  = UIColor(red: 0.40, green: 0.25, blue: 0.10, alpha: 0.78)
        let sfStem    = UIColor(red: 0.25, green: 0.45, blue: 0.15, alpha: 0.65)
        // Fence
        let fenceC    = UIColor(red: 0.45, green: 0.32, blue: 0.18, alpha: 0.60)
        // Hay bale
        let hayC      = UIColor(red: 0.72, green: 0.60, blue: 0.30, alpha: 0.65)
        let hayD      = UIColor(red: 0.55, green: 0.45, blue: 0.22, alpha: 0.68)
        // Sunset birds
        let birdC     = UIColor(red: 0.20, green: 0.15, blue: 0.10, alpha: 0.45)

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let c = ctx.cgContext

            func fill(_ fx: Int, _ fy: Int, _ fw: Int, _ fh: Int, _ color: UIColor) {
                guard fw > 0 && fh > 0 else { return }
                c.setFillColor(color.cgColor)
                c.fill(CGRect(x: CGFloat(fx) * ps, y: h - CGFloat(fy + fh) * ps,
                              width: CGFloat(fw) * ps, height: CGFloat(fh) * ps))
            }
            func dot(_ dx: Int, _ dy: Int, _ color: UIColor) { fill(dx, dy, 1, 1, color) }

            // Hills terrain
            for x in 0..<gridW {
                let mH = heightMap[x]
                for y in 0..<mH {
                    let yPos = h - CGFloat(y + 1) * ps
                    let ratio = CGFloat(y) / max(1, CGFloat(mH))
                    let color: UIColor
                    if y == mH - 1 { color = hillTop }
                    else if ratio > 0.6 { color = hillLight }
                    else if ratio > 0.3 { color = hillMid }
                    else { color = hillBase }
                    c.setFillColor(color.cgColor)
                    c.fill(CGRect(x: CGFloat(x) * ps, y: yPos, width: ps, height: ps))
                }
            }

            // ── BARN + SILO ── (x=120)
            fill(120, 3, 18, 14, barnRed)
            fill(121, 4, 16, 12, barnDark)
            fill(126, 3, 6, 8, barnDark) // Door
            fill(128, 3, 2, 8, barnRed)  // Door center
            for dx in 0..<20 { let rh = max(0, 5 - abs(dx - 10) * 2 / 3); if rh > 0 { fill(119 + dx, 17, 1, rh, barnDark) } }
            fill(120, 17, 18, 1, barnWhite)
            fill(138, 3, 5, 18, barnDark); fill(139, 4, 3, 16, barnRed)
            fill(138, 21, 5, 1, barnWhite)

            // ── SUNFLOWERS ── (field near barn)
            for (sx, sy) in [(100,5),(103,6),(106,4),(109,6),(112,5),(95,4),
                             (150,5),(153,4),(156,6),(159,4)] {
                fill(sx, sy - 2, 1, 3, sfStem) // Stem
                dot(sx - 1, sy + 1, sfYellow); dot(sx + 1, sy + 1, sfYellow)
                dot(sx, sy + 2, sfYellow); dot(sx, sy, sfYellow)
                dot(sx, sy + 1, sfCenter) // Center
            }

            // ── FENCE ── (x=60..90)
            for fx in stride(from: 60, to: 91, by: 5) { fill(fx, 0, 1, 7, fenceC) }
            fill(60, 3, 30, 1, fenceC); fill(60, 5, 30, 1, fenceC)

            // ── HAY BALES ──
            for (hx, hy) in [(70, 2), (78, 2), (170, 3)] {
                fill(hx, hy, 5, 3, hayC); fill(hx + 1, hy + 1, 3, 1, hayD)
                // Round top
                fill(hx + 1, hy + 3, 3, 1, hayC)
            }

            // ── BIRDS ──
            for (bx, by) in [(30, 55), (40, 58), (48, 56), (150, 60), (160, 57)] {
                dot(bx - 1, by + 1, birdC); dot(bx, by, birdC); dot(bx + 1, by + 1, birdC)
            }
        }
    }

    // MARK: Night Hills — dark blue silhouettes

    private func renderNightHills() -> UIImage {
        let w: CGFloat = GK.worldWidth * 2
        let h: CGFloat = 300
        let ps: CGFloat = 4
        let gridW = Int(w / ps)

        // Gentle rolling hills
        var heightMap = [Int](repeating: 1, count: gridW)
        let bumps: [(center: Int, radius: Int, peak: Int)] = [
            (20, 30, 22), (55, 25, 18), (85, 35, 28), (115, 20, 15),
            (145, 30, 25), (170, 25, 20), (195, 20, 16),
        ]
        for bump in bumps {
            for x in max(0, bump.center - bump.radius)..<min(gridW, bump.center + bump.radius) {
                let dist = abs(x - bump.center)
                let nd = CGFloat(dist) / CGFloat(bump.radius)
                heightMap[x] = max(heightMap[x], Int(CGFloat(bump.peak) * (1.0 - nd * nd)))
            }
        }

        let hillDark  = UIColor(red: 0.05, green: 0.15, blue: 0.08, alpha: 0.85)
        let hillMid   = UIColor(red: 0.08, green: 0.22, blue: 0.12, alpha: 0.80)
        let hillLight = UIColor(red: 0.12, green: 0.30, blue: 0.16, alpha: 0.75)
        let hillTop   = UIColor(red: 0.04, green: 0.12, blue: 0.06, alpha: 0.88)
        // Moon
        let moonYellow  = UIColor(red: 0.98, green: 0.92, blue: 0.55, alpha: 0.95)
        let moonLight   = UIColor(red: 0.95, green: 0.88, blue: 0.50, alpha: 0.85)
        let moonGlow    = UIColor(red: 0.95, green: 0.90, blue: 0.55, alpha: 0.15)
        // Windmill
        let millBrown   = UIColor(red: 0.25, green: 0.16, blue: 0.08, alpha: 0.90)
        let millLight   = UIColor(red: 0.35, green: 0.24, blue: 0.14, alpha: 0.85)
        let bladeGray   = UIColor(red: 0.30, green: 0.28, blue: 0.25, alpha: 0.80)
        // Cottage
        let stoneGray   = UIColor(red: 0.35, green: 0.32, blue: 0.30, alpha: 0.88)
        let stoneDark   = UIColor(red: 0.25, green: 0.22, blue: 0.20, alpha: 0.90)
        let roofBrown   = UIColor(red: 0.22, green: 0.14, blue: 0.08, alpha: 0.92)
        let windowWarm  = UIColor(red: 0.95, green: 0.80, blue: 0.35, alpha: 0.90)
        let chimneyC    = UIColor(red: 0.30, green: 0.25, blue: 0.22, alpha: 0.88)
        let smokeC      = UIColor(red: 0.50, green: 0.50, blue: 0.55, alpha: 0.25)
        // Owl
        let owlBrown    = UIColor(red: 0.35, green: 0.22, blue: 0.12, alpha: 0.85)
        let owlLight    = UIColor(red: 0.50, green: 0.38, blue: 0.22, alpha: 0.80)
        let owlEye      = UIColor(red: 0.95, green: 0.85, blue: 0.20, alpha: 0.95)
        // Fence
        let fenceBrown  = UIColor(red: 0.30, green: 0.20, blue: 0.10, alpha: 0.70)
        // Firefly
        let fireflyY    = UIColor(red: 1.0, green: 0.95, blue: 0.40, alpha: 0.80)
        let fireflyGlow = UIColor(red: 1.0, green: 0.95, blue: 0.40, alpha: 0.25)
        // Pine tree
        let pineD       = UIColor(red: 0.04, green: 0.12, blue: 0.06, alpha: 0.85)
        let pineM       = UIColor(red: 0.06, green: 0.16, blue: 0.08, alpha: 0.80)
        // Path
        let pathC       = UIColor(red: 0.30, green: 0.22, blue: 0.14, alpha: 0.55)
        // Stars
        let starC       = UIColor(red: 0.90, green: 0.90, blue: 1.0, alpha: 0.60)

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let c = ctx.cgContext

            func fill(_ fx: Int, _ fy: Int, _ fw: Int, _ fh: Int, _ color: UIColor) {
                guard fw > 0 && fh > 0 else { return }
                c.setFillColor(color.cgColor)
                c.fill(CGRect(x: CGFloat(fx) * ps, y: h - CGFloat(fy + fh) * ps,
                              width: CGFloat(fw) * ps, height: CGFloat(fh) * ps))
            }
            func dot(_ dx: Int, _ dy: Int, _ color: UIColor) { fill(dx, dy, 1, 1, color) }

            // ── STARS ──
            let starPositions = [(10,68),(25,72),(45,65),(60,70),(75,67),(95,73),
                                 (110,66),(130,71),(150,68),(165,73),(180,65),(195,70),
                                 (5,60),(35,62),(55,58),(88,63),(120,60),(142,64),(175,61),(192,63)]
            for (sx, sy) in starPositions { dot(sx, sy, starC) }

            // ── CRESCENT MOON ── (x=30, y=52)
            let mx = 30, my = 52
            // Glow aura
            for dy in -3..<12 { for dx in -3..<12 {
                let dist = (dx - 4) * (dx - 4) + (dy - 4) * (dy - 4)
                if dist < 50 { dot(mx + dx, my + dy, moonGlow) }
            }}
            // Crescent shape (full circle minus offset circle)
            for dy in 0..<9 { for dx in 0..<9 {
                let cx1 = (dx - 4) * (dx - 4) + (dy - 4) * (dy - 4)
                let cx2 = (dx - 6) * (dx - 6) + (dy - 4) * (dy - 4)
                if cx1 <= 16 && cx2 > 12 {
                    dot(mx + dx, my + dy, moonYellow)
                } else if cx1 <= 18 && cx2 > 14 && cx1 > 16 {
                    dot(mx + dx, my + dy, moonLight)
                }
            }}

            // ── HILLS TERRAIN ──
            for x in 0..<gridW {
                let mH = heightMap[x]
                for y in 0..<mH {
                    let yPos = h - CGFloat(y + 1) * ps
                    let ratio = CGFloat(y) / max(1, CGFloat(mH))
                    let color: UIColor
                    if y == mH - 1 { color = hillTop }
                    else if ratio > 0.7 { color = hillLight }
                    else if ratio > 0.4 { color = hillMid }
                    else { color = hillDark }
                    c.setFillColor(color.cgColor)
                    c.fill(CGRect(x: CGFloat(x) * ps, y: yPos, width: ps, height: ps))
                }
            }

            // ── WINDING PATH ── (from x=95 bottom toward cottage at x=135)
            var pathX = 95
            for py in 0..<12 {
                let offset = Int(sin(CGFloat(py) * 0.5) * 3)
                fill(pathX + offset, py, 4, 1, pathC)
                pathX += 3
            }

            // ── PINE TREES ── (silhouettes)
            func drawPine(_ bx: Int, _ by: Int, _ ph: Int) {
                fill(bx + 2, by, 1, ph, pineD) // Trunk
                for layer in 0..<(ph - 2) {
                    let layerW = min(1 + layer, 5)
                    let cx = bx + 2 - layerW / 2
                    fill(cx, by + ph - 2 - layer + layer / 2, layerW, 1,
                         layer % 2 == 0 ? pineD : pineM)
                }
                // Triangular canopy
                for row in 0..<(ph * 2 / 3) {
                    let cw = min(row + 1, 7)
                    fill(bx + 2 - cw / 2, by + ph / 3 + row, cw, 1, pineD)
                }
            }
            drawPine(8, 0, 18); drawPine(18, 0, 14); drawPine(48, 0, 16)
            drawPine(160, 0, 20); drawPine(185, 0, 15); drawPine(195, 0, 12)

            // ── WOODEN FENCE ── (x=48..72)
            for fx in stride(from: 48, to: 73, by: 5) {
                fill(fx, 0, 1, 10, fenceBrown)
                dot(fx, 10, fenceBrown)
            }
            fill(48, 4, 24, 1, fenceBrown)
            fill(48, 7, 24, 1, fenceBrown)

            // ── OWL ON FENCE ── (x=55, y=10)
            let ox = 55, oy = 10
            fill(ox, oy, 4, 5, owlBrown)               // Body
            fill(ox + 1, oy + 1, 2, 3, owlLight)        // Chest
            fill(ox, oy + 5, 4, 2, owlBrown)            // Head
            dot(ox, oy + 6, owlBrown)                    // Ear tuft left
            dot(ox + 3, oy + 6, owlBrown)                // Ear tuft right
            dot(ox + 1, oy + 5, owlEye)                  // Left eye
            dot(ox + 2, oy + 5, owlEye)                  // Right eye

            // ── WINDMILL ── (x=80, y=10..45)
            let wmx = 80, wmy = 10
            // Tower body
            fill(wmx + 2, wmy, 5, 30, millBrown)
            fill(wmx + 3, wmy + 1, 3, 28, millLight)
            // Cap / roof
            fill(wmx + 1, wmy + 30, 7, 2, roofBrown)
            fill(wmx + 2, wmy + 32, 5, 2, roofBrown)
            fill(wmx + 3, wmy + 34, 3, 1, roofBrown)
            // Door
            fill(wmx + 3, wmy, 3, 4, roofBrown)
            // Window
            fill(wmx + 3, wmy + 16, 3, 3, windowWarm)
            fill(wmx + 4, wmy + 16, 1, 3, millBrown)   // Cross bar
            // Platform / balcony
            fill(wmx, wmy + 14, 9, 1, millBrown)
            // Blades (X shape from cap center)
            let bcx = wmx + 4, bcy = wmy + 33
            // Blade 1: upper-right
            for i in 1..<10 { dot(bcx + i, bcy + i, bladeGray) }
            for i in 1..<10 { fill(bcx + i, bcy + i - 1, 1, 2, bladeGray) }
            // Blade 2: upper-left
            for i in 1..<10 { dot(bcx - i, bcy + i, bladeGray) }
            for i in 1..<10 { fill(bcx - i, bcy + i - 1, 1, 2, bladeGray) }
            // Blade 3: lower-right
            for i in 1..<8 { dot(bcx + i, bcy - i, bladeGray) }
            // Blade 4: lower-left
            for i in 1..<8 { dot(bcx - i, bcy - i, bladeGray) }

            // ── COTTAGE ── (x=125, y=0..22)
            let cx = 125, cy = 0
            // Walls
            fill(cx, cy, 22, 14, stoneGray)
            fill(cx + 1, cy + 1, 20, 12, stoneDark)
            // Stone texture
            for row in stride(from: 1, to: 12, by: 3) {
                for col in stride(from: 1, to: 20, by: 5) {
                    fill(cx + col, cy + row, 3, 2, stoneGray)
                }
            }
            // Peaked roof
            for dx in 0..<24 {
                let rh = max(0, 8 - abs(dx - 12) * 2 / 3)
                if rh > 0 { fill(cx - 1 + dx, cy + 14, 1, rh, roofBrown) }
            }
            // Door
            fill(cx + 9, cy, 4, 7, roofBrown)
            fill(cx + 10, cy, 2, 6, doorDark)
            dot(cx + 11, cy + 3, windowWarm) // Handle
            // Windows (lit)
            fill(cx + 3, cy + 7, 4, 4, windowWarm)
            fill(cx + 5, cy + 7, 1, 4, stoneDark)  // Cross
            fill(cx + 3, cy + 9, 4, 1, stoneDark)
            fill(cx + 15, cy + 7, 4, 4, windowWarm)
            fill(cx + 17, cy + 7, 1, 4, stoneDark)
            fill(cx + 15, cy + 9, 4, 1, stoneDark)
            // Window glow spill
            fill(cx + 2, cy + 6, 6, 1, UIColor(red: 1, green: 0.9, blue: 0.4, alpha: 0.12))
            fill(cx + 14, cy + 6, 6, 1, UIColor(red: 1, green: 0.9, blue: 0.4, alpha: 0.12))
            // Chimney
            fill(cx + 17, cy + 18, 3, 6, chimneyC)
            fill(cx + 17, cy + 24, 4, 1, chimneyC) // Cap
            // Smoke puffs
            dot(cx + 18, cy + 25, smokeC)
            dot(cx + 19, cy + 27, smokeC)
            fill(cx + 17, cy + 26, 2, 1, smokeC)
            dot(cx + 20, cy + 29, smokeC)
            dot(cx + 18, cy + 30, smokeC)
            // Garden bushes
            fill(cx - 2, cy, 2, 3, pineD)
            fill(cx + 22, cy, 2, 3, pineD)

            // ── FIREFLIES ──
            let fireflyPos = [(15,8),(22,15),(42,12),(62,18),(70,6),(88,20),
                              (100,14),(115,8),(138,16),(152,10),(172,12),(182,18),
                              (28,22),(78,25),(120,20),(165,22),(145,5),(55,10)]
            for (fx, fy) in fireflyPos {
                dot(fx, fy, fireflyY)
                // Glow
                for gx in -1...1 { for gy in -1...1 {
                    if gx != 0 || gy != 0 { dot(fx + gx, fy + gy, fireflyGlow) }
                }}
            }
        }
    }

    // MARK: City Skyline Hills — neonCity & pixelTokyo

    private func renderCitySkylineHills(neon: Bool) -> UIImage {
        let w: CGFloat = GK.worldWidth * 2
        let h: CGFloat = 300
        let ps: CGFloat = 4
        let gridW = Int(w / ps)
        let gridH = Int(h / ps)

        // Building palette
        let wallDark  = neon ? UIColor(red: 0.12, green: 0.06, blue: 0.22, alpha: 0.85)
                             : UIColor(red: 0.15, green: 0.10, blue: 0.25, alpha: 0.85)
        let wallMid   = neon ? UIColor(red: 0.18, green: 0.08, blue: 0.30, alpha: 0.80)
                             : UIColor(red: 0.20, green: 0.12, blue: 0.32, alpha: 0.80)
        let wallLight = neon ? UIColor(red: 0.25, green: 0.12, blue: 0.40, alpha: 0.75)
                             : UIColor(red: 0.28, green: 0.15, blue: 0.38, alpha: 0.75)
        let roofColor = neon ? UIColor(red: 0.10, green: 0.04, blue: 0.18, alpha: 0.90)
                             : UIColor(red: 0.12, green: 0.06, blue: 0.20, alpha: 0.90)

        // Window glow colors
        let windowYellow = UIColor(red: 1.0, green: 0.90, blue: 0.40, alpha: 0.9)
        let windowCyan   = UIColor(red: 0.30, green: 0.90, blue: 1.0, alpha: 0.85)
        let windowPink   = UIColor(red: 1.0, green: 0.35, blue: 0.70, alpha: 0.85)
        let windowOff    = UIColor(red: 0.08, green: 0.05, blue: 0.15, alpha: 0.7)
        let windowColors = [windowYellow, windowCyan, windowPink, windowOff, windowOff]

        // Neon sign glow colors
        let neonCyan  = UIColor(red: 0.20, green: 0.85, blue: 0.95, alpha: 0.35)
        let neonPink  = UIColor(red: 0.95, green: 0.25, blue: 0.60, alpha: 0.35)
        let neonGreen = UIColor(red: 0.20, green: 0.90, blue: 0.40, alpha: 0.30)

        // Deterministic building specs: (xPixel, widthPixels, heightPixels)
        let buildings: [(x: Int, w: Int, h: Int)] = [
            (2, 8, 45), (12, 6, 30), (20, 10, 55), (32, 5, 22),
            (39, 9, 40), (50, 7, 50), (59, 11, 62), (72, 6, 28),
            (80, 8, 42), (90, 10, 58), (102, 5, 20), (109, 9, 48),
            (120, 7, 35), (129, 11, 65), (142, 6, 25), (150, 8, 52),
            (160, 10, 38), (172, 7, 60), (181, 9, 32), (192, 6, 45),
        ]

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let c = ctx.cgContext

            for (bIdx, bld) in buildings.enumerated() {
                let bx = bld.x
                let bw = bld.w
                let bh = min(bld.h, gridH)

                // Building body
                for row in 0..<bh {
                    let yPos = h - CGFloat(row + 1) * ps
                    let color: UIColor
                    if row == bh - 1 { color = roofColor }
                    else if row > bh * 2 / 3 { color = wallLight }
                    else if row > bh / 3 { color = wallMid }
                    else { color = wallDark }
                    c.setFillColor(color.cgColor)
                    for col in bx..<(bx + bw) {
                        guard col < gridW else { break }
                        c.fill(CGRect(x: CGFloat(col) * ps, y: yPos, width: ps, height: ps))
                    }
                }

                // Windows — 2px wide, every other row starting from row 2
                for row in stride(from: 2, to: bh - 2, by: 3) {
                    for col in stride(from: bx + 1, to: bx + bw - 1, by: 3) {
                        guard col < gridW else { break }
                        let yPos = h - CGFloat(row + 1) * ps
                        let wc = windowColors[(row * 7 + col * 3) % windowColors.count]
                        c.setFillColor(wc.cgColor)
                        c.fill(CGRect(x: CGFloat(col) * ps, y: yPos, width: ps, height: ps))
                        if col + 1 < gridW && col + 1 < bx + bw - 1 {
                            c.fill(CGRect(x: CGFloat(col + 1) * ps, y: yPos, width: ps, height: ps))
                        }
                    }
                }

                // Antenna on tall buildings
                if bh > 18 {
                    let antX = bx + bw / 2
                    guard antX < gridW else { continue }
                    let antColor = neon ? UIColor(red: 1.0, green: 0.20, blue: 0.40, alpha: 0.9)
                                        : UIColor(red: 1.0, green: 0.30, blue: 0.30, alpha: 0.9)
                    c.setFillColor(roofColor.cgColor)
                    for i in 1...3 {
                        let yPos = h - CGFloat(bh + i) * ps
                        c.fill(CGRect(x: CGFloat(antX) * ps, y: yPos, width: ps, height: ps))
                    }
                    c.setFillColor(antColor.cgColor)
                    c.fill(CGRect(x: CGFloat(antX) * ps, y: h - CGFloat(bh + 4) * ps, width: ps, height: ps))
                }

                // Neon signs on some buildings (neon mode only)
                if neon && bw >= 7 && bh > 10 && bIdx % 3 == 0 {
                    let signY = h - CGFloat(bh / 2 + 2) * ps
                    let signX = CGFloat(bx + 1) * ps
                    let signW = CGFloat(bw - 2) * ps
                    let signColor = [neonCyan, neonPink, neonGreen][bIdx % 3]
                    // Neon sign rectangle glow
                    c.setFillColor(signColor.cgColor)
                    c.fill(CGRect(x: signX, y: signY, width: signW, height: ps))
                    c.fill(CGRect(x: signX, y: signY + ps * 2, width: signW, height: ps))
                    c.fill(CGRect(x: signX, y: signY, width: ps, height: ps * 3))
                    c.fill(CGRect(x: signX + signW - ps, y: signY, width: ps, height: ps * 3))
                    // Glow halo
                    let haloColor = signColor.withAlphaComponent(0.08)
                    c.setFillColor(haloColor.cgColor)
                    c.fill(CGRect(x: signX - ps, y: signY - ps, width: signW + ps * 2, height: ps * 5))
                }
            }

            // Rain streaks (neon only)
            if neon {
                let rainC = UIColor(red: 0.60, green: 0.70, blue: 0.85, alpha: 0.08)
                c.setFillColor(rainC.cgColor)
                for i in stride(from: 0, to: gridW, by: 5) {
                    let rx = CGFloat(i) * ps
                    let ry = CGFloat(i % 7) * ps * 2
                    c.fill(CGRect(x: rx, y: ry, width: ps * 0.5, height: ps * 3))
                }

                // Wet ground reflections at base
                let reflectC = UIColor(red: 0.25, green: 0.15, blue: 0.45, alpha: 0.10)
                c.setFillColor(reflectC.cgColor)
                c.fill(CGRect(x: 0, y: h - ps * 2, width: w, height: ps * 2))
            }
        }
    }

    // MARK: Coral Reef Hills — underwater

    private func renderCoralReefHills() -> UIImage {
        let w: CGFloat = GK.worldWidth * 2
        let h: CGFloat = 300
        let ps: CGFloat = 4
        let gridW = Int(w / ps)

        // Coral reef terrain
        var heightMap = [Int](repeating: 3, count: gridW)
        let bumps: [(center: Int, radius: Int, peak: Int)] = [
            (15, 20, 25), (45, 15, 18), (70, 25, 30), (95, 12, 20),
            (120, 18, 22), (145, 20, 28), (170, 15, 24), (195, 12, 18),
        ]
        for bump in bumps {
            for x in max(0, bump.center - bump.radius)..<min(gridW, bump.center + bump.radius) {
                let dist = abs(x - bump.center)
                let nd = CGFloat(dist) / CGFloat(bump.radius)
                heightMap[x] = max(heightMap[x], Int(CGFloat(bump.peak) * (1.0 - nd * nd)))
            }
        }

        // Water gradient
        let waterTop  = UIColor(red: 0.05, green: 0.20, blue: 0.45, alpha: 0.30)
        let waterMid  = UIColor(red: 0.08, green: 0.30, blue: 0.55, alpha: 0.25)
        // Coral colors
        let coralPinkD = UIColor(red: 0.65, green: 0.25, blue: 0.35, alpha: 0.85)
        let coralPinkL = UIColor(red: 0.80, green: 0.40, blue: 0.50, alpha: 0.80)
        let coralOrgD  = UIColor(red: 0.75, green: 0.40, blue: 0.15, alpha: 0.85)
        let coralOrgL  = UIColor(red: 0.90, green: 0.55, blue: 0.25, alpha: 0.80)
        let coralPurpD = UIColor(red: 0.40, green: 0.20, blue: 0.55, alpha: 0.82)
        let coralPurpL = UIColor(red: 0.55, green: 0.35, blue: 0.70, alpha: 0.78)
        let brainPinkD = UIColor(red: 0.70, green: 0.35, blue: 0.45, alpha: 0.80)
        let brainPinkL = UIColor(red: 0.85, green: 0.50, blue: 0.60, alpha: 0.75)
        let sandD      = UIColor(red: 0.60, green: 0.52, blue: 0.38, alpha: 0.65)
        let sandL      = UIColor(red: 0.72, green: 0.65, blue: 0.50, alpha: 0.60)
        // Kelp
        let kelpD      = UIColor(red: 0.15, green: 0.40, blue: 0.18, alpha: 0.80)
        let kelpL      = UIColor(red: 0.25, green: 0.55, blue: 0.25, alpha: 0.75)
        // Jellyfish
        let jellyBody  = UIColor(red: 0.60, green: 0.45, blue: 0.75, alpha: 0.50)
        let jellyLight = UIColor(red: 0.75, green: 0.60, blue: 0.88, alpha: 0.45)
        let jellyTent  = UIColor(red: 0.55, green: 0.40, blue: 0.70, alpha: 0.35)
        // Fish
        let fishOrange = UIColor(red: 0.95, green: 0.55, blue: 0.15, alpha: 0.80)
        let fishWhite  = UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 0.75)
        let fishYellow = UIColor(red: 0.95, green: 0.85, blue: 0.25, alpha: 0.78)
        let fishBlue   = UIColor(red: 0.20, green: 0.45, blue: 0.85, alpha: 0.78)
        let fishBlack  = UIColor(red: 0.10, green: 0.10, blue: 0.12, alpha: 0.75)
        // Treasure
        let chestBrn   = UIColor(red: 0.45, green: 0.28, blue: 0.10, alpha: 0.82)
        let goldC      = UIColor(red: 0.88, green: 0.75, blue: 0.20, alpha: 0.85)
        // Shell/starfish
        let shellPink  = UIColor(red: 0.82, green: 0.55, blue: 0.65, alpha: 0.65)
        let starOrange = UIColor(red: 0.90, green: 0.45, blue: 0.20, alpha: 0.70)
        let urchinD    = UIColor(red: 0.10, green: 0.08, blue: 0.15, alpha: 0.70)
        // Anemone
        let anemPink   = UIColor(red: 0.85, green: 0.40, blue: 0.55, alpha: 0.70)
        let anemBase   = UIColor(red: 0.65, green: 0.30, blue: 0.45, alpha: 0.75)
        // Light rays
        let lightRay   = UIColor(red: 0.50, green: 0.70, blue: 0.85, alpha: 0.06)
        // Tube coral
        let tubeD      = UIColor(red: 0.50, green: 0.25, blue: 0.60, alpha: 0.80)
        let tubeL      = UIColor(red: 0.65, green: 0.40, blue: 0.75, alpha: 0.75)

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let c = ctx.cgContext

            func fill(_ fx: Int, _ fy: Int, _ fw: Int, _ fh: Int, _ color: UIColor) {
                guard fw > 0 && fh > 0 else { return }
                c.setFillColor(color.cgColor)
                c.fill(CGRect(x: CGFloat(fx) * ps, y: h - CGFloat(fy + fh) * ps,
                              width: CGFloat(fw) * ps, height: CGFloat(fh) * ps))
            }
            func dot(_ dx: Int, _ dy: Int, _ color: UIColor) { fill(dx, dy, 1, 1, color) }

            // ── LIGHT RAYS FROM SURFACE ──
            for rx in stride(from: 25, to: 180, by: 30) {
                for ry in stride(from: 35, to: 74, by: 1) {
                    let offset = (74 - ry) / 5
                    fill(rx - offset, ry, 3, 1, lightRay)
                }
            }

            // ── WATER GRADIENT ──
            for y in 50..<75 {
                fill(0, y, gridW, 1, y > 62 ? waterTop : waterMid)
            }

            // ── CORAL REEF TERRAIN ──
            for x in 0..<gridW {
                let mH = heightMap[x]
                guard mH > 0 else { continue }
                for y in 0..<mH {
                    let yPos = h - CGFloat(y + 1) * ps
                    let ratio = CGFloat(y) / max(1, CGFloat(mH))
                    let color: UIColor
                    // Alternate coral colors based on position
                    let zone = (x / 25) % 4
                    if y < 3 { color = y % 2 == 0 ? sandD : sandL }
                    else if zone == 0 { color = ratio > 0.6 ? coralPinkL : coralPinkD }
                    else if zone == 1 { color = ratio > 0.6 ? coralOrgL : coralOrgD }
                    else if zone == 2 { color = ratio > 0.6 ? coralPurpL : coralPurpD }
                    else { color = ratio > 0.6 ? coralPinkL : coralPinkD }
                    c.setFillColor(color.cgColor)
                    c.fill(CGRect(x: CGFloat(x) * ps, y: yPos, width: ps, height: ps))
                }
            }

            // ── BRAIN CORAL ── (round formations)
            func drawBrainCoral(_ cx: Int, _ cy: Int, _ r: Int) {
                for dy in -r...r {
                    for dx in -r...r {
                        if dx * dx + dy * dy <= r * r {
                            let swirl = (dx + dy + r) % 3 == 0
                            dot(cx + dx, cy + dy, swirl ? brainPinkL : brainPinkD)
                        }
                    }
                }
            }
            drawBrainCoral(22, 12, 5)
            drawBrainCoral(175, 10, 4)
            drawBrainCoral(95, 8, 3)

            // ── FAN CORAL ── (branching structure)
            func drawFanCoral(_ bx: Int, _ by: Int, _ fh: Int, _ dark: UIColor, _ light: UIColor) {
                fill(bx, by, 1, fh, dark) // Main stem
                for i in 1..<fh {
                    if i % 2 == 0 {
                        let spread = min(i / 2, 4)
                        for s in 1...spread {
                            dot(bx - s, by + i, i % 4 < 2 ? dark : light)
                            dot(bx + s, by + i, i % 4 < 2 ? light : dark)
                        }
                    }
                }
            }
            drawFanCoral(50, 5, 16, coralPinkD, coralPinkL)
            drawFanCoral(130, 8, 14, coralOrgD, coralOrgL)

            // ── TUBE CORAL ──
            for (tx, th) in [(140, 10), (143, 8), (146, 11), (148, 7)] {
                fill(tx, 3, 2, th, tubeD)
                dot(tx, 3 + th, tubeL)  // Open top
                dot(tx + 1, 3 + th, tubeL)
            }

            // ── KELP STALKS ──
            func drawKelp(_ bx: Int, _ by: Int, _ kh: Int) {
                for i in 0..<kh {
                    let sway = Int(sin(CGFloat(i) * 0.4) * 1.5)
                    dot(bx + sway, by + i, i % 2 == 0 ? kelpD : kelpL)
                    if i % 4 == 0 { // Leaf
                        dot(bx + sway + 1, by + i, kelpL)
                        dot(bx + sway + 2, by + i + 1, kelpL)
                    }
                }
            }
            drawKelp(5, 3, 30); drawKelp(10, 5, 25)
            drawKelp(160, 4, 28); drawKelp(195, 3, 22)

            // ── JELLYFISH ──
            func drawJellyfish(_ jx: Int, _ jy: Int, _ jr: Int) {
                // Dome
                for dy in 0..<jr {
                    let dw = jr - dy
                    for dx in -dw...dw {
                        if dx * dx + dy * dy * 2 <= jr * jr {
                            dot(jx + dx, jy + dy, dy > jr / 2 ? jellyLight : jellyBody)
                        }
                    }
                }
                // Tentacles
                for t in stride(from: -jr + 1, to: jr, by: 2) {
                    for ty in 1..<(jr + 3) {
                        let sway = Int(sin(CGFloat(ty) * 0.6 + CGFloat(t)) * 1.5)
                        dot(jx + t + sway, jy - ty, jellyTent)
                    }
                }
            }
            drawJellyfish(60, 50, 4)
            drawJellyfish(150, 55, 5)
            drawJellyfish(90, 48, 3)

            // ── FISH ──
            // Clownfish (orange/white)
            func drawClownfish(_ fx: Int, _ fy: Int) {
                fill(fx, fy, 4, 2, fishOrange)
                fill(fx + 1, fy, 1, 2, fishWhite)
                fill(fx + 3, fy, 1, 2, fishWhite)
                dot(fx + 4, fy, fishOrange) // Tail
                dot(fx + 4, fy + 1, fishOrange)
                dot(fx, fy + 1, fishBlack) // Eye
            }
            drawClownfish(40, 38)
            drawClownfish(105, 42)

            // Blue tang
            func drawBlueTang(_ fx: Int, _ fy: Int) {
                fill(fx, fy, 4, 2, fishBlue)
                fill(fx + 1, fy, 2, 3, fishBlue) // Body depth
                dot(fx + 4, fy, fishYellow) // Tail
                dot(fx + 4, fy + 1, fishYellow)
                dot(fx, fy + 1, fishBlack) // Eye
            }
            drawBlueTang(75, 35)

            // Yellow tang
            fill(112, 30, 3, 2, fishYellow)
            dot(112, 31, fishBlack) // Eye
            dot(115, 30, fishYellow) // Tail

            // Small fish school (background)
            let schoolC = UIColor(red: 0.40, green: 0.50, blue: 0.60, alpha: 0.40)
            for (sx, sy) in [(82,45),(85,44),(88,46),(91,45),(94,44),(97,46)] {
                dot(sx, sy, schoolC); dot(sx + 1, sy, schoolC)
            }

            // ── ANEMONE ──
            func drawAnemone(_ ax: Int, _ ay: Int) {
                fill(ax, ay, 4, 2, anemBase)
                // Waving tentacles
                for i in 0..<6 {
                    let sway = Int(sin(CGFloat(i) * 1.2) * 1)
                    dot(ax + i - 1 + sway, ay + 2, anemPink)
                    dot(ax + i - 1 + sway, ay + 3, anemPink)
                    if i % 2 == 0 { dot(ax + i - 1 + sway, ay + 4, anemPink) }
                }
            }
            drawAnemone(80, 5)
            drawAnemone(115, 3)

            // ── TREASURE CHEST ──
            let tcx = 165, tcy = 4
            fill(tcx, tcy, 6, 4, chestBrn)
            fill(tcx, tcy + 4, 7, 2, chestBrn) // Open lid
            fill(tcx + 1, tcy + 1, 4, 2, goldC)
            dot(tcx + 2, tcy + 3, goldC)
            dot(tcx + 6, tcy, goldC) // Spilled coins
            dot(tcx + 7, tcy + 1, goldC)

            // ── SEA URCHINS ──
            for (ux, uy) in [(30, 3), (100, 4), (155, 3)] {
                fill(ux, uy, 3, 2, urchinD)
                dot(ux, uy + 2, urchinD); dot(ux + 2, uy + 2, urchinD)
                dot(ux + 1, uy - 1, urchinD)
            }

            // ── STARFISH ──
            for (sfx, sfy) in [(42, 3), (120, 2), (180, 4)] {
                dot(sfx, sfy + 1, starOrange)
                dot(sfx - 1, sfy, starOrange); dot(sfx + 1, sfy, starOrange)
                dot(sfx, sfy + 2, starOrange); dot(sfx, sfy, starOrange)
            }

            // ── SEASHELLS ──
            for (shx, shy) in [(55, 2), (140, 3), (190, 2)] {
                dot(shx, shy, shellPink); dot(shx + 1, shy, shellPink)
                dot(shx, shy + 1, shellPink)
            }
        }
    }

    // MARK: Volcano Hills — jagged rocky mountains with lava glow

    private func renderVolcanoHills() -> UIImage {
        let w: CGFloat = GK.worldWidth * 2
        let h: CGFloat = 300
        let ps: CGFloat = 4
        let gridW = Int(w / ps)

        // Jagged volcanic mountains
        var heightMap = [Int](repeating: 1, count: gridW)
        let peaks: [(center: Int, radius: Int, peak: Int)] = [
            (20, 20, 35), (55, 15, 50), (80, 25, 40),
            (110, 12, 55), (140, 18, 45), (165, 14, 38), (190, 20, 42),
        ]
        for p in peaks {
            for x in max(0, p.center - p.radius)..<min(gridW, p.center + p.radius) {
                let dist = abs(x - p.center)
                let nd = CGFloat(dist) / CGFloat(p.radius)
                heightMap[x] = max(heightMap[x], Int(CGFloat(p.peak) * (1.0 - nd * nd)))
            }
        }

        let rockDark   = UIColor(red: 0.12, green: 0.08, blue: 0.06, alpha: 0.90)
        let rockMid    = UIColor(red: 0.22, green: 0.15, blue: 0.10, alpha: 0.88)
        let rockLight  = UIColor(red: 0.30, green: 0.20, blue: 0.14, alpha: 0.82)
        let rockHot    = UIColor(red: 0.35, green: 0.12, blue: 0.08, alpha: 0.80)
        let lavaD      = UIColor(red: 0.80, green: 0.20, blue: 0.05, alpha: 0.92)
        let lavaM      = UIColor(red: 0.95, green: 0.45, blue: 0.10, alpha: 0.90)
        let lavaL      = UIColor(red: 1.0, green: 0.70, blue: 0.20, alpha: 0.88)
        let lavaGlow   = UIColor(red: 1.0, green: 0.40, blue: 0.10, alpha: 0.15)
        let crackGlow  = UIColor(red: 0.90, green: 0.35, blue: 0.10, alpha: 0.60)
        let emberC     = UIColor(red: 1.0, green: 0.55, blue: 0.15, alpha: 0.70)
        let emberFaint = UIColor(red: 1.0, green: 0.45, blue: 0.10, alpha: 0.35)
        let smokeD     = UIColor(red: 0.25, green: 0.22, blue: 0.22, alpha: 0.20)
        let smokeL     = UIColor(red: 0.40, green: 0.38, blue: 0.38, alpha: 0.12)
        let charBark   = UIColor(red: 0.10, green: 0.08, blue: 0.06, alpha: 0.80)
        let charBranch = UIColor(red: 0.15, green: 0.12, blue: 0.10, alpha: 0.65)

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let c = ctx.cgContext

            func fill(_ fx: Int, _ fy: Int, _ fw: Int, _ fh: Int, _ color: UIColor) {
                guard fw > 0 && fh > 0 else { return }
                c.setFillColor(color.cgColor)
                c.fill(CGRect(x: CGFloat(fx) * ps, y: h - CGFloat(fy + fh) * ps,
                              width: CGFloat(fw) * ps, height: CGFloat(fh) * ps))
            }
            func dot(_ dx: Int, _ dy: Int, _ color: UIColor) { fill(dx, dy, 1, 1, color) }

            // ── LAVA GLOW AT BASE ──
            fill(0, 0, gridW, 6, lavaGlow)

            // ── VOLCANIC TERRAIN ──
            for x in 0..<gridW {
                let mH = heightMap[x]
                guard mH > 0 else { continue }
                for y in 0..<mH {
                    let yPos = h - CGFloat(y + 1) * ps
                    let ratio = CGFloat(y) / max(1, CGFloat(mH))
                    let color: UIColor
                    if ratio > 0.90 { color = rockHot }  // Summit glow
                    else if ratio > 0.65 { color = rockLight }
                    else if ratio > 0.35 { color = rockMid }
                    else { color = rockDark }
                    c.setFillColor(color.cgColor)
                    c.fill(CGRect(x: CGFloat(x) * ps, y: yPos, width: ps, height: ps))
                }
            }

            // ── LAVA CRATER GLOW ── (at tallest peak = x=110)
            let craterX = 110, craterPeak = heightMap[110]
            fill(craterX - 4, craterPeak - 2, 8, 4, lavaL)
            fill(craterX - 3, craterPeak, 6, 3, lavaM)
            fill(craterX - 2, craterPeak + 1, 4, 2, lavaD)
            // Glow above crater
            for gy in 1..<6 {
                let gw = max(1, 5 - gy)
                fill(craterX - gw / 2, craterPeak + 2 + gy, gw, 1,
                     UIColor(red: 1.0, green: 0.5, blue: 0.15, alpha: CGFloat(max(0.02, 0.12 - Double(gy) * 0.02))))
            }

            // ── LAVA RIVERS ── (flowing at base between rock formations)
            // River 1: x=25..65
            for x in 25..<65 {
                let waveY = Int(sin(CGFloat(x) * 0.3) * 1.5) + 2
                fill(x, waveY, 1, 2, lavaD)
                dot(x, waveY + 2, lavaM)
                if x % 4 == 0 { dot(x, waveY + 3, lavaL) }
            }
            // River 2: x=130..175
            for x in 130..<175 {
                let waveY = Int(sin(CGFloat(x) * 0.25 + 1.5) * 1.5) + 1
                fill(x, waveY, 1, 2, lavaD)
                dot(x, waveY + 2, lavaM)
                if x % 5 == 0 { dot(x, waveY + 3, lavaL) }
            }

            // ── CRACKED GROUND WITH GLOWING VEINS ──
            let crackPaths: [(start: Int, end: Int, baseY: Int)] = [
                (70, 90, 3), (95, 115, 2), (150, 168, 4),
            ]
            for crack in crackPaths {
                for x in crack.start..<crack.end {
                    let cy = crack.baseY + Int(sin(CGFloat(x) * 0.8) * 1.5)
                    dot(x, cy, crackGlow)
                    if x % 3 == 0 { dot(x, cy + 1, lavaGlow) }
                }
            }

            // ── CHARRED TREES ──
            func drawCharredTree(_ bx: Int, _ by: Int, _ th: Int) {
                // Trunk
                fill(bx, by, 2, th, charBark)
                // Branches (bare, no leaves)
                let branchY = by + th * 2 / 3
                // Left branches
                dot(bx - 1, branchY, charBranch)
                dot(bx - 2, branchY + 1, charBranch)
                dot(bx - 2, branchY + 2, charBranch)
                // Right branches
                dot(bx + 2, branchY + 2, charBranch)
                dot(bx + 3, branchY + 3, charBranch)
                dot(bx + 3, branchY + 4, charBranch)
                // Top
                dot(bx, by + th, charBranch)
                dot(bx + 1, by + th + 1, charBranch)
            }
            drawCharredTree(42, 5, 12)
            drawCharredTree(88, 4, 10)
            drawCharredTree(155, 6, 14)
            drawCharredTree(178, 3, 9)

            // ── SMOKE WISPS ── (above peaks)
            for (sx, sy) in [(55, 52), (110, 58), (140, 48)] {
                for i in 0..<5 {
                    let ox = Int(sin(CGFloat(i) * 1.2) * 2)
                    fill(sx + ox, sy + i * 2, 2, 2, smokeD)
                    if i > 1 { fill(sx + ox + 1, sy + i * 2 + 1, 3, 2, smokeL) }
                }
            }

            // ── EMBERS / SPARKS ──
            let emberPos = [(30,35),(48,42),(62,30),(75,45),(95,50),(105,40),
                            (118,48),(135,35),(148,42),(160,38),(175,44),(185,32),
                            (22,28),(68,38),(128,45),(170,30)]
            for (ex, ey) in emberPos {
                dot(ex, ey, (ex + ey) % 3 == 0 ? emberC : emberFaint)
            }
        }
    }

    // MARK: Arctic Hills — snow-capped mountain peaks

    private func renderArcticHills() -> UIImage {
        let w: CGFloat = GK.worldWidth * 2
        let h: CGFloat = 300
        let ps: CGFloat = 4
        let gridW = Int(w / ps)

        var heightMap = [Int](repeating: 1, count: gridW)
        let bumps: [(center: Int, radius: Int, peak: Int)] = [
            (20, 30, 38), (55, 20, 25), (85, 40, 52), (120, 18, 20),
            (150, 35, 48), (180, 22, 30), (198, 15, 22),
        ]
        for bump in bumps {
            for x in max(0, bump.center - bump.radius)..<min(gridW, bump.center + bump.radius) {
                let dist = abs(x - bump.center)
                let nd = CGFloat(dist) / CGFloat(bump.radius)
                heightMap[x] = max(heightMap[x], Int(CGFloat(bump.peak) * (1.0 - nd * nd)))
            }
        }

        let rockBase  = UIColor(red: 0.35, green: 0.40, blue: 0.50, alpha: 0.78)
        let rockMid   = UIColor(red: 0.45, green: 0.50, blue: 0.60, alpha: 0.72)
        let snowTop   = UIColor(red: 0.95, green: 0.97, blue: 1.0, alpha: 0.90)
        let snowMid   = UIColor(red: 0.85, green: 0.90, blue: 0.95, alpha: 0.82)
        let icicle    = UIColor(red: 0.80, green: 0.92, blue: 0.98, alpha: 0.70)
        let auroraG   = UIColor(red: 0.20, green: 0.80, blue: 0.45, alpha: 0.22)
        let auroraB   = UIColor(red: 0.25, green: 0.55, blue: 0.85, alpha: 0.18)
        let auroraP   = UIColor(red: 0.55, green: 0.30, blue: 0.75, alpha: 0.15)
        // Igloo
        let iglooW    = UIColor(red: 0.92, green: 0.95, blue: 0.98, alpha: 0.82)
        let iglooD    = UIColor(red: 0.78, green: 0.82, blue: 0.88, alpha: 0.78)
        let iglooDoor = UIColor(red: 0.30, green: 0.35, blue: 0.42, alpha: 0.70)
        // Penguin
        let penguinB  = UIColor(red: 0.10, green: 0.10, blue: 0.15, alpha: 0.78)
        let penguinW  = UIColor(red: 0.92, green: 0.90, blue: 0.88, alpha: 0.75)
        let penguinO  = UIColor(red: 0.90, green: 0.55, blue: 0.15, alpha: 0.75)
        // Polar bear
        let bearW     = UIColor(red: 0.92, green: 0.90, blue: 0.85, alpha: 0.72)
        let bearD     = UIColor(red: 0.80, green: 0.78, blue: 0.72, alpha: 0.68)
        let bearNose  = UIColor(red: 0.12, green: 0.10, blue: 0.10, alpha: 0.70)

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let c = ctx.cgContext

            func fill(_ fx: Int, _ fy: Int, _ fw: Int, _ fh: Int, _ color: UIColor) {
                guard fw > 0 && fh > 0 else { return }
                c.setFillColor(color.cgColor)
                c.fill(CGRect(x: CGFloat(fx) * ps, y: h - CGFloat(fy + fh) * ps,
                              width: CGFloat(fw) * ps, height: CGFloat(fh) * ps))
            }
            func dot(_ dx: Int, _ dy: Int, _ color: UIColor) { fill(dx, dy, 1, 1, color) }

            // ── AURORA BOREALIS ──
            let aurColors = [auroraG, auroraB, auroraP, auroraG, auroraB]
            for (i, ac) in aurColors.enumerated() {
                for x in 0..<gridW {
                    let wave = Int(sin(CGFloat(x) / CGFloat(gridW) * .pi * 3 + CGFloat(i) * 1.2) * 3)
                    fill(x, 66 + i * 2 + wave, 1, 2, ac)
                }
            }

            // ── MOUNTAIN PEAKS ──
            for x in 0..<gridW {
                let mH = heightMap[x]
                for y in 0..<mH {
                    let yPos = h - CGFloat(y + 1) * ps
                    let ratio = CGFloat(y) / max(1, CGFloat(mH))
                    let color: UIColor
                    if ratio > 0.80 { color = snowTop }
                    else if ratio > 0.65 { color = snowMid }
                    else if ratio > 0.35 { color = y % 2 == 0 ? rockMid : rockBase }
                    else { color = rockBase }
                    c.setFillColor(color.cgColor)
                    c.fill(CGRect(x: CGFloat(x) * ps, y: yPos, width: ps, height: ps))
                }
                // Icicles
                if mH > 5 && x > 0 && heightMap[x - 1] < mH - 2 && x % 5 == 0 {
                    fill(x, mH - 4, 1, 2, icicle)
                }
            }

            // ── IGLOO ── (x=40..55, y=0)
            let igx = 40
            for dy in 0..<7 {
                let dw = 7 - dy
                fill(igx + 7 - dw, dy, dw * 2, 1, dy % 2 == 0 ? iglooW : iglooD)
            }
            // Door tunnel
            fill(igx - 3, 0, 4, 3, iglooD)
            fill(igx - 2, 0, 2, 2, iglooDoor)

            // ── PENGUINS ──
            func drawPenguin(_ px: Int, _ py: Int) {
                fill(px, py, 2, 3, penguinB)
                fill(px, py + 1, 2, 1, penguinW) // Belly
                dot(px, py + 3, penguinB) // Head
                dot(px + 1, py + 3, penguinB)
                dot(px, py - 1, penguinO) // Feet
                dot(px + 1, py - 1, penguinO)
            }
            drawPenguin(55, 2); drawPenguin(58, 2); drawPenguin(62, 3)
            drawPenguin(160, 3); drawPenguin(164, 2)

            // ── POLAR BEAR ── (x=110, y=2)
            let pbx = 110
            fill(pbx, 2, 6, 4, bearW)         // Body
            fill(pbx + 1, 3, 4, 2, bearD)     // Shading
            fill(pbx - 1, 4, 2, 3, bearW)     // Head
            dot(pbx - 1, 6, bearW)             // Ear
            dot(pbx, 6, bearW)
            dot(pbx - 1, 5, bearNose)          // Nose
            fill(pbx, 1, 1, 1, bearD)          // Legs
            fill(pbx + 5, 1, 1, 1, bearD)
        }
    }

    // MARK: Space Terrain Hills — alien planet surface with nebula and ringed planet

    private func renderSpaceTerrainHills() -> UIImage {
        let w: CGFloat = GK.worldWidth * 2
        let h: CGFloat = 300
        let ps: CGFloat = 4
        let gridW = Int(w / ps)

        // Alien terrain — lumpy cratered surface
        var heightMap = [Int](repeating: 2, count: gridW)
        let bumps: [(center: Int, radius: Int, peak: Int)] = [
            (15, 18, 22), (45, 12, 15), (75, 20, 28), (100, 10, 12),
            (125, 16, 25), (155, 14, 20), (180, 18, 24),
        ]
        for bump in bumps {
            for x in max(0, bump.center - bump.radius)..<min(gridW, bump.center + bump.radius) {
                let dist = abs(x - bump.center)
                let nd = CGFloat(dist) / CGFloat(bump.radius)
                heightMap[x] = max(heightMap[x], Int(CGFloat(bump.peak) * (1.0 - nd * nd)))
            }
        }
        // Craters (depressions)
        let craters: [(center: Int, radius: Int, depth: Int)] = [
            (35, 5, 8), (90, 7, 10), (145, 4, 6), (170, 6, 8),
        ]
        for crater in craters {
            for x in max(0, crater.center - crater.radius)..<min(gridW, crater.center + crater.radius) {
                let dist = abs(x - crater.center)
                let nd = CGFloat(dist) / CGFloat(crater.radius)
                let dip = Int(CGFloat(crater.depth) * (1.0 - nd * nd))
                heightMap[x] = max(2, heightMap[x] - dip)
            }
        }

        let terrainD  = UIColor(red: 0.18, green: 0.14, blue: 0.25, alpha: 0.88)
        let terrainM  = UIColor(red: 0.28, green: 0.22, blue: 0.35, alpha: 0.85)
        let terrainL  = UIColor(red: 0.38, green: 0.32, blue: 0.45, alpha: 0.80)
        let terrainH  = UIColor(red: 0.48, green: 0.40, blue: 0.55, alpha: 0.70)
        // Planet colors
        let planetD   = UIColor(red: 0.20, green: 0.15, blue: 0.40, alpha: 0.85)
        let planetM   = UIColor(red: 0.30, green: 0.22, blue: 0.55, alpha: 0.82)
        let planetL   = UIColor(red: 0.40, green: 0.30, blue: 0.65, alpha: 0.78)
        let planetH   = UIColor(red: 0.50, green: 0.38, blue: 0.72, alpha: 0.70)
        let ringC     = UIColor(red: 0.55, green: 0.45, blue: 0.65, alpha: 0.65)
        let ringL     = UIColor(red: 0.70, green: 0.58, blue: 0.78, alpha: 0.55)
        // Stars
        let starBright = UIColor(red: 0.95, green: 0.95, blue: 1.0, alpha: 0.80)
        let starDim    = UIColor(red: 0.70, green: 0.70, blue: 0.85, alpha: 0.45)
        let starPink   = UIColor(red: 0.90, green: 0.60, blue: 0.70, alpha: 0.50)
        // Nebula
        let nebulaP    = UIColor(red: 0.50, green: 0.20, blue: 0.60, alpha: 0.08)
        let nebulaB    = UIColor(red: 0.20, green: 0.30, blue: 0.60, alpha: 0.08)
        // Satellite
        let satGray    = UIColor(red: 0.55, green: 0.55, blue: 0.60, alpha: 0.80)
        let satPanel   = UIColor(red: 0.30, green: 0.40, blue: 0.65, alpha: 0.78)
        // Galaxy
        let galaxyC    = UIColor(red: 0.60, green: 0.50, blue: 0.75, alpha: 0.35)
        let galaxyCore = UIColor(red: 0.80, green: 0.70, blue: 0.90, alpha: 0.55)
        // Crystals
        let alienCrystD = UIColor(red: 0.15, green: 0.50, blue: 0.55, alpha: 0.85)
        let alienCrystM = UIColor(red: 0.25, green: 0.65, blue: 0.70, alpha: 0.80)
        let alienCrystL = UIColor(red: 0.40, green: 0.82, blue: 0.88, alpha: 0.75)
        let alienGlow   = UIColor(red: 0.25, green: 0.70, blue: 0.75, alpha: 0.12)
        // Alien plants
        let plantPurp   = UIColor(red: 0.55, green: 0.20, blue: 0.60, alpha: 0.70)
        let plantPink   = UIColor(red: 0.75, green: 0.35, blue: 0.55, alpha: 0.65)
        let plantGlow   = UIColor(red: 0.60, green: 0.30, blue: 0.55, alpha: 0.12)
        // Asteroids
        let asteroidC   = UIColor(red: 0.35, green: 0.30, blue: 0.28, alpha: 0.70)

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let c = ctx.cgContext

            func fill(_ fx: Int, _ fy: Int, _ fw: Int, _ fh: Int, _ color: UIColor) {
                guard fw > 0 && fh > 0 else { return }
                c.setFillColor(color.cgColor)
                c.fill(CGRect(x: CGFloat(fx) * ps, y: h - CGFloat(fy + fh) * ps,
                              width: CGFloat(fw) * ps, height: CGFloat(fh) * ps))
            }
            func dot(_ dx: Int, _ dy: Int, _ color: UIColor) { fill(dx, dy, 1, 1, color) }

            // ── NEBULA WISPS ──
            for ny in stride(from: 40, to: 70, by: 4) {
                for nx in stride(from: 10, to: 90, by: 3) {
                    let wave = Int(sin(CGFloat(nx) * 0.15 + CGFloat(ny) * 0.3) * 2)
                    dot(nx + wave, ny, nebulaP)
                }
            }
            for ny in stride(from: 45, to: 65, by: 3) {
                for nx in stride(from: 120, to: 195, by: 3) {
                    let wave = Int(sin(CGFloat(nx) * 0.12 + CGFloat(ny) * 0.2) * 2)
                    dot(nx + wave, ny, nebulaB)
                }
            }

            // ── STARS ──
            let brightStars = [(5,55),(22,68),(42,60),(60,72),(78,58),(95,65),
                               (115,70),(132,55),(148,62),(168,72),(182,58),(198,66)]
            for (sx, sy) in brightStars { dot(sx, sy, starBright) }
            let dimStars = [(12,50),(28,62),(38,55),(52,67),(68,52),(85,63),
                            (102,58),(120,65),(138,50),(155,68),(175,53),(192,62),
                            (8,45),(35,48),(65,44),(105,48),(145,46),(185,47)]
            for (sx, sy) in dimStars { dot(sx, sy, starDim) }
            let pinkStars = [(18,58),(48,65),(88,70),(128,60),(158,55),(188,68)]
            for (sx, sy) in pinkStars { dot(sx, sy, starPink) }

            // ── RINGED PLANET ── (center x=120, y=50, radius ~12)
            let pcx = 120, pcy = 50, pr = 12
            for dy in -pr...pr {
                for dx in -pr...pr {
                    let dist2 = dx * dx + dy * dy
                    if dist2 <= pr * pr {
                        let ratio = CGFloat(dist2) / CGFloat(pr * pr)
                        let lightSide = dx < 0  // Light from left
                        let color: UIColor
                        if ratio < 0.3 { color = lightSide ? planetH : planetM }
                        else if ratio < 0.6 { color = lightSide ? planetL : planetD }
                        else if ratio < 0.85 { color = lightSide ? planetM : planetD }
                        else { color = planetD }
                        dot(pcx + dx, pcy + dy, color)
                    }
                }
            }
            // Ring (ellipse around planet)
            for rx in -18..<19 {
                let ringY1 = Int(CGFloat(rx) * 0.35)
                let ringY2 = ringY1 + 1
                // Skip ring behind planet
                if abs(rx) <= pr && ringY1 >= -2 { continue }
                dot(pcx + rx, pcy + ringY1, ringC)
                dot(pcx + rx, pcy + ringY2, ringL)
            }
            // Front part of ring (over planet)
            for rx in -6..<7 {
                let ringY = Int(CGFloat(rx) * 0.35) - 1
                dot(pcx + rx, pcy + ringY, ringL)
            }

            // ── GALAXY SPIRAL ── (x=35, y=62)
            let gx = 35, gy = 62
            dot(gx, gy, galaxyCore)
            dot(gx + 1, gy, galaxyCore); dot(gx, gy + 1, galaxyCore)
            for arm in 0..<20 {
                let angle = CGFloat(arm) * 0.6
                let radius = CGFloat(arm) * 0.5 + 1
                let sx = gx + Int(cos(angle) * radius)
                let sy = gy + Int(sin(angle) * radius)
                dot(sx, sy, galaxyC)
            }
            for arm in 0..<20 {
                let angle = CGFloat(arm) * 0.6 + .pi
                let radius = CGFloat(arm) * 0.5 + 1
                let sx = gx + Int(cos(angle) * radius)
                let sy = gy + Int(sin(angle) * radius)
                dot(sx, sy, galaxyC)
            }

            // ── SECOND GALAXY ── (smaller, x=175, y=65)
            let g2x = 175, g2y = 65
            dot(g2x, g2y, galaxyCore)
            for arm in 0..<12 {
                let angle = CGFloat(arm) * 0.7
                let radius = CGFloat(arm) * 0.4 + 1
                dot(g2x + Int(cos(angle) * radius), g2y + Int(sin(angle) * radius), galaxyC)
            }
            for arm in 0..<12 {
                let angle = CGFloat(arm) * 0.7 + .pi
                let radius = CGFloat(arm) * 0.4 + 1
                dot(g2x + Int(cos(angle) * radius), g2y + Int(sin(angle) * radius), galaxyC)
            }

            // ── SATELLITE ── (x=55, y=55)
            let stx = 55, sty = 55
            // Main body
            fill(stx, sty, 6, 3, satGray)
            fill(stx + 1, sty + 1, 4, 1, UIColor(red: 0.40, green: 0.55, blue: 0.70, alpha: 0.65))
            // Solar panels
            fill(stx - 5, sty, 4, 3, satPanel)
            fill(stx + 7, sty, 4, 3, satPanel)
            // Panel grid lines
            fill(stx - 3, sty, 1, 3, satGray)
            fill(stx + 9, sty, 1, 3, satGray)
            // Antenna
            dot(stx + 3, sty + 3, satGray)
            dot(stx + 3, sty + 4, satGray)
            // Dish
            dot(stx + 2, sty + 5, satGray)
            dot(stx + 4, sty + 5, satGray)

            // ── ASTEROID BELT ── (scattered rocks)
            let asteroids: [(x: Int, y: Int, s: Int)] = [
                (85, 38), (90, 40), (95, 37), (100, 39), (105, 36),
                (110, 38), (115, 35), (118, 37),
            ].map { ($0.0, $0.1, (($0.0 + $0.1) % 3) + 1) }
            for a in asteroids {
                fill(a.x, a.y, a.s, a.s, asteroidC)
                if a.s > 1 { dot(a.x, a.y + a.s - 1, terrainL) } // Highlight
            }

            // ── ALIEN TERRAIN ──
            for x in 0..<gridW {
                let mH = heightMap[x]
                guard mH > 0 else { continue }
                for y in 0..<mH {
                    let yPos = h - CGFloat(y + 1) * ps
                    let ratio = CGFloat(y) / max(1, CGFloat(mH))
                    let color: UIColor
                    if y == mH - 1 { color = terrainH }
                    else if ratio > 0.7 { color = terrainL }
                    else if ratio > 0.4 { color = terrainM }
                    else { color = terrainD }
                    c.setFillColor(color.cgColor)
                    c.fill(CGRect(x: CGFloat(x) * ps, y: yPos, width: ps, height: ps))
                }
            }

            // ── CRYSTAL FORMATIONS ON TERRAIN ──
            func drawAlienCrystal(_ bx: Int, _ by: Int, _ ch: Int) {
                for gy in -1..<(ch + 2) {
                    for gx in -2..<3 { dot(bx + gx, by + gy, alienGlow) }
                }
                for y in 0..<ch {
                    let cw = max(1, 3 - y * 3 / (ch * 2))
                    fill(bx - cw / 2, by + y, cw, 1,
                         y > ch * 2 / 3 ? alienCrystL : (y > ch / 3 ? alienCrystM : alienCrystD))
                }
                dot(bx, by + ch, alienCrystL)
            }
            drawAlienCrystal(18, 15, 10)
            drawAlienCrystal(22, 12, 7)
            drawAlienCrystal(155, 14, 9)
            drawAlienCrystal(160, 10, 6)

            // ── ALIEN PLANTS ──
            func drawAlienPlant(_ bx: Int, _ by: Int, _ ph: Int) {
                for gy in -1..<(ph + 2) {
                    for gx in -2..<3 { dot(bx + gx, by + gy, plantGlow) }
                }
                fill(bx, by, 1, ph, plantPurp)
                // Bulb tips
                for i in 0..<3 {
                    let tipY = by + ph - 1 + i
                    let tipX = bx + (i % 2 == 0 ? -1 : 1)
                    dot(tipX, tipY, plantPink)
                    dot(bx, tipY + 1, plantPink)
                }
            }
            drawAlienPlant(72, 20, 6)
            drawAlienPlant(140, 8, 5)
            drawAlienPlant(185, 16, 7)
        }
    }

    // MARK: Lagoon Island Hills — gentle tropical island mounds with palm silhouettes

    private func renderLagoonIslandHills() -> UIImage {
        let w: CGFloat = GK.worldWidth * 2
        let h: CGFloat = 300
        let ps: CGFloat = 4
        let gridW = Int(w / ps)

        // Water colors
        let waterD    = UIColor(red: 0.05, green: 0.30, blue: 0.50, alpha: 0.50)
        let waterM    = UIColor(red: 0.10, green: 0.45, blue: 0.60, alpha: 0.45)
        let waterL    = UIColor(red: 0.20, green: 0.55, blue: 0.70, alpha: 0.40)
        let foam      = UIColor(red: 0.85, green: 0.95, blue: 1.0, alpha: 0.50)
        // Ship hull
        let hullDark  = UIColor(red: 0.20, green: 0.12, blue: 0.06, alpha: 0.92)
        let hullMid   = UIColor(red: 0.32, green: 0.20, blue: 0.10, alpha: 0.90)
        let hullLight = UIColor(red: 0.42, green: 0.28, blue: 0.14, alpha: 0.85)
        let hullTrim  = UIColor(red: 0.65, green: 0.50, blue: 0.20, alpha: 0.80)
        // Sails
        let sailC     = UIColor(red: 0.92, green: 0.88, blue: 0.78, alpha: 0.90)
        let sailS     = UIColor(red: 0.80, green: 0.75, blue: 0.65, alpha: 0.85)
        // Skull
        let skullW    = UIColor(red: 0.15, green: 0.12, blue: 0.10, alpha: 0.90)
        // Mast / rigging
        let mastC     = UIColor(red: 0.28, green: 0.18, blue: 0.10, alpha: 0.88)
        let rigging   = UIColor(red: 0.25, green: 0.20, blue: 0.15, alpha: 0.40)
        // Flags
        let flagBlack = UIColor(red: 0.10, green: 0.08, blue: 0.08, alpha: 0.85)
        // Rocky island
        let rockD     = UIColor(red: 0.30, green: 0.25, blue: 0.20, alpha: 0.82)
        let rockL     = UIColor(red: 0.45, green: 0.38, blue: 0.30, alpha: 0.78)
        // Palm tree
        let trunkBrn  = UIColor(red: 0.40, green: 0.25, blue: 0.12, alpha: 0.85)
        let leafGrn   = UIColor(red: 0.15, green: 0.50, blue: 0.20, alpha: 0.80)
        let leafDrk   = UIColor(red: 0.10, green: 0.35, blue: 0.15, alpha: 0.82)
        // Treasure
        let chestBrn  = UIColor(red: 0.45, green: 0.28, blue: 0.10, alpha: 0.85)
        let goldC     = UIColor(red: 0.90, green: 0.78, blue: 0.20, alpha: 0.88)
        // Beach details
        let sandC     = UIColor(red: 0.85, green: 0.75, blue: 0.55, alpha: 0.55)
        let shellPink = UIColor(red: 0.85, green: 0.55, blue: 0.65, alpha: 0.60)
        let starOrange = UIColor(red: 0.90, green: 0.45, blue: 0.20, alpha: 0.65)
        let shellWhite = UIColor(red: 0.90, green: 0.85, blue: 0.75, alpha: 0.55)
        let cannonC   = UIColor(red: 0.15, green: 0.12, blue: 0.10, alpha: 0.80)

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let c = ctx.cgContext

            func fill(_ fx: Int, _ fy: Int, _ fw: Int, _ fh: Int, _ color: UIColor) {
                guard fw > 0 && fh > 0 else { return }
                c.setFillColor(color.cgColor)
                c.fill(CGRect(x: CGFloat(fx) * ps, y: h - CGFloat(fy + fh) * ps,
                              width: CGFloat(fw) * ps, height: CGFloat(fh) * ps))
            }
            func dot(_ dx: Int, _ dy: Int, _ color: UIColor) { fill(dx, dy, 1, 1, color) }

            // ── WATER BASE ──
            for y in 0..<8 {
                let wc = y < 3 ? waterD : (y < 6 ? waterM : waterL)
                fill(0, y, gridW, 1, wc)
            }
            // Foam lines
            for x in stride(from: 5, to: gridW, by: 12) {
                fill(x, 7, 6, 1, foam)
            }

            // ── ROCKY ISLANDS ──
            // Left island
            for x in 0..<20 {
                let ih = max(0, 12 - abs(x - 10))
                for y in 6..<(6 + ih) {
                    fill(x, y, 1, 1, y > 6 + ih - 3 ? rockL : rockD)
                }
            }
            // Right island
            for x in 180..<200 {
                let ih = max(0, 10 - abs(x - 190))
                for y in 6..<(6 + ih) {
                    fill(x, y, 1, 1, y > 6 + ih - 3 ? rockL : rockD)
                }
            }

            // ── PALM TREES ON ISLANDS ──
            func drawPalm(_ bx: Int, _ by: Int, _ ph: Int) {
                // Trunk (slightly curved)
                for i in 0..<ph {
                    let lean = i > ph / 2 ? 1 : 0
                    fill(bx + lean, by + i, 2, 1, trunkBrn)
                }
                let top = by + ph
                // Fronds
                for dx in -5..<6 {
                    let droop = abs(dx) > 3 ? -1 : (abs(dx) > 1 ? 0 : 1)
                    dot(bx + 1 + dx, top + droop, abs(dx) % 2 == 0 ? leafGrn : leafDrk)
                }
                for dx in -4..<5 {
                    let droop = abs(dx) > 2 ? -2 : -1
                    dot(bx + 1 + dx, top + droop + 2, leafDrk)
                }
                // Coconuts
                dot(bx, top - 1, chestBrn); dot(bx + 2, top - 1, chestBrn)
            }
            drawPalm(8, 14, 16)
            drawPalm(186, 12, 14)

            // ══════════════════════════════════════════════
            // ── MASSIVE PIRATE SHIP ── (center, x=50..150)
            // ══════════════════════════════════════════════
            let shipX = 50, shipBaseY = 4

            // Hull — curved bottom
            for x in 0..<100 {
                let distFromCenter = abs(x - 50)
                let hullH: Int
                if distFromCenter < 10 { hullH = 18 }
                else if distFromCenter < 20 { hullH = 17 }
                else if distFromCenter < 30 { hullH = 15 }
                else if distFromCenter < 40 { hullH = 12 }
                else if distFromCenter < 45 { hullH = 8 }
                else { hullH = max(0, 52 - distFromCenter) }
                guard hullH > 0 else { continue }

                for y in 0..<hullH {
                    let ratio = CGFloat(y) / CGFloat(max(1, hullH))
                    let hc: UIColor
                    if y == hullH - 1 { hc = hullTrim }  // Top railing
                    else if ratio > 0.7 { hc = hullLight }
                    else if ratio > 0.3 { hc = hullMid }
                    else { hc = hullDark }
                    dot(shipX + x, shipBaseY + y, hc)
                }
            }

            // Plank lines
            for py in stride(from: 3, to: 16, by: 3) {
                fill(shipX + 8, shipBaseY + py, 84, 1,
                     UIColor(red: 0.18, green: 0.10, blue: 0.05, alpha: 0.25))
            }

            // Cannon ports
            for cx in stride(from: 15, to: 85, by: 10) {
                fill(shipX + cx, shipBaseY + 8, 3, 2, cannonC)
                fill(shipX + cx, shipBaseY + 10, 3, 1, hullTrim)
            }

            // Bow (front) decoration
            fill(shipX + 95, shipBaseY + 10, 4, 2, hullTrim)
            fill(shipX + 97, shipBaseY + 8, 2, 2, hullTrim)

            // Stern (back) decoration
            fill(shipX, shipBaseY + 14, 8, 6, hullMid)
            fill(shipX + 1, shipBaseY + 16, 6, 3, hullLight)
            // Captain's windows
            fill(shipX + 2, shipBaseY + 17, 2, 2,
                 UIColor(red: 0.90, green: 0.80, blue: 0.40, alpha: 0.60))
            fill(shipX + 5, shipBaseY + 17, 2, 2,
                 UIColor(red: 0.90, green: 0.80, blue: 0.40, alpha: 0.60))

            // ── MASTS ──
            let mast1X = shipX + 25  // Foremast
            let mast2X = shipX + 50  // Mainmast (tallest)
            let mast3X = shipX + 72  // Mizzenmast
            let mastBaseY = shipBaseY + 18

            fill(mast1X, mastBaseY, 2, 38, mastC)     // Foremast
            fill(mast2X, mastBaseY, 2, 48, mastC)     // Mainmast
            fill(mast3X, mastBaseY, 2, 35, mastC)     // Mizzenmast

            // Cross beams (yards)
            fill(mast1X - 8, mastBaseY + 30, 18, 1, mastC)
            fill(mast1X - 6, mastBaseY + 20, 14, 1, mastC)
            fill(mast2X - 10, mastBaseY + 38, 22, 1, mastC)
            fill(mast2X - 8, mastBaseY + 28, 18, 1, mastC)
            fill(mast2X - 6, mastBaseY + 18, 14, 1, mastC)
            fill(mast3X - 7, mastBaseY + 28, 16, 1, mastC)
            fill(mast3X - 5, mastBaseY + 18, 12, 1, mastC)

            // ── SAILS ──
            // Foremast sails
            fill(mast1X - 7, mastBaseY + 21, 16, 8, sailC)
            fill(mast1X - 6, mastBaseY + 22, 14, 6, sailS)
            fill(mast1X - 5, mastBaseY + 31, 12, 5, sailC)

            // Mainmast sails (largest, skull on middle one)
            fill(mast2X - 9, mastBaseY + 29, 20, 8, sailC)
            fill(mast2X - 8, mastBaseY + 30, 18, 6, sailS)
            fill(mast2X - 7, mastBaseY + 19, 16, 8, sailC)
            fill(mast2X - 6, mastBaseY + 20, 14, 6, sailS)
            // Skull on main sail
            let skullX = mast2X - 3, skullY = mastBaseY + 31
            // Skull outline (6x5)
            fill(skullX + 1, skullY, 4, 1, skullW)    // Bottom
            fill(skullX, skullY + 1, 6, 3, skullW)    // Middle
            fill(skullX + 1, skullY + 4, 4, 1, skullW) // Top
            // Eye holes (clear = sail color)
            dot(skullX + 1, skullY + 3, sailS)
            dot(skullX + 4, skullY + 3, sailS)
            // Crossbones below
            dot(skullX, skullY - 1, skullW); dot(skullX + 5, skullY - 1, skullW)
            dot(skullX + 1, skullY - 2, skullW); dot(skullX + 4, skullY - 2, skullW)

            // Top sail
            fill(mast2X - 4, mastBaseY + 39, 10, 6, sailC)

            // Mizzenmast sails
            fill(mast3X - 6, mastBaseY + 19, 14, 8, sailC)
            fill(mast3X - 5, mastBaseY + 20, 12, 6, sailS)
            fill(mast3X - 4, mastBaseY + 29, 10, 5, sailC)

            // ── CROW'S NEST ── (on mainmast)
            fill(mast2X - 3, mastBaseY + 45, 8, 1, mastC)
            fill(mast2X - 2, mastBaseY + 44, 6, 1, mastC)
            fill(mast2X - 2, mastBaseY + 46, 1, 2, mastC)
            fill(mast2X + 3, mastBaseY + 46, 1, 2, mastC)

            // ── JOLLY ROGER FLAG ── (top of mainmast)
            let flagY = mastBaseY + 48
            fill(mast2X + 2, flagY, 6, 4, flagBlack)
            dot(mast2X + 4, flagY + 2, sailC)  // Tiny skull
            dot(mast2X + 5, flagY + 2, sailC)

            // ── RIGGING LINES ──
            // Diagonal lines between masts (simplified as dots)
            for i in 0..<15 {
                dot(mast1X + 2 + i * 2, mastBaseY + 36 - i, rigging)
            }
            for i in 0..<12 {
                dot(mast2X + 2 + i * 2, mastBaseY + 46 - i, rigging)
            }

            // ── WATER RIPPLES AROUND SHIP ──
            for rx in stride(from: shipX + 5, to: shipX + 95, by: 8) {
                fill(rx, shipBaseY - 1, 4, 1, foam)
            }

            // ── TREASURE CHEST ── (on right island)
            let tx = 182, ty = 14
            fill(tx, ty, 6, 4, chestBrn)              // Base
            fill(tx, ty + 4, 6, 1, chestBrn)          // Lid (open, tilted back)
            fill(tx + 1, ty + 5, 5, 2, chestBrn)      // Lid open
            fill(tx + 1, ty + 1, 4, 2, goldC)          // Gold inside
            dot(tx + 2, ty + 3, goldC); dot(tx + 3, ty + 3, goldC)
            // Gold coins spilling
            dot(tx + 6, ty, goldC); dot(tx + 6, ty + 1, goldC)
            dot(tx - 1, ty, goldC)

            // ── SEASHELLS & STARFISH ──
            // Starfish
            dot(170, 7, starOrange); dot(169, 8, starOrange)
            dot(171, 8, starOrange); dot(170, 9, starOrange)
            dot(170, 6, starOrange)
            // Shell
            dot(175, 7, shellPink); dot(176, 7, shellPink); dot(175, 8, shellPink)
            // Conch
            dot(30, 8, shellWhite); dot(31, 8, shellWhite); dot(31, 9, shellWhite)
            // Sand patches on islands
            fill(5, 7, 8, 1, sandC)
            fill(185, 7, 8, 1, sandC)
        }
    }

    // MARK: Los Angeles Hollywood Hills — rolling brown hills with HOLLYWOOD-like structures

    private func renderLosAngelesHollywoodHills() -> UIImage {
        let w: CGFloat = GK.worldWidth * 2
        let h: CGFloat = 300
        let ps: CGFloat = 4
        let gridW = Int(w / ps)

        // Rolling brown hills
        var heightMap = [Int](repeating: 3, count: gridW)
        let bumps: [(center: Int, radius: Int, peak: Int)] = [
            (25, 35, 40), (65, 25, 32), (100, 30, 45),
            (135, 20, 28), (165, 25, 35), (190, 20, 30),
        ]
        for bump in bumps {
            for x in max(0, bump.center - bump.radius)..<min(gridW, bump.center + bump.radius) {
                let dist = abs(x - bump.center)
                let nd = CGFloat(dist) / CGFloat(bump.radius)
                heightMap[x] = max(heightMap[x], Int(CGFloat(bump.peak) * (1.0 - nd * nd)))
            }
        }

        let hillDark   = UIColor(red: 0.28, green: 0.22, blue: 0.15, alpha: 0.82)
        let hillMid    = UIColor(red: 0.38, green: 0.30, blue: 0.20, alpha: 0.78)
        let hillLight  = UIColor(red: 0.48, green: 0.38, blue: 0.25, alpha: 0.72)
        let hillTop    = UIColor(red: 0.22, green: 0.18, blue: 0.12, alpha: 0.85)
        // Hollywood sign
        let signWhite  = UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 0.92)
        let signShadow = UIColor(red: 0.75, green: 0.75, blue: 0.78, alpha: 0.80)
        // Observatory
        let obsWall    = UIColor(red: 0.75, green: 0.72, blue: 0.65, alpha: 0.85)
        let obsDome    = UIColor(red: 0.50, green: 0.55, blue: 0.58, alpha: 0.82)
        let obsWindow  = UIColor(red: 0.90, green: 0.80, blue: 0.45, alpha: 0.75)
        // Skyline
        let bldgDark   = UIColor(red: 0.20, green: 0.22, blue: 0.28, alpha: 0.88)
        let bldgMid    = UIColor(red: 0.30, green: 0.32, blue: 0.38, alpha: 0.85)
        let bldgLight  = UIColor(red: 0.38, green: 0.42, blue: 0.50, alpha: 0.80)
        let windowLit  = UIColor(red: 0.95, green: 0.85, blue: 0.45, alpha: 0.70)
        let windowDark = UIColor(red: 0.15, green: 0.18, blue: 0.25, alpha: 0.60)
        // Palm trees
        let trunkBrn   = UIColor(red: 0.35, green: 0.22, blue: 0.12, alpha: 0.75)
        let palmGreen  = UIColor(red: 0.12, green: 0.35, blue: 0.15, alpha: 0.72)
        let palmDark   = UIColor(red: 0.08, green: 0.25, blue: 0.10, alpha: 0.75)
        // Highway
        let roadGray   = UIColor(red: 0.25, green: 0.25, blue: 0.28, alpha: 0.70)
        let lineYellow = UIColor(red: 0.90, green: 0.80, blue: 0.25, alpha: 0.60)
        // Cars
        let carRed     = UIColor(red: 0.75, green: 0.15, blue: 0.12, alpha: 0.72)
        let carWhite   = UIColor(red: 0.88, green: 0.88, blue: 0.90, alpha: 0.70)
        let carBlue    = UIColor(red: 0.20, green: 0.30, blue: 0.60, alpha: 0.70)
        // Beach / sunset reflection
        let sandC      = UIColor(red: 0.75, green: 0.65, blue: 0.45, alpha: 0.40)
        let reflectC   = UIColor(red: 0.70, green: 0.40, blue: 0.50, alpha: 0.25)
        // Sunset glow
        let sunsetGlow = UIColor(red: 0.90, green: 0.55, blue: 0.30, alpha: 0.08)

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let c = ctx.cgContext

            func fill(_ fx: Int, _ fy: Int, _ fw: Int, _ fh: Int, _ color: UIColor) {
                guard fw > 0 && fh > 0 else { return }
                c.setFillColor(color.cgColor)
                c.fill(CGRect(x: CGFloat(fx) * ps, y: h - CGFloat(fy + fh) * ps,
                              width: CGFloat(fw) * ps, height: CGFloat(fh) * ps))
            }
            func dot(_ dx: Int, _ dy: Int, _ color: UIColor) { fill(dx, dy, 1, 1, color) }

            // ── SUNSET GLOW ──
            fill(0, 50, gridW, 25, sunsetGlow)

            // ── HILLS TERRAIN ──
            for x in 0..<gridW {
                let mH = heightMap[x]
                guard mH > 0 else { continue }
                for y in 0..<mH {
                    let yPos = h - CGFloat(y + 1) * ps
                    let ratio = CGFloat(y) / max(1, CGFloat(mH))
                    let color: UIColor
                    if y == mH - 1 { color = hillTop }
                    else if ratio > 0.7 { color = hillLight }
                    else if ratio > 0.4 { color = hillMid }
                    else { color = hillDark }
                    c.setFillColor(color.cgColor)
                    c.fill(CGRect(x: CGFloat(x) * ps, y: yPos, width: ps, height: ps))
                }
            }

            // ── HOLLYWOOD SIGN ── (on hill at x=20..70)
            // Letters: H-O-L-L-Y-W-O-O-D
            let letters: [(xOff: Int, pattern: [(dx: Int, dy: Int, w: Int, h: Int)])] = [
                // H
                (0, [(0,0,1,7),(4,0,1,7),(1,3,3,1)]),
                // O
                (6, [(0,1,1,5),(4,1,1,5),(1,0,3,1),(1,6,3,1)]),
                // L
                (12, [(0,0,1,7),(1,0,3,1)]),
                // L
                (17, [(0,0,1,7),(1,0,3,1)]),
                // Y
                (22, [(0,4,1,3),(4,4,1,3),(1,3,1,1),(3,3,1,1),(2,0,1,3)]),
                // W
                (27, [(0,0,1,7),(4,0,1,7),(1,1,1,2),(3,1,1,2),(2,0,1,2)]),
                // O
                (33, [(0,1,1,5),(4,1,1,5),(1,0,3,1),(1,6,3,1)]),
                // O
                (39, [(0,1,1,5),(4,1,1,5),(1,0,3,1),(1,6,3,1)]),
                // D
                (45, [(0,0,1,7),(1,0,3,1),(1,6,3,1),(4,1,1,5)]),
            ]
            let signBaseX = 18, signBaseY = 35
            for letter in letters {
                for part in letter.pattern {
                    fill(signBaseX + letter.xOff + part.dx,
                         signBaseY + part.dy,
                         part.w, part.h, signWhite)
                }
                // Shadow
                for part in letter.pattern {
                    if part.dy == 0 {
                        fill(signBaseX + letter.xOff + part.dx + 1,
                             signBaseY - 1, part.w, 1, signShadow)
                    }
                }
            }

            // ── GRIFFITH OBSERVATORY ── (on hilltop x=8..28)
            let obx = 10, oby = 42
            // Main building
            fill(obx, oby, 18, 4, obsWall)
            fill(obx + 1, oby + 1, 16, 2, obsWall)
            // Central dome
            for dy in 0..<4 {
                let dw = 4 - dy
                fill(obx + 9 - dw, oby + 4 + dy, dw * 2, 1, obsDome)
            }
            dot(obx + 9, oby + 8, obsDome) // Tip
            // Side wings
            fill(obx - 2, oby, 3, 3, obsWall)
            fill(obx + 17, oby, 3, 3, obsWall)
            // Windows
            for wx in stride(from: obx + 2, to: obx + 16, by: 3) {
                dot(wx, oby + 2, obsWindow)
            }

            // ── DOWNTOWN SKYLINE ── (x=120..185)
            let buildings: [(x: Int, bw: Int, bh: Int)] = [
                (120, 5, 40), (126, 6, 48), (133, 4, 35), (138, 7, 52),
                (146, 5, 38), (152, 6, 45), (159, 4, 30), (164, 5, 42),
                (170, 6, 35), (177, 5, 28), (183, 4, 32),
            ]
            for bldg in buildings {
                let color = bldg.bh > 40 ? bldgMid : bldgDark
                fill(bldg.x, 5, bldg.bw, bldg.bh, color)
                // Windows
                for wy in stride(from: 8, to: 5 + bldg.bh - 2, by: 3) {
                    for wx in stride(from: bldg.x + 1, to: bldg.x + bldg.bw - 1, by: 2) {
                        dot(wx, wy, (wx + wy) % 5 < 3 ? windowLit : windowDark)
                    }
                }
                // Rooftop details
                if bldg.bh > 35 {
                    fill(bldg.x + bldg.bw / 2, 5 + bldg.bh, 1, 3, bldgLight) // Antenna
                }
            }

            // ── PALM TREES ──
            func drawPalm(_ bx: Int, _ by: Int, _ ph: Int) {
                for i in 0..<ph {
                    let lean = i > ph * 2 / 3 ? 1 : 0
                    fill(bx + lean, by + i, 1, 1, trunkBrn)
                }
                let top = by + ph
                for dx in -4..<5 {
                    let droop = abs(dx) > 2 ? -1 : (abs(dx) > 0 ? 0 : 1)
                    dot(bx + 1 + dx, top + droop, abs(dx) % 2 == 0 ? palmGreen : palmDark)
                }
                for dx in -3..<4 {
                    let droop = abs(dx) > 1 ? -2 : -1
                    dot(bx + 1 + dx, top + droop + 2, palmDark)
                }
            }
            drawPalm(90, 5, 22)
            drawPalm(108, 5, 18)
            drawPalm(195, 5, 20)

            // ── HIGHWAY ── (y=5..8)
            fill(0, 5, gridW, 4, roadGray)
            // Center line
            for lx in stride(from: 0, to: gridW, by: 6) {
                fill(lx, 7, 3, 1, lineYellow)
            }
            // Cars
            fill(82, 6, 4, 2, carRed)
            fill(115, 6, 4, 2, carWhite)
            fill(150, 8, 4, 2, carBlue)

            // ── BEACH / WATER ── (y=0..4)
            fill(0, 0, gridW, 3, reflectC)
            fill(0, 3, gridW, 2, sandC)
        }
    }

    // MARK: London Skyline Hills — iconic London skyline with Big Ben, Parliament, Eye

    private func renderLondonSkylineHills() -> UIImage {
        let w: CGFloat = GK.worldWidth * 2
        let h: CGFloat = 300
        let ps: CGFloat = 4
        let gridW = Int(w / ps)

        // Moody London sky colors
        let skyDark   = UIColor(red: 0.18, green: 0.18, blue: 0.28, alpha: 0.15)
        let cloudC    = UIColor(red: 0.30, green: 0.28, blue: 0.35, alpha: 0.12)
        // Stone / building
        let stoneD    = UIColor(red: 0.40, green: 0.35, blue: 0.30, alpha: 0.90)
        let stoneM    = UIColor(red: 0.50, green: 0.45, blue: 0.38, alpha: 0.88)
        let stoneL    = UIColor(red: 0.60, green: 0.55, blue: 0.48, alpha: 0.85)
        let stoneDark = UIColor(red: 0.30, green: 0.28, blue: 0.25, alpha: 0.92)
        // Clock face
        let clockFace = UIColor(red: 0.95, green: 0.90, blue: 0.70, alpha: 0.92)
        let clockGlow = UIColor(red: 0.95, green: 0.90, blue: 0.70, alpha: 0.20)
        let clockHand = UIColor(red: 0.15, green: 0.12, blue: 0.10, alpha: 0.90)
        // Windows
        let windowLit = UIColor(red: 0.90, green: 0.80, blue: 0.45, alpha: 0.75)
        let windowDark = UIColor(red: 0.15, green: 0.18, blue: 0.22, alpha: 0.70)
        // Red elements
        let redBright = UIColor(red: 0.80, green: 0.15, blue: 0.12, alpha: 0.90)
        let redDark   = UIColor(red: 0.60, green: 0.10, blue: 0.08, alpha: 0.88)
        // Bridge cables
        let cableC    = UIColor(red: 0.35, green: 0.35, blue: 0.40, alpha: 0.55)
        // Glass buildings
        let glassD    = UIColor(red: 0.25, green: 0.30, blue: 0.40, alpha: 0.85)
        let glassM    = UIColor(red: 0.35, green: 0.42, blue: 0.55, alpha: 0.82)
        let glassL    = UIColor(red: 0.45, green: 0.55, blue: 0.70, alpha: 0.78)
        // River
        let riverD    = UIColor(red: 0.12, green: 0.18, blue: 0.28, alpha: 0.55)
        let riverL    = UIColor(red: 0.20, green: 0.28, blue: 0.38, alpha: 0.40)
        // Lamp
        let lampPost  = UIColor(red: 0.15, green: 0.15, blue: 0.18, alpha: 0.80)
        let lampGlow  = UIColor(red: 0.95, green: 0.85, blue: 0.50, alpha: 0.80)
        let lampAura  = UIColor(red: 0.95, green: 0.85, blue: 0.50, alpha: 0.12)
        // Cobblestones
        let cobbleD   = UIColor(red: 0.30, green: 0.28, blue: 0.26, alpha: 0.50)
        let cobbleL   = UIColor(red: 0.40, green: 0.38, blue: 0.36, alpha: 0.45)
        // Gherkin
        let gherkinD  = UIColor(red: 0.30, green: 0.38, blue: 0.42, alpha: 0.82)
        let gherkinL  = UIColor(red: 0.40, green: 0.50, blue: 0.55, alpha: 0.78)

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let c = ctx.cgContext

            func fill(_ fx: Int, _ fy: Int, _ fw: Int, _ fh: Int, _ color: UIColor) {
                guard fw > 0 && fh > 0 else { return }
                c.setFillColor(color.cgColor)
                c.fill(CGRect(x: CGFloat(fx) * ps, y: h - CGFloat(fy + fh) * ps,
                              width: CGFloat(fw) * ps, height: CGFloat(fh) * ps))
            }
            func dot(_ dx: Int, _ dy: Int, _ color: UIColor) { fill(dx, dy, 1, 1, color) }

            // ── MOODY SKY ──
            fill(0, 55, gridW, 20, skyDark)
            // Clouds
            for (cx, cy) in [(30, 68), (80, 65), (140, 70), (180, 66)] {
                fill(cx, cy, 15, 3, cloudC)
                fill(cx + 3, cy + 3, 10, 2, cloudC)
            }

            // ── RIVER THAMES ── (y=4..8)
            fill(0, 4, gridW, 5, riverD)
            for rx in stride(from: 5, to: gridW, by: 10) {
                fill(rx, 6, 5, 1, riverL)
            }

            // ── PARLIAMENT / HOUSES OF PARLIAMENT ── (x=2..28, y=8..22)
            fill(2, 8, 26, 16, stoneD)
            fill(3, 9, 24, 14, stoneM)
            // Gothic window arches
            for wx in stride(from: 5, to: 25, by: 4) {
                fill(wx, 12, 2, 5, windowLit)
                dot(wx, 17, stoneL) // Arch top
                dot(wx + 1, 17, stoneL)
            }
            // Crenellation
            for cx in stride(from: 2, to: 28, by: 3) {
                fill(cx, 24, 2, 2, stoneD)
            }
            // Victoria Tower (left end)
            fill(2, 24, 5, 10, stoneD)
            fill(3, 25, 3, 8, stoneM)
            dot(4, 34, stoneL) // Spire

            // ── BIG BEN ── (x=28..40, y=8..60 — TALL)
            // Main tower
            fill(30, 8, 8, 48, stoneD)
            fill(31, 9, 6, 46, stoneM)
            // Stone detail bands
            for by in stride(from: 15, to: 50, by: 8) {
                fill(30, by, 8, 1, stoneL)
            }
            // Clock face (large, glowing)
            let clkX = 31, clkY = 44
            // Glow aura
            for gy in -2..<8 {
                for gx in -2..<8 {
                    dot(clkX + gx, clkY + gy, clockGlow)
                }
            }
            fill(clkX, clkY, 6, 6, clockFace)
            fill(clkX + 1, clkY + 1, 4, 4, clockFace)
            // Clock hands
            dot(clkX + 3, clkY + 3, clockHand) // Center
            fill(clkX + 3, clkY + 4, 1, 2, clockHand) // Hour hand
            fill(clkX + 4, clkY + 3, 2, 1, clockHand) // Minute hand
            // Spire above clock
            fill(32, 56, 4, 3, stoneD)
            fill(33, 59, 2, 4, stoneD)
            fill(33, 63, 2, 1, stoneL) // Tip

            // Windows on Big Ben
            for wy in stride(from: 12, to: 42, by: 5) {
                fill(32, wy, 2, 3, windowLit)
                fill(35, wy, 2, 3, windowLit)
            }

            // ── TOWER BRIDGE ── (x=65..110, y=8..45)
            // Left tower
            fill(68, 8, 8, 35, stoneD)
            fill(69, 9, 6, 33, stoneM)
            // Tower turrets
            fill(67, 43, 3, 4, stoneD); fill(76, 43, 3, 4, stoneD)
            dot(68, 47, stoneL); dot(77, 47, stoneL) // Spire tips
            // Right tower
            fill(98, 8, 8, 35, stoneD)
            fill(99, 9, 6, 33, stoneM)
            fill(97, 43, 3, 4, stoneD); fill(106, 43, 3, 4, stoneD)
            dot(98, 47, stoneL); dot(107, 47, stoneL)
            // Bridge road deck
            fill(68, 18, 38, 2, stoneDark)
            fill(68, 17, 38, 1, stoneL)
            // Upper walkway
            fill(76, 35, 22, 2, stoneD)
            fill(76, 37, 22, 1, stoneL)
            // Suspension cables
            for i in 0..<10 {
                let cableY = 35 - Int(CGFloat(i) * CGFloat(i) * 0.15)
                dot(76 + i, max(20, cableY), cableC)
                dot(98 - i, max(20, cableY), cableC)
            }
            // Tower windows
            for wy in stride(from: 12, to: 38, by: 5) {
                fill(70, wy, 2, 3, windowLit); fill(73, wy, 2, 3, windowLit)
                fill(100, wy, 2, 3, windowLit); fill(103, wy, 2, 3, windowLit)
            }

            // ── THE SHARD ── (x=125..133, y=8..62 — very tall, pointed)
            for sy in 8..<62 {
                let ratio = CGFloat(sy - 8) / 54.0
                let sWidth = max(1, Int(8.0 * (1.0 - ratio * 0.85)))
                let sx = 129 - sWidth / 2
                let glass = ratio > 0.5 ? glassL : (ratio > 0.2 ? glassM : glassD)
                fill(sx, sy, sWidth, 1, glass)
                // Window floor lines
                if sy % 3 == 0 && sWidth > 2 {
                    fill(sx + 1, sy, sWidth - 2, 1,
                         UIColor(red: 0.50, green: 0.60, blue: 0.75, alpha: 0.30))
                }
            }
            dot(129, 62, glassL) // Very tip

            // ── THE GHERKIN ── (x=140..152, y=8..50)
            for gy in 8..<50 {
                let t = CGFloat(gy - 8) / 42.0
                // Curved profile: wider in middle, narrow at top and bottom
                let profile = sin(t * .pi) * 0.8 + 0.2
                let gw = max(2, Int(12.0 * profile))
                let gx = 146 - gw / 2
                let glass = t > 0.5 ? gherkinL : gherkinD
                fill(gx, gy, gw, 1, glass)
                // Diamond pattern
                if gy % 4 == 0 {
                    for dx in stride(from: 0, to: gw, by: 3) {
                        dot(gx + dx, gy, stoneD)
                    }
                }
            }
            // Dome at top
            fill(145, 50, 3, 2, gherkinL)
            dot(146, 52, stoneL)

            // ── BACKGROUND BUILDINGS ── (fill gaps)
            for (bx, bw, bh) in [(48, 6, 25), (55, 5, 20), (112, 6, 28), (118, 5, 22),
                                   (155, 7, 18), (162, 5, 22), (168, 6, 15)] {
                fill(bx, 8, bw, bh, stoneDark)
                for wy in stride(from: 12, to: 8 + bh, by: 4) {
                    for wx in stride(from: bx + 1, to: bx + bw - 1, by: 2) {
                        dot(wx, wy, (wx + wy) % 3 == 0 ? windowLit : windowDark)
                    }
                }
            }

            // ── RED PHONE BOX ── (x=172, y=0, foreground)
            let pbx = 172
            fill(pbx, 0, 5, 10, redBright)
            fill(pbx, 10, 5, 1, redDark) // Top
            fill(pbx + 1, 11, 3, 1, redDark) // Crown
            fill(pbx + 2, 12, 1, 1, redDark) // Tip
            // Window panes
            fill(pbx + 1, 3, 3, 5, windowLit)
            fill(pbx + 2, 3, 1, 5, redDark) // Center bar
            // Door
            fill(pbx + 1, 0, 3, 2, redDark)

            // ── DOUBLE-DECKER BUS ── (x=180..196, y=0)
            let bux = 180
            fill(bux, 0, 16, 4, redDark)    // Lower deck
            fill(bux, 4, 16, 4, redBright)   // Upper deck
            fill(bux, 8, 16, 1, redDark)     // Roof
            // Windows
            for wx in stride(from: bux + 1, to: bux + 15, by: 3) {
                fill(wx, 1, 2, 2, windowLit) // Lower windows
                fill(wx, 5, 2, 2, windowLit) // Upper windows
            }
            // Wheels
            fill(bux + 2, 0, 2, 1, UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 0.80))
            fill(bux + 12, 0, 2, 1, UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 0.80))
            // Front
            fill(bux + 15, 1, 1, 6, redDark)

            // ── LAMP POST ── (x=60)
            fill(60, 0, 1, 16, lampPost)
            fill(58, 16, 5, 2, lampPost)  // Lamp housing
            fill(59, 18, 3, 1, lampGlow)  // Lamp light
            // Glow aura
            for gy in -2..<4 {
                for gx in -3..<4 {
                    dot(60 + gx, 17 + gy, lampAura)
                }
            }

            // ── COBBLESTONE FOREGROUND ── (y=0..3)
            for y in 0..<4 {
                for x in stride(from: y % 2, to: gridW, by: 3) {
                    dot(x, y, cobbleD)
                    if x + 1 < gridW { dot(x + 1, y, cobbleL) }
                }
            }
        }
    }

    // MARK: - Themed Trees (Midground) Rendering

    private func renderThemedTrees(theme: BackgroundTheme) -> UIImage {
        switch theme {
        case .day:                          return renderPixelTrees()
        case .sunset:                       return renderSunsetTrees()
        case .night:                        return renderNightTrees()
        case .neonCity:                     return renderNeonCityMidground()
        case .pixelTokyo:                   return renderTokyoMidground()
        case .underwater:                   return renderKelpForest()
        case .volcano:                      return renderCharredTrees()
        case .arctic:                       return renderSnowyPines()
        case .western:                      return renderWesternCactiMidground()
        case .jungle:                       return renderJungleTropicalTrees()
        case .egypt:                        return renderEgyptPalmObelisks()
        case .cave:                         return renderCaveCrystalPillars()
        case .mountain:                     return renderMountainPineForest()
        case .space:                        return renderSpaceStructures()
        case .lagoon:                       return renderLagoonPalmsMidground()
        case .losAngeles:                   return renderLosAngelesMidground()
        case .london:                       return renderLondonMidground()
        }
    }

    // MARK: Sunset Trees — warm amber park trees

    private func renderSunsetTrees() -> UIImage {
        let w: CGFloat = GK.worldWidth * 2
        let h: CGFloat = 160
        let ps: CGFloat = 4

        let tG = UIColor(red: 0.50, green: 0.35, blue: 0.15, alpha: 0.70)
        let tg = UIColor(red: 0.62, green: 0.45, blue: 0.20, alpha: 0.65)
        let tD = UIColor(red: 0.42, green: 0.28, blue: 0.12, alpha: 0.75)
        let tT = UIColor(red: 0.35, green: 0.22, blue: 0.10, alpha: 0.70)
        let tB = UIColor(red: 0.48, green: 0.32, blue: 0.14, alpha: 0.60)
        let C  = UIColor.clear

        let roundTree: [[UIColor]] = [
            [C,C,C,tD,tD,tD,C,C,C],
            [C,C,tD,tG,tG,tG,tD,C,C],
            [C,tD,tG,tG,tg,tG,tG,tD,C],
            [tD,tG,tG,tg,tg,tG,tG,tG,tD],
            [tD,tG,tg,tG,tG,tG,tG,tG,tD],
            [tD,tG,tG,tG,tG,tG,tG,tG,tD],
            [C,tD,tG,tG,tG,tG,tG,tD,C],
            [C,C,tD,tD,tG,tD,tD,C,C],
            [C,C,C,C,tT,C,C,C,C],
            [C,C,C,C,tT,C,C,C,C],
            [C,C,C,C,tT,C,C,C,C],
            [C,C,C,C,tT,C,C,C,C],
        ]
        let bush: [[UIColor]] = [
            [C,C,tB,tB,tB,C,C],
            [C,tB,tB,tg,tB,tB,C],
            [tB,tB,tg,tB,tB,tB,tB],
            [C,tB,tB,tB,tB,tB,C],
        ]

        return renderTreesFromTemplates(width: w, height: h, ps: ps,
                                         roundTree: roundTree, pineTree: roundTree,
                                         bush: bush, showBenches: true,
                                         benchColor: UIColor(red: 0.35, green: 0.22, blue: 0.10, alpha: 0.45))
    }

    // MARK: Night Trees — dark silhouettes

    private func renderNightTrees() -> UIImage {
        let w: CGFloat = GK.worldWidth * 2
        let h: CGFloat = 160
        let ps: CGFloat = 4

        let tG = UIColor(red: 0.06, green: 0.10, blue: 0.18, alpha: 0.80)
        let tg = UIColor(red: 0.10, green: 0.14, blue: 0.24, alpha: 0.75)
        let tD = UIColor(red: 0.04, green: 0.06, blue: 0.12, alpha: 0.85)
        let tT = UIColor(red: 0.08, green: 0.08, blue: 0.14, alpha: 0.75)
        let tB = UIColor(red: 0.06, green: 0.08, blue: 0.15, alpha: 0.75)
        let C  = UIColor.clear

        let roundTree: [[UIColor]] = [
            [C,C,C,tD,tD,tD,C,C,C],
            [C,C,tD,tG,tG,tG,tD,C,C],
            [C,tD,tG,tG,tg,tG,tG,tD,C],
            [tD,tG,tG,tg,tg,tG,tG,tG,tD],
            [tD,tG,tg,tG,tG,tG,tG,tG,tD],
            [tD,tG,tG,tG,tG,tG,tG,tG,tD],
            [C,tD,tG,tG,tG,tG,tG,tD,C],
            [C,C,tD,tD,tG,tD,tD,C,C],
            [C,C,C,C,tT,C,C,C,C],
            [C,C,C,C,tT,C,C,C,C],
            [C,C,C,C,tT,C,C,C,C],
            [C,C,C,C,tT,C,C,C,C],
        ]
        let bush: [[UIColor]] = [
            [C,C,tB,tB,tB,C,C],
            [C,tB,tB,tg,tB,tB,C],
            [tB,tB,tg,tB,tB,tB,tB],
            [C,tB,tB,tB,tB,tB,C],
        ]

        return renderTreesFromTemplates(width: w, height: h, ps: ps,
                                         roundTree: roundTree, pineTree: roundTree,
                                         bush: bush, showBenches: true,
                                         benchColor: UIColor(red: 0.06, green: 0.06, blue: 0.12, alpha: 0.55))
    }

    // MARK: Neon City Midground — shorter buildings, neon signs

    private func renderNeonCityMidground() -> UIImage {
        let w: CGFloat = GK.worldWidth * 2
        let h: CGFloat = 160
        let ps: CGFloat = 4
        let gridW = Int(w / ps)

        // Foreground buildings — shorter, more varied, with neon accents
        let wallDark  = UIColor(red: 0.10, green: 0.05, blue: 0.20, alpha: 0.75)
        let wallMid   = UIColor(red: 0.15, green: 0.08, blue: 0.28, alpha: 0.70)
        let roofColor = UIColor(red: 0.08, green: 0.04, blue: 0.16, alpha: 0.80)

        let neonPink  = UIColor(red: 1.0, green: 0.20, blue: 0.55, alpha: 0.90)
        let neonCyan  = UIColor(red: 0.20, green: 0.90, blue: 1.0, alpha: 0.85)
        let neonPurple = UIColor(red: 0.75, green: 0.30, blue: 1.0, alpha: 0.85)

        let windowYellow = UIColor(red: 1.0, green: 0.90, blue: 0.40, alpha: 0.80)
        let windowOff    = UIColor(red: 0.06, green: 0.04, blue: 0.12, alpha: 0.65)

        // Buildings: (xPixel, widthPixels, heightPixels)
        let buildings: [(x: Int, w: Int, h: Int)] = [
            (1, 10, 12), (13, 7, 8), (22, 12, 16), (36, 6, 10), (44, 9, 14),
            (55, 8, 9), (65, 11, 18), (78, 6, 7), (86, 10, 13), (98, 8, 11),
            (108, 12, 20), (122, 7, 8), (131, 9, 15), (142, 10, 12), (154, 8, 17),
            (164, 6, 9), (172, 11, 14), (185, 7, 10), (194, 9, 16),
        ]

        let neonSigns: [(x: Int, y: Int, w: Int, color: UIColor)] = [
            (16, 10, 5, neonPink), (46, 16, 4, neonCyan), (70, 20, 6, neonPurple),
            (102, 14, 5, neonPink), (135, 18, 4, neonCyan), (170, 16, 5, neonPurple),
        ]

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let c = ctx.cgContext

            for bld in buildings {
                let bx = bld.x
                let bw = bld.w
                let bh = bld.h

                for row in 0..<bh {
                    let yPos = h - CGFloat(row + 1) * ps
                    let color = row == bh - 1 ? roofColor : (row > bh / 2 ? wallMid : wallDark)
                    c.setFillColor(color.cgColor)
                    for col in bx..<(bx + bw) {
                        guard col < gridW else { break }
                        c.fill(CGRect(x: CGFloat(col) * ps, y: yPos, width: ps, height: ps))
                    }
                }

                // Windows
                for row in stride(from: 1, to: bh - 1, by: 2) {
                    for col in stride(from: bx + 1, to: bx + bw - 1, by: 2) {
                        guard col < gridW else { break }
                        let yPos = h - CGFloat(row + 1) * ps
                        let wc = (row + col) % 3 == 0 ? windowYellow : windowOff
                        c.setFillColor(wc.cgColor)
                        c.fill(CGRect(x: CGFloat(col) * ps, y: yPos, width: ps, height: ps))
                    }
                }
            }

            // Neon signs — horizontal bars of color
            for sign in neonSigns {
                c.setFillColor(sign.color.cgColor)
                for col in sign.x..<(sign.x + sign.w) {
                    guard col < gridW else { break }
                    let yPos = h - CGFloat(sign.y + 1) * ps
                    c.fill(CGRect(x: CGFloat(col) * ps, y: yPos, width: ps, height: ps))
                    // Glow pixel below
                    c.setFillColor(sign.color.withAlphaComponent(0.35).cgColor)
                    c.fill(CGRect(x: CGFloat(col) * ps, y: yPos + ps, width: ps, height: ps))
                    c.setFillColor(sign.color.cgColor)
                }
            }
        }
    }

    // MARK: Tokyo Midground — detailed buildings with Japanese elements

    private func renderTokyoMidground() -> UIImage {
        let w: CGFloat = GK.worldWidth * 2
        let h: CGFloat = 160
        let ps: CGFloat = 4
        let gridW = Int(w / ps)

        let wallDark   = UIColor(red: 0.14, green: 0.08, blue: 0.28, alpha: 0.75)
        let wallMid    = UIColor(red: 0.20, green: 0.12, blue: 0.35, alpha: 0.70)
        let roofColor  = UIColor(red: 0.10, green: 0.05, blue: 0.22, alpha: 0.80)

        let neonPink   = UIColor(red: 1.0, green: 0.30, blue: 0.50, alpha: 0.85)
        let neonBlue   = UIColor(red: 0.30, green: 0.70, blue: 1.0, alpha: 0.80)
        let windowWarm = UIColor(red: 1.0, green: 0.85, blue: 0.50, alpha: 0.75)
        let windowOff  = UIColor(red: 0.08, green: 0.05, blue: 0.18, alpha: 0.65)

        // Tokyo buildings — mix of sizes
        let buildings: [(x: Int, w: Int, h: Int)] = [
            (1, 12, 15), (15, 8, 10), (25, 14, 22), (41, 6, 8), (49, 10, 18),
            (61, 7, 12), (70, 13, 26), (85, 8, 9), (95, 11, 20), (108, 6, 11),
            (116, 14, 24), (132, 7, 10), (141, 10, 16), (153, 9, 14), (164, 12, 28),
            (178, 7, 8), (187, 10, 19),
        ]

        // Signage positions: some vertical, some horizontal
        let hSigns: [(x: Int, y: Int, w: Int, color: UIColor)] = [
            (28, 14, 8, neonPink), (52, 20, 5, neonBlue),
            (99, 22, 6, neonPink), (145, 18, 5, neonBlue),
            (168, 24, 7, neonPink),
        ]
        let vSigns: [(x: Int, yStart: Int, h: Int, color: UIColor)] = [
            (3, 8, 5, neonBlue), (73, 12, 8, neonPink),
            (119, 10, 6, neonBlue), (190, 8, 5, neonPink),
        ]

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let c = ctx.cgContext

            for bld in buildings {
                let bx = bld.x
                let bw = bld.w
                let bh = bld.h

                for row in 0..<bh {
                    let yPos = h - CGFloat(row + 1) * ps
                    let color = row == bh - 1 ? roofColor : (row > bh / 2 ? wallMid : wallDark)
                    c.setFillColor(color.cgColor)
                    for col in bx..<(bx + bw) {
                        guard col < gridW else { break }
                        c.fill(CGRect(x: CGFloat(col) * ps, y: yPos, width: ps, height: ps))
                    }
                }

                // Windows — grid pattern
                for row in stride(from: 1, to: bh - 1, by: 2) {
                    for col in stride(from: bx + 1, to: bx + bw - 1, by: 2) {
                        guard col < gridW else { break }
                        let yPos = h - CGFloat(row + 1) * ps
                        let wc = (row * 5 + col * 3) % 4 == 0 ? windowOff : windowWarm
                        c.setFillColor(wc.cgColor)
                        c.fill(CGRect(x: CGFloat(col) * ps, y: yPos, width: ps, height: ps))
                    }
                }

                // Rooftop detail — small antenna or A/C unit on tall buildings
                if bh > 16 && bx + bw / 2 < gridW {
                    c.setFillColor(roofColor.cgColor)
                    let ax = bx + bw / 2
                    c.fill(CGRect(x: CGFloat(ax) * ps, y: h - CGFloat(bh + 1) * ps, width: ps, height: ps))
                    c.fill(CGRect(x: CGFloat(ax) * ps, y: h - CGFloat(bh + 2) * ps, width: ps, height: ps))
                }
            }

            // Horizontal neon signs
            for sign in hSigns {
                c.setFillColor(sign.color.cgColor)
                for col in sign.x..<(sign.x + sign.w) {
                    guard col < gridW else { break }
                    c.fill(CGRect(x: CGFloat(col) * ps, y: h - CGFloat(sign.y + 1) * ps, width: ps, height: ps))
                }
                // Glow row below
                c.setFillColor(sign.color.withAlphaComponent(0.30).cgColor)
                for col in sign.x..<(sign.x + sign.w) {
                    guard col < gridW else { break }
                    c.fill(CGRect(x: CGFloat(col) * ps, y: h - CGFloat(sign.y) * ps, width: ps, height: ps))
                }
            }
            // Vertical neon signs
            for sign in vSigns {
                guard sign.x < gridW else { continue }
                for row in sign.yStart..<(sign.yStart + sign.h) {
                    c.setFillColor(sign.color.cgColor)
                    c.fill(CGRect(x: CGFloat(sign.x) * ps, y: h - CGFloat(row + 1) * ps, width: ps, height: ps))
                    // Glow pixel beside
                    if sign.x + 1 < gridW {
                        c.setFillColor(sign.color.withAlphaComponent(0.25).cgColor)
                        c.fill(CGRect(x: CGFloat(sign.x + 1) * ps, y: h - CGFloat(row + 1) * ps, width: ps, height: ps))
                    }
                }
            }
        }
    }

    // MARK: Kelp Forest — underwater trees

    private func renderKelpForest() -> UIImage {
        let w: CGFloat = GK.worldWidth * 2
        let h: CGFloat = 160
        let ps: CGFloat = 4
        let C  = UIColor.clear

        let kD = UIColor(red: 0.10, green: 0.42, blue: 0.25, alpha: 0.70)
        let kL = UIColor(red: 0.18, green: 0.58, blue: 0.35, alpha: 0.65)
        let kT = UIColor(red: 0.15, green: 0.50, blue: 0.30, alpha: 0.55)

        // Tall kelp strand (3 wide × 16 tall, swaying)
        let kelpA: [[UIColor]] = [
            [C,kT,C], [C,kL,C], [kL,kD,C], [C,kD,C],
            [C,kD,kL], [C,kL,C], [kL,kD,C], [C,kD,C],
            [C,kD,kL], [C,kL,C], [kL,kD,C], [C,kD,C],
            [C,kL,C], [C,kD,C], [C,kD,C], [C,kD,C],
        ]
        // Short kelp strand (3 wide × 10 tall)
        let kelpB: [[UIColor]] = [
            [C,kT,C], [kL,kD,C], [C,kD,C], [C,kD,kL],
            [C,kL,C], [kL,kD,C], [C,kD,C], [C,kD,C],
            [C,kD,C], [C,kD,C],
        ]

        // Small coral cluster (5 wide × 4 tall)
        let coralR = UIColor(red: 0.85, green: 0.30, blue: 0.35, alpha: 0.60)
        let coralO = UIColor(red: 0.90, green: 0.55, blue: 0.20, alpha: 0.55)
        let coral: [[UIColor]] = [
            [C,coralR,C,coralO,C],
            [coralR,coralR,coralO,coralO,C],
            [coralR,coralR,coralO,coralO,coralR],
            [C,coralR,coralO,coralR,C],
        ]

        let positions: [(x: CGFloat, type: Int)] = [
            (20, 0), (80, 1), (130, 2), (180, 0), (240, 1), (300, 0),
            (360, 2), (420, 0), (470, 1), (530, 0), (580, 2), (640, 0),
            (700, 1), (750, 0),
        ]

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let c = ctx.cgContext
            for pos in positions {
                let template: [[UIColor]]
                switch pos.type {
                case 0: template = kelpA
                case 1: template = kelpB
                default: template = coral
                }
                let tH = template.count
                let tW = template[0].count
                let baseY = h - CGFloat(tH) * ps

                for row in 0..<tH {
                    for col in 0..<tW {
                        let color = template[row][col]
                        guard color != UIColor.clear else { continue }
                        c.setFillColor(color.cgColor)
                        c.fill(CGRect(x: pos.x + CGFloat(col) * ps,
                                      y: baseY + CGFloat(row) * ps,
                                      width: ps, height: ps))
                    }
                }
            }
        }
    }

    // MARK: Charred Trees — volcano midground

    private func renderCharredTrees() -> UIImage {
        let w: CGFloat = GK.worldWidth * 2
        let h: CGFloat = 160
        let ps: CGFloat = 4
        let C = UIColor.clear

        let tD = UIColor(red: 0.12, green: 0.08, blue: 0.06, alpha: 0.80)
        let tM = UIColor(red: 0.18, green: 0.12, blue: 0.08, alpha: 0.75)
        let eG = UIColor(red: 0.95, green: 0.40, blue: 0.10, alpha: 0.45) // ember glow

        // Dead tree silhouette (7 wide × 14 tall)
        let deadTree: [[UIColor]] = [
            [C,C,C,tD,C,C,C],
            [C,tD,C,tD,C,tD,C],
            [tD,tD,C,tD,C,tD,tD],
            [C,tM,tD,tD,tD,tM,C],
            [C,C,tD,tD,tD,C,C],
            [C,C,C,tD,C,C,C],
            [C,C,C,tD,C,C,C],
            [C,C,C,tD,C,C,C],
            [C,C,C,tD,C,C,C],
            [C,C,C,tD,C,C,C],
            [C,C,C,tD,C,C,C],
            [C,C,C,tD,C,C,C],
            [C,C,C,tD,C,C,C],
            [C,C,C,tD,C,C,C],
        ]

        // Small charred stump (5 wide × 5 tall)
        let stump: [[UIColor]] = [
            [C,tD,tD,tD,C],
            [C,tM,tD,tM,C],
            [C,C,tD,C,C],
            [C,C,tD,C,C],
            [C,C,tD,C,C],
        ]

        let positions: [(x: CGFloat, type: Int)] = [
            (40, 0), (120, 1), (190, 0), (260, 1), (330, 0),
            (400, 1), (470, 0), (540, 1), (620, 0), (700, 1), (760, 0),
        ]

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let c = ctx.cgContext
            for pos in positions {
                let template = pos.type == 0 ? deadTree : stump
                let tH = template.count
                let tW = template[0].count
                let baseY = h - CGFloat(tH) * ps
                for row in 0..<tH {
                    for col in 0..<tW {
                        let color = template[row][col]
                        guard color != UIColor.clear else { continue }
                        c.setFillColor(color.cgColor)
                        c.fill(CGRect(x: pos.x + CGFloat(col) * ps,
                                      y: baseY + CGFloat(row) * ps,
                                      width: ps, height: ps))
                    }
                }
                // Ember glow at base of full trees
                if pos.type == 0 {
                    c.setFillColor(eG.cgColor)
                    c.fill(CGRect(x: pos.x + 2 * ps, y: h - ps, width: ps * 3, height: ps))
                }
            }
        }
    }

    // MARK: Snowy Pines — arctic trees

    private func renderSnowyPines() -> UIImage {
        let w: CGFloat = GK.worldWidth * 2
        let h: CGFloat = 160
        let ps: CGFloat = 4
        let C = UIColor.clear

        let tG = UIColor(red: 0.15, green: 0.35, blue: 0.20, alpha: 0.70)
        let tD = UIColor(red: 0.10, green: 0.28, blue: 0.15, alpha: 0.75)
        let sW = UIColor(red: 0.92, green: 0.95, blue: 1.0, alpha: 0.80) // snow white
        let sL = UIColor(red: 0.80, green: 0.88, blue: 0.95, alpha: 0.65) // snow shadow
        let tT = UIColor(red: 0.35, green: 0.25, blue: 0.15, alpha: 0.70)

        // Snowy pine (7 wide × 14 tall — snow-tipped)
        let snowPine: [[UIColor]] = [
            [C,C,C,sW,C,C,C],
            [C,C,sW,sW,sW,C,C],
            [C,C,tD,tG,tD,C,C],
            [C,sW,tG,tG,tG,sW,C],
            [C,sL,tG,tG,tG,sL,C],
            [sW,tG,tG,tG,tG,tG,sW],
            [sL,tG,tG,tG,tG,tG,sL],
            [C,C,sW,tG,sW,C,C],
            [C,sW,tG,tG,tG,sW,C],
            [sW,tG,tG,tG,tG,tG,sW],
            [sL,tG,tG,tG,tG,tG,sL],
            [C,C,C,tT,C,C,C],
            [C,C,C,tT,C,C,C],
            [C,C,C,tT,C,C,C],
        ]

        // Snow drift (7 wide × 3 tall)
        let drift: [[UIColor]] = [
            [C,C,sW,sW,sW,C,C],
            [C,sW,sW,sW,sW,sW,C],
            [sL,sW,sW,sW,sW,sW,sL],
        ]

        let positions: [(x: CGFloat, type: Int)] = [
            (30, 0), (100, 1), (160, 0), (220, 1), (290, 0), (350, 1),
            (420, 0), (480, 1), (540, 0), (610, 1), (680, 0), (740, 1), (790, 0),
        ]

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let c = ctx.cgContext
            for pos in positions {
                let template = pos.type == 0 ? snowPine : drift
                let tH = template.count
                let tW = template[0].count
                let baseY = h - CGFloat(tH) * ps
                for row in 0..<tH {
                    for col in 0..<tW {
                        let color = template[row][col]
                        guard color != UIColor.clear else { continue }
                        c.setFillColor(color.cgColor)
                        c.fill(CGRect(x: pos.x + CGFloat(col) * ps,
                                      y: baseY + CGFloat(row) * ps,
                                      width: ps, height: ps))
                    }
                }
            }
        }
    }

    // MARK: Space Structures — space station silhouettes, satellite dishes

    private func renderSpaceStructures() -> UIImage {
        let w: CGFloat = GK.worldWidth * 2
        let h: CGFloat = 160
        let ps: CGFloat = 4
        let C = UIColor.clear

        let sM = UIColor(red: 0.30, green: 0.32, blue: 0.38, alpha: 0.65) // metal gray
        let sD = UIColor(red: 0.18, green: 0.20, blue: 0.25, alpha: 0.70) // dark frame
        let sL = UIColor(red: 0.45, green: 0.48, blue: 0.55, alpha: 0.55) // light panel
        let gR = UIColor(red: 0.20, green: 0.80, blue: 0.30, alpha: 0.70) // green status light
        // Satellite dish (9 wide × 10 tall)
        let dish: [[UIColor]] = [
            [C,C,C,C,sD,C,C,C,C],
            [C,C,C,sD,sM,sD,C,C,C],
            [C,C,sD,sM,sL,sM,sD,C,C],
            [C,sD,sM,sL,sL,sL,sM,sD,C],
            [sD,sM,sL,sL,sL,sL,sM,sD,C],
            [C,C,C,C,sD,C,C,C,C],
            [C,C,C,C,sD,C,C,C,C],
            [C,C,C,sD,sM,sD,C,C,C],
            [C,C,sD,C,sD,C,sD,C,C],
            [C,sD,C,C,sD,C,C,sD,C],
        ]

        // Small space module (7 wide × 8 tall)
        let module: [[UIColor]] = [
            [C,C,sD,sD,sD,C,C],
            [C,sD,sM,sM,sM,sD,C],
            [sD,sM,sL,gR,sL,sM,sD],
            [sD,sM,sM,sM,sM,sM,sD],
            [sD,sM,sL,sL,sL,sM,sD],
            [C,sD,sM,sM,sM,sD,C],
            [C,C,sD,sD,sD,C,C],
            [C,C,C,sD,C,C,C],
        ]

        // Floating asteroid (5 wide × 4 tall)
        let aD = UIColor(red: 0.28, green: 0.25, blue: 0.22, alpha: 0.60)
        let aL = UIColor(red: 0.40, green: 0.36, blue: 0.32, alpha: 0.50)
        let asteroid: [[UIColor]] = [
            [C,aD,aD,aD,C],
            [aD,aD,aL,aD,aD],
            [aD,aL,aD,aD,aD],
            [C,aD,aD,aD,C],
        ]

        let positions: [(x: CGFloat, type: Int)] = [
            (30, 0), (110, 2), (180, 1), (260, 2), (340, 0), (420, 2),
            (500, 1), (580, 2), (650, 0), (720, 2), (780, 1),
        ]

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let c = ctx.cgContext
            for pos in positions {
                let template: [[UIColor]]
                switch pos.type {
                case 0: template = dish
                case 1: template = module
                default: template = asteroid
                }
                let tH = template.count
                let tW = template[0].count
                let baseY = h - CGFloat(tH) * ps

                for row in 0..<tH {
                    for col in 0..<tW {
                        let color = template[row][col]
                        guard color != UIColor.clear else { continue }
                        c.setFillColor(color.cgColor)
                        c.fill(CGRect(x: pos.x + CGFloat(col) * ps,
                                      y: baseY + CGFloat(row) * ps,
                                      width: ps, height: ps))
                    }
                }
            }
        }
    }

    /// Shared helper to render sunset/night tree variants from palette-shifted templates.
    private func renderTreesFromTemplates(
        width: CGFloat, height: CGFloat, ps: CGFloat,
        roundTree: [[UIColor]], pineTree: [[UIColor]], bush: [[UIColor]],
        showBenches: Bool, benchColor: UIColor
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        return renderer.image { ctx in
            let c = ctx.cgContext
            let positions: [(x: CGFloat, type: Int)] = [
                (30, 0), (110, 1), (170, 2), (230, 0), (290, 1),
                (360, 0), (430, 2), (480, 0), (540, 1), (610, 0),
                (670, 2), (720, 0), (780, 1),
            ]
            for pos in positions {
                let template: [[UIColor]]
                switch pos.type {
                case 0: template = roundTree
                case 1: template = pineTree
                default: template = bush
                }
                let tH = template.count
                let tW = template[0].count
                let baseY = height - CGFloat(tH) * ps
                for row in 0..<tH {
                    for col in 0..<tW {
                        let color = template[row][col]
                        guard color != UIColor.clear else { continue }
                        c.setFillColor(color.cgColor)
                        c.fill(CGRect(x: pos.x + CGFloat(col) * ps,
                                      y: baseY + CGFloat(row) * ps,
                                      width: ps, height: ps))
                    }
                }
            }

            if showBenches {
                let benchPositions: [CGFloat] = [150, 450, 700]
                for bx in benchPositions {
                    let by = height - 3 * ps
                    c.setFillColor(benchColor.cgColor)
                    for i in 0..<6 { c.fill(CGRect(x: bx + CGFloat(i) * ps, y: by, width: ps, height: ps)) }
                    for i in 0..<6 { c.fill(CGRect(x: bx + CGFloat(i) * ps, y: by - ps, width: ps, height: ps)) }
                    c.fill(CGRect(x: bx, y: by + ps, width: ps, height: ps * 2))
                    c.fill(CGRect(x: bx + 5 * ps, y: by + ps, width: ps, height: ps * 2))
                }
            }
        }
    }

    // MARK: Lagoon Palms Midground — tall palm trees with coconuts, tropical flowers

    private func renderLagoonPalmsMidground() -> UIImage {
        let w: CGFloat = GK.worldWidth * 2
        let h: CGFloat = 160
        let ps: CGFloat = 4
        let C = UIColor.clear

        let trunk = UIColor(red: 0.45, green: 0.30, blue: 0.18, alpha: 0.65)
        let trunkL = UIColor(red: 0.55, green: 0.38, blue: 0.22, alpha: 0.60)
        let leaf  = UIColor(red: 0.20, green: 0.55, blue: 0.28, alpha: 0.65)
        let leafL = UIColor(red: 0.30, green: 0.65, blue: 0.35, alpha: 0.55)
        let coco  = UIColor(red: 0.45, green: 0.30, blue: 0.15, alpha: 0.70)
        let flower = UIColor(red: 0.95, green: 0.45, blue: 0.55, alpha: 0.60)

        // Palm tree (6w × 16h)
        let palm: [[UIColor]] = [
            [C,C,leaf,C,C,C],
            [C,leaf,leafL,leaf,C,C],
            [leaf,C,leafL,C,leaf,C],
            [C,C,trunk,C,C,C],
            [C,C,coco,trunk,coco,C],
            [C,C,trunk,C,C,C],
            [C,C,trunk,C,C,C],
            [C,C,trunkL,C,C,C],
            [C,C,trunk,C,C,C],
            [C,C,trunk,C,C,C],
            [C,C,trunkL,C,C,C],
            [C,C,trunk,C,C,C],
            [C,C,trunk,C,C,C],
            [C,C,trunk,C,C,C],
            [C,C,trunkL,C,C,C],
            [C,C,trunk,C,C,C],
        ]

        // Tropical flower cluster (3w × 3h)
        let flowerCluster: [[UIColor]] = [
            [C, flower, C],
            [flower, leafL, flower],
            [C, leaf, C],
        ]

        let positions: [(x: CGFloat, type: Int)] = [
            (30, 0), (130, 1), (220, 0), (340, 1), (420, 0),
            (520, 1), (610, 0), (700, 1), (780, 0),
        ]

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let c = ctx.cgContext
            for pos in positions {
                let template = pos.type == 0 ? palm : flowerCluster
                let tH = template.count
                let tW = template[0].count
                let baseY = h - CGFloat(tH) * ps
                for row in 0..<tH {
                    for col in 0..<tW {
                        let color = template[row][col]
                        guard color != C else { continue }
                        c.setFillColor(color.cgColor)
                        c.fill(CGRect(x: pos.x + CGFloat(col) * ps, y: baseY + CGFloat(row) * ps,
                                      width: ps, height: ps))
                    }
                }
            }
        }
    }

    // MARK: Los Angeles Midground — palm-lined boulevard with buildings

    private func renderLosAngelesMidground() -> UIImage {
        let w: CGFloat = GK.worldWidth * 2
        let h: CGFloat = 160
        let ps: CGFloat = 4
        let C = UIColor.clear

        let trunk = UIColor(red: 0.42, green: 0.28, blue: 0.16, alpha: 0.65)
        let leafD = UIColor(red: 0.22, green: 0.45, blue: 0.22, alpha: 0.60)
        let leafL = UIColor(red: 0.35, green: 0.58, blue: 0.30, alpha: 0.50)
        let bldg  = UIColor(red: 0.65, green: 0.55, blue: 0.48, alpha: 0.40)
        let bldgD = UIColor(red: 0.50, green: 0.42, blue: 0.35, alpha: 0.45)
        let glass = UIColor(red: 0.55, green: 0.72, blue: 0.85, alpha: 0.35)

        // Tall palm (4w × 16h)
        let tallPalm: [[UIColor]] = [
            [C,leafD,leafL,C],
            [leafD,C,C,leafL],
            [C,C,trunk,C],
            [C,C,trunk,C],
            [C,C,trunk,C],
            [C,C,trunk,C],
            [C,C,trunk,C],
            [C,C,trunk,C],
            [C,C,trunk,C],
            [C,C,trunk,C],
            [C,C,trunk,C],
            [C,C,trunk,C],
            [C,C,trunk,C],
            [C,C,trunk,C],
            [C,C,trunk,C],
            [C,C,trunk,C],
        ]

        // Low-rise building (8w × 8h)
        let building: [[UIColor]] = [
            [bldgD,bldgD,bldgD,bldgD,bldgD,bldgD,bldgD,bldgD],
            [bldg,glass,bldg,glass,bldg,glass,bldg,bldg],
            [bldg,glass,bldg,glass,bldg,glass,bldg,bldg],
            [bldg,bldg,bldg,bldg,bldg,bldg,bldg,bldg],
            [bldg,glass,bldg,glass,bldg,glass,bldg,bldg],
            [bldg,glass,bldg,glass,bldg,glass,bldg,bldg],
            [bldg,bldg,bldg,bldg,bldg,bldg,bldg,bldg],
            [bldg,bldg,bldg,bldg,bldg,bldg,bldg,bldg],
        ]

        let positions: [(x: CGFloat, type: Int)] = [
            (30, 0), (100, 1), (210, 0), (300, 0), (380, 1),
            (490, 0), (580, 0), (660, 1), (760, 0),
        ]

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let c = ctx.cgContext
            for pos in positions {
                let template = pos.type == 0 ? tallPalm : building
                let tH = template.count
                let tW = template[0].count
                let baseY = h - CGFloat(tH) * ps
                for row in 0..<tH {
                    for col in 0..<tW {
                        let color = template[row][col]
                        guard color != C else { continue }
                        c.setFillColor(color.cgColor)
                        c.fill(CGRect(x: pos.x + CGFloat(col) * ps, y: baseY + CGFloat(row) * ps,
                                      width: ps, height: ps))
                    }
                }
            }
        }
    }

    // MARK: London Midground — red telephone box, lamp post, double-decker bus hint

    private func renderLondonMidground() -> UIImage {
        let w: CGFloat = GK.worldWidth * 2
        let h: CGFloat = 160
        let ps: CGFloat = 4
        let C = UIColor.clear

        let redBus = UIColor(red: 0.78, green: 0.15, blue: 0.12, alpha: 0.65)
        let redDark = UIColor(red: 0.60, green: 0.10, blue: 0.08, alpha: 0.70)
        let glass = UIColor(red: 0.55, green: 0.65, blue: 0.75, alpha: 0.50)
        let lampBlack = UIColor(red: 0.15, green: 0.15, blue: 0.18, alpha: 0.65)
        let lampGlow = UIColor(red: 1.0, green: 0.90, blue: 0.60, alpha: 0.50)

        // Red telephone box (4w × 10h)
        let phoneBox: [[UIColor]] = [
            [C,redDark,redDark,C],
            [redBus,glass,glass,redBus],
            [redBus,glass,glass,redBus],
            [redBus,glass,glass,redBus],
            [redBus,glass,glass,redBus],
            [redBus,redBus,redBus,redBus],
            [redBus,glass,glass,redBus],
            [redBus,glass,glass,redBus],
            [redBus,redBus,redBus,redBus],
            [redBus,redBus,redBus,redBus],
        ]

        // Lamp post (2w × 14h)
        let lamp: [[UIColor]] = [
            [lampGlow, lampGlow],
            [lampBlack, lampBlack],
            [C, lampBlack],
            [C, lampBlack],
            [C, lampBlack],
            [C, lampBlack],
            [C, lampBlack],
            [C, lampBlack],
            [C, lampBlack],
            [C, lampBlack],
            [C, lampBlack],
            [C, lampBlack],
            [C, lampBlack],
            [lampBlack, lampBlack],
        ]

        let positions: [(x: CGFloat, type: Int)] = [
            (40, 1), (130, 0), (220, 1), (340, 0), (430, 1),
            (530, 0), (620, 1), (720, 0), (790, 1),
        ]

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let c = ctx.cgContext
            for pos in positions {
                let template = pos.type == 0 ? phoneBox : lamp
                let tH = template.count
                let tW = template[0].count
                let baseY = h - CGFloat(tH) * ps
                for row in 0..<tH {
                    for col in 0..<tW {
                        let color = template[row][col]
                        guard color != C else { continue }
                        c.setFillColor(color.cgColor)
                        c.fill(CGRect(x: pos.x + CGFloat(col) * ps, y: baseY + CGFloat(row) * ps,
                                      width: ps, height: ps))
                    }
                }
            }
        }
    }

    // MARK: - Themed Bush / Foreground Rendering

    private func renderThemedBushes(theme: BackgroundTheme) -> UIImage {
        switch theme {
        case .day:                          return renderDayBushStrip()
        case .sunset:                       return renderSunsetBushStrip()
        case .night:                        return renderNightBushStrip()
        case .neonCity, .pixelTokyo:        return renderUrbanForegroundStrip(tokyo: theme == .pixelTokyo)
        case .underwater:                   return renderBubbleFishStrip()
        case .volcano:                      return renderLavaPoolStrip()
        case .arctic:                       return renderIceCrystalStrip()
        case .western:                      return renderWesternScrubStrip()
        case .jungle:                       return renderJungleFernStrip()
        case .egypt:                        return renderEgyptDesertStrip()
        case .cave:                         return renderCaveMossStrip()
        case .mountain:                     return renderMountainMeadowStrip()
        case .space:                        return renderSpaceDebrisStrip()
        case .lagoon:                       return renderLagoonBeachStrip()
        case .losAngeles:                   return renderLosAngelesStreetStrip()
        case .london:                       return renderLondonPavementStrip()
        }
    }

    // MARK: Day Bushes — same as the original GameScene renderBushTexture

    private func renderDayBushStrip() -> UIImage {
        let w = Int(GK.worldWidth * 2)
        let h = 36
        let size = CGSize(width: w, height: h)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let c = ctx.cgContext
            var x = 0
            while x < w {
                let bushW = Int.random(in: 18...32)
                let bushH = Int.random(in: 14...24)
                let gap = Int.random(in: 20...40)
                let ps = 4
                let bodyColor = UIColor(red: 0.20, green: 0.48, blue: 0.14, alpha: 0.8)
                c.setFillColor(bodyColor.cgColor)
                let topY = h - bushH
                c.fill(CGRect(x: x + ps * 2, y: topY, width: bushW - ps * 4, height: ps))
                c.fill(CGRect(x: x + ps, y: topY + ps, width: bushW - ps * 2, height: ps))
                c.fill(CGRect(x: x, y: topY + ps * 2, width: bushW, height: bushH - ps * 3))
                c.fill(CGRect(x: x + ps, y: h - ps, width: bushW - ps * 2, height: ps))
                let hlColor = UIColor(red: 0.32, green: 0.62, blue: 0.20, alpha: 0.6)
                c.setFillColor(hlColor.cgColor)
                c.fill(CGRect(x: x + ps * 2, y: topY + ps, width: bushW - ps * 4, height: ps))
                if Int.random(in: 0...2) == 0 {
                    let flowerColors: [UIColor] = [
                        UIColor(red: 1.0, green: 0.35, blue: 0.35, alpha: 1.0),
                        UIColor(red: 1.0, green: 0.85, blue: 0.2, alpha: 1.0),
                        UIColor(red: 0.80, green: 0.40, blue: 0.85, alpha: 1.0),
                    ]
                    c.setFillColor(flowerColors.randomElement()!.cgColor)
                    let fx = x + Int.random(in: ps...(max(ps + 1, bushW - ps * 2)))
                    c.fill(CGRect(x: fx, y: topY - ps, width: ps + 2, height: ps + 2))
                }
                x += bushW + gap
            }
        }
    }

    // MARK: Sunset Bushes

    private func renderSunsetBushStrip() -> UIImage {
        let w = Int(GK.worldWidth * 2)
        let h = 36
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let c = ctx.cgContext
            var x = 0
            while x < w {
                let bushW = Int.random(in: 18...32)
                let bushH = Int.random(in: 14...24)
                let gap = Int.random(in: 20...40)
                let ps = 4
                let bodyColor = UIColor(red: 0.40, green: 0.28, blue: 0.12, alpha: 0.75)
                c.setFillColor(bodyColor.cgColor)
                let topY = h - bushH
                c.fill(CGRect(x: x + ps * 2, y: topY, width: bushW - ps * 4, height: ps))
                c.fill(CGRect(x: x + ps, y: topY + ps, width: bushW - ps * 2, height: ps))
                c.fill(CGRect(x: x, y: topY + ps * 2, width: bushW, height: bushH - ps * 3))
                c.fill(CGRect(x: x + ps, y: h - ps, width: bushW - ps * 2, height: ps))
                let hlColor = UIColor(red: 0.55, green: 0.38, blue: 0.18, alpha: 0.55)
                c.setFillColor(hlColor.cgColor)
                c.fill(CGRect(x: x + ps * 2, y: topY + ps, width: bushW - ps * 4, height: ps))
                x += bushW + gap
            }
        }
    }

    // MARK: Night Bushes

    private func renderNightBushStrip() -> UIImage {
        let w = Int(GK.worldWidth * 2)
        let h = 36
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let c = ctx.cgContext
            var x = 0
            while x < w {
                let bushW = Int.random(in: 18...32)
                let bushH = Int.random(in: 14...24)
                let gap = Int.random(in: 20...40)
                let ps = 4
                let bodyColor = UIColor(red: 0.05, green: 0.07, blue: 0.14, alpha: 0.80)
                c.setFillColor(bodyColor.cgColor)
                let topY = h - bushH
                c.fill(CGRect(x: x + ps * 2, y: topY, width: bushW - ps * 4, height: ps))
                c.fill(CGRect(x: x + ps, y: topY + ps, width: bushW - ps * 2, height: ps))
                c.fill(CGRect(x: x, y: topY + ps * 2, width: bushW, height: bushH - ps * 3))
                c.fill(CGRect(x: x + ps, y: h - ps, width: bushW - ps * 2, height: ps))
                let hlColor = UIColor(red: 0.08, green: 0.12, blue: 0.22, alpha: 0.60)
                c.setFillColor(hlColor.cgColor)
                c.fill(CGRect(x: x + ps * 2, y: topY + ps, width: bushW - ps * 4, height: ps))
                x += bushW + gap
            }
        }
    }

    // MARK: Urban Foreground — neonCity / pixelTokyo

    private func renderUrbanForegroundStrip(tokyo: Bool) -> UIImage {
        let w = Int(GK.worldWidth * 2)
        let h = 36
        let ps = 4
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let c = ctx.cgContext

            let signBase = tokyo ? UIColor(red: 0.18, green: 0.10, blue: 0.30, alpha: 0.80)
                                 : UIColor(red: 0.12, green: 0.06, blue: 0.22, alpha: 0.80)
            let neonA = tokyo ? UIColor(red: 1.0, green: 0.35, blue: 0.55, alpha: 0.85)
                              : UIColor(red: 0.25, green: 0.85, blue: 1.0, alpha: 0.80)
            let neonB = tokyo ? UIColor(red: 0.40, green: 0.75, blue: 1.0, alpha: 0.80)
                              : UIColor(red: 1.0, green: 0.20, blue: 0.60, alpha: 0.80)

            var x = 0
            var toggle = false
            while x < w {
                let elW = Int.random(in: 12...28)
                let elH = Int.random(in: 10...20)
                let gap = Int.random(in: 14...30)

                let topY = h - elH
                // Small sign / barrier block
                c.setFillColor(signBase.cgColor)
                c.fill(CGRect(x: x, y: topY, width: elW, height: elH))

                // Neon accent stripe on top
                let nc = toggle ? neonA : neonB
                c.setFillColor(nc.cgColor)
                c.fill(CGRect(x: x + ps, y: topY, width: elW - ps * 2, height: ps))
                // Glow below stripe
                c.setFillColor(nc.withAlphaComponent(0.30).cgColor)
                c.fill(CGRect(x: x + ps, y: topY + ps, width: elW - ps * 2, height: ps))

                x += elW + gap
                toggle.toggle()
            }
        }
    }

    // MARK: Bubble + Fish Strip — underwater foreground

    private func renderBubbleFishStrip() -> UIImage {
        let w = Int(GK.worldWidth * 2)
        let h = 36
        let ps = 4
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let c = ctx.cgContext

            let bubble = UIColor(red: 0.60, green: 0.85, blue: 1.0, alpha: 0.40)
            let bubbleH = UIColor(red: 0.80, green: 0.95, blue: 1.0, alpha: 0.55)
            let fishBody = UIColor(red: 1.0, green: 0.55, blue: 0.25, alpha: 0.65)
            let fishTail = UIColor(red: 1.0, green: 0.40, blue: 0.20, alpha: 0.60)

            // Scatter bubbles
            var x = 4
            while x < w {
                let size = Int.random(in: 1...3)
                let y = Int.random(in: 4...(h - size * ps - 4))
                c.setFillColor(bubble.cgColor)
                for row in 0..<size {
                    for col in 0..<size {
                        c.fill(CGRect(x: x + col * ps, y: y + row * ps, width: ps, height: ps))
                    }
                }
                // Highlight pixel
                c.setFillColor(bubbleH.cgColor)
                c.fill(CGRect(x: x, y: y, width: ps, height: ps))

                // Every 3rd element is a small fish instead
                if x % (ps * 18) < ps * 3 {
                    let fy = Int.random(in: 8...(h - 12))
                    c.setFillColor(fishBody.cgColor)
                    c.fill(CGRect(x: x, y: fy, width: ps, height: ps))
                    c.fill(CGRect(x: x + ps, y: fy, width: ps, height: ps))
                    c.fill(CGRect(x: x + ps, y: fy - ps, width: ps, height: ps))
                    c.fill(CGRect(x: x + ps, y: fy + ps, width: ps, height: ps))
                    c.setFillColor(fishTail.cgColor)
                    c.fill(CGRect(x: x + ps * 2, y: fy - ps, width: ps, height: ps))
                    c.fill(CGRect(x: x + ps * 2, y: fy + ps, width: ps, height: ps))
                }

                x += Int.random(in: 20...40)
            }
        }
    }

    // MARK: Lava Pool Strip — volcano foreground

    private func renderLavaPoolStrip() -> UIImage {
        let w = Int(GK.worldWidth * 2)
        let h = 36
        let ps = 4
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let c = ctx.cgContext

            let lavaOuter = UIColor(red: 0.80, green: 0.25, blue: 0.05, alpha: 0.70)
            let lavaInner = UIColor(red: 1.0, green: 0.65, blue: 0.15, alpha: 0.65)
            let lavaHot   = UIColor(red: 1.0, green: 0.90, blue: 0.40, alpha: 0.55)
            let ember      = UIColor(red: 1.0, green: 0.50, blue: 0.10, alpha: 0.50)
            let rock       = UIColor(red: 0.22, green: 0.14, blue: 0.10, alpha: 0.75)

            var x = 0
            while x < w {
                let poolW = Int.random(in: 16...28)
                let poolH = Int.random(in: 6...12)
                let gap = Int.random(in: 20...35)
                let topY = h - poolH

                // Rock border
                c.setFillColor(rock.cgColor)
                c.fill(CGRect(x: x, y: topY, width: poolW, height: ps))
                c.fill(CGRect(x: x, y: h - ps, width: poolW, height: ps))

                // Lava fill
                c.setFillColor(lavaOuter.cgColor)
                c.fill(CGRect(x: x + ps, y: topY + ps, width: poolW - ps * 2, height: poolH - ps * 2))
                // Hot center
                c.setFillColor(lavaInner.cgColor)
                c.fill(CGRect(x: x + ps * 2, y: topY + ps * 2, width: max(ps, poolW - ps * 4), height: max(ps, poolH - ps * 4)))
                // Bright pixel
                if poolW > 16 {
                    c.setFillColor(lavaHot.cgColor)
                    c.fill(CGRect(x: x + poolW / 2, y: topY + poolH / 2, width: ps, height: ps))
                }

                // Floating ember above
                if Int.random(in: 0...2) == 0 {
                    c.setFillColor(ember.cgColor)
                    c.fill(CGRect(x: x + Int.random(in: 2...max(3, poolW - 4)),
                                  y: topY - Int.random(in: ps...(ps * 3)),
                                  width: ps - 1, height: ps - 1))
                }

                x += poolW + gap
            }
        }
    }

    // MARK: Ice Crystal Strip — arctic foreground

    private func renderIceCrystalStrip() -> UIImage {
        let w = Int(GK.worldWidth * 2)
        let h = 36
        let ps = 4
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let c = ctx.cgContext

            let iceLight = UIColor(red: 0.80, green: 0.92, blue: 1.0, alpha: 0.65)
            let iceMid   = UIColor(red: 0.60, green: 0.78, blue: 0.92, alpha: 0.55)
            let iceShine = UIColor(red: 0.95, green: 0.98, blue: 1.0, alpha: 0.80)

            var x = 0
            while x < w {
                let crystalH = Int.random(in: 10...22)
                let gap = Int.random(in: 18...36)
                let topY = h - crystalH

                // Diamond / crystal shape — narrow at top, wider middle, narrow base
                let midRow = crystalH / 2
                for row in 0..<crystalH {
                    let dist = abs(row - midRow)
                    let halfW = max(1, midRow - dist + 1)
                    let cx = x + ps   // center offset
                    for col in -halfW..<halfW {
                        let color = col == 0 && row < midRow ? iceShine
                                  : row < midRow ? iceLight : iceMid
                        c.setFillColor(color.cgColor)
                        c.fill(CGRect(x: cx + col * ps, y: topY + row * ps, width: ps, height: ps))
                    }
                }

                x += ps * 4 + gap
            }
        }
    }

    // MARK: Space Debris Strip — space foreground

    private func renderSpaceDebrisStrip() -> UIImage {
        let w = Int(GK.worldWidth * 2)
        let h = 36
        let ps = 4
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let c = ctx.cgContext

            let rockD = UIColor(red: 0.25, green: 0.22, blue: 0.20, alpha: 0.60)
            let rockL = UIColor(red: 0.38, green: 0.35, blue: 0.30, alpha: 0.50)
            let metalA = UIColor(red: 0.40, green: 0.42, blue: 0.48, alpha: 0.55)
            let metalB = UIColor(red: 0.55, green: 0.58, blue: 0.62, alpha: 0.45)

            var x = 0
            while x < w {
                let gap = Int.random(in: 24...44)
                let y = Int.random(in: 4...(h - 16))

                // Alternate small asteroids and debris
                if x % (ps * 14) < ps * 5 {
                    // Small asteroid (3×2 px)
                    c.setFillColor(rockD.cgColor)
                    c.fill(CGRect(x: x, y: y, width: ps, height: ps))
                    c.fill(CGRect(x: x + ps, y: y, width: ps, height: ps))
                    c.fill(CGRect(x: x + ps * 2, y: y, width: ps, height: ps))
                    c.fill(CGRect(x: x, y: y + ps, width: ps, height: ps))
                    c.fill(CGRect(x: x + ps, y: y + ps, width: ps, height: ps))
                    c.setFillColor(rockL.cgColor)
                    c.fill(CGRect(x: x + ps * 2, y: y + ps, width: ps, height: ps))
                } else {
                    // Metal debris panel (2×3 px)
                    c.setFillColor(metalA.cgColor)
                    c.fill(CGRect(x: x, y: y, width: ps, height: ps))
                    c.fill(CGRect(x: x + ps, y: y, width: ps, height: ps))
                    c.setFillColor(metalB.cgColor)
                    c.fill(CGRect(x: x, y: y + ps, width: ps, height: ps))
                    c.fill(CGRect(x: x + ps, y: y + ps, width: ps, height: ps))
                    c.setFillColor(metalA.cgColor)
                    c.fill(CGRect(x: x, y: y + ps * 2, width: ps, height: ps))
                    c.fill(CGRect(x: x + ps, y: y + ps * 2, width: ps, height: ps))
                }

                x += gap
            }
        }
    }

    // MARK: - Western Theme

    // MARK: Western Mesa Hills — flat-topped buttes and mesa formations

    private func renderWesternMesaHills() -> UIImage {
        let w: CGFloat = GK.worldWidth * 2
        let h: CGFloat = 300
        let ps: CGFloat = 4
        let gridW = Int(w / ps)

        // Mesa height map — flat-topped formations with steep sides
        var heightMap = [Int](repeating: 0, count: gridW)
        let mesas: [(center: Int, halfWidth: Int, peak: Int)] = [
            (15, 12, 35), (50, 25, 28), (80, 8, 48),
            (105, 18, 22), (140, 10, 42), (170, 30, 32), (195, 12, 38),
        ]
        for mesa in mesas {
            for x in max(0, mesa.center - mesa.halfWidth)..<min(gridW, mesa.center + mesa.halfWidth) {
                let dist = abs(x - mesa.center)
                let edgeDist = mesa.halfWidth - dist
                let bh = edgeDist <= 2 ? Int(CGFloat(mesa.peak) * CGFloat(edgeDist) / 3.0) : mesa.peak
                heightMap[x] = max(heightMap[x], bh)
            }
        }
        let dunes: [(center: Int, radius: Int, peak: Int)] = [
            (35, 20, 6), (95, 15, 5), (125, 20, 7), (155, 15, 4), (185, 12, 5),
        ]
        for dune in dunes {
            for x in max(0, dune.center - dune.radius)..<min(gridW, dune.center + dune.radius) {
                let dist = abs(x - dune.center)
                let nd = CGFloat(dist) / CGFloat(dune.radius)
                heightMap[x] = max(heightMap[x], Int(CGFloat(dune.peak) * (1.0 - nd * nd)))
            }
        }

        let mesaBase   = UIColor(red: 0.36, green: 0.20, blue: 0.09, alpha: 0.85)
        let mesaLayer1 = UIColor(red: 0.48, green: 0.28, blue: 0.12, alpha: 0.82)
        let mesaLayer2 = UIColor(red: 0.55, green: 0.34, blue: 0.16, alpha: 0.80)
        let mesaLayer3 = UIColor(red: 0.62, green: 0.40, blue: 0.22, alpha: 0.78)
        let mesaTop    = UIColor(red: 0.25, green: 0.14, blue: 0.07, alpha: 0.90)
        let mesaLight  = UIColor(red: 0.78, green: 0.58, blue: 0.30, alpha: 0.65)
        let dustHaze   = UIColor(red: 0.80, green: 0.65, blue: 0.45, alpha: 0.06)
        // Saloon colors
        let woodDark   = UIColor(red: 0.30, green: 0.18, blue: 0.08, alpha: 0.90)
        let woodMid    = UIColor(red: 0.45, green: 0.28, blue: 0.12, alpha: 0.88)
        let woodLight  = UIColor(red: 0.55, green: 0.38, blue: 0.18, alpha: 0.85)
        let roofRed    = UIColor(red: 0.50, green: 0.15, blue: 0.10, alpha: 0.88)
        let windowGlow = UIColor(red: 0.90, green: 0.75, blue: 0.35, alpha: 0.85)
        let signYellow = UIColor(red: 0.85, green: 0.70, blue: 0.25, alpha: 0.80)
        let doorDark   = UIColor(red: 0.22, green: 0.12, blue: 0.05, alpha: 0.90)
        // Cactus colors
        let cactusD    = UIColor(red: 0.15, green: 0.38, blue: 0.12, alpha: 0.88)
        let cactusM    = UIColor(red: 0.22, green: 0.50, blue: 0.18, alpha: 0.85)
        let cactusL    = UIColor(red: 0.30, green: 0.60, blue: 0.25, alpha: 0.80)
        let cactusSpine = UIColor(red: 0.50, green: 0.65, blue: 0.30, alpha: 0.55)
        // Fence / wagon
        let fenceBrown = UIColor(red: 0.40, green: 0.25, blue: 0.10, alpha: 0.75)
        let wagonGray  = UIColor(red: 0.35, green: 0.30, blue: 0.25, alpha: 0.70)
        let tumbleC    = UIColor(red: 0.55, green: 0.45, blue: 0.25, alpha: 0.50)
        let sageGreen  = UIColor(red: 0.35, green: 0.42, blue: 0.25, alpha: 0.55)

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let c = ctx.cgContext

            func fill(_ fx: Int, _ fy: Int, _ fw: Int, _ fh: Int, _ color: UIColor) {
                guard fw > 0 && fh > 0 else { return }
                c.setFillColor(color.cgColor)
                c.fill(CGRect(x: CGFloat(fx) * ps, y: h - CGFloat(fy + fh) * ps,
                              width: CGFloat(fw) * ps, height: CGFloat(fh) * ps))
            }
            func dot(_ dx: Int, _ dy: Int, _ color: UIColor) {
                fill(dx, dy, 1, 1, color)
            }

            // Dust haze
            c.setFillColor(dustHaze.cgColor)
            c.fill(CGRect(x: 0, y: h * 0.25, width: w, height: h * 0.15))

            // Mesa terrain
            for x in 0..<gridW {
                let mH = heightMap[x]
                guard mH > 0 else { continue }
                for y in 0..<mH {
                    let yPos = h - CGFloat(y + 1) * ps
                    let ratio = CGFloat(y) / max(1, CGFloat(mH))
                    let color: UIColor
                    if y == mH - 1 { color = mesaTop }
                    else if ratio > 0.80 { color = mesaLayer3 }
                    else if ratio > 0.60 { color = mesaLayer2 }
                    else if ratio > 0.40 { color = mesaLayer1 }
                    else if ratio > 0.20 { color = mesaBase }
                    else { color = mesaLight }
                    if x > 0 && heightMap[x - 1] < y && ratio > 0.5 {
                        c.setFillColor(mesaLight.cgColor)
                    } else {
                        c.setFillColor(color.cgColor)
                    }
                    c.fill(CGRect(x: CGFloat(x) * ps, y: yPos, width: ps, height: ps))
                }
            }

            // ── SALOON BUILDING ── (at x=60..85, y=0..30)
            let sx = 60, sy = 0
            fill(sx, sy, 26, 22, woodMid)           // Main body
            fill(sx, sy + 22, 26, 2, woodDark)       // Top trim
            // Peaked roof
            for dx in 0..<26 {
                let roofH = max(0, 5 - abs(dx - 13) / 2)
                if roofH > 0 { fill(sx + dx, sy + 24, 1, roofH, roofRed) }
            }
            // False front / facade
            fill(sx + 1, sy + 24, 24, 4, woodLight)
            fill(sx + 1, sy + 28, 24, 1, woodDark)
            // SALOON sign
            fill(sx + 5, sy + 25, 16, 2, signYellow)
            // Windows (2 upstairs, glowing)
            fill(sx + 3, sy + 16, 4, 4, windowGlow)
            fill(sx + 19, sy + 16, 4, 4, windowGlow)
            // Window frames
            fill(sx + 3, sy + 20, 4, 1, woodDark)
            fill(sx + 19, sy + 20, 4, 1, woodDark)
            fill(sx + 5, sy + 16, 1, 4, woodDark)    // Window cross
            fill(sx + 21, sy + 16, 1, 4, woodDark)
            // Swinging doors
            fill(sx + 10, sy, 6, 10, doorDark)
            fill(sx + 10, sy + 10, 6, 1, woodDark)   // Door top
            fill(sx + 12, sy + 5, 1, 1, signYellow)   // Door handle
            // Porch overhang
            fill(sx - 1, sy + 12, 28, 1, woodDark)
            // Porch posts
            fill(sx, sy, 1, 12, woodDark)
            fill(sx + 25, sy, 1, 12, woodDark)
            fill(sx + 8, sy, 1, 12, woodDark)
            fill(sx + 17, sy, 1, 12, woodDark)
            // Porch railing
            fill(sx, sy + 4, 9, 1, fenceBrown)
            fill(sx + 17, sy + 4, 9, 1, fenceBrown)
            // Barrel on porch
            fill(sx + 2, sy, 3, 4, woodDark)
            fill(sx + 2, sy + 2, 3, 1, woodLight)
            // Chimney
            fill(sx + 20, sy + 29, 3, 5, mesaBase)

            // ── SAGUARO CACTUS 1 ── (x=110, tall)
            let c1x = 110, c1y = 0
            fill(c1x + 2, c1y, 3, 30, cactusM)       // Main trunk
            fill(c1x + 3, c1y + 2, 1, 26, cactusL)   // Light highlight
            // Left arm
            fill(c1x, c1y + 14, 2, 2, cactusM)       // Horizontal
            fill(c1x, c1y + 16, 2, 10, cactusM)      // Vertical up
            fill(c1x + 1, c1y + 17, 1, 8, cactusL)   // Highlight
            // Right arm
            fill(c1x + 5, c1y + 18, 2, 2, cactusM)
            fill(c1x + 5, c1y + 20, 2, 8, cactusM)
            fill(c1x + 6, c1y + 21, 1, 6, cactusL)
            // Spines
            dot(c1x + 1, c1y + 28, cactusSpine)
            dot(c1x + 4, c1y + 25, cactusSpine)
            dot(c1x + 1, c1y + 22, cactusSpine)

            // ── SAGUARO CACTUS 2 ── (x=155, shorter)
            let c2x = 155, c2y = 0
            fill(c2x + 1, c2y, 3, 22, cactusD)
            fill(c2x + 2, c2y + 1, 1, 19, cactusM)
            // One arm left
            fill(c2x - 1, c2y + 10, 2, 2, cactusD)
            fill(c2x - 1, c2y + 12, 2, 7, cactusD)
            fill(c2x, c2y + 13, 1, 5, cactusM)

            // ── BARREL CACTUS ── (x=130)
            fill(130, 0, 5, 6, cactusD)
            fill(131, 1, 3, 4, cactusM)
            fill(132, 6, 1, 1, cactusSpine)           // Flower bud

            // ── WOODEN FENCE ── (x=38..55)
            for fx in stride(from: 38, to: 56, by: 4) {
                fill(fx, 0, 1, 8, fenceBrown)          // Post
                dot(fx, 8, woodDark)                    // Post cap
            }
            fill(38, 3, 17, 1, fenceBrown)             // Rail 1
            fill(38, 6, 17, 1, fenceBrown)             // Rail 2

            // ── WAGON WHEEL ── (x=145, y=0)
            let wx = 145, wy = 0
            // Outer rim (circle approx)
            let wheelR = 4
            for angle in 0..<12 {
                let a = CGFloat(angle) * .pi / 6
                let px = wx + Int(round(CGFloat(wheelR) * cos(a)))
                let py = wy + wheelR + Int(round(CGFloat(wheelR) * sin(a)))
                dot(px, py, wagonGray)
            }
            dot(wx, wy + wheelR, wagonGray)            // Hub
            // Spokes
            fill(wx, wy + 1, 1, 7, wagonGray)
            fill(wx - 3, wy + wheelR, 7, 1, wagonGray)

            // ── TUMBLEWEEDS ──
            for tx in [93, 178, 35] {
                for dy in 0..<3 {
                    for dx in 0..<3 {
                        if (dx + dy) % 2 == 0 { dot(tx + dx, dy, tumbleC) }
                    }
                }
            }

            // ── SAGEBRUSH ──
            for sbx in [42, 98, 125, 165, 188] {
                fill(sbx, 0, 3, 2, sageGreen)
                dot(sbx + 1, 2, sageGreen)
            }

            // ── VULTURES ──
            let vultureC = UIColor(red: 0.15, green: 0.12, blue: 0.10, alpha: 0.45)
            for (vx, vy) in [(40, 62), (130, 58)] {
                dot(vx - 2, vy, vultureC); dot(vx - 1, vy + 1, vultureC)
                dot(vx, vy, vultureC)
                dot(vx + 1, vy + 1, vultureC); dot(vx + 2, vy, vultureC)
            }

            // ── WATER TOWER ── (x=175)
            fill(175, 0, 1, 18, woodDark)              // Left leg
            fill(181, 0, 1, 18, woodDark)              // Right leg
            fill(178, 0, 1, 18, woodDark)              // Center brace
            fill(174, 18, 9, 7, woodMid)               // Tank
            fill(174, 25, 9, 1, woodDark)              // Tank rim
            fill(175, 19, 7, 5, woodLight)             // Tank highlight
            fill(177, 18, 1, 1, woodDark)              // Spout
        }
    }

    // MARK: Western Cacti Midground — saguaros, barrel cacti, and saloon silhouette

    private func renderWesternCactiMidground() -> UIImage {
        let w: CGFloat = GK.worldWidth * 2
        let h: CGFloat = 160
        let ps: CGFloat = 4
        let C = UIColor.clear

        let cD = UIColor(red: 0.18, green: 0.35, blue: 0.18, alpha: 0.70) // cactus dark
        let cM = UIColor(red: 0.29, green: 0.48, blue: 0.23, alpha: 0.65) // cactus mid
        let cL = UIColor(red: 0.42, green: 0.61, blue: 0.33, alpha: 0.55) // cactus light
        let sB = UIColor(red: 0.29, green: 0.19, blue: 0.13, alpha: 0.70) // saloon wood
        let sD = UIColor(red: 0.20, green: 0.12, blue: 0.08, alpha: 0.75) // saloon dark

        // Tall Saguaro (7w × 14h)
        let saguaro: [[UIColor]] = [
            [C,C,C,cM,C,C,C],
            [C,cM,C,cM,C,cM,C],
            [C,cM,C,cM,C,cM,C],
            [cD,cM,C,cM,C,cM,cD],
            [C,cL,cM,cM,cM,cL,C],
            [C,C,cM,cM,cM,C,C],
            [C,C,C,cM,C,C,C],
            [C,C,C,cM,C,C,C],
            [C,C,C,cM,C,C,C],
            [C,C,C,cL,C,C,C],
            [C,C,C,cM,C,C,C],
            [C,C,C,cM,C,C,C],
            [C,C,C,cM,C,C,C],
            [C,C,C,cM,C,C,C],
        ]

        // Barrel Cactus (5w × 5h)
        let barrel: [[UIColor]] = [
            [C,cD,cM,cD,C],
            [cD,cL,cM,cL,cD],
            [cM,cM,cL,cM,cM],
            [C,cD,cM,cD,C],
            [C,C,cD,C,C],
        ]

        // Saloon (11w × 10h)
        let saloon: [[UIColor]] = [
            [C,C,sB,sB,sB,sB,sB,sB,sB,C,C],
            [C,C,sB,sD,sD,sD,sD,sD,sB,C,C],
            [C,sB,sB,sB,sB,sB,sB,sB,sB,sB,C],
            [C,sB,sD,sB,sD,sD,sD,sB,sD,sB,C],
            [C,sB,sD,sB,sD,sD,sD,sB,sD,sB,C],
            [sB,sB,sB,sB,sB,sB,sB,sB,sB,sB,sB],
            [sB,sD,sB,sD,sB,sD,sB,sD,sB,sD,sB],
            [sB,sD,sB,sD,sB,sD,sB,sD,sB,sD,sB],
            [sB,sB,sB,sB,sB,sB,sB,sB,sB,sB,sB],
            [sB,sB,sB,sB,sB,sB,sB,sB,sB,sB,sB],
        ]

        let positions: [(x: CGFloat, type: Int)] = [
            (20, 0), (90, 1), (140, 0), (210, 1), (280, 2),
            (370, 0), (440, 1), (510, 0), (570, 1), (640, 0),
            (700, 2), (760, 0),
        ]

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let c = ctx.cgContext
            for pos in positions {
                let template: [[UIColor]]
                switch pos.type {
                case 0: template = saguaro
                case 1: template = barrel
                default: template = saloon
                }
                let tH = template.count
                let tW = template[0].count
                let baseY = h - CGFloat(tH) * ps
                for row in 0..<tH {
                    for col in 0..<tW {
                        let color = template[row][col]
                        guard color != C else { continue }
                        c.setFillColor(color.cgColor)
                        c.fill(CGRect(x: pos.x + CGFloat(col) * ps,
                                      y: baseY + CGFloat(row) * ps,
                                      width: ps, height: ps))
                    }
                }
            }
        }
    }

    // MARK: Western Scrub Strip — tumbleweeds, dry grass, rocks

    private func renderWesternScrubStrip() -> UIImage {
        let w = Int(GK.worldWidth * 2)
        let h = 36
        let ps = 4
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let c = ctx.cgContext
            let straw  = UIColor(red: 0.63, green: 0.50, blue: 0.31, alpha: 0.60)
            let dryGrn = UIColor(red: 0.45, green: 0.40, blue: 0.25, alpha: 0.55)
            let rock   = UIColor(red: 0.50, green: 0.38, blue: 0.25, alpha: 0.65)

            var x = 0
            while x < w {
                let kind = Int.random(in: 0...2)
                let gap = Int.random(in: 20...40)

                if kind == 0 {
                    // Tumbleweed — circular blob
                    let sz = Int.random(in: 3...5)
                    let by = h - sz * ps
                    for row in 0..<sz {
                        for col in 0..<sz {
                            let dx = col - sz / 2
                            let dy = row - sz / 2
                            if dx * dx + dy * dy <= (sz / 2 + 1) * (sz / 2 + 1) {
                                c.setFillColor(straw.cgColor)
                                c.fill(CGRect(x: x + col * ps, y: by + row * ps, width: ps, height: ps))
                            }
                        }
                    }
                } else if kind == 1 {
                    // Dry scrub — small bush
                    let bw = Int.random(in: 4...6)
                    let bh = Int.random(in: 2...3)
                    let by = h - bh * ps
                    for row in 0..<bh {
                        for col in 0..<bw {
                            if row == 0 && (col == 0 || col == bw - 1) { continue }
                            c.setFillColor(dryGrn.cgColor)
                            c.fill(CGRect(x: x + col * ps, y: by + row * ps, width: ps, height: ps))
                        }
                    }
                } else {
                    // Small rock
                    let rw = Int.random(in: 3...4)
                    let rh = 2
                    let by = h - rh * ps
                    for row in 0..<rh {
                        for col in 0..<rw {
                            if row == 0 && col == 0 { continue }
                            c.setFillColor(rock.cgColor)
                            c.fill(CGRect(x: x + col * ps, y: by + row * ps, width: ps, height: ps))
                        }
                    }
                }
                x += ps * 6 + gap
            }
        }
    }

    // MARK: - Jungle Theme

    // MARK: Jungle Canopy Hills — dense rolling treetop silhouette

    private func renderJungleCanopyHills() -> UIImage {
        let w: CGFloat = GK.worldWidth * 2
        let h: CGFloat = 300
        let ps: CGFloat = 4
        let gridW = Int(w / ps)

        // Dense overlapping canopy — very tall
        var heightMap = [Int](repeating: 3, count: gridW)
        let bumps: [(center: Int, radius: Int, peak: Int)] = [
            (15, 25, 35), (40, 30, 45), (65, 20, 30), (85, 35, 50),
            (110, 25, 38), (135, 30, 48), (155, 20, 32), (175, 35, 45),
            (195, 20, 35),
        ]
        for bump in bumps {
            for x in max(0, bump.center - bump.radius)..<min(gridW, bump.center + bump.radius) {
                let dist = abs(x - bump.center)
                let nd = CGFloat(dist) / CGFloat(bump.radius)
                heightMap[x] = max(heightMap[x], Int(CGFloat(bump.peak) * (1.0 - nd * nd)))
            }
        }

        let deepGreen   = UIColor(red: 0.04, green: 0.18, blue: 0.08, alpha: 0.88)
        let midGreen    = UIColor(red: 0.08, green: 0.32, blue: 0.14, alpha: 0.82)
        let lightGreen  = UIColor(red: 0.15, green: 0.45, blue: 0.20, alpha: 0.78)
        let topGreen    = UIColor(red: 0.03, green: 0.14, blue: 0.06, alpha: 0.90)
        let sunDapple   = UIColor(red: 0.22, green: 0.55, blue: 0.25, alpha: 0.60)
        // Tree trunks
        let barkDark    = UIColor(red: 0.18, green: 0.12, blue: 0.06, alpha: 0.88)
        let barkMid     = UIColor(red: 0.28, green: 0.18, blue: 0.10, alpha: 0.85)
        let barkLight   = UIColor(red: 0.38, green: 0.25, blue: 0.14, alpha: 0.80)
        let barkMoss    = UIColor(red: 0.15, green: 0.30, blue: 0.12, alpha: 0.70)
        // Vines
        let vineD       = UIColor(red: 0.10, green: 0.28, blue: 0.12, alpha: 0.72)
        let vineL       = UIColor(red: 0.18, green: 0.40, blue: 0.18, alpha: 0.65)
        // Snake
        let snakeGreen  = UIColor(red: 0.25, green: 0.55, blue: 0.20, alpha: 0.80)
        let snakeYellow = UIColor(red: 0.70, green: 0.60, blue: 0.20, alpha: 0.78)
        let snakeEye    = UIColor(red: 0.90, green: 0.20, blue: 0.15, alpha: 0.85)
        // Parrot
        let parrotRed   = UIColor(red: 0.85, green: 0.20, blue: 0.15, alpha: 0.80)
        let parrotBlue  = UIColor(red: 0.15, green: 0.40, blue: 0.80, alpha: 0.78)
        let parrotYellow = UIColor(red: 0.95, green: 0.80, blue: 0.20, alpha: 0.80)
        // Flowers
        let orchidPink  = UIColor(red: 0.85, green: 0.35, blue: 0.55, alpha: 0.75)
        let orchidWhite = UIColor(red: 0.90, green: 0.85, blue: 0.88, alpha: 0.70)
        // Fern
        let fernD       = UIColor(red: 0.10, green: 0.35, blue: 0.12, alpha: 0.75)
        let fernL       = UIColor(red: 0.18, green: 0.50, blue: 0.20, alpha: 0.70)
        // Frog
        let frogGreen   = UIColor(red: 0.30, green: 0.70, blue: 0.25, alpha: 0.75)
        let frogRed     = UIColor(red: 0.80, green: 0.15, blue: 0.10, alpha: 0.72)
        // Butterfly
        let butterflyB  = UIColor(red: 0.20, green: 0.50, blue: 0.85, alpha: 0.55)

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let c = ctx.cgContext

            func fill(_ fx: Int, _ fy: Int, _ fw: Int, _ fh: Int, _ color: UIColor) {
                guard fw > 0 && fh > 0 else { return }
                c.setFillColor(color.cgColor)
                c.fill(CGRect(x: CGFloat(fx) * ps, y: h - CGFloat(fy + fh) * ps,
                              width: CGFloat(fw) * ps, height: CGFloat(fh) * ps))
            }
            func dot(_ dx: Int, _ dy: Int, _ color: UIColor) { fill(dx, dy, 1, 1, color) }

            // ── CANOPY TERRAIN ──
            for x in 0..<gridW {
                let mH = heightMap[x]
                for y in 0..<mH {
                    let yPos = h - CGFloat(y + 1) * ps
                    let ratio = CGFloat(y) / max(1, CGFloat(mH))
                    let color: UIColor
                    if y == mH - 1 { color = topGreen }
                    else if ratio > 0.75 && x % 5 == 0 { color = sunDapple }
                    else if ratio > 0.6 { color = lightGreen }
                    else if ratio > 0.3 { color = midGreen }
                    else { color = deepGreen }
                    c.setFillColor(color.cgColor)
                    c.fill(CGRect(x: CGFloat(x) * ps, y: yPos, width: ps, height: ps))
                }
            }

            // ── MASSIVE TREE TRUNK 1 ── (x=30..42, y=0..55)
            let t1x = 30, t1w = 12
            fill(t1x, 0, t1w, 55, barkDark)
            fill(t1x + 1, 1, t1w - 2, 53, barkMid)
            // Bark texture
            for by in stride(from: 3, to: 50, by: 5) {
                fill(t1x + 2, by, t1w - 4, 1, barkLight)
            }
            // Moss patches
            fill(t1x, 8, 2, 4, barkMoss)
            fill(t1x + t1w - 2, 20, 2, 5, barkMoss)
            fill(t1x + 1, 35, 3, 3, barkMoss)
            // Roots spreading out
            fill(t1x - 3, 0, 3, 3, barkDark)
            fill(t1x - 2, 0, 2, 5, barkMid)
            fill(t1x + t1w, 0, 3, 3, barkDark)
            fill(t1x + t1w + 1, 0, 2, 5, barkMid)
            // Branch stubs
            fill(t1x - 2, 30, 2, 2, barkDark)
            fill(t1x + t1w, 38, 3, 2, barkDark)

            // ── MASSIVE TREE TRUNK 2 ── (x=140..150, y=0..48)
            let t2x = 140, t2w = 10
            fill(t2x, 0, t2w, 48, barkDark)
            fill(t2x + 1, 1, t2w - 2, 46, barkMid)
            for by in stride(from: 4, to: 44, by: 6) {
                fill(t2x + 2, by, t2w - 4, 1, barkLight)
            }
            fill(t2x, 15, 2, 3, barkMoss)
            fill(t2x + t2w - 2, 28, 2, 4, barkMoss)
            // Roots
            fill(t2x - 2, 0, 2, 4, barkDark)
            fill(t2x + t2w, 0, 2, 4, barkDark)

            // ── HANGING VINES ──
            func drawVine(_ vx: Int, _ topY: Int, _ length: Int) {
                for i in 0..<length {
                    let sway = Int(sin(CGFloat(i) * 0.3) * 1.5)
                    dot(vx + sway, topY - i, i % 2 == 0 ? vineD : vineL)
                    // Leaves on vine
                    if i % 5 == 0 && i > 0 {
                        dot(vx + sway + 1, topY - i, vineL)
                        dot(vx + sway - 1, topY - i + 1, vineD)
                    }
                }
            }
            drawVine(25, 40, 20); drawVine(50, 38, 18); drawVine(70, 35, 15)
            drawVine(95, 42, 22); drawVine(120, 36, 16); drawVine(155, 40, 20)
            drawVine(180, 38, 18); drawVine(195, 35, 14)

            // ── SNAKE ON BRANCH ── (near trunk 2)
            let snkX = 148, snkY = 35
            // Body (sinuous)
            for i in 0..<12 {
                let sy = Int(sin(CGFloat(i) * 0.8) * 1.5)
                dot(snkX + i, snkY + sy, i < 3 ? snakeYellow : snakeGreen)
            }
            // Head
            fill(snkX + 12, snkY, 2, 2, snakeGreen)
            dot(snkX + 13, snkY + 1, snakeEye) // Eye
            // Forked tongue
            dot(snkX + 14, snkY, snakeEye)

            // ── PARROTS ──
            func drawParrot(_ px: Int, _ py: Int) {
                dot(px, py, parrotRed)           // Body
                dot(px, py + 1, parrotRed)
                dot(px + 1, py + 1, parrotBlue)  // Wing
                dot(px - 1, py + 1, parrotYellow) // Head
                dot(px - 1, py, parrotYellow)     // Beak
            }
            drawParrot(55, 42); drawParrot(110, 38); drawParrot(175, 44)

            // ── ORCHID FLOWERS ──
            for (fx, fy) in [(38, 20), (145, 15), (80, 25)] {
                dot(fx, fy, orchidPink); dot(fx + 1, fy, orchidPink)
                dot(fx, fy + 1, orchidWhite); dot(fx + 1, fy + 1, orchidPink)
            }

            // ── FERNS AT BASE ──
            func drawFern(_ bx: Int, _ by: Int) {
                fill(bx, by, 1, 4, fernD) // Stem
                for i in 1..<4 {
                    dot(bx - i, by + i, fernL)  // Left frond
                    dot(bx + i, by + i, fernL)  // Right frond
                }
                dot(bx, by + 4, fernL) // Tip
            }
            drawFern(10, 0); drawFern(60, 0); drawFern(100, 0)
            drawFern(130, 0); drawFern(170, 0); drawFern(192, 0)

            // ── TREE FROG ──
            let frgX = 75, frgY = 5
            fill(frgX, frgY, 3, 2, frogGreen)
            dot(frgX, frgY + 2, frogGreen)    // Head
            dot(frgX + 2, frgY + 2, frogGreen)
            dot(frgX, frgY + 3, frogRed)       // Eye
            dot(frgX + 2, frgY + 3, frogRed)
            // Feet
            dot(frgX - 1, frgY, frogGreen)
            dot(frgX + 3, frgY, frogGreen)

            // ── BUTTERFLIES ──
            for (bx, by) in [(20, 30), (90, 28), (165, 35)] {
                dot(bx, by, butterflyB)
                dot(bx - 1, by + 1, butterflyB); dot(bx + 1, by + 1, butterflyB)
                dot(bx - 1, by - 1, butterflyB); dot(bx + 1, by - 1, butterflyB)
            }
        }
    }

    // MARK: Jungle Tropical Trees — HUGE trees, snakes, dense vines, flowers, butterflies

    private func renderJungleTropicalTrees() -> UIImage {
        let w: CGFloat = GK.worldWidth * 2
        let h: CGFloat = 160
        let ps: CGFloat = 4
        let C = UIColor.clear

        let gD = UIColor(red: 0.12, green: 0.42, blue: 0.16, alpha: 0.65) // canopy dark
        let gM = UIColor(red: 0.24, green: 0.63, blue: 0.27, alpha: 0.60) // canopy mid
        let gL = UIColor(red: 0.42, green: 0.75, blue: 0.33, alpha: 0.50) // canopy light
        let gB = UIColor(red: 0.30, green: 0.70, blue: 0.35, alpha: 0.45) // bright leaf
        let tK = UIColor(red: 0.16, green: 0.10, blue: 0.06, alpha: 0.70) // trunk
        let tL = UIColor(red: 0.22, green: 0.14, blue: 0.08, alpha: 0.65) // trunk light
        let vN = UIColor(red: 0.10, green: 0.30, blue: 0.10, alpha: 0.55) // vine
        let fP = UIColor(red: 0.91, green: 0.25, blue: 0.50, alpha: 0.60) // flower pink
        let fO = UIColor(red: 1.00, green: 0.53, blue: 0.19, alpha: 0.60) // flower orange
        let sG = UIColor(red: 0.20, green: 0.55, blue: 0.12, alpha: 0.70) // snake green
        let sY = UIColor(red: 0.65, green: 0.60, blue: 0.10, alpha: 0.65) // snake pattern
        let sE = UIColor(red: 0.80, green: 0.15, blue: 0.10, alpha: 0.70) // snake eye
        let bW = UIColor(red: 0.30, green: 0.65, blue: 0.85, alpha: 0.50) // butterfly blue
        let bO = UIColor(red: 0.95, green: 0.55, blue: 0.15, alpha: 0.50) // butterfly orange

        // HUGE Jungle Tree (15w × 26h) — massive canopy, thick trunk, roots
        let hugeTree: [[UIColor]] = [
            [C,C,C,C,C,C,gD,gD,gD,C,C,C,C,C,C],
            [C,C,C,C,gD,gM,gM,gB,gM,gM,gD,C,C,C,C],
            [C,C,C,gD,gM,gL,gB,gL,gB,gL,gM,gD,C,C,C],
            [C,C,gD,gM,gL,gM,gL,gM,gL,gM,gL,gM,gD,C,C],
            [C,gD,gM,gL,gB,gM,gM,gM,gM,gB,gL,gM,gD,C,C],
            [gD,gM,gM,gM,gL,gL,gM,gM,gL,gL,gM,gM,gM,gD,C],
            [gD,gM,gL,gM,gM,gM,gM,gM,gM,gM,gM,gL,gM,gM,gD],
            [gD,gM,gM,gL,gM,gM,gM,gM,gM,gM,gL,gM,gM,gM,gD],
            [C,gD,gM,gM,gM,gM,gM,gM,gM,gM,gM,gM,gM,gD,C],
            [C,C,gD,gM,gM,gD,gM,gM,gM,gD,gM,gM,gD,C,C],
            [C,C,C,gD,gD,C,gD,gM,gD,C,gD,gD,C,C,C],
            [C,C,C,C,C,C,C,tK,C,C,C,C,C,C,C],
            [C,C,C,C,C,C,tK,tK,tK,C,C,C,C,C,C],
            [C,vN,C,C,C,C,tK,tL,tK,C,C,C,C,vN,C],
            [C,vN,C,C,C,C,tK,tL,tK,C,C,C,C,vN,C],
            [C,vN,C,C,C,C,tK,tL,tK,C,C,C,C,vN,C],
            [C,C,vN,C,C,C,tK,tL,tK,C,C,C,vN,C,C],
            [C,C,vN,C,C,tK,tK,tL,tK,tK,C,C,vN,C,C],
            [C,C,C,vN,C,tK,tL,tK,tL,tK,C,vN,C,C,C],
            [C,C,C,vN,C,tK,tL,tK,tL,tK,C,vN,C,C,C],
            [C,C,C,C,C,tK,tL,tK,tL,tK,C,C,C,C,C],
            [C,C,C,C,tK,tK,tL,tK,tL,tK,tK,C,C,C,C],
            [C,C,C,tK,tK,C,tK,tK,tK,C,tK,tK,C,C,C],
            [C,C,tK,tK,C,C,C,tK,C,C,C,tK,tK,C,C],
            [C,tK,C,C,C,C,C,tK,C,C,C,C,C,tK,C],
            [tK,C,C,C,C,C,C,tK,C,C,C,C,C,C,tK],
        ]

        // Tree with snake wrapped around trunk (11w × 20h)
        let snakeTree: [[UIColor]] = [
            [C,C,C,C,gD,gD,gD,C,C,C,C],
            [C,C,gD,gM,gM,gB,gM,gM,gD,C,C],
            [C,gD,gM,gL,gM,gM,gM,gL,gM,gD,C],
            [gD,gM,gM,gM,gL,gM,gL,gM,gM,gM,gD],
            [gD,gM,gL,gM,gM,gM,gM,gM,gL,gM,gD],
            [C,gD,gM,gM,gM,gM,gM,gM,gM,gD,C],
            [C,C,gD,gD,gD,gM,gD,gD,gD,C,C],
            [C,C,C,C,C,tK,C,C,C,C,C],
            [C,C,C,C,sG,tK,C,C,C,C,C],    // snake starts
            [C,C,C,sG,sY,tK,C,C,C,C,C],
            [C,C,C,C,sG,tK,sG,C,C,C,C],
            [C,C,C,C,tK,tK,sY,sG,C,C,C],
            [C,C,C,C,tK,sG,sG,C,C,C,C],
            [C,C,C,sG,sY,tK,C,C,C,C,C],
            [C,C,sE,sG,sG,tK,C,C,C,C,C],  // snake head with eye
            [C,C,C,C,C,tK,C,C,C,C,C],
            [C,vN,C,C,C,tK,C,C,C,vN,C],
            [C,vN,C,C,C,tK,C,C,C,vN,C],
            [C,C,C,C,C,tK,C,C,C,C,C],
            [C,C,C,C,C,tK,C,C,C,C,C],
        ]

        // Flower Bush (7w × 5h)
        let flowerBush: [[UIColor]] = [
            [C,C,fP,gM,fO,C,C],
            [C,gM,gM,gM,gM,gM,C],
            [gM,gM,gL,gM,gL,gM,gM],
            [C,gM,gM,gM,gM,gM,C],
            [C,C,gM,gM,gM,C,C],
        ]

        // Vine Cluster (3w × 12h) — longer hanging vines
        let vineCluster: [[UIColor]] = [
            [vN,C,C], [vN,C,vN], [vN,C,vN], [C,vN,vN],
            [C,vN,C], [C,vN,C], [vN,vN,C], [vN,C,C],
            [vN,C,vN], [C,C,vN], [C,vN,C], [C,vN,C],
        ]

        let positions: [(x: CGFloat, type: Int)] = [
            (10, 0),   // huge tree
            (80, 3),   // vine
            (120, 2),  // flower bush
            (180, 1),  // snake tree
            (280, 3),  // vine
            (330, 2),  // flower bush
            (380, 0),  // huge tree
            (480, 3),  // vine
            (530, 1),  // snake tree
            (620, 2),  // flower bush
            (670, 0),  // huge tree
            (770, 3),  // vine
        ]

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let c = ctx.cgContext
            for pos in positions {
                let template: [[UIColor]]
                switch pos.type {
                case 0: template = hugeTree
                case 1: template = snakeTree
                case 2: template = flowerBush
                default: template = vineCluster
                }
                let tH = template.count
                let tW = template[0].count
                let baseY = h - CGFloat(tH) * ps
                for row in 0..<tH {
                    for col in 0..<tW {
                        let color = template[row][col]
                        guard color != C else { continue }
                        c.setFillColor(color.cgColor)
                        c.fill(CGRect(x: pos.x + CGFloat(col) * ps,
                                      y: baseY + CGFloat(row) * ps,
                                      width: ps, height: ps))
                    }
                }
            }

            // Butterflies floating between trees
            let butterflies: [(x: CGFloat, y: CGFloat, color: UIColor)] = [
                (w * 0.15, h * 0.3, bW), (w * 0.35, h * 0.2, bO),
                (w * 0.55, h * 0.35, bW), (w * 0.78, h * 0.25, bO),
            ]
            for bf in butterflies {
                // Wing left + right
                c.setFillColor(bf.color.cgColor)
                c.fill(CGRect(x: bf.x - ps, y: bf.y, width: ps, height: ps))
                c.fill(CGRect(x: bf.x + ps, y: bf.y, width: ps, height: ps))
                // Body
                c.setFillColor(UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 0.5).cgColor)
                c.fill(CGRect(x: bf.x, y: bf.y, width: ps, height: ps))
            }
        }
    }

    // MARK: Jungle Fern Strip — ferns, small flowers, moss

    private func renderJungleFernStrip() -> UIImage {
        let w = Int(GK.worldWidth * 2)
        let h = 36
        let ps = 4
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let c = ctx.cgContext
            let fern  = UIColor(red: 0.18, green: 0.45, blue: 0.15, alpha: 0.65)
            let bloom = UIColor(red: 0.91, green: 0.25, blue: 0.50, alpha: 0.55)
            let moss  = UIColor(red: 0.23, green: 0.35, blue: 0.16, alpha: 0.60)

            var x = 0
            while x < w {
                let kind = Int.random(in: 0...2)
                let gap = Int.random(in: 14...24)

                if kind == 0 {
                    // Fern frond — fan shape
                    let fw = 6; let fh = 4
                    let by = h - fh * ps
                    for row in 0..<fh {
                        let cols = fw - row
                        let offset = row / 2
                        for col in offset..<(offset + cols) {
                            c.setFillColor(fern.cgColor)
                            c.fill(CGRect(x: x + col * ps, y: by + row * ps, width: ps, height: ps))
                        }
                    }
                } else if kind == 1 {
                    // Small tropical flower
                    let by = h - 3 * ps
                    c.setFillColor(fern.cgColor)
                    c.fill(CGRect(x: x + ps, y: by + 2 * ps, width: ps, height: ps)) // stem
                    c.fill(CGRect(x: x + ps, y: by + ps, width: ps, height: ps))
                    c.setFillColor(bloom.cgColor)
                    c.fill(CGRect(x: x, y: by, width: ps, height: ps))
                    c.fill(CGRect(x: x + ps, y: by, width: ps, height: ps))
                    c.fill(CGRect(x: x + 2 * ps, y: by, width: ps, height: ps))
                } else {
                    // Moss patch
                    let mw = Int.random(in: 4...6)
                    let by = h - ps
                    for col in 0..<mw {
                        c.setFillColor(moss.cgColor)
                        c.fill(CGRect(x: x + col * ps, y: by, width: ps, height: ps))
                        if col % 2 == 0 {
                            c.fill(CGRect(x: x + col * ps, y: by - ps, width: ps, height: ps))
                        }
                    }
                }
                x += ps * 5 + gap
            }
        }
    }

    // MARK: - Egypt Theme

    // MARK: Egypt Pyramid Hills — sand dunes with pyramid silhouettes

    private func renderEgyptPyramidHills() -> UIImage {
        let w: CGFloat = GK.worldWidth * 2
        let h: CGFloat = 300
        let ps: CGFloat = 4
        let gridW = Int(w / ps)

        var heightMap = [Int](repeating: 1, count: gridW)
        // Sand dunes
        let dunes: [(center: Int, radius: Int, peak: Int)] = [
            (15, 20, 10), (50, 25, 14), (90, 18, 8), (130, 22, 12),
            (170, 20, 10), (195, 15, 8),
        ]
        for dune in dunes {
            for x in max(0, dune.center - dune.radius)..<min(gridW, dune.center + dune.radius) {
                let dist = abs(x - dune.center)
                let nd = CGFloat(dist) / CGFloat(dune.radius)
                heightMap[x] = max(heightMap[x], Int(CGFloat(dune.peak) * (1.0 - nd * nd)))
            }
        }

        let sandBase  = UIColor(red: 0.75, green: 0.62, blue: 0.38, alpha: 0.75)
        let sandLight = UIColor(red: 0.85, green: 0.72, blue: 0.48, alpha: 0.70)
        let sandDark  = UIColor(red: 0.65, green: 0.52, blue: 0.30, alpha: 0.78)
        // Pyramids
        let pyrBase   = UIColor(red: 0.72, green: 0.58, blue: 0.35, alpha: 0.88)
        let pyrLight  = UIColor(red: 0.82, green: 0.68, blue: 0.42, alpha: 0.85)
        let pyrDark   = UIColor(red: 0.58, green: 0.45, blue: 0.28, alpha: 0.90)
        let pyrGold   = UIColor(red: 0.90, green: 0.78, blue: 0.40, alpha: 0.82)
        // Sphinx
        let sphinxD   = UIColor(red: 0.60, green: 0.48, blue: 0.30, alpha: 0.85)
        let sphinxL   = UIColor(red: 0.72, green: 0.58, blue: 0.38, alpha: 0.82)
        // Temple columns
        let colWhite  = UIColor(red: 0.85, green: 0.80, blue: 0.72, alpha: 0.78)
        let colShadow = UIColor(red: 0.65, green: 0.60, blue: 0.52, alpha: 0.75)
        // Hieroglyphics
        let hieroC    = UIColor(red: 0.55, green: 0.42, blue: 0.25, alpha: 0.45)
        // Palm
        let palmTrunk = UIColor(red: 0.40, green: 0.28, blue: 0.15, alpha: 0.72)
        let palmLeaf  = UIColor(red: 0.20, green: 0.48, blue: 0.22, alpha: 0.68)

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let c = ctx.cgContext

            func fill(_ fx: Int, _ fy: Int, _ fw: Int, _ fh: Int, _ color: UIColor) {
                guard fw > 0 && fh > 0 else { return }
                c.setFillColor(color.cgColor)
                c.fill(CGRect(x: CGFloat(fx) * ps, y: h - CGFloat(fy + fh) * ps,
                              width: CGFloat(fw) * ps, height: CGFloat(fh) * ps))
            }
            func dot(_ dx: Int, _ dy: Int, _ color: UIColor) { fill(dx, dy, 1, 1, color) }

            // Sand terrain
            for x in 0..<gridW {
                let mH = heightMap[x]
                for y in 0..<mH {
                    let yPos = h - CGFloat(y + 1) * ps
                    let color = y == mH - 1 ? sandDark : (y % 2 == 0 ? sandBase : sandLight)
                    c.setFillColor(color.cgColor)
                    c.fill(CGRect(x: CGFloat(x) * ps, y: yPos, width: ps, height: ps))
                }
            }

            // ── GREAT PYRAMID ── (x=50, large triangle)
            for row in 0..<40 {
                let pw = 40 - row
                let px = 50 - pw / 2
                let leftSide = row < 20
                fill(px, row + 5, pw, 1, leftSide || row > 30 ? pyrLight : pyrBase)
            }
            // Brick lines
            for row in stride(from: 5, to: 45, by: 4) {
                let pw = max(1, 40 - (row - 5))
                let px = 50 - pw / 2
                fill(px, row, pw, 1, pyrDark)
            }
            // Gold capstone
            fill(49, 44, 3, 2, pyrGold)
            dot(50, 46, pyrGold)

            // ── SMALLER PYRAMID ── (x=85)
            for row in 0..<28 {
                let pw = 28 - row
                fill(85 - pw / 2, row + 3, pw, 1, row < 14 ? pyrLight : pyrBase)
            }
            for row in stride(from: 3, to: 31, by: 4) {
                let pw = max(1, 28 - (row - 3))
                fill(85 - pw / 2, row, pw, 1, pyrDark)
            }
            fill(84, 30, 3, 1, pyrGold)

            // ── SPHINX ── (x=110..130, y=2..12)
            // Body
            fill(112, 2, 16, 5, sphinxD)
            fill(113, 3, 14, 3, sphinxL)
            // Head
            fill(110, 7, 6, 6, sphinxD)
            fill(111, 8, 4, 4, sphinxL)
            // Headdress
            fill(109, 12, 2, 2, sphinxD)
            fill(116, 12, 2, 2, sphinxD)
            // Face detail
            dot(112, 10, pyrDark) // Eye
            dot(113, 9, pyrDark)  // Nose
            // Paws
            fill(126, 2, 4, 3, sphinxD)

            // ── TEMPLE COLUMNS ── (x=155..175)
            for cx in stride(from: 155, to: 176, by: 5) {
                fill(cx, 3, 3, 20, colWhite)
                fill(cx, 3, 3, 1, colShadow)   // Base
                fill(cx, 23, 3, 1, colShadow)  // Capital
                fill(cx + 1, 5, 1, 16, colShadow) // Fluting
            }
            // Lintel
            fill(155, 24, 23, 2, colWhite)
            fill(155, 26, 23, 1, colShadow)
            // Hieroglyphics on lintel
            for hx in stride(from: 157, to: 176, by: 3) {
                dot(hx, 25, hieroC)
                dot(hx + 1, 24, hieroC)
            }

            // ── PALM TREES ──
            for (px, ph) in [(140, 16), (185, 14), (10, 12)] {
                for i in 0..<ph { dot(px, 3 + i, palmTrunk) }
                for dx in -3..<4 {
                    let droop = abs(dx) > 1 ? -1 : 0
                    dot(px + dx, 3 + ph + droop, palmLeaf)
                }
            }
        }
    }

    // MARK: Egypt Palm Obelisks — palm trees, obelisks, sphinx hint

    private func renderEgyptPalmObelisks() -> UIImage {
        let w: CGFloat = GK.worldWidth * 2
        let h: CGFloat = 160
        let ps: CGFloat = 4
        let C = UIColor.clear

        let fD = UIColor(red: 0.29, green: 0.48, blue: 0.19, alpha: 0.65) // frond dark
        let fL = UIColor(red: 0.42, green: 0.61, blue: 0.27, alpha: 0.55) // frond light
        let tK = UIColor(red: 0.35, green: 0.23, blue: 0.10, alpha: 0.70) // trunk
        let oS = UIColor(red: 0.48, green: 0.35, blue: 0.19, alpha: 0.70) // obelisk stone
        let oA = UIColor(red: 0.16, green: 0.54, blue: 0.48, alpha: 0.60) // hieroglyph teal

        // Desert Palm (9w × 14h)
        let palm: [[UIColor]] = [
            [C,C,fD,fD,fD,fD,fD,C,C],
            [C,fD,fD,fL,fD,fL,fD,fD,C],
            [fD,fD,fL,C,C,C,fL,fD,fD],
            [C,fD,C,C,C,C,C,fD,C],
            [C,C,C,C,tK,C,C,C,C],
            [C,C,C,C,tK,C,C,C,C],
            [C,C,C,tK,C,C,C,C,C],
            [C,C,C,tK,C,C,C,C,C],
            [C,C,tK,C,C,C,C,C,C],
            [C,C,tK,C,C,C,C,C,C],
            [C,C,tK,C,C,C,C,C,C],
            [C,C,C,tK,C,C,C,C,C],
            [C,C,C,tK,C,C,C,C,C],
            [C,C,C,tK,C,C,C,C,C],
        ]

        // Obelisk (5w × 12h)
        let obelisk: [[UIColor]] = [
            [C,C,oS,C,C],
            [C,C,oS,C,C],
            [C,oS,oS,oS,C],
            [C,oS,oA,oS,C],
            [C,oS,oA,oS,C],
            [oS,oS,oA,oS,oS],
            [oS,oS,oA,oS,oS],
            [oS,oS,oA,oS,oS],
            [oS,oS,oS,oS,oS],
            [oS,oS,oS,oS,oS],
            [oS,oS,oS,oS,oS],
            [oS,oS,oS,oS,oS],
        ]

        // Sphinx silhouette (12w × 6h)
        let sphinx: [[UIColor]] = [
            [C,C,C,oS,oS,oS,oS,C,C,C,C,C],
            [C,C,oS,oS,oS,oS,oS,oS,C,C,C,C],
            [C,oS,oS,oS,oS,oS,oS,oS,oS,C,C,C],
            [oS,oS,oS,oS,oS,oS,oS,oS,oS,oS,oS,C],
            [oS,oS,oS,oS,oS,oS,oS,oS,oS,oS,oS,oS],
            [oS,oS,oS,oS,oS,oS,oS,oS,oS,oS,oS,oS],
        ]

        let positions: [(x: CGFloat, type: Int)] = [
            (30, 0), (110, 1), (200, 0), (280, 2), (370, 0),
            (460, 1), (540, 0), (630, 0), (710, 1), (770, 0),
        ]

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let c = ctx.cgContext
            for pos in positions {
                let template: [[UIColor]]
                switch pos.type {
                case 0: template = palm
                case 1: template = obelisk
                default: template = sphinx
                }
                let tH = template.count
                let tW = template[0].count
                let baseY = h - CGFloat(tH) * ps
                for row in 0..<tH {
                    for col in 0..<tW {
                        let color = template[row][col]
                        guard color != C else { continue }
                        c.setFillColor(color.cgColor)
                        c.fill(CGRect(x: pos.x + CGFloat(col) * ps,
                                      y: baseY + CGFloat(row) * ps,
                                      width: ps, height: ps))
                    }
                }
            }
        }
    }

    // MARK: Egypt Desert Strip — papyrus reeds, pottery, sand ripples

    private func renderEgyptDesertStrip() -> UIImage {
        let w = Int(GK.worldWidth * 2)
        let h = 36
        let ps = 4
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let c = ctx.cgContext
            let reed  = UIColor(red: 0.29, green: 0.48, blue: 0.19, alpha: 0.55)
            let pot   = UIColor(red: 0.65, green: 0.40, blue: 0.20, alpha: 0.60)
            let sand  = UIColor(red: 0.72, green: 0.56, blue: 0.31, alpha: 0.45)

            var x = 0
            while x < w {
                let kind = Int.random(in: 0...2)
                let gap = Int.random(in: 30...50)

                if kind == 0 {
                    // Papyrus reed — thin stem with fan top
                    let rh = Int.random(in: 4...6)
                    let by = h - rh * ps
                    c.setFillColor(reed.cgColor)
                    for row in 1..<rh {
                        c.fill(CGRect(x: x + ps, y: by + row * ps, width: ps, height: ps))
                    }
                    c.fill(CGRect(x: x, y: by, width: ps, height: ps))
                    c.fill(CGRect(x: x + ps, y: by, width: ps, height: ps))
                    c.fill(CGRect(x: x + 2 * ps, y: by, width: ps, height: ps))
                    c.fill(CGRect(x: x + ps * 3, y: by, width: ps, height: ps))
                } else if kind == 1 {
                    // Clay pot
                    let by = h - 4 * ps
                    c.setFillColor(pot.cgColor)
                    c.fill(CGRect(x: x + ps, y: by, width: ps, height: ps))
                    c.fill(CGRect(x: x + 2 * ps, y: by, width: ps, height: ps))
                    c.fill(CGRect(x: x, y: by + ps, width: ps * 4, height: ps))
                    c.fill(CGRect(x: x, y: by + 2 * ps, width: ps * 4, height: ps))
                    c.fill(CGRect(x: x + ps, y: by + 3 * ps, width: ps * 2, height: ps))
                } else {
                    // Sand ripple
                    let rw = Int.random(in: 6...10)
                    let by = h - ps
                    for col in 0..<rw {
                        let yOff = (col % 3 == 1) ? -ps : 0
                        c.setFillColor(sand.cgColor)
                        c.fill(CGRect(x: x + col * ps, y: by + yOff, width: ps, height: ps))
                    }
                }
                x += ps * 6 + gap
            }
        }
    }

    // MARK: - Cave Theme

    // MARK: Cave Formation Hills — stalactites from top, stalagmites from bottom

    private func renderCaveFormationHills() -> UIImage {
        let w: CGFloat = GK.worldWidth * 2
        let h: CGFloat = 300
        let ps: CGFloat = 4
        let gridW = Int(w / ps)
        let gridH = Int(h / ps)

        // Stalagmites from floor
        var floorMap = [Int](repeating: 2, count: gridW)
        let stalagmites: [(center: Int, radius: Int, peak: Int)] = [
            (15, 8, 20), (40, 12, 30), (70, 6, 15), (100, 15, 35),
            (130, 8, 22), (160, 10, 28), (185, 7, 18),
        ]
        for s in stalagmites {
            for x in max(0, s.center - s.radius)..<min(gridW, s.center + s.radius) {
                let dist = abs(x - s.center)
                let nd = CGFloat(dist) / CGFloat(s.radius)
                floorMap[x] = max(floorMap[x], Int(CGFloat(s.peak) * (1.0 - nd * nd)))
            }
        }

        // Stalactites from ceiling
        var ceilMap = [Int](repeating: 2, count: gridW)
        let stalactites: [(center: Int, radius: Int, peak: Int)] = [
            (10, 6, 18), (30, 10, 25), (55, 5, 14), (80, 12, 30),
            (110, 7, 20), (140, 9, 26), (170, 6, 16), (195, 8, 22),
        ]
        for s in stalactites {
            for x in max(0, s.center - s.radius)..<min(gridW, s.center + s.radius) {
                let dist = abs(x - s.center)
                let nd = CGFloat(dist) / CGFloat(s.radius)
                ceilMap[x] = max(ceilMap[x], Int(CGFloat(s.peak) * (1.0 - nd * nd)))
            }
        }

        let rockDark  = UIColor(red: 0.15, green: 0.13, blue: 0.12, alpha: 0.90)
        let rockMid   = UIColor(red: 0.25, green: 0.22, blue: 0.20, alpha: 0.85)
        let rockLight = UIColor(red: 0.35, green: 0.30, blue: 0.28, alpha: 0.80)
        let rockWet   = UIColor(red: 0.20, green: 0.25, blue: 0.30, alpha: 0.75)
        // Crystal colors
        let crystPurpD = UIColor(red: 0.40, green: 0.10, blue: 0.60, alpha: 0.90)
        let crystPurpM = UIColor(red: 0.55, green: 0.20, blue: 0.80, alpha: 0.85)
        let crystPurpL = UIColor(red: 0.70, green: 0.40, blue: 0.95, alpha: 0.80)
        let crystCyanD = UIColor(red: 0.10, green: 0.45, blue: 0.65, alpha: 0.88)
        let crystCyanM = UIColor(red: 0.20, green: 0.60, blue: 0.80, alpha: 0.85)
        let crystCyanL = UIColor(red: 0.40, green: 0.80, blue: 0.95, alpha: 0.80)
        let crystGlow  = UIColor(red: 0.50, green: 0.30, blue: 0.80, alpha: 0.12)
        let cyanGlow   = UIColor(red: 0.20, green: 0.60, blue: 0.85, alpha: 0.12)
        // Mushroom colors
        let mushStem   = UIColor(red: 0.55, green: 0.50, blue: 0.45, alpha: 0.75)
        let mushCapB   = UIColor(red: 0.15, green: 0.45, blue: 0.55, alpha: 0.80)
        let mushCapG   = UIColor(red: 0.20, green: 0.70, blue: 0.50, alpha: 0.75)
        let mushGlow   = UIColor(red: 0.20, green: 0.65, blue: 0.55, alpha: 0.15)
        // Underground pool
        let poolDark   = UIColor(red: 0.08, green: 0.18, blue: 0.30, alpha: 0.70)
        let poolLight  = UIColor(red: 0.15, green: 0.30, blue: 0.45, alpha: 0.55)
        let poolShine  = UIColor(red: 0.30, green: 0.50, blue: 0.65, alpha: 0.40)
        // Bats
        let batC       = UIColor(red: 0.12, green: 0.10, blue: 0.10, alpha: 0.70)

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let c = ctx.cgContext

            func fill(_ fx: Int, _ fy: Int, _ fw: Int, _ fh: Int, _ color: UIColor) {
                guard fw > 0 && fh > 0 else { return }
                c.setFillColor(color.cgColor)
                c.fill(CGRect(x: CGFloat(fx) * ps, y: h - CGFloat(fy + fh) * ps,
                              width: CGFloat(fw) * ps, height: CGFloat(fh) * ps))
            }
            func dot(_ dx: Int, _ dy: Int, _ color: UIColor) { fill(dx, dy, 1, 1, color) }

            // ── STALACTITES FROM CEILING ──
            for x in 0..<gridW {
                let cH = ceilMap[x]
                guard cH > 0 else { continue }
                for y in 0..<cH {
                    let screenY = gridH - 1 - y  // Flip: top of grid
                    let ratio = CGFloat(y) / max(1, CGFloat(cH))
                    let color: UIColor
                    if ratio > 0.8 { color = rockLight }
                    else if ratio > 0.5 { color = rockMid }
                    else if y % 3 == 0 { color = rockWet }
                    else { color = rockDark }
                    dot(x, screenY, color)
                }
            }

            // ── STALAGMITES FROM FLOOR ──
            for x in 0..<gridW {
                let fH = floorMap[x]
                guard fH > 0 else { continue }
                for y in 0..<fH {
                    let ratio = CGFloat(y) / max(1, CGFloat(fH))
                    let color: UIColor
                    if y == fH - 1 { color = rockLight }
                    else if ratio > 0.7 { color = rockMid }
                    else if y % 4 == 0 { color = rockWet }
                    else { color = rockDark }
                    dot(x, y, color)
                }
            }

            // ── CRYSTAL CLUSTER (PURPLE) ── (x=35..50, growing from floor)
            func drawCrystal(_ bx: Int, _ by: Int, _ cw: Int, _ ch: Int,
                             _ dark: UIColor, _ mid: UIColor, _ light: UIColor, _ glow: UIColor) {
                // Glow aura
                for gy in -2..<(ch + 2) {
                    for gx in -2..<(cw + 2) {
                        dot(bx + gx, by + gy, glow)
                    }
                }
                // Crystal body (tapered)
                for y in 0..<ch {
                    let taper = max(1, cw - y * cw / (ch * 2))
                    let offset = (cw - taper) / 2
                    for x in 0..<taper {
                        let ratio = CGFloat(y) / CGFloat(ch)
                        let color = ratio > 0.7 ? light : (ratio > 0.3 ? mid : dark)
                        dot(bx + offset + x, by + y, color)
                    }
                }
                // Bright tip
                dot(bx + cw / 2, by + ch - 1, light)
                dot(bx + cw / 2, by + ch, light)
            }

            // Purple cluster (3 crystals, different angles)
            drawCrystal(36, 8, 4, 18, crystPurpD, crystPurpM, crystPurpL, crystGlow)
            drawCrystal(41, 5, 3, 14, crystPurpD, crystPurpM, crystPurpL, crystGlow)
            drawCrystal(45, 10, 5, 20, crystPurpD, crystPurpM, crystPurpL, crystGlow)

            // Cyan cluster
            drawCrystal(140, 6, 3, 15, crystCyanD, crystCyanM, crystCyanL, cyanGlow)
            drawCrystal(144, 3, 4, 12, crystCyanD, crystCyanM, crystCyanL, cyanGlow)
            drawCrystal(149, 8, 3, 16, crystCyanD, crystCyanM, crystCyanL, cyanGlow)

            // Small crystals scattered
            drawCrystal(15, 12, 2, 6, crystPurpD, crystPurpM, crystPurpL, crystGlow)
            drawCrystal(170, 5, 2, 8, crystCyanD, crystCyanM, crystCyanL, cyanGlow)
            drawCrystal(88, 4, 2, 7, crystPurpD, crystPurpM, crystPurpL, crystGlow)

            // ── BIOLUMINESCENT MUSHROOMS ──
            func drawMushroom(_ bx: Int, _ by: Int, _ sh: Int, _ capW: Int,
                              _ capColor: UIColor) {
                // Glow aura
                for gy in -1..<(sh + capW / 2 + 2) {
                    for gx in -(capW / 2 + 1)..<(capW / 2 + 2) {
                        dot(bx + gx, by + gy, mushGlow)
                    }
                }
                // Stem
                fill(bx, by, 1, sh, mushStem)
                // Cap (dome)
                for cy in 0..<(capW / 2 + 1) {
                    let cw = capW - cy
                    fill(bx - cw / 2, by + sh + cy, cw, 1, capColor)
                }
                // Spots
                if capW >= 4 {
                    dot(bx - 1, by + sh + 1,
                        UIColor(red: 0.80, green: 0.95, blue: 0.85, alpha: 0.70))
                    dot(bx + 1, by + sh + 1,
                        UIColor(red: 0.80, green: 0.95, blue: 0.85, alpha: 0.70))
                }
            }

            drawMushroom(60, 3, 5, 6, mushCapB)
            drawMushroom(65, 2, 3, 4, mushCapG)
            drawMushroom(115, 4, 4, 5, mushCapB)
            drawMushroom(120, 2, 3, 4, mushCapG)
            drawMushroom(175, 3, 4, 5, mushCapG)

            // ── UNDERGROUND POOL / RIVER ── (x=75..125, y=0..3)
            fill(75, 0, 50, 3, poolDark)
            fill(78, 1, 44, 1, poolLight)
            // Shimmer reflections
            for sx in stride(from: 80, to: 120, by: 8) {
                fill(sx, 2, 3, 1, poolShine)
            }

            // ── BATS ── (near ceiling)
            func drawBat(_ bx: Int, _ by: Int) {
                dot(bx, by, batC)
                dot(bx - 1, by + 1, batC); dot(bx + 1, by + 1, batC)
                dot(bx - 2, by, batC); dot(bx + 2, by, batC)
            }
            drawBat(25, 68); drawBat(55, 70); drawBat(90, 66)
            drawBat(125, 69); drawBat(165, 67); drawBat(190, 71)

            // ── DRIPPING WATER DROPS ──
            let dropC = UIColor(red: 0.30, green: 0.45, blue: 0.55, alpha: 0.50)
            for dx in [28, 78, 138, 192] {
                let tipY = gridH - 1 - ceilMap[min(dx, gridW - 1)]
                dot(dx, tipY - 1, dropC)
                dot(dx, tipY - 2, dropC)
            }
        }
    }

    // MARK: Cave Crystal Pillars — crystal formations with glowing accents

    private func renderCaveCrystalPillars() -> UIImage {
        let w: CGFloat = GK.worldWidth * 2
        let h: CGFloat = 160
        let ps: CGFloat = 4
        let C = UIColor.clear

        let rD = UIColor(red: 0.10, green: 0.08, blue: 0.13, alpha: 0.65) // rock dark
        let rM = UIColor(red: 0.18, green: 0.16, blue: 0.22, alpha: 0.60) // rock mid
        let rL = UIColor(red: 0.29, green: 0.25, blue: 0.35, alpha: 0.50) // rock light
        let cC = UIColor(red: 0.25, green: 0.82, blue: 0.88, alpha: 0.75) // crystal cyan
        let cP = UIColor(red: 0.88, green: 0.25, blue: 0.75, alpha: 0.75) // crystal pink
        let cA = UIColor(red: 0.88, green: 0.63, blue: 0.13, alpha: 0.75) // crystal amber
        let bT = UIColor(red: 0.08, green: 0.06, blue: 0.10, alpha: 0.70) // bat

        // Crystal Pillar (5w × 14h)
        let pillar: [[UIColor]] = [
            [C,rD,rM,rD,C],
            [rD,rM,rL,rM,rD],
            [rD,rL,cC,rL,rD],
            [rD,rM,cC,rM,rD],
            [rD,rL,rL,rL,rD],
            [C,rD,rM,rD,C],
            [C,rD,rM,rD,C],
            [C,rD,rM,rD,C],
            [C,rD,rL,rD,C],
            [C,rD,cP,rD,C],
            [C,rD,rM,rD,C],
            [C,rD,rM,rD,C],
            [C,rD,rM,rD,C],
            [C,rD,rM,rD,C],
        ]

        // Crystal Cluster (5w × 5h)
        let cluster: [[UIColor]] = [
            [C,C,cA,C,C],
            [C,cA,cC,cA,C],
            [cC,cA,C,cC,cP],
            [C,cP,cA,cP,C],
            [C,C,cC,C,C],
        ]

        // Stalactite hanging (5w × 8h) — top-anchored
        let stalactite: [[UIColor]] = [
            [rD,rM,rD,rM,rD],
            [C,rM,rD,rM,C],
            [C,rM,rL,rM,C],
            [C,C,rM,C,C],
            [C,C,rM,C,C],
            [C,C,rL,C,C],
            [C,C,rD,C,C],
            [C,C,C,C,C],
        ]

        // Bat cluster (5w × 3h)
        let bat: [[UIColor]] = [
            [bT,C,C,C,bT],
            [C,bT,bT,bT,C],
            [C,C,bT,C,C],
        ]

        // Bottom-anchored items
        let bottomPositions: [(x: CGFloat, type: Int)] = [
            (40, 0), (120, 1), (200, 0), (310, 1), (400, 0),
            (500, 1), (580, 0), (680, 1), (760, 0),
        ]
        // Top-anchored items
        let topPositions: [(x: CGFloat, type: Int)] = [
            (80, 2), (250, 3), (420, 2), (560, 3), (720, 2),
        ]

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let c = ctx.cgContext

            // Bottom-anchored
            for pos in bottomPositions {
                let template = pos.type == 0 ? pillar : cluster
                let tH = template.count
                let tW = template[0].count
                let baseY = h - CGFloat(tH) * ps
                for row in 0..<tH {
                    for col in 0..<tW {
                        let color = template[row][col]
                        guard color != C else { continue }
                        c.setFillColor(color.cgColor)
                        c.fill(CGRect(x: pos.x + CGFloat(col) * ps,
                                      y: baseY + CGFloat(row) * ps,
                                      width: ps, height: ps))
                    }
                }
            }

            // Top-anchored
            for pos in topPositions {
                let template = pos.type == 2 ? stalactite : bat
                let tH = template.count
                let tW = template[0].count
                for row in 0..<tH {
                    for col in 0..<tW {
                        let color = template[row][col]
                        guard color != C else { continue }
                        c.setFillColor(color.cgColor)
                        c.fill(CGRect(x: pos.x + CGFloat(col) * ps,
                                      y: CGFloat(row) * ps,
                                      width: ps, height: ps))
                    }
                }
            }
        }
    }

    // MARK: Cave Moss Strip — crystals, cave moss, water drips

    private func renderCaveMossStrip() -> UIImage {
        let w = Int(GK.worldWidth * 2)
        let h = 36
        let ps = 4
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let c = ctx.cgContext
            let crystCyan = UIColor(red: 0.25, green: 0.82, blue: 0.88, alpha: 0.70)
            let crystPink = UIColor(red: 0.88, green: 0.25, blue: 0.75, alpha: 0.70)
            let caveMoss  = UIColor(red: 0.16, green: 0.29, blue: 0.16, alpha: 0.55)
            let caveRock  = UIColor(red: 0.18, green: 0.16, blue: 0.22, alpha: 0.60)

            var x = 0
            while x < w {
                let kind = Int.random(in: 0...2)
                let gap = Int.random(in: 22...38)

                if kind == 0 {
                    // Crystal shard — thin triangle pointing up
                    let sh = Int.random(in: 3...5)
                    let by = h - sh * ps
                    let color = Bool.random() ? crystCyan : crystPink
                    c.setFillColor(color.cgColor)
                    for row in 0..<sh {
                        c.fill(CGRect(x: x + ps, y: by + row * ps, width: ps, height: ps))
                    }
                    // Glow pixel at base
                    c.setFillColor(color.withAlphaComponent(0.35).cgColor)
                    c.fill(CGRect(x: x, y: h - ps, width: ps, height: ps))
                    c.fill(CGRect(x: x + 2 * ps, y: h - ps, width: ps, height: ps))
                } else if kind == 1 {
                    // Cave moss patch
                    let mw = Int.random(in: 4...6)
                    let by = h - ps
                    c.setFillColor(caveMoss.cgColor)
                    for col in 0..<mw {
                        c.fill(CGRect(x: x + col * ps, y: by, width: ps, height: ps))
                    }
                } else {
                    // Cave rocks
                    let rw = Int.random(in: 2...4)
                    let by = h - 2 * ps
                    c.setFillColor(caveRock.cgColor)
                    for col in 0..<rw {
                        c.fill(CGRect(x: x + col * ps, y: by, width: ps, height: ps))
                        c.fill(CGRect(x: x + col * ps, y: by + ps, width: ps, height: ps))
                    }
                }
                x += ps * 5 + gap
            }
        }
    }

    // MARK: - Mountain Theme

    // MARK: Mountain Peak Hills — snow-capped mountain range

    private func renderMountainPeakHills() -> UIImage {
        let w: CGFloat = GK.worldWidth * 2
        let h: CGFloat = 300
        let ps: CGFloat = 4
        let gridW = Int(w / ps)

        var heightMap = [Int](repeating: 2, count: gridW)
        let peaks: [(center: Int, radius: Int, peak: Int)] = [
            (20, 25, 40), (55, 18, 30), (85, 35, 55), (115, 15, 22),
            (145, 28, 48), (175, 20, 35), (195, 15, 25),
        ]
        for p in peaks {
            for x in max(0, p.center - p.radius)..<min(gridW, p.center + p.radius) {
                let dist = abs(x - p.center)
                let nd = CGFloat(dist) / CGFloat(p.radius)
                heightMap[x] = max(heightMap[x], Int(CGFloat(p.peak) * (1.0 - nd * nd)))
            }
        }

        let rockD     = UIColor(red: 0.30, green: 0.28, blue: 0.25, alpha: 0.85)
        let rockM     = UIColor(red: 0.40, green: 0.38, blue: 0.35, alpha: 0.80)
        let rockL     = UIColor(red: 0.50, green: 0.48, blue: 0.45, alpha: 0.75)
        let snowC     = UIColor(red: 0.95, green: 0.97, blue: 1.0, alpha: 0.88)
        let snowM     = UIColor(red: 0.85, green: 0.88, blue: 0.92, alpha: 0.80)
        // Cabin
        let cabinBrn  = UIColor(red: 0.38, green: 0.22, blue: 0.10, alpha: 0.82)
        let cabinLt   = UIColor(red: 0.50, green: 0.35, blue: 0.18, alpha: 0.78)
        let cabinRoof = UIColor(red: 0.28, green: 0.16, blue: 0.08, alpha: 0.85)
        let windowW   = UIColor(red: 0.90, green: 0.78, blue: 0.40, alpha: 0.75)
        let chimneyC  = UIColor(red: 0.35, green: 0.30, blue: 0.28, alpha: 0.80)
        let smokeC    = UIColor(red: 0.55, green: 0.52, blue: 0.52, alpha: 0.22)
        // Waterfall
        let waterW    = UIColor(red: 0.75, green: 0.88, blue: 0.95, alpha: 0.65)
        let waterD    = UIColor(red: 0.40, green: 0.60, blue: 0.75, alpha: 0.55)
        let mist      = UIColor(red: 0.80, green: 0.90, blue: 0.95, alpha: 0.20)
        // Pine tree
        let pineD     = UIColor(red: 0.08, green: 0.22, blue: 0.10, alpha: 0.78)
        let pineM     = UIColor(red: 0.12, green: 0.32, blue: 0.15, alpha: 0.72)
        // Eagle
        let eagleC    = UIColor(red: 0.20, green: 0.15, blue: 0.12, alpha: 0.55)
        // Lake
        let lakeC     = UIColor(red: 0.25, green: 0.50, blue: 0.65, alpha: 0.50)
        let lakeL     = UIColor(red: 0.40, green: 0.62, blue: 0.75, alpha: 0.38)

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let c = ctx.cgContext

            func fill(_ fx: Int, _ fy: Int, _ fw: Int, _ fh: Int, _ color: UIColor) {
                guard fw > 0 && fh > 0 else { return }
                c.setFillColor(color.cgColor)
                c.fill(CGRect(x: CGFloat(fx) * ps, y: h - CGFloat(fy + fh) * ps,
                              width: CGFloat(fw) * ps, height: CGFloat(fh) * ps))
            }
            func dot(_ dx: Int, _ dy: Int, _ color: UIColor) { fill(dx, dy, 1, 1, color) }

            // Mountain terrain
            for x in 0..<gridW {
                let mH = heightMap[x]
                for y in 0..<mH {
                    let yPos = h - CGFloat(y + 1) * ps
                    let ratio = CGFloat(y) / max(1, CGFloat(mH))
                    let color: UIColor
                    if ratio > 0.80 { color = snowC }
                    else if ratio > 0.65 { color = snowM }
                    else if ratio > 0.40 { color = rockL }
                    else if ratio > 0.20 { color = rockM }
                    else { color = rockD }
                    c.setFillColor(color.cgColor)
                    c.fill(CGRect(x: CGFloat(x) * ps, y: yPos, width: ps, height: ps))
                }
            }

            // ── WATERFALL ── (at x=88, flowing from peak)
            let wfx = 88, wfTop = 40
            for y in 5..<wfTop {
                let sway = Int(sin(CGFloat(y) * 0.4) * 1)
                fill(wfx + sway, y, 2, 1, waterW)
                if y % 3 == 0 { dot(wfx + sway - 1, y, waterD) }
            }
            // Splash at base
            fill(wfx - 2, 4, 6, 2, mist)
            fill(wfx - 1, 3, 4, 1, mist)

            // ── MOUNTAIN LAKE ── (x=78..100, y=2..5)
            fill(78, 2, 22, 3, lakeC)
            for rx in stride(from: 80, to: 98, by: 5) { dot(rx, 3, lakeL) }

            // ── LOG CABIN ── (x=35, y=3)
            let cbx = 35, cby = 3
            fill(cbx, cby, 14, 10, cabinBrn)
            fill(cbx + 1, cby + 1, 12, 8, cabinLt)
            // Log lines
            for ly in stride(from: cby + 2, to: cby + 9, by: 2) {
                fill(cbx, ly, 14, 1, cabinBrn)
            }
            // Roof
            for dx in 0..<16 { let rh = max(0, 4 - abs(dx - 8) / 2); if rh > 0 { fill(cbx - 1 + dx, cby + 10, 1, rh, cabinRoof) } }
            // Window
            fill(cbx + 3, cby + 5, 3, 3, windowW)
            fill(cbx + 4, cby + 5, 1, 3, cabinBrn) // Cross
            // Door
            fill(cbx + 9, cby, 3, 5, cabinRoof)
            dot(cbx + 11, cby + 3, windowW) // Handle
            // Chimney & smoke
            fill(cbx + 10, cby + 12, 2, 4, chimneyC)
            for i in 0..<4 { dot(cbx + 11 + Int(sin(CGFloat(i)) * 1), cby + 16 + i, smokeC) }

            // ── PINE TREES ──
            func drawPine(_ bx: Int, _ by: Int, _ ph: Int) {
                fill(bx + 2, by, 1, 3, pineD) // Trunk
                for row in 0..<ph {
                    let cw = min(1 + row, 5)
                    fill(bx + 2 - cw / 2, by + 3 + row, cw, 1, row % 2 == 0 ? pineD : pineM)
                }
            }
            drawPine(15, 4, 8); drawPine(55, 3, 10); drawPine(110, 5, 7)
            drawPine(130, 4, 9); drawPine(165, 3, 8); drawPine(185, 5, 6)

            // ── EAGLE ──
            for (ex, ey) in [(50, 50), (140, 55)] {
                dot(ex - 2, ey, eagleC); dot(ex - 1, ey + 1, eagleC)
                dot(ex, ey, eagleC); dot(ex + 1, ey + 1, eagleC); dot(ex + 2, ey, eagleC)
            }
        }
    }

    // MARK: Mountain Pine Forest — pine trees, rocky outcrops, eagle

    private func renderMountainPineForest() -> UIImage {
        let w: CGFloat = GK.worldWidth * 2
        let h: CGFloat = 160
        let ps: CGFloat = 4
        let C = UIColor.clear

        let pD = UIColor(red: 0.10, green: 0.23, blue: 0.10, alpha: 0.70) // pine dark
        let pM = UIColor(red: 0.16, green: 0.35, blue: 0.16, alpha: 0.65) // pine mid
        let pL = UIColor(red: 0.23, green: 0.48, blue: 0.23, alpha: 0.55) // pine light
        let pS = UIColor(red: 0.82, green: 0.88, blue: 0.82, alpha: 0.50) // pine snow
        let tK = UIColor(red: 0.30, green: 0.20, blue: 0.12, alpha: 0.70) // trunk
        let rK = UIColor(red: 0.35, green: 0.42, blue: 0.48, alpha: 0.60) // rock
        let rL = UIColor(red: 0.48, green: 0.54, blue: 0.60, alpha: 0.50) // rock light
        let eG = UIColor(red: 0.23, green: 0.16, blue: 0.10, alpha: 0.65) // eagle

        // Tall Pine (7w × 14h)
        let tallPine: [[UIColor]] = [
            [C,C,C,pS,C,C,C],
            [C,C,pD,pM,pD,C,C],
            [C,C,pM,pL,pM,C,C],
            [C,pD,pM,pL,pM,pD,C],
            [C,pM,pL,pM,pL,pM,C],
            [pD,pM,pM,pL,pM,pM,pD],
            [pM,pM,pL,pM,pL,pM,pM],
            [C,pM,pM,pM,pM,pM,C],
            [C,C,pM,pM,pM,C,C],
            [C,C,C,tK,C,C,C],
            [C,C,C,tK,C,C,C],
            [C,C,C,tK,C,C,C],
            [C,C,C,tK,C,C,C],
            [C,C,C,tK,C,C,C],
        ]

        // Short Pine (5w × 8h)
        let shortPine: [[UIColor]] = [
            [C,C,pS,C,C],
            [C,pD,pM,pD,C],
            [C,pM,pL,pM,C],
            [pM,pM,pL,pM,pM],
            [C,pM,pM,pM,C],
            [C,C,tK,C,C],
            [C,C,tK,C,C],
            [C,C,tK,C,C],
        ]

        // Rocky Outcrop (9w × 5h)
        let outcrop: [[UIColor]] = [
            [C,C,C,rK,rK,rK,C,C,C],
            [C,C,rK,rL,rK,rK,rK,C,C],
            [C,rK,rK,rK,rL,rK,rK,rK,C],
            [rK,rK,rK,rK,rK,rL,rK,rK,rK],
            [rK,rK,rL,rK,rK,rK,rK,rK,rK],
        ]

        // Eagle (7w × 3h) — top-anchored
        let eagle: [[UIColor]] = [
            [eG,C,C,C,C,C,eG],
            [C,eG,C,eG,C,eG,C],
            [C,C,eG,eG,eG,C,C],
        ]

        let bottomPositions: [(x: CGFloat, type: Int)] = [
            (15, 0), (70, 1), (120, 0), (180, 2), (240, 1), (300, 0),
            (360, 1), (420, 0), (480, 2), (540, 1), (600, 0), (660, 1),
            (720, 0), (770, 1),
        ]
        let topPositions: [(x: CGFloat, type: Int)] = [
            (200, 3), (550, 3),
        ]

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let c = ctx.cgContext

            for pos in bottomPositions {
                let template: [[UIColor]]
                switch pos.type {
                case 0: template = tallPine
                case 1: template = shortPine
                default: template = outcrop
                }
                let tH = template.count
                let tW = template[0].count
                let baseY = h - CGFloat(tH) * ps
                for row in 0..<tH {
                    for col in 0..<tW {
                        let color = template[row][col]
                        guard color != C else { continue }
                        c.setFillColor(color.cgColor)
                        c.fill(CGRect(x: pos.x + CGFloat(col) * ps,
                                      y: baseY + CGFloat(row) * ps,
                                      width: ps, height: ps))
                    }
                }
            }

            for pos in topPositions {
                let tH = eagle.count
                let tW = eagle[0].count
                for row in 0..<tH {
                    for col in 0..<tW {
                        let color = eagle[row][col]
                        guard color != C else { continue }
                        c.setFillColor(color.cgColor)
                        c.fill(CGRect(x: pos.x + CGFloat(col) * ps,
                                      y: CGFloat(row) * ps,
                                      width: ps, height: ps))
                    }
                }
            }
        }
    }

    // MARK: Mountain Meadow Strip — wildflowers, alpine bushes, pebbles

    private func renderMountainMeadowStrip() -> UIImage {
        let w = Int(GK.worldWidth * 2)
        let h = 36
        let ps = 4
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let c = ctx.cgContext
            let grass   = UIColor(red: 0.35, green: 0.54, blue: 0.25, alpha: 0.60)
            let flwrPrp = UIColor(red: 0.50, green: 0.25, blue: 0.63, alpha: 0.55)
            let flwrYlw = UIColor(red: 0.88, green: 0.75, blue: 0.19, alpha: 0.55)
            let pebble  = UIColor(red: 0.42, green: 0.48, blue: 0.55, alpha: 0.55)

            var x = 0
            while x < w {
                let kind = Int.random(in: 0...2)
                let gap = Int.random(in: 16...28)

                if kind == 0 {
                    // Alpine grass tuft
                    let gw = Int.random(in: 3...5)
                    let gh = Int.random(in: 2...4)
                    let by = h - gh * ps
                    for row in 0..<gh {
                        for col in 0..<gw {
                            if row == 0 && (col % 2 == 0) {
                                c.setFillColor(grass.cgColor)
                                c.fill(CGRect(x: x + col * ps, y: by, width: ps, height: ps))
                            } else if row > 0 {
                                c.setFillColor(grass.cgColor)
                                c.fill(CGRect(x: x + col * ps, y: by + row * ps, width: ps, height: ps))
                            }
                        }
                    }
                } else if kind == 1 {
                    // Wildflower
                    let by = h - 3 * ps
                    c.setFillColor(grass.cgColor)
                    c.fill(CGRect(x: x + ps, y: by + 2 * ps, width: ps, height: ps))
                    c.fill(CGRect(x: x + ps, y: by + ps, width: ps, height: ps))
                    let fColor = Bool.random() ? flwrPrp : flwrYlw
                    c.setFillColor(fColor.cgColor)
                    c.fill(CGRect(x: x, y: by, width: ps, height: ps))
                    c.fill(CGRect(x: x + ps, y: by, width: ps, height: ps))
                    c.fill(CGRect(x: x + 2 * ps, y: by, width: ps, height: ps))
                } else {
                    // Mountain pebbles
                    let pw = Int.random(in: 2...4)
                    let by = h - ps
                    for col in 0..<pw {
                        c.setFillColor(pebble.cgColor)
                        c.fill(CGRect(x: x + col * ps, y: by, width: ps, height: ps))
                    }
                }
                x += ps * 5 + gap
            }
        }
    }

    // MARK: Lagoon Beach Strip — seashells, starfish, foam line

    private func renderLagoonBeachStrip() -> UIImage {
        let w = Int(GK.worldWidth * 2)
        let h = 40
        let ps = 4
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let c = ctx.cgContext
            // Foam line
            var fx = 0
            while fx < w {
                let foamW = Int.random(in: 2...5) * ps
                c.setFillColor(UIColor(red: 0.90, green: 0.95, blue: 0.98, alpha: 0.6).cgColor)
                c.fill(CGRect(x: fx, y: h - ps * 2, width: foamW, height: ps))
                fx += foamW + Int.random(in: 3...8) * ps
            }
            // Seashells
            let shell1 = UIColor(red: 0.92, green: 0.82, blue: 0.68, alpha: 0.55)
            let shell2 = UIColor(red: 0.88, green: 0.72, blue: 0.60, alpha: 0.50)
            var sx = Int.random(in: 3...8) * ps
            while sx < w {
                c.setFillColor(sx % (ps * 10) < ps * 5 ? shell1.cgColor : shell2.cgColor)
                c.fill(CGRect(x: sx, y: h - ps * 3, width: ps, height: ps))
                c.fill(CGRect(x: sx + ps, y: h - ps * 3, width: ps, height: ps))
                sx += Int.random(in: 10...18) * ps
            }
            // Starfish
            let star = UIColor(red: 0.90, green: 0.50, blue: 0.30, alpha: 0.50)
            c.setFillColor(star.cgColor)
            c.fill(CGRect(x: w / 3, y: h - ps * 4, width: ps, height: ps * 3))
            c.fill(CGRect(x: w / 3 - ps, y: h - ps * 3, width: ps * 3, height: ps))
        }
    }

    // MARK: Los Angeles Street Strip — palm fronds, litter, sidewalk cracks

    private func renderLosAngelesStreetStrip() -> UIImage {
        let w = Int(GK.worldWidth * 2)
        let h = 40
        let ps = 4
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let c = ctx.cgContext
            // Road markings
            let marking = UIColor(red: 0.85, green: 0.75, blue: 0.45, alpha: 0.30)
            c.setFillColor(marking.cgColor)
            var mx = ps * 4
            while mx < w {
                c.fill(CGRect(x: mx, y: h / 2, width: ps * 3, height: ps))
                mx += ps * 12
            }
            // Scattered palm fronds
            let frond = UIColor(red: 0.30, green: 0.48, blue: 0.22, alpha: 0.35)
            c.setFillColor(frond.cgColor)
            var px = Int.random(in: 5...12) * ps
            while px < w {
                c.fill(CGRect(x: px, y: h - ps * 3, width: ps * 4, height: ps))
                c.fill(CGRect(x: px + ps, y: h - ps * 2, width: ps * 2, height: ps))
                px += Int.random(in: 15...25) * ps
            }
        }
    }

    // MARK: London Pavement Strip — cobblestone hints, puddle reflections, leaves

    private func renderLondonPavementStrip() -> UIImage {
        let w = Int(GK.worldWidth * 2)
        let h = 40
        let ps = 4
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let c = ctx.cgContext
            // Cobblestone grid lines
            let cobble = UIColor(red: 0.35, green: 0.34, blue: 0.33, alpha: 0.30)
            c.setFillColor(cobble.cgColor)
            var gx = 0
            while gx < w {
                c.fill(CGRect(x: gx, y: 0, width: 1, height: h))
                gx += ps * 4
            }
            var gy = 0
            while gy < h {
                c.fill(CGRect(x: 0, y: gy, width: w, height: 1))
                gy += ps * 3
            }
            // Rain puddles (small reflective patches)
            let puddle = UIColor(red: 0.40, green: 0.45, blue: 0.55, alpha: 0.30)
            var pdx = Int.random(in: 5...10) * ps
            while pdx < w {
                c.setFillColor(puddle.cgColor)
                let pw = Int.random(in: 3...6) * ps
                c.fill(CGRect(x: pdx, y: h - ps * 2, width: pw, height: ps))
                pdx += Int.random(in: 12...22) * ps
            }
            // Fallen leaves (autumn)
            let leafColors = [
                UIColor(red: 0.70, green: 0.40, blue: 0.15, alpha: 0.40),
                UIColor(red: 0.65, green: 0.30, blue: 0.10, alpha: 0.35),
                UIColor(red: 0.80, green: 0.55, blue: 0.20, alpha: 0.35),
            ]
            var lx = Int.random(in: 3...8) * ps
            var li = 0
            while lx < w {
                c.setFillColor(leafColors[li % leafColors.count].cgColor)
                c.fill(CGRect(x: lx, y: h - ps * 3, width: ps, height: ps))
                lx += Int.random(in: 8...16) * ps
                li += 1
            }
        }
    }

    // MARK: - Themed Ground Rendering
    //
    // Each theme gets a unique ground tile instead of the default green grass + tan dirt.

    private func renderThemedGround(theme: BackgroundTheme) -> UIImage {
        switch theme {
        case .day:          return renderGround()
        case .sunset:       return renderSunsetGround()
        case .night:        return renderNightGround()
        case .neonCity:     return renderNeonCityGround()
        case .pixelTokyo:   return renderTokyoGround()
        case .underwater:   return renderUnderwaterGround()
        case .volcano:      return renderVolcanoGround()
        case .arctic:       return renderArcticGround()
        case .western:      return renderWesternGround()
        case .jungle:       return renderJungleGround()
        case .egypt:        return renderEgyptGround()
        case .cave:         return renderCaveGround()
        case .mountain:     return renderMountainGround()
        case .space:        return renderSpaceGround()
        case .lagoon:       return renderLagoonGround()
        case .losAngeles:   return renderLosAngelesGround()
        case .london:       return renderLondonGround()
        }
    }

    // MARK: Sunset Ground — warm amber dirt with golden-hour grass

    private func renderSunsetGround() -> UIImage {
        let w: CGFloat = GK.worldWidth * 2
        let h: CGFloat = GK.groundHeight
        let ps: CGFloat = 4
        let size = CGSize(width: w, height: h)

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let c = ctx.cgContext

            // Warm amber earth base
            c.setFillColor(UIColor(red: 0.62, green: 0.45, blue: 0.28, alpha: 1).cgColor)
            c.fill(CGRect(origin: .zero, size: size))

            // Diagonal pixel dirt stripes
            let stripe = UIColor(red: 0.55, green: 0.38, blue: 0.22, alpha: 1)
            var sx: CGFloat = 0
            while sx < w {
                c.setFillColor(stripe.cgColor)
                for i in 0..<Int(h / ps) {
                    let px = sx + CGFloat(i) * ps
                    let py = h - CGFloat(i + 1) * ps
                    if px < w && py >= 22 { c.fill(CGRect(x: px, y: py, width: ps, height: ps)) }
                }
                sx += ps * 4
            }

            // Golden grass top
            let grassH: CGFloat = 22
            c.setFillColor(UIColor(red: 0.65, green: 0.55, blue: 0.20, alpha: 1).cgColor)
            c.fill(CGRect(x: 0, y: 0, width: w, height: grassH))

            // Dark grass line
            c.setFillColor(UIColor(red: 0.50, green: 0.38, blue: 0.14, alpha: 1).cgColor)
            c.fill(CGRect(x: 0, y: 0, width: w, height: ps))

            // Amber tufts
            let tufts = UIColor(red: 0.72, green: 0.58, blue: 0.22, alpha: 1)
            var tx: CGFloat = 0
            while tx < w {
                c.setFillColor(tufts.cgColor)
                let tw = Int.random(in: 1...3)
                for t in 0..<tw { c.fill(CGRect(x: tx + CGFloat(t) * ps, y: grassH, width: ps, height: ps)) }
                c.fill(CGRect(x: tx + CGFloat(tw / 2) * ps, y: grassH + ps, width: ps, height: ps))
                tx += CGFloat(Int.random(in: 3...6)) * ps
            }

            // Warm-toned flowers
            let flowerColors: [UIColor] = [
                UIColor(red: 0.95, green: 0.65, blue: 0.20, alpha: 1),
                UIColor(red: 0.90, green: 0.40, blue: 0.25, alpha: 1),
                UIColor(red: 0.95, green: 0.82, blue: 0.40, alpha: 1),
            ]
            var fx: CGFloat = CGFloat.random(in: 5...10) * ps
            while fx < w {
                c.setFillColor(flowerColors[Int.random(in: 0..<flowerColors.count)].cgColor)
                let fy = CGFloat(Int.random(in: 1...4)) * ps
                c.fill(CGRect(x: fx, y: fy, width: ps, height: ps))
                fx += CGFloat(Int.random(in: 6...12)) * ps
            }
        }
    }

    // MARK: Night Ground — dark grass with firefly dots

    private func renderNightGround() -> UIImage {
        let w: CGFloat = GK.worldWidth * 2
        let h: CGFloat = GK.groundHeight
        let ps: CGFloat = 4
        let size = CGSize(width: w, height: h)

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let c = ctx.cgContext

            // Dark earth
            c.setFillColor(UIColor(red: 0.18, green: 0.16, blue: 0.12, alpha: 1).cgColor)
            c.fill(CGRect(origin: .zero, size: size))

            // Subtle dark stripes
            let stripe = UIColor(red: 0.14, green: 0.12, blue: 0.08, alpha: 1)
            var sx: CGFloat = 0
            while sx < w {
                c.setFillColor(stripe.cgColor)
                for i in 0..<Int(h / ps) {
                    let px = sx + CGFloat(i) * ps
                    let py = h - CGFloat(i + 1) * ps
                    if px < w && py >= 22 { c.fill(CGRect(x: px, y: py, width: ps, height: ps)) }
                }
                sx += ps * 4
            }

            // Dark blue-green grass
            let grassH: CGFloat = 22
            c.setFillColor(UIColor(red: 0.10, green: 0.22, blue: 0.12, alpha: 1).cgColor)
            c.fill(CGRect(x: 0, y: 0, width: w, height: grassH))

            c.setFillColor(UIColor(red: 0.06, green: 0.14, blue: 0.08, alpha: 1).cgColor)
            c.fill(CGRect(x: 0, y: 0, width: w, height: ps))

            // Dark tufts
            let tufts = UIColor(red: 0.14, green: 0.28, blue: 0.16, alpha: 1)
            var tx: CGFloat = 0
            while tx < w {
                c.setFillColor(tufts.cgColor)
                let tw = Int.random(in: 1...3)
                for t in 0..<tw { c.fill(CGRect(x: tx + CGFloat(t) * ps, y: grassH, width: ps, height: ps)) }
                c.fill(CGRect(x: tx + CGFloat(tw / 2) * ps, y: grassH + ps, width: ps, height: ps))
                tx += CGFloat(Int.random(in: 3...6)) * ps
            }

            // Firefly dots (small yellow/green glowing pixels)
            var fx: CGFloat = CGFloat.random(in: 8...15) * ps
            while fx < w {
                let glow = Bool.random()
                    ? UIColor(red: 0.85, green: 0.90, blue: 0.30, alpha: 0.7)
                    : UIColor(red: 0.40, green: 0.80, blue: 0.35, alpha: 0.5)
                c.setFillColor(glow.cgColor)
                let fy = CGFloat(Int.random(in: 1...4)) * ps
                c.fill(CGRect(x: fx, y: fy, width: ps, height: ps))
                fx += CGFloat(Int.random(in: 10...18)) * ps
            }
        }
    }

    // MARK: Neon City Ground — asphalt with road markings and neon reflections

    private func renderNeonCityGround() -> UIImage {
        let w: CGFloat = GK.worldWidth * 2
        let h: CGFloat = GK.groundHeight
        let ps: CGFloat = 4
        let size = CGSize(width: w, height: h)

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let c = ctx.cgContext

            // Dark asphalt
            c.setFillColor(UIColor(red: 0.10, green: 0.08, blue: 0.14, alpha: 1).cgColor)
            c.fill(CGRect(origin: .zero, size: size))

            // Asphalt speckles
            let speck = UIColor(red: 0.14, green: 0.12, blue: 0.18, alpha: 1)
            c.setFillColor(speck.cgColor)
            var sx: CGFloat = 0
            while sx < w {
                c.fill(CGRect(x: sx, y: CGFloat(Int.random(in: 4...Int(h/ps)-1)) * ps, width: ps, height: ps))
                sx += CGFloat(Int.random(in: 3...8)) * ps
            }

            // Sidewalk curb (top strip)
            let curbH: CGFloat = 22
            c.setFillColor(UIColor(red: 0.22, green: 0.18, blue: 0.30, alpha: 1).cgColor)
            c.fill(CGRect(x: 0, y: 0, width: w, height: curbH))

            // Curb top edge
            c.setFillColor(UIColor(red: 0.30, green: 0.25, blue: 0.40, alpha: 1).cgColor)
            c.fill(CGRect(x: 0, y: 0, width: w, height: ps))

            // Neon reflection strips
            let neonColors: [UIColor] = [
                UIColor(red: 0.80, green: 0.20, blue: 0.60, alpha: 0.35),
                UIColor(red: 0.20, green: 0.80, blue: 0.95, alpha: 0.30),
                UIColor(red: 0.95, green: 0.40, blue: 0.90, alpha: 0.25),
            ]
            var nx: CGFloat = CGFloat.random(in: 5...12) * ps
            while nx < w {
                c.setFillColor(neonColors[Int.random(in: 0..<neonColors.count)].cgColor)
                let nw = Int.random(in: 2...5)
                for i in 0..<nw { c.fill(CGRect(x: nx + CGFloat(i) * ps, y: curbH, width: ps, height: ps)) }
                nx += CGFloat(Int.random(in: 8...16)) * ps
            }

            // Road dashes
            let dashColor = UIColor(red: 0.80, green: 0.75, blue: 0.40, alpha: 0.5)
            c.setFillColor(dashColor.cgColor)
            var dx: CGFloat = ps * 3
            while dx < w {
                c.fill(CGRect(x: dx, y: h - ps * 3, width: ps * 4, height: ps))
                dx += ps * 12
            }
        }
    }

    // MARK: Tokyo Ground — patterned sidewalk tiles with cherry blossom petals

    private func renderTokyoGround() -> UIImage {
        let w: CGFloat = GK.worldWidth * 2
        let h: CGFloat = GK.groundHeight
        let ps: CGFloat = 4
        let size = CGSize(width: w, height: h)

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let c = ctx.cgContext

            // Grey-purple pavement base
            c.setFillColor(UIColor(red: 0.20, green: 0.16, blue: 0.25, alpha: 1).cgColor)
            c.fill(CGRect(origin: .zero, size: size))

            // Tile grid pattern
            let tileColor = UIColor(red: 0.25, green: 0.20, blue: 0.32, alpha: 1)
            c.setFillColor(tileColor.cgColor)
            // Horizontal lines every 3 pixels
            var gy: CGFloat = ps * 3
            while gy < h {
                c.fill(CGRect(x: 0, y: gy, width: w, height: 1))
                gy += ps * 3
            }
            // Vertical lines staggered
            var row = 0
            gy = 0
            while gy < h {
                var gx: CGFloat = (row % 2 == 0) ? 0 : ps * 4
                while gx < w {
                    c.fill(CGRect(x: gx, y: gy, width: 1, height: ps * 3))
                    gx += ps * 8
                }
                gy += ps * 3
                row += 1
            }

            // Sidewalk curb
            let curbH: CGFloat = 22
            c.setFillColor(UIColor(red: 0.30, green: 0.22, blue: 0.38, alpha: 1).cgColor)
            c.fill(CGRect(x: 0, y: 0, width: w, height: curbH))

            c.setFillColor(UIColor(red: 0.38, green: 0.28, blue: 0.48, alpha: 1).cgColor)
            c.fill(CGRect(x: 0, y: 0, width: w, height: ps))

            // Cherry blossom petals scattered
            let petalColors: [UIColor] = [
                UIColor(red: 1.0, green: 0.70, blue: 0.80, alpha: 0.7),
                UIColor(red: 1.0, green: 0.80, blue: 0.85, alpha: 0.6),
                UIColor(red: 0.95, green: 0.55, blue: 0.70, alpha: 0.5),
            ]
            var px: CGFloat = CGFloat.random(in: 3...8) * ps
            while px < w {
                c.setFillColor(petalColors[Int.random(in: 0..<petalColors.count)].cgColor)
                let py = CGFloat(Int.random(in: 1...5)) * ps
                c.fill(CGRect(x: px, y: py, width: ps, height: ps))
                // Second petal pixel offset
                if Bool.random() {
                    c.fill(CGRect(x: px + ps, y: py - ps, width: ps, height: ps))
                }
                px += CGFloat(Int.random(in: 6...14)) * ps
            }
        }
    }

    // MARK: Underwater Ground — sandy ocean floor with shells and coral bits

    private func renderUnderwaterGround() -> UIImage {
        let w: CGFloat = GK.worldWidth * 2
        let h: CGFloat = GK.groundHeight
        let ps: CGFloat = 4
        let size = CGSize(width: w, height: h)

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let c = ctx.cgContext

            // Sandy ocean floor
            c.setFillColor(UIColor(red: 0.60, green: 0.52, blue: 0.35, alpha: 1).cgColor)
            c.fill(CGRect(origin: .zero, size: size))

            // Darker sand layers
            let deepSand = UIColor(red: 0.50, green: 0.42, blue: 0.28, alpha: 1)
            c.setFillColor(deepSand.cgColor)
            c.fill(CGRect(x: 0, y: h * 0.6, width: w, height: h * 0.4))

            // Sand ripple stripes
            let ripple = UIColor(red: 0.55, green: 0.48, blue: 0.32, alpha: 1)
            var rx: CGFloat = 0
            while rx < w {
                c.setFillColor(ripple.cgColor)
                for i in 0..<3 {
                    let ry = CGFloat(Int.random(in: 5...Int(h/ps)-2)) * ps
                    c.fill(CGRect(x: rx + CGFloat(i) * ps, y: ry, width: ps, height: ps))
                }
                rx += CGFloat(Int.random(in: 4...8)) * ps
            }

            // Coral/reef top strip
            let coralH: CGFloat = 22
            c.setFillColor(UIColor(red: 0.65, green: 0.55, blue: 0.38, alpha: 1).cgColor)
            c.fill(CGRect(x: 0, y: 0, width: w, height: coralH))

            c.setFillColor(UIColor(red: 0.48, green: 0.40, blue: 0.25, alpha: 1).cgColor)
            c.fill(CGRect(x: 0, y: 0, width: w, height: ps))

            // Coral bits and shells
            let coralColors: [UIColor] = [
                UIColor(red: 0.90, green: 0.45, blue: 0.35, alpha: 0.8),
                UIColor(red: 0.95, green: 0.70, blue: 0.50, alpha: 0.7),
                UIColor(red: 0.80, green: 0.35, blue: 0.55, alpha: 0.7),
                UIColor(red: 0.90, green: 0.85, blue: 0.75, alpha: 0.6),  // shell white
            ]
            var cx: CGFloat = CGFloat.random(in: 4...8) * ps
            while cx < w {
                c.setFillColor(coralColors[Int.random(in: 0..<coralColors.count)].cgColor)
                let cy = CGFloat(Int.random(in: 1...4)) * ps
                let cw = Int.random(in: 1...2)
                for i in 0..<cw { c.fill(CGRect(x: cx + CGFloat(i) * ps, y: cy, width: ps, height: ps)) }
                if Bool.random() { c.fill(CGRect(x: cx, y: cy + ps, width: ps, height: ps)) }
                cx += CGFloat(Int.random(in: 5...10)) * ps
            }

            // Bubbles rising from floor
            let bubble = UIColor(red: 0.70, green: 0.85, blue: 0.95, alpha: 0.4)
            c.setFillColor(bubble.cgColor)
            var bx: CGFloat = CGFloat.random(in: 10...20) * ps
            while bx < w {
                c.fill(CGRect(x: bx, y: coralH + ps, width: ps, height: ps))
                if Bool.random() { c.fill(CGRect(x: bx + ps, y: coralH + ps * 3, width: ps, height: ps)) }
                bx += CGFloat(Int.random(in: 15...25)) * ps
            }
        }
    }

    // MARK: Volcano Ground — dark rock with lava cracks and ember glow

    private func renderVolcanoGround() -> UIImage {
        let w: CGFloat = GK.worldWidth * 2
        let h: CGFloat = GK.groundHeight
        let ps: CGFloat = 4
        let size = CGSize(width: w, height: h)

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let c = ctx.cgContext

            // Dark volcanic rock base
            c.setFillColor(UIColor(red: 0.12, green: 0.08, blue: 0.06, alpha: 1).cgColor)
            c.fill(CGRect(origin: .zero, size: size))

            // Rock texture speckles
            let rockVariants: [UIColor] = [
                UIColor(red: 0.16, green: 0.10, blue: 0.08, alpha: 1),
                UIColor(red: 0.10, green: 0.06, blue: 0.04, alpha: 1),
            ]
            var sx: CGFloat = 0
            while sx < w {
                c.setFillColor(rockVariants[Int.random(in: 0..<2)].cgColor)
                c.fill(CGRect(x: sx, y: CGFloat(Int.random(in: 3...Int(h/ps)-1)) * ps, width: ps, height: ps))
                sx += CGFloat(Int.random(in: 2...5)) * ps
            }

            // Lava cracks (jagged orange-red lines)
            let crackH: CGFloat = 22
            c.setFillColor(UIColor(red: 0.20, green: 0.12, blue: 0.08, alpha: 1).cgColor)
            c.fill(CGRect(x: 0, y: 0, width: w, height: crackH))

            // Glowing lava top edge
            c.setFillColor(UIColor(red: 0.85, green: 0.35, blue: 0.08, alpha: 0.9).cgColor)
            c.fill(CGRect(x: 0, y: 0, width: w, height: ps))
            c.setFillColor(UIColor(red: 0.95, green: 0.55, blue: 0.12, alpha: 0.6).cgColor)
            c.fill(CGRect(x: 0, y: ps, width: w, height: ps))

            // Lava crack veins in the dirt
            let lavaColors: [UIColor] = [
                UIColor(red: 0.95, green: 0.40, blue: 0.08, alpha: 0.7),
                UIColor(red: 0.90, green: 0.25, blue: 0.05, alpha: 0.6),
                UIColor(red: 1.0, green: 0.65, blue: 0.15, alpha: 0.5),
            ]
            var lx: CGFloat = CGFloat.random(in: 6...12) * ps
            while lx < w {
                c.setFillColor(lavaColors[Int.random(in: 0..<lavaColors.count)].cgColor)
                let ly = CGFloat(Int.random(in: 4...Int(h/ps)-1)) * ps
                // Jagged horizontal crack
                let len = Int.random(in: 2...5)
                var cy = ly
                for i in 0..<len {
                    c.fill(CGRect(x: lx + CGFloat(i) * ps, y: cy, width: ps, height: ps))
                    cy += (Bool.random() ? ps : -ps)
                    cy = max(crackH, min(cy, h - ps * 2))
                }
                lx += CGFloat(Int.random(in: 8...16)) * ps
            }

            // Ember pixel dots
            let ember = UIColor(red: 1.0, green: 0.50, blue: 0.10, alpha: 0.5)
            c.setFillColor(ember.cgColor)
            var ex: CGFloat = CGFloat.random(in: 8...14) * ps
            while ex < w {
                let ey = CGFloat(Int.random(in: 1...3)) * ps
                c.fill(CGRect(x: ex, y: ey, width: ps, height: ps))
                ex += CGFloat(Int.random(in: 12...20)) * ps
            }
        }
    }

    // MARK: Arctic Ground — snow and ice with frozen puddles

    private func renderArcticGround() -> UIImage {
        let w: CGFloat = GK.worldWidth * 2
        let h: CGFloat = GK.groundHeight
        let ps: CGFloat = 4
        let size = CGSize(width: w, height: h)

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let c = ctx.cgContext

            // Packed snow base
            c.setFillColor(UIColor(red: 0.85, green: 0.88, blue: 0.92, alpha: 1).cgColor)
            c.fill(CGRect(origin: .zero, size: size))

            // Icy blue undertone layer
            let iceLayer = UIColor(red: 0.72, green: 0.82, blue: 0.90, alpha: 1)
            c.setFillColor(iceLayer.cgColor)
            c.fill(CGRect(x: 0, y: h * 0.5, width: w, height: h * 0.5))

            // Snow drift stripes
            let drift = UIColor(red: 0.90, green: 0.92, blue: 0.95, alpha: 1)
            var sx: CGFloat = 0
            while sx < w {
                c.setFillColor(drift.cgColor)
                c.fill(CGRect(x: sx, y: CGFloat(Int.random(in: 4...Int(h/ps)-2)) * ps, width: ps * 3, height: ps))
                sx += CGFloat(Int.random(in: 4...8)) * ps
            }

            // Snow surface top
            let snowH: CGFloat = 22
            c.setFillColor(UIColor(red: 0.92, green: 0.94, blue: 0.97, alpha: 1).cgColor)
            c.fill(CGRect(x: 0, y: 0, width: w, height: snowH))

            // Crystal ice edge
            c.setFillColor(UIColor(red: 0.65, green: 0.78, blue: 0.92, alpha: 0.8).cgColor)
            c.fill(CGRect(x: 0, y: 0, width: w, height: ps))

            // Snow tufts (white bumps)
            let tuft = UIColor(red: 0.96, green: 0.97, blue: 0.99, alpha: 1)
            var tx: CGFloat = 0
            while tx < w {
                c.setFillColor(tuft.cgColor)
                let tw = Int.random(in: 2...4)
                for t in 0..<tw { c.fill(CGRect(x: tx + CGFloat(t) * ps, y: snowH, width: ps, height: ps)) }
                c.fill(CGRect(x: tx + CGFloat(tw / 2) * ps, y: snowH + ps, width: ps, height: ps))
                tx += CGFloat(Int.random(in: 3...6)) * ps
            }

            // Frozen puddle patches (ice blue)
            let puddle = UIColor(red: 0.55, green: 0.72, blue: 0.88, alpha: 0.5)
            c.setFillColor(puddle.cgColor)
            var px: CGFloat = CGFloat.random(in: 8...15) * ps
            while px < w {
                let pw = Int.random(in: 3...6)
                for i in 0..<pw { c.fill(CGRect(x: px + CGFloat(i) * ps, y: ps * 2, width: ps, height: ps)) }
                px += CGFloat(Int.random(in: 12...22)) * ps
            }
        }
    }

    // MARK: Western Ground — dry cracked desert dirt with tumbleweeds

    private func renderWesternGround() -> UIImage {
        let w: CGFloat = GK.worldWidth * 2
        let h: CGFloat = GK.groundHeight
        let ps: CGFloat = 4
        let size = CGSize(width: w, height: h)

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let c = ctx.cgContext

            // Dusty tan base
            c.setFillColor(UIColor(red: 0.72, green: 0.58, blue: 0.38, alpha: 1).cgColor)
            c.fill(CGRect(origin: .zero, size: size))

            // Dry cracks pattern
            let crack = UIColor(red: 0.60, green: 0.48, blue: 0.30, alpha: 1)
            var cx: CGFloat = 0
            while cx < w {
                c.setFillColor(crack.cgColor)
                for i in 0..<Int.random(in: 2...4) {
                    let py = CGFloat(Int.random(in: 4...Int(h/ps)-1)) * ps
                    c.fill(CGRect(x: cx + CGFloat(i) * ps, y: py, width: ps, height: ps))
                }
                cx += CGFloat(Int.random(in: 5...10)) * ps
            }

            // Dry scrub top strip
            let scrubH: CGFloat = 22
            c.setFillColor(UIColor(red: 0.68, green: 0.55, blue: 0.32, alpha: 1).cgColor)
            c.fill(CGRect(x: 0, y: 0, width: w, height: scrubH))

            // Dark border line
            c.setFillColor(UIColor(red: 0.55, green: 0.42, blue: 0.24, alpha: 1).cgColor)
            c.fill(CGRect(x: 0, y: 0, width: w, height: ps))

            // Dead grass tufts (brown/yellow)
            let deadGrass = UIColor(red: 0.75, green: 0.62, blue: 0.30, alpha: 0.8)
            var tx: CGFloat = 0
            while tx < w {
                c.setFillColor(deadGrass.cgColor)
                let tw = Int.random(in: 1...2)
                for t in 0..<tw { c.fill(CGRect(x: tx + CGFloat(t) * ps, y: scrubH, width: ps, height: ps)) }
                tx += CGFloat(Int.random(in: 4...8)) * ps
            }

            // Small rocks/pebbles
            let pebble = UIColor(red: 0.52, green: 0.42, blue: 0.28, alpha: 0.7)
            var px: CGFloat = CGFloat.random(in: 5...10) * ps
            while px < w {
                c.setFillColor(pebble.cgColor)
                c.fill(CGRect(x: px, y: CGFloat(Int.random(in: 1...3)) * ps, width: ps, height: ps))
                px += CGFloat(Int.random(in: 8...14)) * ps
            }
        }
    }

    // MARK: Jungle Ground — rich dark soil with moss, roots, and small flowers

    private func renderJungleGround() -> UIImage {
        let w: CGFloat = GK.worldWidth * 2
        let h: CGFloat = GK.groundHeight
        let ps: CGFloat = 4
        let size = CGSize(width: w, height: h)

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let c = ctx.cgContext

            // Rich dark soil
            c.setFillColor(UIColor(red: 0.28, green: 0.20, blue: 0.12, alpha: 1).cgColor)
            c.fill(CGRect(origin: .zero, size: size))

            // Root-like dark streaks
            let root = UIColor(red: 0.22, green: 0.15, blue: 0.08, alpha: 1)
            var rx: CGFloat = 0
            while rx < w {
                c.setFillColor(root.cgColor)
                let ry = CGFloat(Int.random(in: 4...Int(h/ps)-1)) * ps
                let rLen = Int.random(in: 3...6)
                var cy = ry
                for i in 0..<rLen {
                    c.fill(CGRect(x: rx + CGFloat(i) * ps, y: cy, width: ps, height: ps))
                    if Bool.random() { cy += ps }
                }
                rx += CGFloat(Int.random(in: 6...12)) * ps
            }

            // Mossy top strip
            let mossH: CGFloat = 22
            c.setFillColor(UIColor(red: 0.22, green: 0.45, blue: 0.15, alpha: 1).cgColor)
            c.fill(CGRect(x: 0, y: 0, width: w, height: mossH))

            // Dark moss edge
            c.setFillColor(UIColor(red: 0.15, green: 0.32, blue: 0.10, alpha: 1).cgColor)
            c.fill(CGRect(x: 0, y: 0, width: w, height: ps))

            // Lush fern tufts
            let fern = UIColor(red: 0.28, green: 0.55, blue: 0.18, alpha: 1)
            var tx: CGFloat = 0
            while tx < w {
                c.setFillColor(fern.cgColor)
                let tw = Int.random(in: 1...3)
                for t in 0..<tw { c.fill(CGRect(x: tx + CGFloat(t) * ps, y: mossH, width: ps, height: ps)) }
                c.fill(CGRect(x: tx + CGFloat(tw / 2) * ps, y: mossH + ps, width: ps, height: ps))
                tx += CGFloat(Int.random(in: 3...5)) * ps
            }

            // Tropical flowers
            let flowerColors: [UIColor] = [
                UIColor(red: 0.95, green: 0.30, blue: 0.40, alpha: 0.8),
                UIColor(red: 0.95, green: 0.75, blue: 0.15, alpha: 0.8),
                UIColor(red: 0.85, green: 0.20, blue: 0.65, alpha: 0.7),
                UIColor(red: 0.95, green: 0.55, blue: 0.20, alpha: 0.7),
            ]
            var fx: CGFloat = CGFloat.random(in: 4...8) * ps
            while fx < w {
                c.setFillColor(flowerColors[Int.random(in: 0..<flowerColors.count)].cgColor)
                let fy = CGFloat(Int.random(in: 1...3)) * ps
                c.fill(CGRect(x: fx, y: fy, width: ps, height: ps))
                fx += CGFloat(Int.random(in: 5...10)) * ps
            }

            // Mushroom dots
            let mush = UIColor(red: 0.85, green: 0.78, blue: 0.60, alpha: 0.6)
            c.setFillColor(mush.cgColor)
            var mx: CGFloat = CGFloat.random(in: 12...20) * ps
            while mx < w {
                c.fill(CGRect(x: mx, y: ps, width: ps * 2, height: ps))
                c.fill(CGRect(x: mx + ps / 2, y: ps * 2, width: ps, height: ps))
                mx += CGFloat(Int.random(in: 20...35)) * ps
            }
        }
    }

    // MARK: Egypt Ground — golden desert sand with hieroglyphic fragments

    private func renderEgyptGround() -> UIImage {
        let w: CGFloat = GK.worldWidth * 2
        let h: CGFloat = GK.groundHeight
        let ps: CGFloat = 4
        let size = CGSize(width: w, height: h)

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let c = ctx.cgContext

            // Golden sand base
            c.setFillColor(UIColor(red: 0.82, green: 0.68, blue: 0.40, alpha: 1).cgColor)
            c.fill(CGRect(origin: .zero, size: size))

            // Deeper sand layer
            c.setFillColor(UIColor(red: 0.75, green: 0.60, blue: 0.32, alpha: 1).cgColor)
            c.fill(CGRect(x: 0, y: h * 0.55, width: w, height: h * 0.45))

            // Sand ripple highlights
            let highlight = UIColor(red: 0.88, green: 0.75, blue: 0.48, alpha: 1)
            var sx: CGFloat = 0
            while sx < w {
                c.setFillColor(highlight.cgColor)
                c.fill(CGRect(x: sx, y: CGFloat(Int.random(in: 3...Int(h/ps)-2)) * ps, width: ps * 2, height: ps))
                sx += CGFloat(Int.random(in: 4...7)) * ps
            }

            // Sandstone top strip
            let stoneH: CGFloat = 22
            c.setFillColor(UIColor(red: 0.78, green: 0.62, blue: 0.35, alpha: 1).cgColor)
            c.fill(CGRect(x: 0, y: 0, width: w, height: stoneH))

            // Dark sandstone edge
            c.setFillColor(UIColor(red: 0.65, green: 0.50, blue: 0.28, alpha: 1).cgColor)
            c.fill(CGRect(x: 0, y: 0, width: w, height: ps))

            // Hieroglyphic fragments (tiny pixel patterns in the stone)
            let hieroglyph = UIColor(red: 0.60, green: 0.45, blue: 0.22, alpha: 0.5)
            c.setFillColor(hieroglyph.cgColor)
            var hx: CGFloat = CGFloat.random(in: 8...15) * ps
            while hx < w {
                // Simple L or T shapes
                let pattern = Int.random(in: 0...2)
                if pattern == 0 {
                    // L shape
                    c.fill(CGRect(x: hx, y: ps * 2, width: ps, height: ps * 2))
                    c.fill(CGRect(x: hx + ps, y: ps * 3, width: ps, height: ps))
                } else if pattern == 1 {
                    // T shape
                    c.fill(CGRect(x: hx, y: ps * 2, width: ps * 3, height: ps))
                    c.fill(CGRect(x: hx + ps, y: ps * 3, width: ps, height: ps))
                } else {
                    // Dot pair
                    c.fill(CGRect(x: hx, y: ps * 2, width: ps, height: ps))
                    c.fill(CGRect(x: hx + ps * 2, y: ps * 2, width: ps, height: ps))
                }
                hx += CGFloat(Int.random(in: 12...22)) * ps
            }

            // Scattered pottery shard pixels
            let shard = UIColor(red: 0.70, green: 0.42, blue: 0.20, alpha: 0.6)
            c.setFillColor(shard.cgColor)
            var fx: CGFloat = CGFloat.random(in: 10...18) * ps
            while fx < w {
                c.fill(CGRect(x: fx, y: CGFloat(Int.random(in: 1...3)) * ps, width: ps, height: ps))
                fx += CGFloat(Int.random(in: 14...24)) * ps
            }
        }
    }

    // MARK: Cave Ground — dark stone floor with crystal shards and glowing moss

    private func renderCaveGround() -> UIImage {
        let w: CGFloat = GK.worldWidth * 2
        let h: CGFloat = GK.groundHeight
        let ps: CGFloat = 4
        let size = CGSize(width: w, height: h)

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let c = ctx.cgContext

            // Dark stone base
            c.setFillColor(UIColor(red: 0.10, green: 0.08, blue: 0.12, alpha: 1).cgColor)
            c.fill(CGRect(origin: .zero, size: size))

            // Stone texture variation
            let stoneVar: [UIColor] = [
                UIColor(red: 0.12, green: 0.10, blue: 0.16, alpha: 1),
                UIColor(red: 0.08, green: 0.06, blue: 0.10, alpha: 1),
            ]
            var sx: CGFloat = 0
            while sx < w {
                c.setFillColor(stoneVar[Int.random(in: 0..<2)].cgColor)
                c.fill(CGRect(x: sx, y: CGFloat(Int.random(in: 2...Int(h/ps)-1)) * ps, width: ps, height: ps))
                sx += CGFloat(Int.random(in: 2...4)) * ps
            }

            // Rocky ledge top
            let ledgeH: CGFloat = 22
            c.setFillColor(UIColor(red: 0.15, green: 0.12, blue: 0.20, alpha: 1).cgColor)
            c.fill(CGRect(x: 0, y: 0, width: w, height: ledgeH))

            c.setFillColor(UIColor(red: 0.20, green: 0.16, blue: 0.26, alpha: 1).cgColor)
            c.fill(CGRect(x: 0, y: 0, width: w, height: ps))

            // Crystal shard protrusions
            let crystalColors: [UIColor] = [
                UIColor(red: 0.50, green: 0.30, blue: 0.80, alpha: 0.7),
                UIColor(red: 0.30, green: 0.60, blue: 0.85, alpha: 0.6),
                UIColor(red: 0.70, green: 0.40, blue: 0.90, alpha: 0.5),
            ]
            var cx: CGFloat = CGFloat.random(in: 8...14) * ps
            while cx < w {
                c.setFillColor(crystalColors[Int.random(in: 0..<crystalColors.count)].cgColor)
                let ch = Int.random(in: 2...4)
                for i in 0..<ch {
                    c.fill(CGRect(x: cx, y: ledgeH + CGFloat(i) * ps, width: ps, height: ps))
                }
                // Point at top
                c.fill(CGRect(x: cx - ps / 2, y: ledgeH + CGFloat(ch) * ps, width: ps, height: ps))
                cx += CGFloat(Int.random(in: 14...25)) * ps
            }

            // Bioluminescent moss dots
            let moss = UIColor(red: 0.30, green: 0.85, blue: 0.50, alpha: 0.4)
            c.setFillColor(moss.cgColor)
            var mx: CGFloat = CGFloat.random(in: 5...10) * ps
            while mx < w {
                c.fill(CGRect(x: mx, y: CGFloat(Int.random(in: 1...3)) * ps, width: ps, height: ps))
                mx += CGFloat(Int.random(in: 8...15)) * ps
            }
        }
    }

    // MARK: Mountain Ground — rocky trail with alpine flowers and pebbles

    private func renderMountainGround() -> UIImage {
        let w: CGFloat = GK.worldWidth * 2
        let h: CGFloat = GK.groundHeight
        let ps: CGFloat = 4
        let size = CGSize(width: w, height: h)

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let c = ctx.cgContext

            // Rocky grey-brown base
            c.setFillColor(UIColor(red: 0.48, green: 0.42, blue: 0.35, alpha: 1).cgColor)
            c.fill(CGRect(origin: .zero, size: size))

            // Dirt/gravel variation
            let gravel = UIColor(red: 0.42, green: 0.36, blue: 0.28, alpha: 1)
            c.setFillColor(gravel.cgColor)
            c.fill(CGRect(x: 0, y: h * 0.5, width: w, height: h * 0.5))

            // Stone speckles
            let speck = UIColor(red: 0.55, green: 0.48, blue: 0.40, alpha: 1)
            var sx: CGFloat = 0
            while sx < w {
                c.setFillColor(speck.cgColor)
                c.fill(CGRect(x: sx, y: CGFloat(Int.random(in: 3...Int(h/ps)-2)) * ps, width: ps, height: ps))
                sx += CGFloat(Int.random(in: 3...6)) * ps
            }

            // Grassy trail top strip
            let trailH: CGFloat = 22
            c.setFillColor(UIColor(red: 0.35, green: 0.50, blue: 0.28, alpha: 1).cgColor)
            c.fill(CGRect(x: 0, y: 0, width: w, height: trailH))

            // Rocky edge
            c.setFillColor(UIColor(red: 0.28, green: 0.40, blue: 0.22, alpha: 1).cgColor)
            c.fill(CGRect(x: 0, y: 0, width: w, height: ps))

            // Sparse alpine grass tufts
            let alpine = UIColor(red: 0.40, green: 0.58, blue: 0.30, alpha: 0.9)
            var tx: CGFloat = 0
            while tx < w {
                c.setFillColor(alpine.cgColor)
                let tw = Int.random(in: 1...2)
                for t in 0..<tw { c.fill(CGRect(x: tx + CGFloat(t) * ps, y: trailH, width: ps, height: ps)) }
                tx += CGFloat(Int.random(in: 4...7)) * ps
            }

            // Alpine wildflowers
            let flowerColors: [UIColor] = [
                UIColor(red: 0.90, green: 0.85, blue: 0.95, alpha: 0.8),  // edelweiss white
                UIColor(red: 0.70, green: 0.50, blue: 0.85, alpha: 0.7),  // alpine violet
                UIColor(red: 0.95, green: 0.80, blue: 0.20, alpha: 0.7),  // buttercup
            ]
            var fx: CGFloat = CGFloat.random(in: 6...12) * ps
            while fx < w {
                c.setFillColor(flowerColors[Int.random(in: 0..<flowerColors.count)].cgColor)
                c.fill(CGRect(x: fx, y: CGFloat(Int.random(in: 1...3)) * ps, width: ps, height: ps))
                fx += CGFloat(Int.random(in: 8...14)) * ps
            }
        }
    }

    // MARK: Space Ground — metal plating with rivets and status lights

    private func renderSpaceGround() -> UIImage {
        let w: CGFloat = GK.worldWidth * 2
        let h: CGFloat = GK.groundHeight
        let ps: CGFloat = 4
        let size = CGSize(width: w, height: h)

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let c = ctx.cgContext

            // Dark metal hull base
            c.setFillColor(UIColor(red: 0.10, green: 0.10, blue: 0.14, alpha: 1).cgColor)
            c.fill(CGRect(origin: .zero, size: size))

            // Panel seam lines (horizontal)
            let seam = UIColor(red: 0.06, green: 0.06, blue: 0.10, alpha: 1)
            c.setFillColor(seam.cgColor)
            c.fill(CGRect(x: 0, y: h * 0.35, width: w, height: 1))
            c.fill(CGRect(x: 0, y: h * 0.65, width: w, height: 1))

            // Vertical seams
            var vx: CGFloat = 0
            while vx < w {
                c.fill(CGRect(x: vx, y: 0, width: 1, height: h))
                vx += ps * 10
            }

            // Plating edge top
            let edgeH: CGFloat = 22
            c.setFillColor(UIColor(red: 0.14, green: 0.14, blue: 0.20, alpha: 1).cgColor)
            c.fill(CGRect(x: 0, y: 0, width: w, height: edgeH))

            // Warning stripe (yellow/black hazard)
            let stripeW: CGFloat = ps * 2
            var stx: CGFloat = 0
            var isYellow = true
            while stx < w {
                c.setFillColor(isYellow
                    ? UIColor(red: 0.85, green: 0.75, blue: 0.15, alpha: 0.8).cgColor
                    : UIColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 0.8).cgColor)
                c.fill(CGRect(x: stx, y: 0, width: stripeW, height: ps))
                stx += stripeW
                isYellow.toggle()
            }

            // Highlight edge line
            c.setFillColor(UIColor(red: 0.22, green: 0.22, blue: 0.30, alpha: 1).cgColor)
            c.fill(CGRect(x: 0, y: ps, width: w, height: 1))

            // Rivet dots
            let rivet = UIColor(red: 0.20, green: 0.20, blue: 0.28, alpha: 0.8)
            c.setFillColor(rivet.cgColor)
            var rx: CGFloat = ps * 4
            while rx < w {
                c.fill(CGRect(x: rx, y: edgeH - ps, width: ps, height: ps))
                c.fill(CGRect(x: rx, y: h - ps * 2, width: ps, height: ps))
                rx += ps * 10
            }

            // Small status lights
            let lightColors: [UIColor] = [
                UIColor(red: 0.20, green: 0.80, blue: 0.30, alpha: 0.7),
                UIColor(red: 0.85, green: 0.25, blue: 0.20, alpha: 0.6),
                UIColor(red: 0.30, green: 0.60, blue: 0.95, alpha: 0.6),
            ]
            var lx: CGFloat = CGFloat.random(in: 12...20) * ps
            while lx < w {
                c.setFillColor(lightColors[Int.random(in: 0..<lightColors.count)].cgColor)
                c.fill(CGRect(x: lx, y: CGFloat(Int.random(in: 2...4)) * ps, width: ps, height: ps))
                lx += CGFloat(Int.random(in: 15...25)) * ps
            }
        }
    }

    // MARK: Lagoon Ground — white sand with tidal water hints

    private func renderLagoonGround() -> UIImage {
        let w: CGFloat = GK.worldWidth * 2
        let h: CGFloat = GK.groundHeight
        let ps: CGFloat = 4
        let size = CGSize(width: w, height: h)

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let c = ctx.cgContext
            // Warm sand base
            c.setFillColor(UIColor(red: 0.88, green: 0.80, blue: 0.62, alpha: 1).cgColor)
            c.fill(CGRect(origin: .zero, size: size))
            // Top strip — wet sand near water
            let wetH: CGFloat = 20
            c.setFillColor(UIColor(red: 0.72, green: 0.68, blue: 0.52, alpha: 1).cgColor)
            c.fill(CGRect(x: 0, y: 0, width: w, height: wetH))
            // Water foam edge
            c.setFillColor(UIColor(red: 0.80, green: 0.90, blue: 0.95, alpha: 0.5).cgColor)
            c.fill(CGRect(x: 0, y: 0, width: w, height: ps))
            // Sandy speckles
            let speckle = UIColor(red: 0.82, green: 0.75, blue: 0.55, alpha: 0.6)
            var sx: CGFloat = 0
            while sx < w {
                c.setFillColor(speckle.cgColor)
                let sy = CGFloat(Int.random(in: 2...Int(h / ps) - 1)) * ps
                c.fill(CGRect(x: sx, y: sy, width: ps, height: ps))
                sx += CGFloat(Int.random(in: 4...9)) * ps
            }
        }
    }

    // MARK: Los Angeles Ground — hot asphalt road with lane markings

    private func renderLosAngelesGround() -> UIImage {
        let w: CGFloat = GK.worldWidth * 2
        let h: CGFloat = GK.groundHeight
        let ps: CGFloat = 4
        let size = CGSize(width: w, height: h)

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let c = ctx.cgContext
            // Dark asphalt
            c.setFillColor(UIColor(red: 0.22, green: 0.22, blue: 0.24, alpha: 1).cgColor)
            c.fill(CGRect(origin: .zero, size: size))
            // Curb/sidewalk strip at top
            let curbH: CGFloat = 18
            c.setFillColor(UIColor(red: 0.52, green: 0.50, blue: 0.48, alpha: 1).cgColor)
            c.fill(CGRect(x: 0, y: 0, width: w, height: curbH))
            c.setFillColor(UIColor(red: 0.60, green: 0.58, blue: 0.55, alpha: 1).cgColor)
            c.fill(CGRect(x: 0, y: 0, width: w, height: ps))
            // Road texture noise
            let noise = UIColor(red: 0.18, green: 0.18, blue: 0.20, alpha: 0.5)
            var nx: CGFloat = 0
            while nx < w {
                c.setFillColor(noise.cgColor)
                let ny = CGFloat(Int.random(in: 3...Int(h / ps) - 1)) * ps
                c.fill(CGRect(x: nx, y: ny, width: ps, height: ps))
                nx += CGFloat(Int.random(in: 3...7)) * ps
            }
        }
    }

    // MARK: London Ground — wet cobblestone with brick tint

    private func renderLondonGround() -> UIImage {
        let w: CGFloat = GK.worldWidth * 2
        let h: CGFloat = GK.groundHeight
        let ps: CGFloat = 4
        let size = CGSize(width: w, height: h)

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let c = ctx.cgContext
            // Grey stone base
            c.setFillColor(UIColor(red: 0.32, green: 0.32, blue: 0.34, alpha: 1).cgColor)
            c.fill(CGRect(origin: .zero, size: size))
            // Brick-tinted top strip
            let brickH: CGFloat = 18
            c.setFillColor(UIColor(red: 0.38, green: 0.30, blue: 0.26, alpha: 1).cgColor)
            c.fill(CGRect(x: 0, y: 0, width: w, height: brickH))
            // Edge line
            c.setFillColor(UIColor(red: 0.28, green: 0.26, blue: 0.24, alpha: 1).cgColor)
            c.fill(CGRect(x: 0, y: 0, width: w, height: ps))
            // Cobblestone pattern (alternating shade)
            let stoneLight = UIColor(red: 0.38, green: 0.37, blue: 0.38, alpha: 0.4)
            let stoneDark  = UIColor(red: 0.26, green: 0.26, blue: 0.28, alpha: 0.4)
            var sy: CGFloat = brickH
            var rowIdx = 0
            while sy < h {
                var sx: CGFloat = rowIdx % 2 == 0 ? 0 : ps * 2
                while sx < w {
                    c.setFillColor(Int(sx / ps) % 3 == 0 ? stoneDark.cgColor : stoneLight.cgColor)
                    c.fill(CGRect(x: sx, y: sy, width: ps * 4, height: ps * 2))
                    sx += ps * 4 + 1 // 1px gap
                }
                sy += ps * 2 + 1
                rowIdx += 1
            }
            // Wet sheen
            let sheen = UIColor(red: 0.50, green: 0.55, blue: 0.60, alpha: 0.12)
            c.setFillColor(sheen.cgColor)
            c.fill(CGRect(x: 0, y: 0, width: w, height: h))
        }
    }

    // MARK: - Themed Ground Detail Rendering
    //
    // Each theme gets unique surface decorations above the ground tile.

    private func renderThemedGroundDetail(theme: BackgroundTheme, tileWidth: CGFloat, groundHeight: CGFloat, seed: Int) -> UIImage {
        switch theme {
        case .day:         return renderGroundDetail(tileWidth: tileWidth, groundHeight: groundHeight, seed: seed)
        case .sunset:      return renderSunsetGroundDetail(tileWidth: tileWidth, groundHeight: groundHeight, seed: seed)
        case .night:       return renderNightGroundDetail(tileWidth: tileWidth, groundHeight: groundHeight, seed: seed)
        case .neonCity:    return renderNeonGroundDetail(tileWidth: tileWidth, groundHeight: groundHeight, seed: seed)
        case .pixelTokyo:  return renderTokyoGroundDetail(tileWidth: tileWidth, groundHeight: groundHeight, seed: seed)
        case .underwater:  return renderUnderwaterGroundDetail(tileWidth: tileWidth, groundHeight: groundHeight, seed: seed)
        case .volcano:     return renderVolcanoGroundDetail(tileWidth: tileWidth, groundHeight: groundHeight, seed: seed)
        case .arctic:      return renderArcticGroundDetail(tileWidth: tileWidth, groundHeight: groundHeight, seed: seed)
        case .western:     return renderWesternGroundDetail(tileWidth: tileWidth, groundHeight: groundHeight, seed: seed)
        case .jungle:      return renderJungleGroundDetail(tileWidth: tileWidth, groundHeight: groundHeight, seed: seed)
        case .egypt:       return renderEgyptGroundDetail(tileWidth: tileWidth, groundHeight: groundHeight, seed: seed)
        case .cave:        return renderCaveGroundDetail(tileWidth: tileWidth, groundHeight: groundHeight, seed: seed)
        case .mountain:    return renderMountainGroundDetail(tileWidth: tileWidth, groundHeight: groundHeight, seed: seed)
        case .space:       return renderSpaceGroundDetail(tileWidth: tileWidth, groundHeight: groundHeight, seed: seed)
        case .lagoon:      return renderLagoonGroundDetail(tileWidth: tileWidth, groundHeight: groundHeight, seed: seed)
        case .losAngeles:  return renderLosAngelesGroundDetail(tileWidth: tileWidth, groundHeight: groundHeight, seed: seed)
        case .london:      return renderLondonGroundDetail(tileWidth: tileWidth, groundHeight: groundHeight, seed: seed)
        }
    }

    // MARK: Sunset Ground Detail — amber grass blades

    private func renderSunsetGroundDetail(tileWidth: CGFloat, groundHeight: CGFloat, seed: Int) -> UIImage {
        srand48(seed)
        let h: CGFloat = groundHeight + 20
        let size = CGSize(width: tileWidth, height: h)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let c = ctx.cgContext
            let baseY = h - groundHeight
            for _ in 0..<14 {
                let x = CGFloat(drand48()) * tileWidth
                let bladeH = CGFloat(drand48()) * 8 + 6
                let halfW: CGFloat = 1.5
                let r = 0.50 + CGFloat(drand48()) * 0.20
                let g = 0.38 + CGFloat(drand48()) * 0.15
                let b = 0.10 + CGFloat(drand48()) * 0.10
                c.setFillColor(UIColor(red: r, green: g, blue: b, alpha: 1).cgColor)
                let path = CGMutablePath()
                path.move(to: CGPoint(x: x - halfW, y: baseY))
                path.addLine(to: CGPoint(x: x, y: baseY - bladeH))
                path.addLine(to: CGPoint(x: x + halfW, y: baseY))
                path.closeSubpath()
                c.addPath(path); c.fillPath()
            }
        }
    }

    // MARK: Night Ground Detail — dark grass with firefly specks

    private func renderNightGroundDetail(tileWidth: CGFloat, groundHeight: CGFloat, seed: Int) -> UIImage {
        srand48(seed)
        let h: CGFloat = groundHeight + 20
        let size = CGSize(width: tileWidth, height: h)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let c = ctx.cgContext
            let baseY = h - groundHeight
            // Dark grass blades
            for _ in 0..<10 {
                let x = CGFloat(drand48()) * tileWidth
                let bladeH = CGFloat(drand48()) * 7 + 5
                let halfW: CGFloat = 1.5
                let r = 0.08 + CGFloat(drand48()) * 0.08
                let g = 0.18 + CGFloat(drand48()) * 0.12
                let b = 0.06 + CGFloat(drand48()) * 0.06
                c.setFillColor(UIColor(red: r, green: g, blue: b, alpha: 0.8).cgColor)
                let path = CGMutablePath()
                path.move(to: CGPoint(x: x - halfW, y: baseY))
                path.addLine(to: CGPoint(x: x, y: baseY - bladeH))
                path.addLine(to: CGPoint(x: x + halfW, y: baseY))
                path.closeSubpath()
                c.addPath(path); c.fillPath()
            }
            // Firefly dots
            for _ in 0..<4 {
                let fx = CGFloat(drand48()) * tileWidth
                let fy = baseY - CGFloat(drand48()) * 16
                c.setFillColor(UIColor(red: 0.85, green: 0.90, blue: 0.30, alpha: 0.6).cgColor)
                c.fill(CGRect(x: fx, y: fy, width: 2, height: 2))
            }
        }
    }

    // MARK: Neon Ground Detail — neon light reflections on wet asphalt

    private func renderNeonGroundDetail(tileWidth: CGFloat, groundHeight: CGFloat, seed: Int) -> UIImage {
        srand48(seed)
        let h: CGFloat = groundHeight + 20
        let size = CGSize(width: tileWidth, height: h)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let c = ctx.cgContext
            let baseY = h - groundHeight
            let neonColors: [UIColor] = [
                UIColor(red: 0.80, green: 0.20, blue: 0.60, alpha: 0.3),
                UIColor(red: 0.20, green: 0.80, blue: 0.95, alpha: 0.25),
                UIColor(red: 0.95, green: 0.40, blue: 0.90, alpha: 0.20),
            ]
            for _ in 0..<6 {
                let x = CGFloat(drand48()) * tileWidth
                let w: CGFloat = CGFloat(drand48()) * 12 + 4
                c.setFillColor(neonColors[Int(drand48() * Double(neonColors.count))].cgColor)
                c.fill(CGRect(x: x, y: baseY - 2, width: w, height: 3))
            }
        }
    }

    // MARK: Tokyo Ground Detail — fallen cherry petals

    private func renderTokyoGroundDetail(tileWidth: CGFloat, groundHeight: CGFloat, seed: Int) -> UIImage {
        srand48(seed)
        let h: CGFloat = groundHeight + 20
        let size = CGSize(width: tileWidth, height: h)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let c = ctx.cgContext
            let baseY = h - groundHeight
            let petalColors: [UIColor] = [
                UIColor(red: 1.0, green: 0.70, blue: 0.80, alpha: 0.6),
                UIColor(red: 1.0, green: 0.80, blue: 0.85, alpha: 0.5),
            ]
            for _ in 0..<8 {
                let x = CGFloat(drand48()) * tileWidth
                let y = baseY - CGFloat(drand48()) * 12
                c.setFillColor(petalColors[Int(drand48() * Double(petalColors.count))].cgColor)
                c.fill(CGRect(x: x, y: y, width: 3, height: 2))
            }
        }
    }

    // MARK: Underwater Ground Detail — rising bubbles

    private func renderUnderwaterGroundDetail(tileWidth: CGFloat, groundHeight: CGFloat, seed: Int) -> UIImage {
        srand48(seed)
        let h: CGFloat = groundHeight + 20
        let size = CGSize(width: tileWidth, height: h)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let c = ctx.cgContext
            let baseY = h - groundHeight
            for _ in 0..<6 {
                let x = CGFloat(drand48()) * tileWidth
                let y = baseY - CGFloat(drand48()) * 18
                let r = CGFloat(drand48()) * 2 + 1.5
                c.setFillColor(UIColor(red: 0.65, green: 0.85, blue: 0.95, alpha: 0.35).cgColor)
                c.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
            }
            // Small seaweed strands
            for _ in 0..<5 {
                let x = CGFloat(drand48()) * tileWidth
                let strandH = CGFloat(drand48()) * 10 + 6
                c.setFillColor(UIColor(red: 0.15, green: 0.50, blue: 0.30, alpha: 0.5).cgColor)
                let path = CGMutablePath()
                path.move(to: CGPoint(x: x, y: baseY))
                path.addLine(to: CGPoint(x: x + 2, y: baseY - strandH))
                path.addLine(to: CGPoint(x: x + 3, y: baseY))
                path.closeSubpath()
                c.addPath(path); c.fillPath()
            }
        }
    }

    // MARK: Volcano Ground Detail — floating embers and ash

    private func renderVolcanoGroundDetail(tileWidth: CGFloat, groundHeight: CGFloat, seed: Int) -> UIImage {
        srand48(seed)
        let h: CGFloat = groundHeight + 20
        let size = CGSize(width: tileWidth, height: h)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let c = ctx.cgContext
            let baseY = h - groundHeight
            // Ember particles
            for _ in 0..<8 {
                let x = CGFloat(drand48()) * tileWidth
                let y = baseY - CGFloat(drand48()) * 16
                let bright = drand48() > 0.5
                c.setFillColor(bright
                    ? UIColor(red: 1.0, green: 0.55, blue: 0.10, alpha: 0.6).cgColor
                    : UIColor(red: 0.90, green: 0.30, blue: 0.08, alpha: 0.4).cgColor)
                c.fill(CGRect(x: x, y: y, width: 2, height: 2))
            }
            // Ash flecks
            for _ in 0..<6 {
                let x = CGFloat(drand48()) * tileWidth
                let y = baseY - CGFloat(drand48()) * 14
                c.setFillColor(UIColor(red: 0.30, green: 0.25, blue: 0.22, alpha: 0.4).cgColor)
                c.fill(CGRect(x: x, y: y, width: 2, height: 1))
            }
        }
    }

    // MARK: Arctic Ground Detail — snowflake particles

    private func renderArcticGroundDetail(tileWidth: CGFloat, groundHeight: CGFloat, seed: Int) -> UIImage {
        srand48(seed)
        let h: CGFloat = groundHeight + 20
        let size = CGSize(width: tileWidth, height: h)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let c = ctx.cgContext
            let baseY = h - groundHeight
            // Snow particles
            for _ in 0..<10 {
                let x = CGFloat(drand48()) * tileWidth
                let y = baseY - CGFloat(drand48()) * 18
                let r = CGFloat(drand48()) * 1.5 + 1
                c.setFillColor(UIColor(red: 0.95, green: 0.97, blue: 1.0, alpha: 0.5).cgColor)
                c.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
            }
            // Ice sparkle dots
            for _ in 0..<4 {
                let x = CGFloat(drand48()) * tileWidth
                let y = baseY - CGFloat(drand48()) * 8
                c.setFillColor(UIColor(red: 0.70, green: 0.85, blue: 1.0, alpha: 0.5).cgColor)
                c.fill(CGRect(x: x, y: y, width: 2, height: 2))
            }
        }
    }

    // MARK: Western Ground Detail — dust wisps and small rocks

    private func renderWesternGroundDetail(tileWidth: CGFloat, groundHeight: CGFloat, seed: Int) -> UIImage {
        srand48(seed)
        let h: CGFloat = groundHeight + 20
        let size = CGSize(width: tileWidth, height: h)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let c = ctx.cgContext
            let baseY = h - groundHeight
            // Dust wisps
            for _ in 0..<5 {
                let x = CGFloat(drand48()) * tileWidth
                let y = baseY - CGFloat(drand48()) * 10
                let w: CGFloat = CGFloat(drand48()) * 8 + 4
                c.setFillColor(UIColor(red: 0.75, green: 0.62, blue: 0.40, alpha: 0.25).cgColor)
                c.fill(CGRect(x: x, y: y, width: w, height: 2))
            }
            // Pebbles
            for _ in 0..<6 {
                let x = CGFloat(drand48()) * tileWidth
                let r = CGFloat(drand48()) * 2.0 + 1.5
                let gray = CGFloat(drand48()) * 0.15 + 0.45
                c.setFillColor(UIColor(red: gray, green: gray - 0.05, blue: gray - 0.12, alpha: 0.7).cgColor)
                c.fillEllipse(in: CGRect(x: x - r, y: baseY + 2 - r, width: r * 2, height: r * 2))
            }
        }
    }

    // MARK: Jungle Ground Detail — fern fronds and butterflies

    private func renderJungleGroundDetail(tileWidth: CGFloat, groundHeight: CGFloat, seed: Int) -> UIImage {
        srand48(seed)
        let h: CGFloat = groundHeight + 20
        let size = CGSize(width: tileWidth, height: h)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let c = ctx.cgContext
            let baseY = h - groundHeight
            // Fern fronds
            for _ in 0..<12 {
                let x = CGFloat(drand48()) * tileWidth
                let bladeH = CGFloat(drand48()) * 10 + 6
                let halfW: CGFloat = 2.0
                let r = 0.15 + CGFloat(drand48()) * 0.15
                let g = 0.42 + CGFloat(drand48()) * 0.20
                let b = 0.10 + CGFloat(drand48()) * 0.08
                c.setFillColor(UIColor(red: r, green: g, blue: b, alpha: 0.8).cgColor)
                let path = CGMutablePath()
                path.move(to: CGPoint(x: x - halfW, y: baseY))
                path.addLine(to: CGPoint(x: x, y: baseY - bladeH))
                path.addLine(to: CGPoint(x: x + halfW, y: baseY))
                path.closeSubpath()
                c.addPath(path); c.fillPath()
            }
            // Butterfly
            for _ in 0..<2 {
                let bx = CGFloat(drand48()) * tileWidth
                let by = baseY - CGFloat(drand48()) * 14 - 4
                let colors: [UIColor] = [
                    UIColor(red: 0.20, green: 0.60, blue: 0.90, alpha: 0.6),
                    UIColor(red: 0.90, green: 0.40, blue: 0.20, alpha: 0.6),
                ]
                c.setFillColor(colors[Int(drand48() * Double(colors.count))].cgColor)
                c.fill(CGRect(x: bx - 2, y: by, width: 2, height: 2))
                c.fill(CGRect(x: bx + 1, y: by, width: 2, height: 2))
            }
        }
    }

    // MARK: Egypt Ground Detail — sand particles and scarab hint

    private func renderEgyptGroundDetail(tileWidth: CGFloat, groundHeight: CGFloat, seed: Int) -> UIImage {
        srand48(seed)
        let h: CGFloat = groundHeight + 20
        let size = CGSize(width: tileWidth, height: h)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let c = ctx.cgContext
            let baseY = h - groundHeight
            // Blowing sand particles
            for _ in 0..<8 {
                let x = CGFloat(drand48()) * tileWidth
                let y = baseY - CGFloat(drand48()) * 14
                c.setFillColor(UIColor(red: 0.85, green: 0.72, blue: 0.45, alpha: 0.3).cgColor)
                c.fill(CGRect(x: x, y: y, width: 3, height: 1))
            }
        }
    }

    // MARK: Cave Ground Detail — dripping water and glowing spores

    private func renderCaveGroundDetail(tileWidth: CGFloat, groundHeight: CGFloat, seed: Int) -> UIImage {
        srand48(seed)
        let h: CGFloat = groundHeight + 20
        let size = CGSize(width: tileWidth, height: h)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let c = ctx.cgContext
            let baseY = h - groundHeight
            // Glowing spore dots
            for _ in 0..<6 {
                let x = CGFloat(drand48()) * tileWidth
                let y = baseY - CGFloat(drand48()) * 16
                let colors: [UIColor] = [
                    UIColor(red: 0.30, green: 0.85, blue: 0.50, alpha: 0.4),
                    UIColor(red: 0.50, green: 0.30, blue: 0.80, alpha: 0.3),
                ]
                c.setFillColor(colors[Int(drand48() * Double(colors.count))].cgColor)
                c.fill(CGRect(x: x, y: y, width: 2, height: 2))
            }
            // Water drip streaks
            for _ in 0..<3 {
                let x = CGFloat(drand48()) * tileWidth
                let dropH = CGFloat(drand48()) * 6 + 3
                c.setFillColor(UIColor(red: 0.40, green: 0.55, blue: 0.75, alpha: 0.3).cgColor)
                c.fill(CGRect(x: x, y: baseY - dropH, width: 1, height: dropH))
            }
        }
    }

    // MARK: Mountain Ground Detail — alpine grass and pebbles

    private func renderMountainGroundDetail(tileWidth: CGFloat, groundHeight: CGFloat, seed: Int) -> UIImage {
        srand48(seed)
        let h: CGFloat = groundHeight + 20
        let size = CGSize(width: tileWidth, height: h)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let c = ctx.cgContext
            let baseY = h - groundHeight
            // Sparse grass
            for _ in 0..<10 {
                let x = CGFloat(drand48()) * tileWidth
                let bladeH = CGFloat(drand48()) * 6 + 4
                let halfW: CGFloat = 1.5
                c.setFillColor(UIColor(red: 0.30 + CGFloat(drand48()) * 0.15,
                                        green: 0.48 + CGFloat(drand48()) * 0.15,
                                        blue: 0.20 + CGFloat(drand48()) * 0.10,
                                        alpha: 0.7).cgColor)
                let path = CGMutablePath()
                path.move(to: CGPoint(x: x - halfW, y: baseY))
                path.addLine(to: CGPoint(x: x, y: baseY - bladeH))
                path.addLine(to: CGPoint(x: x + halfW, y: baseY))
                path.closeSubpath()
                c.addPath(path); c.fillPath()
            }
            // Mountain pebbles
            for _ in 0..<6 {
                let x = CGFloat(drand48()) * tileWidth
                let r = CGFloat(drand48()) * 2.0 + 1.5
                let gray = CGFloat(drand48()) * 0.20 + 0.40
                c.setFillColor(UIColor(red: gray, green: gray - 0.03, blue: gray - 0.08, alpha: 0.7).cgColor)
                c.fillEllipse(in: CGRect(x: x - r, y: baseY + 2 - r, width: r * 2, height: r * 2))
            }
        }
    }

    // MARK: Space Ground Detail — sparks and steam vents

    private func renderSpaceGroundDetail(tileWidth: CGFloat, groundHeight: CGFloat, seed: Int) -> UIImage {
        srand48(seed)
        let h: CGFloat = groundHeight + 20
        let size = CGSize(width: tileWidth, height: h)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let c = ctx.cgContext
            let baseY = h - groundHeight
            // Steam vent plumes
            for _ in 0..<3 {
                let x = CGFloat(drand48()) * tileWidth
                let ventH = CGFloat(drand48()) * 10 + 5
                c.setFillColor(UIColor(red: 0.60, green: 0.65, blue: 0.75, alpha: 0.15).cgColor)
                c.fill(CGRect(x: x - 2, y: baseY - ventH, width: 5, height: ventH))
            }
            // Electric spark dots
            for _ in 0..<4 {
                let x = CGFloat(drand48()) * tileWidth
                let y = baseY - CGFloat(drand48()) * 12
                c.setFillColor(UIColor(red: 0.40, green: 0.70, blue: 1.0, alpha: 0.5).cgColor)
                c.fill(CGRect(x: x, y: y, width: 2, height: 2))
            }
        }
    }

    // MARK: Lagoon Ground Detail — coconut husks, wave lapping, crab

    private func renderLagoonGroundDetail(tileWidth: CGFloat, groundHeight: CGFloat, seed: Int) -> UIImage {
        srand48(seed)
        let h: CGFloat = groundHeight + 20
        let size = CGSize(width: tileWidth, height: h)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let c = ctx.cgContext
            let baseY = h - groundHeight
            // Wave foam lapping
            for _ in 0..<4 {
                let x = CGFloat(drand48()) * tileWidth
                let w: CGFloat = CGFloat(drand48()) * 12 + 6
                c.setFillColor(UIColor(red: 0.85, green: 0.92, blue: 0.96, alpha: 0.35).cgColor)
                c.fill(CGRect(x: x, y: baseY - 2, width: w, height: 3))
            }
            // Coconut husks
            for _ in 0..<3 {
                let x = CGFloat(drand48()) * tileWidth
                let r: CGFloat = CGFloat(drand48()) * 2.0 + 2.0
                c.setFillColor(UIColor(red: 0.48, green: 0.32, blue: 0.18, alpha: 0.5).cgColor)
                c.fillEllipse(in: CGRect(x: x - r, y: baseY + 4 - r, width: r * 2, height: r * 1.5))
            }
            // Tiny crab
            let crabX = CGFloat(drand48()) * tileWidth * 0.8 + tileWidth * 0.1
            c.setFillColor(UIColor(red: 0.85, green: 0.35, blue: 0.20, alpha: 0.5).cgColor)
            c.fill(CGRect(x: crabX, y: baseY + 2, width: 4, height: 3))
            c.fill(CGRect(x: crabX - 2, y: baseY + 1, width: 2, height: 2))
            c.fill(CGRect(x: crabX + 4, y: baseY + 1, width: 2, height: 2))
        }
    }

    // MARK: Los Angeles Ground Detail — heat shimmer, road cracks, palm shadows

    private func renderLosAngelesGroundDetail(tileWidth: CGFloat, groundHeight: CGFloat, seed: Int) -> UIImage {
        srand48(seed)
        let h: CGFloat = groundHeight + 20
        let size = CGSize(width: tileWidth, height: h)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let c = ctx.cgContext
            let baseY = h - groundHeight
            // Heat shimmer lines
            for _ in 0..<3 {
                let x = CGFloat(drand48()) * tileWidth
                let w: CGFloat = CGFloat(drand48()) * 15 + 8
                c.setFillColor(UIColor(red: 0.90, green: 0.80, blue: 0.65, alpha: 0.12).cgColor)
                c.fill(CGRect(x: x, y: baseY - CGFloat(drand48()) * 8, width: w, height: 1.5))
            }
            // Road cracks
            for _ in 0..<5 {
                let x = CGFloat(drand48()) * tileWidth
                let crackH = CGFloat(drand48()) * 8 + 3
                c.setFillColor(UIColor(red: 0.15, green: 0.15, blue: 0.16, alpha: 0.3).cgColor)
                c.fill(CGRect(x: x, y: baseY + 2, width: 1.5, height: crackH))
            }
            // Palm tree shadow streaks
            for _ in 0..<2 {
                let x = CGFloat(drand48()) * tileWidth
                let sw: CGFloat = CGFloat(drand48()) * 20 + 10
                c.setFillColor(UIColor(red: 0.10, green: 0.10, blue: 0.12, alpha: 0.08).cgColor)
                c.fill(CGRect(x: x, y: baseY + 1, width: sw, height: 4))
            }
        }
    }

    // MARK: London Ground Detail — rain drops, puddle highlights, leaf scraps

    private func renderLondonGroundDetail(tileWidth: CGFloat, groundHeight: CGFloat, seed: Int) -> UIImage {
        srand48(seed)
        let h: CGFloat = groundHeight + 20
        let size = CGSize(width: tileWidth, height: h)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let c = ctx.cgContext
            let baseY = h - groundHeight
            // Rain drop splashes
            for _ in 0..<8 {
                let x = CGFloat(drand48()) * tileWidth
                let y = baseY - CGFloat(drand48()) * 12
                c.setFillColor(UIColor(red: 0.55, green: 0.60, blue: 0.70, alpha: 0.25).cgColor)
                c.fillEllipse(in: CGRect(x: x - 1.5, y: y - 1.5, width: 3, height: 3))
            }
            // Puddle reflections
            for _ in 0..<3 {
                let x = CGFloat(drand48()) * tileWidth
                let pw: CGFloat = CGFloat(drand48()) * 12 + 5
                c.setFillColor(UIColor(red: 0.42, green: 0.48, blue: 0.58, alpha: 0.20).cgColor)
                c.fillEllipse(in: CGRect(x: x, y: baseY + 2, width: pw, height: pw * 0.4))
            }
            // Autumn leaves
            for _ in 0..<4 {
                let x = CGFloat(drand48()) * tileWidth
                let r = CGFloat(drand48()) * 0.25 + 0.55
                let g = CGFloat(drand48()) * 0.15 + 0.25
                c.setFillColor(UIColor(red: r, green: g, blue: 0.10, alpha: 0.35).cgColor)
                c.fill(CGRect(x: x, y: baseY + CGFloat(drand48()) * 6, width: 3, height: 2))
            }
        }
    }
}
