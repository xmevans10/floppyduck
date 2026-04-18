import SwiftUI

/// A Mortal Kombat-inspired "VS" intro shown before bot ladder, head-to-head,
/// and quick-play matches.  Two duck portraits slide in from opposite sides,
/// a "VS" emblem slams down in the center, then a "READY? FIGHT!" sequence
/// plays before the whole thing fades out to start gameplay.
///
/// Usage:
///     VersusIntroView(
///         playerSkin: .classic,
///         playerName: "YOU",
///         playerBanner: .classic,
///         opponentSkin: .pirate,
///         opponentName: "PUDDLES",
///         opponentAccent: bot.accentColor,
///     ) {
///         // Start gameplay
///     }
struct VersusIntroView: View {
    let playerSkin: DuckSkin
    let playerName: String
    let playerBanner: BattleBanner
    let opponentSkin: DuckSkin?
    let opponentName: String
    let opponentAccent: Color
    let onComplete: () -> Void

    // Animation state
    @State private var playerSlide: CGFloat = -UIScreen.main.bounds.width
    @State private var opponentSlide: CGFloat = UIScreen.main.bounds.width
    @State private var vsScale: CGFloat = 0.001
    @State private var vsRotation: Double = -75
    @State private var flashOpacity: Double = 0
    @State private var bgOpacity: Double = 0

    // "Ready? Fight!" animation state
    @State private var fightPhase: FightTextPhase = .hidden
    @State private var fightTextScale: CGFloat = 0.001
    @State private var fightFlashOpacity: Double = 0

    @State private var dismissOpacity: Double = 1
    @State private var bgOffset: CGFloat = 0

    private let factory = TextureFactory.shared

    /// Phases for the "Ready? Fight!" text sequence.
    private enum FightTextPhase {
        case hidden
        case ready
        case fight
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background — Dark Base
                Color.black.ignoresSafeArea()

                // Split diagonal backgrounds (animated scrolling) — uses player's battle banner
                ZStack {
                    // Player side (left/top)
                    BannerPatternView(banner: playerBanner, offset: bgOffset)
                        .clipShape(LightningSplit(isLeft: true))
                        .shadow(color: playerBanner.glowColor, radius: 15, x: 5, y: 0)

                    // Opponent side (right/bottom) — uses opponent accent color as fallback
                    PlayerBackgroundHalf(color: opponentAccent, offset: -bgOffset)
                        .clipShape(LightningSplit(isLeft: false))
                }
                .opacity(bgOpacity)
                .ignoresSafeArea()

                // Pixel Grid Overlay / Scanlines
                ScanlineOverlay()
                    .opacity(bgOpacity * 0.4)
                    .ignoresSafeArea()

                // Middle Lightning Slash
                LightningSplitPath()
                    .stroke(Color.white, lineWidth: 6)
                    .shadow(color: .white, radius: 10)
                    .opacity(bgOpacity)
                    .ignoresSafeArea()

                // ── Portraits + Names + VS ─────────────────────────────
                // Laid out as a single HStack so nothing overlaps.
                HStack(alignment: .center, spacing: 0) {

                    // Player portrait (left)
                    VStack(spacing: 8) {
                        duckPortrait(skin: playerSkin, flipped: false)
                        Text(playerName)
                            .font(.custom(GK.pixelFontName, size: 14))
                            .foregroundColor(.white)
                            .shadow(color: playerBanner.primaryColor, radius: 6)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    .frame(maxWidth: .infinity)
                    .offset(x: playerSlide)

                    // Center VS emblem — fixed width keeps it from pushing names
                    ZStack {
                        // Glow ring behind VS
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [Color.white.opacity(0.3), Color.clear],
                                    center: .center,
                                    startRadius: 10,
                                    endRadius: 60
                                )
                            )
                            .frame(width: 120, height: 120)
                            .scaleEffect(vsScale)

                        // Flashy VS text
                        Text("VS")
                            .font(.custom(GK.pixelFontName, size: 64))
                            .foregroundColor(.white)
                            .shadow(color: GK.Colors.scoreYellow, radius: 2)
                            .shadow(color: GK.Colors.scoreYellow.opacity(0.8), radius: 15)
                            .shadow(color: GK.Colors.scoreYellow.opacity(0.4), radius: 30)
                            .overlay(
                                Text("VS")
                                    .font(.custom(GK.pixelFontName, size: 64))
                                    .foregroundColor(.clear)
                                    .shadow(color: .black, radius: 0, x: 4, y: 5)
                                    .offset(x: -2, y: -2)
                                    .blendMode(.destinationOut)
                            )
                            .scaleEffect(vsScale)
                            .rotationEffect(.degrees(vsRotation))
                    }
                    .frame(width: 100)

