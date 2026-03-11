import SwiftUI

/// Splash: black screen → duck pops up with overshoot → fast coin-flip spin →
/// coin sound → "FLOPPY DUCK" title pops in → hold → fade out → proceed.
struct SplashView: View {
    @Binding var isFinished: Bool

    // MARK: - Animation State

    @State private var duckScale: CGFloat = 0
    @State private var coinAngle: Double = 0
    @State private var duckOpacity: Double = 1
    @State private var hasCoinSounded = false

    // Title text
    @State private var titleOpacity: Double = 0
    @State private var titleScale: CGFloat = 0.7

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                // Duck sprite — coin-flip spin via Y-axis 3D rotation
                Image(uiImage: TextureFactory.shared.duckUIImage(pixelScale: 8.0))
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 90)
                    .scaleEffect(duckScale)
                    .rotation3DEffect(.degrees(coinAngle), axis: (0, 1, 0))
                    .opacity(duckOpacity)

                // Title pops in after the spin
                Text("FLOPPY DUCK")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundColor(.yellow)
                    .opacity(titleOpacity)
                    .scaleEffect(titleScale)
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

    // MARK: - Animation Sequence (~3.5s total)

    private func runSequence() {
        // Phase 1: Duck pops in with exaggerated spring overshoot (0 → ~0.4s)
        // Lower damping = bigger bounce; target 1.15 overshoots past final size
        withAnimation(.spring(response: 0.35, dampingFraction: 0.45, blendDuration: 0)) {
            duckScale = 1.15
        }

        // Phase 1b: Settle scale back to 1.0 (0.35s → 0.55s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.easeOut(duration: 0.2)) {
                duckScale = 1.0
            }
        }

        // Phase 2: Fast coin-flip spin (0.55s → 0.9s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            withAnimation(.easeInOut(duration: 0.35)) {
                coinAngle = 360
            }
        }

        // Phase 3: Title pops in with spring (1.1s → ~1.5s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0)) {
                titleOpacity = 1
                titleScale = 1.0
            }
            Haptic.splashTitlePop()
        }

        // Phase 4: Hold visible — let it breathe (1.5s → 2.8s)

        // Phase 5: Fade out everything (2.8s → 3.2s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
            withAnimation(.easeOut(duration: 0.4)) {
                duckOpacity = 0
                titleOpacity = 0
            }
        }

        // Phase 6: Transition to game (~3.5s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            finish()
        }
    }

    private func finish() {
        guard !isFinished else { return }
        isFinished = true
    }
}
