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
    @State private var playerSlide: CGFloat = -400
    @State private var opponentSlide: CGFloat = 400
    @State private var vsScale: CGFloat = 0
    @State private var vsRotation: Double = -30
    @State private var flashOpacity: Double = 0
    @State private var bgGlow: Double = 0
    @State private var subtitleOpacity: Double = 0
    @State private var dismissOpacity: Double = 1

    private let factory = TextureFactory.shared

    var body: some View {
        ZStack {
            // Background — dramatic dark with colored glow
            Rectangle()
                .fill(Color.black)
                .ignoresSafeArea()

            // Split-color background glow
            HStack(spacing: 0) {
                playerSkin.accentColor.opacity(bgGlow * 0.25)
                opponentAccent.opacity(bgGlow * 0.25)
            }
            .ignoresSafeArea()

            // Diagonal slash through center
            DiagonalSlash()
                .fill(Color.white.opacity(bgGlow * 0.08))
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

                    Text("VS")
                        .font(.custom(GK.pixelFontName, size: 40))
                        .foregroundColor(GK.Colors.scoreYellow)
                        .shadow(color: .black, radius: 0, x: 3, y: 3)
                        .shadow(color: GK.Colors.scoreYellow.opacity(0.6), radius: 12)
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

    // MARK: - Duck Portrait

    private func duckPortrait(skin: DuckSkin, flipped: Bool) -> some View {
        Image(uiImage: factory.skinDuckUIImage(skin: skin, pixelScale: 10.0))
            .interpolation(.none)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 100, height: 100)
            .scaleEffect(x: flipped ? -1 : 1, y: 1)
            .shadow(color: (flipped ? opponentAccent : skin.accentColor).opacity(0.5), radius: 12)
    }

    // MARK: - Animation Sequence

    private func runAnimation() {
        SoundManager.shared.play(.button)

        // 1. Portraits slide in (0.0–0.4s)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            playerSlide = 0
            opponentSlide = 0
            bgGlow = 1
        }

        // 2. VS slams down (0.35–0.65s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            SoundManager.shared.play(.score) // Impact sound
            Haptic.win()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                vsScale = 1.0
                vsRotation = 0
            }
            // Flash
            withAnimation(.easeOut(duration: 0.1)) {
                flashOpacity = 0.6
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeOut(duration: 0.2)) {
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

        // 4. Hold for a beat, then dismiss (1.6s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeIn(duration: 0.3)) {
                dismissOpacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                onComplete()
            }
        }
    }
}

// MARK: - Diagonal Slash Shape

/// Diagonal stripe through center for the dramatic VS background.
private struct DiagonalSlash: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        let slashWidth = w * 0.15
        p.move(to: CGPoint(x: w * 0.5 - slashWidth, y: 0))
        p.addLine(to: CGPoint(x: w * 0.5 + slashWidth, y: 0))
        p.addLine(to: CGPoint(x: w * 0.5, y: h))
        p.addLine(to: CGPoint(x: w * 0.5 - slashWidth * 2, y: h))
        p.closeSubpath()
        return p
    }
}