                    // Opponent portrait (right)
                    VStack(spacing: 8) {
                        if let opSkin = opponentSkin {
                            duckPortrait(skin: opSkin, flipped: true)
                        } else {
                            // Ghost silhouette for head-to-head
                            duckPortrait(skin: playerSkin, flipped: true)
                                .opacity(0.5)
                        }
                        Text(opponentName)
                            .font(.custom(GK.pixelFontName, size: 14))
                            .foregroundColor(.white)
                            .shadow(color: opponentAccent, radius: 6)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    .frame(maxWidth: .infinity)
                    .offset(x: opponentSlide)
                }
                .padding(.horizontal, 16)

                // ── "READY? FIGHT!" overlay ─────────────────────────────
                if fightPhase != .hidden {
                    ZStack {
                        // Screen-wide dark stripe behind the text
                        Rectangle()
                            .fill(Color.black.opacity(0.55))
                            .frame(height: 80)

                        fightText
                            .scaleEffect(fightTextScale)
                    }
                    .transition(.identity) // managed manually via scale
                }

                // Flash overlay (when VS slams in)
                Color.white.opacity(flashOpacity)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                // Secondary flash for FIGHT!
                Color.white.opacity(fightFlashOpacity)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
            .opacity(dismissOpacity)
            .onAppear { runAnimation() }
        }
    }

    // MARK: - "Ready? Fight!" Text

    @ViewBuilder
    private var fightText: some View {
        switch fightPhase {
        case .hidden:
            EmptyView()
        case .ready:
            Text("READY?")
                .font(.custom(GK.pixelFontName, size: 40))
                .foregroundColor(.white)
                .shadow(color: GK.Colors.scoreYellow, radius: 4)
                .shadow(color: GK.Colors.scoreYellow.opacity(0.6), radius: 12)
                .shadow(color: .black, radius: 0, x: 3, y: 3)
        case .fight:
            Text("FIGHT!")
                .font(.custom(GK.pixelFontName, size: 48))
                .foregroundColor(GK.Colors.scoreYellow)
                .shadow(color: Color.red, radius: 6)
                .shadow(color: Color.red.opacity(0.6), radius: 18)
                .shadow(color: .black, radius: 0, x: 3, y: 3)
        }
    }

    // MARK: - Duck Portrait

    private func duckPortrait(skin: DuckSkin, flipped: Bool) -> some View {
        Image(uiImage: factory.skinDuckUIImage(skin: skin, pixelScale: 10.0))
            .interpolation(.none)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 140, height: 140)
            .scaleEffect(x: flipped ? -1 : 1, y: 1)
            .shadow(color: (flipped ? opponentAccent : playerBanner.primaryColor).opacity(0.7), radius: 20)
            .shadow(color: (flipped ? opponentAccent : playerBanner.primaryColor).opacity(0.3), radius: 40)
    }

    // MARK: - Animation Sequence

    private func runAnimation() {
        SoundManager.shared.play(.button)

        // 1. Enter background + continuous scroll
        withAnimation(.easeIn(duration: 0.2)) {
            bgOpacity = 1
        }
        withAnimation(.linear(duration: 5.0).repeatForever(autoreverses: false)) {
            bgOffset = 400
        }

        // 2. Portraits slide in with massive spring
        withAnimation(.spring(response: 0.6, dampingFraction: 0.6, blendDuration: 0.1)) {
            playerSlide = 0
            opponentSlide = 0
        }

        // 3. VS slams down (0.35s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            SoundManager.shared.play(.score)
            Haptic.win()
            withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.4, blendDuration: 0.1)) {
                vsScale = 1.0
                vsRotation = 0
            }
            // Flash screen on slam
            withAnimation(.easeOut(duration: 0.05)) {
                flashOpacity = 0.8
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.easeOut(duration: 0.3)) {
                    flashOpacity = 0
                }
            }
        }

        // 4. "READY?" appears (1.3s after start)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            fightPhase = .ready
            fightTextScale = 0.001
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5, blendDuration: 0.05)) {
                fightTextScale = 1.0
            }
            SoundManager.shared.play(.button)
        }

        // 5. Transition to "FIGHT!" (2.1s after start)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.1) {
            fightTextScale = 0.001
            fightPhase = .fight

            withAnimation(.interactiveSpring(response: 0.25, dampingFraction: 0.4, blendDuration: 0.05)) {
                fightTextScale = 1.0
            }

            // Flash on FIGHT!
            withAnimation(.easeOut(duration: 0.04)) {
                fightFlashOpacity = 0.6
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) {
                withAnimation(.easeOut(duration: 0.25)) {
                    fightFlashOpacity = 0
                }
            }

            SoundManager.shared.play(.score)
            Haptic.win()
        }

        // 6. Hold for a beat, then dismiss (3.2s — extra drama)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
            withAnimation(.easeIn(duration: 0.3)) {
                dismissOpacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                onComplete()
            }
        }
    }
}

