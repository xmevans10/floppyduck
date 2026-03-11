import SwiftUI

/// Standard title-card splash screen shown on app launch.
///
/// Clean, centered layout with punchy scale-up animations:
/// 1. Black screen → sky gradient fades in              (0.35s)
/// 2. Duck mascot scales up from center with spring pop  (0.35s) + heavy haptic
/// 3. "FLOPPY DUCK" title punches in below with spring   (0.3s)  + medium haptic
/// 4. Shimmer sweeps across the card                     (0.5s)  + light tap
/// 5. Hold                                               (0.4s)
/// 6. Everything fades out cleanly                       (0.3s)
struct SplashView: View {
    @Binding var isFinished: Bool

    // MARK: - Animation State

    @State private var showSky = false
    @State private var showDuck = false
    @State private var showTitle = false
    @State private var showShimmer = false
    @State private var shimmerOffset: CGFloat = -250
    @State private var fadeOut = false

    var body: some View {
        ZStack {
            // 1 ─ Background: black → sky gradient
            Color.black.ignoresSafeArea()

            LinearGradient(
                colors: [GK.Colors.skyTop, GK.Colors.skyBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .opacity(showSky ? 1 : 0)

            // 2 ─ Centered title card content
            VStack(spacing: 20) {
                Spacer()

                // Duck mascot — pops in from center
                Image(uiImage: TextureFactory.shared.skinDuckUIImage(
                    skin: SkinManager.shared.selectedSkin,
                    pixelScale: 9.0
                ))
                .interpolation(.none)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 140, height: 140)
                .scaleEffect(showDuck ? 1.0 : 0.0)
                .opacity(showDuck ? 1.0 : 0.0)
                .accessibilityLabel("Floppy Duck mascot")

                // Title card
                VStack(spacing: 2) {
                    Text("FLOPPY")
                        .font(.custom(GK.pixelFontName, size: 30))
                        .foregroundColor(.white)
                        .shadow(color: GK.Colors.pipeBorder, radius: 0, x: 4, y: 4)
                        .shadow(color: Color.black.opacity(0.35), radius: 0, x: 0, y: 2)

                    Text("DUCK")
                        .font(.custom(GK.pixelFontName, size: 30))
                        .foregroundColor(GK.Colors.scoreYellow)
                        .shadow(color: GK.Colors.pipeBorder, radius: 0, x: 4, y: 4)
                        .shadow(color: Color.black.opacity(0.35), radius: 0, x: 0, y: 2)
                }
                .scaleEffect(showTitle ? 1.0 : 0.0)
                .opacity(showTitle ? 1.0 : 0.0)
                // Shimmer overlay — sweeps across title for that flash of pop
                .overlay {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.clear,
                                    Color.white.opacity(0.15),
                                    Color.white.opacity(0.7),
                                    Color.white.opacity(0.15),
                                    Color.clear,
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 55, height: 100)
                        .rotationEffect(.degrees(14))
                        .offset(x: shimmerOffset)
                        .blendMode(.screen)
                        .allowsHitTesting(false)
                        .mask {
                            VStack(spacing: 2) {
                                Text("FLOPPY")
                                    .font(.custom(GK.pixelFontName, size: 30))
                                Text("DUCK")
                                    .font(.custom(GK.pixelFontName, size: 30))
                            }
                        }
                        .opacity(showShimmer ? 1 : 0)
                }
                .accessibilityLabel("Floppy Duck")

                Spacer()
            }
            .opacity(fadeOut ? 0.0 : 1.0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Floppy Duck splash screen")
        .onAppear(perform: runSequence)
    }

    // MARK: - Animation Sequence

    private func runSequence() {
        let reduceMotion = UIAccessibility.isReduceMotionEnabled

        if reduceMotion {
            // Skip animations for accessibility
            showSky = true
            showDuck = true
            showTitle = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                SoundManager.shared.play(.quack)
                Haptic.splashImpact()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                isFinished = true
            }
            return
        }

        // Phase 1 — Sky fades in (0–0.35s)
        withAnimation(.easeIn(duration: 0.35)) {
            showSky = true
        }

        // Phase 2 — Duck pops in from center with spring (at 0.3s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.55, blendDuration: 0)) {
                showDuck = true
            }
        }

        // Phase 2b — Haptic hit on duck pop (at 0.45s, when spring overshoots)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            Haptic.splashImpact()
            SoundManager.shared.play(.quack)
        }

        // Phase 3 — Title punches in (at 0.7s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5, blendDuration: 0)) {
                showTitle = true
            }
        }

        // Phase 3b — Haptic hit on title pop (at 0.8s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            Haptic.splashTitlePop()
        }

        // Phase 4 — Shimmer sweep across title (at 1.0s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            showShimmer = true
            withAnimation(.easeInOut(duration: 0.5)) {
                shimmerOffset = 250
            }
        }

        // Phase 4b — Light haptic tap at shimmer peak (at 1.25s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) {
            Haptic.splashShimmer()
        }

        // Phase 5 — Fade out (at 1.7s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) {
            withAnimation(.easeOut(duration: 0.3)) {
                fadeOut = true
            }
        }

        // Phase 6 — Mark finished (at 2.05s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.05) {
            isFinished = true
        }
    }
}
