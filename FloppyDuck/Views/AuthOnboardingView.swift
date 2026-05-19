import SwiftUI

// MARK: - Onboarding Auth Action (file-private)

private enum OnboardingAuthAction {
    case gameCenter
    case guest
}

// MARK: - Pages Enum

private enum OnboardingPage: Int, CaseIterable {
    case welcome = 0
    case howToPlay = 1
    case authChoice = 2
}

// MARK: - Main Onboarding Container

struct AuthOnboardingView: View {
    @EnvironmentObject var manager: GameManager
    @EnvironmentObject var auth: AuthManager

    @State private var currentPage: OnboardingPage = .welcome
    @State private var busyAction: OnboardingAuthAction?

    var body: some View {
        ZStack {
            // Shared sky background
            GeometryReader { geo in
                Image(uiImage: UIImage(named: "floppy_theme") ?? UIImage())
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            }
            .ignoresSafeArea()

            // Pixel-art clouds (same as HomeView menu)
            cloudLayer

            // Page content
            Group {
                switch currentPage {
                case .welcome:
                    WelcomePage {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            currentPage = .howToPlay
                        }
                    }
                case .howToPlay:
                    HowToPlayPage(
                        onContinue: {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                currentPage = .authChoice
                            }
                        },
                        onBack: {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                currentPage = .welcome
                            }
                        }
                    )
                case .authChoice:
                    AuthChoicePage(
                        busyAction: $busyAction,
                        onGameCenter: {
                            busyAction = .gameCenter
                            Task {
                                await auth.signInWithGameCenter()
                                busyAction = nil
                            }
                        },
                        onGuest: {
                            busyAction = .guest
                            Task {
                                await auth.continueAsGuest()
                                busyAction = nil
                            }
                        },
                        statusMessage: auth.statusMessage,
                        onBack: {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                currentPage = .howToPlay
                            }
                        }
                    )
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))

            // Page dots
            VStack {
                Spacer()
                OnboardingPageDots(current: currentPage)
                    .padding(.bottom, 28)
            }
        }
    }

    // MARK: - Cloud Layer (same pixel-art clouds as HomeView)

    private var cloudLayer: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack {
                PixelCloud(scale: 1.0, yOffset: 12, duration: 22, screenWidth: w)
                PixelCloud(scale: 0.65, yOffset: 0, duration: 29, screenWidth: w)
                PixelCloud(scale: 1.2, yOffset: 24, duration: 25, screenWidth: w)
                PixelCloud(scale: 0.8, yOffset: 40, duration: 32, screenWidth: w)
                PixelCloud(scale: 0.5, yOffset: 30, duration: 27, screenWidth: w)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - Pixel Cloud

private struct PixelCloud: View {
    let scale: CGFloat
    let yOffset: CGFloat
    let duration: Double
    let screenWidth: CGFloat

    @State private var xOffset: CGFloat

    init(scale: CGFloat, yOffset: CGFloat, duration: Double, screenWidth: CGFloat) {
        self.scale = scale
        self.yOffset = yOffset
        self.duration = duration
        self.screenWidth = screenWidth
        let baseW: CGFloat = 90 * scale
        _xOffset = State(initialValue: -baseW)
    }

    var body: some View {
        Image(uiImage: TextureFactory.shared.cloudUIImage())
            .interpolation(.none)
            .resizable()
            .frame(width: 90 * scale, height: 40 * scale)
            .offset(x: xOffset, y: yOffset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .onAppear {
                guard !UIAccessibility.isReduceMotionEnabled else { return }
                withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                    xOffset = screenWidth + 90 * scale
                }
            }
    }
}

// MARK: - Page Dots

private struct OnboardingPageDots: View {
    let current: OnboardingPage

    var body: some View {
        HStack(spacing: 8) {
            ForEach(OnboardingPage.allCases, id: \.rawValue) { page in
                Capsule()
                    .fill(page == current ? Color.white : Color.white.opacity(0.35))
                    .frame(width: page == current ? 20 : 8, height: 8)
                    .animation(.spring(response: 0.35), value: current)
            }
        }
    }
}

// MARK: - Page 1: Welcome

private struct WelcomePage: View {
    let onContinue: () -> Void

    @State private var titleFlashOffset: CGFloat = -180
    @State private var subtitleOpacity: Double = 0
    @State private var tapPromptOpacity: Double = 0

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                Spacer().frame(height: max(24, geo.size.height * 0.30))

                // Title with sheen
                VStack(spacing: 4) {
                    titleLine("FLOPPY", color: .white, size: 36)
                    titleLine("DUCK", color: GK.Colors.scoreYellow, size: 36)
                }
                .frame(maxWidth: .infinity)
                .overlay {
                    VStack(spacing: 4) {
                        titleLine("FLOPPY", color: .white, size: 36)
                        titleLine("DUCK", color: GK.Colors.scoreYellow, size: 36)
                    }
                    .mask {
                        VStack(spacing: 4) {
                            Text("FLOPPY").font(.custom(GK.pixelFontName, size: 36))
                            Text("DUCK").font(.custom(GK.pixelFontName, size: 36))
                        }
                    }
                    .overlay {
                        Rectangle()
                            .fill(LinearGradient(
                                colors: [.clear, .white.opacity(0.15), .white.opacity(0.65), .white.opacity(0.15), .clear],
                                startPoint: .leading, endPoint: .trailing
                            ))
                            .frame(width: 60, height: 110)
                            .rotationEffect(.degrees(14))
                            .offset(x: titleFlashOffset)
                            .blendMode(.screen)
                            .allowsHitTesting(false)
                    }
                    .mask {
                        VStack(spacing: 4) {
                            Text("FLOPPY").font(.custom(GK.pixelFontName, size: 36))
                            Text("DUCK").font(.custom(GK.pixelFontName, size: 36))
                        }
                    }
                }
                .onAppear {
                    guard !UIAccessibility.isReduceMotionEnabled else { return }
                    withAnimation(.linear(duration: 1.65).repeatForever(autoreverses: false)) {
                        titleFlashOffset = 200
                    }
                }

                PixelOutlinedText(text: "WELCOME, NEW FLAPPER!", fontSize: 12,
                                  fillColor: GK.Colors.titleCream, outlineColor: GK.Colors.pipeBorder, outlineWidth: 2)
                    .padding(.top, 18)
                    .opacity(subtitleOpacity)
                    .onAppear {
                        withAnimation(.easeIn(duration: 0.6).delay(0.4)) {
                            subtitleOpacity = 1
                        }
                    }

                Spacer()

                // Tap prompt with subtle dark plate
                VStack(spacing: 6) {
                    Image(uiImage: PixelIconFactory.shared.image(for: .tapHand, pixelScale: 3.0))
                        .interpolation(.none)
                        .resizable()
                        .frame(width: 28, height: 28)

                    PixelOutlinedText(text: "TAP TO BEGIN", fontSize: 10,
                                      fillColor: GK.Colors.titleCream, outlineColor: GK.Colors.pipeBorder, outlineWidth: 1)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.2))
                )
                .opacity(tapPromptOpacity)
                .padding(.bottom, 40)
                .onAppear {
                    withAnimation(.easeIn(duration: 0.5).delay(0.8)) {
                        tapPromptOpacity = 1
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            SoundManager.shared.play(.button)
            Haptic.buttonTap()
            onContinue()
        }
        .accessibilityAction(named: "Continue") { onContinue() }
    }

    private func titleLine(_ text: String, color: Color, size: CGFloat) -> some View {
        Text(text)
            .font(.custom(GK.pixelFontName, size: size))
            .foregroundColor(color)
            .shadow(color: GK.Colors.pipeBorder, radius: 0, x: 4, y: 4)
            .shadow(color: GK.Colors.pipeBorder, radius: 0, x: -4, y: 4)
            .shadow(color: GK.Colors.pipeBorder, radius: 0, x: 4, y: -4)
            .shadow(color: GK.Colors.pipeBorder, radius: 0, x: -4, y: -4)
            .shadow(color: Color.black.opacity(0.25), radius: 0, x: 0, y: 6)
    }
}

