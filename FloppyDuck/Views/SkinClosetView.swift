import SwiftUI

struct SkinClosetView: View {
    @EnvironmentObject var manager: GameManager
    @ObservedObject var skinManager = SkinManager.shared

    private let icons = PixelIconFactory.shared
    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [GK.Colors.skyTop, GK.Colors.skyBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button {
                        SoundManager.shared.play(.button)
                        manager.goHome()
                    } label: {
                        Image(uiImage: icons.image(for: .back, pixelScale: 3.0))
                            .interpolation(.none)
                            .resizable()
                            .frame(width: 28, height: 28)
                            .padding(8)
                            .background(Circle().fill(Color.black.opacity(0.15)))
                    }
                    Spacer()
                    Text("CLOSET")
                        .font(.custom(GK.pixelFontName, size: 22))
                        .foregroundColor(.white)
                        .shadow(color: GK.Colors.pipeBorder, radius: 0, x: 2, y: 2)
                    Spacer()
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                if ownedSkins.count <= 1 {
                    // Only classic owned — show encouraging message
                    Spacer()
                    VStack(spacing: 16) {
                        Image(uiImage: TextureFactory.shared.duckUIImage(pixelScale: 5.0))
                            .interpolation(.none)
                            .resizable()
                            .frame(width: 80, height: 60)
                        Text("YOUR CLOSET IS EMPTY!")
                            .font(.custom(GK.pixelFontName, size: 12))
                            .foregroundColor(.white)
                        Text("Beat bots or visit the shop\nto unlock new skins.")
                            .font(.custom(GK.pixelFontName, size: 7))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                    .padding(30)
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(ownedSkins) { skin in
                                skinCard(skin)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 14)
                        .padding(.bottom, 16)
                    }
                }

                // Bottom shop link
                Button {
                    SoundManager.shared.play(.button)
                    manager.goHome()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        manager.navigate(to: .shop)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text("Get more skins in the Shop")
                            .font(.custom(GK.pixelFontName, size: 7))
                            .foregroundColor(.white.opacity(0.8))
                        Text("→")
                            .font(.custom(GK.pixelFontName, size: 8))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.25))
                            .overlay(
                                Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Go to shop for more skins")
                .padding(.bottom, 20)
            }
        }
        .navigationBarHidden(true)
    }

    // MARK: - Data

    private var ownedSkins: [DuckSkin] {
        DuckSkin.allCases.filter { skinManager.ownedSkins.contains($0) }
    }

    // MARK: - Skin Card

    private func skinCard(_ skin: DuckSkin) -> some View {
        let selected = skinManager.selectedSkin == skin

        return Button {
            SoundManager.shared.play(.button)
            skinManager.select(skin)
        } label: {
            VStack(spacing: 8) {
                // Duck preview
                Image(uiImage: TextureFactory.shared.skinDuckUIImage(skin: skin, pixelScale: 5.0))
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)

                Text(skin.displayName)
                    .font(.custom(GK.pixelFontName, size: 10))
                    .foregroundColor(GK.Colors.panelBorder)

                Text(skin.subtitle)
                    .font(.custom(GK.pixelFontName, size: 6))
                    .foregroundColor(GK.Colors.panelBorder.opacity(0.6))

                if selected {
                    Text("EQUIPPED")
                        .font(.custom(GK.pixelFontName, size: 7))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 6).fill(skin.accentColor))
                } else {
                    Text("TAP TO EQUIP")
                        .font(.custom(GK.pixelFontName, size: 7))
                        .foregroundColor(GK.Colors.panelBorder.opacity(0.5))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(GK.Colors.panelCream)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(GK.Colors.panelBorder.opacity(0.3), lineWidth: 1)
                                )
                        )
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(GK.Colors.panelCream)
                    .shadow(color: Color.black.opacity(0.1), radius: 0, x: 0, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selected ? skin.accentColor : GK.Colors.panelBorder,
                            lineWidth: selected ? 3 : 2)
            )
        }
        .buttonStyle(.plain)
    }
}
