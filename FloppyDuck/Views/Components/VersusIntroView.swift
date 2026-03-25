import SwiftUI

/// A Mortal Kombat-inspired "VS" intro shown before bot ladder, head-to-head,
/// and quick-play matches.  Two duck portraits slide in from opposite sides,
/// a "VS" emblem slams down in the center, then the whole thing fades out
/// to start gameplay.
///
/// Usage:
///     VersusIntroView(
///         playerSkin: .classic,
///         playerName: "YOU",
///         opponentSkin: .pirate,
///         opponentName: "PUDDLES",
///         opponentAccent: bot.accentColor,
///         subtitle: "DIES AT 18"
///     ) {
///         // Start gameplay
///     }
struct VersusIntroView: View {
    let playerSkin: DuckSkin
    let playerName: String
    let opponentSkin: DuckSkin?
    let opponentName: String
    let opponentAccent: Color
    let subtitle: String?
    let onComplete: () -> Void

    // Animation state
    @State private var playerSlide: CGFloat = -UIScreen.main.bounds.width
    @State private var opponentSlide: CGFloat = UIScreen.main.bounds.width
    @State private var vsScale: CGFloat = 0.001
    @State private var vsRotation: Double = -75
    @State private var flashOpacity: Double = 0
    @State private var bgOpacity: Double = 0
    @State private var subtitleOpacity: Double = 0
    @State private var dismissOpacity: Double = 1
    @State private var bgOffset: CGFloat = 0

    private let factory = TextureFactory.shared

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background — Dark Base
                Color.black.ignoresSafeArea()

                // Split diagonal backgrounds (animated scrolling)
                ZStack {
                    // Player side (left/top)
                    PlayerBackgroundHalf(color: playerSkin.accentColor, offset: bgOffset)
                        .clipShape(LightningSplit(isLeft: true))
                        .shadow(color: playerSkin.accentColor.opacity(0.8), radius: 15, x: 5, y: 0)
                    
                    // Opponent side (right/bottom)
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

            // Player portrait (left)
            HStack {
                VStack(spacing: 8) {
                    duckPortrait(skin: playerSkin, flipped: false)
                    Text(playerName)
                        .font(.custom(GK.pixelFontName, size: 14))
                        .foregroundColor(.white)
                        .shadow(color: playerSkin.accentColor, radius: 6)
                }
                .offset(x: playerSlide)
                Spacer()
            }
            .padding(.leading, 40)

            // Opponent portrait (right)
            HStack {
                Spacer()
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
                }
                .offset(x: opponentSlide)
            }
            .padding(.trailing, 40)

            // Center VS emblem
            VStack(spacing: 6) {
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

                if let subtitle {
                    Text(subtitle)
                        .font(.custom(GK.pixelFontName, size: 9))
                        .foregroundColor(.white.opacity(0.7))
                        .opacity(subtitleOpacity)
                }
            }

            // Flash overlay (when VS slams in)
            Color.white.opacity(flashOpacity)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .opacity(dismissOpacity)
        .onAppear { runAnimation() }
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
            .shadow(color: (flipped ? opponentAccent : skin.accentColor).opacity(0.7), radius: 20)
            .shadow(color: (flipped ? opponentAccent : skin.accentColor).opacity(0.3), radius: 40)
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

        // 3. Subtitle fades in (0.7s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.easeIn(duration: 0.2)) {
                subtitleOpacity = 1
            }
        }

        // 4. Hold for a beat, then dismiss (2.2s — longer for drama)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation(.easeIn(duration: 0.3)) {
                dismissOpacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                onComplete()
            }
        }
    }
}

// MARK: - Fancy Background Components

/// Renders a scrolling checkered/striped pattern for the background halves
private struct PlayerBackgroundHalf: View {
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
