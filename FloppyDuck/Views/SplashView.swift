import SwiftUI

/// Splash: black screen → "FLOPPY DUCK" title coin-flips in with coin sound →
/// hold → fade out → proceed.  Title-only, no duck sprite.
struct SplashView: View {
    @Binding var isFinished: Bool

    // MARK: - Animation State

    // Title text
    @State private var titleScale: CGFloat = 0
    @State private var titleOpacity: Double = 0
    @State private var coinAngle: Double = 0
    @State private var hasCoinSounded = false

    // Subtitle
    @State private var subtitleOpacity: Double = 0

    // Shine effect
    @State private var shineOffset: CGFloat = -1.0

    /// Gradient stop locations must be in ascending order within [0, 1].
    /// shineOffset starts at −1 and animates to 1.2, so we clamp each stop.
    private func clampedShineStops() -> [Gradient.Stop] {
        let lo = max(0, min(1, shineOffset - 0.2))
        let mid = max(0, min(1, shineOffset))
        let hi = max(0, min(1, shineOffset + 0.2))
        return [
            .init(color: .black, location: 0),
            .init(color: .black, location: lo),
            .init(color: .white, location: mid),
            .init(color: .black, location: hi),
            .init(color: .black, location: 1)
        ]
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 16) {
                // Title text — coin-flip spin via Y-axis 3D rotation with shiny metallic mask
                Text("FLOPPY DUCK")
                    .font(.custom(GK.pixelFontName, size: 34))
                    .foregroundColor(.yellow)
                    .shadow(color: .orange, radius: 0, x: 2, y: 2)
                    .mask(
                        LinearGradient(
                            stops: clampedShineStops(),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(titleScale)
                    .rotation3DEffect(.degrees(coinAngle), axis: (0, 1, 0))
                    .opacity(titleOpacity)

                // Subtle tagline
                Text("TAP TO FLAP")
                    .font(.custom(GK.pixelFontName, size: 10))
                    .foregroundColor(.white.opacity(0.6))
                    .opacity(subtitleOpacity)
            }
        }
        .onAppear {
            // Pre-warm textures on background thread while splash animation plays.
            // This avoids the ~30s synchronous render hitch on first game start.
            TextureFactory.shared.preWarm()
            PixelIconFactory.shared.preWarm()
            runSequence()
        }
        // Detect mid-spin to play coin sound at the right moment
        .onChange(of: coinAngle) { angle in
            if angle >= 180 && !hasCoinSounded {
                hasCoinSounded = true
                SoundManager.shared.play(.coin)
                Haptic.splashCoin()
            }
        }
        // Allow tap to skip at any time
        .onTapGesture { finish() }
        // Accessibility: skip animation entirely
        .accessibilityAction(named: "Skip") { finish() }
    }

    // MARK: - Animation Sequence (~5.0s total)

    private func runSequence() {
        // Phase 1: Title pops in with big spring overshoot (0 → ~0.5s)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.5, blendDuration: 0)) {
            titleScale = 1.15
            titleOpacity = 1
        }

        // Phase 1b: Settle scale back to 1.0 (0.4s → 0.6s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeOut(duration: 0.2)) {
                titleScale = 1.0
            }
        }

        // Phase 2: Coin-flip spin & Shine (+0.5s delay requested = 1.2s start)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeInOut(duration: 0.5)) {
                coinAngle = 360
            }
            withAnimation(.linear(duration: 0.6)) {
                shineOffset = 1.2
            }
        }

        // Phase 3: Second spin for extra flair (1.9s → 2.3s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) {
            hasCoinSounded = false  // Reset for second coin sound
            withAnimation(.easeInOut(duration: 0.4)) {
                coinAngle = 720
            }
            // Reset and trigger a second shine
            shineOffset = -1.0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.linear(duration: 0.5)) {
                    shineOffset = 1.2
                }
            }
        }

        // Phase 4: Subtitle fades in (2.5s → 2.8s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeIn(duration: 0.3)) {
                subtitleOpacity = 1
            }
        }

        // Phase 5: Hold visible — let it breathe (2.8s → 4.3s)

        // Phase 6: Fade out everything (4.3s → 4.7s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.3) {
            withAnimation(.easeOut(duration: 0.4)) {
                titleOpacity = 0
                subtitleOpacity = 0
            }
        }

        // Phase 7: Transition to game (~5.0s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            finish()
        }
    }

    private func finish() {
        guard !isFinished else { return }
        isFinished = true
    }
}
