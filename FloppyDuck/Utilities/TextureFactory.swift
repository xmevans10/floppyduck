import SpriteKit
import UIKit

/// Generates all game textures programmatically using pixel-art style rendering.
/// Matches the classic Flappy Bird retro aesthetic.
final class TextureFactory {
    static let shared = TextureFactory()
    private init() {}

    private var cache: [String: SKTexture] = [:]

    // MARK: - Public API

    /// Pixel-art duck body (wing up, mid, down)
    func duckTexture(wingPhase: Int) -> SKTexture {
        let key = "duck_\(wingPhase)"
        if let cached = cache[key] { return cached }
        let tex = SKTexture(image: renderPixelDuck(wingPhase: wingPhase))
        tex.filteringMode = .nearest   // pixel-crisp scaling
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

    /// Pipe cap (top of pipe) with lip
    func pipeCapTexture() -> SKTexture {
        let key = "pipecap"
        if let cached = cache[key] { return cached }
        let tex = SKTexture(image: renderPipeCap())
        tex.filteringMode = .nearest
        cache[key] = tex
        return tex
    }

    /// Scrolling ground tile with grass and dirt stripes
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

    /// Puffy pixel cloud
    func cloudTexture() -> SKTexture {
        let key = "cloud"
        if let cached = cache[key] { return cached }
        let tex = SKTexture(image: renderCloud())
        tex.filteringMode = .nearest
        cache[key] = tex
        return tex
    }

    /// City silhouette for parallax
    func buildingTexture() -> SKTexture {
        let key = "buildings"
        if let cached = cache[key] { return cached }
        let tex = SKTexture(image: renderBuildings())
        tex.filteringMode = .nearest
        cache[key] = tex
        return tex
    }

    /// UIImage of duck for SwiftUI views
    func duckUIImage(pixelScale: CGFloat = 3.0) -> UIImage {
        return renderPixelDuck(wingPhase: 1, pixelSize: pixelScale)
    }

    // MARK: - Pixel Duck

    /// Draws a pixel-art duck similar to the classic Flappy Bird bird style.
    /// 17 wide x 12 tall pixel grid, then scaled up.
    private func renderPixelDuck(wingPhase: Int, pixelSize: CGFloat = 3.0) -> UIImage {
        let gridW = 17
        let gridH = 12
        let imgSize = CGSize(width: CGFloat(gridW) * pixelSize, height: CGFloat(gridH) * pixelSize)

        // Color definitions
        let Y = UIColor(red: 0.98, green: 0.80, blue: 0.18, alpha: 1) // yellow body
        let O = UIColor(red: 0.93, green: 0.49, blue: 0.13, alpha: 1) // orange (beak, feet)
        let W = UIColor.white                                           // white (eye, belly)
        let B = UIColor.black                                           // black (outline, pupil)
        let D = UIColor(red: 0.85, green: 0.68, blue: 0.10, alpha: 1) // darker yellow (wing)
        let R = UIColor(red: 0.90, green: 0.25, blue: 0.20, alpha: 1) // red (crest accent)
        let _ = UIColor.clear                                           // transparent
        let C = UIColor.clear

        // Pixel grid - row 0 is top
        // B=black, Y=yellow, O=orange, W=white, D=dark yellow, R=red, C=clear
        var grid: [[UIColor]] = []

        // Row 0:  crest hint
        grid.append([C,C,C,C,C,C,C,B,B,B,C,C,C,C,C,C,C])
        // Row 1:  head top
        grid.append([C,C,C,C,C,B,B,Y,Y,Y,B,B,C,C,C,C,C])
        // Row 2:  head with eye white
        grid.append([C,C,C,C,B,Y,Y,Y,W,W,W,Y,B,C,C,C,C])
        // Row 3:  eye with pupil + beak start
        grid.append([C,C,C,B,Y,Y,Y,W,B,B,W,Y,B,B,B,B,C])
        // Row 4:  body + beak
        grid.append([C,C,B,Y,Y,Y,Y,Y,W,B,Y,B,O,O,O,O,B])
        // Row 5:  body + beak bottom
        grid.append([C,B,Y,Y,Y,Y,Y,Y,Y,Y,B,O,O,O,O,B,C])
        // Row 6:  belly (white) + wing
        grid.append([C,B,Y,Y,D,D,D,W,W,W,W,W,B,B,C,C,C])
        // Row 7:  belly
        grid.append([B,Y,Y,D,D,D,W,W,W,W,W,W,W,B,C,C,C])
        // Row 8:  lower body
        grid.append([B,Y,Y,Y,D,D,Y,Y,W,W,W,Y,B,C,C,C,C])
        // Row 9:  bottom
        grid.append([C,B,Y,Y,Y,Y,Y,Y,Y,Y,B,B,C,C,C,C,C])
        // Row 10: tail/feet
        grid.append([C,C,B,B,Y,Y,Y,B,B,B,C,C,C,C,C,C,C])
        // Row 11: feet
        grid.append([C,C,C,C,B,B,C,C,C,C,C,C,C,C,C,C,C])

        // Adjust wing based on phase
        if wingPhase == 0 {
            // Wing up - shift wing pixels up by 1
            grid[5][3] = D; grid[5][4] = D; grid[5][5] = D
            grid[7][3] = Y; grid[7][4] = Y; grid[7][5] = Y
        } else if wingPhase == 2 {
            // Wing down - shift wing pixels down by 1
            grid[6][3] = Y; grid[6][4] = Y; grid[6][5] = Y
            grid[9][3] = D; grid[9][4] = D; grid[9][5] = D
        }
        // phase 1 = mid (default grid)

        let renderer = UIGraphicsImageRenderer(size: imgSize)
        return renderer.image { ctx in
            for row in 0..<gridH {
                for col in 0..<gridW {
                    let color = grid[row][col]
                    guard color != UIColor.clear else { continue }
                    color.setFill()
                    let rect = CGRect(
                        x: CGFloat(col) * pixelSize,
                        y: CGFloat(row) * pixelSize,
                        width: pixelSize,
                        height: pixelSize
                    )
                    ctx.fill(rect)
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

            // Dark green border
            c.setFillColor(UIColor(red: 0.20, green: 0.33, blue: 0.10, alpha: 1).cgColor)
            c.fill(CGRect(origin: .zero, size: size))

            // Main green body (inset by border)
            let body = CGRect(x: borderW, y: 0, width: width - borderW * 2, height: height)
            c.setFillColor(UIColor(red: 0.45, green: 0.75, blue: 0.18, alpha: 1).cgColor)
            c.fill(body)

            // Left highlight stripe
            let highlight = CGRect(x: borderW + 3, y: 0, width: highlightW, height: height)
            c.setFillColor(UIColor(red: 0.55, green: 0.85, blue: 0.28, alpha: 1).cgColor)
            c.fill(highlight)

            // Right shadow stripe
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

            // Dark green border
            c.setFillColor(UIColor(red: 0.20, green: 0.33, blue: 0.10, alpha: 1).cgColor)
            c.fill(CGRect(origin: .zero, size: size))

            // Inner green
            let inner = CGRect(x: borderW, y: borderW, width: capW - borderW * 2, height: capH - borderW * 2)
            c.setFillColor(UIColor(red: 0.45, green: 0.75, blue: 0.18, alpha: 1).cgColor)
            c.fill(inner)

            // Highlight on left
            let hl = CGRect(x: borderW + 3, y: borderW, width: 6, height: capH - borderW * 2)
            c.setFillColor(UIColor(red: 0.55, green: 0.85, blue: 0.28, alpha: 1).cgColor)
            c.fill(hl)

            // Shadow on right
            let sh = CGRect(x: capW - borderW - 7, y: borderW, width: 6, height: capH - borderW * 2)
            c.setFillColor(UIColor(red: 0.34, green: 0.54, blue: 0.13, alpha: 1).cgColor)
            c.fill(sh)
        }
    }

    // MARK: - Ground (green grass + tan dirt + diagonal stripes)

    private func renderGround() -> UIImage {
        let w: CGFloat = GK.worldWidth * 2
        let h: CGFloat = GK.groundHeight
        let grassH: CGFloat = 20
        let size = CGSize(width: w, height: h)

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let c = ctx.cgContext

            // Tan/earth base
            c.setFillColor(UIColor(red: 0.87, green: 0.85, blue: 0.58, alpha: 1).cgColor)
            c.fill(CGRect(origin: .zero, size: size))

            // Diagonal green stripes on tan
            c.setStrokeColor(UIColor(red: 0.80, green: 0.78, blue: 0.50, alpha: 1).cgColor)
            c.setLineWidth(4)
            let stripeSpacing: CGFloat = 12
            var x: CGFloat = -h
            while x < w + h {
                c.move(to: CGPoint(x: x, y: h))
                c.addLine(to: CGPoint(x: x + h, y: 0))
                x += stripeSpacing
            }
            c.strokePath()

            // Bright green grass top
            c.setFillColor(UIColor(red: 0.51, green: 0.76, blue: 0.24, alpha: 1).cgColor)
            c.fill(CGRect(x: 0, y: 0, width: w, height: grassH))

            // Darker green grass line at very top
            c.setFillColor(UIColor(red: 0.33, green: 0.55, blue: 0.18, alpha: 1).cgColor)
            c.fill(CGRect(x: 0, y: 0, width: w, height: 4))

            // Grass tufts (small triangular bumps)
            c.setFillColor(UIColor(red: 0.51, green: 0.76, blue: 0.24, alpha: 1).cgColor)
            var tx: CGFloat = 0
            while tx < w {
                let tuftW: CGFloat = CGFloat.random(in: 6...10)
                c.move(to: CGPoint(x: tx, y: grassH))
                c.addLine(to: CGPoint(x: tx + tuftW / 2, y: grassH + 4))
                c.addLine(to: CGPoint(x: tx + tuftW, y: grassH))
                c.fillPath()
                tx += CGFloat.random(in: 14...22)
            }
        }
    }

    // MARK: - Sky (bright cyan gradient like classic Flappy Bird)

    private func renderSky() -> UIImage {
        let size = CGSize(width: GK.worldWidth, height: GK.worldHeight)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let c = ctx.cgContext
            let colors = [
                UIColor(red: 0.31, green: 0.75, blue: 0.79, alpha: 1).cgColor,  // top: cyan
                UIColor(red: 0.56, green: 0.86, blue: 0.87, alpha: 1).cgColor,  // mid
                UIColor(red: 0.72, green: 0.91, blue: 0.92, alpha: 1).cgColor   // bottom: light
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

    // MARK: - Cloud (puffy white/light pixel cloud)

    private func renderCloud() -> UIImage {
        let w: CGFloat = 80
        let h: CGFloat = 30
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let c = ctx.cgContext

            // Cloud puffs - overlapping circles
            c.setFillColor(UIColor(white: 1.0, alpha: 0.90).cgColor)
            let puffs: [(x: CGFloat, y: CGFloat, r: CGFloat)] = [
                (20, 18, 14),
                (35, 12, 16),
                (52, 16, 13),
                (42, 20, 12),
                (28, 22, 10),
                (60, 20, 10),
            ]
            for p in puffs {
                c.fillEllipse(in: CGRect(x: p.x - p.r, y: p.y - p.r, width: p.r * 2, height: p.r * 2))
            }
        }
    }

    // MARK: - City Silhouette (light green, behind clouds)

    private func renderBuildings() -> UIImage {
        let w: CGFloat = GK.worldWidth * 2
        let h: CGFloat = 140
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let c = ctx.cgContext

            // Light green tint buildings
            c.setFillColor(UIColor(red: 0.38, green: 0.63, blue: 0.45, alpha: 0.35).cgColor)

            var x: CGFloat = 0
            while x < w {
                let bw = CGFloat.random(in: 25...55)
                let bh = CGFloat.random(in: 40...110)
                c.fill(CGRect(x: x, y: h - bh, width: bw, height: bh))

                // Window dots
                c.setFillColor(UIColor(red: 0.45, green: 0.72, blue: 0.55, alpha: 0.25).cgColor)
                var wy = h - bh + 8
                while wy < h - 8 {
                    var wx = x + 6
                    while wx < x + bw - 6 {
                        c.fill(CGRect(x: wx, y: wy, width: 4, height: 4))
                        wx += 10
                    }
                    wy += 10
                }

                c.setFillColor(UIColor(red: 0.38, green: 0.63, blue: 0.45, alpha: 0.35).cgColor)
                x += bw + CGFloat.random(in: 4...12)
            }
        }
    }
}
