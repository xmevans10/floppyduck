import SwiftUI

/// Splash: black screen → gold coin with duck flips in with coin sound →
/// title appears → hold → fade out → proceed.
///
/// The duck is rendered as the face of a shiny 3D gold coin that does two
/// full 360° Y-axis flips (``rotation3DEffect`` with perspective) before
/// settling.  A metallic rim, specular highlight, and animated shine sweep
/// sell the precious-metal look.
struct SplashView: View {
    @Binding var isFinished: Bool

    // MARK: - Animation State

    // Coin transform
    @State private var coinAngle: Double = 0
    @State private var coinScale: CGFloat = 0.12
    @State private var coinOpacity: Double = 0
    @State private var coinOffsetY: CGFloat = -50
    @State private var landBounce: CGFloat = 1.0

    // Title text
    @State private var titleOpacity: Double = 0
    @State private var titleScale: CGFloat = 0.85

    // Subtitle
    @State private var subtitleOpacity: Double = 0

    // Effects
    @State private var shineOffset: CGFloat = -1.0
    @State private var secondShineOffset: CGFloat = -1.0
    @State private var glowOpacity: Double = 0

    // MARK: - Constants

    private let coinDiameter: CGFloat = 175

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Ambient gold glow behind coin
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.22),
                            Color(red: 1.0, green: 0.70, blue: 0.0).opacity(0.06),
                            Color.clear,
                        ],
                        center: .center,
                        startRadius: coinDiameter * 0.2,
                        endRadius: coinDiameter * 1.4
                    )
                )
                .frame(width: coinDiameter * 3, height: coinDiameter * 3)
                .opacity(glowOpacity)
                .offset(y: -20)

            VStack(spacing: 28) {
                // ── The 3-D Coin ──
                coinBody
                    .frame(width: coinDiameter, height: coinDiameter)
                    .scaleEffect(coinScale * landBounce)
                    .offset(y: coinOffsetY)
                    .opacity(coinOpacity)
                    .rotation3DEffect(
                        .degrees(coinAngle),
                        axis: (0, 1, 0),
                        perspective: 0.35
                    )
                    // Warm gold glow
                    .shadow(
                        color: Color(red: 0.85, green: 0.65, blue: 0.10).opacity(0.30),
                        radius: 14, x: 0, y: 6
                    )
                    // Grounding shadow
                    .shadow(
                        color: .black.opacity(0.40),
                        radius: 22, x: 0, y: 14
                    )

                // ── Title & Subtitle ──
                VStack(spacing: 14) {
                    Text("FLOPPY DUCK")
                        .font(.custom(GK.pixelFontName, size: 26))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    GK.Colors.scoreYellow,
                                    Color(red: 1.0, green: 0.72, blue: 0.12),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: .orange.opacity(0.60), radius: 0, x: 2, y: 2)
                        .shadow(color: .black.opacity(0.30), radius: 4, y: 2)
                        .scaleEffect(titleScale)
                        .opacity(titleOpacity)

                    Text("TAP TO FLAP")
                        .font(.custom(GK.pixelFontName, size: 10))
                        .foregroundColor(.white.opacity(0.50))
                        .opacity(subtitleOpacity)
                }
            }
        }
        .onAppear {
            // Pre-warm textures on background thread while splash animation plays.
            TextureFactory.shared.preWarm()
            PixelIconFactory.shared.preWarm()
            runSequence()
        }
        .onTapGesture { finish() }
        .accessibilityAction(named: "Skip") { finish() }
    }

    // MARK: - Coin Construction

    private var coinBody: some View {
        ZStack {
            // ── 1. Gold base fill ──
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 1.00, green: 0.92, blue: 0.50),  // bright centre
                            Color(red: 0.95, green: 0.80, blue: 0.28),  // mid-tone
                            Color(red: 0.80, green: 0.62, blue: 0.16),  // darker rim
                        ],
                        center: .init(x: 0.42, y: 0.38),
                        startRadius: 0,
                        endRadius: coinDiameter / 2
                    )
                )

            // ── 2. Soft inner highlight (raised centre look) ──
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.10),
                            Color.clear,
                        ],
                        center: .init(x: 0.38, y: 0.32),
                        startRadius: 0,
                        endRadius: coinDiameter * 0.35
                    )
                )

            // ── 3. Inner rim ring ──
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.88, blue: 0.45).opacity(0.60),
                            Color(red: 0.65, green: 0.50, blue: 0.12).opacity(0.40),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .padding(18)

            // ── 4. Duck face — embossed ──
            Image(uiImage: TextureFactory.shared.skinDuckUIImage(
                skin: SkinManager.shared.selectedSkin,
                pixelScale: 10.0
            ))
            .interpolation(.none)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: coinDiameter * 0.50, height: coinDiameter * 0.50)
            // Dark inset shadow (south-east)
            .shadow(
                color: Color(red: 0.50, green: 0.36, blue: 0.08).opacity(0.70),
                radius: 0.8, x: 1.0, y: 1.5
            )
            // Light bevel highlight (north-west)
            .shadow(
                color: Color(red: 1.0, green: 0.95, blue: 0.72).opacity(0.40),
                radius: 0.5, x: -0.5, y: -0.5
            )

            // ── 5. Outer metallic rim — angular gradient ──
            Circle()
                .strokeBorder(
                    AngularGradient(
                        colors: [
                            Color(red: 1.00, green: 0.88, blue: 0.45),
                            Color(red: 0.72, green: 0.55, blue: 0.15),
                            Color(red: 1.00, green: 0.92, blue: 0.55),
                            Color(red: 0.68, green: 0.50, blue: 0.12),
                            Color(red: 1.00, green: 0.88, blue: 0.45),
                        ],
                        center: .center
                    ),
                    lineWidth: 5
                )

            // Fine ridge detail
            Circle()
                .strokeBorder(
                    Color(red: 0.58, green: 0.42, blue: 0.10).opacity(0.25),
                    lineWidth: 0.5
                )
                .padding(5)

            // ── 6. Fixed specular highlight ──
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.28),
                            Color.white.opacity(0.06),
                            Color.clear,
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: coinDiameter * 0.25
                    )
                )
                .frame(width: coinDiameter * 0.45, height: coinDiameter * 0.25)
                .offset(x: -14, y: -30)
                .blendMode(.screen)

            // ── 7. Animated shine sweep (first) ──
            shineSweep(offset: shineOffset)
                .clipShape(Circle())

            // ── 8. Animated shine sweep (second) ──
            shineSweep(offset: secondShineOffset)
                .clipShape(Circle())
        }
    }

    // MARK: - Shine Helper

    /// Gradient stop locations must stay in ascending order within [0,1].
    private func shineSweep(offset: CGFloat) -> some View {
        let lo  = max(0, min(1, offset - 0.12))
        let mid = max(0, min(1, offset))
        let hi  = max(0, min(1, offset + 0.12))
        return LinearGradient(
            stops: [
                .init(color: .clear,                       location: 0),
                .init(color: .clear,                       location: lo),
                .init(color: .white.opacity(0.40),         location: mid),
                .init(color: .clear,                       location: hi),
                .init(color: .clear,                       location: 1),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .blendMode(.overlay)
    }

    // MARK: - Animation Sequence (~5.0 s total)

    private func runSequence() {

        // ── Phase 1  (0 → 0.5 s)  Coin enters with spring ──────────────
        withAnimation(.spring(response: 0.50, dampingFraction: 0.60)) {
            coinScale   = 1.08
            coinOpacity = 1
            coinOffsetY = 0
        }

        // Settle scale (0.50 → 0.70 s)
        after(0.50) {
            withAnimation(.easeOut(duration: 0.20)) { coinScale = 1.0 }
            withAnimation(.easeIn(duration: 0.50))  { glowOpacity = 1.0 }
        }

        // ── Phase 2  (0.90 → 1.55 s)  First 360° Y-spin ───────────────
        after(0.90) {
            withAnimation(.easeInOut(duration: 0.65)) { coinAngle = 360 }
        }
        // Coin SFX + haptic at ≈180° (midpoint of first spin)
        after(1.22) {
            SoundManager.shared.play(.coin)
            Haptic.splashCoin()
        }

        // ── Phase 3  (1.70 → 2.25 s)  Second 360° Y-spin ──────────────
        after(1.70) {
            withAnimation(.easeInOut(duration: 0.55)) { coinAngle = 720 }
        }
        // Coin SFX + haptic at ≈540° (midpoint of second spin)
        after(1.97) {
            SoundManager.shared.play(.coin)
            Haptic.splashCoin()
        }

        // ── Phase 4  (2.25 → 2.50 s)  Land bounce ─────────────────────
        after(2.25) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.35)) {
                landBounce = 1.07
            }
        }
        after(2.45) {
            withAnimation(.easeOut(duration: 0.15)) { landBounce = 1.0 }
        }

        // ── Phase 5  (2.30 → 2.80 s)  Shine sweep after landing ───────
        after(2.30) {
            withAnimation(.linear(duration: 0.50)) { shineOffset = 1.2 }
        }
        // Second quick shine for extra sparkle
        after(2.55) {
            withAnimation(.linear(duration: 0.40)) { secondShineOffset = 1.2 }
        }

        // ── Phase 6  (2.60 → 2.90 s)  Title fades in ──────────────────
        after(2.60) {
            withAnimation(.easeOut(duration: 0.30)) {
                titleOpacity = 1
                titleScale   = 1.0
            }
        }

        // ── Phase 7  (3.00 → 3.30 s)  Subtitle fades in ──────────────
        after(3.00) {
            withAnimation(.easeIn(duration: 0.30)) { subtitleOpacity = 1 }
        }

        // ── Phase 8  (4.30 → 4.70 s)  Fade everything out ────────────
        after(4.30) {
            withAnimation(.easeOut(duration: 0.40)) {
                coinOpacity     = 0
                titleOpacity    = 0
                subtitleOpacity = 0
                glowOpacity     = 0
            }
        }

        // ── Phase 9  (5.00 s)  Transition to game ────────────────────
        after(5.00) { finish() }
    }

    // MARK: - Helpers

    /// Sugar for `DispatchQueue.main.asyncAfter`.
    private func after(_ seconds: Double, _ work: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    private func finish() {
        guard !isFinished else { return }
        isFinished = true
    }
}
