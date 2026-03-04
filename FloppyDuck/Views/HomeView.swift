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
        .sheet(isPresented: $showRoomSheet) {
            roomSheet
        }
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

    // MARK: - Duck Mascot (pixel art)

    private var duckMascot: some View {
        Group {
            if let img = TextureFactory.shared.duckUIImage().cgImage {
                Image(uiImage: UIImage(cgImage: img, scale: 0.5, orientation: .up))
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 90, height: 64)
            }
        }
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

    // MARK: - Room Sheet

    private var roomSheet: some View {
        VStack(spacing: 20) {
            Text("Private Room")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(GK.Colors.panelBorder)

            Text("Coming soon!")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            Button("Close") { showRoomSheet = false }
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 30)
                .padding(.vertical, 12)
                .background(GK.Colors.buttonOrange)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .padding(30)
        .presentationDetents([.height(200)])
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
