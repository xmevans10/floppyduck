import SwiftUI

// MARK: - Onboarding Auth Action (file-private)

private enum OnboardingAuthAction {
    case guest, apple
}

// MARK: - Pages Enum

private enum OnboardingPage: Int, CaseIterable {
    case welcome = 0
    case namePicker = 1
    case howToPlay = 2
    case authChoice = 3
}

// MARK: - Main Onboarding Container

struct AuthOnboardingView: View {
    @EnvironmentObject var manager: GameManager
    @EnvironmentObject var auth: AuthManager

    @State private var currentPage: OnboardingPage = .welcome
    @State private var busyAction: OnboardingAuthAction?
    @State private var username: String = ""

    private var isUsernameValid: Bool {
        let trimmed = username.trimmingCharacters(in: .whitespaces)
        return trimmed.count >= 2 && trimmed.count <= 16
    }

    var body: some View {
        ZStack {
            // Shared sky background
            OnboardingSkyBackground()
                .ignoresSafeArea()

            // Page content
            Group {
                switch currentPage {
                case .welcome:
                    WelcomePage {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            currentPage = .namePicker
                        }
                    }
                case .namePicker:
                    NamePickerPage(
                        username: $username,
                        isUsernameValid: isUsernameValid,
                        onContinue: {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                currentPage = .howToPlay
                            }
                        },
                        onBack: {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                currentPage = .welcome
                            }
                        }
                    )
                case .howToPlay:
                    HowToPlayPage(
                        onContinue: {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                currentPage = .authChoice
                            }
                        },
                        onBack: {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                currentPage = .namePicker
                            }
                        }
                    )
                case .authChoice:
                    AuthChoicePage(
                        busyAction: $busyAction,
                        onGuest: {
                            commitUsername()
                            busyAction = .guest
                            Task {
                                await auth.continueAsGuest()
                                busyAction = nil
                            }
                        },
                        onApple: {
                            commitUsername()
                            busyAction = .apple
                            Task {
                                await auth.signInWithApple()
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

    private func commitUsername() {
        let trimmed = username.trimmingCharacters(in: .whitespaces)
        if trimmed.count >= 2 {
            manager.playerName = trimmed
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

// MARK: - Shared Sky Background

private struct OnboardingSkyBackground: View {
    @State private var cloudOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            ZStack {
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

                // Scrolling pixel clouds
                HStack(spacing: 60) {
                    ForEach(0..<6, id: \.self) { i in
                        Image(uiImage: TextureFactory.shared.cloudUIImage())
                            .interpolation(.none)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: [70, 90, 55, 80, 65, 95][i],
                                   height: [28, 36, 22, 32, 26, 38][i])
                            .opacity([0.55, 0.65, 0.45, 0.6, 0.5, 0.6][i])
                            .offset(y: [0, -20, 15, -35, 5, -15][i])
                    }
                }
                .offset(x: cloudOffset)
                .onAppear {
                    guard !UIAccessibility.isReduceMotionEnabled else { return }
                    withAnimation(.linear(duration: 30).repeatForever(autoreverses: false)) {
                        cloudOffset = -300
                    }
                }
                .frame(maxHeight: geo.size.height * 0.4, alignment: .top)
                .padding(.top, 40)

                // Ground
                VStack(spacing: 0) {
                    Spacer()
                    Rectangle()
                        .fill(Color(red: 0.28, green: 0.52, blue: 0.16))
                        .frame(height: 3)
                    Rectangle()
                        .fill(Color(red: 0.40, green: 0.72, blue: 0.22))
                        .frame(height: 14)
                    Rectangle()
                        .fill(Color(red: 0.78, green: 0.70, blue: 0.50))
                        .frame(height: 45)
                }
            }
        }
    }
}

// MARK: - Page 1: Welcome

private struct WelcomePage: View {
    let onContinue: () -> Void

    @State private var duckBounce: CGFloat = 0
    @State private var duckRotation: Double = 0
    @State private var titleFlashOffset: CGFloat = -180
    @State private var subtitleOpacity: Double = 0
    @State private var tapPromptOpacity: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Bouncing duck
            Image(uiImage: TextureFactory.shared.duckUIImage(pixelScale: 6.0))
                .interpolation(.none)
                .resizable()
                .frame(width: 108, height: 81)
                .rotationEffect(.degrees(duckRotation))
                .offset(y: duckBounce)
                .onAppear {
                    guard !UIAccessibility.isReduceMotionEnabled else { return }
                    withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                        duckBounce = -12
                    }
                    withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                        duckRotation = 5
                    }
                }
                .padding(.bottom, 20)

            // Title with sheen
            VStack(spacing: 4) {
                titleLine("FLOPPY", color: .white, size: 30)
                titleLine("DUCK", color: GK.Colors.scoreYellow, size: 30)
            }
            .overlay {
                VStack(spacing: 4) {
                    titleLine("FLOPPY", color: .white, size: 30)
                    titleLine("DUCK", color: GK.Colors.scoreYellow, size: 30)
                }
                .mask {
                    VStack(spacing: 4) {
                        Text("FLOPPY").font(.custom(GK.pixelFontName, size: 30))
                        Text("DUCK").font(.custom(GK.pixelFontName, size: 30))
                    }
                }
                .overlay {
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [.clear, .white.opacity(0.15), .white.opacity(0.65), .white.opacity(0.15), .clear],
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .frame(width: 50, height: 100)
                        .rotationEffect(.degrees(14))
                        .offset(x: titleFlashOffset)
                        .blendMode(.screen)
                        .allowsHitTesting(false)
                }
                .mask {
                    VStack(spacing: 4) {
                        Text("FLOPPY").font(.custom(GK.pixelFontName, size: 30))
                        Text("DUCK").font(.custom(GK.pixelFontName, size: 30))
                    }
                }
            }
            .onAppear {
                guard !UIAccessibility.isReduceMotionEnabled else { return }
                withAnimation(.linear(duration: 1.65).repeatForever(autoreverses: false)) {
                    titleFlashOffset = 180
                }
            }

            Text("WELCOME, NEW FLAPPER!")
                .font(.custom(GK.pixelFontName, size: 8))
                .foregroundColor(.white.opacity(0.8))
                .padding(.top, 16)
                .opacity(subtitleOpacity)
                .onAppear {
                    withAnimation(.easeIn(duration: 0.6).delay(0.4)) {
                        subtitleOpacity = 1
                    }
                }

            Spacer()

            // Tap prompt
            VStack(spacing: 6) {
                Image(uiImage: PixelIconFactory.shared.image(for: .tapHand, pixelScale: 3.0))
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 24, height: 24)

                Text("TAP TO BEGIN")
                    .font(.custom(GK.pixelFontName, size: 8))
                    .foregroundColor(.white.opacity(0.6))
            }
            .opacity(tapPromptOpacity)
            .onAppear {
                withAnimation(.easeIn(duration: 0.5).delay(0.8)) {
                    tapPromptOpacity = 1
                }
            }
            .padding(.bottom, 60)
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
            .shadow(color: Color.black.opacity(0.35), radius: 0, x: 0, y: 2)
    }
}

