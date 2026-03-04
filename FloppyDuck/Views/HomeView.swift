import SwiftUI

/// Home screen styled after classic Flappy Bird — bright sky, pixel duck, retro buttons.
struct HomeView: View {
    @EnvironmentObject var gameManager: GameManager

    @State private var duckOffset: CGFloat = 0
    @State private var cloudOffset: CGFloat = 0
    @State private var showRoomSheet = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // ── Sky gradient background ──
                LinearGradient(
                    colors: [GK.Colors.skyTop, GK.Colors.skyBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // ── Floating clouds ──
                cloudLayer(width: geo.size.width)

                // ── City silhouette (faint) ──
                VStack {
                    Spacer()
                    Rectangle()
                        .fill(GK.Colors.grassGreen.opacity(0.15))
                        .frame(height: 100)
                }
                .ignoresSafeArea()

                // ── Ground strip at bottom ──
                VStack {
                    Spacer()
                    groundStrip(width: geo.size.width)
                }
                .ignoresSafeArea()

                // ── Main content ──
                VStack(spacing: 0) {
                    Spacer().frame(height: geo.safeAreaInsets.top + 40)

                    // Title
                    retroTitle

                    Spacer().frame(height: 16)

                    // Bouncing pixel duck
                    duckMascot
                        .offset(y: duckOffset)

                    Spacer().frame(height: 20)

                    // Stats bar
                    statsPanel

                    Spacer().frame(height: 24)

                    // Mode buttons
                    modeButtons

                    Spacer()

                    // Private room section at bottom (above ground)
                    privateRoomSection
                        .padding(.bottom, 100) // above ground
                }
                .padding(.horizontal, 24)
            }
        }
        .navigationBarHidden(true)
        .onAppear { startAnimations() }
        .overlay {
            if showRoomSheet {
                roomOverlay
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.9).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showRoomSheet)
    }

    // MARK: - Title

    private var retroTitle: some View {
        ZStack {
            // Shadow/outline layer
            Text("Floppy Duck")
                .font(.system(size: 44, weight: .black, design: .rounded))
                .foregroundStyle(GK.Colors.panelBorder)
                .offset(x: 2, y: 2)

            // Main title
            Text("Floppy Duck")
                .font(.system(size: 44, weight: .black, design: .rounded))
                .foregroundStyle(.white)
        }
    }

    // MARK: - Duck Mascot (pixel art, rendered at display size)

    private var duckMascot: some View {
        // Render at 6x pixel scale so 17×12 grid = 102×72pt — no resizing blur
        let img = TextureFactory.shared.duckUIImage(pixelScale: 6.0)
        return Image(uiImage: img)
            .interpolation(.none)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 102, height: 72)
    }

    // MARK: - Stats

    private var statsPanel: some View {
        HStack(spacing: 0) {
            statItem(label: "RATING", value: "\(gameManager.playerRating)")
            retroDivider
            statItem(label: "BEST", value: "\(gameManager.bestScore)")
            retroDivider
            statItem(label: "GAMES", value: "\(gameManager.gamesPlayed)")
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(GK.Colors.panelCream)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(GK.Colors.panelBorder, lineWidth: 3)
                )
                .shadow(color: GK.Colors.panelBorder.opacity(0.4), radius: 0, x: 2, y: 3)
        )
    }

    private func statItem(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(GK.Colors.panelBorder.opacity(0.6))
            Text(value)
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(GK.Colors.panelBorder)
        }
        .frame(maxWidth: .infinity)
    }

    private var retroDivider: some View {
        Rectangle()
            .fill(GK.Colors.panelBorder.opacity(0.2))
            .frame(width: 2, height: 40)
    }

    // MARK: - Mode Buttons

    private var modeButtons: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                retroButton(
                    icon: "▶",
                    label: "Play",
                    color: GK.Colors.buttonGreen
                ) {
                    gameManager.startSoloGame()
                }

                retroButton(
                    icon: "⚡",
                    label: "Quick",
                    color: GK.Colors.buttonOrange
                ) {
                    gameManager.startMatchmaking(mode: .quickPlay)
                }
            }

            retroButton(
                icon: "🏆",
                label: "Ranked Match",
                color: Color(red: 0.85, green: 0.30, blue: 0.30),
                wide: true
            ) {
                gameManager.startMatchmaking(mode: .ranked)
            }
        }
    }

    private func retroButton(icon: String, label: String, color: Color, wide: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(icon)
                    .font(.system(size: 20))
                Text(label)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: wide ? .infinity : nil)
            .frame(height: 50)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(color)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.black.opacity(0.3), lineWidth: 3)
                    )
                    .shadow(color: Color.black.opacity(0.25), radius: 0, x: 2, y: 3)
            )
        }
        .buttonStyle(RetroPress())
    }

    // MARK: - Private Room

    private var privateRoomSection: some View {
        HStack(spacing: 12) {
            Button {
                showRoomSheet = true
            } label: {
                HStack(spacing: 6) {
                    Text("🔗")
                    Text("Create Room")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .foregroundStyle(GK.Colors.panelBorder)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(GK.Colors.panelCream)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(GK.Colors.panelBorder, lineWidth: 2)
                        )
                )
            }

            Button {
                showRoomSheet = true
            } label: {
                HStack(spacing: 6) {
                    Text("🎮")
                    Text("Join Code")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .foregroundStyle(GK.Colors.panelBorder)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(GK.Colors.panelCream)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(GK.Colors.panelBorder, lineWidth: 2)
                        )
                )
            }
        }
    }

    // MARK: - Clouds

    private func cloudLayer(width: CGFloat) -> some View {
        ZStack {
            cloudPuff(x: cloudOffset.truncatingRemainder(dividingBy: width + 100) - 50, y: 120, scale: 1.0)
            cloudPuff(x: (cloudOffset * 0.7 + 200).truncatingRemainder(dividingBy: width + 100) - 50, y: 80, scale: 0.7)
            cloudPuff(x: (cloudOffset * 0.5 + 350).truncatingRemainder(dividingBy: width + 100) - 50, y: 160, scale: 0.85)
        }
    }

    private func cloudPuff(x: CGFloat, y: CGFloat, scale: CGFloat) -> some View {
        Circle()
            .fill(Color.white.opacity(0.6))
            .frame(width: 80 * scale, height: 40 * scale)
            .scaleEffect(x: 2.0, y: 1.0)
            .position(x: x, y: y)
    }

    // MARK: - Ground Strip

    private func groundStrip(width: CGFloat) -> some View {
        VStack(spacing: 0) {
            // Dark grass line
            Rectangle()
                .fill(GK.Colors.grassGreen)
                .frame(height: 4)

            // Bright grass
            Rectangle()
                .fill(GK.Colors.grassLight)
                .frame(height: 16)

            // Tan earth
            Rectangle()
                .fill(GK.Colors.groundTan)
                .frame(height: 60)
        }
    }

    // MARK: - Private Room Overlay (retro styled)

    private var roomOverlay: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { showRoomSheet = false }

            VStack(spacing: 16) {
                ZStack {
                    Text("Private Room")
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(GK.Colors.panelBorder)
                        .offset(x: 1, y: 1)
                    Text("Private Room")
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }

                Text("🎮")
                    .font(.system(size: 40))

                Text("Coming soon!")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(GK.Colors.panelBorder.opacity(0.7))

                Text("Multiplayer private rooms will let you create a 5-letter code and challenge friends.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(GK.Colors.panelBorder.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)

                Button {
                    Haptic.buttonTap()
                    showRoomSheet = false
                } label: {
                    Text("Got It")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 140, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(GK.Colors.buttonOrange)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.black.opacity(0.3), lineWidth: 3)
                                )
                                .shadow(color: .black.opacity(0.25), radius: 0, x: 2, y: 3)
                        )
                }
                .buttonStyle(RetroPress())
            }
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(GK.Colors.panelCream)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(GK.Colors.panelBorder, lineWidth: 3)
                    )
                    .shadow(color: GK.Colors.panelBorder.opacity(0.4), radius: 0, x: 3, y: 4)
            )
            .padding(.horizontal, 40)
        }
    }

    // MARK: - Animations

    private func startAnimations() {
        // Bouncing duck
        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
            duckOffset = -12
        }

        // Drifting clouds
        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
            cloudOffset = UIScreen.main.bounds.width + 100
        }
    }
}

// MARK: - Retro Button Press Style

struct RetroPress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .offset(y: configuration.isPressed ? 2 : 0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
