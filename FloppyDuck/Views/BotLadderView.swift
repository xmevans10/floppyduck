import SwiftUI

// MARK: - Bot Ladder View
//
// Presents the 8-bot ladder as a vertical card list with a connecting path.
// Styled to match HomeView's 8-bit aesthetic — scrolling pixel clouds,
// distant hills, and layered ground — while keeping the climb-the-ladder feel.

struct BotLadderView: View {
    @EnvironmentObject var manager: GameManager
    @State private var playerBounce = false
    @State private var cloudOffset: CGFloat = 0

    private let bots = BotCharacter.all
    private let icons = PixelIconFactory.shared
    private let factory = TextureFactory.shared

    // MARK: - 8-bit Background (matches HomeView)

    private var eightBitBackground: some View {
        GeometryReader { geo in
            ZStack {
                // Rich sky gradient (same stops as HomeView)
                LinearGradient(
                    stops: [
                        .init(color: Color(red: 0.22, green: 0.50, blue: 0.85), location: 0.0),
                        .init(color: Color(red: 0.38, green: 0.65, blue: 0.90), location: 0.3),
                        .init(color: Color(red: 0.58, green: 0.80, blue: 0.94), location: 0.6),
                        .init(color: Color(red: 0.78, green: 0.92, blue: 0.97), location: 0.85),
                        .init(color: Color(red: 0.90, green: 0.95, blue: 0.98), location: 1.0),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Scrolling pixel clouds
                HStack(spacing: 60) {
                    ForEach(0..<6, id: \.self) { i in
                        Image(uiImage: TextureFactory.shared.cloudUIImage())
                            .interpolation(.none)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: [70, 90, 55, 80, 65, 95][i],
                                   height: [28, 36, 22, 32, 26, 38][i])
                            .opacity([0.7, 0.85, 0.6, 0.75, 0.65, 0.8][i])
                            .offset(y: [0, -20, 15, -35, 5, -15][i])
                    }
                }
                .offset(x: cloudOffset)
                .onAppear {
                    guard !UIAccessibility.isReduceMotionEnabled else { return }
                    withAnimation(.linear(duration: 30).repeatForever(autoreverses: false)) {
                        cloudOffset = -300
                    }
                }
                .frame(maxHeight: geo.size.height * 0.4, alignment: .top)
                .padding(.top, 40)

                // Distant pixel hills
                VStack {
                    Spacer()
                    Image(uiImage: TextureFactory.shared.hillsUIImage())
                        .interpolation(.none)
                        .resizable()
                        .frame(height: 80)
                        .opacity(0.5)
                        .offset(y: -50)
                }

                // Ground at bottom — layered grass + dirt
                VStack(spacing: 0) {
                    Spacer()

                    // Dark grass edge
                    Rectangle()
                        .fill(Color(red: 0.28, green: 0.52, blue: 0.16))
                        .frame(height: 3)

                    // Grass
                    Rectangle()
                        .fill(Color(red: 0.40, green: 0.72, blue: 0.22))
                        .frame(height: 14)

                    // Dirt
                    ZStack {
                        Rectangle()
                            .fill(Color(red: 0.78, green: 0.70, blue: 0.50))
                        Rectangle()
                            .fill(Color(red: 0.72, green: 0.64, blue: 0.44).opacity(0.4))
                    }
                    .frame(height: 45)
                }
            }
        }
    }

    var body: some View {
        ZStack {
            // 8-bit background matching HomeView (XAN-7)
            eightBitBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                progressBar
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        ladderList
                            .padding(.top, 16)
                            .padding(.bottom, 80)
                    }
                    .onAppear {
                        let idx = manager.nextBotIndex
                        if idx < bots.count {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                withAnimation(.easeInOut(duration: 0.4)) {
                                    proxy.scrollTo(bots[idx].id, anchor: .center)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationBarHidden(true)
    }

    // MARK: - Header (standard layout: back / title / counter)

    private var header: some View {
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

            Text("BOT LADDER")
                .font(.custom(GK.pixelFontName, size: 18))
                .foregroundColor(.white)
                .shadow(color: GK.Colors.pipeBorder, radius: 0, x: 2, y: 2)

            Spacer()

            let beaten = bots.filter { manager.isBotBeaten($0.id) }.count
            HStack(spacing: 4) {
                Image(uiImage: icons.image(for: .swords, pixelScale: 2.0))
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 16, height: 16)
                Text("\(beaten)/\(bots.count)")
                    .font(.custom(GK.pixelFontName, size: 12))
                    .foregroundColor(GK.Colors.scoreYellow)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.25)))
            .accessibilityLabel("\(beaten) of \(bots.count) bots beaten")
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        let beaten = bots.filter { manager.isBotBeaten($0.id) }.count
        let progress = CGFloat(beaten) / CGFloat(bots.count)

        return VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.black.opacity(0.15))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [GK.Colors.buttonGreen, GK.Colors.buttonGreen.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(geo.size.width * progress, progress > 0 ? 12 : 0), height: 8)
                }
            }
            .frame(height: 8)

            Text(beaten == bots.count
                 ? "ALL BOTS DEFEATED! 🏆"
                 : "Defeat each bot to unlock their skin")
                .font(.custom(GK.pixelFontName, size: 6))
                .foregroundColor(.white.opacity(0.6))
        }
    }

    // MARK: - Ladder List

    private var ladderList: some View {
        VStack(spacing: 0) {
            // Hardest at top, easiest at bottom — climb the ladder
            ForEach(Array(bots.reversed().enumerated()), id: \.element.id) { index, bot in
                let realIdx = bots.count - 1 - index
                let beaten = manager.isBotBeaten(bot.id)
                let isNext = realIdx == manager.nextBotIndex
                let locked = realIdx > manager.nextBotIndex
                let isBoss = realIdx == bots.count - 1

                // Connector line to next card (above)
                if index > 0 {
                    connectorLine(
                        completed: beaten,
                        active: isNext,
                        color: bot.accentColor
                    )
                }

                botCard(
                    bot: bot,
                    beaten: beaten,
                    isNext: isNext,
                    locked: locked,
                    isBoss: isBoss
                )
                .id(bot.id)
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Bot Card

    private func botCard(
        bot: BotCharacter,
        beaten: Bool,
        isNext: Bool,
        locked: Bool,
        isBoss: Bool
    ) -> some View {
        Button {
            if !locked {
                SoundManager.shared.play(.button)
                manager.startBotLadderMatch(bot)
            }
        } label: {
            HStack(spacing: 14) {
                // Bot portrait
                ZStack {
                    // Glow ring for current challenge
                    if isNext {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [bot.accentColor.opacity(0.3), .clear],
                                    center: .center, startRadius: 12, endRadius: 38
                                )
                            )
                            .frame(width: 72, height: 72)
                    }

                    Circle()
                        .fill(
                            locked ? Color.black.opacity(0.08) :
                            beaten ? bot.accentColor.opacity(0.12) :
                            bot.accentColor.opacity(0.15)
                        )
                        .frame(width: isBoss ? 60 : 52, height: isBoss ? 60 : 52)
                        .overlay(
                            Circle().stroke(
                                isNext ? bot.accentColor :
                                beaten ? GK.Colors.buttonGreen.opacity(0.5) :
                                locked ? GK.Colors.panelBorder.opacity(0.15) :
                                bot.accentColor.opacity(0.3),
                                lineWidth: isNext ? 3 : 2
                            )
                        )

                    Group {
                        if locked {
                            Image(uiImage: factory.skinDuckUIImage(skin: bot.skin, pixelScale: 5.0))
                                .interpolation(.none)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: isBoss ? 36 : 30, height: isBoss ? 36 : 30)
                                .colorMultiply(.black)
                                .opacity(0.25)
                        } else {
                            Image(uiImage: factory.skinDuckUIImage(skin: bot.skin, pixelScale: 5.0))
                                .interpolation(.none)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: isBoss ? 36 : 30, height: isBoss ? 36 : 30)
                        }
                    }

                    // Lock overlay
                    if locked {
                        Image(uiImage: icons.image(for: .lock, pixelScale: 2.0))
                            .interpolation(.none)
                            .resizable()
                            .frame(width: 14, height: 14)
                    }

                    // Beaten checkmark
                    if beaten {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Image(uiImage: icons.image(for: .checkmark))
                                    .interpolation(.none)
                                    .resizable()
                                    .frame(width: 10, height: 10)
                                    .background(
                                        Circle()
                                            .fill(GK.Colors.buttonGreen)
                                            .frame(width: 14, height: 14)
                                    )
                            }
                        }
                        .frame(width: 48, height: 48)
                    }

                    // Crown for boss
                    if isBoss && !locked {
                        Image(uiImage: icons.image(for: .crown, pixelScale: 2.0))
                            .interpolation(.none)
                            .resizable()
                            .frame(width: 14, height: 14)
                            .offset(y: -(isBoss ? 34 : 30))
                    }

                    // Bouncing player duck marker
                    if isNext {
                        Image(uiImage: factory.skinDuckUIImage(
                            skin: SkinManager.shared.selectedSkin, pixelScale: 3.5))
                            .interpolation(.none)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 22, height: 22)
                            .shadow(color: .white.opacity(0.6), radius: 3)
                            .offset(x: -42, y: playerBounce ? -2 : 2)
                            .animation(
                                .easeInOut(duration: 0.5).repeatForever(autoreverses: true),
                                value: playerBounce
                            )
                            .onAppear { playerBounce = true }
                    }
                }
                .frame(width: 72)

                // Info
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(bot.name)
                            .font(.custom(GK.pixelFontName, size: isNext ? 13 : 11))
                            .foregroundColor(
                                locked ? GK.Colors.panelBorder.opacity(0.3) :
                                GK.Colors.panelBorder
                            )

                        if isBoss && !locked {
                            Text("BOSS")
                                .font(.custom(GK.pixelFontName, size: 6))
                                .foregroundColor(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule().fill(bot.accentColor)
                                )
                        }
                    }

                    if !locked {
                        Text(bot.title.uppercased())
                            .font(.custom(GK.pixelFontName, size: 7))
                            .foregroundColor(
                                beaten ? bot.accentColor.opacity(0.6) :
                                GK.Colors.panelBorder.opacity(0.5)
                            )
                    } else {
                        Text("BEAT PREVIOUS BOTS TO UNLOCK")
                            .font(.custom(GK.pixelFontName, size: 5))
                            .foregroundColor(GK.Colors.panelBorder.opacity(0.25))
                    }

                    if beaten {
                        HStack(spacing: 4) {
                            Image(uiImage: icons.image(for: .checkmark))
                                .interpolation(.none)
                                .resizable()
                                .frame(width: 8, height: 8)
                            Text("DEFEATED")
                                .font(.custom(GK.pixelFontName, size: 6))
                                .foregroundColor(GK.Colors.buttonGreen.opacity(0.8))
                        }
                    }
                }

                Spacer()

                // Right side: FIGHT button or status
                if isNext {
                    Text("FIGHT")
                        .font(.custom(GK.pixelFontName, size: 9))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(bot.accentColor)
                                .shadow(color: bot.accentColor.opacity(0.4), radius: 0, x: 0, y: 2)
                        )
                        .overlay(
                            Capsule().stroke(Color.black.opacity(0.2), lineWidth: 1)
                        )
                } else if beaten {
                    Text("REPLAY")
                        .font(.custom(GK.pixelFontName, size: 7))
                        .foregroundColor(GK.Colors.panelBorder.opacity(0.5))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(GK.Colors.panelCream)
                                .overlay(
                                    Capsule().stroke(GK.Colors.panelBorder.opacity(0.2), lineWidth: 1)
                                )
                        )
                } else if locked {
                    Image(uiImage: icons.image(for: .lock, pixelScale: 2.0))
                        .interpolation(.none)
                        .resizable()
                        .frame(width: 16, height: 16)
                        .opacity(0.2)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, isNext ? 14 : 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(GK.Colors.panelCream)
                    .shadow(color: isNext ? bot.accentColor.opacity(0.3) : Color.black.opacity(0.1),
                            radius: isNext ? 6 : 0, x: 0, y: isNext ? 4 : 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isNext ? bot.accentColor :
                        beaten ? GK.Colors.buttonGreen.opacity(0.3) :
                        GK.Colors.panelBorder.opacity(locked ? 0.08 : 0.15),
                        lineWidth: isNext ? 3 : 2
                    )
            )
            .opacity(locked ? 0.55 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(locked)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(bot.name), \(bot.title)" +
            (beaten ? ", beaten" : isNext ? ", next challenge" : locked ? ", locked" : "")
        )
        .accessibilityHint(
            isNext ? "Double-tap to challenge" :
            locked ? "Beat previous bots to unlock" :
            beaten ? "Double-tap to replay" : ""
        )
    }

    // MARK: - Connector Line

    private func connectorLine(completed: Bool, active: Bool, color: Color) -> some View {
        HStack(spacing: 0) {
            Spacer()
            Rectangle()
                .fill(
                    completed ? GK.Colors.buttonGreen.opacity(0.4) :
                    active    ? color.opacity(0.25) :
                                Color.black.opacity(0.06)
                )
                .frame(width: 3, height: 24)
            Spacer()
        }
    }
}
