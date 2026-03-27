import SwiftUI

struct HomeView: View {
    @EnvironmentObject var manager: GameManager
    @EnvironmentObject var auth: AuthManager
    @State private var titleFlashOffset: CGFloat = -180

    private let icons = PixelIconFactory.shared

    @State private var cloudOffset: CGFloat = 0
    @State private var showSignInPrompt: Bool = false

    private var isGuest: Bool { auth.isGuest }

    var body: some View {
        ZStack {
            // Enhanced 8-bit sky background
            homeBackground
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer().frame(height: 54)

                    // Title
                    titleSection
                        .padding(.top, 2)

                    // Bread counter + best score
                    HStack(spacing: 12) {
                        breadCounter
                        bestScoreBadge
                    }
                    .padding(.top, 16)

                    accountBadge
                        .padding(.top, 10)

                    Spacer().frame(height: 22)

                    // Play button (expandable)
                    playSection
                        .padding(.horizontal, 40)

                    Spacer().frame(height: 16)

                    // Bottom row: Shop, Collection, Achievements, Stats, Settings
                    bottomButtons
                        .padding(.horizontal, 32)

                    Spacer().frame(height: 24)
                }
            }
        }
        .navigationBarHidden(true)
        .alert("Sign In to Unlock", isPresented: $showSignInPrompt) {
            Button("NOT NOW", role: .cancel) {}
            Button("SIGN IN WITH APPLE") {
                Task { await auth.signInWithApple() }
            }
        } message: {
            Text("Sign in with Apple to access all game features. Classic and Quick Play are always free to play.")
        }
    }

    // MARK: - Title

    private var titleSection: some View {
        // Base text (visible color)
        VStack(spacing: 4) {
            titleLine("FLOPPY", color: .white, size: 30)
            titleLine("DUCK", color: GK.Colors.scoreYellow, size: 30)
        }
        .overlay {
            // Sheen masked to letter shapes — no bounding box, shaped precisely to text
            VStack(spacing: 4) {
                titleLine("FLOPPY", color: .white, size: 30)
                titleLine("DUCK", color: GK.Colors.scoreYellow, size: 30)
            }
            .mask {
                VStack(spacing: 4) {
                    Text("FLOPPY")
                        .font(.custom(GK.pixelFontName, size: 30))
                    Text("DUCK")
                        .font(.custom(GK.pixelFontName, size: 30))
                }
            }
            .overlay {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color.white.opacity(0.15),
                                Color.white.opacity(0.65),
                                Color.white.opacity(0.15),
                                Color.clear,
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 50, height: 100)
                    .rotationEffect(.degrees(14))
                    .offset(x: titleFlashOffset)
                    .blendMode(.screen)
                    .allowsHitTesting(false)
            }
            .mask {
                VStack(spacing: 4) {
                    Text("FLOPPY")
                        .font(.custom(GK.pixelFontName, size: 30))
                    Text("DUCK")
                        .font(.custom(GK.pixelFontName, size: 30))
                }
            }
        }
        .onAppear {
            // Item 4: Respect reduce motion accessibility setting
            guard !UIAccessibility.isReduceMotionEnabled else { return }
            withAnimation(.linear(duration: 1.65).repeatForever(autoreverses: false)) {
                titleFlashOffset = 180
            }
        }
    }

    private func titleLine(_ text: String, color: Color, size: CGFloat) -> some View {
        Text(text)
            .font(.custom(GK.pixelFontName, size: size))
            .foregroundColor(color)
            .shadow(color: GK.Colors.pipeBorder, radius: 0, x: 4, y: 4)
            .shadow(color: Color.black.opacity(0.35), radius: 0, x: 0, y: 2)
    }

    // MARK: - 8-bit Home Background

    private var homeBackground: some View {
        GeometryReader { geo in
            ZStack {
                // Rich sky gradient
                LinearGradient(
                    stops: [
                        .init(color: Color(red: 0.22, green: 0.50, blue: 0.85), location: 0.0),
                        .init(color: Color(red: 0.38, green: 0.65, blue: 0.90), location: 0.3),
                        .init(color: Color(red: 0.58, green: 0.80, blue: 0.94), location: 0.6),
                        .init(color: Color(red: 0.78, green: 0.92, blue: 0.97), location: 0.85),
                        .init(color: Color(red: 0.90, green: 0.95, blue: 0.98), location: 1.0),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
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
                            .opacity([0.7, 0.85, 0.6, 0.75, 0.65, 0.8][i])
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

                // Distant pixel hills
                VStack {
                    Spacer()
                    Image(uiImage: TextureFactory.shared.hillsUIImage())
                        .interpolation(.none)
                        .resizable()
                        .frame(height: 80)
                        .opacity(0.5)
                        .offset(y: -50)
                }

                // Ground at bottom — layered grass + dirt
                VStack(spacing: 0) {
                    Spacer()

                    // Dark grass edge
                    Rectangle()
                        .fill(Color(red: 0.28, green: 0.52, blue: 0.16))
                        .frame(height: 3)

                    // Grass
                    Rectangle()
                        .fill(Color(red: 0.40, green: 0.72, blue: 0.22))
                        .frame(height: 14)

                    // Dirt with subtle pixel pattern
                    ZStack {
                        Rectangle()
                            .fill(Color(red: 0.78, green: 0.70, blue: 0.50))
                        // Subtle diagonal stripe effect
                        Rectangle()
                            .fill(Color(red: 0.72, green: 0.64, blue: 0.44).opacity(0.4))
                    }
                    .frame(height: 45)
                }
            }
        }
    }

    // MARK: - Bread Counter

    private var breadCounter: some View {
        HStack(spacing: 10) {
            Image(uiImage: TextureFactory.shared.breadUIImage(pixelScale: 4.0))
                .interpolation(.none)
                .resizable()
                .frame(width: 32, height: 26)

            Text("\(manager.stats.bread)")
                .font(.custom(GK.pixelFontName, size: 16))
                .foregroundColor(GK.Colors.breadGold)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.35))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(GK.Colors.breadGold.opacity(0.3), lineWidth: 2)
                )
        )
        .accessibilityLabel("Bread: \(manager.stats.bread)")
    }

    private var bestScoreBadge: some View {
        HStack(spacing: 6) {
            Image(uiImage: icons.image(for: .trophy, pixelScale: 3.0))
                .interpolation(.none)
                .resizable()
                .frame(width: 20, height: 20)

            Text("\(manager.stats.bestScore)")
                .font(.custom(GK.pixelFontName, size: 16))
                .foregroundColor(GK.Colors.buttonOrange)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.35))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(GK.Colors.buttonOrange.opacity(0.3), lineWidth: 2)
                )
        )
        .accessibilityLabel("Best score: \(manager.stats.bestScore)")
    }

    private var accountBadge: some View {
        HStack(spacing: 6) {
            pixelIcon(auth.isAppleLinked ? .trophy : .classic, size: 14)
            Text(auth.accountBadgeText)
                .font(.custom(GK.pixelFontName, size: 7))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.3))
                .overlay(
                    Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - Play Section

    private var playSection: some View {
        VStack(spacing: 10) {
            // Classic — always available
            subModeButton(
                icon: .classic,
                title: "CLASSIC",
                subtitle: "Solo Run",
                color: GK.Colors.buttonGreen
            ) {
                SoundManager.shared.play(.button)
                manager.startGame(GameModeConfig(mode: .classic))
            }

            // VS Bot ladder — sign in required
            subModeButton(
                icon: .bot,
                title: "VS BOT",
                subtitle: isGuest ? "Sign in to unlock" : "Bot Ladder",
                color: GK.Colors.buttonBlue,
                locked: isGuest
            ) {
                if isGuest {
                    showSignInPrompt = true
                } else {
                    SoundManager.shared.play(.button)
                    manager.navigate(to: .botLadder)
                }
            }

            // Head to Head — always accessible (Quick Play available inside)
            subModeButton(
                icon: .headToHead,
                title: "HEAD TO HEAD",
                subtitle: "Quick / Ranked / Room",
                color: GK.Colors.buttonOrange
            ) {
                SoundManager.shared.play(.button)
                manager.navigate(to: .multiplayerModes)
            }
        }
    }

    private func subModeButton(icon: PixelIcon, title: String, subtitle: String, color: Color, locked: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                pixelIcon(icon, size: 22)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.custom(GK.pixelFontName, size: 11))
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.custom(GK.pixelFontName, size: 7))
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()

                Image(uiImage: PixelIconFactory.shared.image(for: locked ? .lock : .play, pixelScale: 2.0))
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 14, height: 14)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
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
        .opacity(locked ? 0.5 : 1.0)
        .accessibilityLabel(locked ? "\(title), sign in to unlock" : "\(title), \(subtitle)")
    }

    // MARK: - Bottom Buttons (5 buttons)

    private var bottomButtons: some View {
        HStack(spacing: 8) {
            bottomButton(icon: .shop, label: "SHOP", locked: isGuest) {
                if isGuest { showSignInPrompt = true; return }
                SoundManager.shared.play(.button)
                manager.navigate(to: .shop)
            }

            bottomButton(icon: .collection, label: "COLLECTION", locked: isGuest) {
                if isGuest { showSignInPrompt = true; return }
                SoundManager.shared.play(.button)
                manager.navigate(to: .collection)
            }

            bottomButton(icon: .trophy, label: "ACHIEVE", locked: isGuest) {
                if isGuest { showSignInPrompt = true; return }
                SoundManager.shared.play(.button)
                manager.navigate(to: .achievements)
            }

            bottomButton(icon: .stats, label: "STATS", locked: isGuest) {
                if isGuest { showSignInPrompt = true; return }
                SoundManager.shared.play(.button)
                manager.navigate(to: .stats)
            }

            bottomButton(icon: .settings, label: "SETTINGS") {
                SoundManager.shared.play(.button)
                manager.navigate(to: .settings)
            }
        }
    }

    private func bottomButton(icon: PixelIcon, label: String, locked: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                pixelIcon(icon, size: 24)
                Text(label)
                    .font(.custom(GK.pixelFontName, size: 5))
                    .foregroundColor(GK.Colors.panelBorder)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(GK.Colors.panelCream)
                    .shadow(color: Color.black.opacity(0.15), radius: 0, x: 0, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(GK.Colors.panelBorder, lineWidth: 2)
            )
            .overlay(alignment: .topTrailing) {
                if locked {
                    Image(uiImage: PixelIconFactory.shared.image(for: .lock, pixelScale: 1.5))
                        .interpolation(.none)
                        .resizable()
                        .frame(width: 10, height: 10)
                        .padding(4)
                }
            }
        }
        .buttonStyle(.plain)
        .opacity(locked ? 0.45 : 1.0)
        .accessibilityLabel(locked ? "\(label), sign in to unlock" : label)
    }

    // MARK: - Helpers



}
