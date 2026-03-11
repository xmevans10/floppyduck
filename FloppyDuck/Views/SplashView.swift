import SwiftUI

/// Supercell-inspired cinematic splash screen (~4.5s).
///
/// Sequence:
/// 1. Black → studio badge fades in ("A FLOPPY DUCK GAME") + heavy haptic
/// 2. Badge fades out → sky gradient reveals → decorative pipes grow in from edges
/// 3. Duck bounces in from left with trail → quack + haptic on landing
/// 4. "FLOPPY" slams in from above → "DUCK" punches up from below → haptics
/// 5. Shimmer sweep + "TAP TO START" pulse + pixel ground grows in
/// 6. Tap to proceed (or auto-advance at 5s) → zoom-out transition
struct SplashView: View {
    @Binding var isFinished: Bool

    // MARK: - Animation State

    // Phase 1: Studio badge
    @State private var showBadge = false
    @State private var badgePulse = false

    // Phase 2: Sky + environment
    @State private var showSky = false
    @State private var pipeScale: CGFloat = 0
    @State private var showClouds = false

    // Phase 3: Duck entrance
    @State private var duckOffset: CGFloat = -300
    @State private var duckLanded = false
    @State private var showTrail = false
    @State private var trailOpacity: Double = 0.8

    // Phase 4: Title slam
    @State private var floppyOffset: CGFloat = -200
    @State private var floppyScale: CGFloat = 1.3
    @State private var duckTitleOffset: CGFloat = 200
    @State private var duckTitleScale: CGFloat = 1.3
    @State private var showFloppy = false
    @State private var showDuckTitle = false

    // Phase 5: Shimmer + ground + tap prompt
    @State private var shimmerOffset: CGFloat = -300
    @State private var showShimmer = false
    @State private var groundHeight: CGFloat = 0
    @State private var showTapPrompt = false
    @State private var tapPulse = false

    // Phase 6: Exit
    @State private var exitZoom: CGFloat = 1.0
    @State private var exitOpacity: Double = 1.0
    @State private var canTap = false
    @State private var autoAdvanceTask: DispatchWorkItem?

    var body: some View {
        ZStack {
            // ── Background layers ──
            Color.black.ignoresSafeArea()

            // Sky gradient (reveals in Phase 2)
            LinearGradient(
                colors: [GK.Colors.skyTop, GK.Colors.skyBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .opacity(showSky ? 1 : 0)

            // ── Phase 1: Studio badge ──
            studioBadge
                .opacity(showBadge && !showSky ? 1 : 0)

            // ── Phase 2+: Environment ──
            if showSky {
                environmentLayer
            }

            // ── Phase 3: Duck entrance ──
            if duckLanded || duckOffset > -300 {
                duckEntrance
            }

            // ── Phase 4: Title ──
            titleLayer

            // ── Phase 5: Shimmer + tap prompt ──
            if showShimmer {
                shimmerLayer
            }

            if showTapPrompt {
                tapPromptLayer
            }

            // ── Ground strip ──
            VStack {
                Spacer()
                groundStrip
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .scaleEffect(exitZoom)
        .opacity(exitOpacity)
        .contentShape(Rectangle())
        .onTapGesture {
            guard canTap else { return }
            triggerExit()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Floppy Duck splash screen")
        .onAppear(perform: runSequence)
    }

    // MARK: - Studio Badge (Phase 1)

    private var studioBadge: some View {
        VStack(spacing: 12) {
            // Decorative pixel border
            HStack(spacing: 4) {
                ForEach(0..<7, id: \.self) { _ in
                    Rectangle()
                        .fill(GK.Colors.scoreYellow.opacity(0.6))
                        .frame(width: 6, height: 6)
                }
            }

            Text("A")
                .font(.custom(GK.pixelFontName, size: 8))
                .foregroundColor(.white.opacity(0.5))

            Text("FLOPPY DUCK")
                .font(.custom(GK.pixelFontName, size: 14))
                .foregroundColor(.white)
                .shadow(color: GK.Colors.scoreYellow.opacity(0.4), radius: 8, x: 0, y: 0)

            Text("GAME")
                .font(.custom(GK.pixelFontName, size: 8))
                .foregroundColor(.white.opacity(0.5))

            HStack(spacing: 4) {
                ForEach(0..<7, id: \.self) { _ in
                    Rectangle()
                        .fill(GK.Colors.scoreYellow.opacity(0.6))
                        .frame(width: 6, height: 6)
                }
            }
        }
        .scaleEffect(badgePulse ? 1.02 : 1.0)
    }

    // MARK: - Environment (Phase 2)

    private var environmentLayer: some View {
        ZStack {
            // Clouds drifting in
            if showClouds {
                cloudLayer
            }

            // Decorative pipes from edges
            HStack {
                // Left pipe
                VStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: [GK.Colors.pipeGreen, GK.Colors.pipeDarkGreen],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(GK.Colors.pipeBorder, lineWidth: 2)
                        )
                        .frame(width: 36, height: 140 * pipeScale)
                    // Pipe cap
                    RoundedRectangle(cornerRadius: 3)
                        .fill(GK.Colors.pipeGreen)
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(GK.Colors.pipeBorder, lineWidth: 2)
                        )
                        .frame(width: 44, height: 16)
                    Spacer()
                        .frame(height: 200)
                }
                .offset(x: -4)

                Spacer()

                // Right pipe (top)
                VStack {
                    Spacer()
                        .frame(height: 80)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(GK.Colors.pipeGreen)
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(GK.Colors.pipeBorder, lineWidth: 2)
                        )
                        .frame(width: 44, height: 16)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: [GK.Colors.pipeGreen, GK.Colors.pipeDarkGreen],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(GK.Colors.pipeBorder, lineWidth: 2)
                        )
                        .frame(width: 36, height: 180 * pipeScale)
                    Spacer()
                }
                .offset(x: 4)
            }
            .opacity(pipeScale > 0 ? 1 : 0)
        }
    }