// MARK: - Banner Pattern View

/// Renders the player's selected battle banner pattern on their VS intro half.
struct BannerPatternView: View {
    let banner: BattleBanner
    let offset: CGFloat

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Base color
                banner.secondaryColor

                // Pattern layer
                switch banner.pattern {
                case .diagonalStripes:
                    DiagonalStripesPattern(color: banner.primaryColor, offset: offset)
                case .chevrons:
                    ChevronsPattern(color: banner.primaryColor, offset: offset)
                case .diamonds:
                    DiamondsPattern(color: banner.primaryColor, offset: offset)
                case .zigzag:
                    ZigzagPattern(color: banner.primaryColor, offset: offset)
                case .crosshatch:
                    CrosshatchPattern(color: banner.primaryColor, offset: offset)
                case .hexGrid:
                    HexGridPattern(color: banner.primaryColor, offset: offset)
                case .flames:
                    FlamesPattern(color: banner.primaryColor, offset: offset)
                case .circuit:
                    CircuitPattern(color: banner.primaryColor, offset: offset)
                case .waves:
                    WavesPattern(color: banner.primaryColor, offset: offset)
                case .skulls:
                    SkullsPattern(color: banner.primaryColor, offset: offset)
                }
            }
        }
    }
}

// MARK: - Pattern Implementations

/// Original diagonal stripes (preserved from original PlayerBackgroundHalf).
private struct DiagonalStripesPattern: View {
    let color: Color
    let offset: CGFloat

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height

            Path { p in
                let stripeWidth: CGFloat = 60
                let totalScroll = offset.truncatingRemainder(dividingBy: stripeWidth * 2)

                for i in -20...20 {
                    let startX = CGFloat(i) * stripeWidth * 2 + totalScroll
                    p.move(to: CGPoint(x: startX, y: -h))
                    p.addLine(to: CGPoint(x: startX + stripeWidth, y: -h))
                    p.addLine(to: CGPoint(x: startX + stripeWidth - h * 1.5, y: h * 1.5))
                    p.addLine(to: CGPoint(x: startX - h * 1.5, y: h * 1.5))
                    p.closeSubpath()
                }
            }
            .fill(color.opacity(0.4))
        }
    }
}

/// Repeating chevron (V) shapes scrolling vertically.
private struct ChevronsPattern: View {
    let color: Color
    let offset: CGFloat

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width

            Path { p in
                let rowHeight: CGFloat = 50
                let totalScroll = offset.truncatingRemainder(dividingBy: rowHeight)

                for row in -5...20 {
                    let y = CGFloat(row) * rowHeight + totalScroll
                    // Left arm of V
                    p.move(to: CGPoint(x: 0, y: y))
                    p.addLine(to: CGPoint(x: w / 2, y: y + rowHeight * 0.5))
                    p.addLine(to: CGPoint(x: w / 2, y: y + rowHeight * 0.5 + 8))
                    p.addLine(to: CGPoint(x: 0, y: y + 8))
                    p.closeSubpath()
                    // Right arm of V
                    p.move(to: CGPoint(x: w, y: y))
                    p.addLine(to: CGPoint(x: w / 2, y: y + rowHeight * 0.5))
                    p.addLine(to: CGPoint(x: w / 2, y: y + rowHeight * 0.5 + 8))
                    p.addLine(to: CGPoint(x: w, y: y + 8))
                    p.closeSubpath()
                }
            }
            .fill(color.opacity(0.35))
        }
    }
}