// MARK: - Page 2: How To Play

private struct HowToPlayPage: View {
    let onContinue: () -> Void
    let onBack: () -> Void

    @State private var cardsAppeared = false

    private let tips: [(PixelIcon, String, String)] = [
        (.tapHand, "TAP TO FLAP", "Tap anywhere to keep\nyour duck airborne"),
        (.bread, "COLLECT BREAD", "Grab bread mid-flight\nto spend in the shop"),
        (.trophy, "RISE THE RANKS", "Challenge bots & friends\nto climb the ladder"),
    ]

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                HStack {
                    onboardingBackButton(action: onBack)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                Spacer().frame(height: max(10, geo.size.height * 0.22))

                Text("HOW TO PLAY")
                    .font(.custom(GK.pixelFontName, size: 24))
                    .foregroundColor(.white)
                    .shadow(color: GK.Colors.pipeBorder, radius: 0, x: 3, y: 3)
                    .shadow(color: GK.Colors.pipeBorder, radius: 0, x: -3, y: 3)
                    .shadow(color: GK.Colors.pipeBorder, radius: 0, x: 3, y: -3)
                    .shadow(color: GK.Colors.pipeBorder, radius: 0, x: -3, y: -3)
                    .padding(.bottom, 8)

                PixelOutlinedText(text: "IT'S SIMPLE, REALLY", fontSize: 9,
                                  fillColor: GK.Colors.titleCream, outlineColor: GK.Colors.pipeBorder, outlineWidth: 1.5)
                    .padding(.bottom, 24)

                // Tip cards
                VStack(spacing: 12) {
                    ForEach(Array(tips.enumerated()), id: \.offset) { index, tip in
                        tipCard(icon: tip.0, title: tip.1, subtitle: tip.2)
                            .offset(x: cardsAppeared ? 0 : (index % 2 == 0 ? -60 : 60))
                            .opacity(cardsAppeared ? 1 : 0)
                            .animation(
                                .spring(response: 0.5, dampingFraction: 0.75).delay(Double(index) * 0.12),
                                value: cardsAppeared
                            )
                    }
                }
                .padding(.horizontal, 28)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        cardsAppeared = true
                    }
                }

                Spacer()

                onboardingContinueButton(title: "ALMOST DONE", color: GK.Colors.buttonGreen, enabled: true) {
                    SoundManager.shared.play(.button)
                    Haptic.buttonTap()
                    onContinue()
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 60)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func tipCard(icon: PixelIcon, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(uiImage: PixelIconFactory.shared.image(for: icon, pixelScale: 3.5))
                .interpolation(.none)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.custom(GK.pixelFontName, size: 10))
                    .foregroundColor(GK.Colors.cardTextPrimary)

                Text(subtitle)
                    .font(.custom(GK.pixelFontName, size: 7))
                    .foregroundColor(GK.Colors.cardTextSecondary)
                    .lineSpacing(3)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(GK.Colors.panelCream)
                .shadow(color: Color.black.opacity(0.12), radius: 0, x: 0, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(GK.Colors.panelBorder.opacity(0.25), lineWidth: 2)
        )
    }
}

