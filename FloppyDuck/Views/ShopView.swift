import SwiftUI

struct ShopView: View {
    @EnvironmentObject var manager: GameManager
    @ObservedObject var skinManager = SkinManager.shared

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
                    Button { manager.goHome() } label: {
                        Image(uiImage: icons.image(for: .back, pixelScale: 3.0))
                            .interpolation(.none)
                            .resizable()
                            .frame(width: 28, height: 28)
                            .padding(8)
                            .background(Circle().fill(Color.black.opacity(0.15)))
                    }
                    .accessibilityLabel("Back to home")
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

                sectionPicker
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

    private var filteredSkins: [DuckSkin] {
        DuckSkin.allCases.filter { skin in
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
