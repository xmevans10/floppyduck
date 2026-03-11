import SwiftUI

/// Minimal splash: black screen → duck pops up → coin-flip spin → quack → proceed.
struct SplashView: View {
    @Binding var isFinished: Bool

    // MARK: - Animation State

    @State private var duckScale: CGFloat = 0
    @State private var coinAngle: Double = 0
    @State private var duckOpacity: Double = 1
    @State private var hasQuacked = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Duck sprite — coin-flip spin via Y-axis 3D rotation
            Image(uiImage: TextureFactory.shared.duckUIImage(pixelScale: 8.0))
                .interpolation(.none)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 120, height: 90)
                .scaleEffect(duckScale)
                .rotation3DEffect(.degrees(coinAngle), axis: (0, 1, 0))
                .opacity(duckOpacity)
        }
        .onAppear { runSequence() }
        // Detect mid-spin to play quack at the right moment
        .onChange(of: coinAngle) { angle in
            if angle >= 180 && !hasQuacked {
                hasQuacked = true
                SoundManager.shared.play(.quack)
                Haptic.splashImpact()
            }
        }
        // Allow tap to skip at any time
        .onTapGesture { finish() }
        // Accessibility: skip animation entirely
        .accessibilityAction(named: "Skip") { finish() }
    }

    // MARK: - Animation Sequence

    private func runSequence() {
        // Phase 1: Duck pops in with spring bounce (0 → 0.3s)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.55, blendDuration: 0)) {
            duckScale = 1.0
        }

        // Phase 2: Coin-flip spin (0.5s → 1.1s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 0.6)) {
                coinAngle = 360
            }
        }

        // Phase 3: Hold briefly, then fade out and finish (1.4s → 1.9s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.easeOut(duration: 0.4)) {
                duckOpacity = 0
            }
        }

        // Phase 4: Transition to game
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) {
            finish()
        }
    }

    private func finish() {
        guard !isFinished else { return }
        isFinished = true
    }
}