// MARK: - Page 4: Auth Choice

private struct AuthChoicePage: View {
    @Binding var busyAction: OnboardingAuthAction?
    let onGameCenter: () -> Void
    let onGuest: () -> Void
    let statusMessage: String?
    let onBack: () -> Void

    @State private var buttonsAppeared = false
    @State private var videoAppeared = false

    private var anyBusy: Bool { busyAction != nil }

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                HStack {
                    onboardingBackButton(action: onBack)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                Spacer().frame(height: max(10, geo.size.height * 0.08))

                // Looping gameplay preview
                LoopingVideoView(resourceName: "gameplay_preview", fileExtension: "mp4")
                    .frame(width: 160, height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.4), lineWidth: 2)
                    )
                    .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
                    .scaleEffect(videoAppeared ? 1 : 0.8)
                    .opacity(videoAppeared ? 1 : 0)
                    .onAppear {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                            videoAppeared = true
                        }
                    }
                    .padding(.bottom, 20)

                Text("READY TO PLAY?")
                    .font(.custom(GK.pixelFontName, size: 18))
                    .foregroundColor(.white)
                    .shadow(color: GK.Colors.pipeBorder, radius: 0, x: 2, y: 2)
                    .shadow(color: GK.Colors.pipeBorder, radius: 0, x: -2, y: 2)
                    .shadow(color: GK.Colors.pipeBorder, radius: 0, x: 2, y: -2)
                    .shadow(color: GK.Colors.pipeBorder, radius: 0, x: -2, y: -2)
                    .padding(.bottom, 6)

                Text("Choose how to get started")
                    .font(.custom(GK.pixelFontName, size: 8))
                    .foregroundColor(GK.Colors.titleCream.opacity(0.8))
                    .padding(.bottom, 28)

                // Auth buttons
                VStack(spacing: 10) {
                    authOptionButton(
                        icon: .trophy,
                        title: "GAME CENTER",
                        subtitle: "Sync scores & play ranked",
                        color: GK.Colors.buttonBlue,
                        isBusy: busyAction == .gameCenter,
                        action: onGameCenter
                    )
                    .scaleEffect(buttonsAppeared ? 1 : 0.85)
                    .opacity(buttonsAppeared ? 1 : 0)
                    .animation(.spring(response: 0.45, dampingFraction: 0.7).delay(0.1), value: buttonsAppeared)

                    authOptionButton(
                        icon: .play,
                        title: "PLAY AS GUEST",
                        subtitle: "Jump right in, sign in later",
                        color: Color(white: 0.35),
                        isBusy: busyAction == .guest,
                        action: onGuest
                    )
                    .scaleEffect(buttonsAppeared ? 1 : 0.85)
                    .opacity(buttonsAppeared ? 1 : 0)
                    .animation(.spring(response: 0.45, dampingFraction: 0.7).delay(0.2), value: buttonsAppeared)
                }
                .padding(.horizontal, 34)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        buttonsAppeared = true
                    }
                }

                if let statusMessage {
                    Text(statusMessage)
                        .font(.custom(GK.pixelFontName, size: 7))
                        .foregroundColor(GK.Colors.scoreYellow)
                        .shadow(color: GK.Colors.pipeBorder, radius: 0, x: 1, y: 1)
                        .shadow(color: GK.Colors.pipeBorder, radius: 0, x: -1, y: 1)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                        .padding(.top, 10)
                }

                Spacer()

                // Spacer for page dots
                Spacer().frame(height: 50)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func authOptionButton(icon: PixelIcon, title: String, subtitle: String,
                                   color: Color, isBusy: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(uiImage: PixelIconFactory.shared.image(for: icon, pixelScale: 2.5))
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.custom(GK.pixelFontName, size: 9))
                        .foregroundColor(.white)
                        .shadow(color: GK.Colors.pipeBorder, radius: 0, x: 1, y: 1)
                        .shadow(color: GK.Colors.pipeBorder, radius: 0, x: -1, y: 1)
                    Text(subtitle)
                        .font(.custom(GK.pixelFontName, size: 6.5))
                        .foregroundColor(GK.Colors.titleCream.opacity(0.85))
                }

                Spacer()

                if isBusy {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(color)
                    .shadow(color: color.opacity(0.4), radius: 0, x: 0, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(anyBusy)
        .opacity(anyBusy && !isBusy ? 0.5 : (anyBusy ? 0.8 : 1))
        .accessibilityLabel(title)
    }
}