/// Diamond grid pattern.
private struct DiamondsPattern: View {
    let color: Color
    let offset: CGFloat

    var body: some View {
        GeometryReader { geo in
            Path { p in
                let size: CGFloat = 40
                let totalScroll = offset.truncatingRemainder(dividingBy: size * 2)

                for row in -5...20 {
                    for col in -5...15 {
                        let cx = CGFloat(col) * size * 2 + (row % 2 == 0 ? 0 : size) + totalScroll
                        let cy = CGFloat(row) * size + totalScroll * 0.5
                        let half = size * 0.4
                        p.move(to: CGPoint(x: cx, y: cy - half))
                        p.addLine(to: CGPoint(x: cx + half, y: cy))
                        p.addLine(to: CGPoint(x: cx, y: cy + half))
                        p.addLine(to: CGPoint(x: cx - half, y: cy))
                        p.closeSubpath()
                    }
                }
            }
            .fill(color.opacity(0.35))
        }
    }
}

/// Zigzag horizontal bands.
private struct ZigzagPattern: View {
    let color: Color
    let offset: CGFloat

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width

            Path { p in
                let bandHeight: CGFloat = 35
                let zigWidth: CGFloat = 30
                let totalScroll = offset.truncatingRemainder(dividingBy: bandHeight * 2)

                for band in -5...25 {
                    let baseY = CGFloat(band) * bandHeight + totalScroll
                    p.move(to: CGPoint(x: -zigWidth, y: baseY))
                    var x: CGFloat = -zigWidth
                    var up = true
                    while x < w + zigWidth {
                        x += zigWidth
                        p.addLine(to: CGPoint(x: x, y: baseY + (up ? -12 : 12)))
                        up.toggle()
                    }
                    // Close the band with thickness
                    p.addLine(to: CGPoint(x: w + zigWidth, y: baseY + 8))
                    x = w + zigWidth
                    up.toggle()
                    while x > -zigWidth {
                        x -= zigWidth
                        p.addLine(to: CGPoint(x: x, y: baseY + 8 + (up ? 12 : -12)))
                        up.toggle()
                    }
                    p.closeSubpath()
                }
            }
            .fill(color.opacity(0.35))
        }
    }
}

/// Cross-hatched lines.
private struct CrosshatchPattern: View {
    let color: Color
    let offset: CGFloat

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height

            Path { p in
                let spacing: CGFloat = 30
                let totalScroll = offset.truncatingRemainder(dividingBy: spacing)

                // Forward diagonals
                for i in -30...30 {
                    let startX = CGFloat(i) * spacing + totalScroll
                    p.move(to: CGPoint(x: startX, y: 0))
                    p.addLine(to: CGPoint(x: startX + h, y: h))
                }
                // Backward diagonals
                for i in -30...30 {
                    let startX = CGFloat(i) * spacing - totalScroll
                    p.move(to: CGPoint(x: startX + h, y: 0))
                    p.addLine(to: CGPoint(x: startX, y: h))
                }
            }
            .stroke(color.opacity(0.3), lineWidth: 3)
        }
    }
}

/// Hexagonal grid (honeycomb).
private struct HexGridPattern: View {
    let color: Color
    let offset: CGFloat

    var body: some View {
        GeometryReader { geo in
            Path { p in
                let hexSize: CGFloat = 25
                let totalScroll = offset.truncatingRemainder(dividingBy: hexSize * 2)
                let rowH = hexSize * 1.73
                let colW = hexSize * 1.5

                for row in -3...15 {
                    for col in -3...12 {
                        let cx = CGFloat(col) * colW + (row % 2 == 0 ? 0 : colW / 2) + totalScroll
                        let cy = CGFloat(row) * rowH + totalScroll * 0.5

                        p.move(to: CGPoint(x: cx + hexSize, y: cy))
                        for angle in 1...6 {
                            let a = CGFloat(angle) * .pi / 3
                            p.addLine(to: CGPoint(
                                x: cx + hexSize * cos(a),
                                y: cy + hexSize * sin(a)
                            ))
                        }
                        p.closeSubpath()
                    }
                }
            }
            .stroke(color.opacity(0.3), lineWidth: 2)
        }
    }
}

