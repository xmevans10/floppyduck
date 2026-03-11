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

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 16) {
                // Title text — coin-flip spin via Y-axis 3D rotation
                Text("FLOPPY DUCK")
                    .font(.custom(GK.pixelFontName, size: 32))
                    .foregroundColor(.yellow)
                    .shadow(color: .orange, radius: 0, x: 2, y: 2)
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
        .onAppear { runSequence() }
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

    // MARK: - Animation Sequence (~4.5s total)

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

        // Phase 2: Coin-flip spin (0.7s → 1.2s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.easeInOut(duration: 0.5)) {
                coinAngle = 360
            }
        }

        // Phase 3: Second spin for extra flair (1.4s → 1.8s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            hasCoinSounded = false  // Reset for second coin sound
            withAnimation(.easeInOut(duration: 0.4)) {
                coinAngle = 720
            }
        }

        // Phase 4: Subtitle fades in (2.0s → 2.3s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeIn(duration: 0.3)) {
                subtitleOpacity = 1
            }
        }

        // Phase 5: Hold visible — let it breathe (2.3s → 3.8s)

        // Phase 6: Fade out everything (3.8s → 4.2s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.8) {
            withAnimation(.easeOut(duration: 0.4)) {
                titleOpacity = 0
                subtitleOpacity = 0
            }
        }

        // Phase 7: Transition to game (~4.5s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
            finish()
        }
    }

    private func finish() {
        guard !isFinished else { return }
        isFinished = true
    }
}
