import SwiftUI

/// Minimalistic retro splash screen shown on app launch.
///
/// Animation sequence (~2s total):
/// 1. Black screen → sky gradient fades in              (0.5s)
/// 2. Pixel duck drops from above with spring bounce     (0.4s)
/// 3. On landing → quack sound + medium haptic
/// 4. "FLOPPY DUCK" title scales up with spring          (0.3s)
/// 5. Brief hold                                         (0.4s)
/// 6. Everything slides up and out                       (0.35s)
struct SplashView: View {
    @Binding var isFinished: Bool

    // MARK: - Animation State

    @State private var showSky = false
    @State private var duckLanded = false
    @State private var showTitle = false
    @State private var exitSlide = false

    // Duck starts off-screen above
    private let duckDropDistance: CGFloat = -300

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

            // 2 ─ Content group (slides up on exit)
            VStack(spacing: 16) {
                Spacer()

                // Pixel duck
                Image(uiImage: TextureFactory.shared.skinDuckUIImage(
                    skin: SkinManager.shared.selectedSkin,
                    pixelScale: 9.0
                ))
                .interpolation(.none)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 140, height: 140)
                .offset(y: duckLanded ? 0 : duckDropDistance)

                // Title
                VStack(spacing: 2) {
                    Text("FLOPPY")
                        .font(.custom(GK.pixelFontName, size: 30))
                        .foregroundColor(.white)
                        .shadow(color: GK.Colors.pipeBorder, radius: 0, x: 3, y: 3)

                    Text("DUCK")
                        .font(.custom(GK.pixelFontName, size: 30))
                        .foregroundColor(GK.Colors.scoreYellow)
                        .shadow(color: GK.Colors.pipeBorder, radius: 0, x: 3, y: 3)
                }
                .scaleEffect(showTitle ? 1.0 : 0.0)
                .opacity(showTitle ? 1.0 : 0.0)

                Spacer()
            }
            .offset(y: exitSlide ? -UIScreen.main.bounds.height : 0)
        }
        .onAppear(perform: runSequence)
    }

    // MARK: - Animation Sequence

    private func runSequence() {
        // Phase 1 — Sky fades in (0–0.5s)
        withAnimation(.easeIn(duration: 0.5)) {
            showSky = true
        }

        // Phase 2 — Duck drops with spring bounce (at 0.45s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.55, blendDuration: 0)) {
                duckLanded = true
            }
        }

        // Phase 3 — Quack + haptic on landing (at 0.75s, when spring roughly settles)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
            SoundManager.shared.play(.quack)
            Haptic.splash()
        }

        // Phase 4 — Title scales up (at 0.9s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0)) {
                showTitle = true
            }
        }

        // Phase 5 — Hold, then slide everything up (at 1.55s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.55) {
            withAnimation(.easeIn(duration: 0.35)) {
                exitSlide = true
            }
        }

        // Phase 6 — Mark finished (at 1.95s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.95) {
            isFinished = true
        }
    }
}
