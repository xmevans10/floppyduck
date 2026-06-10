import AVFoundation
import SwiftUI
import UIKit

// MARK: - Onboarding Auth Action (file-private)

private enum OnboardingAuthAction {
    case gameCenter
    case guest
}

// MARK: - Pages Enum

private enum OnboardingPage: Int, CaseIterable {
    case welcome = 0
    case masterFlap = 1
    case authChoice = 2
}

private let onboardingPlateOpacity = 0.38

// MARK: - Main Onboarding Container

struct AuthOnboardingView: View {
    @EnvironmentObject var manager: GameManager
    @EnvironmentObject var auth: AuthManager

    @State private var currentPage: OnboardingPage = .welcome
    @State private var busyAction: OnboardingAuthAction?

    var body: some View {
        ZStack {
            GeometryReader { geo in
                Image(uiImage: UIImage(named: "floppy_theme") ?? UIImage())
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            }
            .ignoresSafeArea()

            cloudLayer

            Group {
                switch currentPage {
                case .welcome:
                    WelcomePage(onContinue: { advance(to: .masterFlap) })
                case .masterFlap:
                    MasterFlapPage(
                        onContinue: { advance(to: .authChoice) },
                        onBack: { advance(to: .welcome) }
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
                        showGameCenterSettingsAction: auth.needsGameCenterSettingsRecovery,
                        onOpenSettings: openSettings,
                        onBack: { advance(to: .masterFlap) }
                    )
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))

            VStack {
                Spacer()
                OnboardingPageDots(current: currentPage)
                    .padding(.bottom, 28)
            }
        }
        .onAppear {
            auth.refreshGameCenterAuthenticationState(reason: "onboarding_appear")
        }
    }

    private func advance(to page: OnboardingPage) {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
            currentPage = page
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

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

// MARK: - Story Pages

private struct WelcomePage: View {
    let onContinue: () -> Void

    @State private var titleFlashOffset: CGFloat = -180
    @State private var contentAppeared = false

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                Spacer().frame(height: max(24, geo.size.height * 0.14))

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
                                startPoint: .leading,
                                endPoint: .trailing
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
                .scaleEffect(contentAppeared ? 1 : 0.8)
                .opacity(contentAppeared ? 1 : 0)
                .animation(.spring(response: 0.55, dampingFraction: 0.55).delay(0.1), value: contentAppeared)

                Spacer()

                VStack(spacing: 16) {
                    welcomeLine("Tap to flap.")
                        .opacity(contentAppeared ? 1 : 0)
                        .scaleEffect(contentAppeared ? 1 : 0.7)
                        .offset(y: contentAppeared ? 0 : 22)
                        .animation(.spring(response: 0.5, dampingFraction: 0.58).delay(0.35), value: contentAppeared)

                    welcomeLine("Don't hit the pipes.")
                        .opacity(contentAppeared ? 1 : 0)
                        .scaleEffect(contentAppeared ? 1 : 0.7)
                        .offset(y: contentAppeared ? 0 : 22)
                        .animation(.spring(response: 0.5, dampingFraction: 0.58).delay(0.55), value: contentAppeared)
                }

                Spacer()

                onboardingContinueButton(title: "GET STARTED", color: GK.Colors.buttonGreen, enabled: true) {
                    SoundManager.shared.play(.button)
                    Haptic.buttonTap()
                    onContinue()
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 60)
                .opacity(contentAppeared ? 1 : 0)
                .animation(.easeOut(duration: 0.45).delay(0.85), value: contentAppeared)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear { contentAppeared = true }
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

    private func welcomeLine(_ text: String) -> some View {
        Text(text)
            .font(.custom(GK.pixelFontName, size: 15))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .shadow(color: GK.Colors.pipeBorder, radius: 0, x: 2, y: 2)
            .shadow(color: GK.Colors.pipeBorder, radius: 0, x: -2, y: 2)
            .shadow(color: GK.Colors.pipeBorder, radius: 0, x: 2, y: -2)
            .shadow(color: GK.Colors.pipeBorder, radius: 0, x: -2, y: -2)
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .background(onboardingCopyPlate())
    }
}

private struct MasterFlapPage: View {
    let onContinue: () -> Void
    let onBack: () -> Void

    @State private var appeared = false

    var body: some View {
        StoryPage(
            title: "HOW TO PLAY",
            subtitle: "Tap to fly. Grab bread along the way.",
            bodyText: nil,
            buttonTitle: "NEXT",
            onContinue: onContinue,
            onBack: onBack
        ) {
            OnboardingVideoCard()
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.94)
                .animation(.spring(response: 0.55, dampingFraction: 0.78).delay(0.1), value: appeared)
                .onAppear { appeared = true }
        }
    }
}

private struct StoryPage<Visual: View>: View {
    let title: String
    let subtitle: String
    let bodyText: String?
    let buttonTitle: String
    let onContinue: () -> Void
    let onBack: () -> Void
    @ViewBuilder let visual: () -> Visual

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                HStack {
                    onboardingBackButton(action: onBack)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                Spacer().frame(height: max(10, geo.size.height * 0.09))

                onboardingCopy(title: title, subtitle: subtitle, body: bodyText, compact: geo.size.height < 740)
                    .padding(.horizontal, 24)

                Spacer().frame(height: max(18, geo.size.height * 0.045))

                visual()
                    .padding(.horizontal, 30)

                Spacer()

                onboardingContinueButton(title: buttonTitle, color: GK.Colors.buttonGreen, enabled: true) {
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
}

// MARK: - Video

private struct OnboardingVideoCard: View {
    var body: some View {
        LoopingOnboardingVideo()
            .aspectRatio(1004.0 / 1614.0, contentMode: .fit)
            .frame(maxHeight: 330)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.black.opacity(0.35), lineWidth: 2)
            )
            .shadow(color: Color.black.opacity(0.3), radius: 0, x: 0, y: 5)
            .accessibilityLabel("Gameplay preview")
    }
}

private struct LoopingOnboardingVideo: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.playerLayer.videoGravity = .resizeAspectFill
        view.backgroundColor = .clear