/// Rising flame shapes.
private struct FlamesPattern: View {
    let color: Color
    let offset: CGFloat

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height

            Path { p in
                let flameWidth: CGFloat = 40
                let totalScroll = offset.truncatingRemainder(dividingBy: flameWidth * 2)

                for i in -5...15 {
                    let baseX = CGFloat(i) * flameWidth + totalScroll
                    let tipY = h * 0.1 - abs(offset.truncatingRemainder(dividingBy: 80))
                    let baseY = h + 20

                    p.move(to: CGPoint(x: baseX, y: baseY))
                    p.addQuadCurve(
                        to: CGPoint(x: baseX + flameWidth * 0.5, y: tipY),
                        control: CGPoint(x: baseX + flameWidth * 0.15, y: h * 0.4)
                    )
                    p.addQuadCurve(
                        to: CGPoint(x: baseX + flameWidth, y: baseY),
                        control: CGPoint(x: baseX + flameWidth * 0.85, y: h * 0.4)
                    )
                    p.closeSubpath()
                }
            }
            .fill(color.opacity(0.3))
        }
    }
}

/// Circuit board trace pattern.
private struct CircuitPattern: View {
    let color: Color
    let offset: CGFloat

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width

            Path { p in
                let gridSize: CGFloat = 40
                let totalScroll = offset.truncatingRemainder(dividingBy: gridSize)

                // Horizontal traces
                for row in -3...20 {
                    let y = CGFloat(row) * gridSize + totalScroll
                    p.move(to: CGPoint(x: 0, y: y))
                    var x: CGFloat = 0
                    while x < w {
                        let segLen = CGFloat.random(in: 20...60)
                        p.addLine(to: CGPoint(x: min(x + segLen, w), y: y))
                        x += segLen
                        // Small node circle
                        if x < w {
                            p.addEllipse(in: CGRect(x: x - 3, y: y - 3, width: 6, height: 6))
                        }
                        // Short vertical connector
                        let down = CGFloat.random(in: -15...15)
                        p.move(to: CGPoint(x: x, y: y))
                        p.addLine(to: CGPoint(x: x, y: y + down))
                        p.move(to: CGPoint(x: x, y: y))
                        x += 10
                    }
                }
            }
            .stroke(color.opacity(0.3), lineWidth: 2)
        }
    }
}

/// Rolling wave lines.
private struct WavesPattern: View {
    let color: Color
    let offset: CGFloat

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width

            Path { p in
                let waveHeight: CGFloat = 20
                let spacing: CGFloat = 35
                let totalScroll = offset.truncatingRemainder(dividingBy: spacing)

                for row in -3...25 {
                    let baseY = CGFloat(row) * spacing + totalScroll
                    p.move(to: CGPoint(x: -20, y: baseY))

                    var x: CGFloat = -20
                    while x < w + 40 {
                        p.addQuadCurve(
                            to: CGPoint(x: x + 30, y: baseY),
                            control: CGPoint(x: x + 15, y: baseY - waveHeight)
                        )
                        x += 30
                        p.addQuadCurve(
                            to: CGPoint(x: x + 30, y: baseY),
                            control: CGPoint(x: x + 15, y: baseY + waveHeight)
                        )
                        x += 30
                    }
                }
            }
            .stroke(color.opacity(0.3), lineWidth: 3)
        }
    }
}

/// Repeating skull pixel art (simplified).
private struct SkullsPattern: View {
    let color: Color
    let offset: CGFloat

    var body: some View {
        GeometryReader { geo in
            Path { p in
                let size: CGFloat = 50
                let totalScroll = offset.truncatingRemainder(dividingBy: size * 2)

                for row in -3...18 {
                    for col in -3...10 {
                        let cx = CGFloat(col) * size * 1.5 + (row % 2 == 0 ? 0 : size * 0.75) + totalScroll
                        let cy = CGFloat(row) * size + totalScroll * 0.3

                        // Skull circle
                        let r = size * 0.3
                        p.addEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 1.8))
                        // Crossbones (X below)
                        let boneLen = size * 0.25
                        let boneY = cy + r * 0.9
                        p.move(to: CGPoint(x: cx - boneLen, y: boneY - boneLen * 0.5))
                        p.addLine(to: CGPoint(x: cx + boneLen, y: boneY + boneLen * 0.5))
                        p.move(to: CGPoint(x: cx + boneLen, y: boneY - boneLen * 0.5))
                        p.addLine(to: CGPoint(x: cx - boneLen, y: boneY + boneLen * 0.5))
                    }
                }
            }
            .stroke(color.opacity(0.25), lineWidth: 2)
        }
    }
}

