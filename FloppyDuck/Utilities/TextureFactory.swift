import SpriteKit
import UIKit

/// Generates all game textures programmatically using pixel-art style rendering.
/// Park theme with mallard duck.
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

    /// Scrolling ground tile — park grass with flowers
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

    /// Park trees for parallax background
    func treesTexture() -> SKTexture {
        let key = "trees"
        if let cached = cache[key] { return cached }
        let tex = SKTexture(image: renderParkTrees())
        tex.filteringMode = .nearest
        cache[key] = tex
        return tex
    }

    /// Distant hills
    func hillsTexture() -> SKTexture {
        let key = "hills"
        if let cached = cache[key] { return cached }
        let tex = SKTexture(image: renderHills())
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

    // MARK: - Mallard Duck (Pixel Art)

    /// Mallard duck: green iridescent head, white collar, chestnut breast, gray body
    /// 20 wide × 14 tall pixel grid
    private func renderMallardDuck(wingPhase: Int, pixelSize: CGFloat = 3.0) -> UIImage {
        let gridW = 20
        let gridH = 14
        let imgSize = CGSize(width: CGFloat(gridW) * pixelSize, height: CGFloat(gridH) * pixelSize)

        // Color definitions — mallard palette
        let G = UIColor(red: 0.08, green: 0.42, blue: 0.22, alpha: 1)  // dark green (head)
        let g = UIColor(red: 0.12, green: 0.56, blue: 0.32, alpha: 1)  // light green (head highlight)
        let W = UIColor.white                                            // white (eye, collar)
        let B = UIColor.black                                            // black (outline, pupil, tail)
        let R = UIColor(red: 0.55, green: 0.22, blue: 0.10, alpha: 1)  // chestnut (breast)
        let r = UIColor(red: 0.65, green: 0.30, blue: 0.15, alpha: 1)  // lighter brown
        let A = UIColor(red: 0.60, green: 0.60, blue: 0.60, alpha: 1)  // gray (body)
        let a = UIColor(red: 0.72, green: 0.72, blue: 0.72, alpha: 1)  // light gray
        let O = UIColor(red: 0.93, green: 0.65, blue: 0.10, alpha: 1)  // orange-yellow (bill)
        let o = UIColor(red: 0.85, green: 0.75, blue: 0.15, alpha: 1)  // yellow-green (bill tip)
        let U = UIColor(red: 0.15, green: 0.30, blue: 0.70, alpha: 1)  // blue (speculum)
        let u = UIColor(red: 0.25, green: 0.45, blue: 0.85, alpha: 1)  // light blue
        let C = UIColor.clear

        // Pixel grid — row 0 is top
        var grid: [[UIColor]] = []

        // Row 0:  head crest
        grid.append([C,C,C,C,C,C,C,C,B,B,B,C,C,C,C,C,C,C,C,C])
        // Row 1:  head top
        grid.append([C,C,C,C,C,C,B,B,G,G,G,B,B,C,C,C,C,C,C,C])
        // Row 2:  head with eye
        grid.append([C,C,C,C,C,B,G,g,G,W,W,G,g,B,C,C,C,C,C,C])
        // Row 3:  eye pupil + bill
        grid.append([C,C,C,C,B,G,G,g,W,B,W,G,B,B,B,B,B,C,C,C])
        // Row 4:  head + full bill
        grid.append([C,C,C,B,G,G,G,G,G,G,G,B,O,O,o,O,B,C,C,C])
        // Row 5:  white collar + bill bottom
        grid.append([C,C,B,W,W,W,W,W,G,G,B,O,O,O,O,B,C,C,C,C])
        // Row 6:  chest (chestnut) starts
        grid.append([C,B,R,R,R,r,W,W,W,W,W,B,B,C,C,C,C,C,C,C])
        // Row 7:  chest + wing
        grid.append([B,R,R,r,A,A,A,a,a,a,a,a,B,C,C,C,C,C,C,C])
        // Row 8:  body with speculum
        grid.append([B,R,r,A,A,U,u,U,a,a,a,A,A,B,C,C,C,C,C,C])
        // Row 9:  gray body
        grid.append([B,A,A,A,A,A,a,a,a,a,A,A,B,C,C,C,C,C,C,C])
        // Row 10: lower body + tail curl
        grid.append([C,B,A,A,A,A,A,A,A,B,B,B,C,C,C,C,C,C,C,C])
        // Row 11: tail + feet gap
        grid.append([C,C,B,B,B,A,A,B,B,C,C,C,C,C,C,C,C,C,C,C])
        // Row 12: feet
        grid.append([C,C,C,C,B,O,B,C,B,O,B,C,C,C,C,C,C,C,C,C])
        // Row 13: feet pads
        grid.append([C,C,C,B,O,O,O,B,O,O,O,B,C,C,C,C,C,C,C,C])

        // Wing animation
        if wingPhase == 0 {
            // Wing up — shift wing detail up
            grid[6][4] = A; grid[6][5] = U; grid[6][6] = u
            grid[8][4] = r; grid[8][5] = A; grid[8][6] = A
        } else if wingPhase == 2 {
            // Wing down — shift wing detail down
            grid[8][4] = A; grid[8][5] = A; grid[8][6] = A
            grid[10][3] = U; grid[10][4] = u; grid[10][5] = U
        }

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

    // MARK: - Bread (Currency Icon)

    private func renderBread(pixelSize: CGFloat = 3.0) -> UIImage {
        let gridW = 10
        let gridH = 8
        let imgSize = CGSize(width: CGFloat(gridW) * pixelSize, height: CGFloat(gridH) * pixelSize)

        let B = UIColor.black
        let L = UIColor(red: 0.85, green: 0.68, blue: 0.30, alpha: 1)  // light crust
        let D = UIColor(red: 0.65, green: 0.45, blue: 0.18, alpha: 1)  // dark crust
        let I = UIColor(red: 0.95, green: 0.88, blue: 0.60, alpha: 1)  // inner bread
        let H = UIColor(red: 0.98, green: 0.92, blue: 0.72, alpha: 1)  // highlight
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

    // MARK: - Pipes (classic green — reads as park gates)

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

    // MARK: - Ground (park grass with flowers + dirt path)

    private func renderGround() -> UIImage {
        let w: CGFloat = GK.worldWidth * 2
        let h: CGFloat = GK.groundHeight
        let grassH: CGFloat = 22
        let size = CGSize(width: w, height: h)

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let c = ctx.cgContext

            // Tan/earth base with slight warmth
            c.setFillColor(UIColor(red: 0.78, green: 0.70, blue: 0.50, alpha: 1).cgColor)
            c.fill(CGRect(origin: .zero, size: size))

            // Dirt path texture — diagonal lines
            c.setStrokeColor(UIColor(red: 0.72, green: 0.64, blue: 0.44, alpha: 1).cgColor)
            c.setLineWidth(3)
            var x: CGFloat = -h
            while x < w + h {
                c.move(to: CGPoint(x: x, y: h))
                c.addLine(to: CGPoint(x: x + h, y: 0))
                x += 14
            }
            c.strokePath()

            // Pebbles on dirt path
            c.setFillColor(UIColor(red: 0.68, green: 0.60, blue: 0.42, alpha: 0.6).cgColor)
            var px: CGFloat = 8
            while px < w {
                let pSize = CGFloat.random(in: 2...5)
                c.fillEllipse(in: CGRect(x: px, y: CGFloat.random(in: grassH + 5 ... h - 5),
                                          width: pSize, height: pSize * 0.7))
                px += CGFloat.random(in: 15...30)
            }

            // Bright green grass top
            c.setFillColor(UIColor(red: 0.40, green: 0.72, blue: 0.22, alpha: 1).cgColor)
            c.fill(CGRect(x: 0, y: 0, width: w, height: grassH))

            // Darker grass line at very top
            c.setFillColor(UIColor(red: 0.28, green: 0.52, blue: 0.16, alpha: 1).cgColor)
            c.fill(CGRect(x: 0, y: 0, width: w, height: 4))

            // Grass tufts
            c.setFillColor(UIColor(red: 0.45, green: 0.78, blue: 0.26, alpha: 1).cgColor)
            var tx: CGFloat = 0
            while tx < w {
                let tuftW = CGFloat.random(in: 5...9)
                c.move(to: CGPoint(x: tx, y: grassH))
                c.addLine(to: CGPoint(x: tx + tuftW / 2, y: grassH + 5))
                c.addLine(to: CGPoint(x: tx + tuftW, y: grassH))
                c.fillPath()
                tx += CGFloat.random(in: 10...18)
            }

            // Tiny flowers scattered in grass
            let flowerColors: [UIColor] = [
                UIColor(red: 0.95, green: 0.35, blue: 0.35, alpha: 1),  // red
                UIColor(red: 0.95, green: 0.85, blue: 0.20, alpha: 1),  // yellow
                UIColor(red: 0.90, green: 0.50, blue: 0.80, alpha: 1),  // pink
                UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1),  // white
            ]
            var fx: CGFloat = CGFloat.random(in: 20...40)
            while fx < w {
                let fc = flowerColors[Int.random(in: 0..<flowerColors.count)]
                c.setFillColor(fc.cgColor)
                let fy = CGFloat.random(in: 4...grassH - 4)
                c.fillEllipse(in: CGRect(x: fx - 2, y: fy - 2, width: 4, height: 4))
                // Center dot
                c.setFillColor(UIColor(red: 1.0, green: 0.90, blue: 0.30, alpha: 1).cgColor)
                c.fillEllipse(in: CGRect(x: fx - 0.5, y: fy - 0.5, width: 1.5, height: 1.5))
                fx += CGFloat.random(in: 25...50)
            }
        }
    }

    // MARK: - Sky (warm blue park sky)

    private func renderSky() -> UIImage {
        let size = CGSize(width: GK.worldWidth, height: GK.worldHeight)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let c = ctx.cgContext
            let colors = [
                UIColor(red: 0.35, green: 0.65, blue: 0.90, alpha: 1).cgColor,  // top: warm blue
                UIColor(red: 0.55, green: 0.78, blue: 0.92, alpha: 1).cgColor,  // mid
                UIColor(red: 0.75, green: 0.90, blue: 0.95, alpha: 1).cgColor   // bottom: light
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

    // MARK: - Cloud

    private func renderCloud() -> UIImage {
        let w: CGFloat = 80
        let h: CGFloat = 30
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let c = ctx.cgContext
            c.setFillColor(UIColor(white: 1.0, alpha: 0.90).cgColor)
            let puffs: [(x: CGFloat, y: CGFloat, r: CGFloat)] = [
                (20, 18, 14), (35, 12, 16), (52, 16, 13),
                (42, 20, 12), (28, 22, 10), (60, 20, 10),
            ]
            for p in puffs {
                c.fillEllipse(in: CGRect(x: p.x - p.r, y: p.y - p.r, width: p.r * 2, height: p.r * 2))
            }
        }
    }

    // MARK: - Distant Hills

    private func renderHills() -> UIImage {
        let w: CGFloat = GK.worldWidth * 2
        let h: CGFloat = 120
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let c = ctx.cgContext

            // Far hills (lighter)
            c.setFillColor(UIColor(red: 0.55, green: 0.75, blue: 0.50, alpha: 0.35).cgColor)
            c.move(to: CGPoint(x: 0, y: h))
            var hx: CGFloat = 0
            while hx <= w {
                let hy = h - CGFloat.random(in: 40...90)
                let cpx = hx + CGFloat.random(in: 30...60)
                c.addQuadCurve(to: CGPoint(x: hx + CGFloat.random(in: 60...120), y: h - CGFloat.random(in: 30...50)),
                               control: CGPoint(x: cpx, y: hy))
                hx += CGFloat.random(in: 80...150)
            }
            c.addLine(to: CGPoint(x: w, y: h))
            c.closePath()
            c.fillPath()

            // Near hills (darker)
            c.setFillColor(UIColor(red: 0.42, green: 0.65, blue: 0.38, alpha: 0.40).cgColor)
            c.move(to: CGPoint(x: 0, y: h))
            hx = 0
            while hx <= w {
                let hy = h - CGFloat.random(in: 25...60)
                let cpx = hx + CGFloat.random(in: 25...50)
                c.addQuadCurve(to: CGPoint(x: hx + CGFloat.random(in: 50...100), y: h - CGFloat.random(in: 15...35)),
                               control: CGPoint(x: cpx, y: hy))
                hx += CGFloat.random(in: 60...120)
            }
            c.addLine(to: CGPoint(x: w, y: h))
            c.closePath()
            c.fillPath()
        }
    }

    // MARK: - Park Trees (parallax mid-layer)

    private func renderParkTrees() -> UIImage {
        let w: CGFloat = GK.worldWidth * 2
        let h: CGFloat = 160
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let c = ctx.cgContext

            var tx: CGFloat = CGFloat.random(in: 10...30)
            while tx < w {
                let treeType = Int.random(in: 0...2)
                let treeH = CGFloat.random(in: 60...120)
                let trunkW: CGFloat = CGFloat.random(in: 8...14)
                let trunkH: CGFloat = treeH * 0.35
                let canopyW = CGFloat.random(in: 35...60)
                let canopyH = treeH * 0.70

                let baseY = h  // bottom of texture

                // Trunk
                c.setFillColor(UIColor(red: 0.45, green: 0.32, blue: 0.18, alpha: 0.7).cgColor)
                c.fill(CGRect(x: tx - trunkW / 2, y: baseY - trunkH, width: trunkW, height: trunkH))

                // Canopy
                let canopyY = baseY - trunkH - canopyH * 0.6

                if treeType == 0 {
                    // Round deciduous tree
                    let darkGreen = UIColor(red: 0.25, green: 0.55, blue: 0.20, alpha: 0.75)
                    let lightGreen = UIColor(red: 0.35, green: 0.70, blue: 0.28, alpha: 0.65)

                    c.setFillColor(darkGreen.cgColor)
                    c.fillEllipse(in: CGRect(x: tx - canopyW / 2, y: canopyY, width: canopyW, height: canopyH))

                    // Highlight blob
                    c.setFillColor(lightGreen.cgColor)
                    c.fillEllipse(in: CGRect(x: tx - canopyW * 0.3, y: canopyY + canopyH * 0.1,
                                              width: canopyW * 0.5, height: canopyH * 0.5))
                } else if treeType == 1 {
                    // Bushy tree (multiple circles)
                    let green1 = UIColor(red: 0.30, green: 0.58, blue: 0.22, alpha: 0.70)
                    let green2 = UIColor(red: 0.22, green: 0.48, blue: 0.18, alpha: 0.75)

                    c.setFillColor(green2.cgColor)
                    c.fillEllipse(in: CGRect(x: tx - canopyW * 0.45, y: canopyY + canopyH * 0.2,
                                              width: canopyW * 0.5, height: canopyH * 0.6))
                    c.fillEllipse(in: CGRect(x: tx + canopyW * 0.0, y: canopyY + canopyH * 0.15,
                                              width: canopyW * 0.5, height: canopyH * 0.65))
                    c.setFillColor(green1.cgColor)
                    c.fillEllipse(in: CGRect(x: tx - canopyW * 0.25, y: canopyY,
                                              width: canopyW * 0.55, height: canopyH * 0.55))
                } else {
                    // Triangular / pine-ish tree
                    let pineGreen = UIColor(red: 0.20, green: 0.50, blue: 0.22, alpha: 0.75)
                    c.setFillColor(pineGreen.cgColor)

                    c.move(to: CGPoint(x: tx, y: canopyY))
                    c.addLine(to: CGPoint(x: tx - canopyW * 0.45, y: canopyY + canopyH))
                    c.addLine(to: CGPoint(x: tx + canopyW * 0.45, y: canopyY + canopyH))
                    c.closePath()
                    c.fillPath()

                    // Second triangle overlap
                    let pineLight = UIColor(red: 0.28, green: 0.58, blue: 0.26, alpha: 0.60)
                    c.setFillColor(pineLight.cgColor)
                    c.move(to: CGPoint(x: tx, y: canopyY + canopyH * 0.2))
                    c.addLine(to: CGPoint(x: tx - canopyW * 0.35, y: canopyY + canopyH * 0.9))
                    c.addLine(to: CGPoint(x: tx + canopyW * 0.35, y: canopyY + canopyH * 0.9))
                    c.closePath()
                    c.fillPath()
                }

                // Bush at base
                if Bool.random() {
                    c.setFillColor(UIColor(red: 0.30, green: 0.60, blue: 0.25, alpha: 0.55).cgColor)
                    let bushW = CGFloat.random(in: 18...30)
                    c.fillEllipse(in: CGRect(x: tx + CGFloat.random(in: -20...15),
                                              y: baseY - CGFloat.random(in: 10...20),
                                              width: bushW, height: bushW * 0.6))
                }

                tx += CGFloat.random(in: 50...100)
            }

            // Park benches scattered
            var bx: CGFloat = CGFloat.random(in: 100...200)
            while bx < w {
                // Bench silhouette
                c.setFillColor(UIColor(red: 0.40, green: 0.28, blue: 0.15, alpha: 0.5).cgColor)
                let benchY = h - 12
                // Seat
                c.fill(CGRect(x: bx, y: benchY, width: 24, height: 4))
                // Back
                c.fill(CGRect(x: bx + 1, y: benchY - 10, width: 22, height: 3))
                // Legs
                c.fill(CGRect(x: bx + 2, y: benchY, width: 3, height: 10))
                c.fill(CGRect(x: bx + 19, y: benchY, width: 3, height: 10))

                bx += CGFloat.random(in: 200...400)
            }
        }
    }
}