    private var cloudLayer: some View {
        ZStack {
            // Pixel cloud shapes at different depths
            pixelCloud(width: 70, height: 24)
                .offset(x: -90, y: -240)
                .opacity(0.8)

            pixelCloud(width: 55, height: 18)
                .offset(x: 100, y: -180)
                .opacity(0.6)

            pixelCloud(width: 45, height: 16)
                .offset(x: -40, y: -120)
                .opacity(0.5)
        }
        .transition(.opacity)
    }

    private func pixelCloud(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(.white.opacity(0.85))
            .frame(width: width, height: height)
    }

    // MARK: - Duck Entrance (Phase 3)

    private var duckEntrance: some View {
        ZStack {
            // Trail particles (small pixel dots behind duck)
            if showTrail {
                ForEach(0..<5, id: \.self) { i in
                    Circle()
                        .fill(GK.Colors.scoreYellow)
                        .frame(width: CGFloat(8 - i), height: CGFloat(8 - i))
                        .offset(
                            x: duckLanded ? CGFloat(-30 - i * 18) : CGFloat(-200 - i * 20),
                            y: CGFloat(i % 2 == 0 ? -5 : 5)
                        )
                        .opacity(trailOpacity * Double(5 - i) / 5.0)
                }
            }

            // Duck sprite
            Image(uiImage: TextureFactory.shared.skinDuckUIImage(
                skin: SkinManager.shared.selectedSkin,
                pixelScale: 9.0
            ))
            .interpolation(.none)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 140, height: 140)
            .offset(x: duckLanded ? 0 : duckOffset)
            .scaleEffect(duckLanded ? 1.0 : 0.85)
            .rotationEffect(.degrees(duckLanded ? 0 : -12))
            .accessibilityLabel("Floppy Duck mascot")
        }
        .offset(y: -20)
    }

    // MARK: - Title (Phase 4)

    private var titleLayer: some View {
        VStack(spacing: 4) {
            // "FLOPPY" — slams down from above
            Text("FLOPPY")
                .font(.custom(GK.pixelFontName, size: 36))
                .foregroundColor(.white)
                .shadow(color: GK.Colors.pipeBorder, radius: 0, x: 4, y: 4)
                .shadow(color: Color.black.opacity(0.4), radius: 0, x: 0, y: 3)
                .scaleEffect(showFloppy ? 1.0 : floppyScale)
                .offset(y: showFloppy ? 0 : floppyOffset)
                .opacity(showFloppy ? 1.0 : 0.0)

            // "DUCK" — punches up from below
            Text("DUCK")
                .font(.custom(GK.pixelFontName, size: 36))
                .foregroundColor(GK.Colors.scoreYellow)
                .shadow(color: GK.Colors.pipeBorder, radius: 0, x: 4, y: 4)
                .shadow(color: Color.black.opacity(0.4), radius: 0, x: 0, y: 3)
                .scaleEffect(showDuckTitle ? 1.0 : duckTitleScale)
                .offset(y: showDuckTitle ? 0 : duckTitleOffset)
                .opacity(showDuckTitle ? 1.0 : 0.0)
        }
        .offset(y: 110)
    }

    // MARK: - Shimmer (Phase 5)

    private var shimmerLayer: some View {
        VStack(spacing: 4) {
            Text("FLOPPY")
                .font(.custom(GK.pixelFontName, size: 36))
            Text("DUCK")
                .font(.custom(GK.pixelFontName, size: 36))
        }
        .foregroundColor(.clear)
        .offset(y: 110)
        .overlay {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.white.opacity(0.12),
                            Color.white.opacity(0.65),
                            Color.white.opacity(0.12),
                            Color.clear,
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 60, height: 120)
                .rotationEffect(.degrees(14))
                .offset(x: shimmerOffset, y: 110)
                .blendMode(.screen)
                .allowsHitTesting(false)
                .mask {
                    VStack(spacing: 4) {
                        Text("FLOPPY")
                            .font(.custom(GK.pixelFontName, size: 36))
                        Text("DUCK")
                            .font(.custom(GK.pixelFontName, size: 36))
                    }
                    .offset(y: 110)
                }
        }
    }

    // MARK: - Tap Prompt (Phase 5)

    private var tapPromptLayer: some View {
        VStack {
            Spacer()
            Text("TAP  TO  START")
                .font(.custom(GK.pixelFontName, size: 10))
                .foregroundColor(.white.opacity(tapPulse ? 0.9 : 0.4))
                .shadow(color: GK.Colors.pipeBorder.opacity(0.5), radius: 0, x: 1, y: 1)
                .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: tapPulse)
                .padding(.bottom, 100)
        }
        .transition(.opacity)
    }

    // MARK: - Ground Strip

    private var groundStrip: some View {
        VStack(spacing: 0) {
            // Grass stripe
            Rectangle()
                .fill(GK.Colors.grassGreen)
                .frame(height: 6)
            // Dirt
            Rectangle()
                .fill(GK.Colors.groundTan)
                .frame(height: groundHeight)
        }
    }

    // MARK: - Animation Sequence

    private func runSequence() {
        let reduceMotion = UIAccessibility.isReduceMotionEnabled

        if reduceMotion {
            showSky = true
            duckLanded = true
            showFloppy = true
            showDuckTitle = true
            groundHeight = 50
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                SoundManager.shared.play(.quack)
                Haptic.splashImpact()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                isFinished = true
            }
            return
        }

        // ── Phase 1: Studio badge (0–1.0s) ──
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeIn(duration: 0.4)) {
                showBadge = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            Haptic.splashImpact()
            // Subtle pulse on badge
            withAnimation(.easeInOut(duration: 0.3)) {
                badgePulse = true
            }
        }

        // ── Phase 2: Sky reveal + pipes (1.0–1.8s) ──
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeIn(duration: 0.5)) {
                showBadge = false
            }
            withAnimation(.easeOut(duration: 0.6)) {
                showSky = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                pipeScale = 1.0
            }
            withAnimation(.easeOut(duration: 0.4)) {
                showClouds = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.easeOut(duration: 0.3)) {
                groundHeight = 50
            }
        }

        // ── Phase 3: Duck entrance (1.8–2.6s) ──
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            showTrail = true
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6, blendDuration: 0)) {
                duckLanded = true
                duckOffset = 0
            }
        }

        // Quack on landing (at ~2.1s when spring roughly settles)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.1) {
            SoundManager.shared.play(.quack)
            Haptic.splashImpact()
        }

        // Fade trail
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.3) {
            withAnimation(.easeOut(duration: 0.4)) {
                trailOpacity = 0
            }
        }

        // ── Phase 4: Title slam (2.6–3.4s) ──
        // "FLOPPY" drops from above
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.5, blendDuration: 0)) {
                showFloppy = true
                floppyOffset = 0
                floppyScale = 1.0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.75) {
            Haptic.splashTitlePop()
        }

        // "DUCK" punches up from below
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.95) {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.5, blendDuration: 0)) {
                showDuckTitle = true
                duckTitleOffset = 0
                duckTitleScale = 1.0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.1) {
            Haptic.splashImpact()
        }

        // ── Phase 5: Shimmer + tap prompt (3.4–4.2s) ──
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.4) {
            showShimmer = true
            withAnimation(.easeInOut(duration: 0.55)) {
                shimmerOffset = 300
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.6) {
            Haptic.splashShimmer()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.8) {
            withAnimation(.easeIn(duration: 0.3)) {
                showTapPrompt = true
            }
            // Start pulsing
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                tapPulse = true
            }
            canTap = true
        }

        // ── Phase 6: Auto-advance fallback (at 5.5s) ──
        let autoAdvance = DispatchWorkItem { [self] in
            triggerExit()
        }
        autoAdvanceTask = autoAdvance
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.5, execute: autoAdvance)
    }

    // MARK: - Exit Transition

    private func triggerExit() {
        guard canTap else { return }
        canTap = false
        autoAdvanceTask?.cancel()

        SoundManager.shared.play(.button)
        Haptic.splashImpact()

        // Zoom out and fade
        withAnimation(.easeIn(duration: 0.35)) {
            exitZoom = 1.15
            exitOpacity = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            isFinished = true
        }
    }
}
