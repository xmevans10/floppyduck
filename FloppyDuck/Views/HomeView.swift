import SwiftUI

struct HomeView: View {
    @EnvironmentObject var manager: GameManager
    @ObservedObject var skinManager = SkinManager.shared
    @State private var playExpanded = false
    @State private var duckBob: Bool = false
    @State private var titlePulse: Bool = false

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
                    Spacer().frame(height: 40)

                    // Mascot duck ABOVE title
                    mascotSection

                    // Title
                    titleSection
                        .padding(.top, 4)

                    // Bread counter
                    breadCounter
                        .padding(.top, 12)

                    Spacer().frame(height: 20)

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
    }

    // MARK: - Mascot Duck (ABOVE title)

    private var mascotSection: some View {
        Image(uiImage: TextureFactory.shared.skinDuckUIImage(
            skin: skinManager.selectedSkin, pixelScale: 7.0
        ))
            .interpolation(.none)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 112, height: 112)
            .offset(y: duckBob ? -6 : 6)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    duckBob = true
                }
            }
    }

    // MARK: - Title

    private var titleSection: some View {
        VStack(spacing: 2) {
            Text("FLOPPY")
                .font(.custom(GK.pixelFontName, size: 28))
                .foregroundColor(.white)
                .shadow(color: GK.Colors.pipeBorder, radius: 0, x: 3, y: 3)
                .scaleEffect(titlePulse ? 1.02 : 1.0)

            Text("DUCK")
                .font(.custom(GK.pixelFontName, size: 28))
                .foregroundColor(GK.Colors.scoreYellow)
                .shadow(color: GK.Colors.pipeBorder, radius: 0, x: 3, y: 3)
                .scaleEffect(titlePulse ? 1.02 : 1.0)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                titlePulse = true
            }
        }
    }

    // MARK: - Bread Counter

    private var breadCounter: some View {
        HStack(spacing: 8) {
            Image(uiImage: TextureFactory.shared.breadUIImage(pixelScale: 3.0))
                .interpolation(.none)
                .resizable()
                .frame(width: 24, height: 20)

            Text("\(manager.stats.bread)")
                .font(.custom(GK.pixelFontName, size: 14))
                .foregroundColor(GK.Colors.breadGold)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.3))
        )
    }

    // MARK: - Play Section

    private var playSection: some View {
        VStack(spacing: 12) {
            // Main PLAY button
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    playExpanded.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    pixelIcon(.play, size: 20)
                    Text("PLAY")
                        .font(.custom(GK.pixelFontName, size: 18))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(GK.Colors.buttonGreen)
                        .shadow(color: GK.Colors.pipeDarkGreen, radius: 0, x: 0, y: 4)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(GK.Colors.pipeBorder, lineWidth: 3)
                )
            }
            .buttonStyle(.plain)

            // Expanded sub-modes
            if playExpanded {
                VStack(spacing: 10) {
                    subModeButton(
                        icon: .bot,
                        title: "VS BOT",
                        subtitle: "Bot Ladder",
                        color: GK.Colors.buttonBlue
                    ) {
                        manager.navigate(to: .botLadder)
                    }

                    subModeButton(
                        icon: .classic,
                        title: "CLASSIC",
                        subtitle: "Solo Run",
                        color: GK.Colors.buttonGreen
                    ) {
                        manager.startGame(GameModeConfig(mode: .classic))
                    }

                    subModeButton(
                        icon: .headToHead,
                        title: "HEAD TO HEAD",
                        subtitle: "1v1 Online",
                        color: GK.Colors.buttonOrange
                    ) {
                        manager.navigate(to: .matchmaking(.quickPlay))
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
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
