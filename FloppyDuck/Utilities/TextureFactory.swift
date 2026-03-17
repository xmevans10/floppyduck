import SpriteKit
import UIKit

/// Generates all game textures programmatically using pixel-art style rendering.
/// Park theme with round mallard duck matching Flappy Bird proportions.
final class TextureFactory {
    static let shared = TextureFactory()
    private init() {}

    private var cache: [String: SKTexture] = [:]

    // MARK: - Public API

    /// Pixel-art mallard duck (wing up, mid, down)
    func duckTexture(wingPhase: Int) -> SKTexture {
        let key = "duck_\(wingPhase)"
        if let cached = cache[key] { return cached }
        let tex = SKTexture(image: renderMallardDuck(wingPhase: wingPhase))
        tex.filteringMode = .nearest
        cache[key] = tex
        return tex
    }

    /// Bot ghost duck (tinted, semi-transparent)
    func botDuckTexture(wingPhase: Int) -> SKTexture {
        let key = "botduck_\(wingPhase)"
        if let cached = cache[key] { return cached }
        let tex = SKTexture(image: renderMallardDuck(wingPhase: wingPhase, ghost: true))
        tex.filteringMode = .nearest
        cache[key] = tex
        return tex
    }

    /// Green gradient pipe body with pixel border.
    /// Pre-renders one master texture; subsequent calls crop a sub-region — no per-height rendering.
    func pipeTexture(height: CGFloat) -> SKTexture {
        let masterKey = "pipe_master"
        let masterTex: SKTexture
        if let cached = cache[masterKey] {
            masterTex = cached
        } else {
            let tex = SKTexture(image: renderPipe(width: GK.pipeWidth, height: GK.worldHeight))
            tex.filteringMode = .nearest
            cache[masterKey] = tex
            masterTex = tex
        }
        // Crop from bottom of master texture (unit coords, origin bottom-left)
        let fraction = min(height / GK.worldHeight, 1.0)
        let cropped = SKTexture(rect: CGRect(x: 0, y: 0, width: 1, height: fraction), in: masterTex)
        cropped.filteringMode = .nearest
        return cropped
    }

    /// Pipe cap with lip
    func pipeCapTexture() -> SKTexture {
        let key = "pipecap"
        if let cached = cache[key] { return cached }
        let tex = SKTexture(image: renderPipeCap())
        tex.filteringMode = .nearest
        cache[key] = tex
        return tex
    }

    /// Scrolling ground tile — park grass with flowers (pixel art)
    func groundTexture() -> SKTexture {
        let key = "ground"
        if let cached = cache[key] { return cached }
        let tex = SKTexture(image: renderGround())
        tex.filteringMode = .nearest
        cache[key] = tex
        return tex
    }

    /// Sky gradient background
    func skyTexture() -> SKTexture {
        let key = "sky"
        if let cached = cache[key] { return cached }
        let tex = SKTexture(image: renderSky())
        tex.filteringMode = .nearest
        cache[key] = tex
        return tex
    }

    /// Pixel-art cloud
    func cloudTexture() -> SKTexture {
        let key = "cloud"
        if let cached = cache[key] { return cached }
        let tex = SKTexture(image: renderPixelCloud())
        tex.filteringMode = .nearest
        cache[key] = tex
        return tex
    }

    /// Pixel-art park trees for parallax background
    func treesTexture() -> SKTexture {
        let key = "trees"
        if let cached = cache[key] { return cached }
        let tex = SKTexture(image: renderPixelTrees())
        tex.filteringMode = .nearest
        cache[key] = tex
        return tex
    }

