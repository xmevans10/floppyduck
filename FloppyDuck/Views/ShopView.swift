import SwiftUI

struct ShopView: View {
    @EnvironmentObject var manager: GameManager
    @ObservedObject var skinManager = SkinManager.shared
    @ObservedObject var themeManager = ThemeManager.shared

    @State private var selectedTab: ShopTab = .skins
    @State private var selectedSection: ShopSection = .normal
    @State private var localErrorMessage: String?

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
                    .accessibilityLabel("Back")
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
                    .accessibilityLabel("Bread balance: \(manager.stats.bread)")
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                // Top-level tab picker: SKINS | BACKGROUNDS
                shopTabPicker
                    .padding(.horizontal, 20)
                    .padding(.top, 14)

                if selectedTab == .skins {
                    // Sub-section picker for skins
                    sectionPicker
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                }

                if let message = activeErrorMessage {
                    Text(message)
                        .font(.custom(GK.pixelFontName, size: 7))
                        .foregroundColor(GK.Colors.buttonRed)
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                        .multilineTextAlignment(.center)
                }

                ScrollView(showsIndicators: false) {
                    if selectedTab == .skins {
                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(filteredSkins) { skin in
                                skinCard(skin)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 14)
                        .padding(.bottom, 30)

                        if selectedSection == .premium {
                            Button {
                                Task { await skinManager.restorePurchases() }
                            } label: {
                                Text("RESTORE PREMIUM PURCHASES")
                                    .font(.custom(GK.pixelFontName, size: 7))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .padding(.bottom, 40)
                        } else {
                            Spacer().frame(height: 24)
                        }
                    } else {
                        // Background themes grid
                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(BackgroundTheme.allCases) { theme in
                                themeCard(theme)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 14)
                        .padding(.bottom, 30)

                        if BackgroundTheme.allCases.contains(where: { $0.isPremium }) {
                            Button {
                                Task { await themeManager.restorePurchases() }
                            } label: {
                                Text("RESTORE PREMIUM PURCHASES")
                                    .font(.custom(GK.pixelFontName, size: 7))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .padding(.bottom, 40)
                        }
                    }
                }
            }
        }
        .navigationBarHidden(true)
    }

    // MARK: - Section Picker

    private var sectionPicker: some View {
        HStack(spacing: 8) {
            sectionButton(.normal)
            sectionButton(.premium)
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(GK.Colors.panelCream)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(GK.Colors.panelBorder, lineWidth: 2)
                )
        )
    }

    private func sectionButton(_ section: ShopSection) -> some View {
        Button {
            selectedSection = section
            localErrorMessage = nil
        } label: {
            Text(section.rawValue)
                .font(.custom(GK.pixelFontName, size: 8))
                .foregroundColor(selectedSection == section ? .white : GK.Colors.panelBorder)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(selectedSection == section ? section.accent : Color.white)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(section.rawValue) section")
    }

    // MARK: - Skin Card

    private func skinCard(_ skin: DuckSkin) -> some View {
        let owned = skinManager.ownedSkins.contains(skin)
        let selected = skinManager.selectedSkin == skin
        let purchasing = skinManager.purchasing == skin
        let canAffordNormal = (skin.breadPrice ?? 0) <= manager.stats.bread

        return Button {
            localErrorMessage = nil

            if owned {
                skinManager.select(skin)
                return
            }

            switch skin.purchaseKind {
            case .free:
                skinManager.select(.classic)
            case .normal:
                let cost = skin.breadPrice ?? 0
                guard manager.spendBread(cost) else {
                    localErrorMessage = "Not enough bread. Play games to earn more."
                    return
                }
                skinManager.unlockNormal(skin)
                skinManager.select(skin)
            case .premium:
                Task { await skinManager.purchasePremium(skin) }
            case .botReward:
                localErrorMessage = "Win against this bot to unlock their skin!"
            }
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
                    priceBadge(for: skin)
                        .opacity(skin.isNormal && !canAffordNormal ? 0.5 : 1)
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
        .disabled(skin.isPremium && skinManager.purchasing != nil)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(skin.displayName), \(skin.subtitle)\(selected ? ", equipped" : owned ? ", owned" : ", \(skin.priceDisplay)")")
        .accessibilityHint(selected ? "Currently equipped" : owned ? "Double-tap to equip" : "Double-tap to purchase")
    }

    private func priceBadge(for skin: DuckSkin) -> some View {
        Group {
            if skin.isNormal {
                HStack(spacing: 4) {
                    Image(uiImage: TextureFactory.shared.breadUIImage(pixelScale: 2.0))
                        .interpolation(.none)
                        .resizable()
                        .frame(width: 14, height: 11)
                    Text("\(skin.breadPrice ?? 0)")
                }
                .font(.custom(GK.pixelFontName, size: 8))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 6).fill(GK.Colors.buttonGreen))
            } else {
                Text(skin.priceDisplay)
                    .font(.custom(GK.pixelFontName, size: 8))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(GK.Colors.buttonOrange))
            }
        }
    }

    // MARK: - Shop Tab Picker

    private var shopTabPicker: some View {
        HStack(spacing: 8) {
            shopTabButton(.skins)
            shopTabButton(.backgrounds)
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.2))
        )
    }

    private func shopTabButton(_ tab: ShopTab) -> some View {
        Button {
            selectedTab = tab
            localErrorMessage = nil
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

    // MARK: - Theme Card

    private func themeCard(_ theme: BackgroundTheme) -> some View {
        let owned = themeManager.ownedThemes.contains(theme)
        let selected = themeManager.selectedTheme == theme
        let purchasing = themeManager.purchasing == theme
        let canAffordNormal = (theme.breadPrice ?? 0) <= manager.stats.bread

        return Button {
            localErrorMessage = nil

            if owned {
                themeManager.select(theme)
                SoundManager.shared.play(.button)
                return
            }

            switch theme.purchaseKind {
            case .free:
                themeManager.select(theme)
            case .normal:
                let cost = theme.breadPrice ?? 0
                guard manager.spendBread(cost) else {
                    localErrorMessage = "Not enough bread. Play games to earn more."
                    return
                }
                themeManager.unlockNormal(theme)
                themeManager.select(theme)
                SoundManager.shared.play(.button)
            case .premium:
                Task { await themeManager.purchasePremium(theme) }
            }
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
                        // Stars overlay for night/space themes
                        Group {
                            if theme.showStars {
                                ZStack {
                                    ForEach(0..<8, id: \.self) { i in
                                        Circle()
                                            .fill(.white.opacity(Double.random(in: 0.4...0.9)))
                                            .frame(width: CGFloat.random(in: 1.5...3), height: CGFloat.random(in: 1.5...3))
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
                    .font(.custom(GK.pixelFontName, size: 9))
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
                    themePriceBadge(for: theme)
                        .opacity(theme.isNormal && !canAffordNormal ? 0.5 : 1)
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
        .disabled(theme.isPremium && themeManager.purchasing != nil)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(theme.displayName) background, \(theme.subtitle)\(selected ? ", equipped" : owned ? ", owned" : ", \(theme.priceDisplay)")")
        .accessibilityHint(selected ? "Currently equipped" : owned ? "Double-tap to equip" : "Double-tap to purchase")
    }

    private func themePriceBadge(for theme: BackgroundTheme) -> some View {
        Group {
            if theme.isNormal {
                HStack(spacing: 4) {
                    Image(uiImage: TextureFactory.shared.breadUIImage(pixelScale: 2.0))
                        .interpolation(.none)
                        .resizable()
                        .frame(width: 14, height: 11)
                    Text("\(theme.breadPrice ?? 0)")
                }
                .font(.custom(GK.pixelFontName, size: 8))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 6).fill(GK.Colors.buttonGreen))
            } else if theme.isPremium {
                Text(theme.priceDisplay)
                    .font(.custom(GK.pixelFontName, size: 8))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(GK.Colors.buttonOrange))
            } else {
                Text("FREE")
                    .font(.custom(GK.pixelFontName, size: 7))
                    .foregroundColor(GK.Colors.panelBorder)
            }
        }
    }

    private var filteredSkins: [DuckSkin] {
        DuckSkin.allCases.filter { skin in
            // Bot reward skins are not shown in shop
            if skin.isBotReward { return false }
            switch selectedSection {
            case .normal:
                return skin.isNormal || skin.isFree
            case .premium:
                return skin.isPremium
            }
        }
    }

    private var activeErrorMessage: String? {
        localErrorMessage ?? skinManager.errorMessage
    }
}

private enum ShopTab: String {
    case skins = "DUCKS"
    case backgrounds = "BACKGROUNDS"

    var icon: String {
        switch self {
        case .skins:       return "bird"
        case .backgrounds: return "paintpalette"
        }
    }

    var accent: Color {
        switch self {
        case .skins:       return GK.Colors.buttonGreen
        case .backgrounds: return GK.Colors.buttonBlue
        }
    }
}

private enum ShopSection: String, CaseIterable {
    case normal = "NORMAL"
    case premium = "PREMIUM"

    var accent: Color {
        switch self {
        case .normal:
            return GK.Colors.buttonGreen
        case .premium:
            return GK.Colors.buttonOrange
        }
    }
}