// MARK: - Page 2: Name Picker

private struct NamePickerPage: View {
    @Binding var username: String
    let isUsernameValid: Bool
    let onContinue: () -> Void
    let onBack: () -> Void

    @State private var appearedSuggestions = false

    private let nameSuggestions = [
        "FlapJack", "BreadBaron", "QuackAttack",
        "SirFlaps", "DizzyBird", "CrumbLord",
        "CloudDuck", "PipeDodger",
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Back button
            HStack {
                onboardingBackButton(action: onBack)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            Spacer()

            // Duck
            Image(uiImage: TextureFactory.shared.duckUIImage(pixelScale: 4.0))
                .interpolation(.none)
                .resizable()
                .frame(width: 72, height: 54)
                .padding(.bottom, 10)

            Text("WHO ARE YOU?")
                .font(.custom(GK.pixelFontName, size: 18))
                .foregroundColor(.white)
                .shadow(color: GK.Colors.pipeBorder, radius: 0, x: 2, y: 2)
                .padding(.bottom, 4)

            Text("EVERY DUCK NEEDS A NAME")
                .font(.custom(GK.pixelFontName, size: 7))
                .foregroundColor(.white.opacity(0.7))
                .padding(.bottom, 20)

            // Name input
            VStack(spacing: 8) {
                PixelTextField(text: $username, pixelFontName: GK.pixelFontName,
                               fontSize: 14, maxLength: 16)
                    .frame(height: 44)
                    .padding(.horizontal, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(isUsernameValid
                                            ? GK.Colors.buttonGreen.opacity(0.6)
                                            : GK.Colors.panelBorder.opacity(0.15),
                                            lineWidth: 2)
                            )
                    )
                    .shadow(color: Color.black.opacity(0.12), radius: 4, y: 2)

                HStack {
                    if !username.isEmpty && !isUsernameValid {
                        Text("2–16 CHARACTERS")
                            .font(.custom(GK.pixelFontName, size: 6))
                            .foregroundColor(GK.Colors.buttonRed.opacity(0.8))
                    }
                    Spacer()
                    Text("\(username.count)/16")
                        .font(.custom(GK.pixelFontName, size: 6))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 16)

            // Random name chips
            VStack(spacing: 6) {
                Text("OR PICK ONE")
                    .font(.custom(GK.pixelFontName, size: 6))
                    .foregroundColor(.white.opacity(0.55))

                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 6),
                    GridItem(.flexible(), spacing: 6),
                ], spacing: 6) {
                    ForEach(Array(nameSuggestions.enumerated()), id: \.offset) { index, name in
                        Button {
                            SoundManager.shared.play(.button)
                            Haptic.buttonTap()
                            username = name
                        } label: {
                            Text(name.uppercased())
                                .font(.custom(GK.pixelFontName, size: 7))
                                .foregroundColor(username == name ? .white : GK.Colors.panelBorder)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(username == name
                                              ? GK.Colors.buttonBlue
                                              : GK.Colors.panelCream)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(username == name
                                                ? GK.Colors.buttonBlue.opacity(0.8)
                                                : GK.Colors.panelBorder.opacity(0.3),
                                                lineWidth: 1.5)
                                )
                        }
                        .buttonStyle(.plain)
                        .scaleEffect(appearedSuggestions ? 1 : 0.7)
                        .opacity(appearedSuggestions ? 1 : 0)
                        .animation(
                            .spring(response: 0.4, dampingFraction: 0.65).delay(Double(index) * 0.05),
                            value: appearedSuggestions
                        )
                    }
                }
                .padding(.horizontal, 32)
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    appearedSuggestions = true
                }
            }

            Spacer()

            // Continue button
            onboardingContinueButton(title: "NEXT", color: GK.Colors.buttonGreen, enabled: isUsernameValid) {
                SoundManager.shared.play(.button)
                Haptic.buttonTap()
                onContinue()
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 60)
        }
    }
}

