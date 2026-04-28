import SwiftUI

struct ShopView: View {
    @EnvironmentObject var manager: GameManager
    @ObservedObject var skinManager = SkinManager.shared
    @ObservedObject var themeManager = ThemeManager.shared
    @ObservedObject var bannerManager = BannerManager.shared
    @ObservedObject var pipeSkinManager = PipeSkinManager.shared

    @State private var selectedTab: ShopTab = .skins
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
                            .background(PixelButtonBackground(style: .dark, size: 44))
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

                        if DuckSkin.allCases.contains(where: { $0.isPremium }) {
                            Button {
                                Task { await skinManager.restorePurchases() }
                            } label: {
                                Text("RESTORE PREMIUM PURCHASES")
                                    .font(.custom(GK.pixelFontName, size: 7))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .padding(.bottom, 40)
                        }
                    } else if selectedTab == .backgrounds {
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
                    } else if selectedTab == .banners {
                        // Battle banners grid
                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(BattleBanner.allCases) { banner in
                                bannerCard(banner)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 14)
                        .padding(.bottom, 30)

                        if BattleBanner.allCases.contains(where: { $0.isPremium }) {
                            Button {
                                Task { await bannerManager.restorePurchases() }
                            } label: {
                                Text("RESTORE PREMIUM PURCHASES")
                                    .font(.custom(GK.pixelFontName, size: 7))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .padding(.bottom, 40)
                        }
                    } else {
                        // Pipe skins grid
                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(PipeSkin.allCases) { skin in
                                pipeCard(skin)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 14)
                        .padding(.bottom, 30)

                        if PipeSkin.allCases.contains(where: { $0.isPremium }) {
                            Button {
                                Task { await pipeSkinManager.restorePurchases() }
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
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                shopTabButton(.skins)
                shopTabButton(.pipes)
                shopTabButton(.backgrounds)
                shopTabButton(.banners)
            }
            .padding(6)
        }
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
            HStack(spacing: 5) {
                Image(systemName: tab.icon)
                    .font(.system(size: 9, weight: .bold))
                Text(tab.rawValue)
                    .font(.custom(GK.pixelFontName, size: 8))
                    .lineLimit(1)
                    .fixedSize()
            }
            .foregroundColor(selectedTab == tab ? .white : .white.opacity(0.5))
            .padding(.horizontal, 12)
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
                // Mini-scene preview showing sky + hills + ground
                ThemePreviewView(theme: theme)
                    .frame(height: 70)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
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

    // MARK: - Banner Card

    private func bannerCard(_ banner: BattleBanner) -> some View {
        let owned = bannerManager.ownedBanners.contains(banner)
        let selected = bannerManager.selectedBanner == banner
        let purchasing = bannerManager.purchasing == banner
        let canAffordNormal = (banner.breadPrice ?? 0) <= manager.stats.bread

        return Button {
            localErrorMessage = nil

            if owned {
                bannerManager.select(banner)
                SoundManager.shared.play(.button)
                return
            }

            switch banner.purchaseKind {
            case .free:
                bannerManager.select(banner)
            case .normal:
                let cost = banner.breadPrice ?? 0
                guard manager.spendBread(cost) else {
                    localErrorMessage = "Not enough bread. Play games to earn more."
                    return
                }
                bannerManager.unlockNormal(banner)
                bannerManager.select(banner)
                SoundManager.shared.play(.button)
            case .botReward:
                // Bot reward banners are auto-unlocked when beating the bot
                if owned {
                    bannerManager.select(banner)
                    SoundManager.shared.play(.button)
                }
            case .premium:
                Task { await bannerManager.purchasePremium(banner) }
            }
        } label: {
            VStack(spacing: 8) {
                // Banner pattern preview
                RoundedRectangle(cornerRadius: 8)
                    .fill(banner.secondaryColor)
                    .frame(height: 70)
                    .overlay(
                        BannerPatternView(banner: banner, offset: 0)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(selected ? banner.primaryColor : Color.clear, lineWidth: 2)
                    )
                    .opacity(owned || banner.isFree ? 1 : 0.6)

                Text(banner.displayName)
                    .font(.custom(GK.pixelFontName, size: 9))
                    .foregroundColor(GK.Colors.panelBorder)

                Text(banner.subtitle)
                    .font(.custom(GK.pixelFontName, size: 6))
                    .foregroundColor(GK.Colors.panelBorder.opacity(0.6))

                if selected {
                    Text("EQUIPPED")
                        .font(.custom(GK.pixelFontName, size: 7))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 6).fill(banner.primaryColor))
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
                    bannerPriceBadge(for: banner)
                        .opacity(banner.isNormal && !canAffordNormal ? 0.5 : 1)
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
        .disabled(banner.isPremium && bannerManager.purchasing != nil)
        .disabled(banner.isBotReward && !owned)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(banner.displayName) banner, \(banner.subtitle)\(selected ? ", equipped" : owned ? ", owned" : ", \(banner.priceDisplay)")")
        .accessibilityHint(selected ? "Currently equipped" : owned ? "Double-tap to equip" : "Double-tap to purchase")
    }

    private func bannerPriceBadge(for banner: BattleBanner) -> some View {
        Group {
            if banner.isNormal {
                HStack(spacing: 4) {
                    Image(uiImage: TextureFactory.shared.breadUIImage(pixelScale: 2.0))
                        .interpolation(.none)
                        .resizable()
                        .frame(width: 14, height: 11)
                    Text("\(banner.breadPrice ?? 0)")
                }
                .font(.custom(GK.pixelFontName, size: 8))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 6).fill(GK.Colors.buttonGreen))
            } else if banner.isPremium {
                Text(banner.priceDisplay)
                    .font(.custom(GK.pixelFontName, size: 8))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(GK.Colors.buttonOrange))
            } else if banner.isBotReward {
                Text("BOT REWARD")
                    .font(.custom(GK.pixelFontName, size: 7))
                    .foregroundColor(GK.Colors.panelBorder.opacity(0.5))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.1)))
            } else {
                Text("FREE")
                    .font(.custom(GK.pixelFontName, size: 7))
                    .foregroundColor(GK.Colors.panelBorder)
            }
        }
    }

    // MARK: - Pipe Card

    private func pipeCard(_ skin: PipeSkin) -> some View {
        let owned = pipeSkinManager.ownedSkins.contains(skin)
        let selected = pipeSkinManager.selectedSkin == skin
        let purchasing = pipeSkinManager.purchasing == skin
        let canAffordNormal = (skin.breadPrice ?? 0) <= manager.stats.bread

        return Button {
            localErrorMessage = nil

            if owned {
                pipeSkinManager.select(skin)
                SoundManager.shared.play(.button)
                return
            }

            switch skin.purchaseKind {
            case .free:
                pipeSkinManager.select(skin)
            case .normal:
                let cost = skin.breadPrice ?? 0
                guard manager.spendBread(cost) else {
                    localErrorMessage = "Not enough bread. Play games to earn more."
                    return
                }
                pipeSkinManager.unlockNormal(skin)
                pipeSkinManager.select(skin)
                SoundManager.shared.play(.button)
            case .premium:
                Task { await pipeSkinManager.purchasePremium(skin) }
            case .botReward:
                break // Cannot buy bot rewards
            }
        } label: {
            VStack(spacing: 8) {
                // Pipe preview — mini pipe body + cap swatch
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.05))
                        .frame(height: 70)

                    HStack(spacing: 4) {
                        // Pipe body preview
                        VStack(spacing: 0) {
                            // Cap
                            Image(uiImage: TextureFactory.shared.pipeSkinCapPreviewUIImage(skin: skin))
                                .interpolation(.none)
                                .resizable()
                                .frame(width: 28, height: 10)
                            // Body
                            Image(uiImage: TextureFactory.shared.pipeSkinPreviewUIImage(skin: skin, width: 24, height: 50))
                                .interpolation(.none)
                                .resizable()
                                .frame(width: 24, height: 40)
                        }

                        // Second pipe (upside-down) for pair preview
                        VStack(spacing: 0) {
                            Image(uiImage: TextureFactory.shared.pipeSkinPreviewUIImage(skin: skin, width: 24, height: 50))
                                .interpolation(.none)
                                .resizable()
                                .frame(width: 24, height: 40)
                                .rotationEffect(.degrees(180))
                            Image(uiImage: TextureFactory.shared.pipeSkinCapPreviewUIImage(skin: skin))
                                .interpolation(.none)
                                .resizable()
                                .frame(width: 28, height: 10)
                                .rotationEffect(.degrees(180))
                        }
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(selected ? skin.accentColor : Color.clear, lineWidth: 2)
                )

                Text(skin.displayName)
                    .font(.custom(GK.pixelFontName, size: 10))
                    .foregroundColor(GK.Colors.panelBorder)

                Text(skin.subtitle)
                    .font(.custom(GK.pixelFontName, size: 6))
                    .foregroundColor(GK.Colors.panelBorder.opacity(0.6))

                if owned {
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
                } else if purchasing {
                    ProgressView()
                        .tint(.white)
                        .frame(height: 24)
                } else {
                    pipePriceBadge(for: skin)
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
        .disabled(purchasing || (skin.isBotReward && !owned))
        .opacity((!canAffordNormal && skin.isNormal && !owned) || (skin.isBotReward && !owned) ? 0.5 : 1.0)
        .accessibilityLabel("\(skin.displayName) pipe skin, \(owned ? "owned" : skin.priceDisplay)")
        .accessibilityHint(selected ? "Currently equipped" : owned ? "Double-tap to equip" : "Double-tap to purchase")
    }

    private func pipePriceBadge(for skin: PipeSkin) -> some View {
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
            } else if skin.isPremium {
                Text(skin.priceDisplay)
                    .font(.custom(GK.pixelFontName, size: 8))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(GK.Colors.buttonOrange))
            } else if skin.isBotReward {
                Text("BOT REWARD")
                    .font(.custom(GK.pixelFontName, size: 7))
                    .foregroundColor(GK.Colors.panelBorder.opacity(0.5))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.1)))
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
            !skin.isBotReward
        }
    }

    private var activeErrorMessage: String? {
        localErrorMessage ?? skinManager.errorMessage ?? bannerManager.errorMessage ?? pipeSkinManager.errorMessage
    }
}

private enum ShopTab: String {
    case skins = "DUCKS"
    case pipes = "PIPES"
    case backgrounds = "BGs"
    case banners = "BANNERS"

    var icon: String {
        switch self {
        case .skins:       return "bird"
        case .pipes:       return "arrow.up.and.down.square"
        case .backgrounds: return "paintpalette"
        case .banners:     return "flag.fill"
        }
    }

    var accent: Color {
        switch self {
        case .skins:       return GK.Colors.buttonGreen
        case .pipes:       return GK.Colors.pipeGreen
        case .backgrounds: return GK.Colors.buttonBlue
        case .banners:     return Color(red: 0.85, green: 0.35, blue: 0.55)
        }
    }
}