        guard let url = Bundle.main.url(forResource: "onboarding_vid_final", withExtension: "mov") else {
            return view
        }

        let player = AVQueuePlayer()
        player.isMuted = true
        player.actionAtItemEnd = .none

        let item = AVPlayerItem(url: url)
        context.coordinator.player = player
        context.coordinator.looper = AVPlayerLooper(player: player, templateItem: item)
        view.playerLayer.player = player

        if !UIAccessibility.isReduceMotionEnabled {
            player.play()
        }

        return view
    }

    func updateUIView(_ view: PlayerContainerView, context: Context) {
        context.coordinator.player?.isMuted = true
        if UIAccessibility.isReduceMotionEnabled {
            context.coordinator.player?.pause()
        } else if context.coordinator.player?.timeControlStatus != .playing {
            context.coordinator.player?.play()
        }
    }

    static func dismantleUIView(_ uiView: PlayerContainerView, coordinator: Coordinator) {
        coordinator.player?.pause()
        coordinator.player = nil
        coordinator.looper = nil
    }

    final class Coordinator {
        var player: AVQueuePlayer?
        var looper: AVPlayerLooper?
    }

    final class PlayerContainerView: UIView {
        override static var layerClass: AnyClass {
            AVPlayerLayer.self
        }

        var playerLayer: AVPlayerLayer {
            layer as! AVPlayerLayer
        }
    }
}

// MARK: - Page 4: Auth Choice

private struct AuthChoicePage: View {
    @Binding var busyAction: OnboardingAuthAction?
    let onGameCenter: () -> Void
    let onGuest: () -> Void
    let statusMessage: String?
    let showGameCenterSettingsAction: Bool
    let onOpenSettings: () -> Void
    let onBack: () -> Void

    @State private var buttonsAppeared = false

    private var anyBusy: Bool { busyAction != nil }

