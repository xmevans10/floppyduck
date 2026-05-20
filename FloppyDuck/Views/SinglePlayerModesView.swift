import SwiftUI

struct SinglePlayerModesView: View {
    @EnvironmentObject var manager: GameManager
    private let icons = PixelIconFactory.shared

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

            VStack(spacing: 20) {
                Spacer().frame(height: 30)

                HStack {
                    backButton
                    Spacer()
                    Text("SINGLE PLAYER")
                        .font(.custom(GK.pixelFontName, size: 16))
                        .foregroundColor(.white)
                        .shadow(color: GK.Colors.pipeBorder, radius: 0, x: 2, y: 2)
                    Spacer()
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, 16)

                VStack(spacing: 12) {
                    modeButton(
                        icon: .classic,
                        title: "CLASSIC",
                        subtitle: "No Power-Ups",
                        color: GK.Colors.classicTint
                    ) {
                        SoundManager.shared.play(.button)
                        manager.startGame(GameModeConfig(mode: .classic, powerUpsEnabled: false))
                    }

                    modeButton(
                        icon: .star,
                        title: "ARCADE",
                        subtitle: "Power-Ups Enabled",
                        color: GK.Colors.arcadeTint
                    ) {
                        SoundManager.shared.play(.button)
                        manager.startGame(GameModeConfig(mode: .classic))
                    }
                }
                .padding(.horizontal, 32)

                Spacer()
            }
        }
        .navigationBarHidden(true)
    }

    private func modeButton(icon: PixelIcon,
                            title: String,
                            subtitle: String,
                            color: Color,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                pixelIcon(icon, size: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.custom(GK.pixelFontName, size: 10))
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.custom(GK.pixelFontName, size: 7))
                        .foregroundColor(.white.opacity(0.75))
                }

                Spacer()

                pixelIcon(.play, size: 14)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(color)
                    .shadow(color: color.opacity(0.45), radius: 0, x: 0, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.black.opacity(0.3), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private func pixelIcon(_ icon: PixelIcon, size: CGFloat) -> some View {
        Image(uiImage: icons.image(for: icon))
            .interpolation(.none)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
    }

    private var backButton: some View {
        Button {
            manager.goHome()
        } label: {
            Image(uiImage: icons.image(for: .back))
                .interpolation(.none)
                .resizable()
                .frame(width: 28, height: 28)
                .padding(8)
                .background(PixelButtonBackground(style: .light, size: 44))
        }
        .buttonStyle(.plain)
    }
}
