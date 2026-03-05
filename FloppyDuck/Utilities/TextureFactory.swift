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

    /// Green gradient pipe body with pixel border
    func pipeTexture(height: CGFloat) -> SKTexture {
        let key = "pipe_\(Int(height))"
        if let cached = cache[key] { return cached }
        let tex = SKTexture(image: renderPipe(width: GK.pipeWidth, height: height))
        tex.filteringMode = .nearest
        cache[key] = tex
        return tex
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

    /// UIImage of duck for SwiftUI views
    func duckUIImage(pixelScale: CGFloat = 3.0) -> UIImage {
        return renderMallardDuck(wingPhase: 1, pixelSize: pixelScale)
    }

    /// Bread currency icon for SwiftUI
    func breadUIImage(pixelScale: CGFloat = 4.0) -> UIImage {
        return renderBread(pixelSize: pixelScale)
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

        let alpha: CGFloat = ghost ? 0.55 : 1.0

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

    // MARK: - Sky (warm blue gradient)

    private func renderSky() -> UIImage {
        let size = CGSize(width: GK.worldWidth, height: GK.worldHeight)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let c = ctx.cgContext
            let colors = [
                UIColor(red: 0.35, green: 0.65, blue: 0.90, alpha: 1).cgColor,
                UIColor(red: 0.55, green: 0.78, blue: 0.92, alpha: 1).cgColor,
                UIColor(red: 0.75, green: 0.90, blue: 0.95, alpha: 1).cgColor
            ]
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors as CFArray,
                locations: [0.0, 0.5, 1.0]
            )!
            c.drawLinearGradient(gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: 0, y: size.height),
                options: [])
        }
    }

    // MARK: - Pixel Cloud

    private func renderPixelCloud() -> UIImage {
        let ps: CGFloat = 5  // pixel size
        let W = UIColor(white: 1.0, alpha: 0.92)
        let L = UIColor(white: 0.88, alpha: 0.85)   // subtle shadow
        let C = UIColor.clear

        // 16×7 pixel cloud — chunky retro style
        let grid: [[UIColor]] = [
            [C,C,C,C,W,W,W,C,C,C,C,C,C,C,C,C],
            [C,C,C,W,W,W,W,W,C,C,W,W,C,C,C,C],
            [C,C,W,W,W,W,W,W,W,W,W,W,W,C,C,C],
            [C,W,W,W,W,W,W,W,W,W,W,W,W,W,C,C],
            [W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,C],
            [C,L,L,W,W,W,W,W,W,W,W,W,W,L,C,C],
            [C,C,C,L,L,L,L,L,L,L,L,L,C,C,C,C],
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
        let h: CGFloat = 120
        let ps: CGFloat = 4  // pixel size

        let gridW = Int(w / ps)
        let gridH = Int(h / ps)

        // Generate stepped hill silhouette using overlapping bumps
        var heightMap = [Int](repeating: 1, count: gridW)

        // Deterministic hill bumps (seeded so they look good)
        let bumps: [(center: Int, radius: Int, peak: Int)] = [
            (gridW / 8,     14, 10),
            (gridW / 4,     18, 14),
            (gridW * 3 / 8, 10, 7),
            (gridW / 2,     16, 12),
            (gridW * 5 / 8, 12, 9),
            (gridW * 3 / 4, 17, 13),
            (gridW * 7 / 8, 13, 8),
        ]

        for bump in bumps {
            for x in max(0, bump.center - bump.radius)..<min(gridW, bump.center + bump.radius) {
                let dist = abs(x - bump.center)
                let nd = CGFloat(dist) / CGFloat(bump.radius)
                let bh = Int(CGFloat(bump.peak) * (1.0 - nd * nd))
                heightMap[x] = max(heightMap[x], bh)
            }
        }

        let hillFill = UIColor(red: 0.50, green: 0.72, blue: 0.45, alpha: 0.40)
        let hillTop  = UIColor(red: 0.42, green: 0.62, blue: 0.38, alpha: 0.45)  // darker top edge

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let c = ctx.cgContext
            for x in 0..<gridW {
                for y in 0..<heightMap[x] {
                    let yPos = h - CGFloat(y + 1) * ps
                    let color = (y == heightMap[x] - 1) ? hillTop : hillFill
                    c.setFillColor(color.cgColor)
                    c.fill(CGRect(x: CGFloat(x) * ps, y: yPos, width: ps, height: ps))
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
