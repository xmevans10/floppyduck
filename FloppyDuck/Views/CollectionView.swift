import SwiftUI

struct CollectionView: View {
    @EnvironmentObject var manager: GameManager
    @ObservedObject var skinManager = SkinManager.shared
    @ObservedObject var themeManager = ThemeManager.shared
    @ObservedObject var bannerManager = BannerManager.shared

    @State private var selectedTab: CollectionTab = .skins

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
                    Text("COLLECTION")
                        .font(.custom(GK.pixelFontName, size: 22))
                        .foregroundColor(.white)
                        .shadow(color: GK.Colors.pipeBorder, radius: 0, x: 2, y: 2)
                    Spacer()
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                // Tab picker: SKINS | BACKGROUNDS
                collectionTabPicker
                    .padding(.horizontal, 20)
                    .padding(.top, 14)

                switch selectedTab {
                case .skins:
                    skinsContent
                case .backgrounds:
                    backgroundsContent
                case .banners:
                    bannersContent
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
                        Text(shopLinkText)
                            .font(.custom(GK.pixelFontName, size: 7))
                            .foregroundColor(.white.opacity(0.8))
                        Image(uiImage: PixelIconFactory.shared.image(for: .arrowRight))
                            .interpolation(.none)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 10, height: 10)
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
                .accessibilityLabel("Go to shop")
                .padding(.bottom, 20)
            }
        }
        .navigationBarHidden(true)
    }

    // MARK: - Tab Picker

    private var collectionTabPicker: some View {
        HStack(spacing: 8) {
            collectionTabButton(.skins)
            collectionTabButton(.backgrounds)
            collectionTabButton(.banners)
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.2))
        )
    }

    private func collectionTabButton(_ tab: CollectionTab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            HStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .font(.system(size: 10, weight: .bold))
                Text(tab.rawValue)
                    .font(.custom(GK.pixelFontName, size: 8))
            }
            .foregroundColor(selectedTab == tab ? .white : .white.opacity(0.5))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selectedTab == tab ? tab.accent : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Skins Content

    @ViewBuilder
    private var skinsContent: some View {
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
                        skinCollectionCard(skin)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 16)
            }
        }
    }

    // MARK: - Backgrounds Content

    @ViewBuilder
    private var backgroundsContent: some View {
        let ownedBGs = BackgroundTheme.allCases.filter { themeManager.ownedThemes.contains($0) }

        if ownedBGs.isEmpty {
            Spacer()
            VStack(spacing: 16) {
                Text("NO BACKGROUNDS YET!")
                    .font(.custom(GK.pixelFontName, size: 12))
                    .foregroundColor(.white)
                Text("Visit the shop to unlock\nnew background themes.")
                    .font(.custom(GK.pixelFontName, size: 7))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            .padding(30)
            Spacer()
        } else {
            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(ownedBGs) { theme in
                        themeCollectionCard(theme)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 16)
            }
        }
    }

    // MARK: - Banners Content

    @ViewBuilder
    private var bannersContent: some View {
        let owned = BattleBanner.allCases.filter { bannerManager.ownedBanners.contains($0) }

        if owned.isEmpty {
            Spacer()
            VStack(spacing: 16) {
                Text("NO BANNERS YET!")
                    .font(.custom(GK.pixelFontName, size: 12))
                    .foregroundColor(.white)
                Text("Beat bots or visit the shop\nto unlock battle banners.")
                    .font(.custom(GK.pixelFontName, size: 7))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            .padding(30)
            Spacer()
        } else {
            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(owned) { banner in
                        bannerCollectionCard(banner)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 16)
            }
        }
    }

    // MARK: - Shop Link Text

    private var shopLinkText: String {
        switch selectedTab {
        case .skins:       return "Get more skins in the Shop"
        case .backgrounds: return "Get more backgrounds in the Shop"
        case .banners:     return "Get more banners in the Shop"
        }
    }

    // MARK: - Data

    private var ownedSkins: [DuckSkin] {
        DuckSkin.allCases.filter { skinManager.ownedSkins.contains($0) }
    }

    // MARK: - Skin Card

    private func skinCollectionCard(_ skin: DuckSkin) -> some View {
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

    // MARK: - Theme Collection Card

    private func themeCollectionCard(_ theme: BackgroundTheme) -> some View {
        let selected = themeManager.selectedTheme == theme

        return Button {
            SoundManager.shared.play(.button)
            themeManager.select(theme)
        } label: {
            VStack(spacing: 8) {
                // Gradient preview swatch
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: theme.gradientColors,
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 70)
                    .overlay(
                        Group {
                            if theme.showStars {
                                ZStack {
                                    ForEach(0..<8, id: \.self) { i in
                                        Circle()
                                            .fill(.white.opacity(Double.random(in: 0.4...0.9)))
                                            .frame(width: CGFloat.random(in: 1.5...3),
                                                   height: CGFloat.random(in: 1.5...3))
                                            .offset(
                                                x: CGFloat.random(in: -35...35),
                                                y: CGFloat.random(in: -25...25)
                                            )
                                    }
                                }
                            }
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(selected ? theme.accentColor : Color.clear, lineWidth: 2)
                    )

                Text(theme.displayName)
                    .font(.custom(GK.pixelFontName, size: 10))
                    .foregroundColor(GK.Colors.panelBorder)

                Text(theme.subtitle)
                    .font(.custom(GK.pixelFontName, size: 6))
                    .foregroundColor(GK.Colors.panelBorder.opacity(0.6))

                if selected {
                    Text("EQUIPPED")
                        .font(.custom(GK.pixelFontName, size: 7))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 6).fill(theme.accentColor))
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
                    .stroke(selected ? theme.accentColor : GK.Colors.panelBorder,
                            lineWidth: selected ? 3 : 2)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Banner Card

    private func bannerCollectionCard(_ banner: BattleBanner) -> some View {
        let selected = bannerManager.selectedBanner == banner

        return Button {
            SoundManager.shared.play(.button)
            bannerManager.select(banner)
        } label: {
            VStack(spacing: 10) {
                // Banner preview — small pattern swatch
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(banner.secondaryColor)
                        .frame(height: 60)

                    // Simplified pattern preview stripe
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [banner.primaryColor.opacity(0.6), banner.secondaryColor],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 60)

                    if selected {
                        Image(uiImage: PixelIconFactory.shared.image(for: .checkmark))
                            .interpolation(.none)
                            .resizable()
                            .frame(width: 16, height: 16)
                            .shadow(color: .white, radius: 4)
                    }
                }

                Text(banner.displayName)
                    .font(.custom(GK.pixelFontName, size: 8))
                    .foregroundColor(GK.Colors.panelBorder)
                    .lineLimit(1)

                Text(banner.subtitle.uppercased())
                    .font(.custom(GK.pixelFontName, size: 5))
                    .foregroundColor(GK.Colors.panelBorder.opacity(0.5))
                    .lineLimit(1)

                if selected {
                    Text("EQUIPPED")
                        .font(.custom(GK.pixelFontName, size: 7))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 6).fill(banner.primaryColor))
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
                    .stroke(selected ? banner.primaryColor : GK.Colors.panelBorder,
                            lineWidth: selected ? 3 : 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tab Enum

private enum CollectionTab: String {
    case skins = "SKINS"
    case backgrounds = "BACKGROUNDS"
    case banners = "BANNERS"

    var icon: String {
        switch self {
        case .skins:       return "bird"
        case .backgrounds: return "paintpalette"
        case .banners:     return "flag.fill"
        }
    }

    var accent: Color {
        switch self {
        case .skins:       return GK.Colors.buttonGreen
        case .backgrounds: return GK.Colors.buttonBlue
        case .banners:     return Color(red: 0.85, green: 0.35, blue: 0.55)
        }
    }
}