    var body: some View {
        GeometryReader { geo in
            let compact = geo.size.height < 740
            VStack(spacing: 0) {
                HStack {
                    onboardingBackButton(action: onBack)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                Spacer().frame(height: max(10, geo.size.height * (compact ? 0.055 : 0.095)))

                onboardingCopy(
                    title: "MAKE IT YOURS",
                    subtitle: "Sign in to save everything you earn.",
                    body: nil,
                    compact: compact
                )
                .padding(.horizontal, 24)
                .padding(.bottom, compact ? 14 : 22)

                VStack(spacing: compact ? 7 : 9) {
                    onboardingPillLabel("KEEP YOUR BREAD & SKINS", fontSize: 9, horizontalPadding: 16, verticalPadding: 8)
                    onboardingPillLabel("RANKED & LEADERBOARDS", fontSize: 9, horizontalPadding: 16, verticalPadding: 8)
                    onboardingPillLabel("SYNC ACROSS DEVICES", fontSize: 9, horizontalPadding: 16, verticalPadding: 8)
                }
                .frame(maxWidth: 300)
                .padding(.horizontal, 26)
                .padding(.bottom, compact ? 16 : 24)

                VStack(spacing: compact ? 9 : 12) {
                    authOptionButton(
                        icon: .trophy,
                        title: "GAME CENTER",
                        subtitle: "SAVE BREAD, SKINS & RANKED",
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
                        subtitle: "FLAP NOW, SIGN IN LATER",
                        color: Color(red: 0.45, green: 0.45, blue: 0.50),
                        isBusy: busyAction == .guest,
                        action: onGuest
                    )
                    .scaleEffect(buttonsAppeared ? 1 : 0.85)
                    .opacity(buttonsAppeared ? 1 : 0)
                    .animation(.spring(response: 0.45, dampingFraction: 0.7).delay(0.2), value: buttonsAppeared)
                }
                .padding(.horizontal, 30)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        buttonsAppeared = true
                    }
                }

                if let statusMessage {
                    VStack(spacing: 8) {
                        Text(statusMessage)
                            .font(.custom(GK.pixelFontName, size: 8))
                            .foregroundColor(GK.Colors.scoreYellow)
                            .shadow(color: GK.Colors.pipeBorder, radius: 0, x: 1, y: 1)
                            .shadow(color: GK.Colors.pipeBorder, radius: 0, x: -1, y: 1)
                            .shadow(color: GK.Colors.pipeBorder, radius: 0, x: 1, y: -1)
                            .shadow(color: GK.Colors.pipeBorder, radius: 0, x: -1, y: -1)
                            .multilineTextAlignment(.center)

                        if showGameCenterSettingsAction {
                            Button(action: onOpenSettings) {
                                HStack(spacing: 6) {
                                    Image(uiImage: PixelIconFactory.shared.image(for: .settings, pixelScale: 1.8))
                                        .interpolation(.none)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 14, height: 14)
                                    Text("OPEN SETTINGS")
                                        .font(.custom(GK.pixelFontName, size: 8))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(GK.Colors.buttonBlue))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 30)
                    .padding(.top, 12)
                }

                Spacer()
                Spacer().frame(height: compact ? 34 : 50)
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
                    .frame(width: 22, height: 22)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.custom(GK.pixelFontName, size: 10))
                        .foregroundColor(.white)
                        .shadow(color: GK.Colors.pipeBorder, radius: 0, x: 1, y: 1)
                        .shadow(color: GK.Colors.pipeBorder, radius: 0, x: -1, y: 1)
                        .shadow(color: GK.Colors.pipeBorder, radius: 0, x: 1, y: -1)
                        .shadow(color: GK.Colors.pipeBorder, radius: 0, x: -1, y: -1)
                    Text(subtitle)
                        .font(.custom(GK.pixelFontName, size: 7))
                        .foregroundColor(GK.Colors.titleCream)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                }

                Spacer()

                if isBusy {
                    ProgressView().tint(.white)
                } else {
                    Image(uiImage: PixelIconFactory.shared.image(for: .play, pixelScale: 2.0))
                        .interpolation(.none)
                        .resizable()
                        .frame(width: 14, height: 14)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(color)
                    .shadow(color: color.opacity(0.5), radius: 0, x: 0, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.black.opacity(0.3), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .disabled(anyBusy)
        .opacity(anyBusy && !isBusy ? 0.5 : (anyBusy ? 0.8 : 1))
        .accessibilityLabel(title)
    }
}

// MARK: - Shared Onboarding Components

private func onboardingCopy(title: String?, subtitle: String, body: String?, compact: Bool) -> some View {
    VStack(spacing: compact ? 8 : 10) {
        if let title {
            Text(title)
                .font(.custom(GK.pixelFontName, size: compact ? 18 : 21))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.72)
                .shadow(color: GK.Colors.pipeBorder, radius: 0, x: 2, y: 2)
                .shadow(color: GK.Colors.pipeBorder, radius: 0, x: -2, y: 2)
                .shadow(color: GK.Colors.pipeBorder, radius: 0, x: 2, y: -2)
                .shadow(color: GK.Colors.pipeBorder, radius: 0, x: -2, y: -2)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(onboardingCopyPlate())
        }

        Text(subtitle)
            .font(.custom(GK.pixelFontName, size: compact ? 8 : 9))
            .foregroundColor(GK.Colors.titleCream)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.7)
            .shadow(color: Color.black.opacity(0.75), radius: 0, x: 1, y: 1)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(onboardingCopyPlate())

        if let body {
            Text(body)
                .font(.custom(GK.pixelFontName, size: compact ? 8 : 9))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .lineLimit(3)
                .minimumScaleFactor(0.72)
                .shadow(color: Color.black.opacity(0.85), radius: 0, x: 1, y: 1)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(onboardingCopyPlate())
        }
    }
    .frame(maxWidth: .infinity)
}

private func onboardingCopyPlate(opacity: Double = onboardingPlateOpacity) -> some View {
    RoundedRectangle(cornerRadius: 8)
        .fill(Color.black.opacity(opacity))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        )
}

private func onboardingPillLabel(_ text: String,
                                 fontSize: CGFloat,
                                 horizontalPadding: CGFloat,
                                 verticalPadding: CGFloat) -> some View {
    Text(text)
        .font(.custom(GK.pixelFontName, size: fontSize))
        .foregroundColor(GK.Colors.titleCream)
        .multilineTextAlignment(.center)
        .lineLimit(1)
        .minimumScaleFactor(0.72)
        .shadow(color: Color.black.opacity(0.75), radius: 0, x: 1, y: 1)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.28))
        )
}

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