    /// Pixel-art distant hills
    func hillsTexture() -> SKTexture {
        let key = "hills"
        if let cached = cache[key] { return cached }
        let tex = SKTexture(image: renderPixelHills())
        tex.filteringMode = .nearest
        cache[key] = tex
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

    /// UIImage of pixel hills for SwiftUI home background
    func hillsUIImage() -> UIImage {
        return renderPixelHills()
    }

    // MARK: - Themed Parallax Textures

    /// Theme-aware hills texture. Free themes reuse the classic park hills
    /// with palette shifts; paid themes get unique silhouettes.
    func themedHillsTexture(theme: BackgroundTheme) -> SKTexture {
        let key = "hills_\(theme.rawValue)"
        if let cached = cache[key] { return cached }
        let tex = SKTexture(image: renderThemedHills(theme: theme))
        tex.filteringMode = .nearest
        cache[key] = tex
        return tex
    }

    /// Theme-aware trees / midground texture.
    func themedTreesTexture(theme: BackgroundTheme) -> SKTexture {
        let key = "trees_\(theme.rawValue)"
        if let cached = cache[key] { return cached }
        let tex = SKTexture(image: renderThemedTrees(theme: theme))
        tex.filteringMode = .nearest
        cache[key] = tex
        return tex
    }

    /// Theme-aware foreground bush / element strip.
    func themedBushTexture(theme: BackgroundTheme) -> SKTexture {
        let key = "bushes_\(theme.rawValue)"
        if let cached = cache[key] { return cached }
        let tex = SKTexture(image: renderThemedBushes(theme: theme))
        tex.filteringMode = .nearest
        cache[key] = tex
        return tex
    }

    // MARK: - Skinned Duck API

    /// Duck texture for any skin (SpriteKit).
    func skinDuckTexture(skin: DuckSkin, wingPhase: Int) -> SKTexture {
        let key = "skin_\(skin.rawValue)_\(wingPhase)"
        if let cached = cache[key] { return cached }
        let tex = SKTexture(image: renderSkinnedDuck(skin: skin, wingPhase: wingPhase))
        tex.filteringMode = .nearest
        cache[key] = tex
        return tex
    }

    /// Ghost/bot version of any skin.
    func skinBotDuckTexture(skin: DuckSkin, wingPhase: Int) -> SKTexture {
        let key = "skinbot_\(skin.rawValue)_\(wingPhase)"
        if let cached = cache[key] { return cached }
        let tex = SKTexture(image: renderSkinnedDuck(skin: skin, wingPhase: wingPhase, ghost: true))
        tex.filteringMode = .nearest
        cache[key] = tex
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
        if let cached = cache[key] { return cached }
        let tex = SKTexture(image: renderBread())
        tex.filteringMode = .nearest
        cache[key] = tex
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

    private func renderPipe(width: CGFloat, height: CGFloat) -> UIImage {
        let size = CGSize(width: width, height: height)
        let borderW: CGFloat = 3
        let highlightW: CGFloat = 6

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let c = ctx.cgContext
            c.setFillColor(UIColor(red: 0.20, green: 0.33, blue: 0.10, alpha: 1).cgColor)
            c.fill(CGRect(origin: .zero, size: size))

            let body = CGRect(x: borderW, y: 0, width: width - borderW * 2, height: height)
            c.setFillColor(UIColor(red: 0.45, green: 0.75, blue: 0.18, alpha: 1).cgColor)
            c.fill(body)

            let highlight = CGRect(x: borderW + 3, y: 0, width: highlightW, height: height)
            c.setFillColor(UIColor(red: 0.55, green: 0.85, blue: 0.28, alpha: 1).cgColor)
            c.fill(highlight)

            let shadow = CGRect(x: width - borderW - highlightW - 1, y: 0, width: highlightW, height: height)
            c.setFillColor(UIColor(red: 0.34, green: 0.54, blue: 0.13, alpha: 1).cgColor)
            c.fill(shadow)
        }
    }

    private func renderPipeCap() -> UIImage {
        let capW: CGFloat = GK.pipeWidth + 10
        let capH: CGFloat = 30
        let borderW: CGFloat = 3
        let size = CGSize(width: capW, height: capH)

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let c = ctx.cgContext
            c.setFillColor(UIColor(red: 0.20, green: 0.33, blue: 0.10, alpha: 1).cgColor)
            c.fill(CGRect(origin: .zero, size: size))

            let inner = CGRect(x: borderW, y: borderW, width: capW - borderW * 2, height: capH - borderW * 2)
            c.setFillColor(UIColor(red: 0.45, green: 0.75, blue: 0.18, alpha: 1).cgColor)
            c.fill(inner)

            let hl = CGRect(x: borderW + 3, y: borderW, width: 6, height: capH - borderW * 2)
            c.setFillColor(UIColor(red: 0.55, green: 0.85, blue: 0.28, alpha: 1).cgColor)
            c.fill(hl)

            let sh = CGRect(x: capW - borderW - 7, y: borderW, width: 6, height: capH - borderW * 2)
            c.setFillColor(UIColor(red: 0.34, green: 0.54, blue: 0.13, alpha: 1).cgColor)
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
        let h: CGFloat = 140          // taller canvas for more dramatic peaks
        let ps: CGFloat = 4           // pixel size

        let gridW = Int(w / ps)

        // --- Back hills (distant, muted) ---
        var backHeight = [Int](repeating: 1, count: gridW)
        let backBumps: [(center: Int, radius: Int, peak: Int)] = [
            (gridW / 10,     20, 18),
            (gridW * 3 / 10, 22, 20),
            (gridW / 2,      18, 16),
            (gridW * 7 / 10, 24, 22),
            (gridW * 9 / 10, 16, 14),
        ]
        for bump in backBumps {
            for x in max(0, bump.center - bump.radius)..<min(gridW, bump.center + bump.radius) {
                let dist = abs(x - bump.center)
                let nd = CGFloat(dist) / CGFloat(bump.radius)
                backHeight[x] = max(backHeight[x], Int(CGFloat(bump.peak) * (1.0 - nd * nd)))
            }
        }

        // --- Front hills (closer, vivid) ---
        var frontHeight = [Int](repeating: 1, count: gridW)
        let frontBumps: [(center: Int, radius: Int, peak: Int)] = [
            (gridW / 8,       14, 11),
            (gridW / 4,       16, 14),
            (gridW * 3 / 8,   10, 8),
            (gridW / 2 + 5,   18, 15),
            (gridW * 5 / 8,   12, 10),
            (gridW * 3 / 4,   15, 13),
            (gridW * 7 / 8,   13, 9),
        ]
        for bump in frontBumps {
            for x in max(0, bump.center - bump.radius)..<min(gridW, bump.center + bump.radius) {
                let dist = abs(x - bump.center)
                let nd = CGFloat(dist) / CGFloat(bump.radius)
                frontHeight[x] = max(frontHeight[x], Int(CGFloat(bump.peak) * (1.0 - nd * nd)))
            }
        }

        // Palette — back layer muted, front layer vivid
        let backBase  = UIColor(red: 0.35, green: 0.55, blue: 0.30, alpha: 0.35)
        let backMid   = UIColor(red: 0.40, green: 0.60, blue: 0.34, alpha: 0.30)
        let backTop   = UIColor(red: 0.30, green: 0.48, blue: 0.26, alpha: 0.40)
        let frontBase = UIColor(red: 0.45, green: 0.68, blue: 0.38, alpha: 0.55)
        let frontMid  = UIColor(red: 0.52, green: 0.74, blue: 0.42, alpha: 0.50)
        let frontTop  = UIColor(red: 0.38, green: 0.58, blue: 0.32, alpha: 0.60)
        let frontHL   = UIColor(red: 0.58, green: 0.80, blue: 0.50, alpha: 0.40)

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let c = ctx.cgContext

            // Draw back hills first (behind)
            for x in 0..<gridW {
                let bh = backHeight[x]
                for y in 0..<bh {
                    let yPos = h - CGFloat(y + 1) * ps
                    let ratio = CGFloat(y) / max(1, CGFloat(bh))
                    let color = y == bh - 1 ? backTop : ratio > 0.5 ? backMid : backBase
                    c.setFillColor(color.cgColor)
                    c.fill(CGRect(x: CGFloat(x) * ps, y: yPos, width: ps, height: ps))
                }
            }

            // Draw front hills on top
            for x in 0..<gridW {
                let fh = frontHeight[x]
                for y in 0..<fh {
                    let yPos = h - CGFloat(y + 1) * ps
                    let ratio = CGFloat(y) / max(1, CGFloat(fh))
                    let color: UIColor
                    if y == fh - 1 { color = frontTop }
                    else if y == fh - 2 && fh > 4 { color = frontHL }
                    else if ratio > 0.6 { color = frontMid }
                    else { color = frontBase }
                    c.setFillColor(color.cgColor)
                    c.fill(CGRect(x: CGFloat(x) * ps, y: yPos, width: ps, height: ps))
                }
            }

            // Scatter pixel detail on front hill peaks — tiny bushes + flowers
            let bushColor = UIColor(red: 0.35, green: 0.55, blue: 0.28, alpha: 0.55)
            let flowerColors: [UIColor] = [
                UIColor(red: 1.0, green: 0.35, blue: 0.35, alpha: 0.90),
                UIColor(red: 1.0, green: 0.85, blue: 0.20, alpha: 0.90),
                UIColor(red: 0.80, green: 0.40, blue: 0.85, alpha: 0.85),
                UIColor(red: 0.95, green: 0.60, blue: 0.80, alpha: 0.85),
            ]
            var flowerSeed = 42
            for x in stride(from: 3, to: gridW - 3, by: 5) {
                let fh = frontHeight[x]
                if fh > 5 {
                    // Small bush on peak
                    let yPos = h - CGFloat(fh + 1) * ps
                    c.setFillColor(bushColor.cgColor)
                    c.fill(CGRect(x: CGFloat(x) * ps, y: yPos, width: ps * 2, height: ps))
                    c.fill(CGRect(x: CGFloat(x - 1) * ps, y: yPos + ps, width: ps, height: ps))
                    c.fill(CGRect(x: CGFloat(x + 2) * ps, y: yPos + ps, width: ps, height: ps))
                    // Occasional flower dot
                    flowerSeed = (flowerSeed &* 1103515245 &+ 12345) & 0x7FFFFFFF
                    if flowerSeed % 3 == 0 {
                        c.setFillColor(flowerColors[flowerSeed % flowerColors.count].cgColor)
                        c.fill(CGRect(x: CGFloat(x + 1) * ps, y: yPos - ps, width: ps, height: ps))
                    }
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
        case .space:                        return renderSpaceTerrainHills()
        }
    }

    // MARK: Sunset Hills — warm amber recolor of classic hills

    private func renderSunsetHills() -> UIImage {
        let w: CGFloat = GK.worldWidth * 2
        let h: CGFloat = 140
        let ps: CGFloat = 4
        let gridW = Int(w / ps)

        var heightMap = [Int](repeating: 1, count: gridW)
        let bumps: [(center: Int, radius: Int, peak: Int)] = [
            (gridW / 8, 14, 10), (gridW / 4, 18, 14), (gridW * 3 / 8, 10, 7),
            (gridW / 2, 16, 12), (gridW * 5 / 8, 12, 9), (gridW * 3 / 4, 17, 13),
            (gridW * 7 / 8, 13, 8),
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
        let h: CGFloat = 140
        let ps: CGFloat = 4
        let gridW = Int(w / ps)

        var heightMap = [Int](repeating: 1, count: gridW)
        let bumps: [(center: Int, radius: Int, peak: Int)] = [
            (gridW / 8, 14, 10), (gridW / 4, 18, 14), (gridW * 3 / 8, 10, 7),
            (gridW / 2, 16, 12), (gridW * 5 / 8, 12, 9), (gridW * 3 / 4, 17, 13),
            (gridW * 7 / 8, 13, 8),
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
        let h: CGFloat = 140
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

        // Deterministic building specs: (xPixel, widthPixels, heightPixels)
        let buildings: [(x: Int, w: Int, h: Int)] = [
            (2, 8, 18), (12, 6, 12), (20, 10, 22), (32, 5, 9),
            (39, 9, 16), (50, 7, 20), (59, 11, 25), (72, 6, 11),
            (80, 8, 17), (90, 10, 23), (102, 5, 8), (109, 9, 19),
            (120, 7, 14), (129, 11, 26), (142, 6, 10), (150, 8, 21),
            (160, 10, 15), (172, 7, 24), (181, 9, 13), (192, 6, 18),
        ]

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let c = ctx.cgContext

            for bld in buildings {
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
                    // Blinking light at tip
                    c.setFillColor(antColor.cgColor)
                    c.fill(CGRect(x: CGFloat(antX) * ps, y: h - CGFloat(bh + 4) * ps, width: ps, height: ps))
                }
            }
        }
    }

    // MARK: Coral Reef Hills — underwater

    private func renderCoralReefHills() -> UIImage {
        let w: CGFloat = GK.worldWidth * 2
        let h: CGFloat = 140
        let ps: CGFloat = 4
        let gridW = Int(w / ps)

        // Coral reef uses overlapping rounded bumps like hills but with vibrant ocean colors
        var heightMap = [Int](repeating: 0, count: gridW)
        let bumps: [(center: Int, radius: Int, peak: Int)] = [
            (gridW / 10, 8, 8), (gridW / 5, 12, 14), (gridW * 3 / 10, 6, 6),
            (gridW * 2 / 5, 14, 16), (gridW / 2, 7, 5), (gridW * 3 / 5, 10, 12),
            (gridW * 7 / 10, 15, 18), (gridW * 4 / 5, 8, 10), (gridW * 9 / 10, 11, 13),
        ]
        for bump in bumps {
            for x in max(0, bump.center - bump.radius)..<min(gridW, bump.center + bump.radius) {
                let dist = abs(x - bump.center)
                let nd = CGFloat(dist) / CGFloat(bump.radius)
                heightMap[x] = max(heightMap[x], Int(CGFloat(bump.peak) * (1.0 - nd * nd)))
            }
        }

        // Coral palette — each "bump" gets a color from this cycle
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

        // Map each x to its dominant bump for coloring
        var bumpOwner = [Int](repeating: 0, count: gridW)
        for (bi, bump) in bumps.enumerated() {
            for x in max(0, bump.center - bump.radius)..<min(gridW, bump.center + bump.radius) {
                let dist = abs(x - bump.center)
                let nd = CGFloat(dist) / CGFloat(bump.radius)
                let bh = Int(CGFloat(bump.peak) * (1.0 - nd * nd))
                if bh >= heightMap[x] { bumpOwner[x] = bi % coralPalette.count }
            }
        }

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let c = ctx.cgContext
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

            // Scattered small coral nubs on top
            let nubColor = UIColor(red: 1.0, green: 0.50, blue: 0.60, alpha: 0.50)
            c.setFillColor(nubColor.cgColor)
            for x in stride(from: 5, to: gridW - 3, by: 9) {
                let ch = heightMap[x]
                if ch > 3 {
                    let yPos = h - CGFloat(ch + 1) * ps
                    c.fill(CGRect(x: CGFloat(x) * ps, y: yPos, width: ps, height: ps))
                }
            }
        }
    }

    // MARK: Volcano Hills — jagged rocky mountains with lava glow

    private func renderVolcanoHills() -> UIImage {
        let w: CGFloat = GK.worldWidth * 2
        let h: CGFloat = 140
        let ps: CGFloat = 4
        let gridW = Int(w / ps)

        // Jagged peaks — sharper bumps with smaller radii
        var heightMap = [Int](repeating: 0, count: gridW)
        let bumps: [(center: Int, radius: Int, peak: Int)] = [
            (gridW / 10, 6, 12), (gridW / 5, 10, 20), (gridW * 3 / 10, 4, 8),
            (gridW * 2 / 5, 8, 18), (gridW / 2, 5, 10), (gridW * 3 / 5, 12, 24),
            (gridW * 7 / 10, 6, 14), (gridW * 4 / 5, 9, 22), (gridW * 9 / 10, 7, 16),
        ]
        for bump in bumps {
            for x in max(0, bump.center - bump.radius)..<min(gridW, bump.center + bump.radius) {
                let dist = abs(x - bump.center)
                let nd = CGFloat(dist) / CGFloat(bump.radius)
                // Steeper falloff for jagged look
                let bh = Int(CGFloat(bump.peak) * max(0, 1.0 - nd * nd * nd))
                heightMap[x] = max(heightMap[x], bh)
            }
        }

        let rockBase = UIColor(red: 0.25, green: 0.15, blue: 0.10, alpha: 0.75)
        let rockMid  = UIColor(red: 0.35, green: 0.22, blue: 0.15, alpha: 0.70)
        let rockTop  = UIColor(red: 0.20, green: 0.12, blue: 0.08, alpha: 0.80)
        let lavaGlow = UIColor(red: 1.0, green: 0.45, blue: 0.10, alpha: 0.60)
        let lavaHot  = UIColor(red: 1.0, green: 0.70, blue: 0.20, alpha: 0.50)

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let c = ctx.cgContext
            for x in 0..<gridW {
                let mtnH = heightMap[x]
                guard mtnH > 0 else { continue }
                for y in 0..<mtnH {
                    let yPos = h - CGFloat(y + 1) * ps
                    let ratio = CGFloat(y) / max(1, CGFloat(mtnH))
                    let color: UIColor
                    if y <= 1 { color = lavaGlow }          // lava glow at base
                    else if y == 2 && mtnH > 5 { color = lavaHot }
                    else if y == mtnH - 1 { color = rockTop }
                    else if ratio > 0.5 { color = rockMid }
                    else { color = rockBase }
                    c.setFillColor(color.cgColor)
                    c.fill(CGRect(x: CGFloat(x) * ps, y: yPos, width: ps, height: ps))
                }
            }
        }
    }