// MARK: - Fancy Background Components (preserved for opponent side)

/// Renders a scrolling checkered/striped pattern for the background halves
struct PlayerBackgroundHalf: View {
    let color: Color
    let offset: CGFloat

    // Create repeating diagonal stripes
    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height

            Path { p in
                // Draw wide diagonal stripes
                let stripeWidth: CGFloat = 60
                let totalScroll = offset.truncatingRemainder(dividingBy: stripeWidth * 2)

                for i in -20...20 {
                    let startX = CGFloat(i) * stripeWidth * 2 + totalScroll
                    p.move(to: CGPoint(x: startX, y: -h))
                    p.addLine(to: CGPoint(x: startX + stripeWidth, y: -h))
                    p.addLine(to: CGPoint(x: startX + stripeWidth - h * 1.5, y: h * 1.5))
                    p.addLine(to: CGPoint(x: startX - h * 1.5, y: h * 1.5))
                    p.closeSubpath()
                }
            }
            .fill(color.opacity(0.4))
            .background(color.opacity(0.15))
        }
    }
}

/// Creates a jagged lightning-bolt split down the middle
private struct LightningSplit: Shape {
    let isLeft: Bool

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        let cx = w / 2

        let point1 = CGPoint(x: cx + w * 0.15, y: 0)
        let point2 = CGPoint(x: cx + w * 0.05, y: h * 0.3)
        let point3 = CGPoint(x: cx + w * 0.12, y: h * 0.3)
        let point4 = CGPoint(x: cx - w * 0.08, y: h * 0.7)
        let point5 = CGPoint(x: cx - w * 0.01, y: h * 0.7)
        let point6 = CGPoint(x: cx - w * 0.18, y: h)

        if isLeft {
            p.move(to: CGPoint(x: 0, y: 0))
            p.addLine(to: point1)
            p.addLine(to: point2)
            p.addLine(to: point3)
            p.addLine(to: point4)
            p.addLine(to: point5)
            p.addLine(to: point6)
            p.addLine(to: CGPoint(x: 0, y: h))
        } else {
            p.move(to: CGPoint(x: w, y: 0))
            p.addLine(to: point1)
            p.addLine(to: point2)
            p.addLine(to: point3)
            p.addLine(to: point4)
            p.addLine(to: point5)
            p.addLine(to: point6)
            p.addLine(to: CGPoint(x: w, y: h))
        }
        p.closeSubpath()
        return p
    }
}

/// Helper to render just the stroke of the lightning split
private struct LightningSplitPath: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        let cx = w / 2

        let point1 = CGPoint(x: cx + w * 0.15, y: 0)
        let point2 = CGPoint(x: cx + w * 0.05, y: h * 0.3)
        let point3 = CGPoint(x: cx + w * 0.12, y: h * 0.3)
        let point4 = CGPoint(x: cx - w * 0.08, y: h * 0.7)
        let point5 = CGPoint(x: cx - w * 0.01, y: h * 0.7)
        let point6 = CGPoint(x: cx - w * 0.18, y: h)

        p.move(to: point1)
        p.addLine(to: point2)
        p.addLine(to: point3)
        p.addLine(to: point4)
        p.addLine(to: point5)
        p.addLine(to: point6)

        return p
    }
}

/// Horizontal scanlines overlay
private struct ScanlineOverlay: View {
    var body: some View {
        GeometryReader { geo in
            Path { p in
                let h = geo.size.height
                let spacing: CGFloat = 4
                for y in stride(from: 0, to: h, by: spacing * 2) {
                    p.move(to: CGPoint(x: 0, y: y))
                    p.addLine(to: CGPoint(x: geo.size.width, y: y))
                }
            }
            .stroke(Color.black.opacity(0.3), lineWidth: 4)
        }
    }
}