// MARK: - Shared Onboarding Components

private func onboardingBackButton(action: @escaping () -> Void) -> some View {
    Button {
        SoundManager.shared.play(.button)
        action()
    } label: {
        Image(uiImage: PixelIconFactory.shared.image(for: .back, pixelScale: 2.5))
            .interpolation(.none)
            .resizable()
            .frame(width: 16, height: 16)
            .padding(10)
            .background(
                Circle()
                    .fill(Color.black.opacity(0.25))
                    .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
            )
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Back")
}

private func onboardingContinueButton(title: String, color: Color, enabled: Bool,
                                       action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Text(title)
            .font(.custom(GK.pixelFontName, size: 13))
            .foregroundColor(.white)
            .shadow(color: GK.Colors.pipeBorder, radius: 0, x: 2, y: 2)
            .shadow(color: GK.Colors.pipeBorder, radius: 0, x: -2, y: 2)
            .shadow(color: GK.Colors.pipeBorder, radius: 0, x: 2, y: -2)
            .shadow(color: GK.Colors.pipeBorder, radius: 0, x: -2, y: -2)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(color)
                    .shadow(color: color.opacity(0.5), radius: 0, x: 0, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.black.opacity(0.25), lineWidth: 2)
            )
    }
    .buttonStyle(.plain)
    .disabled(!enabled)
    .opacity(enabled ? 1 : 0.4)
}
