import SwiftUI

struct ShopView: View {
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
                    Button { manager.goHome() } label: {
                        Image(uiImage: icons.image(for: .back, pixelScale: 3.0))
                            .interpolation(.none)
                            .resizable()
                            .frame(width: 28, height: 28)
                            .padding(8)
                            .background(Circle().fill(Color.black.opacity(0.15)))
                    }
                    Spacer()
                    Text("SHOP")
                        .font(.custom(GK.pixelFontName, size: 22))
                        .foregroundColor(.white)
                        .shadow(color: GK.Colors.pipeBorder, radius: 0, x: 2, y: 2)
                    Spacer()
                    // Bread balance
                    HStack(spacing: 4) {
                        Image(uiImage: TextureFactory.shared.breadUIImage(pixelScale: 2.5))
                            .interpolation(.none)
                            .resizable()
                            .frame(width: 20, height: 16)
                        Text("\(manager.stats.bread)")
                            .font(.custom(GK.pixelFontName, size: 10))
                            .foregroundColor(GK.Colors.breadGold)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.25)))
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                // Skin grid
                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(DuckSkin.allCases) { skin in
                            skinCard(skin)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 30)

                    // Restore purchases
                    Button {
                        Task { await skinManager.restorePurchases() }
                    } label: {
                        Text("RESTORE PURCHASES")
                            .font(.custom(GK.pixelFontName, size: 7))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationBarHidden(true)
    }

    // MARK: - Skin Card

    private func skinCard(_ skin: DuckSkin) -> some View {
        let owned = skinManager.ownedSkins.contains(skin)
        let selected = skinManager.selectedSkin == skin
        let purchasing = skinManager.purchasing == skin

        return Button {
            if owned {
                skinManager.select(skin)
            } else {
                Task { await skinManager.purchase(skin) }
            }
        } label: {
            VStack(spacing: 8) {
                // Duck preview
                Image(uiImage: TextureFactory.shared.skinDuckUIImage(skin: skin, pixelScale: 5.0))
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)

                // Name
                Text(skin.displayName)
                    .font(.custom(GK.pixelFontName, size: 10))
                    .foregroundColor(GK.Colors.panelBorder)

                // Subtitle
                Text(skin.subtitle)
                    .font(.custom(GK.pixelFontName, size: 6))
                    .foregroundColor(GK.Colors.panelBorder.opacity(0.6))

                // Status badge
                if selected {
                    Text("EQUIPPED")
                        .font(.custom(GK.pixelFontName, size: 7))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 6).fill(skin.accentColor))
                } else if owned {
                    Text("OWNED")
                        .font(.custom(GK.pixelFontName, size: 7))
                        .foregroundColor(GK.Colors.panelBorder)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 6).fill(GK.Colors.panelCream))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(GK.Colors.panelBorder, lineWidth: 1))
                } else if purchasing {
                    ProgressView()
                        .frame(height: 22)
                } else {
                    Text(skin.priceDisplay)
                        .font(.custom(GK.pixelFontName, size: 8))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 6).fill(GK.Colors.buttonOrange))
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
