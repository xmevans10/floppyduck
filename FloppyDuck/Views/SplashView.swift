import SwiftUI

/// Splash screen — sky background, duck pops in, title appears, auto-transitions.
/// Matches HomeView's bright retro pixel aesthetic.
struct SplashView: View {
    @Binding var isFinished: Bool

    // MARK: - Animation State

    @State private var duckScale: CGFloat = 0.1
    @State private var duckOpacity: Double = 0
    @State private var titleOpacity: Double = 0
    @State private var subtitleOpacity: Double = 0

    // MARK: - Body

    var body: some View {
        ZStack {
            // Sky gradient matching HomeView
            LinearGradient(
                stops: [
                    .init(color: Color(red: 0.22, green: 0.50, blue: 0.85), location: 0.0),
                    .init(color: Color(red: 0.38, green: 0.65, blue: 0.90), location: 0.3),
                    .init(color: Color(red: 0.58, green: 0.80, blue: 0.94), location: 0.6),
                    .init(color: Color(red: 0.78, green: 0.92, blue: 0.97), location: 0.85),
                    .init(color: Color(red: 0.90, green: 0.95, blue: 0.98), location: 1.0),
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 28) {
                // Duck sprite
                Image(uiImage: TextureFactory.shared.duckUIImage(pixelScale: 8.0))
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 90)
                    .scaleEffect(duckScale)
                    .opacity(duckOpacity)
                    .shadow(color: GK.Colors.pipeBorder.opacity(0.3), radius: 0, x: 3, y: 3)

                // Title
                VStack(spacing: 4) {
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
                .opacity(titleOpacity)

                // Subtitle
                Text("TAP TO FLAP")
                    .font(.custom(GK.pixelFontName, size: 10))
                    .foregroundColor(.white.opacity(0.5))
                    .opacity(subtitleOpacity)
            }
        }
        .onAppear {
            TextureFactory.shared.preWarm()
            PixelIconFactory.shared.preWarm()
            runSequence()
        }
        .onTapGesture { finish() }
        .accessibilityAction(named: "Skip") { finish() }
    }

    // MARK: - Animation Sequence (~5 s)

    private func runSequence() {
        // 0.0 s — Duck pops in with spring
        withAnimation(.spring(response: 0.50, dampingFraction: 0.60)) {
            duckScale = 1.0
            duckOpacity = 1
        }

        // 0.8 s — Coin SFX + haptic
        after(0.80) {
            SoundManager.shared.play(.coin)
            Haptic.splashCoin()
        }

        // 1.2 s — Title fades in
        after(1.20) {
            withAnimation(.easeOut(duration: 0.30)) { titleOpacity = 1 }
        }

        // 1.8 s — Second coin SFX + haptic
        after(1.80) {
            SoundManager.shared.play(.coin)
            Haptic.splashCoin()
        }

        // 2.2 s — Subtitle fades in
        after(2.20) {
            withAnimation(.easeIn(duration: 0.30)) { subtitleOpacity = 1 }
        }

        // 4.2 s — Fade everything out
        after(4.20) {
            withAnimation(.easeOut(duration: 0.40)) {
                duckOpacity = 0
                titleOpacity = 0
                subtitleOpacity = 0
            }
        }

        // 4.8 s — Transition
        after(4.80) { finish() }
    }

    // MARK: - Helpers

    private func after(_ seconds: Double, _ work: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    private func finish() {
        guard !isFinished else { return }
        isFinished = true
    }
}
