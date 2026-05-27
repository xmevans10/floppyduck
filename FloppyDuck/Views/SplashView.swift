import SwiftUI

/// Splash screen — black background, title slides in, quack SFX, "tap to flap" subtitle, then transitions.
struct SplashView: View {
    @Binding var isFinished: Bool

    // MARK: - Animation State

    @State private var titleOffset: CGFloat = -300
    @State private var titleOpacity: Double = 0
    @State private var subtitleOpacity: Double = 0
    @State private var subtitleScale: CGFloat = 0.6
    @State private var fadeOut: Double = 1.0
    @State private var assetsReady = false
    @State private var quackPlayed = false

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 20) {
                // Title
                VStack(spacing: 4) {
                    Text("FLOPPY")
                        .font(.custom(GK.pixelFontName, size: 30))
                        .foregroundColor(.white)
                        .shadow(color: GK.Colors.scoreYellow.opacity(0.6), radius: 8, x: 0, y: 0)
                        .shadow(color: GK.Colors.scoreYellow.opacity(0.3), radius: 16, x: 0, y: 0)
                    Text("DUCK")
                        .font(.custom(GK.pixelFontName, size: 30))
                        .foregroundColor(GK.Colors.scoreYellow)
                        .shadow(color: GK.Colors.scoreYellow.opacity(0.6), radius: 8, x: 0, y: 0)
                        .shadow(color: GK.Colors.scoreYellow.opacity(0.3), radius: 16, x: 0, y: 0)
                }
                .offset(y: titleOffset)
                .opacity(titleOpacity)

                // Subtitle
                Text("TAP TO FLAP")
                    .font(.custom(GK.pixelFontName, size: 10))
                    .foregroundColor(.white.opacity(0.45))
                    .scaleEffect(subtitleScale)
                    .opacity(subtitleOpacity)
            }
        }
        .opacity(fadeOut)
        .onAppear {
            preWarmAssets()
            runSequence()
        }
        .onTapGesture {
            if !quackPlayed {
                quackPlayed = true
                SoundManager.shared.play(.quack)
            }
            finish()
        }
        .accessibilityAction(named: "Skip") { finish() }
    }

    // MARK: - Animation Sequence

    private func runSequence() {
        // 0.3 s — Title slides down from above with spring
        after(0.30) {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.65)) {
                titleOffset = 0
                titleOpacity = 1
            }
        }

        // 0.9 s — Haptic when title lands
        after(0.90) {
            Haptic.splashCoin()
        }

        // 1.6 s — Subtitle pops in
        after(1.60) {
            withAnimation(.spring(response: 0.40, dampingFraction: 0.55)) {
                subtitleOpacity = 1
                subtitleScale = 1.0
            }
        }

        // 3.8 s — Fade everything out
        after(3.80) {
            withAnimation(.easeOut(duration: 0.35)) {
                fadeOut = 0
            }
        }

        // 4.3 s — Transition
        after(4.30) { finish() }
    }

    // MARK: - Helpers

    private func after(_ seconds: Double, _ work: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    private func preWarmAssets() {
        let group = DispatchGroup()

        group.enter()
        TextureFactory.shared.preWarm {
            group.leave()
        }

        group.enter()
        PixelIconFactory.shared.preWarm {
            group.leave()
        }

        group.enter()
        SoundManager.shared.preWarmGameplayAssets {
            group.leave()
        }

        group.notify(queue: .main) {
            assetsReady = true
        }
    }

    private func finish() {
        guard !isFinished else { return }
        // Hold the splash until first-run gameplay assets are actually cached
        // and SpriteKit has preloaded textures onto the render side.
        guard assetsReady && TextureFactory.shared.isPreWarmed else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [self] in
                finish()
            }
            return
        }
        isFinished = true
    }
}
