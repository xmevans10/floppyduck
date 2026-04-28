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
        let ps: CGFloat = 4  // pixel size

        let gridW = Int(w / ps)
        // Generate stepped hill silhouette using overlapping bumps
        var heightMap = [Int](repeating: 1, count: gridW)

        // Deterministic hill bumps — tall rolling hills
        let bumps: [(center: Int, radius: Int, peak: Int)] = [
            (gridW / 8,     25, 25),
            (gridW / 4,     30, 35),
            (gridW * 3 / 8, 18, 18),
            (gridW / 2,     28, 30),
            (gridW * 5 / 8, 22, 22),
            (gridW * 3 / 4, 30, 33),
            (gridW * 7 / 8, 20, 20),
        ]

        for bump in bumps {
            for x in max(0, bump.center - bump.radius)..<min(gridW, bump.center + bump.radius) {
                let dist = abs(x - bump.center)
                let nd = CGFloat(dist) / CGFloat(bump.radius)
                let bh = Int(CGFloat(bump.peak) * (1.0 - nd * nd))
                heightMap[x] = max(heightMap[x], bh)
            }
        }

        let hillBase  = UIColor(red: 0.45, green: 0.68, blue: 0.38, alpha: 0.50)
        let hillMid   = UIColor(red: 0.52, green: 0.74, blue: 0.42, alpha: 0.45)
        let hillTop   = UIColor(red: 0.38, green: 0.58, blue: 0.32, alpha: 0.55)  // darker top edge
        let hillLight = UIColor(red: 0.58, green: 0.80, blue: 0.50, alpha: 0.35)  // highlight

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let c = ctx.cgContext
            for x in 0..<gridW {
                let hillH = heightMap[x]
                for y in 0..<hillH {
                    let yPos = h - CGFloat(y + 1) * ps
                    // Gradient within hill: top edge dark, middle light, base medium
                    let ratio = CGFloat(y) / max(1, CGFloat(hillH))
                    let color: UIColor
                    if y == hillH - 1 {
                        color = hillTop
                    } else if y == hillH - 2 && hillH > 3 {
                        color = hillLight
                    } else if ratio > 0.6 {
                        color = hillMid
                    } else {
                        color = hillBase
                    }
                    c.setFillColor(color.cgColor)
                    c.fill(CGRect(x: CGFloat(x) * ps, y: yPos, width: ps, height: ps))
                }
            }

            // Scatter pixel bushes/details on hill tops
            let bushColor = UIColor(red: 0.35, green: 0.55, blue: 0.28, alpha: 0.50)
            c.setFillColor(bushColor.cgColor)
            for x in stride(from: 3, to: gridW - 3, by: 7) {
                let hillH = heightMap[x]
                if hillH > 4 {
                    let yPos = h - CGFloat(hillH + 1) * ps
                    c.fill(CGRect(x: CGFloat(x) * ps, y: yPos, width: ps * 2, height: ps))
                    c.fill(CGRect(x: CGFloat(x - 1) * ps, y: yPos + ps, width: ps, height: ps))
                    c.fill(CGRect(x: CGFloat(x + 2) * ps, y: yPos + ps, width: ps, height: ps))
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
            (gridW / 8, 25, 25), (gridW / 4, 30, 35), (gridW * 3 / 8, 18, 18),
            (gridW / 2, 28, 30), (gridW * 5 / 8, 22, 22), (gridW * 3 / 4, 30, 33),
            (gridW * 7 / 8, 20, 20),
        ]
        for bump in bumps {
            for x in max(0, bump.center - bump.radius)..<min(gridW, bump.center + bump.radius) {
                let dist = abs(x - bump.center)
                let nd = CGFloat(dist) / CGFloat(bump.radius)
                heightMap[x] = max(heightMap[x], Int(CGFloat(bump.peak) * (1.0 - nd * nd)))
            }
        }

        let hillBase  = UIColor(red: 0.55, green: 0.35, blue: 0.18, alpha: 0.55)
        let hillMid   = UIColor(red: 0.65, green: 0.42, blue: 0.20, alpha: 0.50)
        let hillTop   = UIColor(red: 0.45, green: 0.28, blue: 0.12, alpha: 0.60)
        let hillLight = UIColor(red: 0.80, green: 0.55, blue: 0.25, alpha: 0.40)

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let c = ctx.cgContext
            for x in 0..<gridW {
                let hillH = heightMap[x]
                for y in 0..<hillH {
                    let yPos = h - CGFloat(y + 1) * ps
                    let ratio = CGFloat(y) / max(1, CGFloat(hillH))
                    let color: UIColor
                    if y == hillH - 1 { color = hillTop }
                    else if y == hillH - 2 && hillH > 3 { color = hillLight }
                    else if ratio > 0.6 { color = hillMid }
                    else { color = hillBase }
                    c.setFillColor(color.cgColor)
                    c.fill(CGRect(x: CGFloat(x) * ps, y: yPos, width: ps, height: ps))
                }
            }
        }
    }

    // MARK: Night Hills — dark blue silhouettes

    private func renderNightHills() -> UIImage {
        let w: CGFloat = GK.worldWidth * 2
        let h: CGFloat = 300
        let ps: CGFloat = 4
        let gridW = Int(w / ps)

        var heightMap = [Int](repeating: 1, count: gridW)
        let bumps: [(center: Int, radius: Int, peak: Int)] = [
            (gridW / 8, 25, 25), (gridW / 4, 30, 35), (gridW * 3 / 8, 18, 18),
            (gridW / 2, 28, 30), (gridW * 5 / 8, 22, 22), (gridW * 3 / 4, 30, 33),
            (gridW * 7 / 8, 20, 20),
        ]
        for bump in bumps {
            for x in max(0, bump.center - bump.radius)..<min(gridW, bump.center + bump.radius) {
                let dist = abs(x - bump.center)
                let nd = CGFloat(dist) / CGFloat(bump.radius)
                heightMap[x] = max(heightMap[x], Int(CGFloat(bump.peak) * (1.0 - nd * nd)))
            }
        }

        let hillBase  = UIColor(red: 0.08, green: 0.10, blue: 0.22, alpha: 0.65)
        let hillMid   = UIColor(red: 0.10, green: 0.14, blue: 0.28, alpha: 0.60)
        let hillTop   = UIColor(red: 0.06, green: 0.08, blue: 0.18, alpha: 0.70)
        let hillLight = UIColor(red: 0.14, green: 0.18, blue: 0.35, alpha: 0.45)

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let c = ctx.cgContext
            for x in 0..<gridW {
                let hillH = heightMap[x]
                for y in 0..<hillH {
                    let yPos = h - CGFloat(y + 1) * ps
                    let ratio = CGFloat(y) / max(1, CGFloat(hillH))
                    let color: UIColor
                    if y == hillH - 1 { color = hillTop }
                    else if y == hillH - 2 && hillH > 3 { color = hillLight }
                    else if ratio > 0.6 { color = hillMid }
                    else { color = hillBase }
                    c.setFillColor(color.cgColor)
                    c.fill(CGRect(x: CGFloat(x) * ps, y: yPos, width: ps, height: ps))
                }
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

        // Coral reef — denser, more varied bumps
        var heightMap = [Int](repeating: 0, count: gridW)
        let bumps: [(center: Int, radius: Int, peak: Int)] = [
            (gridW / 10, 20, 25), (gridW / 5, 30, 40), (gridW * 3 / 10, 15, 20),
            (gridW * 2 / 5, 35, 45), (gridW / 2, 17, 17), (gridW * 3 / 5, 25, 35),
            (gridW * 7 / 10, 37, 50), (gridW * 4 / 5, 20, 30), (gridW * 9 / 10, 27, 37),
        ]
        for bump in bumps {
            for x in max(0, bump.center - bump.radius)..<min(gridW, bump.center + bump.radius) {
                let dist = abs(x - bump.center)
                let nd = CGFloat(dist) / CGFloat(bump.radius)
                heightMap[x] = max(heightMap[x], Int(CGFloat(bump.peak) * (1.0 - nd * nd)))
            }
        }

        // Coral palette with more variety
        let coralPalette: [(base: UIColor, mid: UIColor, top: UIColor)] = [
            (UIColor(red: 0.85, green: 0.30, blue: 0.40, alpha: 0.65),
             UIColor(red: 0.95, green: 0.45, blue: 0.50, alpha: 0.60),
             UIColor(red: 0.75, green: 0.22, blue: 0.32, alpha: 0.70)),
            (UIColor(red: 0.90, green: 0.60, blue: 0.20, alpha: 0.60),
             UIColor(red: 1.0, green: 0.75, blue: 0.35, alpha: 0.55),
             UIColor(red: 0.80, green: 0.50, blue: 0.15, alpha: 0.65)),
            (UIColor(red: 0.55, green: 0.25, blue: 0.70, alpha: 0.60),
             UIColor(red: 0.70, green: 0.40, blue: 0.85, alpha: 0.55),
             UIColor(red: 0.45, green: 0.18, blue: 0.58, alpha: 0.65)),
            (UIColor(red: 0.20, green: 0.65, blue: 0.55, alpha: 0.60),
             UIColor(red: 0.30, green: 0.78, blue: 0.65, alpha: 0.55),
             UIColor(red: 0.15, green: 0.52, blue: 0.45, alpha: 0.65)),
        ]

        var bumpOwner = [Int](repeating: 0, count: gridW)
        for (bi, bump) in bumps.enumerated() {
            for x in max(0, bump.center - bump.radius)..<min(gridW, bump.center + bump.radius) {
                let dist = abs(x - bump.center)
                let nd = CGFloat(dist) / CGFloat(bump.radius)
                let bh = Int(CGFloat(bump.peak) * (1.0 - nd * nd))
                if bh >= heightMap[x] { bumpOwner[x] = bi % coralPalette.count }
            }
        }

        let lightRay = UIColor(red: 0.60, green: 0.85, blue: 0.95, alpha: 0.08)
        let bubbleC  = UIColor(red: 0.75, green: 0.90, blue: 1.0, alpha: 0.30)

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let c = ctx.cgContext

            // Light rays from surface — angled shafts of light
            let rayPositions: [CGFloat] = [w * 0.15, w * 0.40, w * 0.65, w * 0.85]
            for rx in rayPositions {
                c.setFillColor(lightRay.cgColor)
                // Diagonal ray — a tall parallelogram
                c.saveGState()
                let rayPath = CGMutablePath()
                rayPath.move(to: CGPoint(x: rx, y: 0))
                rayPath.addLine(to: CGPoint(x: rx + ps * 4, y: 0))
                rayPath.addLine(to: CGPoint(x: rx + ps * 2, y: h * 0.8))
                rayPath.addLine(to: CGPoint(x: rx - ps * 2, y: h * 0.8))
                rayPath.closeSubpath()
                c.addPath(rayPath)
                c.fillPath()
                c.restoreGState()
            }

            // Coral formations
            for x in 0..<gridW {
                let coralH = heightMap[x]
                guard coralH > 0 else { continue }
                let pal = coralPalette[bumpOwner[x]]
                for y in 0..<coralH {
                    let yPos = h - CGFloat(y + 1) * ps
                    let ratio = CGFloat(y) / max(1, CGFloat(coralH))
                    let color: UIColor
                    if y == coralH - 1 { color = pal.top }
                    else if ratio > 0.5 { color = pal.mid }
                    else { color = pal.base }
                    c.setFillColor(color.cgColor)
                    c.fill(CGRect(x: CGFloat(x) * ps, y: yPos, width: ps, height: ps))
                }
            }

            // Coral nubs and branching tips
            let nubColors: [UIColor] = [
                UIColor(red: 1.0, green: 0.50, blue: 0.60, alpha: 0.50),
                UIColor(red: 0.60, green: 0.90, blue: 0.70, alpha: 0.50),
                UIColor(red: 0.95, green: 0.80, blue: 0.30, alpha: 0.50),
            ]
            for x in stride(from: 3, to: gridW - 3, by: 7) {
                let ch = heightMap[x]
                if ch > 3 {
                    let yPos = h - CGFloat(ch + 1) * ps
                    c.setFillColor(nubColors[x % nubColors.count].cgColor)
                    c.fill(CGRect(x: CGFloat(x) * ps, y: yPos, width: ps, height: ps))
                    // Branching tip
                    if ch > 6 {
                        c.fill(CGRect(x: CGFloat(x - 1) * ps, y: yPos + ps, width: ps, height: ps))
                        c.fill(CGRect(x: CGFloat(x + 1) * ps, y: yPos + ps, width: ps, height: ps))
                    }
                }
            }

            // Bubbles rising from coral
            c.setFillColor(bubbleC.cgColor)
            for i in stride(from: 0, to: gridW, by: gridW / 8) {
                let bx = CGFloat(i) * ps + ps * 3
                let by = h * 0.2 + CGFloat(i % 4) * ps * 3
                c.fill(CGRect(x: bx, y: by, width: ps, height: ps))
                c.fill(CGRect(x: bx + ps * 2, y: by - ps * 2, width: ps * 0.75, height: ps * 0.75))
            }
        }
    }

    // MARK: Volcano Hills — jagged rocky mountains with lava glow

    private func renderVolcanoHills() -> UIImage {
        let w: CGFloat = GK.worldWidth * 2
        let h: CGFloat = 300
        let ps: CGFloat = 4
        let gridW = Int(w / ps)

        // Jagged peaks — sharper bumps with smaller radii, taller for drama
        var heightMap = [Int](repeating: 0, count: gridW)
        let bumps: [(center: Int, radius: Int, peak: Int)] = [
            (gridW / 10, 15, 35), (gridW / 5, 25, 60), (gridW * 3 / 10, 10, 25),
            (gridW * 2 / 5, 20, 50), (gridW / 2, 12, 30), (gridW * 3 / 5, 30, 70),
            (gridW * 7 / 10, 15, 40), (gridW * 4 / 5, 22, 65), (gridW * 9 / 10, 17, 45),
        ]
        // Track which bump is tallest (the erupting crater)
        var tallestPeak = 0; var tallestCenter = gridW / 2
        for bump in bumps {
            if bump.peak > tallestPeak { tallestPeak = bump.peak; tallestCenter = bump.center }
            for x in max(0, bump.center - bump.radius)..<min(gridW, bump.center + bump.radius) {
                let dist = abs(x - bump.center)
                let nd = CGFloat(dist) / CGFloat(bump.radius)
                let bh = Int(CGFloat(bump.peak) * max(0, 1.0 - nd * nd * nd))
                heightMap[x] = max(heightMap[x], bh)
            }
        }

        // Lava river channels — valleys between peaks glow with flowing lava
        var lavaMap = [Bool](repeating: false, count: gridW)
        for x in 0..<gridW {
            // Low valleys (height < 4) get lava
            if heightMap[x] < 4 && heightMap[x] > 0 { lavaMap[x] = true }
            // Also fill gaps between adjacent tall peaks
            if heightMap[x] == 0 {
                let leftH = x > 0 ? heightMap[x - 1] : 0
                let rightH = x < gridW - 1 ? heightMap[x + 1] : 0
                if leftH > 3 || rightH > 3 { lavaMap[x] = true; heightMap[x] = 2 }
            }
        }

        let rockBase   = UIColor(red: 0.22, green: 0.12, blue: 0.08, alpha: 0.80)
        let rockMid    = UIColor(red: 0.32, green: 0.20, blue: 0.12, alpha: 0.75)
        let rockLight  = UIColor(red: 0.40, green: 0.28, blue: 0.18, alpha: 0.65)
        let rockTop    = UIColor(red: 0.18, green: 0.10, blue: 0.06, alpha: 0.85)
        let lavaGlow   = UIColor(red: 1.0, green: 0.45, blue: 0.10, alpha: 0.65)
        let lavaHot    = UIColor(red: 1.0, green: 0.70, blue: 0.20, alpha: 0.55)
        let lavaBright = UIColor(red: 1.0, green: 0.85, blue: 0.35, alpha: 0.50)
        let smokeColor = UIColor(red: 0.25, green: 0.20, blue: 0.18, alpha: 0.25)
        let emberColor = UIColor(red: 1.0, green: 0.55, blue: 0.15, alpha: 0.45)

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let c = ctx.cgContext
            for x in 0..<gridW {
                let mtnH = heightMap[x]
                guard mtnH > 0 else { continue }
                let isLava = lavaMap[x]

                for y in 0..<mtnH {
                    let yPos = h - CGFloat(y + 1) * ps
                    let ratio = CGFloat(y) / max(1, CGFloat(mtnH))
                    let color: UIColor

                    if isLava && mtnH <= 4 {
                        // Lava river channel — bright flowing lava
                        color = y == mtnH - 1 ? lavaBright : (y == 0 ? lavaGlow : lavaHot)
                    } else if y <= 1 {
                        color = lavaGlow
                    } else if y == 2 && mtnH > 6 {
                        color = lavaHot
                    } else if y == mtnH - 1 {
                        color = rockTop
                    } else if ratio > 0.7 {
                        color = rockLight
                    } else if ratio > 0.4 {
                        // Rock striations — alternating bands for texture
                        color = (y % 3 == 0) ? rockMid : rockBase
                    } else {
                        color = rockBase
                    }
                    c.setFillColor(color.cgColor)
                    c.fill(CGRect(x: CGFloat(x) * ps, y: yPos, width: ps, height: ps))
                }

                // Crater hollow at tallest peak — carve a V shape at the top
                if abs(x - tallestCenter) < 3 && mtnH == tallestPeak {
                    let craterDepth = 3 - abs(x - tallestCenter)
                    for dy in 0..<craterDepth {
                        let craterY = h - CGFloat(mtnH - dy) * ps
                        c.setFillColor(lavaHot.cgColor)
                        c.fill(CGRect(x: CGFloat(x) * ps, y: craterY, width: ps, height: ps))
                    }
                }
            }

            // Smoke wisps rising from crater
            let smokeBase = h - CGFloat(tallestPeak + 1) * ps
            for i in 0..<4 {
                let sx = CGFloat(tallestCenter) * ps + CGFloat(i - 2) * ps * 2
                let sy = smokeBase - CGFloat(i) * ps * 2
                c.setFillColor(smokeColor.cgColor)
                c.fill(CGRect(x: sx, y: sy, width: ps * 2, height: ps))
                c.fill(CGRect(x: sx + ps, y: sy - ps, width: ps, height: ps))
            }

            // Ember particles floating above lava
            for i in 0..<6 {
                let ex = CGFloat(i * gridW / 6 + 3) * ps
                let ey = h - CGFloat(5 + (i % 3) * 4) * ps
                c.setFillColor(emberColor.cgColor)
                c.fill(CGRect(x: ex, y: ey, width: ps, height: ps))
            }
        }
    }

    // MARK: Arctic Hills — snow-capped mountain peaks

    private func renderArcticHills() -> UIImage {
        let w: CGFloat = GK.worldWidth * 2
        let h: CGFloat = 300
        let ps: CGFloat = 4
        let gridW = Int(w / ps)

        // Taller, more dramatic glacier peaks
        var heightMap = [Int](repeating: 1, count: gridW)
        let bumps: [(center: Int, radius: Int, peak: Int)] = [
            (gridW / 8, 35, 35), (gridW / 4, 45, 55), (gridW * 3 / 8, 20, 25),
            (gridW / 2, 40, 50), (gridW * 5 / 8, 30, 35), (gridW * 3 / 4, 50, 60),
            (gridW * 7 / 8, 25, 30),
        ]
        for bump in bumps {
            for x in max(0, bump.center - bump.radius)..<min(gridW, bump.center + bump.radius) {
                let dist = abs(x - bump.center)
                let nd = CGFloat(dist) / CGFloat(bump.radius)
                heightMap[x] = max(heightMap[x], Int(CGFloat(bump.peak) * (1.0 - nd * nd)))
            }
        }

        let rockBase = UIColor(red: 0.42, green: 0.50, blue: 0.60, alpha: 0.55)
        let rockMid  = UIColor(red: 0.52, green: 0.60, blue: 0.70, alpha: 0.50)
        let snowTop  = UIColor(red: 0.95, green: 0.97, blue: 1.0, alpha: 0.70)
        let snowMid  = UIColor(red: 0.85, green: 0.90, blue: 0.95, alpha: 0.60)
        let icicle   = UIColor(red: 0.80, green: 0.92, blue: 0.98, alpha: 0.50)
        // Aurora colors
        let auroraG  = UIColor(red: 0.20, green: 0.80, blue: 0.45, alpha: 0.12)
        let auroraB  = UIColor(red: 0.25, green: 0.55, blue: 0.85, alpha: 0.10)
        let auroraP  = UIColor(red: 0.55, green: 0.30, blue: 0.75, alpha: 0.08)

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let c = ctx.cgContext

            // Aurora borealis — wavy bands of green/blue/purple in upper portion
            let aurColors = [auroraG, auroraB, auroraP, auroraG, auroraB]
            for (i, ac) in aurColors.enumerated() {
                c.setFillColor(ac.cgColor)
                let bandY = CGFloat(i) * ps * 3 + ps * 2
                let bandH = ps * 2
                // Wavy band using sine
                for x in 0..<gridW {
                    let xF = CGFloat(x) / CGFloat(gridW)
                    let wave = sin(xF * .pi * 3.0 + CGFloat(i) * 1.2) * ps * 2
                    c.fill(CGRect(x: CGFloat(x) * ps, y: bandY + wave, width: ps, height: bandH))
                }
            }

            // Mountain peaks
            for x in 0..<gridW {
                let mtnH = heightMap[x]
                for y in 0..<mtnH {
                    let yPos = h - CGFloat(y + 1) * ps
                    let ratio = CGFloat(y) / max(1, CGFloat(mtnH))
                    let color: UIColor
                    if ratio > 0.80 { color = snowTop }
                    else if ratio > 0.65 { color = snowMid }
                    else if ratio > 0.35 {
                        // Rock striations
                        color = (y % 2 == 0) ? rockMid : rockBase
                    } else { color = rockBase }
                    c.setFillColor(color.cgColor)
                    c.fill(CGRect(x: CGFloat(x) * ps, y: yPos, width: ps, height: ps))
                }

                // Icicle hanging from snow edge
                if mtnH > 5 {
                    let leftH = x > 0 ? heightMap[x - 1] : 0
                    if leftH < mtnH - 2 && (x % 5 == 0) {
                        let iceBase = h - CGFloat(mtnH - 2) * ps
                        c.setFillColor(icicle.cgColor)
                        c.fill(CGRect(x: CGFloat(x) * ps, y: iceBase, width: ps, height: ps * 2))
                    }
                }
            }
        }
    }

    // MARK: Space Terrain Hills — distant cratered planet surface

    private func renderSpaceTerrainHills() -> UIImage {
        let w: CGFloat = GK.worldWidth * 2
        let h: CGFloat = 300
        let ps: CGFloat = 4
        let gridW = Int(w / ps)

        // Lumpy alien terrain
        var heightMap = [Int](repeating: 2, count: gridW)
        let bumps: [(center: Int, radius: Int, peak: Int)] = [
            (gridW / 8, 30, 25), (gridW / 4, 40, 35), (gridW * 3 / 8, 20, 15),
            (gridW / 2, 35, 30), (gridW * 3 / 5, 45, 40), (gridW * 3 / 4, 25, 22),
            (gridW * 9 / 10, 35, 27),
        ]
        for bump in bumps {
            for x in max(0, bump.center - bump.radius)..<min(gridW, bump.center + bump.radius) {
                let dist = abs(x - bump.center)
                let nd = CGFloat(dist) / CGFloat(bump.radius)
                heightMap[x] = max(heightMap[x], Int(CGFloat(bump.peak) * (1.0 - nd * nd)))
            }
        }

        let surfBase = UIColor(red: 0.15, green: 0.10, blue: 0.25, alpha: 0.65)
        let surfMid  = UIColor(red: 0.22, green: 0.15, blue: 0.35, alpha: 0.60)
        let surfTop  = UIColor(red: 0.12, green: 0.08, blue: 0.20, alpha: 0.70)
        let surfDust = UIColor(red: 0.18, green: 0.13, blue: 0.28, alpha: 0.55)

        // More craters with depth
        let craters: [(cx: Int, r: Int)] = [
            (gridW / 8, 4), (gridW / 4, 6), (gridW * 2 / 5, 3),
            (gridW * 3 / 5, 7), (gridW * 3 / 4, 5), (gridW * 7 / 8, 4),
        ]
        var craterMap = [Bool](repeating: false, count: gridW)
        var craterInner = [Bool](repeating: false, count: gridW)
        for crater in craters {
            for x in max(0, crater.cx - crater.r)..<min(gridW, crater.cx + crater.r) {
                craterMap[x] = true
                let dist = abs(x - crater.cx)
                if dist < crater.r {
                    let dip = Int(CGFloat(crater.r - dist) * 0.6)
                    heightMap[x] = max(2, heightMap[x] - dip)
                    if dist < crater.r / 2 { craterInner[x] = true }
                }
            }
        }
        let craterRim   = UIColor(red: 0.28, green: 0.20, blue: 0.42, alpha: 0.55)
        let craterFloor = UIColor(red: 0.10, green: 0.06, blue: 0.18, alpha: 0.70)

        // Nebula glow — faint colored patches in sky
        let nebulaA = UIColor(red: 0.20, green: 0.08, blue: 0.40, alpha: 0.10)
        let nebulaB = UIColor(red: 0.08, green: 0.15, blue: 0.35, alpha: 0.08)
        // Distant planet
        let planetColor = UIColor(red: 0.35, green: 0.25, blue: 0.50, alpha: 0.30)
        let planetLight = UIColor(red: 0.50, green: 0.40, blue: 0.65, alpha: 0.25)

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let c = ctx.cgContext

            // Nebula glow patches
            c.setFillColor(nebulaA.cgColor)
            c.fill(CGRect(x: w * 0.25, y: ps * 2, width: w * 0.3, height: ps * 8))
            c.setFillColor(nebulaB.cgColor)
            c.fill(CGRect(x: w * 0.60, y: ps * 4, width: w * 0.25, height: ps * 6))

            // Distant planet (small circle in sky)
            let planetCX = w * 0.78, planetCY: CGFloat = ps * 6
            let planetR = 5
            for dy in -planetR...planetR {
                for dx in -planetR...planetR {
                    let dist = sqrt(CGFloat(dx * dx + dy * dy))
                    if dist <= CGFloat(planetR) {
                        let pc = dx < 0 ? planetLight : planetColor
                        c.setFillColor(pc.cgColor)
                        c.fill(CGRect(x: planetCX + CGFloat(dx) * ps,
                                      y: planetCY + CGFloat(dy) * ps,
                                      width: ps, height: ps))
                    }
                }
            }

            // Terrain
            for x in 0..<gridW {
                let mtnH = heightMap[x]
                for y in 0..<mtnH {
                    let yPos = h - CGFloat(y + 1) * ps
                    let ratio = CGFloat(y) / max(1, CGFloat(mtnH))
                    var color: UIColor
                    if craterInner[x] && y < 3 { color = craterFloor }
                    else if y == mtnH - 1 { color = surfTop }
                    else if ratio > 0.5 { color = surfMid }
                    else { color = (x + y) % 4 == 0 ? surfDust : surfBase }
                    if craterMap[x] && y == mtnH - 1 { color = craterRim }
                    c.setFillColor(color.cgColor)
                    c.fill(CGRect(x: CGFloat(x) * ps, y: yPos, width: ps, height: ps))
                }
            }

            // Floating asteroid silhouettes in sky
            let asterC = UIColor(red: 0.20, green: 0.15, blue: 0.30, alpha: 0.25)
            for (ax, ay, ar) in [(w * 0.12, ps * 10, 2), (w * 0.45, ps * 5, 1), (w * 0.90, ps * 8, 2)] as [(CGFloat, CGFloat, Int)] {
                for dy in -ar...ar {
                    for dx in -ar...ar {
                        if abs(dx) + abs(dy) <= ar + 1 {
                            c.setFillColor(asterC.cgColor)
                            c.fill(CGRect(x: ax + CGFloat(dx) * ps, y: ay + CGFloat(dy) * ps, width: ps, height: ps))
                        }
                    }
                }
            }
        }
    }

    // MARK: Lagoon Island Hills — gentle tropical island mounds with palm silhouettes

    private func renderLagoonIslandHills() -> UIImage {
        let w: CGFloat = GK.worldWidth * 2
        let h: CGFloat = 300
        let ps: CGFloat = 4
        let gridW = Int(w / ps)

        var heightMap = [Int](repeating: 0, count: gridW)
        // Lush tropical island mounds — tall and rolling
        let bumps: [(center: Int, radius: Int, peak: Int)] = [
            (gridW / 8, 35, 28), (gridW / 4, 45, 38), (gridW * 2 / 5, 30, 22),
            (gridW * 3 / 5, 40, 32), (gridW * 4 / 5, 35, 26),
        ]
        for bump in bumps {
            for x in max(0, bump.center - bump.radius)..<min(gridW, bump.center + bump.radius) {
                let dist = abs(x - bump.center)
                let nd = CGFloat(dist) / CGFloat(bump.radius)
                heightMap[x] = max(heightMap[x], Int(CGFloat(bump.peak) * (1.0 - nd * nd)))
            }
        }

        let islandBase = UIColor(red: 0.18, green: 0.48, blue: 0.32, alpha: 0.55)
        let islandMid  = UIColor(red: 0.22, green: 0.55, blue: 0.38, alpha: 0.50)
        let islandTop  = UIColor(red: 0.28, green: 0.62, blue: 0.42, alpha: 0.60)

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let c = ctx.cgContext

            // Draw island terrain
            for x in 0..<gridW {
                let mH = heightMap[x]
                for y in 0..<mH {
                    let yPos = h - CGFloat(y + 1) * ps
                    let ratio = CGFloat(y) / max(1, CGFloat(mH))
                    let color = y == mH - 1 ? islandTop : (ratio > 0.5 ? islandMid : islandBase)
                    c.setFillColor(color.cgColor)
                    c.fill(CGRect(x: CGFloat(x) * ps, y: yPos, width: ps, height: ps))
                }
            }

            // ── MASSIVE pirate ship ──
            let shipBaseX = w * 0.62
            let waterLine = h - CGFloat(12) * ps  // sits above water level

            let darkWood  = UIColor(red: 0.28, green: 0.16, blue: 0.08, alpha: 0.55)
            let midWood   = UIColor(red: 0.38, green: 0.22, blue: 0.10, alpha: 0.50)
            let lightWood = UIColor(red: 0.48, green: 0.30, blue: 0.14, alpha: 0.45)
            let sailWhite = UIColor(red: 0.92, green: 0.88, blue: 0.80, alpha: 0.40)
            let sailShadow = UIColor(red: 0.78, green: 0.74, blue: 0.68, alpha: 0.35)
            let mastColor = UIColor(red: 0.22, green: 0.14, blue: 0.06, alpha: 0.55)
            let flagBlack = UIColor(red: 0.10, green: 0.08, blue: 0.05, alpha: 0.55)
            let skullWhite = UIColor(red: 0.90, green: 0.85, blue: 0.75, alpha: 0.50)

            // Hull — wide curved shape (20px wide, 8px tall)
            for row in 0..<8 {
                let yPos = waterLine - CGFloat(row) * ps
                // Hull narrows at bottom, widens at top (waterline)
                let inset = max(0, 3 - row / 2)
                let hullW = 20 - inset * 2
                let startX = shipBaseX + CGFloat(inset) * ps
                let color = row < 2 ? darkWood : (row < 5 ? midWood : lightWood)
                c.setFillColor(color.cgColor)
                for col in 0..<hullW {
                    c.fill(CGRect(x: startX + CGFloat(col) * ps, y: yPos, width: ps, height: ps))
                }
            }

            // Hull stripe (waterline)
            c.setFillColor(UIColor(red: 0.60, green: 0.25, blue: 0.10, alpha: 0.40).cgColor)
            for col in 0..<18 {
                c.fill(CGRect(x: shipBaseX + CGFloat(col + 1) * ps, y: waterLine - ps, width: ps, height: ps))
            }

            // Bow (pointed front) — triangle
            c.setFillColor(darkWood.cgColor)
            c.fill(CGRect(x: shipBaseX - ps, y: waterLine - ps * 3, width: ps, height: ps * 2))
            c.fill(CGRect(x: shipBaseX - ps * 2, y: waterLine - ps * 2, width: ps, height: ps))
            // Bowsprit
            c.fill(CGRect(x: shipBaseX - ps * 4, y: waterLine - ps * 6, width: ps * 3, height: ps))

            // Stern (raised back)
            let sternX = shipBaseX + ps * 17
            c.setFillColor(midWood.cgColor)
            for row in 0..<4 {
                c.fill(CGRect(x: sternX, y: waterLine - CGFloat(8 + row) * ps, width: ps * 3, height: ps))
            }
            // Stern windows
            c.setFillColor(UIColor(red: 1.0, green: 0.85, blue: 0.40, alpha: 0.35).cgColor)
            c.fill(CGRect(x: sternX + ps, y: waterLine - ps * 10, width: ps, height: ps))

            // Main mast (center, tallest)
            let mainMastX = shipBaseX + ps * 9
            let mainMastBase = waterLine - ps * 8
            c.setFillColor(mastColor.cgColor)
            for row in 0..<30 {
                c.fill(CGRect(x: mainMastX, y: mainMastBase - CGFloat(row) * ps, width: ps, height: ps))
            }

            // Main sail (large rectangle)
            let mainSailTop = mainMastBase - ps * 26
            for row in 0..<14 {
                let yPos = mainSailTop + CGFloat(row) * ps
                let sailW = row < 3 ? 8 : (row < 10 ? 10 : 8)
                let offset = (10 - sailW) / 2
                let color = row < 7 ? sailWhite : sailShadow
                c.setFillColor(color.cgColor)
                for col in 0..<sailW {
                    c.fill(CGRect(x: mainMastX + CGFloat(col + offset - 4) * ps, y: yPos, width: ps, height: ps))
                }
            }

            // Lower main sail
            let lowerSailTop = mainMastBase - ps * 10
            for row in 0..<8 {
                let yPos = lowerSailTop + CGFloat(row) * ps
                let sailW = row < 2 ? 7 : (row < 6 ? 9 : 7)
                let offset = (9 - sailW) / 2
                c.setFillColor((row < 4 ? sailWhite : sailShadow).cgColor)
                for col in 0..<sailW {
                    c.fill(CGRect(x: mainMastX + CGFloat(col + offset - 3) * ps, y: yPos, width: ps, height: ps))
                }
            }

            // Fore mast (front, shorter)
            let foreMastX = shipBaseX + ps * 4
            let foreMastBase = waterLine - ps * 8
            c.setFillColor(mastColor.cgColor)
            for row in 0..<22 {
                c.fill(CGRect(x: foreMastX, y: foreMastBase - CGFloat(row) * ps, width: ps, height: ps))
            }
            // Fore sail
            let foreSailTop = foreMastBase - ps * 20
            for row in 0..<10 {
                let yPos = foreSailTop + CGFloat(row) * ps
                let sailW = row < 2 ? 5 : (row < 7 ? 7 : 5)
                let offset = (7 - sailW) / 2
                c.setFillColor((row < 5 ? sailWhite : sailShadow).cgColor)
                for col in 0..<sailW {
                    c.fill(CGRect(x: foreMastX + CGFloat(col + offset - 2) * ps, y: yPos, width: ps, height: ps))
                }
            }

            // Mizzen mast (back, medium)
            let mizzenX = shipBaseX + ps * 15
            let mizzenBase = waterLine - ps * 8
            c.setFillColor(mastColor.cgColor)
            for row in 0..<24 {
                c.fill(CGRect(x: mizzenX, y: mizzenBase - CGFloat(row) * ps, width: ps, height: ps))
            }
            // Mizzen sail
            let mizzenSailTop = mizzenBase - ps * 22
            for row in 0..<10 {
                let yPos = mizzenSailTop + CGFloat(row) * ps
                let sailW = row < 2 ? 5 : (row < 7 ? 6 : 4)
                let offset = (6 - sailW) / 2
                c.setFillColor((row < 5 ? sailWhite : sailShadow).cgColor)
                for col in 0..<sailW {
                    c.fill(CGRect(x: mizzenX + CGFloat(col + offset - 2) * ps, y: yPos, width: ps, height: ps))
                }
            }

            // Crow's nest on main mast
            let nestY = mainMastBase - ps * 28
            c.setFillColor(midWood.cgColor)
            c.fill(CGRect(x: mainMastX - ps, y: nestY, width: ps * 3, height: ps))
            c.fill(CGRect(x: mainMastX - ps * 2, y: nestY + ps, width: ps * 5, height: ps))

            // Jolly Roger flag on main mast top
            let flagY = mainMastBase - ps * 30
            c.setFillColor(flagBlack.cgColor)
            c.fill(CGRect(x: mainMastX + ps, y: flagY - ps * 3, width: ps * 4, height: ps * 3))
            // Skull
            c.setFillColor(skullWhite.cgColor)
            c.fill(CGRect(x: mainMastX + ps * 2, y: flagY - ps * 2, width: ps * 2, height: ps))
            c.fill(CGRect(x: mainMastX + ps * 2, y: flagY - ps * 3, width: ps, height: ps))

            // Rigging lines (simple diagonal pixels)
            let riggingColor = UIColor(red: 0.30, green: 0.22, blue: 0.14, alpha: 0.20)
            c.setFillColor(riggingColor.cgColor)
            for i in 0..<6 {
                // Fore to main
                let rx = foreMastX + CGFloat(i) * ps
                let ry = foreMastBase - CGFloat(20 - i) * ps
                c.fill(CGRect(x: rx, y: ry, width: ps, height: ps))
            }

            // Water ripples around hull
            let rippleColor = UIColor(red: 0.60, green: 0.82, blue: 0.90, alpha: 0.15)
            c.setFillColor(rippleColor.cgColor)
            for i in stride(from: 0, to: 22, by: 3) {
                c.fill(CGRect(x: shipBaseX + CGFloat(i) * ps - ps, y: waterLine + ps, width: ps * 2, height: ps))
            }
        }
    }

    // MARK: Los Angeles Hollywood Hills — rolling brown hills with HOLLYWOOD-like structures

    private func renderLosAngelesHollywoodHills() -> UIImage {
        let w: CGFloat = GK.worldWidth * 2
        let h: CGFloat = 300
        let ps: CGFloat = 4
        let gridW = Int(w / ps)

        var heightMap = [Int](repeating: 1, count: gridW)
        let bumps: [(center: Int, radius: Int, peak: Int)] = [
            (gridW / 10, 40, 22), (gridW / 4, 55, 35), (gridW * 2 / 5, 35, 20),
            (gridW / 2, 50, 37), (gridW * 3 / 5, 30, 17), (gridW * 3 / 4, 45, 30),
            (gridW * 9 / 10, 37, 25),
        ]
        for bump in bumps {
            for x in max(0, bump.center - bump.radius)..<min(gridW, bump.center + bump.radius) {
                let dist = abs(x - bump.center)
                let nd = CGFloat(dist) / CGFloat(bump.radius)
                heightMap[x] = max(heightMap[x], Int(CGFloat(bump.peak) * (1.0 - nd * nd)))
            }
        }

        let hillBase = UIColor(red: 0.42, green: 0.32, blue: 0.22, alpha: 0.50)
        let hillMid  = UIColor(red: 0.52, green: 0.38, blue: 0.25, alpha: 0.45)
        let hillTop  = UIColor(red: 0.60, green: 0.45, blue: 0.28, alpha: 0.55)
        let hillGlow = UIColor(red: 0.85, green: 0.55, blue: 0.30, alpha: 0.35)

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let c = ctx.cgContext
            for x in 0..<gridW {
                let hH = heightMap[x]
                for y in 0..<hH {
                    let yPos = h - CGFloat(y + 1) * ps
                    let ratio = CGFloat(y) / max(1, CGFloat(hH))
                    let color: UIColor
                    if y == hH - 1 { color = hillTop }
                    else if y == hH - 2 && hH > 4 { color = hillGlow }
                    else if ratio > 0.5 { color = hillMid }
                    else { color = hillBase }
                    c.setFillColor(color.cgColor)
                    c.fill(CGRect(x: CGFloat(x) * ps, y: yPos, width: ps, height: ps))
                }
            }
        }
    }

    // MARK: London Skyline Hills — iconic London skyline with Big Ben, Parliament, Eye

    private func renderLondonSkylineHills() -> UIImage {
        let w: CGFloat = GK.worldWidth * 2
        let h: CGFloat = 300
        let ps: CGFloat = 4
        let gridW = Int(w / ps)

        // Building-like stepped skyline — tall and dramatic
        var heightMap = [Int](repeating: 5, count: gridW)
        // Parliament block
        let parlStart = gridW / 5
        for x in parlStart..<min(gridW, parlStart + 22) { heightMap[x] = 20 }
        // Big Ben tower
        for x in max(0, parlStart - 4)..<parlStart { heightMap[x] = 45 }
        // Clock face at top
        if parlStart - 2 >= 0 { heightMap[parlStart - 2] = 50 }

        // Tower Bridge area
        let bridgeStart = gridW / 2
        for x in bridgeStart..<min(gridW, bridgeStart + 6) { heightMap[x] = 40 }
        for x in min(gridW, bridgeStart + 6)..<min(gridW, bridgeStart + 16) { heightMap[x] = 12 }
        for x in min(gridW, bridgeStart + 16)..<min(gridW, bridgeStart + 22) { heightMap[x] = 40 }

        // Gherkin / Shard area — tapered spire
        let modernStart = gridW * 3 / 4
        for x in modernStart..<min(gridW, modernStart + 6) {
            let dist = abs(x - modernStart - 3)
            heightMap[x] = max(10, 55 - dist * 8)
        }

        // Generic rooftops
        let blocks: [(start: Int, w: Int, h: Int)] = [
            (gridW * 2 / 5, 20, 35), (gridW * 2 / 5 + 12, 8, 22),
            (gridW * 7 / 8, 25, 42),
        ]
        for block in blocks {
            for x in block.start..<min(gridW, block.start + block.w) { heightMap[x] = max(heightMap[x], block.h) }
        }

        let brickDark = UIColor(red: 0.25, green: 0.22, blue: 0.20, alpha: 0.55)
        let brickMid  = UIColor(red: 0.35, green: 0.30, blue: 0.28, alpha: 0.50)
        let brickTop  = UIColor(red: 0.42, green: 0.38, blue: 0.35, alpha: 0.55)

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let c = ctx.cgContext
            for x in 0..<gridW {
                let bH = heightMap[x]
                for y in 0..<bH {
                    let yPos = h - CGFloat(y + 1) * ps
                    let color = y == bH - 1 ? brickTop : (y > bH / 2 ? brickMid : brickDark)
                    c.setFillColor(color.cgColor)
                    c.fill(CGRect(x: CGFloat(x) * ps, y: yPos, width: ps, height: ps))
                }
            }
            // Clock face glow on Big Ben
            let clockX = CGFloat(max(0, parlStart - 2)) * ps
            let clockY = h - 50 * ps
            c.setFillColor(UIColor(red: 1.0, green: 0.90, blue: 0.60, alpha: 0.5).cgColor)
            c.fill(CGRect(x: clockX, y: clockY, width: ps * 2, height: ps * 2))
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

        var heightMap = [Int](repeating: 0, count: gridW)

        // Mesa formations: flat-topped with steep sides, taller for drama
        let mesas: [(center: Int, halfWidth: Int, peak: Int)] = [
            (gridW / 10, 20, 40),       // narrow butte
            (gridW / 4, 40, 30),       // wide mesa
            (gridW * 3 / 8, 15, 50),    // tall narrow butte
            (gridW / 2, 30, 25),       // medium mesa
            (gridW * 5 / 8, 12, 45),    // narrow butte
            (gridW * 3 / 4, 45, 35),   // wide mesa
            (gridW * 9 / 10, 17, 42),   // medium butte
        ]
        for mesa in mesas {
            for x in max(0, mesa.center - mesa.halfWidth)..<min(gridW, mesa.center + mesa.halfWidth) {
                let dist = abs(x - mesa.center)
                let edgeDist = mesa.halfWidth - dist
                let bh = edgeDist <= 2 ? Int(CGFloat(mesa.peak) * CGFloat(edgeDist) / 3.0) : mesa.peak
                heightMap[x] = max(heightMap[x], bh)
            }
        }
        // Low rolling sand between mesas
        let dunes: [(center: Int, radius: Int, peak: Int)] = [
            (gridW * 3 / 16, 30, 7), (gridW * 7 / 16, 25, 5),
            (gridW * 11 / 16, 35, 7), (gridW * 15 / 16, 25, 5),
        ]
        for dune in dunes {
            for x in max(0, dune.center - dune.radius)..<min(gridW, dune.center + dune.radius) {
                let dist = abs(x - dune.center)
                let nd = CGFloat(dist) / CGFloat(dune.radius)
                let bh = Int(CGFloat(dune.peak) * (1.0 - nd * nd))
                heightMap[x] = max(heightMap[x], bh)
            }
        }

        // Erosion layer colors — bands of sedimentary rock
        let mesaBase   = UIColor(red: 0.36, green: 0.20, blue: 0.09, alpha: 0.60)
        let mesaLayer1 = UIColor(red: 0.48, green: 0.28, blue: 0.12, alpha: 0.58)
        let mesaLayer2 = UIColor(red: 0.54, green: 0.33, blue: 0.16, alpha: 0.55)
        let mesaLayer3 = UIColor(red: 0.60, green: 0.38, blue: 0.20, alpha: 0.52)
        let mesaTop    = UIColor(red: 0.23, green: 0.13, blue: 0.06, alpha: 0.65)
        let mesaLight  = UIColor(red: 0.77, green: 0.57, blue: 0.29, alpha: 0.45)
        let dustHaze   = UIColor(red: 0.80, green: 0.65, blue: 0.45, alpha: 0.06)
        let vultureC   = UIColor(red: 0.15, green: 0.12, blue: 0.10, alpha: 0.40)

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let c = ctx.cgContext

            // Dust haze at horizon
            c.setFillColor(dustHaze.cgColor)
            c.fill(CGRect(x: 0, y: h * 0.3, width: w, height: h * 0.15))

            // Mesa formations with erosion bands
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
                    // Sun highlight on exposed edges
                    if x > 0 && heightMap[x - 1] < y && ratio > 0.5 {
                        c.setFillColor(mesaLight.cgColor)
                    } else {
                        c.setFillColor(color.cgColor)
                    }
                    c.fill(CGRect(x: CGFloat(x) * ps, y: yPos, width: ps, height: ps))
                }
                // Shadow on right side of steep edges
                if x < gridW - 1 && heightMap[x + 1] < heightMap[x] - 3 {
                    let shadowH = min(heightMap[x], 4)
                    for sy in 0..<shadowH {
                        let yPos = h - CGFloat(heightMap[x] - sy) * ps
                        c.setFillColor(UIColor(red: 0, green: 0, blue: 0, alpha: 0.10).cgColor)
                        c.fill(CGRect(x: CGFloat(x + 1) * ps, y: yPos, width: ps, height: ps))
                    }
                }
            }

            // Circling vulture silhouettes
            let vultures: [(x: CGFloat, y: CGFloat)] = [(w * 0.20, h * 0.1), (w * 0.65, h * 0.15)]
            for v in vultures {
                c.setFillColor(vultureC.cgColor)
                c.fill(CGRect(x: v.x - ps * 2, y: v.y, width: ps, height: ps))
                c.fill(CGRect(x: v.x - ps, y: v.y - ps * 0.5, width: ps, height: ps))
                c.fill(CGRect(x: v.x, y: v.y, width: ps, height: ps))
                c.fill(CGRect(x: v.x + ps, y: v.y - ps * 0.5, width: ps, height: ps))
                c.fill(CGRect(x: v.x + ps * 2, y: v.y, width: ps, height: ps))
            }
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

        // Continuous overlapping bumps for dense canopy
        var heightMap = [Int](repeating: 1, count: gridW)
        let bumps: [(center: Int, radius: Int, peak: Int)] = [
            (gridW / 12, 35, 30), (gridW / 6, 40, 37), (gridW / 4, 30, 25),
            (gridW / 3, 45, 40), (gridW * 5 / 12, 35, 32), (gridW / 2, 40, 42),
            (gridW * 7 / 12, 30, 27), (gridW * 2 / 3, 50, 45), (gridW * 3 / 4, 35, 35),
            (gridW * 5 / 6, 40, 37), (gridW * 11 / 12, 30, 30),
        ]
        for bump in bumps {
            for x in max(0, bump.center - bump.radius)..<min(gridW, bump.center + bump.radius) {
                let dist = abs(x - bump.center)
                let nd = CGFloat(dist) / CGFloat(bump.radius)
                heightMap[x] = max(heightMap[x], Int(CGFloat(bump.peak) * (1.0 - nd * nd)))
            }
        }

        let deepCanopy  = UIColor(red: 0.06, green: 0.24, blue: 0.10, alpha: 0.55)
        let midCanopy   = UIColor(red: 0.12, green: 0.42, blue: 0.16, alpha: 0.50)
        let topCanopy   = UIColor(red: 0.04, green: 0.18, blue: 0.07, alpha: 0.60)
        let sunDapple   = UIColor(red: 0.24, green: 0.63, blue: 0.27, alpha: 0.40)

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let c = ctx.cgContext
            for x in 0..<gridW {
                let mH = heightMap[x]
                for y in 0..<mH {
                    let yPos = h - CGFloat(y + 1) * ps
                    let ratio = CGFloat(y) / max(1, CGFloat(mH))
                    let color: UIColor
                    if y == mH - 1 { color = topCanopy }
                    else if ratio > 0.6 {
                        // Sun dapple at peaks (1 in 5 chance)
                        color = (x % 5 == 0 && y == mH - 2) ? sunDapple : midCanopy
                    } else { color = deepCanopy }
                    c.setFillColor(color.cgColor)
                    c.fill(CGRect(x: CGFloat(x) * ps, y: yPos, width: ps, height: ps))
                }
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

        var heightMap = [Int](repeating: 0, count: gridW)

        // Sand dunes (gentle rolling)
        let dunes: [(center: Int, radius: Int, peak: Int)] = [
            (gridW / 8, 45, 10), (gridW * 3 / 8, 35, 7),
            (gridW * 5 / 8, 50, 12), (gridW * 7 / 8, 40, 7),
        ]
        for dune in dunes {
            for x in max(0, dune.center - dune.radius)..<min(gridW, dune.center + dune.radius) {
                let dist = abs(x - dune.center)
                let nd = CGFloat(dist) / CGFloat(dune.radius)
                heightMap[x] = max(heightMap[x], Int(CGFloat(dune.peak) * (1.0 - nd * nd)))
            }
        }

        // Pyramids — triangular
        let pyramids: [(center: Int, halfBase: Int, peak: Int)] = [
            (gridW / 5, 35, 60),       // large pyramid (taller)
            (gridW / 5 + 18, 8, 16),   // medium pyramid
            (gridW * 3 / 4, 25, 45),   // medium pyramid (right side)
        ]

        var isPyramid = [Bool](repeating: false, count: gridW)
        for pyr in pyramids {
            for x in max(0, pyr.center - pyr.halfBase)..<min(gridW, pyr.center + pyr.halfBase) {
                let dist = abs(x - pyr.center)
                let pH = Int(CGFloat(pyr.peak) * (1.0 - CGFloat(dist) / CGFloat(pyr.halfBase)))
                if pH > heightMap[x] {
                    heightMap[x] = pH
                    isPyramid[x] = true
                }
            }
        }

        let sandBase  = UIColor(red: 0.72, green: 0.56, blue: 0.38, alpha: 0.55)
        let sandLight = UIColor(red: 0.83, green: 0.72, blue: 0.50, alpha: 0.50)
        let pyrShadow = UIColor(red: 0.42, green: 0.30, blue: 0.13, alpha: 0.60)
        let pyrLit    = UIColor(red: 0.77, green: 0.63, blue: 0.31, alpha: 0.55)
        let pyrCap    = UIColor(red: 0.91, green: 0.78, blue: 0.25, alpha: 0.65)
        let pyrBlock  = UIColor(red: 0.62, green: 0.48, blue: 0.24, alpha: 0.50)
        let sunRay    = UIColor(red: 1.0, green: 0.90, blue: 0.55, alpha: 0.06)
        let heatHaze  = UIColor(red: 0.85, green: 0.70, blue: 0.45, alpha: 0.05)

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let c = ctx.cgContext

            // Sun rays emanating from behind largest pyramid
            let sunX = CGFloat(pyramids[0].center) * ps
            for i in 0..<5 {
                let angle = CGFloat(i - 2) * 0.25
                c.setFillColor(sunRay.cgColor)
                let rx = sunX + angle * w * 0.2
                c.fill(CGRect(x: rx - ps, y: 0, width: ps * 3, height: h * 0.5))
            }

            // Heat haze at horizon
            c.setFillColor(heatHaze.cgColor)
            c.fill(CGRect(x: 0, y: h * 0.4, width: w, height: h * 0.1))

            // Pyramid and dune terrain
            for x in 0..<gridW {
                let mH = heightMap[x]
                guard mH > 0 else { continue }
                for y in 0..<mH {
                    let yPos = h - CGFloat(y + 1) * ps
                    let color: UIColor
                    if isPyramid[x] {
                        if y == mH - 1 { color = pyrCap }
                        else {
                            var isLeftSide = true
                            for pyr in pyramids {
                                if x >= pyr.center - pyr.halfBase && x < pyr.center + pyr.halfBase {
                                    isLeftSide = x < pyr.center
                                    break
                                }
                            }
                            // Stone block texture — alternating shade every 3 rows
                            let blockShade = (y % 3 == 0)
                            if isLeftSide {
                                color = blockShade ? pyrBlock : pyrLit
                            } else {
                                color = blockShade ? pyrShadow : UIColor(red: 0.48, green: 0.35, blue: 0.18, alpha: 0.58)
                            }
                        }
                    } else {
                        let ratio = CGFloat(y) / max(1, CGFloat(mH))
                        // Sand ripple texture
                        color = (x + y) % 4 == 0 ? sandLight : sandBase
                    }
                    c.setFillColor(color.cgColor)
                    c.fill(CGRect(x: CGFloat(x) * ps, y: yPos, width: ps, height: ps))
                }
            }

            // Camel caravan silhouette (tiny, between pyramids)
            let camelC = UIColor(red: 0.35, green: 0.25, blue: 0.15, alpha: 0.30)
            let camelBase = h - CGFloat(3) * ps
            let camelX = CGFloat(gridW / 2) * ps
            c.setFillColor(camelC.cgColor)
            for i in 0..<3 {
                let cx = camelX + CGFloat(i) * ps * 4
                // Body
                c.fill(CGRect(x: cx, y: camelBase, width: ps * 2, height: ps))
                // Hump
                c.fill(CGRect(x: cx + ps * 0.5, y: camelBase - ps, width: ps, height: ps))
                // Legs
                c.fill(CGRect(x: cx, y: camelBase + ps, width: ps, height: ps))
                c.fill(CGRect(x: cx + ps, y: camelBase + ps, width: ps, height: ps))
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

        // Denser stalagmites rising from bottom
        var bottomMap = [Int](repeating: 0, count: gridW)
        let stalagmites: [(center: Int, radius: Int, peak: Int)] = [
            (gridW / 10, 10, 25), (gridW / 6, 15, 40), (gridW / 4, 20, 50),
            (gridW * 3 / 8, 10, 30), (gridW / 2, 15, 40), (gridW * 5 / 8, 7, 22),
            (gridW * 7 / 10, 12, 35), (gridW * 3 / 4, 17, 50), (gridW * 7 / 8, 12, 32),
        ]
        for bump in stalagmites {
            for x in max(0, bump.center - bump.radius)..<min(gridW, bump.center + bump.radius) {
                let dist = abs(x - bump.center)
                let nd = CGFloat(dist) / CGFloat(bump.radius)
                bottomMap[x] = max(bottomMap[x], Int(CGFloat(bump.peak) * max(0, 1.0 - nd * nd * nd)))
            }
        }

        // More and larger stalactites hanging from top
        var topMap = [Int](repeating: 0, count: gridW)
        let stalactites: [(center: Int, radius: Int, peak: Int)] = [
            (gridW / 8, 12, 25), (gridW / 4, 17, 35), (gridW * 3 / 8, 10, 20),
            (gridW / 2, 15, 30), (gridW * 5 / 8, 12, 27), (gridW * 3 / 4, 7, 17),
            (gridW * 5 / 6, 15, 32), (gridW * 11 / 12, 10, 22),
        ]
        for bump in stalactites {
            for x in max(0, bump.center - bump.radius)..<min(gridW, bump.center + bump.radius) {
                let dist = abs(x - bump.center)
                let nd = CGFloat(dist) / CGFloat(bump.radius)
                topMap[x] = max(topMap[x], Int(CGFloat(bump.peak) * max(0, 1.0 - nd * nd * nd)))
            }
        }

        // Ceiling rock — constant top band to make it feel enclosed
        var ceilingMap = [Int](repeating: 3, count: gridW)
        // Vary ceiling thickness slightly
        for x in 0..<gridW {
            ceilingMap[x] = 3 + (x % 7 < 2 ? 1 : 0)
        }

        let rockDark    = UIColor(red: 0.10, green: 0.08, blue: 0.13, alpha: 0.70)
        let rockMid     = UIColor(red: 0.18, green: 0.16, blue: 0.22, alpha: 0.65)
        let rockLight   = UIColor(red: 0.29, green: 0.25, blue: 0.35, alpha: 0.55)
        let crystalCyan = UIColor(red: 0.25, green: 0.82, blue: 0.88, alpha: 0.75)
        let crystalPink = UIColor(red: 0.88, green: 0.25, blue: 0.75, alpha: 0.75)
        let crystalGlow = UIColor(red: 0.25, green: 0.82, blue: 0.88, alpha: 0.10)
        let waterGlow   = UIColor(red: 0.15, green: 0.45, blue: 0.65, alpha: 0.20)
        let waterBright = UIColor(red: 0.25, green: 0.60, blue: 0.80, alpha: 0.15)
        let dripC       = UIColor(red: 0.40, green: 0.65, blue: 0.80, alpha: 0.35)

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let c = ctx.cgContext

            // Ceiling rock band — makes cave feel enclosed
            for x in 0..<gridW {
                let cH = ceilingMap[x]
                for y in 0..<cH {
                    c.setFillColor((y == cH - 1 ? rockLight : rockDark).cgColor)
                    c.fill(CGRect(x: CGFloat(x) * ps, y: CGFloat(y) * ps, width: ps, height: ps))
                }
            }

            // Stalactites (from ceiling)
            for x in 0..<gridW {
                let mH = topMap[x]
                for y in 0..<mH {
                    let yPos = CGFloat(ceilingMap[x] + y) * ps
                    let ratio = CGFloat(y) / max(1, CGFloat(mH))
                    let color: UIColor
                    if y == mH - 1 && (x % 8 == 0) {
                        color = x % 16 == 0 ? crystalPink : crystalCyan
                    } else if ratio > 0.6 { color = rockLight }
                    else if ratio > 0.3 { color = rockMid }
                    else { color = rockDark }
                    c.setFillColor(color.cgColor)
                    c.fill(CGRect(x: CGFloat(x) * ps, y: yPos, width: ps, height: ps))
                }
                // Water drip from stalactite tips
                if topMap[x] > 6 && x % 11 == 0 {
                    let dripY = CGFloat(ceilingMap[x] + topMap[x]) * ps + ps
                    c.setFillColor(dripC.cgColor)
                    c.fill(CGRect(x: CGFloat(x) * ps, y: dripY, width: ps, height: ps))
                }
            }

            // Stalagmites (from bottom)
            for x in 0..<gridW {
                let mH = bottomMap[x]
                for y in 0..<mH {
                    let yPos = h - CGFloat(y + 1) * ps
                    let ratio = CGFloat(y) / max(1, CGFloat(mH))
                    let color: UIColor
                    if y == mH - 1 && (x % 6 == 0) {
                        color = x % 12 == 0 ? crystalCyan : crystalPink
                    } else if ratio > 0.6 { color = rockLight }
                    else if ratio > 0.3 { color = rockMid }
                    else { color = rockDark }
                    c.setFillColor(color.cgColor)
                    c.fill(CGRect(x: CGFloat(x) * ps, y: yPos, width: ps, height: ps))
                }
            }

            // Crystal glow auras around crystal-tipped formations
            for x in stride(from: 0, to: gridW, by: 6) {
                let bH = bottomMap[x]
                if bH > 5 {
                    let glowY = h - CGFloat(bH + 1) * ps
                    c.setFillColor(crystalGlow.cgColor)
                    c.fill(CGRect(x: CGFloat(x - 1) * ps, y: glowY - ps, width: ps * 3, height: ps * 3))
                }
            }

            // Underground river glow at base between stalagmites
            for x in 0..<gridW {
                if bottomMap[x] < 3 {
                    let riverY = h - ps * 2
                    let rc = (x % 6 == 0) ? waterBright : waterGlow
                    c.setFillColor(rc.cgColor)
                    c.fill(CGRect(x: CGFloat(x) * ps, y: riverY, width: ps, height: ps * 2))
                }
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

        // Sharp peaks with dominant high points
        var heightMap = [Int](repeating: 0, count: gridW)
        let peaks: [(center: Int, radius: Int, peak: Int)] = [
            (gridW / 10, 30, 30),        // small peak
            (gridW / 4, 40, 60),          // dominant peak (taller)
            (gridW * 3 / 8, 25, 22),       // ridge
            (gridW / 2, 35, 50),          // second dominant
            (gridW * 5 / 8, 20, 17),        // small ridge
            (gridW * 3 / 4, 45, 65),      // tallest peak
            (gridW * 7 / 8, 25, 35),      // medium peak
        ]
        // Track waterfall source peak
        let waterfallPeak = gridW * 3 / 4

        for peak in peaks {
            for x in max(0, peak.center - peak.radius)..<min(gridW, peak.center + peak.radius) {
                let dist = abs(x - peak.center)
                let nd = CGFloat(dist) / CGFloat(peak.radius)
                let bh = Int(CGFloat(peak.peak) * max(0, 1.0 - nd))
                heightMap[x] = max(heightMap[x], bh)
            }
        }
        // Low ridges connecting peaks
        let ridges: [(center: Int, radius: Int, peak: Int)] = [
            (gridW * 3 / 16, 35, 12), (gridW * 7 / 16, 30, 10),
            (gridW * 11 / 16, 40, 15),
        ]
        for ridge in ridges {
            for x in max(0, ridge.center - ridge.radius)..<min(gridW, ridge.center + ridge.radius) {
                let dist = abs(x - ridge.center)
                let nd = CGFloat(dist) / CGFloat(ridge.radius)
                heightMap[x] = max(heightMap[x], Int(CGFloat(ridge.peak) * (1.0 - nd * nd)))
            }
        }

        let rockDark = UIColor(red: 0.23, green: 0.29, blue: 0.35, alpha: 0.60)
        let rockMid  = UIColor(red: 0.35, green: 0.42, blue: 0.48, alpha: 0.55)
        let rockLt   = UIColor(red: 0.42, green: 0.48, blue: 0.55, alpha: 0.50)
        let snowShdw = UIColor(red: 0.69, green: 0.75, blue: 0.82, alpha: 0.60)
        let snowMid  = UIColor(red: 0.85, green: 0.88, blue: 0.92, alpha: 0.65)
        let snowTop  = UIColor(red: 0.94, green: 0.96, blue: 0.97, alpha: 0.70)
        let waterC   = UIColor(red: 0.55, green: 0.75, blue: 0.90, alpha: 0.50)
        let waterFm  = UIColor(red: 0.80, green: 0.92, blue: 0.98, alpha: 0.45)
        let mistC    = UIColor(red: 0.85, green: 0.90, blue: 0.95, alpha: 0.15)

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let c = ctx.cgContext
            for x in 0..<gridW {
                let mH = heightMap[x]
                guard mH > 0 else { continue }
                for y in 0..<mH {
                    let yPos = h - CGFloat(y + 1) * ps
                    let ratio = CGFloat(y) / max(1, CGFloat(mH))
                    let color: UIColor
                    if ratio > 0.85 { color = snowTop }
                    else if ratio > 0.75 { color = snowMid }
                    else if ratio > 0.65 { color = snowShdw }
                    else if ratio > 0.35 {
                        // Rock layers with subtle striations
                        color = (y % 3 == 0) ? rockLt : rockMid
                    } else { color = rockDark }
                    c.setFillColor(color.cgColor)
                    c.fill(CGRect(x: CGFloat(x) * ps, y: yPos, width: ps, height: ps))
                }
            }

            // Waterfall — cascading down the tallest peak's right side
            let wfX = CGFloat(waterfallPeak + 2) * ps
            let wfTopY = h - CGFloat(heightMap[waterfallPeak + 2]) * ps
            let wfBotY = h - ps * 2
            // Water stream
            var wy = wfTopY
            while wy < wfBotY {
                c.setFillColor(waterC.cgColor)
                c.fill(CGRect(x: wfX, y: wy, width: ps, height: ps))
                // Foam sparkle on alternating pixels
                if Int(wy / ps) % 3 == 0 {
                    c.setFillColor(waterFm.cgColor)
                    c.fill(CGRect(x: wfX + ps, y: wy, width: ps * 0.5, height: ps))
                }
                wy += ps
            }
            // Mist at base of waterfall
            c.setFillColor(mistC.cgColor)
            c.fill(CGRect(x: wfX - ps * 3, y: wfBotY - ps, width: ps * 8, height: ps * 3))

            // Eagle silhouette (tiny) soaring near peaks
            let eagleC = UIColor(red: 0.20, green: 0.18, blue: 0.22, alpha: 0.45)
            let ex = w * 0.35, ey = h * 0.15
            c.setFillColor(eagleC.cgColor)
            c.fill(CGRect(x: ex - ps * 2, y: ey, width: ps, height: ps))
            c.fill(CGRect(x: ex - ps, y: ey - ps * 0.5, width: ps, height: ps))
            c.fill(CGRect(x: ex, y: ey, width: ps, height: ps))
            c.fill(CGRect(x: ex + ps, y: ey - ps * 0.5, width: ps, height: ps))
            c.fill(CGRect(x: ex + ps * 2, y: ey, width: ps, height: ps))
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
