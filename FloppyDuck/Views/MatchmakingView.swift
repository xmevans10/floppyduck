import SwiftUI

struct MatchmakingView: View {
    let mode: MatchmakingMode
    @EnvironmentObject var manager: GameManager
    @State private var searching = true
    @State private var dots = ""
    @State private var roomCode = ""

    private let icons = PixelIconFactory.shared

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [GK.Colors.skyTop, GK.Colors.skyBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                // Mode icon
                pixelIcon(mode == .ranked ? .trophy : .headToHead, size: 44)

                Text(modeTitle)
                    .font(.custom(GK.pixelFontName, size: 18))
                    .foregroundColor(.white)
                    .shadow(color: GK.Colors.pipeBorder, radius: 0, x: 2, y: 2)

                // Content panel
                VStack(spacing: 16) {
                    switch mode {
                    case .quickPlay, .ranked:
                        searchingContent
                    case .privateRoom:
                        privateRoomContent
                    }
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(GK.Colors.panelCream)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(GK.Colors.panelBorder, lineWidth: 3)
                )
                .padding(.horizontal, 40)

                Spacer()

                // Cancel / back
                Button {
                    manager.goHome()
                } label: {
                    HStack(spacing: 8) {
                        pixelIcon(.cancel, size: 16)
                        Text("CANCEL")
                            .font(.custom(GK.pixelFontName, size: 10))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(GK.Colors.buttonRed)
                            .shadow(color: GK.Colors.buttonRed.opacity(0.4), radius: 0, x: 0, y: 3)
                    )
                    .overlay(Capsule().stroke(Color.black.opacity(0.3), lineWidth: 2))
                }
                .buttonStyle(.plain)

                Spacer().frame(height: 30)
            }
        }
        .navigationBarHidden(true)
        .onAppear { startSearchAnimation() }
    }

    // MARK: - Mode Title

    private var modeTitle: String {
        switch mode {
        case .quickPlay: return "HEAD TO HEAD"
        case .ranked: return "RANKED"
        case .privateRoom: return "PRIVATE ROOM"
        }
    }

    // MARK: - Searching Content

    private var searchingContent: some View {
        VStack(spacing: 12) {
            // Animated duck
            Image(uiImage: TextureFactory.shared.duckUIImage(pixelScale: 3.0))
                .interpolation(.none)
                .resizable()
                .frame(width: 50, height: 38)

            Text("SEARCHING\(dots)")
                .font(.custom(GK.pixelFontName, size: 12))
                .foregroundColor(GK.Colors.panelBorder)
                .frame(width: 200, alignment: .center)

            if mode == .ranked {
                HStack(spacing: 6) {
                    pixelIcon(.trophy, size: 14)
                    Text("ELO: \(manager.stats.elo)")
                        .font(.custom(GK.pixelFontName, size: 8))
                        .foregroundColor(GK.Colors.panelBorder.opacity(0.6))
                }
            }

            Text("Multiplayer coming soon!")
                .font(.custom(GK.pixelFontName, size: 7))
                .foregroundColor(GK.Colors.panelBorder.opacity(0.4))
                .padding(.top, 4)
        }
    }

    // MARK: - Private Room Content

    private var privateRoomContent: some View {
        VStack(spacing: 16) {
            Text("ROOM CODE")
                .font(.custom(GK.pixelFontName, size: 10))
                .foregroundColor(GK.Colors.panelBorder.opacity(0.6))

            TextField("", text: $roomCode)
                .font(.custom(GK.pixelFontName, size: 20))
                .foregroundColor(GK.Colors.panelBorder)
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.characters)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(GK.Colors.panelBorder.opacity(0.3), lineWidth: 2)
                        )
                )
                .onChange(of: roomCode) { _, val in
                    roomCode = String(val.prefix(GK.roomCodeLength)).uppercased()
                }

            Button {
                // TODO: Join room
            } label: {
                Text("JOIN")
                    .font(.custom(GK.pixelFontName, size: 12))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(GK.Colors.buttonGreen)
                            .shadow(color: GK.Colors.pipeDarkGreen, radius: 0, x: 0, y: 3)
                    )
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(GK.Colors.pipeBorder, lineWidth: 2))
            }
            .buttonStyle(.plain)

            Text("Coming soon!")
                .font(.custom(GK.pixelFontName, size: 7))
                .foregroundColor(GK.Colors.panelBorder.opacity(0.4))
        }
    }

    // MARK: - Helpers

    private func pixelIcon(_ icon: PixelIcon, size: CGFloat) -> some View {
        Image(uiImage: icons.image(for: icon))
            .interpolation(.none)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
    }

    private func startSearchAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            dots = dots.count >= 3 ? "" : dots + "."
        }
    }
}
