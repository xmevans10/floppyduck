import SwiftUI

// MARK: - Public API

/// Per-theme mini-scene preview for Collection / Shop selection cards.
/// Each theme gets a bespoke composition — no generic template.
struct ThemePreviewView: View {
    let theme: BackgroundTheme

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            Canvas { ctx, size in
                drawScene(ctx: &ctx, w: w, h: h)
            }
        }
    }

    // MARK: - Scene Dispatcher

    private func drawScene(ctx: inout GraphicsContext, w: CGFloat, h: CGFloat) {
        switch theme {
        case .day:        drawDay(ctx: &ctx, w: w, h: h)
        case .sunset:     drawSunset(ctx: &ctx, w: w, h: h)
        case .night:      drawNight(ctx: &ctx, w: w, h: h)
        case .neonCity:   drawNeonCity(ctx: &ctx, w: w, h: h)
        case .pixelTokyo: drawPixelTokyo(ctx: &ctx, w: w, h: h)
        case .underwater: drawUnderwater(ctx: &ctx, w: w, h: h)
        case .volcano:    drawVolcano(ctx: &ctx, w: w, h: h)
        case .arctic:     drawArctic(ctx: &ctx, w: w, h: h)
        case .western:    drawWestern(ctx: &ctx, w: w, h: h)
        case .jungle:     drawJungle(ctx: &ctx, w: w, h: h)
        case .egypt:      drawEgypt(ctx: &ctx, w: w, h: h)
        case .cave:       drawCave(ctx: &ctx, w: w, h: h)
        case .mountain:   drawMountain(ctx: &ctx, w: w, h: h)
        case .space:      drawSpace(ctx: &ctx, w: w, h: h)
        case .lagoon:     drawLagoon(ctx: &ctx, w: w, h: h)
        case .losAngeles: drawLosAngeles(ctx: &ctx, w: w, h: h)
        case .london:     drawLondon(ctx: &ctx, w: w, h: h)
        case .roughOcean: drawRoughOcean(ctx: &ctx, w: w, h: h)
        }
    }

    // MARK: - Pixel Helpers

    private let px: CGFloat = 2 // pixel size for preview

    private func fill(_ ctx: inout GraphicsContext, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, _ color: Color) {
        ctx.fill(Path(CGRect(x: x, y: y, width: w, height: h)), with: .color(color))
    }

    private func pixel(_ ctx: inout GraphicsContext, x: CGFloat, y: CGFloat, _ color: Color) {
        fill(&ctx, x: x, y: y, w: px, h: px, color)
    }

    private func skyGradient(_ ctx: inout GraphicsContext, w: CGFloat, h: CGFloat) {
        let colors = theme.gradientColors
        let bands = Int(h / px)
        for i in 0..<bands {
            let t = CGFloat(i) / CGFloat(max(1, bands - 1))
            let color = interpolateGradient(colors: colors, t: t)
            fill(&ctx, x: 0, y: CGFloat(i) * px, w: w, h: px, color)
        }
    }

    private func interpolateGradient(colors: [Color], t: CGFloat) -> Color {
        guard colors.count > 1 else { return colors.first ?? .black }
        let segment = t * CGFloat(colors.count - 1)
        let idx = min(Int(segment), colors.count - 2)
        let localT = segment - CGFloat(idx)
        return blend(colors[idx], colors[idx + 1], t: localT)
    }

    private func blend(_ a: Color, _ b: Color, t: CGFloat) -> Color {
        // Simple blend — SwiftUI doesn't expose components easily, so we use opacity trick
        // Instead, use resolved colors approach with ZStack layering at draw time
        // For Canvas we'll use a workaround: draw both with appropriate opacity
        // Actually, let's use UIColor to extract components
        let ua = UIColor(a)
        let ub = UIColor(b)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        ua.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        ub.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let it = 1 - t
        return Color(red: Double(r1 * it + r2 * t),
                      green: Double(g1 * it + g2 * t),
                      blue: Double(b1 * it + b2 * t))
    }

    // Seeded deterministic random
    private func prng(_ seed: Int, _ index: Int) -> CGFloat {
        var s = UInt64(abs(seed &* 2654435761 &+ index &* 40503)) | 1
        s ^= s >> 13; s ^= s << 7; s ^= s >> 17
        return CGFloat(s % 10000) / 10000.0
    }

    // MARK: - DAY — blue sky, fluffy clouds, rolling hills, trees, pond, birds, fence, flowers

    private func drawDay(ctx: inout GraphicsContext, w: CGFloat, h: CGFloat) {
        skyGradient(&ctx, w: w, h: h)

        // Fluffy clouds (two of them, different sizes)
        let cloudW = Color.white.opacity(0.85)
        let cloudS = Color.white.opacity(0.65)
        // Big cloud
        let c1x = w * 0.55, c1y = h * 0.14
        for (dx, dy, cw, ch) in [
            (0.0, 2.0, 14.0, 4.0), (-5.0, 0.0, 10.0, 6.0), (5.0, 0.0, 10.0, 6.0),
            (-2.0, -2.0, 16.0, 4.0),
        ] as [(CGFloat, CGFloat, CGFloat, CGFloat)] {
            fill(&ctx, x: c1x + dx * px, y: c1y + dy * px, w: cw * px, h: ch * px, cloudW)
        }
        // Small cloud
        let c2x = w * 0.15, c2y = h * 0.08
        fill(&ctx, x: c2x, y: c2y, w: px * 8, h: px * 3, cloudS)
        fill(&ctx, x: c2x + px, y: c2y + px * 2, w: px * 6, h: px * 2, cloudS)

        // Birds in sky (V shapes)
        let bird = Color(red: 0.20, green: 0.18, blue: 0.15).opacity(0.5)
        for (bx, by) in [(w * 0.35, h * 0.12), (w * 0.40, h * 0.08), (w * 0.80, h * 0.20)] {
            pixel(&ctx, x: bx - px, y: by + px, bird)
            pixel(&ctx, x: bx, y: by, bird)
            pixel(&ctx, x: bx + px, y: by + px, bird)
        }

        // Rolling hills (three layers for depth)
        let hillFar = Color(red: 0.35, green: 0.58, blue: 0.28)
        let hillMid = Color(red: 0.28, green: 0.52, blue: 0.20)
        let hillNear = Color(red: 0.22, green: 0.45, blue: 0.16)
        drawSineHills(&ctx, w: w, baseY: h * 0.50, amplitude: h * 0.12, freq: 1.2, phase: 0, color: hillFar.opacity(0.5))
        drawSineHills(&ctx, w: w, baseY: h * 0.56, amplitude: h * 0.14, freq: 1.8, phase: 1.2, color: hillMid)
        drawSineHills(&ctx, w: w, baseY: h * 0.64, amplitude: h * 0.10, freq: 2.5, phase: 2.5, color: hillNear)

        // Big oak tree on left hill
        let trunk = Color(red: 0.38, green: 0.26, blue: 0.14)
        let trunkD = Color(red: 0.30, green: 0.20, blue: 0.10)
        let leaf1 = Color(red: 0.22, green: 0.50, blue: 0.18)
        let leaf2 = Color(red: 0.30, green: 0.60, blue: 0.24)
        let leaf3 = Color(red: 0.38, green: 0.65, blue: 0.28)
        let t1x = w * 0.25, t1base = h * 0.52
        // Trunk with bark
        for i in 0..<6 {
            fill(&ctx, x: t1x, y: t1base + CGFloat(i) * px, w: px * 2, h: px, trunk)
            if i % 2 == 0 { pixel(&ctx, x: t1x, y: t1base + CGFloat(i) * px, trunkD) }
        }
        // Round canopy (large)
        for dy in -5..<1 {
            let spread = dy < -3 ? 3 : (dy < -1 ? 4 : 3)
            for dx in -spread...spread {
                let c = (dx + dy) % 3 == 0 ? leaf3 : ((dx + dy) % 2 == 0 ? leaf2 : leaf1)
                pixel(&ctx, x: t1x + px * 0.5 + CGFloat(dx) * px, y: t1base + CGFloat(dy) * px, c)
            }
        }

        // Smaller tree on right
        let t2x = w * 0.72, t2base = h * 0.58
        for i in 0..<4 { pixel(&ctx, x: t2x, y: t2base + CGFloat(i) * px, trunk) }
        for dy in -3..<0 {
            let spread = dy == -2 ? 3 : 2
            for dx in -spread...spread {
                pixel(&ctx, x: t2x + CGFloat(dx) * px, y: t2base + CGFloat(dy) * px, dx < 0 ? leaf2 : leaf1)
            }
        }

        // Small pond
        let pondX = w * 0.52, pondY = h * 0.70
        let water = Color(red: 0.30, green: 0.55, blue: 0.75)
        let waterShine = Color(red: 0.50, green: 0.72, blue: 0.88)
        fill(&ctx, x: pondX, y: pondY, w: px * 6, h: px * 2, water.opacity(0.6))
        fill(&ctx, x: pondX + px, y: pondY - px, w: px * 4, h: px, water.opacity(0.5))
        pixel(&ctx, x: pondX + px * 2, y: pondY, waterShine.opacity(0.4)) // reflection

        // Fence posts
        let fence = Color(red: 0.50, green: 0.38, blue: 0.22)
        for i in 0..<4 {
            let fx = w * 0.38 + CGFloat(i) * px * 4
            pixel(&ctx, x: fx, y: h * 0.72, fence)
            pixel(&ctx, x: fx, y: h * 0.72 - px, fence)
            pixel(&ctx, x: fx, y: h * 0.72 - px * 2, fence)
        }
        // Fence rails
        fill(&ctx, x: w * 0.38, y: h * 0.72 - px, w: px * 13, h: px * 0.5, fence.opacity(0.7))

        // Ground
        fill(&ctx, x: 0, y: h * 0.78, w: w, h: px, Color(red: 0.30, green: 0.50, blue: 0.20))
        fill(&ctx, x: 0, y: h * 0.78 + px, w: w, h: h * 0.22, theme.previewGroundColor)

        // Flowers and grass tufts
        let grassD = Color(red: 0.28, green: 0.50, blue: 0.18)
        let grassL = Color(red: 0.40, green: 0.62, blue: 0.28)
        let flowerY = Color(red: 1.0, green: 0.85, blue: 0.20)
        let flowerR = Color(red: 0.90, green: 0.30, blue: 0.35)
        let flowerW = Color(red: 0.95, green: 0.95, blue: 0.90)
        for i in 0..<Int(w / (px * 4)) {
            let gx = CGFloat(i) * px * 4 + prng(42, i) * px * 2
            pixel(&ctx, x: gx, y: h * 0.78 - px, i % 2 == 0 ? grassD : grassL)
            if i % 3 == 0 {
                let fc = i % 6 == 0 ? flowerY : (i % 6 == 3 ? flowerR : flowerW)
                pixel(&ctx, x: gx, y: h * 0.78 - px * 2, fc)
            }
        }
    }

    // MARK: - SUNSET — warm sky, huge sun sinking, silhouette trees, birds, reflective lake

    private func drawSunset(ctx: inout GraphicsContext, w: CGFloat, h: CGFloat) {
        skyGradient(&ctx, w: w, h: h)

        // Warm haze band near horizon
        fill(&ctx, x: 0, y: h * 0.35, w: w, h: h * 0.10, Color(red: 1.0, green: 0.70, blue: 0.25).opacity(0.12))

        // Large sun — half sinking behind hills
        let sunX = w * 0.65
        let sunY = h * 0.48
        let sunR: CGFloat = 12
        let sunCore = Color(red: 1.0, green: 0.90, blue: 0.40)
        let sunEdge = Color(red: 1.0, green: 0.55, blue: 0.12)
        let sunGlow = Color(red: 1.0, green: 0.45, blue: 0.10)
        for dy in -Int(sunR)...Int(sunR) {
            for dx in -Int(sunR)...Int(sunR) {
                let dist = sqrt(CGFloat(dx * dx + dy * dy))
                if dist <= sunR {
                    let c = dist < sunR * 0.5 ? sunCore : (dist < sunR * 0.8 ? sunEdge : sunGlow.opacity(0.7))
                    pixel(&ctx, x: sunX + CGFloat(dx) * px, y: sunY + CGFloat(dy) * px, c)
                }
            }
        }
        // Sun glow halo
        for dy in -Int(sunR + 3)...Int(sunR + 3) {
            for dx in -Int(sunR + 3)...Int(sunR + 3) {
                let dist = sqrt(CGFloat(dx * dx + dy * dy))
                if dist > sunR && dist <= sunR + 2 {
                    pixel(&ctx, x: sunX + CGFloat(dx) * px, y: sunY + CGFloat(dy) * px, sunGlow.opacity(0.15))
                }
            }
        }

        // Hills — layered warm amber
        let hillFar = Color(red: 0.50, green: 0.32, blue: 0.18)
        let hillMid = Color(red: 0.40, green: 0.25, blue: 0.12)
        let hillNear = Color(red: 0.30, green: 0.18, blue: 0.08)
        drawSineHills(&ctx, w: w, baseY: h * 0.52, amplitude: h * 0.14, freq: 1.5, phase: 0.3, color: hillFar.opacity(0.7))
        drawSineHills(&ctx, w: w, baseY: h * 0.60, amplitude: h * 0.12, freq: 2.2, phase: 1.8, color: hillMid)
        drawSineHills(&ctx, w: w, baseY: h * 0.68, amplitude: h * 0.08, freq: 3.0, phase: 3.0, color: hillNear)

        // Tree silhouettes — multiple, varied
        let sil = Color(red: 0.12, green: 0.08, blue: 0.04)
        drawPixelTreeSilhouette(&ctx, x: w * 0.10, baseY: h * 0.56, color: sil)
        drawPixelTreeSilhouette(&ctx, x: w * 0.30, baseY: h * 0.52, color: sil)
        drawPixelTreeSilhouette(&ctx, x: w * 0.82, baseY: h * 0.54, color: sil)
        // Tall thin tree
        for i in 0..<8 { pixel(&ctx, x: w * 0.50, y: h * 0.55 + CGFloat(i) * px, sil) }
        pixel(&ctx, x: w * 0.50 - px, y: h * 0.55, sil)
        pixel(&ctx, x: w * 0.50 + px, y: h * 0.55, sil)

        // Birds returning home (V formations)
        let birdC = Color(red: 0.10, green: 0.06, blue: 0.03).opacity(0.6)
        for (bx, by) in [(w * 0.25, h * 0.18), (w * 0.30, h * 0.22), (w * 0.28, h * 0.15),
                          (w * 0.45, h * 0.10), (w * 0.48, h * 0.14)] {
            pixel(&ctx, x: bx - px, y: by + px * 0.5, birdC)
            pixel(&ctx, x: bx, y: by, birdC)
            pixel(&ctx, x: bx + px, y: by + px * 0.5, birdC)
        }

        // Reflective lake strip
        let lakeY = h * 0.72
        let lakeC = Color(red: 0.75, green: 0.45, blue: 0.18)
        fill(&ctx, x: w * 0.15, y: lakeY, w: w * 0.55, h: px * 3, lakeC.opacity(0.25))
        // Sun reflection in lake
        fill(&ctx, x: w * 0.58, y: lakeY, w: px * 4, h: px, sunGlow.opacity(0.3))
        fill(&ctx, x: w * 0.60, y: lakeY + px, w: px * 2, h: px, sunCore.opacity(0.2))

        // Ground
        fill(&ctx, x: 0, y: h * 0.78, w: w, h: h * 0.22, theme.previewGroundColor)
    }

    // MARK: - NIGHT — stars, crescent moon with glow, cottage with warm window, fireflies, owl, hills

    private func drawNight(ctx: inout GraphicsContext, w: CGFloat, h: CGFloat) {
        skyGradient(&ctx, w: w, h: h)

        // Dense star field
        for i in 0..<30 {
            let sx = prng(77, i * 2) * w
            let sy = prng(77, i * 2 + 1) * h * 0.55
            let brightness = 0.3 + prng(77, i * 3) * 0.7
            let size = prng(77, i * 4) > 0.85 ? px * 1.5 : px
            fill(&ctx, x: sx, y: sy, w: size, h: size, .white.opacity(brightness))
        }
        // Twinkle stars (cross shape)
        for i in 0..<3 {
            let tx = prng(77, i + 80) * w
            let ty = prng(77, i + 90) * h * 0.35
            let twinkle = Color.white.opacity(0.6)
            pixel(&ctx, x: tx, y: ty, .white.opacity(0.9))
            pixel(&ctx, x: tx - px, y: ty, twinkle)
            pixel(&ctx, x: tx + px, y: ty, twinkle)
            pixel(&ctx, x: tx, y: ty - px, twinkle)
            pixel(&ctx, x: tx, y: ty + px, twinkle)
        }

        // Crescent moon with glow halo
        let moonX = w * 0.78
        let moonY = h * 0.12
        let moonColor = Color(red: 0.92, green: 0.90, blue: 0.72)
        let moonGlow = Color(red: 0.70, green: 0.68, blue: 0.50)
        // Glow halo behind moon
        for dy in -6...6 {
            for dx in -6...6 {
                let dist = sqrt(CGFloat(dx * dx + dy * dy))
                if dist <= 6 && dist > 4 {
                    pixel(&ctx, x: moonX + CGFloat(dx) * px, y: moonY + CGFloat(dy) * px, moonGlow.opacity(0.08))
                }
            }
        }
        // Moon crescent
        for dy in -4...4 {
            for dx in -4...4 {
                let dist = sqrt(CGFloat(dx * dx + dy * dy))
                let cutDist = sqrt(CGFloat((dx - 2) * (dx - 2) + dy * dy))
                if dist <= 4 && cutDist > 3.5 {
                    pixel(&ctx, x: moonX + CGFloat(dx) * px, y: moonY + CGFloat(dy) * px, moonColor)
                }
            }
        }

        // Dark hills with subtle blue tint
        drawSineHills(&ctx, w: w, baseY: h * 0.55, amplitude: h * 0.12, freq: 1.8, phase: 0.5,
                      color: Color(red: 0.06, green: 0.10, blue: 0.14).opacity(0.7))
        drawSineHills(&ctx, w: w, baseY: h * 0.62, amplitude: h * 0.10, freq: 2.5, phase: 2.0,
                      color: Color(red: 0.04, green: 0.08, blue: 0.10))

        // Tree silhouettes on hills
        let treeSil = Color(red: 0.03, green: 0.06, blue: 0.04)
        drawPixelTreeSilhouette(&ctx, x: w * 0.15, baseY: h * 0.55, color: treeSil)
        drawPixelTreeSilhouette(&ctx, x: w * 0.42, baseY: h * 0.58, color: treeSil)

        // Cottage with warm lit window
        let cotX = w * 0.65
        let cotBase = h * 0.72
        let cotWall = Color(red: 0.12, green: 0.10, blue: 0.08)
        let cotRoof = Color(red: 0.08, green: 0.06, blue: 0.05)
        let warmLight = Color(red: 1.0, green: 0.82, blue: 0.35)
        // Walls
        fill(&ctx, x: cotX, y: cotBase - px * 4, w: px * 6, h: px * 4, cotWall)
        // Roof
        fill(&ctx, x: cotX - px, y: cotBase - px * 5, w: px * 8, h: px, cotRoof)
        fill(&ctx, x: cotX, y: cotBase - px * 6, w: px * 6, h: px, cotRoof)
        // Chimney
        fill(&ctx, x: cotX + px * 4, y: cotBase - px * 7, w: px, h: px * 2, cotRoof)
        // Warm glowing window
        pixel(&ctx, x: cotX + px, y: cotBase - px * 3, warmLight.opacity(0.8))
        pixel(&ctx, x: cotX + px * 2, y: cotBase - px * 3, warmLight.opacity(0.8))
        pixel(&ctx, x: cotX + px, y: cotBase - px * 2, warmLight.opacity(0.7))
        pixel(&ctx, x: cotX + px * 2, y: cotBase - px * 2, warmLight.opacity(0.7))
        // Window light spill on ground
        pixel(&ctx, x: cotX + px, y: cotBase, warmLight.opacity(0.15))
        pixel(&ctx, x: cotX + px * 2, y: cotBase, warmLight.opacity(0.15))

        // Owl silhouette on tree
        let owlX = w * 0.18, owlY = h * 0.48
        pixel(&ctx, x: owlX, y: owlY, treeSil)
        pixel(&ctx, x: owlX + px, y: owlY, treeSil)
        pixel(&ctx, x: owlX - px, y: owlY - px, treeSil) // ear tuft
        pixel(&ctx, x: owlX + px * 2, y: owlY - px, treeSil)
        // Eyes
        pixel(&ctx, x: owlX, y: owlY - px * 0.5, Color(red: 0.90, green: 0.80, blue: 0.20).opacity(0.7))
        pixel(&ctx, x: owlX + px, y: owlY - px * 0.5, Color(red: 0.90, green: 0.80, blue: 0.20).opacity(0.7))

        // Fireflies
        let firefly = Color(red: 0.80, green: 0.90, blue: 0.30)
        for i in 0..<6 {
            let fx = prng(77, i + 50) * w
            let fy = h * 0.55 + prng(77, i + 60) * h * 0.2
            pixel(&ctx, x: fx, y: fy, firefly.opacity(0.4 + prng(77, i + 70) * 0.4))
        }

        // Ground
        fill(&ctx, x: 0, y: h * 0.78, w: w, h: h * 0.22, theme.previewGroundColor)
    }

    // MARK: - NEON CITY — skyline, neon signs, flying car, rain, puddle reflections, neon glow

    private func drawNeonCity(ctx: inout GraphicsContext, w: CGFloat, h: CGFloat) {
        skyGradient(&ctx, w: w, h: h)

        // Stars through haze
        for i in 0..<6 {
            let sx = prng(11, i * 2) * w
            let sy = prng(11, i * 2 + 1) * h * 0.2
            pixel(&ctx, x: sx, y: sy, .white.opacity(0.2))
        }

        // Neon glow haze above city
        fill(&ctx, x: 0, y: h * 0.20, w: w, h: h * 0.10,
             Color(red: 0.35, green: 0.10, blue: 0.55).opacity(0.08))

        // City skyline — dense buildings with glowing windows
        let wallDark = Color(red: 0.08, green: 0.04, blue: 0.16)
        let wallMid = Color(red: 0.10, green: 0.06, blue: 0.20)
        let windowColors: [Color] = [
            Color(red: 1.0, green: 0.9, blue: 0.4),
            Color(red: 0.3, green: 0.9, blue: 1.0),
            Color(red: 1.0, green: 0.35, blue: 0.7),
            wallDark.opacity(0.7),
        ]
        let neonPink = Color(red: 1.0, green: 0.20, blue: 0.60)
        let neonCyan = Color(red: 0.20, green: 0.85, blue: 1.0)
        let neonPurple = Color(red: 0.65, green: 0.25, blue: 0.90)

        let buildings: [(x: CGFloat, bw: CGFloat, bh: CGFloat)] = [
            (0.0, 0.09, 0.38), (0.11, 0.07, 0.28), (0.20, 0.11, 0.55),
            (0.33, 0.06, 0.22), (0.41, 0.10, 0.48), (0.53, 0.08, 0.35),
            (0.63, 0.10, 0.52), (0.75, 0.08, 0.30), (0.85, 0.07, 0.42),
            (0.93, 0.07, 0.32),
        ]
        for (i, b) in buildings.enumerated() {
            let bx = b.x * w
            let bW = b.bw * w
            let bH = b.bh * h
            let bTop = h * 0.78 - bH
            // Building body
            fill(&ctx, x: bx, y: bTop, w: bW, h: bH, i % 2 == 0 ? wallDark : wallMid)
            // Edge highlight
            fill(&ctx, x: bx, y: bTop, w: px * 0.5, h: bH, wallMid.opacity(0.3))
            // Windows
            let winStep = px * 3
            var wy = bTop + px * 2
            var winIdx = 0
            while wy < h * 0.76 - winStep {
                var wx = bx + px
                while wx < bx + bW - px * 2 {
                    let c = windowColors[(winIdx + i) % windowColors.count]
                    pixel(&ctx, x: wx, y: wy, c)
                    pixel(&ctx, x: wx + px, y: wy, c)
                    wx += winStep
                    winIdx += 1
                }
                wy += winStep
            }
            // Antenna on tall buildings
            if b.bh > 0.4 {
                let aX = bx + bW / 2
                fill(&ctx, x: aX, y: bTop - px * 4, w: px, h: px * 4, wallDark)
                pixel(&ctx, x: aX, y: bTop - px * 5, Color(red: 1.0, green: 0.2, blue: 0.4).opacity(0.8))
            }
            // Neon sign on some buildings
            if i % 3 == 0 {
                let signC = i % 6 == 0 ? neonPink : neonCyan
                fill(&ctx, x: bx + px, y: bTop + px * 4, w: bW - px * 2, h: px * 2, signC.opacity(0.5))
                // Sign glow
                fill(&ctx, x: bx, y: bTop + px * 3, w: bW, h: px * 4, signC.opacity(0.06))
            }
        }

        // Flying car trail
        let carX = w * 0.38, carY = h * 0.22
        let carBody = Color(red: 0.15, green: 0.12, blue: 0.22)
        fill(&ctx, x: carX, y: carY, w: px * 3, h: px, carBody.opacity(0.6))
        // Tail lights
        pixel(&ctx, x: carX + px * 3, y: carY, neonPink.opacity(0.6))
        // Light trail
        fill(&ctx, x: carX + px * 4, y: carY, w: px * 6, h: px * 0.5, neonPink.opacity(0.15))

        // Rain streaks
        for i in 0..<12 {
            let rx = prng(11, i + 50) * w
            let ry = prng(11, i + 60) * h * 0.75
            fill(&ctx, x: rx, y: ry, w: px * 0.5, h: px * 2, Color(red: 0.4, green: 0.5, blue: 0.7).opacity(0.12))
        }

        // Road/ground with neon reflections
        let roadY = h * 0.78
        fill(&ctx, x: 0, y: roadY, w: w, h: h * 0.22, Color(red: 0.06, green: 0.04, blue: 0.10))
        // Road dashes
        for i in 0..<Int(w / (px * 8)) {
            fill(&ctx, x: CGFloat(i) * px * 8, y: roadY + h * 0.10, w: px * 4, h: px,
                 Color(red: 0.3, green: 0.3, blue: 0.4))
        }
        // Wet puddle neon reflections
        let reflections: [(x: CGFloat, c: Color)] = [
            (0.08, neonPink), (0.28, neonCyan), (0.50, neonPurple),
            (0.68, neonPink), (0.85, neonCyan),
        ]
        for ref in reflections {
            let rx = ref.x * w
            fill(&ctx, x: rx, y: roadY + px, w: px * 4, h: px, ref.c.opacity(0.18))
            fill(&ctx, x: rx + px, y: roadY + px * 2, w: px * 2, h: px, ref.c.opacity(0.08))
        }
    }

    // MARK: - PIXEL TOKYO — dense buildings, torii gate, cherry blossom tree, lanterns, neon signs, vending machine

    private func drawPixelTokyo(ctx: inout GraphicsContext, w: CGFloat, h: CGFloat) {
        skyGradient(&ctx, w: w, h: h)

        // Stars dimly visible
        for i in 0..<5 {
            let sx = prng(33, i * 2) * w
            let sy = prng(33, i * 2 + 1) * h * 0.18
            pixel(&ctx, x: sx, y: sy, .white.opacity(0.2))
        }

        // Moon haze
        let moonX = w * 0.85, moonY = h * 0.10
        for dy in -2...2 {
            for dx in -2...2 {
                let dist = sqrt(CGFloat(dx * dx + dy * dy))
                if dist <= 2 { pixel(&ctx, x: moonX + CGFloat(dx) * px, y: moonY + CGFloat(dy) * px,
                                     Color(red: 0.85, green: 0.82, blue: 0.70).opacity(dist < 1 ? 0.5 : 0.2)) }
            }
        }

        // Buildings with Japanese elements
        let wall = Color(red: 0.15, green: 0.10, blue: 0.25)
        let wallLit = Color(red: 0.22, green: 0.14, blue: 0.32)
        let neonPink = Color(red: 1.0, green: 0.3, blue: 0.5)
        let neonCyan = Color(red: 0.3, green: 0.9, blue: 1.0)
        let signRed = Color(red: 0.9, green: 0.15, blue: 0.2)
        let lanternGold = Color(red: 1.0, green: 0.8, blue: 0.3)
        let lanternRed = Color(red: 0.90, green: 0.15, blue: 0.10)

        let buildings: [(x: CGFloat, bw: CGFloat, bh: CGFloat)] = [
            (0.0, 0.10, 0.32), (0.12, 0.08, 0.48), (0.22, 0.12, 0.40),
            (0.36, 0.09, 0.55), (0.47, 0.07, 0.28), (0.56, 0.11, 0.45),
            (0.69, 0.09, 0.36), (0.80, 0.10, 0.52), (0.92, 0.08, 0.38),
        ]
        for (i, b) in buildings.enumerated() {
            let bx = b.x * w
            let bW = b.bw * w
            let bH = b.bh * h
            let bTop = h * 0.78 - bH
            fill(&ctx, x: bx, y: bTop, w: bW, h: bH, i % 2 == 0 ? wall : wallLit)
            // Pagoda-style roof on some
            if i % 3 == 1 {
                fill(&ctx, x: bx - px, y: bTop - px, w: bW + px * 2, h: px, wall)
                fill(&ctx, x: bx - px * 2, y: bTop, w: px, h: px, wall)
                fill(&ctx, x: bx + bW + px, y: bTop, w: px, h: px, wall)
            }
            // Neon signs — vertical kanji-style blocks
            if i % 2 == 0 {
                let signC = i % 4 == 0 ? signRed : neonPink
                let signW = min(bW * 0.5, px * 3)
                fill(&ctx, x: bx + px, y: bTop + px * 2, w: signW, h: px * 4, signC.opacity(0.6))
                // Sign glow
                fill(&ctx, x: bx, y: bTop + px, w: signW + px * 2, h: px * 6, signC.opacity(0.04))
            }
            // Horizontal neon sign on others
            if i % 3 == 2 {
                fill(&ctx, x: bx + px, y: bTop + px * 3, w: bW - px * 2, h: px * 2, neonCyan.opacity(0.5))
            }
            // Windows — dense grid
            var wy = bTop + px * 7
            var winIdx = 0
            while wy < h * 0.76 - px * 3 {
                var wx = bx + px
                while wx < bx + bW - px * 2 {
                    let c: Color = (winIdx + i) % 3 == 0 ? neonCyan.opacity(0.5) : lanternGold.opacity(0.4)
                    pixel(&ctx, x: wx, y: wy, c)
                    wx += px * 3
                    winIdx += 1
                }
                wy += px * 3
            }
        }

        // Torii gate (red) in foreground
        let toriiX = w * 0.06, toriiBase = h * 0.78
        let torii = Color(red: 0.85, green: 0.12, blue: 0.08)
        let toriiDk = Color(red: 0.65, green: 0.08, blue: 0.06)
        // Pillars
        fill(&ctx, x: toriiX, y: toriiBase - px * 10, w: px, h: px * 10, torii.opacity(0.7))
        fill(&ctx, x: toriiX + px * 6, y: toriiBase - px * 10, w: px, h: px * 10, torii.opacity(0.7))
        // Top beam (kasagi) — wider
        fill(&ctx, x: toriiX - px, y: toriiBase - px * 10, w: px * 9, h: px, toriiDk.opacity(0.7))
        // Secondary beam (nuki)
        fill(&ctx, x: toriiX, y: toriiBase - px * 8, w: px * 7, h: px, torii.opacity(0.6))

        // Cherry blossom tree
        let blossomX = w * 0.52, blossomBase = h * 0.76
        let branchC = Color(red: 0.35, green: 0.22, blue: 0.15)
        // Trunk
        for i in 0..<5 { pixel(&ctx, x: blossomX, y: blossomBase - CGFloat(i) * px, branchC.opacity(0.6)) }
        // Branches
        pixel(&ctx, x: blossomX - px, y: blossomBase - 5 * px, branchC.opacity(0.5))
        pixel(&ctx, x: blossomX + px, y: blossomBase - 5 * px, branchC.opacity(0.5))
        pixel(&ctx, x: blossomX - px * 2, y: blossomBase - 4 * px, branchC.opacity(0.4))
        pixel(&ctx, x: blossomX + px * 2, y: blossomBase - 4 * px, branchC.opacity(0.4))
        // Blossom clusters (pink cloud)
        let petal = Color(red: 1.0, green: 0.70, blue: 0.80)
        let petalL = Color(red: 1.0, green: 0.85, blue: 0.90)
        for dx in -3...3 {
            for dy in -2...0 {
                if abs(dx) + abs(dy) < 4 {
                    let c = (dx + dy) % 2 == 0 ? petal : petalL
                    pixel(&ctx, x: blossomX + CGFloat(dx) * px, y: blossomBase - 5 * px + CGFloat(dy) * px,
                          c.opacity(0.5))
                }
            }
        }

        // Falling petals
        for i in 0..<10 {
            let px2 = prng(55, i * 2) * w
            let py = prng(55, i * 2 + 1) * h * 0.75
            pixel(&ctx, x: px2, y: py, (i % 2 == 0 ? petal : petalL).opacity(0.4))
        }

        // Lanterns hanging between buildings
        for (lx, ly) in [(w * 0.18, h * 0.38), (w * 0.42, h * 0.32), (w * 0.72, h * 0.40)] {
            pixel(&ctx, x: lx, y: ly, lanternRed.opacity(0.5))
            pixel(&ctx, x: lx, y: ly + px, lanternRed.opacity(0.4))
            // Warm glow
            pixel(&ctx, x: lx - px, y: ly + px * 0.5, lanternGold.opacity(0.08))
            pixel(&ctx, x: lx + px, y: ly + px * 0.5, lanternGold.opacity(0.08))
        }

        // Vending machine
        let vmX = w * 0.62, vmY = h * 0.72
        fill(&ctx, x: vmX, y: vmY, w: px * 3, h: px * 5, Color(red: 0.10, green: 0.10, blue: 0.20).opacity(0.6))
        // Lit display
        fill(&ctx, x: vmX + px * 0.5, y: vmY + px, w: px * 2, h: px * 2, neonCyan.opacity(0.3))
        // Glow on ground
        fill(&ctx, x: vmX, y: vmY + px * 5, w: px * 3, h: px, neonCyan.opacity(0.05))

        // Ground — wet sidewalk
        fill(&ctx, x: 0, y: h * 0.78, w: w, h: h * 0.22, theme.previewGroundColor)
        // Neon reflections on wet ground
        for i in 0..<6 {
            let rx = prng(33, i + 40) * w
            let rc: Color = i % 2 == 0 ? neonPink : neonCyan
            fill(&ctx, x: rx, y: h * 0.79, w: px * 2, h: px, rc.opacity(0.1))
        }
    }

    // MARK: - UNDERWATER — light rays, coral reef, kelp forest, jellyfish, sea turtle, treasure, fish school

    private func drawUnderwater(ctx: inout GraphicsContext, w: CGFloat, h: CGFloat) {
        skyGradient(&ctx, w: w, h: h)

        // Light rays from surface — wider, more atmospheric
        let rayColor = Color(red: 0.3, green: 0.7, blue: 0.8)
        for i in 0..<4 {
            let rx = w * (0.15 + CGFloat(i) * 0.22)
            let rayW = px * (2 + CGFloat(i % 2))
            fill(&ctx, x: rx, y: 0, w: rayW, h: h * 0.65, rayColor.opacity(0.06))
            fill(&ctx, x: rx + px, y: 0, w: rayW - px, h: h * 0.55, rayColor.opacity(0.04))
        }

        // Coral reef mounds — varied shapes
        let coralPink = Color(red: 0.88, green: 0.35, blue: 0.55)
        let coralOrange = Color(red: 0.92, green: 0.55, blue: 0.25)
        let coralPurple = Color(red: 0.55, green: 0.25, blue: 0.70)
        let coralYellow = Color(red: 0.90, green: 0.75, blue: 0.20)

        let corals: [(x: CGFloat, cw: CGFloat, ch: CGFloat, c: Color)] = [
            (0.03, 0.10, 0.22, coralPink), (0.18, 0.07, 0.18, coralOrange),
            (0.32, 0.08, 0.25, coralPurple), (0.48, 0.12, 0.30, coralPink),
            (0.66, 0.06, 0.15, coralYellow), (0.78, 0.10, 0.24, coralOrange),
            (0.92, 0.07, 0.16, coralPurple),
        ]
        for coral in corals {
            let cx = coral.x * w
            let cW = coral.cw * w
            let cH = coral.ch * h
            let cTop = h * 0.78 - cH
            for dy in 0..<Int(cH / px) {
                let ratio = CGFloat(dy) / (cH / px)
                let rowW = cW * (1.0 - abs(ratio - 0.5) * 1.2)
                let rowX = cx + (cW - rowW) / 2
                fill(&ctx, x: rowX, y: cTop + CGFloat(dy) * px, w: max(rowW, px), h: px, coral.c.opacity(0.7))
            }
            // Branch corals on top
            if coral.ch > 0.2 {
                pixel(&ctx, x: cx + cW * 0.3, y: cTop - px, coral.c.opacity(0.5))
                pixel(&ctx, x: cx + cW * 0.7, y: cTop - px * 2, coral.c.opacity(0.4))
            }
        }

        // Kelp forest — tall, swaying
        let kelpDark = Color(red: 0.12, green: 0.42, blue: 0.22)
        let kelpLight = Color(red: 0.20, green: 0.55, blue: 0.30)
        for (kx, kH) in [(w * 0.12, 12), (w * 0.28, 10), (w * 0.55, 14), (w * 0.72, 11), (w * 0.88, 9)] {
            for ky in 0..<kH {
                let sway = sin(CGFloat(ky) * 0.7 + kx * 0.01) * px * 2.5
                let c = ky % 2 == 0 ? kelpDark : kelpLight
                pixel(&ctx, x: kx + sway, y: h * 0.78 - CGFloat(ky) * px * 1.5, c.opacity(0.55))
                // Wider fronds on some
                if ky > 6 && ky % 3 == 0 {
                    pixel(&ctx, x: kx + sway + px, y: h * 0.78 - CGFloat(ky) * px * 1.5, kelpLight.opacity(0.3))
                }
            }
        }

        // Jellyfish
        let jellyBody = Color(red: 0.72, green: 0.45, blue: 0.85)
        let jellyGlow = Color(red: 0.82, green: 0.55, blue: 0.95)
        let jx = w * 0.20, jy = h * 0.22
        // Bell
        fill(&ctx, x: jx - px, y: jy, w: px * 3, h: px * 2, jellyGlow.opacity(0.5))
        fill(&ctx, x: jx - px * 2, y: jy + px, w: px * 5, h: px, jellyBody.opacity(0.4))
        // Tentacles
        for i in 0..<3 {
            let tx = jx - px + CGFloat(i) * px
            for t in 0..<4 {
                let sway = sin(CGFloat(t) * 0.8 + CGFloat(i)) * px * 0.5
                pixel(&ctx, x: tx + sway, y: jy + px * 3 + CGFloat(t) * px, jellyBody.opacity(0.25))
            }
        }

        // Sea turtle
        let turtleShell = Color(red: 0.30, green: 0.52, blue: 0.25)
        let turtleHead = Color(red: 0.35, green: 0.48, blue: 0.30)
        let tx2 = w * 0.42, ty2 = h * 0.35
        // Shell
        fill(&ctx, x: tx2, y: ty2, w: px * 4, h: px * 2, turtleShell.opacity(0.6))
        fill(&ctx, x: tx2 + px, y: ty2 - px, w: px * 2, h: px, turtleShell.opacity(0.5))
        // Head
        pixel(&ctx, x: tx2 - px, y: ty2 + px * 0.5, turtleHead.opacity(0.6))
        // Flippers
        pixel(&ctx, x: tx2 + px, y: ty2 + px * 2, turtleHead.opacity(0.4))
        pixel(&ctx, x: tx2 + px * 3, y: ty2 + px * 2, turtleHead.opacity(0.4))
        // Eye
        pixel(&ctx, x: tx2 - px, y: ty2, Color(red: 0.15, green: 0.15, blue: 0.20).opacity(0.5))

        // School of fish (small)
        let fishOrange = Color(red: 1.0, green: 0.65, blue: 0.20)
        let fishBlue = Color(red: 0.30, green: 0.60, blue: 0.90)
        for (fx, fy, fc) in [(w * 0.68, h * 0.30, fishOrange), (w * 0.72, h * 0.28, fishOrange),
                              (w * 0.70, h * 0.33, fishOrange), (w * 0.75, h * 0.31, fishBlue)] {
            pixel(&ctx, x: fx, y: fy, fc.opacity(0.6))
            pixel(&ctx, x: fx + px, y: fy, fc.opacity(0.6))
            pixel(&ctx, x: fx + px * 2, y: fy - px * 0.5, fc.opacity(0.4)) // tail
            pixel(&ctx, x: fx + px * 2, y: fy + px * 0.5, fc.opacity(0.4))
        }

        // Treasure chest half-buried
        let chest = Color(red: 0.50, green: 0.32, blue: 0.15)
        let gold = Color(red: 1.0, green: 0.82, blue: 0.22)
        let chestX = w * 0.82, chestY = h * 0.74
        fill(&ctx, x: chestX, y: chestY, w: px * 4, h: px * 2, chest.opacity(0.6))
        fill(&ctx, x: chestX, y: chestY - px, w: px * 4, h: px, chest.opacity(0.5))
        // Gold glint
        pixel(&ctx, x: chestX + px, y: chestY - px, gold.opacity(0.5))
        pixel(&ctx, x: chestX + px * 2, y: chestY - px, gold.opacity(0.4))

        // Bubbles — more, varied
        let bubble = Color(red: 0.5, green: 0.8, blue: 0.9)
        for i in 0..<10 {
            let bx = prng(88, i * 2) * w
            let by = prng(88, i * 2 + 1) * h * 0.7
            let bs = prng(88, i * 3) > 0.6 ? px * 2 : px
            fill(&ctx, x: bx, y: by, w: bs, h: bs, bubble.opacity(0.25 + prng(88, i * 4) * 0.25))
        }

        // Sandy floor with ripples
        fill(&ctx, x: 0, y: h * 0.78, w: w, h: px, Color(red: 0.65, green: 0.58, blue: 0.40))
        fill(&ctx, x: 0, y: h * 0.78 + px, w: w, h: h * 0.22, theme.previewGroundColor)
        // Sand ripples
        for i in 0..<5 {
            let rx = prng(88, i + 50) * w
            fill(&ctx, x: rx, y: h * 0.80, w: px * 5, h: px * 0.5, Color(red: 0.60, green: 0.55, blue: 0.38).opacity(0.3))
        }
    }

    // MARK: - VOLCANO — erupting crater, lava rivers, mountain walls, smoke, embers

    private func drawVolcano(ctx: inout GraphicsContext, w: CGFloat, h: CGFloat) {
        skyGradient(&ctx, w: w, h: h)

        // Smoke clouds billowing from crater
        let smoke = Color(red: 0.25, green: 0.15, blue: 0.08)
        for i in 0..<4 {
            let sx = w * 0.42 + prng(66, i + 40) * w * 0.16
            let sy = h * 0.05 + CGFloat(i) * px * 3
            let sw = px * (4 + prng(66, i + 50) * 5)
            fill(&ctx, x: sx, y: sy, w: sw, h: px * 2, smoke.opacity(0.25 - CGFloat(i) * 0.04))
        }

        let rockDark = Color(red: 0.15, green: 0.08, blue: 0.05)
        let rockMid = Color(red: 0.25, green: 0.13, blue: 0.07)
        let rockLight = Color(red: 0.35, green: 0.20, blue: 0.10)
        let lavaGlow = Color(red: 1.0, green: 0.45, blue: 0.10)
        let lavaHot = Color(red: 1.0, green: 0.70, blue: 0.20)
        let lavaWhite = Color(red: 1.0, green: 0.90, blue: 0.50)

        // Mountain wall left side — craggy slope
        for x in stride(from: CGFloat(0), to: w * 0.15, by: px) {
            let wallH = h * 0.7 * (1.0 - x / (w * 0.15))
            fill(&ctx, x: x, y: h - wallH, w: px, h: wallH, rockDark)
            if wallH > h * 0.3 {
                fill(&ctx, x: x, y: h - wallH, w: px, h: px, rockLight.opacity(0.4))
            }
        }

        // Mountain wall right side
        for x in stride(from: w * 0.85, to: w, by: px) {
            let wallH = h * 0.6 * ((x - w * 0.85) / (w * 0.15))
            fill(&ctx, x: x, y: h - wallH, w: px, h: wallH, rockDark)
        }

        // Main volcano — massive, center
        let volcCenter = w * 0.50
        let volcW = w * 0.55
        let volcH = h * 0.50
        let volcTop = h * 0.22
        for dy in 0..<Int(volcH / px) {
            let ratio = CGFloat(dy) / (volcH / px)
            let rowW = volcW * ratio
            let rowX = volcCenter - rowW / 2
            // Rock with subtle variation
            let c = ratio < 0.08 ? rockLight : (ratio < 0.4 ? rockMid : rockDark)
            fill(&ctx, x: rowX, y: volcTop + CGFloat(dy) * px, w: rowW, h: px, c)
        }

        // Erupting crater glow — bright hot center
        fill(&ctx, x: volcCenter - px * 4, y: volcTop - px * 2, w: px * 8, h: px * 3, lavaHot)
        fill(&ctx, x: volcCenter - px * 2, y: volcTop - px * 3, w: px * 4, h: px, lavaWhite)
        // Eruption particles shooting up
        for i in 0..<5 {
            let ex = volcCenter - px * 2 + prng(66, i + 60) * px * 4
            let ey = volcTop - px * 4 - prng(66, i + 70) * h * 0.12
            pixel(&ctx, x: ex, y: ey, i % 2 == 0 ? lavaHot : lavaGlow)
        }

        // Lava river flowing down left side
        for i in 0..<10 {
            let lx = volcCenter - px * 3 - CGFloat(i) * px * 1.5
            let ly = volcTop + CGFloat(i) * px * 2.5
            let lw = px * (2 - CGFloat(i) * 0.1)
            fill(&ctx, x: lx, y: ly, w: max(lw, px), h: px * 2, lavaGlow.opacity(0.8 - CGFloat(i) * 0.05))
        }
        // Lava river flowing down right
        for i in 0..<7 {
            let lx = volcCenter + px * 2 + CGFloat(i) * px * 1.8
            let ly = volcTop + px * 3 + CGFloat(i) * px * 2.5
            fill(&ctx, x: lx, y: ly, w: px * 2, h: px * 2, lavaHot.opacity(0.7 - CGFloat(i) * 0.06))
        }

        // Lava bubbling pool at base
        let poolY = h * 0.72
        fill(&ctx, x: w * 0.30, y: poolY, w: w * 0.40, h: px * 3, lavaGlow.opacity(0.6))
        fill(&ctx, x: w * 0.35, y: poolY + px, w: w * 0.30, h: px, lavaHot.opacity(0.5))
        // Bubbles
        for i in 0..<3 {
            let bx = w * 0.35 + prng(66, i + 80) * w * 0.25
            pixel(&ctx, x: bx, y: poolY - px, lavaWhite.opacity(0.5))
        }

        // Floating embers — lots
        let emberColor = Color(red: 1.0, green: 0.55, blue: 0.15)
        let emberBright = Color(red: 1.0, green: 0.80, blue: 0.30)
        for i in 0..<15 {
            let ex = prng(66, i * 2) * w
            let ey = prng(66, i * 2 + 1) * h * 0.65
            let c = i % 3 == 0 ? emberBright : emberColor
            pixel(&ctx, x: ex, y: ey, c.opacity(0.25 + prng(66, i * 3) * 0.55))
        }

        // Ground — dark rock with lava cracks
        fill(&ctx, x: 0, y: h * 0.78, w: w, h: h * 0.22, theme.previewGroundColor)
        for i in 0..<4 {
            let lx = w * (0.10 + CGFloat(i) * 0.22)
            fill(&ctx, x: lx, y: h * 0.80, w: px * 6, h: px, lavaGlow.opacity(0.45))
            fill(&ctx, x: lx + px, y: h * 0.80 + px, w: px * 3, h: px, lavaHot.opacity(0.25))
        }
    }

    // MARK: - ARCTIC — aurora borealis, glaciers, ice shelf, penguins, igloo, snowfall, polar bear

    private func drawArctic(ctx: inout GraphicsContext, w: CGFloat, h: CGFloat) {
        skyGradient(&ctx, w: w, h: h)

        // Aurora borealis — green/purple shimmer bands
        let auroraGreen = Color(red: 0.20, green: 0.85, blue: 0.45)
        let auroraCyan = Color(red: 0.15, green: 0.70, blue: 0.75)
        let auroraPurple = Color(red: 0.50, green: 0.25, blue: 0.70)
        for x in stride(from: CGFloat(0), to: w, by: px) {
            let wave1 = (sin(x / w * .pi * 3 + 0.5) * 0.5 + 0.5) * h * 0.08 + h * 0.06
            let wave2 = (sin(x / w * .pi * 4.5 + 2.0) * 0.5 + 0.5) * h * 0.06 + h * 0.12
            fill(&ctx, x: x, y: wave1, w: px, h: px * 2, auroraGreen.opacity(0.12))
            fill(&ctx, x: x, y: wave1 + px * 2, w: px, h: px, auroraCyan.opacity(0.08))
            fill(&ctx, x: x, y: wave2, w: px, h: px * 2, auroraPurple.opacity(0.08))
        }

        // Stars through aurora
        for i in 0..<10 {
            let sx = prng(99, i * 2) * w
            let sy = prng(99, i * 2 + 1) * h * 0.3
            pixel(&ctx, x: sx, y: sy, .white.opacity(0.3 + prng(99, i * 3) * 0.4))
        }

        // Massive glacier peaks — icy blue-white
        let rock = Color(red: 0.42, green: 0.50, blue: 0.62)
        let snow = Color(red: 0.92, green: 0.95, blue: 1.0)
        let snowMid = Color(red: 0.82, green: 0.88, blue: 0.95)
        let ice = Color(red: 0.65, green: 0.82, blue: 0.92)

        let peaks: [(x: CGFloat, halfW: CGFloat, peakH: CGFloat)] = [
            (0.12, 0.10, 0.32), (0.30, 0.15, 0.48), (0.52, 0.12, 0.40), (0.78, 0.16, 0.44),
        ]
        for peak in peaks {
            let cx = peak.x * w
            let pW = peak.halfW * w
            let pH = peak.peakH * h
            let pTop = h * 0.76 - pH
            for dy in 0..<Int(pH / px) {
                let ratio = CGFloat(dy) / (pH / px)
                let rowW = pW * 2 * ratio
                let c = ratio < 0.2 ? snow : (ratio < 0.35 ? snowMid : (ratio < 0.6 ? ice : rock))
                fill(&ctx, x: cx - rowW / 2, y: pTop + CGFloat(dy) * px, w: rowW, h: px, c)
            }
        }

        // Ice shelf edge
        let shelfY = h * 0.73
        fill(&ctx, x: 0, y: shelfY, w: w, h: px * 2, ice.opacity(0.6))

        // Igloo — bigger, more detailed
        let igX = w * 0.18, igY = h * 0.72
        let igloo = Color(red: 0.88, green: 0.92, blue: 0.96)
        let igShadow = Color(red: 0.68, green: 0.76, blue: 0.84)
        // Dome blocks
        for dy in 0..<5 {
            let ratio = CGFloat(dy) / 5.0
            let dw = px * (5.0 - ratio * 4.0)
            let dx = igX + (px * 5 - dw) / 2
            let c = dy < 3 ? igloo : igShadow
            fill(&ctx, x: dx, y: igY - CGFloat(dy) * px, w: dw, h: px, c)
            // Block lines
            if dy > 0 && dy < 4 {
                fill(&ctx, x: dx, y: igY - CGFloat(dy) * px, w: dw, h: px * 0.3, igShadow.opacity(0.3))
            }
        }
        // Door tunnel
        fill(&ctx, x: igX - px * 2, y: igY - px, w: px * 2, h: px * 2, igShadow)
        pixel(&ctx, x: igX - px * 2, y: igY - px, igloo)

        // Penguins — a small group
        let pengBody = Color(red: 0.08, green: 0.08, blue: 0.10)
        let pengBelly = Color(red: 0.92, green: 0.92, blue: 0.95)
        let pengBeak = Color(red: 0.95, green: 0.70, blue: 0.15)
        for (px2, py) in [(w * 0.55, h * 0.72), (w * 0.58, h * 0.71), (w * 0.61, h * 0.72)] {
            // Body
            pixel(&ctx, x: px2, y: py, pengBody)
            pixel(&ctx, x: px2 + px, y: py, pengBody)
            pixel(&ctx, x: px2, y: py - px, pengBody)
            pixel(&ctx, x: px2 + px, y: py - px, pengBelly)
            // Head
            pixel(&ctx, x: px2, y: py - px * 2, pengBody)
            pixel(&ctx, x: px2 + px, y: py - px * 2, pengBody)
            // Eye
            pixel(&ctx, x: px2 + px, y: py - px * 2, pengBelly.opacity(0.5))
            // Beak
            pixel(&ctx, x: px2 + px * 1.5, y: py - px * 1.5, pengBeak.opacity(0.6))
        }

        // Polar bear in distance
        let bearC = Color(red: 0.90, green: 0.92, blue: 0.88)
        let bx = w * 0.85, by = h * 0.70
        fill(&ctx, x: bx, y: by, w: px * 4, h: px * 2, bearC.opacity(0.5))
        fill(&ctx, x: bx + px, y: by - px, w: px * 2, h: px, bearC.opacity(0.5))
        pixel(&ctx, x: bx + px * 3, y: by - px, bearC.opacity(0.4)) // head

        // Snowfall
        for i in 0..<12 {
            let sx = prng(99, i + 30) * w
            let sy = prng(99, i + 40) * h * 0.7
            pixel(&ctx, x: sx, y: sy, .white.opacity(0.35 + prng(99, i + 50) * 0.3))
        }

        // Snow ground
        fill(&ctx, x: 0, y: h * 0.76, w: w, h: h * 0.24, theme.previewGroundColor)
        // Snow sparkles
        for i in 0..<10 {
            let sx = prng(99, i) * w
            pixel(&ctx, x: sx, y: h * 0.78 + prng(99, i + 20) * h * 0.10, .white.opacity(0.6))
        }
        // Ice crystal accents on ground
        let crystal = Color(red: 0.70, green: 0.88, blue: 0.98)
        pixel(&ctx, x: w * 0.40, y: h * 0.77, crystal.opacity(0.3))
        pixel(&ctx, x: w * 0.42, y: h * 0.76, crystal.opacity(0.2))
        pixel(&ctx, x: w * 0.70, y: h * 0.77, crystal.opacity(0.25))
    }

    // MARK: - WESTERN — dusty sky, dramatic mesas, saloon, windmill, saguaro, vulture, tumbleweed, wagon wheel

    private func drawWestern(ctx: inout GraphicsContext, w: CGFloat, h: CGFloat) {
        skyGradient(&ctx, w: w, h: h)

        // Heat shimmer / dust haze
        fill(&ctx, x: 0, y: h * 0.40, w: w, h: h * 0.08, Color(red: 0.80, green: 0.60, blue: 0.35).opacity(0.06))

        // Distant mesas — dramatic layers
        let mesa = Color(red: 0.50, green: 0.32, blue: 0.18)
        let mesaDark = Color(red: 0.38, green: 0.22, blue: 0.12)
        let mesaLight = Color(red: 0.60, green: 0.40, blue: 0.22)

        // Far mesa (left) — wide, flat-topped
        fill(&ctx, x: w * 0.02, y: h * 0.42, w: px * 16, h: h * 0.34, mesa.opacity(0.6))
        fill(&ctx, x: w * 0.02, y: h * 0.42, w: px * 16, h: px, mesaLight.opacity(0.5))
        // Vertical striation
        for i in stride(from: 0, to: 16, by: 3) {
            fill(&ctx, x: w * 0.02 + CGFloat(i) * px, y: h * 0.44, w: px, h: h * 0.28, mesaDark.opacity(0.15))
        }

        // Tall narrow butte (center-left)
        fill(&ctx, x: w * 0.32, y: h * 0.28, w: px * 10, h: h * 0.48, mesaDark)
        fill(&ctx, x: w * 0.32 - px, y: h * 0.28, w: px * 12, h: px * 2, mesa)
        // Erosion layers
        fill(&ctx, x: w * 0.32, y: h * 0.38, w: px * 10, h: px, mesaLight.opacity(0.3))
        fill(&ctx, x: w * 0.32, y: h * 0.50, w: px * 10, h: px, mesaLight.opacity(0.2))

        // Wide mesa (right)
        fill(&ctx, x: w * 0.60, y: h * 0.46, w: px * 22, h: h * 0.30, mesa)
        fill(&ctx, x: w * 0.60, y: h * 0.46, w: px * 22, h: px, mesaLight)

        // Saguaro cactus — tall
        let cactus = Color(red: 0.25, green: 0.42, blue: 0.20)
        let cactusL = Color(red: 0.35, green: 0.52, blue: 0.28)
        let cacX = w * 0.50, cacBase = h * 0.76
        for i in 0..<10 { pixel(&ctx, x: cacX, y: cacBase - CGFloat(i) * px, cactus) }
        pixel(&ctx, x: cacX, y: cacBase - 10 * px, cactusL)
        // Left arm
        for i in 0..<3 { pixel(&ctx, x: cacX - px, y: cacBase - CGFloat(5 + i) * px, cactusL) }
        pixel(&ctx, x: cacX - px * 2, y: cacBase - 7 * px, cactus)
        // Right arm
        for i in 0..<2 { pixel(&ctx, x: cacX + px, y: cacBase - CGFloat(3 + i) * px, cactus) }
        pixel(&ctx, x: cacX + px * 2, y: cacBase - 4 * px, cactusL)

        // Smaller barrel cactus
        let bc = w * 0.22, bcY = h * 0.74
        fill(&ctx, x: bc, y: bcY, w: px * 2, h: px * 3, cactus)
        pixel(&ctx, x: bc, y: bcY - px, cactusL)
        pixel(&ctx, x: bc + px, y: bcY - px, cactusL)

        // Saloon — larger, more detailed
        let salX = w * 0.72, salBase = h * 0.76
        let wood = Color(red: 0.30, green: 0.20, blue: 0.12)
        let woodDk = Color(red: 0.20, green: 0.12, blue: 0.07)
        let warmGlow = Color(red: 1.0, green: 0.85, blue: 0.40)
        // Building body
        fill(&ctx, x: salX, y: salBase - px * 8, w: px * 10, h: px * 8, wood)
        // False front
        fill(&ctx, x: salX - px, y: salBase - px * 10, w: px * 12, h: px * 2, woodDk)
        // Plank texture
        for i in stride(from: 0, to: 10, by: 2) {
            fill(&ctx, x: salX + CGFloat(i) * px, y: salBase - px * 8, w: px * 0.5, h: px * 8, woodDk.opacity(0.2))
        }
        // Swinging door
        pixel(&ctx, x: salX + px * 4, y: salBase - px, woodDk)
        pixel(&ctx, x: salX + px * 5, y: salBase - px, woodDk)
        pixel(&ctx, x: salX + px * 4, y: salBase - px * 2, woodDk)
        pixel(&ctx, x: salX + px * 5, y: salBase - px * 2, woodDk)
        // Windows with warm glow
        pixel(&ctx, x: salX + px, y: salBase - px * 5, warmGlow.opacity(0.7))
        pixel(&ctx, x: salX + px * 2, y: salBase - px * 5, warmGlow.opacity(0.7))
        pixel(&ctx, x: salX + px * 7, y: salBase - px * 5, warmGlow.opacity(0.7))
        pixel(&ctx, x: salX + px * 8, y: salBase - px * 5, warmGlow.opacity(0.7))
        // Light spill from door
        pixel(&ctx, x: salX + px * 4, y: salBase, warmGlow.opacity(0.1))
        pixel(&ctx, x: salX + px * 5, y: salBase, warmGlow.opacity(0.1))

        // Windmill behind saloon
        let wmX = w * 0.88, wmBase = salBase
        let metal = Color(red: 0.42, green: 0.38, blue: 0.30)
        fill(&ctx, x: wmX, y: wmBase - px * 10, w: px, h: px * 10, metal)
        // Blades (X shape)
        pixel(&ctx, x: wmX - px * 2, y: wmBase - px * 12, metal.opacity(0.6))
        pixel(&ctx, x: wmX - px, y: wmBase - px * 11, metal.opacity(0.6))
        pixel(&ctx, x: wmX + px, y: wmBase - px * 11, metal.opacity(0.6))
        pixel(&ctx, x: wmX + px * 2, y: wmBase - px * 12, metal.opacity(0.6))
        pixel(&ctx, x: wmX - px, y: wmBase - px * 9, metal.opacity(0.5))
        pixel(&ctx, x: wmX + px, y: wmBase - px * 9, metal.opacity(0.5))

        // Vulture circling (silhouette)
        let vulture = Color(red: 0.15, green: 0.10, blue: 0.06).opacity(0.5)
        let vx = w * 0.40, vy = h * 0.14
        pixel(&ctx, x: vx, y: vy, vulture)
        pixel(&ctx, x: vx - px, y: vy - px * 0.5, vulture)
        pixel(&ctx, x: vx - px * 2, y: vy, vulture)
        pixel(&ctx, x: vx + px, y: vy - px * 0.5, vulture)
        pixel(&ctx, x: vx + px * 2, y: vy, vulture)

        // Tumbleweed
        let tweed = Color(red: 0.55, green: 0.42, blue: 0.25)
        let twX = w * 0.14, twY = h * 0.73
        fill(&ctx, x: twX, y: twY, w: px * 3, h: px * 2, tweed.opacity(0.4))
        pixel(&ctx, x: twX + px, y: twY - px, tweed.opacity(0.3))

        // Wagon wheel
        let whlX = w * 0.64, whlY = h * 0.74
        let whlC = Color(red: 0.42, green: 0.28, blue: 0.14)
        for a in 0..<8 {
            let angle = CGFloat(a) * .pi / 4
            let dx = cos(angle) * px * 2
            let dy = sin(angle) * px * 2
            pixel(&ctx, x: whlX + dx, y: whlY + dy, whlC.opacity(0.5))
        }
        pixel(&ctx, x: whlX, y: whlY, whlC.opacity(0.6))

        // Desert ground with cracks
        fill(&ctx, x: 0, y: h * 0.76, w: w, h: h * 0.24, theme.previewGroundColor)
        let crack = Color(red: 0.50, green: 0.38, blue: 0.22)
        fill(&ctx, x: w * 0.15, y: h * 0.82, w: px * 5, h: px, crack.opacity(0.4))
        fill(&ctx, x: w * 0.17, y: h * 0.82 + px, w: px * 3, h: px, crack.opacity(0.3))
        fill(&ctx, x: w * 0.55, y: h * 0.85, w: px * 4, h: px, crack.opacity(0.35))
        fill(&ctx, x: w * 0.40, y: h * 0.80, w: px * 3, h: px, crack.opacity(0.3))
    }

    // MARK: - JUNGLE — HUGE trees, dense canopy, snakes, vines, ferns, butterflies

    private func drawJungle(ctx: inout GraphicsContext, w: CGFloat, h: CGFloat) {
        skyGradient(&ctx, w: w, h: h)

        let canopyDark = Color(red: 0.06, green: 0.18, blue: 0.04)
        let canopyMid = Color(red: 0.12, green: 0.30, blue: 0.08)
        let canopyLight = Color(red: 0.22, green: 0.48, blue: 0.16)
        let canopyBright = Color(red: 0.30, green: 0.58, blue: 0.22)
        let trunk = Color(red: 0.28, green: 0.18, blue: 0.10)
        let trunkLight = Color(red: 0.38, green: 0.26, blue: 0.14)
        let vine = Color(red: 0.16, green: 0.38, blue: 0.12)
        let snakeGreen = Color(red: 0.35, green: 0.60, blue: 0.20)
        let snakeYellow = Color(red: 0.65, green: 0.70, blue: 0.15)
        let snakeEye = Color(red: 0.85, green: 0.20, blue: 0.10)

        // Dense canopy blanket across top — thick, irregular, multi-layered
        for x in stride(from: CGFloat(0), to: w, by: px) {
            let layer1 = (sin(x / w * .pi * 3.5) * 0.5 + 0.5) * h * 0.22 + h * 0.08
            let layer2 = (sin(x / w * .pi * 6 + 1.2) * 0.5 + 0.5) * h * 0.16 + h * 0.04
            let layer3 = (cos(x / w * .pi * 4.5 + 0.8) * 0.5 + 0.5) * h * 0.14
            let maxH = max(layer1, max(layer2, layer3))
            fill(&ctx, x: x, y: 0, w: px, h: maxH, canopyDark)
            // Lighter edge on canopy bottom
            if maxH > h * 0.12 {
                fill(&ctx, x: x, y: maxH - px * 3, w: px, h: px, canopyMid)
                fill(&ctx, x: x, y: maxH - px * 2, w: px, h: px, canopyLight)
                fill(&ctx, x: x, y: maxH - px, w: px, h: px, canopyBright)
            }
        }

        // HUGE tree #1 — left side, massive trunk floor-to-canopy
        let t1x = w * 0.18
        let trunkW1: CGFloat = px * 5
        for y in stride(from: h * 0.10, to: h * 0.78, by: px) {
            // Slightly wavy trunk
            let sway = sin(y / h * .pi * 2) * px
            fill(&ctx, x: t1x + sway, y: y, w: trunkW1, h: px, trunk)
            // Bark texture — lighter pixel on one side
            pixel(&ctx, x: t1x + sway + px, y: y, trunkLight)
        }
        // Massive spreading branches
        for i in 0..<3 {
            let branchY = h * 0.15 + CGFloat(i) * h * 0.08
            let branchDir: CGFloat = i % 2 == 0 ? 1 : -1
            for bx in 0..<6 {
                let bxPos = t1x + trunkW1 / 2 + CGFloat(bx) * px * 2 * branchDir
                let byPos = branchY - CGFloat(bx) * px
                fill(&ctx, x: bxPos, y: byPos, w: px * 2, h: px, trunk)
                // Leaf clusters on branches
                fill(&ctx, x: bxPos - px, y: byPos - px * 2, w: px * 4, h: px * 2, canopyMid)
            }
        }

        // Vine draping from tree 1
        for i in 0..<12 {
            let vy = h * 0.18 + CGFloat(i) * px * 2.5
            let vx = t1x + trunkW1 + px * 2 + sin(CGFloat(i) * 0.7) * px * 2
            pixel(&ctx, x: vx, y: vy, vine)
        }
        // Second vine
        for i in 0..<8 {
            let vy = h * 0.22 + CGFloat(i) * px * 2.5
            let vx = t1x - px * 2 + cos(CGFloat(i) * 0.5) * px * 1.5
            pixel(&ctx, x: vx, y: vy, vine.opacity(0.8))
        }

        // HUGE tree #2 — right side
        let t2x = w * 0.70
        let trunkW2: CGFloat = px * 4
        for y in stride(from: h * 0.14, to: h * 0.78, by: px) {
            let sway = sin(y / h * .pi * 1.5 + 1) * px * 0.5
            fill(&ctx, x: t2x + sway, y: y, w: trunkW2, h: px, trunk)
            pixel(&ctx, x: t2x + sway + px * 2, y: y, trunkLight)
        }
        // Branch
        for bx in 0..<5 {
            fill(&ctx, x: t2x - CGFloat(bx) * px * 2, y: h * 0.20 - CGFloat(bx) * px, w: px * 2, h: px, trunk)
        }
        // Leaf mass on tree 2
        fill(&ctx, x: t2x - px * 6, y: h * 0.10, w: px * 14, h: px * 5, canopyMid)
        fill(&ctx, x: t2x - px * 5, y: h * 0.07, w: px * 12, h: px * 4, canopyDark)

        // 🐍 Snake coiled on tree 1 branch
        let snakeBaseY = h * 0.30
        let snakeBaseX = t1x + trunkW1 / 2
        // Body coils
        for i in 0..<7 {
            let sx = snakeBaseX + sin(CGFloat(i) * 1.2) * px * 2
            let sy = snakeBaseY + CGFloat(i) * px * 1.5
            pixel(&ctx, x: sx, y: sy, i % 2 == 0 ? snakeGreen : snakeYellow)
        }
        // Head
        let headX = snakeBaseX + sin(0.0) * px * 2
        pixel(&ctx, x: headX, y: snakeBaseY - px, snakeGreen)
        pixel(&ctx, x: headX + px, y: snakeBaseY - px, snakeGreen)
        // Eye
        pixel(&ctx, x: headX + px, y: snakeBaseY - px * 2, snakeEye)

        // 🐍 Small snake on tree 2
        let s2x = t2x + px
        let s2y = h * 0.45
        for i in 0..<5 {
            pixel(&ctx, x: s2x + sin(CGFloat(i) * 1.0) * px, y: s2y + CGFloat(i) * px * 1.5, snakeYellow)
        }
        pixel(&ctx, x: s2x, y: s2y - px, snakeGreen) // head
        pixel(&ctx, x: s2x + px, y: s2y - px * 1.5, snakeEye) // eye

        // Dense fern undergrowth
        let fern = Color(red: 0.20, green: 0.52, blue: 0.15)
        let fernDark = Color(red: 0.12, green: 0.38, blue: 0.10)
        for i in 0..<Int(w / (px * 3)) {
            let fx = CGFloat(i) * px * 3
            let fh = px * (2 + CGFloat(i % 4))
            pixel(&ctx, x: fx, y: h * 0.78 - fh, i % 2 == 0 ? fern : fernDark)
            pixel(&ctx, x: fx + px, y: h * 0.78 - fh + px, fern.opacity(0.6))
            if i % 3 == 0 {
                pixel(&ctx, x: fx - px, y: h * 0.78 - fh + px, fernDark.opacity(0.5))
            }
        }

        // Butterflies
        let butterfly1 = Color(red: 0.9, green: 0.55, blue: 0.15)
        let butterfly2 = Color(red: 0.2, green: 0.6, blue: 0.9)
        pixel(&ctx, x: w * 0.48, y: h * 0.42, butterfly1)
        pixel(&ctx, x: w * 0.48 + px, y: h * 0.42 - px, butterfly1)
        pixel(&ctx, x: w * 0.48 - px, y: h * 0.42 - px, butterfly1)
        pixel(&ctx, x: w * 0.55, y: h * 0.55, butterfly2)
        pixel(&ctx, x: w * 0.55 + px, y: h * 0.55 - px, butterfly2)
        pixel(&ctx, x: w * 0.55 - px, y: h * 0.55 - px, butterfly2)

        // Tropical flowers on ground
        let flower1 = Color(red: 1.0, green: 0.3, blue: 0.4)
        let flower2 = Color(red: 0.9, green: 0.2, blue: 0.7)
        pixel(&ctx, x: w * 0.38, y: h * 0.74, flower1)
        pixel(&ctx, x: w * 0.38 + px, y: h * 0.74, Color(red: 1.0, green: 0.9, blue: 0.3))
        pixel(&ctx, x: w * 0.60, y: h * 0.75, flower2)

        // Ground — dark jungle floor
        fill(&ctx, x: 0, y: h * 0.78, w: w, h: h * 0.22, theme.previewGroundColor)
    }

    // MARK: - EGYPT — golden sky, pyramids with detail, sphinx, camel caravan, obelisk, hieroglyphs, Nile strip

    private func drawEgypt(ctx: inout GraphicsContext, w: CGFloat, h: CGFloat) {
        skyGradient(&ctx, w: w, h: h)

        // Blazing sun with glow
        let sunColor = Color(red: 1.0, green: 0.88, blue: 0.40)
        let sunGlow = Color(red: 1.0, green: 0.75, blue: 0.25)
        let sunX = w * 0.82, sunY = h * 0.16
        for dy in -4...4 {
            for dx in -4...4 {
                let dist = sqrt(CGFloat(dx * dx + dy * dy))
                if dist <= 4 {
                    let c = dist < 2.5 ? sunColor : sunGlow.opacity(0.7)
                    pixel(&ctx, x: sunX + CGFloat(dx) * px, y: sunY + CGFloat(dy) * px, c)
                }
            }
        }
        // Sun rays
        for dy in -6...6 {
            for dx in -6...6 {
                let dist = sqrt(CGFloat(dx * dx + dy * dy))
                if dist > 4 && dist <= 5.5 { pixel(&ctx, x: sunX + CGFloat(dx) * px, y: sunY + CGFloat(dy) * px, sunGlow.opacity(0.12)) }
            }
        }

        // Sand dunes — gentle rolling
        let sand = Color(red: 0.78, green: 0.62, blue: 0.35)
        let sandDark = Color(red: 0.65, green: 0.50, blue: 0.28)
        drawSineHills(&ctx, w: w, baseY: h * 0.68, amplitude: h * 0.06, freq: 2.0, phase: 0, color: sand.opacity(0.35))
        drawSineHills(&ctx, w: w, baseY: h * 0.72, amplitude: h * 0.04, freq: 3.5, phase: 1.5, color: sandDark.opacity(0.25))

        // Great Pyramid — large, with stone block texture
        let pyrLit = Color(red: 0.82, green: 0.65, blue: 0.30)
        let pyrShadow = Color(red: 0.45, green: 0.32, blue: 0.14)
        let pyrCap = Color(red: 0.95, green: 0.82, blue: 0.30)
        let pyr1X = w * 0.30
        let pyr1W: CGFloat = px * 24
        let pyr1H: CGFloat = h * 0.42
        let pyr1Top = h * 0.72 - pyr1H
        for dy in 0..<Int(pyr1H / px) {
            let ratio = CGFloat(dy) / (pyr1H / px)
            let rowW = pyr1W * ratio
            let rowX = pyr1X - rowW / 2
            let halfW = rowW / 2
            if halfW > 0 {
                fill(&ctx, x: rowX, y: pyr1Top + CGFloat(dy) * px, w: halfW, h: px, pyrLit)
                fill(&ctx, x: rowX + halfW, y: pyr1Top + CGFloat(dy) * px, w: halfW, h: px, pyrShadow)
            }
            // Block seams every 3 rows
            if dy % 3 == 0 && rowW > px * 2 {
                fill(&ctx, x: rowX, y: pyr1Top + CGFloat(dy) * px, w: rowW, h: px * 0.3,
                     Color(red: 0.40, green: 0.30, blue: 0.15).opacity(0.2))
            }
        }
        // Golden capstone
        fill(&ctx, x: pyr1X - px, y: pyr1Top, w: px * 2, h: px, pyrCap)
        pixel(&ctx, x: pyr1X - px * 0.5, y: pyr1Top - px, pyrCap)

        // Smaller pyramid behind
        let pyr2X = w * 0.52
        let pyr2W: CGFloat = px * 16
        let pyr2H: CGFloat = h * 0.28
        let pyr2Top = h * 0.72 - pyr2H
        for dy in 0..<Int(pyr2H / px) {
            let ratio = CGFloat(dy) / (pyr2H / px)
            let rowW = pyr2W * ratio
            let rowX = pyr2X - rowW / 2
            let halfW = rowW / 2
            if halfW > 0 {
                fill(&ctx, x: rowX, y: pyr2Top + CGFloat(dy) * px, w: halfW, h: px, pyrLit.opacity(0.75))
                fill(&ctx, x: rowX + halfW, y: pyr2Top + CGFloat(dy) * px, w: halfW, h: px, pyrShadow.opacity(0.75))
            }
        }

        // Sphinx silhouette (left of pyramid)
        let sphinxC = Color(red: 0.68, green: 0.52, blue: 0.28)
        let sphinxD = Color(red: 0.55, green: 0.40, blue: 0.22)
        let sX = w * 0.08, sY = h * 0.68
        // Body
        fill(&ctx, x: sX, y: sY, w: px * 7, h: px * 3, sphinxC.opacity(0.6))
        // Head
        fill(&ctx, x: sX, y: sY - px * 2, w: px * 3, h: px * 2, sphinxC.opacity(0.7))
        pixel(&ctx, x: sX, y: sY - px * 3, sphinxD.opacity(0.6)) // headdress top
        pixel(&ctx, x: sX + px, y: sY - px * 3, sphinxD.opacity(0.6))

        // Obelisk with hieroglyphs
        let obX = w * 0.70, obBase = h * 0.72
        let obColor = Color(red: 0.62, green: 0.48, blue: 0.26)
        let hieroglyph = Color(red: 0.45, green: 0.35, blue: 0.18)
        fill(&ctx, x: obX, y: obBase - px * 12, w: px * 2, h: px * 12, obColor)
        // Pyramidion top
        pixel(&ctx, x: obX, y: obBase - px * 13, pyrCap)
        pixel(&ctx, x: obX + px, y: obBase - px * 13, pyrCap)
        pixel(&ctx, x: obX + px * 0.5, y: obBase - px * 14, pyrCap)
        // Hieroglyph marks
        for i in 0..<4 {
            pixel(&ctx, x: obX + px * 0.5, y: obBase - px * CGFloat(3 + i * 2), hieroglyph.opacity(0.3))
        }

        // Camel caravan in distance
        let camelC = Color(red: 0.52, green: 0.38, blue: 0.22).opacity(0.4)
        for (cx, cy) in [(w * 0.58, h * 0.65), (w * 0.62, h * 0.65), (w * 0.66, h * 0.66)] {
            // Body
            fill(&ctx, x: cx, y: cy, w: px * 2, h: px, camelC)
            // Hump
            pixel(&ctx, x: cx + px * 0.5, y: cy - px, camelC)
            // Head
            pixel(&ctx, x: cx - px * 0.5, y: cy - px * 0.5, camelC)
            // Legs
            pixel(&ctx, x: cx, y: cy + px, camelC)
            pixel(&ctx, x: cx + px, y: cy + px, camelC)
        }

        // Palm trees — oasis feel
        let palmTrunk = Color(red: 0.45, green: 0.30, blue: 0.15)
        let palmLeaf = Color(red: 0.30, green: 0.50, blue: 0.18)
        let palmLeafL = Color(red: 0.38, green: 0.58, blue: 0.22)
        for (px2, bend) in [(w * 0.90, 1.0), (w * 0.95, -0.5)] as [(CGFloat, CGFloat)] {
            for i in 0..<7 {
                let sway = sin(CGFloat(i) * 0.3) * px * bend
                pixel(&ctx, x: px2 + sway, y: h * 0.72 - CGFloat(i) * px, palmTrunk)
            }
            // Fronds (drooping)
            for d in [-3, -2, -1, 1, 2, 3] as [CGFloat] {
                pixel(&ctx, x: px2 + d * px, y: h * 0.72 - 7 * px + abs(d) * px * 0.5, d < 0 ? palmLeaf : palmLeafL)
            }
            pixel(&ctx, x: px2, y: h * 0.72 - 8 * px, palmLeaf)
        }

        // Nile water strip
        let nile = Color(red: 0.25, green: 0.45, blue: 0.55)
        fill(&ctx, x: w * 0.86, y: h * 0.72, w: px * 3, h: h * 0.08, nile.opacity(0.25))
        pixel(&ctx, x: w * 0.87, y: h * 0.73, Color.white.opacity(0.08))

        // Sand ground
        fill(&ctx, x: 0, y: h * 0.72, w: w, h: h * 0.28, theme.previewGroundColor)
        // Sand texture / ripples
        for i in 0..<6 {
            let rx = prng(44, i) * w
            fill(&ctx, x: rx, y: h * 0.76 + prng(44, i + 10) * h * 0.06, w: px * 4, h: px * 0.5,
                 sandDark.opacity(0.2))
        }
    }

    // MARK: - CAVE — claustrophobic ceiling, stalactites, stalagmites, crystal glow, underground river, NO sky

    private func drawCave(ctx: inout GraphicsContext, w: CGFloat, h: CGFloat) {
        // No sky — entire background is dark cave
        fill(&ctx, x: 0, y: 0, w: w, h: h, Color(red: 0.03, green: 0.02, blue: 0.05))

        // Depth glow from crystals (ambient light in center)
        let ambientGlow = Color(red: 0.08, green: 0.06, blue: 0.14)
        fill(&ctx, x: w * 0.2, y: h * 0.25, w: w * 0.6, h: h * 0.35, ambientGlow.opacity(0.3))

        let rockDark = Color(red: 0.08, green: 0.06, blue: 0.11)
        let rockMid = Color(red: 0.16, green: 0.13, blue: 0.20)
        let rockLight = Color(red: 0.26, green: 0.22, blue: 0.30)
        let crystalCyan = Color(red: 0.25, green: 0.82, blue: 0.88)
        let crystalPink = Color(red: 0.88, green: 0.25, blue: 0.75)
        let crystalAmber = Color(red: 0.88, green: 0.63, blue: 0.13)
        let crystalGlow = Color(red: 0.20, green: 0.65, blue: 0.72)

        // Heavy rocky ceiling — irregular, oppressive
        for x in stride(from: CGFloat(0), to: w, by: px) {
            let ceilH = (sin(x / w * .pi * 5) * 0.35 + 0.5) * h * 0.15 + h * 0.08
            let extra = (cos(x / w * .pi * 8 + 2) * 0.3 + 0.3) * h * 0.06
            let totalH = max(ceilH, ceilH + extra)
            fill(&ctx, x: x, y: 0, w: px, h: totalH, rockDark)
            fill(&ctx, x: x, y: totalH - px, w: px, h: px, rockLight.opacity(0.4))
        }

        // Stalactites — dramatic, long, some with crystal tips
        let stalactites: [(x: CGFloat, len: CGFloat, crystal: Bool)] = [
            (0.08, 0.25, false), (0.18, 0.35, true), (0.30, 0.20, false),
            (0.42, 0.42, true), (0.55, 0.18, false), (0.65, 0.38, true),
            (0.78, 0.28, false), (0.88, 0.32, true),
        ]
        for stal in stalactites {
            let sx = stal.x * w
            let sLen = stal.len * h
            let baseW: CGFloat = px * 3
            for dy in 0..<Int(sLen / px) {
                let ratio = CGFloat(dy) / (sLen / px)
                let rowW = baseW * (1.0 - ratio * 0.85)
                let rowX = sx - rowW / 2
                let c: Color
                if stal.crystal && ratio > 0.6 {
                    c = crystalCyan.opacity(0.7 + ratio * 0.2)
                } else if ratio > 0.85 {
                    c = rockLight
                } else {
                    c = rockMid
                }
                fill(&ctx, x: rowX, y: CGFloat(dy) * px, w: max(rowW, px), h: px, c)
            }
            // Drip / glow at crystal tips
            if stal.crystal {
                let tipY = sLen
                pixel(&ctx, x: sx, y: tipY, crystalCyan.opacity(0.5))
                pixel(&ctx, x: sx - px, y: tipY, crystalGlow.opacity(0.15))
                pixel(&ctx, x: sx + px, y: tipY, crystalGlow.opacity(0.15))
                pixel(&ctx, x: sx, y: tipY + px, crystalGlow.opacity(0.08))
            }
        }

        // Underground river/pool glowing in middle
        let riverY = h * 0.60
        let riverColor = Color(red: 0.10, green: 0.35, blue: 0.45)
        let riverGlow = Color(red: 0.15, green: 0.50, blue: 0.60)
        fill(&ctx, x: w * 0.25, y: riverY, w: w * 0.50, h: px * 3, riverColor.opacity(0.5))
        fill(&ctx, x: w * 0.30, y: riverY + px, w: w * 0.40, h: px, riverGlow.opacity(0.3))
        // Reflections in water
        for i in 0..<4 {
            let rx = w * 0.30 + prng(44, i + 30) * w * 0.35
            pixel(&ctx, x: rx, y: riverY + px, .white.opacity(0.12))
        }

        // Stalagmites rising from ground — more dramatic
        let groundY = h * 0.78
        let stalagmites: [(x: CGFloat, len: CGFloat, crystal: Bool)] = [
            (0.05, 0.22, true), (0.15, 0.16, false), (0.28, 0.32, true),
            (0.42, 0.14, false), (0.55, 0.28, true), (0.68, 0.20, false),
            (0.78, 0.35, true), (0.90, 0.18, false), (0.97, 0.24, true),
        ]
        for stal in stalagmites {
            let sx = stal.x * w
            let sLen = stal.len * h
            let baseW: CGFloat = px * 3
            for dy in 0..<Int(sLen / px) {
                let ratio = CGFloat(dy) / (sLen / px)
                let rowW = baseW * (1.0 - ratio * 0.85)
                let rowX = sx - rowW / 2
                let yPos = groundY - CGFloat(dy) * px
                let c: Color
                if stal.crystal && ratio > 0.5 {
                    c = ratio > 0.7 ? crystalPink.opacity(0.8) : crystalAmber.opacity(0.6)
                } else {
                    c = ratio > 0.6 ? rockLight : rockMid
                }
                fill(&ctx, x: rowX, y: yPos, w: max(rowW, px), h: px, c)
            }
            // Crystal glow halo at tips
            if stal.crystal {
                let tipY = groundY - sLen
                let glowC = stal.x < 0.5 ? crystalPink : crystalAmber
                pixel(&ctx, x: sx - px, y: tipY, glowC.opacity(0.12))
                pixel(&ctx, x: sx + px, y: tipY, glowC.opacity(0.12))
                pixel(&ctx, x: sx, y: tipY - px, glowC.opacity(0.08))
            }
        }

        // Glowing crystal clusters on walls
        for i in 0..<6 {
            let gx = prng(44, i) * w
            let isTop = i % 2 == 0
            let gy = isTop ? h * 0.05 + prng(44, i + 10) * h * 0.08 : h * 0.80 + prng(44, i + 10) * h * 0.06
            let c = i % 3 == 0 ? crystalCyan : (i % 3 == 1 ? crystalPink : crystalAmber)
            pixel(&ctx, x: gx, y: gy, c.opacity(0.6))
            pixel(&ctx, x: gx - px, y: gy, c.opacity(0.18))
            pixel(&ctx, x: gx + px, y: gy, c.opacity(0.18))
            pixel(&ctx, x: gx, y: gy - px, c.opacity(0.12))
            pixel(&ctx, x: gx, y: gy + px, c.opacity(0.12))
        }

        // Cave floor — dark rock with glowing moss
        fill(&ctx, x: 0, y: groundY, w: w, h: h * 0.22, rockDark)
        let moss = Color(red: 0.12, green: 0.55, blue: 0.28)
        for i in 0..<5 {
            let mx = prng(77, i) * w
            fill(&ctx, x: mx, y: groundY, w: px * 3, h: px, moss.opacity(0.45))
            fill(&ctx, x: mx + px, y: groundY + px, w: px, h: px, moss.opacity(0.20))
        }
    }

    // MARK: - MOUNTAIN — dramatic range, waterfall, cabin, deer, pine forest, alpine meadow, eagle

    private func drawMountain(ctx: inout GraphicsContext, w: CGFloat, h: CGFloat) {
        skyGradient(&ctx, w: w, h: h)

        // Wispy clouds
        for i in 0..<2 {
            let cx = w * (0.15 + CGFloat(i) * 0.50)
            let cy = h * 0.08 + CGFloat(i) * px * 2
            fill(&ctx, x: cx, y: cy, w: px * 10, h: px, .white.opacity(0.4))
            fill(&ctx, x: cx + px * 2, y: cy + px, w: px * 7, h: px, .white.opacity(0.25))
        }

        // Dramatic mountain range — multiple overlapping peaks
        let rockFar = Color(red: 0.45, green: 0.52, blue: 0.62)
        let rockNear = Color(red: 0.35, green: 0.42, blue: 0.52)
        let snow = Color(red: 0.92, green: 0.95, blue: 1.0)
        let snowMid = Color(red: 0.78, green: 0.84, blue: 0.92)

        // Far range
        let farPeaks: [(x: CGFloat, halfW: CGFloat, peakH: CGFloat)] = [
            (0.10, 0.12, 0.35), (0.28, 0.16, 0.48), (0.48, 0.10, 0.32),
            (0.65, 0.18, 0.52), (0.85, 0.14, 0.40), (0.98, 0.08, 0.28),
        ]
        for peak in farPeaks {
            let cx = peak.x * w
            let pW = peak.halfW * w
            let pH = peak.peakH * h
            let pTop = h * 0.72 - pH
            for dy in 0..<Int(pH / px) {
                let ratio = CGFloat(dy) / (pH / px)
                let rowW = pW * 2 * ratio
                let c = ratio < 0.22 ? snow : (ratio < 0.38 ? snowMid : rockFar)
                fill(&ctx, x: cx - rowW / 2, y: pTop + CGFloat(dy) * px, w: rowW, h: px, c)
            }
        }

        // Nearer rocky ridge
        drawSineHills(&ctx, w: w, baseY: h * 0.58, amplitude: h * 0.10, freq: 3.5, phase: 1.0, color: rockNear.opacity(0.6))

        // Waterfall on left peak
        let waterfallX = w * 0.30
        let waterfallBlue = Color(red: 0.65, green: 0.80, blue: 0.95)
        let waterfallWhite = Color.white.opacity(0.6)
        for i in 0..<8 {
            let fy = h * 0.32 + CGFloat(i) * px * 2
            let sway = sin(CGFloat(i) * 0.8) * px * 0.5
            fill(&ctx, x: waterfallX + sway, y: fy, w: px, h: px * 2, waterfallBlue.opacity(0.5))
            if i % 3 == 0 { pixel(&ctx, x: waterfallX + sway + px, y: fy, waterfallWhite.opacity(0.3)) }
        }
        // Splash at base
        pixel(&ctx, x: waterfallX - px, y: h * 0.48, waterfallWhite.opacity(0.2))
        pixel(&ctx, x: waterfallX + px, y: h * 0.48, waterfallWhite.opacity(0.2))

        // Dense pine forest — two layers
        let pineDark = Color(red: 0.10, green: 0.25, blue: 0.08)
        let pineMid = Color(red: 0.16, green: 0.32, blue: 0.12)
        let pineLight = Color(red: 0.22, green: 0.38, blue: 0.18)
        // Back row (smaller)
        for (tx, th) in [(0.05, 7), (0.15, 9), (0.25, 6), (0.38, 8), (0.50, 7),
                          (0.60, 9), (0.72, 6), (0.82, 8), (0.93, 7)] as [(CGFloat, Int)] {
            drawPixelPine(&ctx, x: tx * w, baseY: h * 0.68, height: th, dark: pineDark, light: pineMid)
        }
        // Front row (larger, darker)
        for (tx, th) in [(0.08, 10), (0.22, 12), (0.45, 9), (0.58, 11), (0.75, 10), (0.90, 8)] as [(CGFloat, Int)] {
            drawPixelPine(&ctx, x: tx * w, baseY: h * 0.72, height: th, dark: pineDark, light: pineLight)
        }

        // Log cabin nestled in trees
        let cabin = Color(red: 0.35, green: 0.22, blue: 0.12)
        let cabinD = Color(red: 0.25, green: 0.16, blue: 0.08)
        let cabX = w * 0.42, cabY = h * 0.68
        fill(&ctx, x: cabX, y: cabY, w: px * 6, h: px * 4, cabin)
        // Roof
        fill(&ctx, x: cabX - px, y: cabY - px, w: px * 8, h: px, cabinD)
        fill(&ctx, x: cabX, y: cabY - px * 2, w: px * 6, h: px, cabinD)
        pixel(&ctx, x: cabX + px * 3, y: cabY - px * 3, cabinD) // peak
        // Window
        pixel(&ctx, x: cabX + px * 2, y: cabY + px, Color(red: 1.0, green: 0.85, blue: 0.35).opacity(0.5))
        // Door
        pixel(&ctx, x: cabX + px * 4, y: cabY + px * 2, cabinD)
        pixel(&ctx, x: cabX + px * 4, y: cabY + px * 3, cabinD)
        // Chimney smoke
        pixel(&ctx, x: cabX + px * 5, y: cabY - px * 3, Color.white.opacity(0.15))
        pixel(&ctx, x: cabX + px * 5, y: cabY - px * 4, Color.white.opacity(0.08))

        // Deer silhouette
        let deerC = Color(red: 0.42, green: 0.30, blue: 0.18).opacity(0.5)
        let deerX = w * 0.68, deerY = h * 0.70
        fill(&ctx, x: deerX, y: deerY, w: px * 2, h: px, deerC) // body
        pixel(&ctx, x: deerX - px, y: deerY - px, deerC) // head
        pixel(&ctx, x: deerX - px, y: deerY - px * 2, deerC.opacity(0.3)) // antler
        pixel(&ctx, x: deerX - px * 2, y: deerY - px * 2.5, deerC.opacity(0.2))
        pixel(&ctx, x: deerX, y: deerY + px, deerC.opacity(0.3)) // legs
        pixel(&ctx, x: deerX + px, y: deerY + px, deerC.opacity(0.3))

        // Eagle soaring
        let eagle = Color(red: 0.12, green: 0.10, blue: 0.06)
        let eX = w * 0.55, eY = h * 0.14
        pixel(&ctx, x: eX, y: eY, eagle)
        pixel(&ctx, x: eX - px, y: eY - px, eagle)
        pixel(&ctx, x: eX - px * 2, y: eY, eagle)
        pixel(&ctx, x: eX - px * 3, y: eY + px * 0.5, eagle.opacity(0.6))
        pixel(&ctx, x: eX + px, y: eY - px, eagle)
        pixel(&ctx, x: eX + px * 2, y: eY, eagle)
        pixel(&ctx, x: eX + px * 3, y: eY + px * 0.5, eagle.opacity(0.6))

        // Alpine meadow with wildflowers
        fill(&ctx, x: 0, y: h * 0.72, w: w, h: h * 0.28, theme.previewGroundColor)
        let flowerColors: [Color] = [
            Color(red: 0.9, green: 0.3, blue: 0.3), Color(red: 0.9, green: 0.8, blue: 0.2),
            Color(red: 0.6, green: 0.3, blue: 0.8), Color(red: 1.0, green: 0.5, blue: 0.7),
            Color(red: 1.0, green: 1.0, blue: 0.9),
        ]
        let stem = Color(red: 0.20, green: 0.45, blue: 0.15)
        for i in 0..<10 {
            let fx = prng(22, i) * w
            let fy = h * 0.72 - prng(22, i + 20) * px
            pixel(&ctx, x: fx, y: fy, stem)
            pixel(&ctx, x: fx, y: fy - px, flowerColors[i % flowerColors.count])
        }
        // Grass tufts
        for i in 0..<8 {
            let gx = prng(22, i + 30) * w
            pixel(&ctx, x: gx, y: h * 0.72 - px, Color(red: 0.25, green: 0.48, blue: 0.18).opacity(0.5))
        }
    }

    // MARK: - SPACE — nebula, ringed planet, space station, shuttle, asteroids, crater surface, stars

    private func drawSpace(ctx: inout GraphicsContext, w: CGFloat, h: CGFloat) {
        skyGradient(&ctx, w: w, h: h)

        // Nebula glow — multi-colored clouds
        let nebulaP = Color(red: 0.18, green: 0.06, blue: 0.35)
        let nebulaB = Color(red: 0.06, green: 0.12, blue: 0.30)
        let nebulaR = Color(red: 0.30, green: 0.06, blue: 0.12)
        fill(&ctx, x: w * 0.0, y: h * 0.02, w: w * 0.35, h: h * 0.20, nebulaB.opacity(0.10))
        fill(&ctx, x: w * 0.30, y: h * 0.05, w: w * 0.40, h: h * 0.25, nebulaP.opacity(0.12))
        fill(&ctx, x: w * 0.60, y: h * 0.08, w: w * 0.30, h: h * 0.18, nebulaR.opacity(0.08))

        // Dense star field
        for i in 0..<35 {
            let sx = prng(55, i * 2) * w
            let sy = prng(55, i * 2 + 1) * h * 0.65
            let bright = 0.25 + prng(55, i * 3) * 0.75
            let size = prng(55, i * 4) > 0.85 ? px * 1.5 : px
            fill(&ctx, x: sx, y: sy, w: size, h: size, .white.opacity(bright))
        }
        // Colored star accents
        pixel(&ctx, x: prng(55, 80) * w, y: prng(55, 81) * h * 0.4, Color(red: 0.6, green: 0.8, blue: 1.0).opacity(0.5))
        pixel(&ctx, x: prng(55, 82) * w, y: prng(55, 83) * h * 0.3, Color(red: 1.0, green: 0.7, blue: 0.5).opacity(0.4))

        // Ringed planet — larger, more detailed
        let planetX = w * 0.72, planetY = h * 0.18
        let planetDark = Color(red: 0.30, green: 0.22, blue: 0.48)
        let planetLit = Color(red: 0.48, green: 0.38, blue: 0.65)
        let planetHigh = Color(red: 0.58, green: 0.50, blue: 0.72)
        for dy in -5...5 {
            for dx in -5...5 {
                let dist = sqrt(CGFloat(dx * dx + dy * dy))
                if dist <= 5 {
                    let c = dx < -2 ? planetHigh : (dx < 1 ? planetLit : planetDark)
                    pixel(&ctx, x: planetX + CGFloat(dx) * px, y: planetY + CGFloat(dy) * px, c)
                }
            }
        }
        // Band detail
        for dx in -5...5 {
            let dist = sqrt(CGFloat(dx * dx))
            if dist <= 5 {
                pixel(&ctx, x: planetX + CGFloat(dx) * px, y: planetY + px, planetDark.opacity(0.3))
            }
        }
        // Ring
        let ringC = Color(red: 0.62, green: 0.52, blue: 0.72)
        for dx in -8...8 {
            if abs(dx) > 4 {
                let ry = planetY + CGFloat(abs(dx)) * px * 0.25
                pixel(&ctx, x: planetX + CGFloat(dx) * px, y: ry, ringC.opacity(0.55))
                if abs(dx) > 5 {
                    pixel(&ctx, x: planetX + CGFloat(dx) * px, y: ry + px, ringC.opacity(0.25))
                }
            }
        }

        // Space station (small, boxy)
        let stationX = w * 0.22, stationY = h * 0.28
        let metal = Color(red: 0.35, green: 0.35, blue: 0.40)
        // Main module
        fill(&ctx, x: stationX, y: stationY, w: px * 4, h: px * 2, metal.opacity(0.5))
        // Solar panels
        fill(&ctx, x: stationX - px * 3, y: stationY + px * 0.5, w: px * 2, h: px, Color(red: 0.15, green: 0.20, blue: 0.50).opacity(0.5))
        fill(&ctx, x: stationX + px * 5, y: stationY + px * 0.5, w: px * 2, h: px, Color(red: 0.15, green: 0.20, blue: 0.50).opacity(0.5))
        // Light
        pixel(&ctx, x: stationX + px * 2, y: stationY - px, Color(red: 0.3, green: 1.0, blue: 0.5).opacity(0.6))

        // Small shuttle
        let shuttleX = w * 0.45, shuttleY = h * 0.40
        let shuttleC = Color(red: 0.75, green: 0.75, blue: 0.80)
        pixel(&ctx, x: shuttleX, y: shuttleY, shuttleC.opacity(0.5))
        pixel(&ctx, x: shuttleX + px, y: shuttleY, shuttleC.opacity(0.5))
        pixel(&ctx, x: shuttleX - px * 0.5, y: shuttleY + px * 0.5, shuttleC.opacity(0.3)) // tail
        // Thruster glow
        pixel(&ctx, x: shuttleX + px * 2, y: shuttleY, Color(red: 0.5, green: 0.7, blue: 1.0).opacity(0.3))

        // Asteroids floating
        let asterC = Color(red: 0.30, green: 0.25, blue: 0.20)
        for (ax, ay, aw) in [(w * 0.12, h * 0.48, 2.0), (w * 0.85, h * 0.42, 1.5), (w * 0.55, h * 0.15, 1.0)] as [(CGFloat, CGFloat, CGFloat)] {
            fill(&ctx, x: ax, y: ay, w: px * aw, h: px * aw, asterC.opacity(0.4))
            pixel(&ctx, x: ax, y: ay, Color(red: 0.40, green: 0.35, blue: 0.28).opacity(0.3))
        }

        // Cratered moon surface
        let terrain = Color(red: 0.12, green: 0.10, blue: 0.18)
        let terrainY = h * 0.72
        for x in stride(from: CGFloat(0), to: w, by: px) {
            let tH = (sin(x / w * .pi * 4) * 0.4 + 0.6) * h * 0.08
            fill(&ctx, x: x, y: terrainY - tH, w: px, h: tH, terrain)
        }
        // Craters
        let craterShadow = Color(red: 0.08, green: 0.06, blue: 0.12)
        let craterRim = Color(red: 0.20, green: 0.18, blue: 0.28)
        for (cx, cr) in [(w * 0.35, 3.0), (w * 0.60, 2.0), (w * 0.82, 2.5)] as [(CGFloat, CGFloat)] {
            let cy = terrainY + px * 2
            for dy in -Int(cr)...Int(cr) {
                for dx in -Int(cr)...Int(cr) {
                    let dist = sqrt(CGFloat(dx * dx + dy * dy))
                    if dist <= cr {
                        let c = dist < cr * 0.6 ? craterShadow : craterRim
                        pixel(&ctx, x: cx + CGFloat(dx) * px, y: cy + CGFloat(dy) * px, c)
                    }
                }
            }
        }

        // Satellite dish
        let dishX = w * 0.18, dishBase = terrainY
        fill(&ctx, x: dishX, y: dishBase - px * 5, w: px, h: px * 5, metal.opacity(0.7))
        pixel(&ctx, x: dishX - px * 2, y: dishBase - px * 5, metal.opacity(0.5))
        pixel(&ctx, x: dishX - px, y: dishBase - px * 6, metal.opacity(0.5))
        pixel(&ctx, x: dishX, y: dishBase - px * 7, metal.opacity(0.5))
        pixel(&ctx, x: dishX + px, y: dishBase - px * 6, metal.opacity(0.5))
        pixel(&ctx, x: dishX + px * 2, y: dishBase - px * 5, metal.opacity(0.5))
        pixel(&ctx, x: dishX, y: dishBase - px * 8, Color(red: 0.3, green: 1.0, blue: 0.5).opacity(0.6))

        // Antenna with blinking light
        let antX = w * 0.75
        fill(&ctx, x: antX, y: terrainY - px * 8, w: px, h: px * 8, metal.opacity(0.6))
        fill(&ctx, x: antX - px, y: terrainY - px * 8, w: px * 3, h: px, metal.opacity(0.5))
        pixel(&ctx, x: antX, y: terrainY - px * 9, Color(red: 1.0, green: 0.2, blue: 0.2).opacity(0.8))

        // Metal ground
        fill(&ctx, x: 0, y: terrainY, w: w, h: h * 0.28, theme.previewGroundColor)
        // Hazard stripe
        let hazard = Color(red: 0.85, green: 0.65, blue: 0.10)
        for i in stride(from: 0, to: Int(w / (px * 6)), by: 2) {
            fill(&ctx, x: CGFloat(i) * px * 6, y: terrainY, w: px * 3, h: px, hazard.opacity(0.35))
        }
        // Grid lines on surface
        for i in stride(from: 0, to: Int(w / (px * 10)), by: 1) {
            fill(&ctx, x: CGFloat(i) * px * 10, y: terrainY + px * 3, w: px * 0.5, h: h * 0.1,
                 Color(red: 0.15, green: 0.15, blue: 0.22).opacity(0.15))
        }
    }

    // MARK: - Shared Shape Helpers

    private func drawSineHills(_ ctx: inout GraphicsContext, w: CGFloat, baseY: CGFloat,
                                amplitude: CGFloat, freq: CGFloat, phase: CGFloat, color: Color) {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: baseY + amplitude))
        for x in stride(from: CGFloat(0), through: w, by: px) {
            let y = baseY + amplitude - (sin(x / w * .pi * freq + phase) * 0.5 + 0.5) * amplitude
            let snapped = (y / px).rounded() * px
            path.addLine(to: CGPoint(x: x, y: snapped))
        }
        path.addLine(to: CGPoint(x: w, y: baseY + amplitude))
        path.closeSubpath()
        ctx.fill(path, with: .color(color))
    }

    private func drawPixelTreeSilhouette(_ ctx: inout GraphicsContext, x: CGFloat, baseY: CGFloat, color: Color) {
        // Simple tree silhouette (trunk + round canopy)
        for i in 0..<5 { pixel(&ctx, x: x, y: baseY + CGFloat(i) * px, color) }
        for dy in -3..<1 {
            let spread = dy < -1 ? 2 : 3
            for dx in -spread...spread {
                pixel(&ctx, x: x + CGFloat(dx) * px, y: baseY + CGFloat(dy) * px, color)
            }
        }
    }

    private func drawPixelPine(_ ctx: inout GraphicsContext, x: CGFloat, baseY: CGFloat,
                                height: Int, dark: Color, light: Color) {
        let trunkH = 3
        // Trunk
        for i in 0..<trunkH {
            pixel(&ctx, x: x, y: baseY - CGFloat(i) * px, Color(red: 0.35, green: 0.25, blue: 0.15))
        }
        // Triangle canopy
        let canopyH = height - trunkH
        for row in 0..<canopyH {
            let spread = row / 2 + 1
            let y = baseY - CGFloat(trunkH + canopyH - row) * px
            for dx in -spread...spread {
                let c = dx <= 0 ? light : dark
                pixel(&ctx, x: x + CGFloat(dx) * px, y: y, c)
            }
        }
    }

    // MARK: - LAGOON — tropical beach, turquoise water, palm trees, pirate ship on horizon

    private func drawLagoon(ctx: inout GraphicsContext, w: CGFloat, h: CGFloat) {
        skyGradient(&ctx, w: w, h: h)

        // Hero pirate ship composition with islands and surf
        let waterTop = h * 0.42
        let waterH = h * 0.34
        let waterDeep = Color(red: 0.12, green: 0.50, blue: 0.65)
        let waterMid = Color(red: 0.18, green: 0.62, blue: 0.75)
        let waterShallow = Color(red: 0.35, green: 0.78, blue: 0.85)
        fill(&ctx, x: 0, y: waterTop, w: w, h: waterH * 0.3, waterDeep)
        fill(&ctx, x: 0, y: waterTop + waterH * 0.3, w: w, h: waterH * 0.4, waterMid)
        fill(&ctx, x: 0, y: waterTop + waterH * 0.7, w: w, h: waterH * 0.3, waterShallow)

        // Island silhouettes
        let island = Color(red: 0.30, green: 0.42, blue: 0.26)
        drawSineHills(&ctx, w: w, baseY: h * 0.55, amplitude: h * 0.05, freq: 2.6, phase: 0.9, color: island.opacity(0.65))

        // Pirate ship
        let shipX = w * 0.56
        let shipY = waterTop + px * 3
        let hull = Color(red: 0.24, green: 0.14, blue: 0.08)
        let sail = Color(red: 0.88, green: 0.84, blue: 0.74)
        fill(&ctx, x: shipX, y: shipY, w: px * 10, h: px * 2, hull)
        fill(&ctx, x: shipX + px, y: shipY - px, w: px * 8, h: px, hull.opacity(0.8))
        for mast in [1, 4, 7] {
            fill(&ctx, x: shipX + px * CGFloat(mast), y: shipY - px * 6, w: px * 0.6, h: px * 6, hull)
        }
        fill(&ctx, x: shipX + px * 2, y: shipY - px * 5, w: px * 2, h: px * 3, sail)
        fill(&ctx, x: shipX + px * 5, y: shipY - px * 5, w: px * 2, h: px * 4, sail)
        fill(&ctx, x: shipX + px * 8, y: shipY - px * 4, w: px * 1.5, h: px * 2.5, sail)
        pixel(&ctx, x: shipX + px * 5.5, y: shipY - px * 3.5, Color.black.opacity(0.6))

        // Sandbar and palms
        let sand = Color(red: 0.90, green: 0.82, blue: 0.60)
        let sandDark = Color(red: 0.80, green: 0.72, blue: 0.50)
        drawSineHills(&ctx, w: w, baseY: h * 0.72, amplitude: h * 0.08, freq: 1.5, phase: 0.3, color: sandDark.opacity(0.7))
        let palmTrunk = Color(red: 0.45, green: 0.30, blue: 0.15)
        let palmLeaf = Color(red: 0.22, green: 0.55, blue: 0.25)
        let palmLeafL = Color(red: 0.30, green: 0.65, blue: 0.32)
        let p1x = w * 0.16
        for i in 0..<7 {
            let sway = sin(CGFloat(i) * 0.3) * px
            pixel(&ctx, x: p1x + sway, y: h * 0.78 - CGFloat(i) * px * 1.5, palmTrunk)
        }
        pixel(&ctx, x: p1x - px * 3, y: h * 0.78 - 11 * px, palmLeaf)
        pixel(&ctx, x: p1x - px * 2, y: h * 0.78 - 12 * px, palmLeaf)
        pixel(&ctx, x: p1x - px, y: h * 0.78 - 12 * px, palmLeafL)
        pixel(&ctx, x: p1x, y: h * 0.78 - 12 * px, palmLeafL)
        pixel(&ctx, x: p1x + px, y: h * 0.78 - 12 * px, palmLeaf)
        pixel(&ctx, x: p1x + px * 2, y: h * 0.78 - 11 * px, palmLeaf)
        // Coconuts
        pixel(&ctx, x: p1x - px, y: h * 0.78 - 10.5 * px, Color(red: 0.50, green: 0.35, blue: 0.18))

        let p2x = w * 0.86
        for i in 0..<5 {
            pixel(&ctx, x: p2x, y: h * 0.78 - CGFloat(i) * px * 1.5, palmTrunk)
        }
        pixel(&ctx, x: p2x - px * 2, y: h * 0.78 - 8 * px, palmLeaf)
        pixel(&ctx, x: p2x - px, y: h * 0.78 - 9 * px, palmLeafL)
        pixel(&ctx, x: p2x, y: h * 0.78 - 9 * px, palmLeafL)
        pixel(&ctx, x: p2x + px, y: h * 0.78 - 8 * px, palmLeaf)

        // Sandy ground
        fill(&ctx, x: 0, y: h * 0.78, w: w, h: h * 0.22, sand)
        // Foam line at water edge
        fill(&ctx, x: 0, y: h * 0.78 - px, w: w, h: px, .white.opacity(0.4))
        pixel(&ctx, x: w * 0.75, y: h * 0.88, Color(red: 0.85, green: 0.55, blue: 0.30).opacity(0.6))
    }

    // MARK: - LOS ANGELES — palm boulevard, Hollywood hills, sunset haze, city glow

    private func drawLosAngeles(ctx: inout GraphicsContext, w: CGFloat, h: CGFloat) {
        skyGradient(&ctx, w: w, h: h)

        let sunHaze = Color(red: 1.0, green: 0.75, blue: 0.35)
        fill(&ctx, x: 0, y: h * 0.35, w: w, h: h * 0.12, sunHaze.opacity(0.15))

        let hillDark = Color(red: 0.30, green: 0.20, blue: 0.15)
        let hillMid = Color(red: 0.42, green: 0.30, blue: 0.22)
        drawSineHills(&ctx, w: w, baseY: h * 0.48, amplitude: h * 0.15, freq: 2.0, phase: 0.5, color: hillDark.opacity(0.6))
        drawSineHills(&ctx, w: w, baseY: h * 0.55, amplitude: h * 0.10, freq: 3.0, phase: 1.8, color: hillMid.opacity(0.5))

        let signY = h * 0.40
        let signX = w * 0.35
        let signColor = Color.white.opacity(0.45)
        for i in 0..<9 {
            pixel(&ctx, x: signX + CGFloat(i) * px * 1.5, y: signY, signColor)
            pixel(&ctx, x: signX + CGFloat(i) * px * 1.5, y: signY + px, signColor)
        }

        let palmTrunk = Color(red: 0.35, green: 0.22, blue: 0.12)
        let palmLeaf = Color(red: 0.20, green: 0.42, blue: 0.18)
        let palmLeafL = Color(red: 0.28, green: 0.52, blue: 0.25)

        for (px2, pHeight) in [(w * 0.12, 10), (w * 0.35, 8), (w * 0.58, 11), (w * 0.82, 9)] as [(CGFloat, Int)] {
            for i in 0..<pHeight {
                pixel(&ctx, x: px2, y: h * 0.78 - CGFloat(i) * px * 1.3, palmTrunk)
            }
            let topY = h * 0.78 - CGFloat(pHeight) * px * 1.3
            pixel(&ctx, x: px2 - px * 2, y: topY, palmLeaf)
            pixel(&ctx, x: px2 - px, y: topY - px, palmLeafL)
            pixel(&ctx, x: px2, y: topY - px, palmLeafL)
            pixel(&ctx, x: px2 + px, y: topY - px, palmLeaf)
            pixel(&ctx, x: px2 + px * 2, y: topY, palmLeaf)
        }

        // Motel strip + observatory dome read
        let bldg = Color(red: 0.55, green: 0.48, blue: 0.42)
        let bldgDark = Color(red: 0.40, green: 0.35, blue: 0.30)
        let window = Color(red: 1.0, green: 0.88, blue: 0.55).opacity(0.4)
        let buildings: [(x: CGFloat, bw: CGFloat, bh: CGFloat)] = [
            (0.02, 0.08, 0.12), (0.15, 0.06, 0.08), (0.42, 0.10, 0.15),
            (0.65, 0.07, 0.10), (0.88, 0.10, 0.14),
        ]
        for b in buildings {
            let bx = b.x * w
            let bW = b.bw * w
            let bH = b.bh * h
            fill(&ctx, x: bx, y: h * 0.78 - bH, w: bW, h: bH, bldg)
            fill(&ctx, x: bx, y: h * 0.78 - bH, w: bW, h: px, bldgDark)
            // Windows
            var wy = h * 0.78 - bH + px * 2
            while wy < h * 0.76 {
                var wx = bx + px
                while wx < bx + bW - px {
                    pixel(&ctx, x: wx, y: wy, window)
                    wx += px * 3
                }
                wy += px * 3
            }
        }
        // Observatory dome
        fill(&ctx, x: w * 0.28, y: h * 0.56, w: px * 6, h: px * 2, bldgDark)
        fill(&ctx, x: w * 0.30, y: h * 0.54, w: px * 2, h: px * 2, sunHaze.opacity(0.35))
        // Boardwalk rail
        fill(&ctx, x: 0, y: h * 0.74, w: w, h: px * 0.8, Color(red: 0.35, green: 0.24, blue: 0.16).opacity(0.6))

        // Road / ground
        fill(&ctx, x: 0, y: h * 0.78, w: w, h: h * 0.22, theme.previewGroundColor)
        // Road lane dashes
        for i in 0..<Int(w / (px * 8)) {
            fill(&ctx, x: CGFloat(i) * px * 8, y: h * 0.88, w: px * 4, h: px, Color(red: 0.85, green: 0.75, blue: 0.45).opacity(0.3))
        }
    }

    // MARK: - LONDON — Big Ben, grey sky, rain, double-decker bus, River Thames hint

    private func drawLondon(ctx: inout GraphicsContext, w: CGFloat, h: CGFloat) {
        skyGradient(&ctx, w: w, h: h)

        let rain = Color(red: 0.60, green: 0.65, blue: 0.70).opacity(0.2)
        for i in 0..<12 {
            let rx = prng(19, i * 2) * w
            let ry = prng(19, i * 2 + 1) * h * 0.7
            fill(&ctx, x: rx, y: ry, w: px * 0.5, h: px * 3, rain)
        }

        let river = Color(red: 0.30, green: 0.38, blue: 0.45)
        fill(&ctx, x: 0, y: h * 0.62, w: w, h: h * 0.08, river)
        for i in 0..<4 {
            let rx = prng(23, i) * w
            fill(&ctx, x: rx, y: h * 0.64, w: px * 3, h: px, Color(red: 0.40, green: 0.48, blue: 0.55).opacity(0.3))
        }

        let brickDark = Color(red: 0.32, green: 0.28, blue: 0.24)
        let brickMid = Color(red: 0.42, green: 0.38, blue: 0.32)
        let clockGold = Color(red: 1.0, green: 0.88, blue: 0.50)
        let benX = w * 0.20
        fill(&ctx, x: benX, y: h * 0.18, w: px * 4, h: h * 0.42, brickDark)
        fill(&ctx, x: benX + px, y: h * 0.18, w: px * 2, h: h * 0.42, brickMid)
        fill(&ctx, x: benX + px, y: h * 0.08, w: px * 2, h: h * 0.10, brickDark)
        pixel(&ctx, x: benX + px * 1.5, y: h * 0.05, clockGold)
        fill(&ctx, x: benX + px, y: h * 0.22, w: px * 2, h: px * 2, clockGold)

        fill(&ctx, x: benX + px * 5, y: h * 0.38, w: px * 12, h: h * 0.22, brickDark)
        fill(&ctx, x: benX + px * 5, y: h * 0.38, w: px * 12, h: px, brickMid)
        var pwx = benX + px * 6
        while pwx < benX + px * 16 {
            pixel(&ctx, x: pwx, y: h * 0.42, Color(red: 0.80, green: 0.75, blue: 0.55).opacity(0.4))
            pixel(&ctx, x: pwx, y: h * 0.48, Color(red: 0.80, green: 0.75, blue: 0.55).opacity(0.3))
            pwx += px * 3
        }

        // Bridge towers / eye silhouette
        let eyeX = w * 0.68
        let eyeY = h * 0.34
        let eyeR: CGFloat = 7
        let metal = Color(red: 0.52, green: 0.55, blue: 0.58)
        for angle in stride(from: 0.0, to: Double.pi * 2, by: 0.3) {
            let dx = cos(angle) * Double(eyeR)
            let dy = sin(angle) * Double(eyeR)
            pixel(&ctx, x: eyeX + CGFloat(dx) * px, y: eyeY + CGFloat(dy) * px, metal)
        }
        fill(&ctx, x: eyeX - px * 0.5, y: eyeY, w: px, h: h * 0.60 - eyeY, metal.opacity(0.6))
        for angle in stride(from: 0.0, to: Double.pi * 2, by: Double.pi / 4) {
            let dx = cos(angle) * Double(eyeR)
            let dy = sin(angle) * Double(eyeR)
            pixel(&ctx, x: eyeX + CGFloat(dx) * px, y: eyeY + CGFloat(dy) * px, .white.opacity(0.5))
        }
        fill(&ctx, x: w * 0.52, y: h * 0.46, w: px * 3, h: h * 0.14, brickDark)
        fill(&ctx, x: w * 0.58, y: h * 0.46, w: px * 3, h: h * 0.14, brickDark)
        fill(&ctx, x: w * 0.52, y: h * 0.52, w: px * 9, h: px, metal.opacity(0.6))

        let busX = w * 0.78
        let busY = h * 0.72
        let busRed = Color(red: 0.80, green: 0.15, blue: 0.12)
        let busRedDark = Color(red: 0.60, green: 0.10, blue: 0.08)
        fill(&ctx, x: busX, y: busY - px * 4, w: px * 6, h: px * 4, busRed)
        fill(&ctx, x: busX, y: busY - px * 7, w: px * 6, h: px * 3, busRedDark)
        fill(&ctx, x: busX + px, y: busY - px * 6, w: px * 4, h: px, Color(red: 0.65, green: 0.72, blue: 0.80).opacity(0.5))
        fill(&ctx, x: busX + px, y: busY - px * 3, w: px * 4, h: px, Color(red: 0.65, green: 0.72, blue: 0.80).opacity(0.5))
        pixel(&ctx, x: busX + px, y: busY, Color(red: 0.15, green: 0.15, blue: 0.15))
        pixel(&ctx, x: busX + px * 4, y: busY, Color(red: 0.15, green: 0.15, blue: 0.15))
        fill(&ctx, x: w * 0.10, y: h * 0.70, w: w * 0.80, h: px * 0.8, metal.opacity(0.45))

        // Ground — wet cobblestone
        fill(&ctx, x: 0, y: h * 0.78, w: w, h: h * 0.22, theme.previewGroundColor)
        for i in 0..<3 {
            let pdx = prng(41, i) * w
            fill(&ctx, x: pdx, y: h * 0.82, w: px * 4, h: px, Color(red: 0.40, green: 0.45, blue: 0.55).opacity(0.25))
        }
    }

    private func drawRoughOcean(ctx: inout GraphicsContext, w: CGFloat, h: CGFloat) {
        skyGradient(&ctx, w: w, h: h)

        let cloud = Color(red: 0.04, green: 0.08, blue: 0.10).opacity(0.45)
        fill(&ctx, x: 0, y: h * 0.08, w: w, h: h * 0.10, cloud)
        fill(&ctx, x: w * 0.10, y: h * 0.18, w: w * 0.82, h: h * 0.06, cloud.opacity(0.65))

        let rain = Color(red: 0.72, green: 0.86, blue: 0.86).opacity(0.25)
        for i in 0..<9 {
            let x = prng(53, i) * w
            let y = h * (0.16 + prng(59, i) * 0.30)
            fill(&ctx, x: x, y: y, w: px, h: px * 8, rain)
        }

        let farSea = Color(red: 0.08, green: 0.25, blue: 0.29).opacity(0.86)
        let midSea = Color(red: 0.04, green: 0.32, blue: 0.38)
        let darkSea = Color(red: 0.02, green: 0.14, blue: 0.18)
        let foam = Color(red: 0.82, green: 0.95, blue: 0.91).opacity(0.78)

        fill(&ctx, x: 0, y: h * 0.56, w: w, h: h * 0.14, farSea)
        for i in 0..<8 {
            let x = CGFloat(i) * w / 7 - px * 4
            fill(&ctx, x: x, y: h * 0.54 + prng(61, i) * px * 4, w: px * 8, h: px * 2, foam.opacity(0.42))
        }

        fill(&ctx, x: 0, y: h * 0.66, w: w, h: h * 0.17, midSea)
        for i in 0..<6 {
            let crestX = CGFloat(i) * w / 5 - px * 2
            fill(&ctx, x: crestX, y: h * 0.64 + prng(67, i) * px * 3, w: px * 10, h: px * 2, foam)
        }

        fill(&ctx, x: 0, y: h * 0.80, w: w, h: h * 0.20, darkSea)
        for i in 0..<10 {
            let x = prng(71, i) * w
            fill(&ctx, x: x, y: h * (0.82 + prng(73, i) * 0.12), w: px * CGFloat(2 + i % 4), h: px, foam.opacity(0.70))
        }
    }
}
