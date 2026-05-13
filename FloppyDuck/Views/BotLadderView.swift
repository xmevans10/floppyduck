import SwiftUI

// MARK: - Bot Ladder View
//
// Climb from QUACKERS to THE DUCK.
// Uses HomeView's design system: subModeButton style for active bot,
// settingsPanel cream cards for beaten/locked bots.

struct BotLadderView: View {
    @EnvironmentObject var manager: GameManager
    @State private var cloudOffset: CGFloat = 0

    private let bots = BotCharacter.all
    private let icons = PixelIconFactory.shared
    private let factory = TextureFactory.shared

    private var beatenCount: Int { bots.filter { manager.isBotBeaten($0.id) }.count }
    private var progress: CGFloat { CGFloat(beatenCount) / CGFloat(bots.count) }

    // MARK: - Body

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

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                progressBar
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 10) {
                            ForEach(Array(bots.reversed().enumerated()), id: \.element.id) { index, bot in
                                let realIdx = bots.count - 1 - index
                                let beaten = manager.isBotBeaten(bot.id)
                                let isNext = realIdx == manager.nextBotIndex
                                let locked = realIdx > manager.nextBotIndex

                                botCard(bot: bot, beaten: beaten, isNext: isNext, locked: locked,
                                        isBoss: realIdx == bots.count - 1)
                                    .id(bot.id)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 80)
                    }
                    .onAppear {
                        let idx = manager.nextBotIndex
                        guard idx < bots.count else { return }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            withAnimation(.easeInOut(duration: 0.4)) {
                                proxy.scrollTo(bots[idx].id, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
        .navigationBarHidden(true)
    }

    // MARK: - Header

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
                    .background(PixelButtonBackground(style: .dark, size: 44))
            }
            .accessibilityLabel("Back")

            Spacer()

            Text("BOT LADDER")
                .font(.custom(GK.pixelFontName, size: 18))
                .foregroundColor(.white)
                .shadow(color: GK.Colors.pipeBorder, radius: 0, x: 2, y: 2)

            Spacer()

            HStack(spacing: 4) {
                Image(uiImage: icons.image(for: .swords, pixelScale: 2.0))
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 16, height: 16)
                Text("\(beatenCount)/\(bots.count)")
                    .font(.custom(GK.pixelFontName, size: 12))
                    .foregroundColor(GK.Colors.scoreYellow)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.25))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(GK.Colors.scoreYellow.opacity(0.2), lineWidth: 1)
                    )
            )
            .accessibilityLabel("\(beatenCount) of \(bots.count) bots beaten")
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.black.opacity(0.15))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(
                            colors: [GK.Colors.buttonGreen, GK.Colors.buttonGreen.opacity(0.7)],
                            startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(geo.size.width * progress, progress > 0 ? 12 : 0), height: 8)
                }
            }
            .frame(height: 8)

            Text(beatenCount == bots.count
                 ? "ALL BOTS DEFEATED! 🏆"
                 : "Defeat each bot to unlock their skin")
                .font(.custom(GK.pixelFontName, size: 6))
                .foregroundColor(.white.opacity(0.6))
        }
    }

    // MARK: - Bot Card (unified for regular + boss)

    private func botCard(bot: BotCharacter, beaten: Bool, isNext: Bool,
                         locked: Bool, isBoss: Bool) -> some View {
        Button {
            guard !locked else { return }
            SoundManager.shared.play(.button)
            manager.startBotLadderMatch(bot)
        } label: {
            HStack(spacing: 12) {
                // Portrait
                botPortrait(bot: bot, beaten: beaten, locked: locked)

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(bot.name)
                            .font(.custom(GK.pixelFontName, size: isNext ? 13 : 11))
                            .foregroundColor(
                                isNext ? .white :
                                locked ? GK.Colors.panelBorder.opacity(0.35) :
                                GK.Colors.panelBorder)
                        if isBoss && !locked {
                            Image(uiImage: icons.image(for: .crown, pixelScale: 2.0))
                                .interpolation(.none)
                                .resizable()
                                .frame(width: 12, height: 12)
                        }
                    }

                    if locked {
                        Text("BEAT PREVIOUS BOTS")
                            .font(.custom(GK.pixelFontName, size: 5))
                            .foregroundColor(GK.Colors.panelBorder.opacity(0.3))
                    } else {
                        Text(beaten ? "DEFEATED" : bot.title.uppercased())
                            .font(.custom(GK.pixelFontName, size: 7))
                            .foregroundColor(
                                isNext ? .white.opacity(0.7) :
                                beaten ? GK.Colors.buttonGreen.opacity(0.8) :
                                GK.Colors.panelBorder.opacity(0.5))
                        if isNext {
                            Text("TARGET: \(bot.targetScore) PIPES")
                                .font(.custom(GK.pixelFontName, size: 6))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                }

                Spacer()

                // Action
                if isNext {
                    Text("FIGHT")
                        .font(.custom(GK.pixelFontName, size: 9))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            Capsule().fill(Color.white.opacity(0.2))
                                .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1)))
                } else if beaten {
                    Text("REPLAY")
                        .font(.custom(GK.pixelFontName, size: 7))
                        .foregroundColor(GK.Colors.panelBorder.opacity(0.4))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .overlay(
                            Capsule().stroke(GK.Colors.panelBorder.opacity(0.15), lineWidth: 1))
                } else if locked {
                    Image(uiImage: icons.image(for: .lock, pixelScale: 2.0))
                        .interpolation(.none)
                        .resizable()
                        .frame(width: 14, height: 14)
                        .opacity(0.25)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, isNext ? 14 : 10)
            .background(
                Group {
                    if isNext {
                        // subModeButton pattern — colored fill + drop shadow
                        RoundedRectangle(cornerRadius: 12)
                            .fill(bot.accentColor)
                            .shadow(color: bot.accentColor.opacity(0.5), radius: 0, x: 0, y: 3)
                    } else {
                        // settingsPanel pattern — cream fill
                        RoundedRectangle(cornerRadius: 12)
                            .fill(GK.Colors.panelCream)
                            .shadow(color: Color.black.opacity(0.1), radius: 0, x: 0, y: 3)
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isNext ? Color.black.opacity(0.3) :
                        beaten ? GK.Colors.buttonGreen.opacity(0.3) :
                        GK.Colors.panelBorder.opacity(locked ? 0.1 : 0.15),
                        lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .disabled(locked)
        .opacity(locked ? 0.5 : 1.0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(bot.name), \(bot.title)" +
            (beaten ? ", beaten" : isNext ? ", next challenge" : locked ? ", locked" : ""))
        .accessibilityHint(
            isNext ? "Double-tap to challenge" :
            beaten ? "Double-tap to replay" :
            locked ? "Beat previous bots to unlock" : "")
    }

    // MARK: - Portrait

    private func botPortrait(bot: BotCharacter, beaten: Bool, locked: Bool) -> some View {
        ZStack {
            PixelButtonBackground(
                style: locked ? .dark : .accent(bot.accentColor),
                size: 44
            )

            Image(uiImage: factory.skinDuckUIImage(skin: bot.skin, pixelScale: 5.0))
                .interpolation(.none)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 28, height: 28)
                .colorMultiply(locked ? .black : .white)
                .opacity(locked ? 0.2 : 1.0)

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
                                PixelRoundedRect().fill(GK.Colors.buttonGreen)
                                    .frame(width: 14, height: 14))
                    }
                }
                .frame(width: 40, height: 40)
            }
        }
    }

    // MARK: - 8-Bit Background (matches HomeView)

    private var eightBitBackground: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    stops: [
                        .init(color: Color(red: 0.22, green: 0.50, blue: 0.85), location: 0.0),
                        .init(color: Color(red: 0.38, green: 0.65, blue: 0.90), location: 0.3),
                        .init(color: Color(red: 0.58, green: 0.80, blue: 0.94), location: 0.6),
                        .init(color: Color(red: 0.78, green: 0.92, blue: 0.97), location: 0.85),
                        .init(color: Color(red: 0.90, green: 0.95, blue: 0.98), location: 1.0),
                    ],
                    startPoint: .top, endPoint: .bottom
                )

                HStack(spacing: 60) {
                    ForEach(0..<6, id: \.self) { i in
                        Image(uiImage: factory.cloudUIImage())
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

                VStack {
                    Spacer()
                    Image(uiImage: factory.hillsUIImage())
                        .interpolation(.none)
                        .resizable()
                        .frame(height: 80)
                        .opacity(0.5)
                        .offset(y: -50)
                }

                VStack(spacing: 0) {
                    Spacer()
                    Rectangle().fill(Color(red: 0.28, green: 0.52, blue: 0.16)).frame(height: 3)
                    Rectangle().fill(Color(red: 0.40, green: 0.72, blue: 0.22)).frame(height: 14)
                    ZStack {
                        Rectangle().fill(Color(red: 0.78, green: 0.70, blue: 0.50))
                        Rectangle().fill(Color(red: 0.72, green: 0.64, blue: 0.44).opacity(0.4))
                    }
                    .frame(height: 45)
                }
            }
        }
    }
}
