import SpriteKit
import UIKit

/// Generates all game textures programmatically using pixel-art style rendering.
/// Park theme with round mallard duck matching Flappy Bird proportions.
final class TextureFactory {
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
            // Pipes, sky, cloud (still procedurally rendered)
            _ = pipeTexture(height: 300, skinOverride: .classic)
            _ = pipeCapTexture(skinOverride: .classic)
            _ = skyTexture()
            _ = cloudTexture()
            _ = breadTexture()

            // Theme textures: 9 pre-generated PNG layers per theme from asset catalog.
            // UIImage(named:) uses memory-mapped files — fast and cache-friendly.
            // Warm into SKTexture cache to avoid first-frame hitches.
            let layerSuffixes = [
                "background1", "background2", "background3",
                "midground1", "midground2", "midground3",
                "foreground1", "foreground2", "foreground3"
            ]
            for theme in BackgroundTheme.allCases {
                for suffix in layerSuffixes {
                    _ = self.themedLayerTexture(theme: theme, layer: suffix)
                }
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

    // (themedGroundTexture removed — ground is now foreground2 in 9-layer system)

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

    /// UIImage of pixel hills for SwiftUI home background
    func hillsUIImage() -> UIImage {
        return renderPixelHills()
    }

    // MARK: - Themed Parallax Textures (9-Layer System)

    /// Load any themed layer texture from the asset catalog.
    /// Layer suffixes: background1–3, midground1–3, foreground1–3.
    func themedLayerTexture(theme: BackgroundTheme, layer: String) -> SKTexture {
        let key = "\(theme.rawValue)_\(layer)"
        if let cached = cachedTexture(forKey: key) { return cached }
        guard let image = UIImage(named: key) else {
            fatalError("Missing asset: \(key)")
        }
        let tex = SKTexture(image: image)
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


}