    // MARK: Arctic Hills — snow-capped mountain peaks

    private func renderArcticHills() -> UIImage {
        let w: CGFloat = GK.worldWidth * 2
        let h: CGFloat = 140
        let ps: CGFloat = 4
        let gridW = Int(w / ps)

        var heightMap = [Int](repeating: 1, count: gridW)
        let bumps: [(center: Int, radius: Int, peak: Int)] = [
            (gridW / 8, 16, 12), (gridW / 4, 20, 18), (gridW * 3 / 8, 10, 8),
            (gridW / 2, 18, 16), (gridW * 5 / 8, 14, 11), (gridW * 3 / 4, 22, 20),
            (gridW * 7 / 8, 12, 10),
        ]
        for bump in bumps {
            for x in max(0, bump.center - bump.radius)..<min(gridW, bump.center + bump.radius) {
                let dist = abs(x - bump.center)
                let nd = CGFloat(dist) / CGFloat(bump.radius)
                heightMap[x] = max(heightMap[x], Int(CGFloat(bump.peak) * (1.0 - nd * nd)))
            }
        }

        let rockBase = UIColor(red: 0.45, green: 0.52, blue: 0.62, alpha: 0.55)
        let rockMid  = UIColor(red: 0.55, green: 0.62, blue: 0.72, alpha: 0.50)
        let snowTop  = UIColor(red: 0.95, green: 0.97, blue: 1.0, alpha: 0.70)
        let snowMid  = UIColor(red: 0.85, green: 0.90, blue: 0.95, alpha: 0.60)

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let c = ctx.cgContext
            for x in 0..<gridW {
                let mtnH = heightMap[x]
                for y in 0..<mtnH {
                    let yPos = h - CGFloat(y + 1) * ps
                    let ratio = CGFloat(y) / max(1, CGFloat(mtnH))
                    let color: UIColor
                    // Top 35% is snow, rest is blue-gray rock
                    if ratio > 0.75 { color = snowTop }
                    else if ratio > 0.65 { color = snowMid }
                    else if ratio > 0.35 { color = rockMid }
                    else { color = rockBase }
                    c.setFillColor(color.cgColor)
                    c.fill(CGRect(x: CGFloat(x) * ps, y: yPos, width: ps, height: ps))
                }
            }
        }
    }

    // MARK: Space Terrain Hills — distant cratered planet surface

    private func renderSpaceTerrainHills() -> UIImage {
        let w: CGFloat = GK.worldWidth * 2
        let h: CGFloat = 140
        let ps: CGFloat = 4
        let gridW = Int(w / ps)

        // Lumpy alien terrain
        var heightMap = [Int](repeating: 2, count: gridW)
        let bumps: [(center: Int, radius: Int, peak: Int)] = [
            (gridW / 8, 12, 8), (gridW / 4, 16, 11), (gridW * 3 / 8, 8, 5),
            (gridW / 2, 14, 10), (gridW * 3 / 5, 18, 14), (gridW * 3 / 4, 10, 7),
            (gridW * 9 / 10, 14, 9),
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

        // Crater positions (column index, radius in grid cells)
        let craters: [(cx: Int, r: Int)] = [
            (gridW / 6, 5), (gridW * 2 / 5, 3), (gridW * 2 / 3, 6), (gridW * 5 / 6, 4),
        ]
        var craterMap = [Bool](repeating: false, count: gridW)
        for crater in craters {
            for x in max(0, crater.cx - crater.r)..<min(gridW, crater.cx + crater.r) {
                craterMap[x] = true
                // Dip the heightmap for crater interior
                let dist = abs(x - crater.cx)
                if dist < crater.r {
                    let dip = Int(CGFloat(crater.r - dist) * 0.6)
                    heightMap[x] = max(2, heightMap[x] - dip)
                }
            }
        }
        let craterRim = UIColor(red: 0.28, green: 0.20, blue: 0.42, alpha: 0.55)

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let c = ctx.cgContext
            for x in 0..<gridW {
                let mtnH = heightMap[x]
                for y in 0..<mtnH {
                    let yPos = h - CGFloat(y + 1) * ps
                    let ratio = CGFloat(y) / max(1, CGFloat(mtnH))
                    var color: UIColor
                    if y == mtnH - 1 { color = surfTop }
                    else if ratio > 0.5 { color = surfMid }
                    else { color = surfBase }
                    // Tint crater rims
                    if craterMap[x] && y == mtnH - 1 { color = craterRim }
                    c.setFillColor(color.cgColor)
                    c.fill(CGRect(x: CGFloat(x) * ps, y: yPos, width: ps, height: ps))
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
        case .space:                        return renderSpaceStructures()
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
        let tT = UIColor(red: 0.15, green: 0.10, blue: 0.07, alpha: 0.75)
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
        let rL = UIColor(red: 1.0, green: 0.25, blue: 0.25, alpha: 0.70)  // red light

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
        case .space:                        return renderSpaceDebrisStrip()
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
}
