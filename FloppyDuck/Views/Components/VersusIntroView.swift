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
                        duckPortrait(skin: opponentSkin ?? .classic, flipped: true)
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

/// Renders the player's selected battle banner using a seamless tiled pattern
/// (Kenney CC0 pixel art tiles) tinted with the banner's colors, scrolling
/// vertically, with gradient overlay and vignette for a rich, attention-grabbing look.
struct BannerPatternView: View {
    let banner: BattleBanner
    let offset: CGFloat

    /// Tile size in points (the 64×64 pattern assets tile at this interval).
    private let tileSize: CGFloat = 64

    /// Seamless scroll offset that wraps at the tile boundary.
    private var scrollY: CGFloat {
        offset.truncatingRemainder(dividingBy: tileSize)
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // 1) Rich gradient base
                LinearGradient(
                    colors: [
                        banner.secondaryColor,
                        banner.secondaryColor.opacity(0.8),
                        Color.black.opacity(0.85)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // 2) Tiled pattern — scrolls vertically, tinted with banner color
                Image(banner.patternTileName)
                    .resizable(resizingMode: .tile)
                    .frame(
                        width: w + tileSize * 2,
                        height: h + tileSize * 2
                    )
                    .colorMultiply(banner.primaryColor)
                    .opacity(0.55)
                    .offset(x: -tileSize, y: -tileSize + scrollY)
                    .frame(width: w, height: h)
                    .clipped()

                // 3) Second pattern layer — offset half-tile, subtler, for depth
                Image(banner.patternTileName)
                    .resizable(resizingMode: .tile)
                    .frame(
                        width: w + tileSize * 2,
                        height: h + tileSize * 2
                    )
                    .colorMultiply(banner.primaryColor)
                    .opacity(0.2)
                    .blendMode(.screen)
                    .offset(
                        x: -tileSize + tileSize * 0.5,
                        y: -tileSize + scrollY * 0.6 + tileSize * 0.5
                    )
                    .frame(width: w, height: h)
                    .clipped()

                // 4) Center radial glow in banner's color
                RadialGradient(
                    colors: [
                        banner.primaryColor.opacity(0.3),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 10,
                    endRadius: h * 0.55
                )

                // 5) Vignette edges for cinematic depth
                RadialGradient(
                    colors: [Color.clear, Color.black.opacity(0.45)],
                    center: .center,
                    startRadius: h * 0.25,
                    endRadius: h * 0.75
                )
            }
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