// MARK: - Page 3: How To Play

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
        VStack(spacing: 0) {
            HStack {
                onboardingBackButton(action: onBack)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            Spacer()

            Text("HOW TO PLAY")
                .font(.custom(GK.pixelFontName, size: 20))
                .foregroundColor(.white)
                .shadow(color: GK.Colors.pipeBorder, radius: 0, x: 2, y: 2)
                .padding(.bottom, 6)

            Text("IT'S SIMPLE, REALLY")
                .font(.custom(GK.pixelFontName, size: 7))
                .foregroundColor(.white.opacity(0.7))
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
    }

    private func tipCard(icon: PixelIcon, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(uiImage: PixelIconFactory.shared.image(for: icon, pixelScale: 3.5))
                .interpolation(.none)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.custom(GK.pixelFontName, size: 9))
                    .foregroundColor(GK.Colors.panelBorder)

                Text(subtitle)
                    .font(.custom(GK.pixelFontName, size: 6))
                    .foregroundColor(GK.Colors.panelBorder.opacity(0.7))
                    .lineSpacing(2)
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
    let onGuest: () -> Void
    let onApple: () -> Void
    let statusMessage: String?
    let onBack: () -> Void

    @State private var buttonsAppeared = false

    private var anyBusy: Bool { busyAction != nil }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                onboardingBackButton(action: onBack)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            Spacer()

            Image(uiImage: TextureFactory.shared.duckUIImage(pixelScale: 5.0))
                .interpolation(.none)
                .resizable()
                .frame(width: 90, height: 68)
                .padding(.bottom, 10)

            Text("ONE LAST THING")
                .font(.custom(GK.pixelFontName, size: 18))
                .foregroundColor(.white)
                .shadow(color: GK.Colors.pipeBorder, radius: 0, x: 2, y: 2)
                .padding(.bottom, 4)

            Text("HOW DO YOU WANT TO PLAY?")
                .font(.custom(GK.pixelFontName, size: 7))
                .foregroundColor(.white.opacity(0.7))
                .padding(.bottom, 24)

            // Auth buttons
            VStack(spacing: 12) {
                authOptionButton(
                    icon: .classic,
                    title: "PLAY AS GUEST",
                    subtitle: "Classic + Quick Play",
                    color: GK.Colors.buttonGreen,
                    isBusy: busyAction == .guest,
                    action: onGuest
                )
                .scaleEffect(buttonsAppeared ? 1 : 0.85)
                .opacity(buttonsAppeared ? 1 : 0)
                .animation(.spring(response: 0.45, dampingFraction: 0.7).delay(0.1), value: buttonsAppeared)

                authOptionButton(
                    icon: .trophy,
                    title: "SIGN IN WITH APPLE",
                    subtitle: "All modes + cloud sync",
                    color: GK.Colors.buttonBlue,
                    isBusy: busyAction == .apple,
                    action: onApple
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

            // Fine print
            Text("Classic and Quick Play are always free.\nSign in to unlock ranked, bots & cloud sync.")
                .font(.custom(GK.pixelFontName, size: 6))
                .foregroundColor(.white.opacity(0.55))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
                .padding(.top, 14)

            if let statusMessage {
                Text(statusMessage)
                    .font(.custom(GK.pixelFontName, size: 7))
                    .foregroundColor(GK.Colors.scoreYellow)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                    .padding(.top, 8)
            }

            Spacer()

            // Spacer for page dots
            Spacer().frame(height: 50)
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
                        .font(.custom(GK.pixelFontName, size: 9))
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.custom(GK.pixelFontName, size: 7))
                        .foregroundColor(.white.opacity(0.75))
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
            .font(.custom(GK.pixelFontName, size: 12))
            .foregroundColor(.white)
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
