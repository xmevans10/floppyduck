import SwiftUI

struct HomeView: View {
    @EnvironmentObject var manager: GameManager
    @EnvironmentObject var auth: AuthManager
    @State private var titlePulse: Bool = false
    @State private var titleFlashOffset: CGFloat = -180

    private let icons = PixelIconFactory.shared

    var body: some View {
        ZStack {
            // Sky gradient background
            LinearGradient(
                colors: [GK.Colors.skyTop, GK.Colors.skyBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Ground strip at bottom
            VStack(spacing: 0) {
                Spacer()
                Rectangle()
                    .fill(GK.Colors.grassLight)
                    .frame(height: 6)
                Rectangle()
                    .fill(GK.Colors.groundTan)
                    .frame(height: 50)
            }
            .ignoresSafeArea(edges: .bottom)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer().frame(height: 54)

                    // Title
                    titleSection
                        .padding(.top, 2)

                    // Bread counter
                    breadCounter
                        .padding(.top, 16)

                    accountBadge
                        .padding(.top, 10)

                    Spacer().frame(height: 22)

                    // Play button (expandable)
                    playSection
                        .padding(.horizontal, 40)

                    Spacer().frame(height: 16)

                    // Bottom row: Shop, Stats, Settings, Share
                    bottomButtons
                        .padding(.horizontal, 32)

                    Spacer().frame(height: 24)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            SoundManager.shared.startMenuMusic()
        }
        .onDisappear {
            SoundManager.shared.stopMenuMusic()
        }
    }

    // MARK: - Title

    private var titleSection: some View {
        VStack(spacing: 4) {
            titleLine("FLOPPY", color: .white, size: 30)
            titleLine("DUCK", color: GK.Colors.scoreYellow, size: 30)
        }
        .overlay {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.clear, Color.white.opacity(0.55), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 86, height: 74)
                .rotationEffect(.degrees(14))
                .offset(x: titleFlashOffset)
                .blendMode(.screen)
                .allowsHitTesting(false)
        }
        .clipped()
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                titlePulse = true
            }
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
            .scaleEffect(titlePulse ? 1.04 : 0.98)
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
            // Classic — primary action
            subModeButton(
                icon: .classic,
                title: "CLASSIC",
                subtitle: "Solo Run",
                color: GK.Colors.buttonGreen
            ) {
                SoundManager.shared.play(.button)
                manager.startGame(GameModeConfig(mode: .classic))
            }

            // VS Bot ladder
            subModeButton(
                icon: .bot,
                title: "VS BOT",
                subtitle: "Bot Ladder",
                color: GK.Colors.buttonBlue
            ) {
                SoundManager.shared.play(.button)
                manager.navigate(to: .botLadder)
            }

            // Head to Head
            subModeButton(
                icon: .trophy,
                title: "HEAD TO HEAD",
                subtitle: "Quick / Ranked / Room",
                color: GK.Colors.buttonOrange
            ) {
                SoundManager.shared.play(.button)
                manager.navigate(to: .multiplayerModes)
            }
        }
    }

    private func subModeButton(icon: PixelIcon, title: String, subtitle: String, color: Color, action: @escaping () -> Void) -> some View {
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

                Image(uiImage: PixelIconFactory.shared.image(for: .play, pixelScale: 2.0))
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
    }

    // MARK: - Bottom Buttons (4 buttons)

    private var bottomButtons: some View {
        HStack(spacing: 10) {
            bottomButton(icon: .shop, label: "SHOP") {
                manager.navigate(to: .shop)
            }

            bottomButton(icon: .stats, label: "STATS") {
                manager.navigate(to: .stats)
            }

            bottomButton(icon: .settings, label: "SETTINGS") {
                manager.navigate(to: .settings)
            }

            bottomButton(icon: .share, label: "SHARE") {
                shareApp()
            }
        }
    }

    private func bottomButton(icon: PixelIcon, label: String, action: @escaping () -> Void) -> some View {
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
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func pixelIcon(_ icon: PixelIcon, size: CGFloat) -> some View {
        Image(uiImage: icons.image(for: icon))
            .interpolation(.none)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
    }

    private func shareApp() {
        let text = "Check out Floppy Duck! 🦆 Can you beat my high score of \(manager.stats.bestScore)?"
        let vc = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(vc, animated: true)
        }
    }
}
