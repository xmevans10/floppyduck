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

    // MARK: - DAY — blue sky, fluffy cloud, rolling green hills, pixel tree

    private func drawDay(ctx: inout GraphicsContext, w: CGFloat, h: CGFloat) {
        skyGradient(&ctx, w: w, h: h)

        // Fluffy cloud
        let cloudY = h * 0.18
        let cloudX = w * 0.55
        for (dx, dy, cw, ch) in [
            (0.0, 2.0, 12.0, 4.0), (-4.0, 0.0, 8.0, 6.0), (4.0, 0.0, 10.0, 6.0),
            (-2.0, -2.0, 14.0, 4.0),
        ] as [(CGFloat, CGFloat, CGFloat, CGFloat)] {
            fill(&ctx, x: cloudX + dx * px, y: cloudY + dy * px, w: cw * px, h: ch * px, .white.opacity(0.85))
        }

        // Rolling hills (two layers)
        let hillColor1 = Color(red: 0.30, green: 0.55, blue: 0.22)
        let hillColor2 = Color(red: 0.25, green: 0.48, blue: 0.18)
        drawSineHills(&ctx, w: w, baseY: h * 0.55, amplitude: h * 0.15, freq: 1.5, phase: 0, color: hillColor1)
        drawSineHills(&ctx, w: w, baseY: h * 0.62, amplitude: h * 0.12, freq: 2.2, phase: 1.5, color: hillColor2)

        // Pixel tree on hill
        let treeX = w * 0.3
        let treeBase = h * 0.52
        let trunk = Color(red: 0.40, green: 0.28, blue: 0.15)
        let leaves = Color(red: 0.22, green: 0.50, blue: 0.18)
        let leavesBright = Color(red: 0.32, green: 0.60, blue: 0.25)
        // Trunk
        for i in 0..<5 { pixel(&ctx, x: treeX, y: treeBase + CGFloat(i) * px, trunk) }
        for i in 0..<5 { pixel(&ctx, x: treeX + px, y: treeBase + CGFloat(i) * px, trunk) }
        // Canopy
        for dy in 0..<4 {
            let span = dy < 2 ? 4 : 3
            let offset = dy < 2 ? -3 : -2
            for dx in 0..<span {
                let c = (dx + dy) % 2 == 0 ? leaves : leavesBright
                pixel(&ctx, x: treeX + CGFloat(offset + dx) * px, y: treeBase - CGFloat(4 - dy) * px, c)
            }
        }

        // Ground
        let groundH = h * 0.2
        fill(&ctx, x: 0, y: h - groundH, w: w, h: 2, Color(red: 0.30, green: 0.50, blue: 0.20))
        fill(&ctx, x: 0, y: h - groundH + 2, w: w, h: groundH, theme.previewGroundColor)

        // Grass tufts
        let grassDark = Color(red: 0.28, green: 0.50, blue: 0.18)
        let grassLight = Color(red: 0.40, green: 0.62, blue: 0.28)
        for i in 0..<Int(w / (px * 6)) {
            let gx = CGFloat(i) * px * 6 + prng(42, i) * px * 3
            pixel(&ctx, x: gx, y: h - groundH - px, i % 2 == 0 ? grassDark : grassLight)
        }
    }

    // MARK: - SUNSET — warm sky, large sun disc, amber hills, tree silhouettes

    private func drawSunset(ctx: inout GraphicsContext, w: CGFloat, h: CGFloat) {
        skyGradient(&ctx, w: w, h: h)

        // Sun disc near horizon
        let sunX = w * 0.7
        let sunY = h * 0.42
        let sunR: CGFloat = 10
        let sunColor = Color(red: 1.0, green: 0.85, blue: 0.30)
        let sunGlow = Color(red: 1.0, green: 0.60, blue: 0.15)
        for dy in -Int(sunR)...Int(sunR) {
            for dx in -Int(sunR)...Int(sunR) {
                let dist = sqrt(CGFloat(dx * dx + dy * dy))
                if dist <= sunR {
                    let c = dist < sunR * 0.7 ? sunColor : sunGlow
                    pixel(&ctx, x: sunX + CGFloat(dx) * px, y: sunY + CGFloat(dy) * px, c)
                }
            }
        }

        // Hills with warm amber tones
        let hillColor1 = Color(red: 0.45, green: 0.30, blue: 0.15).opacity(0.9)
        let hillColor2 = Color(red: 0.35, green: 0.22, blue: 0.12)
        drawSineHills(&ctx, w: w, baseY: h * 0.58, amplitude: h * 0.14, freq: 1.8, phase: 0.5, color: hillColor1)

        // Tree silhouettes on hills
        let silhouette = Color(red: 0.18, green: 0.12, blue: 0.06)
        drawPixelTreeSilhouette(&ctx, x: w * 0.2, baseY: h * 0.50, color: silhouette)
        drawPixelTreeSilhouette(&ctx, x: w * 0.75, baseY: h * 0.52, color: silhouette)

        drawSineHills(&ctx, w: w, baseY: h * 0.66, amplitude: h * 0.10, freq: 2.5, phase: 2.0, color: hillColor2)

        // Ground
        fill(&ctx, x: 0, y: h * 0.8, w: w, h: h * 0.2, theme.previewGroundColor)
    }

    // MARK: - NIGHT — dark sky with stars, crescent moon, dark silhouette hills

    private func drawNight(ctx: inout GraphicsContext, w: CGFloat, h: CGFloat) {
        skyGradient(&ctx, w: w, h: h)

        // Stars
        for i in 0..<18 {
            let sx = prng(77, i * 2) * w
            let sy = prng(77, i * 2 + 1) * h * 0.6
            let brightness = 0.4 + prng(77, i * 3) * 0.6
            pixel(&ctx, x: sx, y: sy, .white.opacity(brightness))
        }

        // Crescent moon
        let moonX = w * 0.75
        let moonY = h * 0.15
        let moonColor = Color(red: 0.90, green: 0.88, blue: 0.70)
        for dy in -4...4 {
            for dx in -4...4 {
                let dist = sqrt(CGFloat(dx * dx + dy * dy))
                let cutDist = sqrt(CGFloat((dx - 2) * (dx - 2) + dy * dy))
                if dist <= 4 && cutDist > 3.5 {
                    pixel(&ctx, x: moonX + CGFloat(dx) * px, y: moonY + CGFloat(dy) * px, moonColor)
                }
            }
        }

        // Dark silhouette hills
        drawSineHills(&ctx, w: w, baseY: h * 0.6, amplitude: h * 0.12, freq: 2.0, phase: 0.8,
                      color: Color(red: 0.05, green: 0.12, blue: 0.06))
        drawSineHills(&ctx, w: w, baseY: h * 0.68, amplitude: h * 0.08, freq: 3.0, phase: 2.3,
                      color: Color(red: 0.04, green: 0.10, blue: 0.05))

        // Ground
        fill(&ctx, x: 0, y: h * 0.82, w: w, h: h * 0.18, theme.previewGroundColor)
    }

    // MARK: - NEON CITY — skyline with glowing windows, neon road

    private func drawNeonCity(ctx: inout GraphicsContext, w: CGFloat, h: CGFloat) {
        skyGradient(&ctx, w: w, h: h)

        // Stars
        for i in 0..<8 {
            let sx = prng(11, i * 2) * w
            let sy = prng(11, i * 2 + 1) * h * 0.3
            pixel(&ctx, x: sx, y: sy, .white.opacity(0.3))
        }

        // City skyline — buildings with glowing windows
        let wallDark = Color(red: 0.08, green: 0.04, blue: 0.16)
        let windowColors: [Color] = [
            Color(red: 1.0, green: 0.9, blue: 0.4),
            Color(red: 0.3, green: 0.9, blue: 1.0),
            Color(red: 1.0, green: 0.35, blue: 0.7),
            wallDark.opacity(0.7),
        ]
        let buildings: [(x: CGFloat, bw: CGFloat, bh: CGFloat)] = [
            (0.02, 0.10, 0.40), (0.14, 0.08, 0.30), (0.24, 0.12, 0.55),
            (0.38, 0.07, 0.25), (0.47, 0.10, 0.45), (0.59, 0.09, 0.38),
            (0.70, 0.11, 0.52), (0.83, 0.07, 0.28), (0.92, 0.08, 0.35),
        ]
        for (i, b) in buildings.enumerated() {
            let bx = b.x * w
            let bW = b.bw * w
            let bH = b.bh * h
            let bTop = h * 0.78 - bH
            // Building body
            fill(&ctx, x: bx, y: bTop, w: bW, h: bH, wallDark)
            // Roof line
            fill(&ctx, x: bx, y: bTop, w: bW, h: px, Color(red: 0.06, green: 0.02, blue: 0.12))
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
                fill(&ctx, x: aX, y: bTop - px * 3, w: px, h: px * 3, wallDark)
                pixel(&ctx, x: aX, y: bTop - px * 4, Color(red: 1.0, green: 0.2, blue: 0.4))
            }
        }

        // Road/ground with neon glow
        let roadY = h * 0.78
        fill(&ctx, x: 0, y: roadY, w: w, h: h * 0.22, Color(red: 0.06, green: 0.04, blue: 0.10))
        // Road dashes
        for i in 0..<Int(w / (px * 8)) {
            let dx = CGFloat(i) * px * 8
            fill(&ctx, x: dx, y: roadY + h * 0.10, w: px * 4, h: px, Color(red: 0.3, green: 0.3, blue: 0.4))
        }
        // Neon reflection
        for i in 0..<Int(w / (px * 12)) {
            let rx = CGFloat(i) * px * 12 + px * 3
            let c: Color = i % 2 == 0 ? Color(red: 0.8, green: 0.2, blue: 0.6).opacity(0.3) : Color(red: 0.2, green: 0.8, blue: 1.0).opacity(0.3)
            fill(&ctx, x: rx, y: roadY + px * 2, w: px * 2, h: px, c)
        }
    }

    // MARK: - PIXEL TOKYO — buildings with signs, torii gate hint, cherry blossoms

    private func drawPixelTokyo(ctx: inout GraphicsContext, w: CGFloat, h: CGFloat) {
        skyGradient(&ctx, w: w, h: h)

        // Stars
        for i in 0..<6 {
            let sx = prng(33, i * 2) * w
            let sy = prng(33, i * 2 + 1) * h * 0.25
            pixel(&ctx, x: sx, y: sy, .white.opacity(0.25))
        }

        // Buildings with Japanese elements
        let wall = Color(red: 0.15, green: 0.10, blue: 0.25)
        let wallLit = Color(red: 0.22, green: 0.14, blue: 0.32)
        let neonPink = Color(red: 1.0, green: 0.3, blue: 0.5)
        let neonCyan = Color(red: 0.3, green: 0.9, blue: 1.0)
        let signRed = Color(red: 0.9, green: 0.15, blue: 0.2)
        let lanternGold = Color(red: 1.0, green: 0.8, blue: 0.3)

        let buildings: [(x: CGFloat, bw: CGFloat, bh: CGFloat)] = [
            (0.0, 0.12, 0.35), (0.14, 0.09, 0.50), (0.25, 0.13, 0.42),
            (0.40, 0.10, 0.58), (0.52, 0.08, 0.30), (0.62, 0.12, 0.48),
            (0.76, 0.10, 0.38), (0.88, 0.12, 0.55),
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
            // Neon sign
            if i % 2 == 0 {
                let signW = min(bW * 0.6, px * 4)
                fill(&ctx, x: bx + px, y: bTop + px * 2, w: signW, h: px * 3, i % 4 == 0 ? signRed : neonPink)
            }
            // Windows
            let winY = bTop + px * 6
            if winY < h * 0.76 {
                var wx = bx + px
                while wx < bx + bW - px * 2 {
                    let c: Color = (Int(wx / px) + i) % 3 == 0 ? neonCyan.opacity(0.6) : lanternGold.opacity(0.5)
                    pixel(&ctx, x: wx, y: winY, c)
                    wx += px * 3
                }
            }
        }

        // Cherry blossom petals floating
        let petal = Color(red: 1.0, green: 0.70, blue: 0.80)
        let petalLight = Color(red: 1.0, green: 0.85, blue: 0.90)
        for i in 0..<8 {
            let px2 = prng(55, i * 2) * w
            let py = prng(55, i * 2 + 1) * h * 0.7
            pixel(&ctx, x: px2, y: py, i % 2 == 0 ? petal : petalLight)
        }

        // Ground — sidewalk
        fill(&ctx, x: 0, y: h * 0.78, w: w, h: h * 0.22, theme.previewGroundColor)
    }

    // MARK: - UNDERWATER — ocean gradient, coral reef, kelp, bubbles, fish

    private func drawUnderwater(ctx: inout GraphicsContext, w: CGFloat, h: CGFloat) {
        skyGradient(&ctx, w: w, h: h)

        // Light rays from above
        let rayColor = Color(red: 0.3, green: 0.7, blue: 0.8).opacity(0.08)
        for i in 0..<3 {
            let rx = w * (0.2 + CGFloat(i) * 0.3)
            fill(&ctx, x: rx, y: 0, w: px * 3, h: h * 0.6, rayColor)
            fill(&ctx, x: rx + px, y: 0, w: px * 2, h: h * 0.5, rayColor)
        }

        // Coral reef mounds
        let coralPink = Color(red: 0.88, green: 0.35, blue: 0.55)
        let coralOrange = Color(red: 0.92, green: 0.55, blue: 0.25)
        let coralPurple = Color(red: 0.55, green: 0.25, blue: 0.70)
        let reefBase = Color(red: 0.15, green: 0.30, blue: 0.45)

        // Coral formations
        let corals: [(x: CGFloat, w: CGFloat, h: CGFloat, c: Color)] = [
            (0.05, 0.12, 0.25, coralPink), (0.22, 0.08, 0.18, coralOrange),
            (0.42, 0.10, 0.22, coralPurple), (0.60, 0.14, 0.28, coralPink),
            (0.80, 0.09, 0.20, coralOrange),
        ]
        for coral in corals {
            let cx = coral.x * w
            let cW = coral.w * w
            let cH = coral.h * h
            let cTop = h * 0.78 - cH
            // Rounded coral blob
            for dy in 0..<Int(cH / px) {
                let ratio = CGFloat(dy) / (cH / px)
                let rowW = cW * (1.0 - abs(ratio - 0.5) * 1.2)
                let rowX = cx + (cW - rowW) / 2
                fill(&ctx, x: rowX, y: cTop + CGFloat(dy) * px, w: rowW, h: px, coral.c.opacity(0.7))
            }
        }

        // Kelp
        let kelpGreen = Color(red: 0.15, green: 0.50, blue: 0.25)
        for kx in [w * 0.15, w * 0.55, w * 0.85] {
            for ky in 0..<8 {
                let sway = sin(CGFloat(ky) * 0.8) * px * 2
                pixel(&ctx, x: kx + sway, y: h * 0.78 - CGFloat(ky) * px * 2, kelpGreen.opacity(0.6))
            }
        }

        // Bubbles
        let bubbleColor = Color(red: 0.5, green: 0.8, blue: 0.9)
        for i in 0..<6 {
            let bx = prng(88, i * 2) * w
            let by = prng(88, i * 2 + 1) * h * 0.7
            let bs = prng(88, i * 3) > 0.5 ? px * 2 : px
            fill(&ctx, x: bx, y: by, w: bs, h: bs, bubbleColor.opacity(0.4))
        }

        // Small fish
        let fishColor = Color(red: 1.0, green: 0.65, blue: 0.20)
        let fishX = w * 0.65
        let fishY = h * 0.35
        pixel(&ctx, x: fishX, y: fishY, fishColor)
        pixel(&ctx, x: fishX + px, y: fishY, fishColor)
        pixel(&ctx, x: fishX + px * 2, y: fishY, fishColor)
        pixel(&ctx, x: fishX + px * 3, y: fishY - px, fishColor) // tail
        pixel(&ctx, x: fishX + px * 3, y: fishY + px, fishColor)
        pixel(&ctx, x: fishX, y: fishY - px, Color(red: 0.2, green: 0.2, blue: 0.3)) // eye

        // Sandy floor
        fill(&ctx, x: 0, y: h * 0.78, w: w, h: px, Color(red: 0.65, green: 0.58, blue: 0.40))
        fill(&ctx, x: 0, y: h * 0.78 + px, w: w, h: h * 0.22, theme.previewGroundColor)
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

    // MARK: - ARCTIC — pale sky, snow-capped peaks, ice, igloo hint

    private func drawArctic(ctx: inout GraphicsContext, w: CGFloat, h: CGFloat) {
        skyGradient(&ctx, w: w, h: h)

        // Wispy clouds
        for i in 0..<3 {
            let cx = w * (0.1 + CGFloat(i) * 0.35)
            let cy = h * 0.12 + CGFloat(i) * px * 3
            fill(&ctx, x: cx, y: cy, w: px * 8, h: px, .white.opacity(0.5))
            fill(&ctx, x: cx + px, y: cy + px, w: px * 6, h: px, .white.opacity(0.35))
        }

        // Snow-capped mountain peaks
        let rock = Color(red: 0.48, green: 0.55, blue: 0.65)
        let snow = Color(red: 0.95, green: 0.97, blue: 1.0)
        let snowMid = Color(red: 0.85, green: 0.90, blue: 0.95)

        let peaks: [(x: CGFloat, halfW: CGFloat, peakH: CGFloat)] = [
            (0.20, 0.12, 0.38), (0.45, 0.18, 0.50), (0.72, 0.14, 0.42),
        ]
        for peak in peaks {
            let cx = peak.x * w
            let pW = peak.halfW * w
            let pH = peak.peakH * h
            let pTop = h * 0.76 - pH
            for dy in 0..<Int(pH / px) {
                let ratio = CGFloat(dy) / (pH / px)
                let rowW = pW * 2 * ratio
                let rowX = cx - rowW / 2
                let c = ratio < 0.25 ? snow : (ratio < 0.4 ? snowMid : rock)
                fill(&ctx, x: rowX, y: pTop + CGFloat(dy) * px, w: rowW, h: px, c)
            }
        }

        // Igloo
        let iglooX = w * 0.82
        let iglooY = h * 0.70
        let iglooColor = Color(red: 0.88, green: 0.92, blue: 0.96)
        let iglooShadow = Color(red: 0.70, green: 0.78, blue: 0.85)
        // Dome
        for dy in 0..<4 {
            let dw = CGFloat(4 - abs(dy - 1)) * px
            let dx = iglooX + CGFloat(1 - min(dy, 1)) * px
            fill(&ctx, x: dx, y: iglooY - CGFloat(dy) * px, w: dw, h: px, dy < 2 ? iglooColor : iglooShadow)
        }
        // Door
        pixel(&ctx, x: iglooX + px * 2, y: iglooY, iglooShadow)

        // Snow ground
        fill(&ctx, x: 0, y: h * 0.76, w: w, h: h * 0.24, theme.previewGroundColor)
        // Snow sparkles
        for i in 0..<8 {
            let sx = prng(99, i) * w
            pixel(&ctx, x: sx, y: h * 0.78 + prng(99, i + 20) * h * 0.12, .white.opacity(0.6))
        }
    }

    // MARK: - WESTERN — dusty sky, mesa silhouettes, cactus, saloon

    private func drawWestern(ctx: inout GraphicsContext, w: CGFloat, h: CGFloat) {
        skyGradient(&ctx, w: w, h: h)

        // Distant mesa / butte silhouettes
        let mesa = Color(red: 0.50, green: 0.32, blue: 0.18)
        let mesaDark = Color(red: 0.38, green: 0.22, blue: 0.12)

        // Flat-topped mesa (left)
        let mesa1X = w * 0.08
        let mesa1W = px * 14
        let mesa1H = h * 0.30
        let mesa1Top = h * 0.45
        fill(&ctx, x: mesa1X, y: mesa1Top, w: mesa1W, h: mesa1H, mesa)
        fill(&ctx, x: mesa1X, y: mesa1Top, w: mesa1W, h: px, mesaDark)

        // Tall narrow butte (mid)
        let butte1X = w * 0.38
        let butte1W = px * 8
        let butte1Top = h * 0.32
        fill(&ctx, x: butte1X, y: butte1Top, w: butte1W, h: h * 0.44, mesaDark)
        fill(&ctx, x: butte1X - px, y: butte1Top, w: butte1W + px * 2, h: px, mesa)

        // Wide mesa (right)
        let mesa2X = w * 0.65
        fill(&ctx, x: mesa2X, y: h * 0.50, w: px * 18, h: h * 0.26, mesa)

        // Saguaro cactus
        let cactus = Color(red: 0.25, green: 0.42, blue: 0.20)
        let cactusLight = Color(red: 0.35, green: 0.52, blue: 0.28)
        let cacX = w * 0.55
        let cacBase = h * 0.76
        // Trunk
        for i in 0..<8 { pixel(&ctx, x: cacX, y: cacBase - CGFloat(i) * px, cactus) }
        // Left arm
        pixel(&ctx, x: cacX - px, y: cacBase - 4 * px, cactus)
        pixel(&ctx, x: cacX - px, y: cacBase - 5 * px, cactusLight)
        pixel(&ctx, x: cacX - px, y: cacBase - 6 * px, cactusLight)
        // Right arm
        pixel(&ctx, x: cacX + px, y: cacBase - 3 * px, cactus)
        pixel(&ctx, x: cacX + px, y: cacBase - 4 * px, cactusLight)

        // Small saloon silhouette
        let saloonX = w * 0.78
        let saloonBase = h * 0.76
        let wood = Color(red: 0.30, green: 0.20, blue: 0.12)
        let woodDark = Color(red: 0.20, green: 0.12, blue: 0.07)
        // Building body
        fill(&ctx, x: saloonX, y: saloonBase - px * 7, w: px * 8, h: px * 7, wood)
        // Roof / false front
        fill(&ctx, x: saloonX - px, y: saloonBase - px * 9, w: px * 10, h: px * 2, woodDark)
        // Door
        pixel(&ctx, x: saloonX + px * 3, y: saloonBase - px, woodDark)
        pixel(&ctx, x: saloonX + px * 4, y: saloonBase - px, woodDark)
        pixel(&ctx, x: saloonX + px * 3, y: saloonBase - px * 2, woodDark)
        pixel(&ctx, x: saloonX + px * 4, y: saloonBase - px * 2, woodDark)
        // Windows
        pixel(&ctx, x: saloonX + px, y: saloonBase - px * 5, Color(red: 1.0, green: 0.85, blue: 0.4).opacity(0.7))
        pixel(&ctx, x: saloonX + px * 6, y: saloonBase - px * 5, Color(red: 1.0, green: 0.85, blue: 0.4).opacity(0.7))

        // Barrel cactus (small)
        let bc = w * 0.28
        pixel(&ctx, x: bc, y: cacBase - px, cactus)
        pixel(&ctx, x: bc + px, y: cacBase - px, cactus)
        pixel(&ctx, x: bc, y: cacBase - px * 2, cactusLight)
        pixel(&ctx, x: bc + px, y: cacBase - px * 2, cactusLight)

        // Desert ground
        fill(&ctx, x: 0, y: h * 0.76, w: w, h: h * 0.24, theme.previewGroundColor)
        // Cracks
        let crack = Color(red: 0.55, green: 0.42, blue: 0.25)
        fill(&ctx, x: w * 0.2, y: h * 0.82, w: px * 4, h: px, crack)
        fill(&ctx, x: w * 0.6, y: h * 0.85, w: px * 3, h: px, crack)
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

    // MARK: - EGYPT — golden sky, pyramids, sand dunes, obelisk

    private func drawEgypt(ctx: inout GraphicsContext, w: CGFloat, h: CGFloat) {
        skyGradient(&ctx, w: w, h: h)

        // Sun
        let sunColor = Color(red: 1.0, green: 0.88, blue: 0.40)
        let sunX = w * 0.8
        let sunY = h * 0.20
        for dy in -3...3 {
            for dx in -3...3 {
                if dx * dx + dy * dy <= 9 {
                    pixel(&ctx, x: sunX + CGFloat(dx) * px, y: sunY + CGFloat(dy) * px, sunColor.opacity(0.8))
                }
            }
        }

        // Sand dunes (gentle waves)
        let sand = Color(red: 0.78, green: 0.62, blue: 0.35)
        drawSineHills(&ctx, w: w, baseY: h * 0.72, amplitude: h * 0.06, freq: 2.5, phase: 0, color: sand.opacity(0.5))

        // Large pyramid (left-center)
        let pyrLit = Color(red: 0.82, green: 0.65, blue: 0.30)
        let pyrShadow = Color(red: 0.45, green: 0.32, blue: 0.14)
        let pyrCap = Color(red: 0.95, green: 0.82, blue: 0.30)
        let pyr1X = w * 0.30
        let pyr1W: CGFloat = px * 22
        let pyr1H: CGFloat = h * 0.38
        let pyr1Top = h * 0.72 - pyr1H
        for dy in 0..<Int(pyr1H / px) {
            let ratio = CGFloat(dy) / (pyr1H / px)
            let rowW = pyr1W * ratio
            let rowX = pyr1X - rowW / 2
            // Left face lit, right face shadow
            let halfW = rowW / 2
            if halfW > 0 {
                fill(&ctx, x: rowX, y: pyr1Top + CGFloat(dy) * px, w: halfW, h: px, pyrLit)
                fill(&ctx, x: rowX + halfW, y: pyr1Top + CGFloat(dy) * px, w: halfW, h: px, pyrShadow)
            }
        }
        // Capstone
        pixel(&ctx, x: pyr1X - px / 2, y: pyr1Top, pyrCap)

        // Smaller pyramid (right)
        let pyr2X = w * 0.55
        let pyr2W: CGFloat = px * 14
        let pyr2H: CGFloat = h * 0.26
        let pyr2Top = h * 0.72 - pyr2H
        for dy in 0..<Int(pyr2H / px) {
            let ratio = CGFloat(dy) / (pyr2H / px)
            let rowW = pyr2W * ratio
            let rowX = pyr2X - rowW / 2
            let halfW = rowW / 2
            if halfW > 0 {
                fill(&ctx, x: rowX, y: pyr2Top + CGFloat(dy) * px, w: halfW, h: px, pyrLit.opacity(0.85))
                fill(&ctx, x: rowX + halfW, y: pyr2Top + CGFloat(dy) * px, w: halfW, h: px, pyrShadow.opacity(0.85))
            }
        }

        // Obelisk
        let obX = w * 0.82
        let obBase = h * 0.72
        let obColor = Color(red: 0.65, green: 0.50, blue: 0.28)
        fill(&ctx, x: obX, y: obBase - px * 10, w: px * 2, h: px * 10, obColor)
        pixel(&ctx, x: obX, y: obBase - px * 11, obColor)
        pixel(&ctx, x: obX + px, y: obBase - px * 11, obColor)
        pixel(&ctx, x: obX + px / 2, y: obBase - px * 12, pyrCap) // golden tip

        // Palm tree
        let palmX = w * 0.12
        let palmBase = h * 0.72
        let palmTrunk = Color(red: 0.45, green: 0.30, blue: 0.15)
        let palmLeaf = Color(red: 0.30, green: 0.50, blue: 0.18)
        for i in 0..<6 { pixel(&ctx, x: palmX, y: palmBase - CGFloat(i) * px, palmTrunk) }
        // Fronds
        pixel(&ctx, x: palmX - px * 2, y: palmBase - 6 * px, palmLeaf)
        pixel(&ctx, x: palmX - px, y: palmBase - 7 * px, palmLeaf)
        pixel(&ctx, x: palmX, y: palmBase - 7 * px, palmLeaf)
        pixel(&ctx, x: palmX + px, y: palmBase - 7 * px, palmLeaf)
        pixel(&ctx, x: palmX + px * 2, y: palmBase - 6 * px, palmLeaf)
        pixel(&ctx, x: palmX - px * 3, y: palmBase - 5 * px, palmLeaf.opacity(0.7))
        pixel(&ctx, x: palmX + px * 3, y: palmBase - 5 * px, palmLeaf.opacity(0.7))

        // Sand ground
        fill(&ctx, x: 0, y: h * 0.72, w: w, h: h * 0.28, theme.previewGroundColor)
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

    // MARK: - MOUNTAIN — snow peaks, pine silhouettes, meadow floor, eagle

    private func drawMountain(ctx: inout GraphicsContext, w: CGFloat, h: CGFloat) {
        skyGradient(&ctx, w: w, h: h)

        // Distant mountain range
        let rock = Color(red: 0.38, green: 0.45, blue: 0.55)
        let snow = Color(red: 0.92, green: 0.95, blue: 1.0)
        let snowLine: CGFloat = 0.3

        let peaks: [(x: CGFloat, halfW: CGFloat, peakH: CGFloat)] = [
            (0.15, 0.14, 0.42), (0.35, 0.18, 0.55), (0.55, 0.12, 0.35),
            (0.75, 0.20, 0.50), (0.92, 0.10, 0.30),
        ]
        for peak in peaks {
            let cx = peak.x * w
            let pW = peak.halfW * w
            let pH = peak.peakH * h
            let pTop = h * 0.72 - pH
            for dy in 0..<Int(pH / px) {
                let ratio = CGFloat(dy) / (pH / px)
                let rowW = pW * 2 * ratio
                let c = ratio < snowLine ? snow : rock
                fill(&ctx, x: cx - rowW / 2, y: pTop + CGFloat(dy) * px, w: rowW, h: px, c)
            }
        }

        // Pine tree silhouettes in midground
        let pine = Color(red: 0.12, green: 0.28, blue: 0.10)
        let pineMid = Color(red: 0.18, green: 0.35, blue: 0.15)
        for (tx, th) in [(0.10, 8), (0.30, 10), (0.50, 7), (0.65, 11), (0.85, 9)] as [(CGFloat, Int)] {
            drawPixelPine(&ctx, x: tx * w, baseY: h * 0.72, height: th, dark: pine, light: pineMid)
        }

        // Eagle silhouette
        let eagle = Color(red: 0.15, green: 0.12, blue: 0.08)
        let eX = w * 0.6
        let eY = h * 0.18
        // Body
        pixel(&ctx, x: eX, y: eY, eagle)
        // Wings
        pixel(&ctx, x: eX - px, y: eY - px, eagle)
        pixel(&ctx, x: eX - px * 2, y: eY, eagle)
        pixel(&ctx, x: eX + px, y: eY - px, eagle)
        pixel(&ctx, x: eX + px * 2, y: eY, eagle)

        // Meadow ground with wildflowers
        fill(&ctx, x: 0, y: h * 0.72, w: w, h: h * 0.28, theme.previewGroundColor)
        let flowerColors: [Color] = [
            Color(red: 0.9, green: 0.3, blue: 0.3), Color(red: 0.9, green: 0.8, blue: 0.2),
            Color(red: 0.6, green: 0.3, blue: 0.8), Color(red: 1.0, green: 0.5, blue: 0.7),
        ]
        for i in 0..<6 {
            let fx = prng(22, i) * w
            pixel(&ctx, x: fx, y: h * 0.71, Color(red: 0.20, green: 0.45, blue: 0.15)) // stem
            pixel(&ctx, x: fx, y: h * 0.71 - px, flowerColors[i % flowerColors.count])
        }
    }

    // MARK: - SPACE — void with stars, planet surface, structures, nebula hint

    private func drawSpace(ctx: inout GraphicsContext, w: CGFloat, h: CGFloat) {
        skyGradient(&ctx, w: w, h: h)

        // Nebula glow
        let nebula = Color(red: 0.15, green: 0.05, blue: 0.30)
        fill(&ctx, x: w * 0.3, y: h * 0.05, w: w * 0.4, h: h * 0.25, nebula.opacity(0.15))
        fill(&ctx, x: w * 0.35, y: h * 0.10, w: w * 0.3, h: h * 0.15, nebula.opacity(0.1))

        // Stars (varied sizes)
        for i in 0..<25 {
            let sx = prng(55, i * 2) * w
            let sy = prng(55, i * 2 + 1) * h * 0.65
            let bright = 0.3 + prng(55, i * 3) * 0.7
            let size = prng(55, i * 4) > 0.8 ? px * 2 : px
            fill(&ctx, x: sx, y: sy, w: size, h: size, .white.opacity(bright))
        }

        // Distant planet
        let planetX = w * 0.75
        let planetY = h * 0.20
        let planetColor = Color(red: 0.35, green: 0.25, blue: 0.50)
        let planetLight = Color(red: 0.50, green: 0.40, blue: 0.65)
        for dy in -4...4 {
            for dx in -4...4 {
                if dx * dx + dy * dy <= 16 {
                    let c = dx < 0 ? planetLight : planetColor
                    pixel(&ctx, x: planetX + CGFloat(dx) * px, y: planetY + CGFloat(dy) * px, c)
                }
            }
        }
        // Ring
        for dx in -6...6 {
            let ringY = planetY + CGFloat(abs(dx)) * px * 0.3
            if abs(dx) > 3 {
                pixel(&ctx, x: planetX + CGFloat(dx) * px, y: ringY, Color(red: 0.6, green: 0.5, blue: 0.7).opacity(0.6))
            }
        }

        // Cratered surface terrain
        let terrain = Color(red: 0.12, green: 0.10, blue: 0.18)
        let terrainLight = Color(red: 0.18, green: 0.15, blue: 0.25)
        let terrainY = h * 0.72

        // Lumpy terrain
        for x in stride(from: CGFloat(0), to: w, by: px) {
            let tH = (sin(x / w * .pi * 4) * 0.4 + 0.6) * h * 0.08
            fill(&ctx, x: x, y: terrainY - tH, w: px, h: tH, terrain)
        }

        // Satellite dish
        let dishX = w * 0.25
        let dishBase = terrainY
        let metal = Color(red: 0.30, green: 0.30, blue: 0.35)
        // Pole
        fill(&ctx, x: dishX, y: dishBase - px * 5, w: px, h: px * 5, metal)
        // Dish
        pixel(&ctx, x: dishX - px * 2, y: dishBase - px * 5, metal)
        pixel(&ctx, x: dishX - px, y: dishBase - px * 6, metal)
        pixel(&ctx, x: dishX, y: dishBase - px * 7, metal)
        pixel(&ctx, x: dishX + px, y: dishBase - px * 6, metal)
        pixel(&ctx, x: dishX + px * 2, y: dishBase - px * 5, metal)
        // Signal light
        pixel(&ctx, x: dishX, y: dishBase - px * 8, Color(red: 0.3, green: 1.0, blue: 0.5).opacity(0.8))

        // Antenna structure
        let antX = w * 0.70
        fill(&ctx, x: antX, y: terrainY - px * 8, w: px, h: px * 8, metal)
        fill(&ctx, x: antX - px, y: terrainY - px * 8, w: px * 3, h: px, metal)
        // Blinking light
        pixel(&ctx, x: antX, y: terrainY - px * 9, Color(red: 1.0, green: 0.2, blue: 0.2))

        // Metal ground
        fill(&ctx, x: 0, y: terrainY, w: w, h: h * 0.28, theme.previewGroundColor)
        // Hazard stripe
        let hazard = Color(red: 0.85, green: 0.65, blue: 0.10)
        for i in stride(from: 0, to: Int(w / (px * 6)), by: 2) {
            fill(&ctx, x: CGFloat(i) * px * 6, y: terrainY, w: px * 3, h: px, hazard.opacity(0.4))
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

        // Wispy clouds
        for i in 0..<2 {
            let cx = w * (0.2 + CGFloat(i) * 0.5)
            let cy = h * 0.10 + CGFloat(i) * px * 2
            fill(&ctx, x: cx, y: cy, w: px * 10, h: px, .white.opacity(0.6))
            fill(&ctx, x: cx + px * 2, y: cy + px, w: px * 7, h: px, .white.opacity(0.4))
        }

        // Ocean water band
        let waterTop = h * 0.40
        let waterH = h * 0.38
        let waterDeep = Color(red: 0.12, green: 0.50, blue: 0.65)
        let waterMid = Color(red: 0.18, green: 0.62, blue: 0.75)
        let waterShallow = Color(red: 0.35, green: 0.78, blue: 0.85)
        fill(&ctx, x: 0, y: waterTop, w: w, h: waterH * 0.3, waterDeep)
        fill(&ctx, x: 0, y: waterTop + waterH * 0.3, w: w, h: waterH * 0.4, waterMid)
        fill(&ctx, x: 0, y: waterTop + waterH * 0.7, w: w, h: waterH * 0.3, waterShallow)

        // Wave sparkles on water
        for i in 0..<6 {
            let wx = prng(31, i) * w
            let wy = waterTop + prng(31, i + 10) * waterH
            fill(&ctx, x: wx, y: wy, w: px * 2, h: px, .white.opacity(0.25))
        }

        // Pirate ship on horizon
        let shipX = w * 0.70
        let shipY = waterTop + px * 2
        let shipDark = Color(red: 0.20, green: 0.12, blue: 0.06)
        let sailColor = Color(red: 0.85, green: 0.80, blue: 0.70)
        // Hull
        fill(&ctx, x: shipX, y: shipY, w: px * 6, h: px * 2, shipDark)
        fill(&ctx, x: shipX + px, y: shipY + px * 2, w: px * 4, h: px, shipDark)
        // Mast
        fill(&ctx, x: shipX + px * 2, y: shipY - px * 5, w: px, h: px * 5, shipDark)
        // Sails
        fill(&ctx, x: shipX + px * 3, y: shipY - px * 4, w: px * 2, h: px * 3, sailColor)
        // Skull flag
        pixel(&ctx, x: shipX + px * 2, y: shipY - px * 6, Color(red: 0.1, green: 0.1, blue: 0.1))

        // Beach island mound
        let sand = Color(red: 0.90, green: 0.82, blue: 0.60)
        let sandDark = Color(red: 0.80, green: 0.72, blue: 0.50)
        drawSineHills(&ctx, w: w, baseY: h * 0.72, amplitude: h * 0.08, freq: 1.5, phase: 0.3, color: sandDark.opacity(0.6))

        // Palm trees on beach
        let palmTrunk = Color(red: 0.45, green: 0.30, blue: 0.15)
        let palmLeaf = Color(red: 0.22, green: 0.55, blue: 0.25)
        let palmLeafL = Color(red: 0.30, green: 0.65, blue: 0.32)
        // Palm 1
        let p1x = w * 0.22
        for i in 0..<7 {
            let sway = sin(CGFloat(i) * 0.3) * px
            pixel(&ctx, x: p1x + sway, y: h * 0.78 - CGFloat(i) * px * 1.5, palmTrunk)
        }
        // Fronds
        pixel(&ctx, x: p1x - px * 3, y: h * 0.78 - 11 * px, palmLeaf)
        pixel(&ctx, x: p1x - px * 2, y: h * 0.78 - 12 * px, palmLeaf)
        pixel(&ctx, x: p1x - px, y: h * 0.78 - 12 * px, palmLeafL)
        pixel(&ctx, x: p1x, y: h * 0.78 - 12 * px, palmLeafL)
        pixel(&ctx, x: p1x + px, y: h * 0.78 - 12 * px, palmLeaf)
        pixel(&ctx, x: p1x + px * 2, y: h * 0.78 - 11 * px, palmLeaf)
        // Coconuts
        pixel(&ctx, x: p1x - px, y: h * 0.78 - 10.5 * px, Color(red: 0.50, green: 0.35, blue: 0.18))

        // Palm 2 (smaller)
        let p2x = w * 0.50
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
    }

    // MARK: - LOS ANGELES — palm boulevard, Hollywood hills, sunset haze, city glow

    private func drawLosAngeles(ctx: inout GraphicsContext, w: CGFloat, h: CGFloat) {
        skyGradient(&ctx, w: w, h: h)

        // Sun haze near horizon
        let sunHaze = Color(red: 1.0, green: 0.75, blue: 0.35)
        fill(&ctx, x: 0, y: h * 0.35, w: w, h: h * 0.12, sunHaze.opacity(0.15))

        // Hollywood hills silhouette
        let hillDark = Color(red: 0.30, green: 0.20, blue: 0.15)
        let hillMid = Color(red: 0.42, green: 0.30, blue: 0.22)
        drawSineHills(&ctx, w: w, baseY: h * 0.48, amplitude: h * 0.15, freq: 2.0, phase: 0.5, color: hillDark.opacity(0.6))
        drawSineHills(&ctx, w: w, baseY: h * 0.55, amplitude: h * 0.10, freq: 3.0, phase: 1.8, color: hillMid.opacity(0.5))

        // HOLLYWOOD sign hint (tiny white letters on hill)
        let signY = h * 0.40
        let signX = w * 0.35
        let signColor = Color.white.opacity(0.45)
        for i in 0..<9 {
            // Each "letter" is just a tiny pixel column
            pixel(&ctx, x: signX + CGFloat(i) * px * 1.5, y: signY, signColor)
            pixel(&ctx, x: signX + CGFloat(i) * px * 1.5, y: signY + px, signColor)
        }

        // Tall palm trees lining boulevard
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

        // Low-rise buildings silhouette
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

        // Rain streaks
        let rain = Color(red: 0.60, green: 0.65, blue: 0.70).opacity(0.2)
        for i in 0..<12 {
            let rx = prng(19, i * 2) * w
            let ry = prng(19, i * 2 + 1) * h * 0.7
            fill(&ctx, x: rx, y: ry, w: px * 0.5, h: px * 3, rain)
        }

        // River Thames band
        let river = Color(red: 0.30, green: 0.38, blue: 0.45)
        fill(&ctx, x: 0, y: h * 0.62, w: w, h: h * 0.08, river)
        // River reflections
        for i in 0..<4 {
            let rx = prng(23, i) * w
            fill(&ctx, x: rx, y: h * 0.64, w: px * 3, h: px, Color(red: 0.40, green: 0.48, blue: 0.55).opacity(0.3))
        }

        // Big Ben / Elizabeth Tower
        let brickDark = Color(red: 0.32, green: 0.28, blue: 0.24)
        let brickMid = Color(red: 0.42, green: 0.38, blue: 0.32)
        let clockGold = Color(red: 1.0, green: 0.88, blue: 0.50)
        let benX = w * 0.20
        // Tower body
        fill(&ctx, x: benX, y: h * 0.18, w: px * 4, h: h * 0.42, brickDark)
        fill(&ctx, x: benX + px, y: h * 0.18, w: px * 2, h: h * 0.42, brickMid)
        // Spire
        fill(&ctx, x: benX + px, y: h * 0.08, w: px * 2, h: h * 0.10, brickDark)
        pixel(&ctx, x: benX + px * 1.5, y: h * 0.05, clockGold) // gold tip
        // Clock face
        fill(&ctx, x: benX + px, y: h * 0.22, w: px * 2, h: px * 2, clockGold)

        // Parliament building
        fill(&ctx, x: benX + px * 5, y: h * 0.38, w: px * 12, h: h * 0.22, brickDark)
        fill(&ctx, x: benX + px * 5, y: h * 0.38, w: px * 12, h: px, brickMid)
        // Parliament windows
        var pwx = benX + px * 6
        while pwx < benX + px * 16 {
            pixel(&ctx, x: pwx, y: h * 0.42, Color(red: 0.80, green: 0.75, blue: 0.55).opacity(0.4))
            pixel(&ctx, x: pwx, y: h * 0.48, Color(red: 0.80, green: 0.75, blue: 0.55).opacity(0.3))
            pwx += px * 3
        }

        // London Eye (simplified Ferris wheel)
        let eyeX = w * 0.65
        let eyeY = h * 0.32
        let eyeR: CGFloat = 8
        let metal = Color(red: 0.52, green: 0.55, blue: 0.58)
        // Circle outline
        for angle in stride(from: 0.0, to: Double.pi * 2, by: 0.3) {
            let dx = cos(angle) * Double(eyeR)
            let dy = sin(angle) * Double(eyeR)
            pixel(&ctx, x: eyeX + CGFloat(dx) * px, y: eyeY + CGFloat(dy) * px, metal)
        }
        // Support pole
        fill(&ctx, x: eyeX - px * 0.5, y: eyeY, w: px, h: h * 0.60 - eyeY, metal.opacity(0.6))
        // Pods (small dots)
        for angle in stride(from: 0.0, to: Double.pi * 2, by: Double.pi / 4) {
            let dx = cos(angle) * Double(eyeR)
            let dy = sin(angle) * Double(eyeR)
            pixel(&ctx, x: eyeX + CGFloat(dx) * px, y: eyeY + CGFloat(dy) * px, .white.opacity(0.5))
        }

        // Red double-decker bus
        let busX = w * 0.78
        let busY = h * 0.72
        let busRed = Color(red: 0.80, green: 0.15, blue: 0.12)
        let busRedDark = Color(red: 0.60, green: 0.10, blue: 0.08)
        // Body
        fill(&ctx, x: busX, y: busY - px * 4, w: px * 6, h: px * 4, busRed)
        // Top deck
        fill(&ctx, x: busX, y: busY - px * 7, w: px * 6, h: px * 3, busRedDark)
        // Windows
        fill(&ctx, x: busX + px, y: busY - px * 6, w: px * 4, h: px, Color(red: 0.65, green: 0.72, blue: 0.80).opacity(0.5))
        fill(&ctx, x: busX + px, y: busY - px * 3, w: px * 4, h: px, Color(red: 0.65, green: 0.72, blue: 0.80).opacity(0.5))
        // Wheels
        pixel(&ctx, x: busX + px, y: busY, Color(red: 0.15, green: 0.15, blue: 0.15))
        pixel(&ctx, x: busX + px * 4, y: busY, Color(red: 0.15, green: 0.15, blue: 0.15))

        // Generic rooftops
        let roofColor = Color(red: 0.28, green: 0.25, blue: 0.22)
        fill(&ctx, x: w * 0.42, y: h * 0.45, w: px * 8, h: h * 0.15, roofColor)
        fill(&ctx, x: w * 0.86, y: h * 0.50, w: px * 6, h: h * 0.10, roofColor)

        // Ground — wet cobblestone
        fill(&ctx, x: 0, y: h * 0.78, w: w, h: h * 0.22, theme.previewGroundColor)
        // Puddle reflections
        for i in 0..<3 {
            let pdx = prng(41, i) * w
            fill(&ctx, x: pdx, y: h * 0.82, w: px * 4, h: px, Color(red: 0.40, green: 0.45, blue: 0.55).opacity(0.25))
        }
    }
}
