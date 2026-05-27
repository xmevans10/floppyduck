import SwiftUI

// MARK: - Bot Ladder View
//
// Vertical progression path from QUACKERS → THE DUCK.
// Connected nodes with a glowing trail, reward previews, and
// distinct visual states for beaten / next / locked bots.

struct BotLadderView: View {
    @EnvironmentObject var manager: GameManager

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
                        // Progression path — bottom to top
                        ZStack(alignment: .top) {
                            // Vertical connector line behind the cards
                            pathConnector

                            VStack(spacing: 0) {
                                ForEach(Array(bots.reversed().enumerated()), id: \.element.id) { index, bot in
                                    let realIdx = bots.count - 1 - index
                                    let beaten = manager.isBotBeaten(bot.id)
                                    let isNext = realIdx == manager.nextBotIndex
                                    let locked = !beaten && realIdx > manager.nextBotIndex
                                    let isBoss = realIdx == bots.count - 1

                                    VStack(spacing: 0) {
                                        botNode(bot: bot, beaten: beaten, isNext: isNext,
                                                locked: locked, isBoss: isBoss, rank: realIdx + 1)
                                            .id(bot.id)

                                        // Connector segment between nodes (skip after last)
                                        if index < bots.count - 1 {
                                            connectorSegment(
                                                aboveBeaten: beaten,
                                                belowBeaten: manager.isBotBeaten(bots[realIdx - 1].id),
                                                isNextEdge: isNext || (realIdx - 1 == manager.nextBotIndex)
                                            )
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                            .padding(.bottom, 80)
                        }
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
                 : "Climb the ladder — each victory unlocks rewards")
                .font(.custom(GK.pixelFontName, size: 6))
                .foregroundColor(.white.opacity(0.6))
        }
    }

    // MARK: - Path Connector (background vertical line)

    private var pathConnector: some View {
        // Invisible — connectors are drawn per-segment between nodes
        Color.clear
    }

    // MARK: - Connector Segment Between Nodes

    private func connectorSegment(aboveBeaten: Bool, belowBeaten: Bool, isNextEdge: Bool) -> some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(
                    aboveBeaten && belowBeaten
                        ? GK.Colors.buttonGreen.opacity(0.6)
                        : isNextEdge
                            ? Color.white.opacity(0.25)
                            : Color.white.opacity(0.08)
                )
                .frame(width: 3, height: 20)

            // Dot marker
            Circle()
                .fill(
                    aboveBeaten && belowBeaten
                        ? GK.Colors.buttonGreen.opacity(0.8)
                        : Color.white.opacity(0.15)
                )
                .frame(width: 7, height: 7)

            Rectangle()
                .fill(
                    aboveBeaten && belowBeaten
                        ? GK.Colors.buttonGreen.opacity(0.6)
                        : isNextEdge
                            ? Color.white.opacity(0.25)
                            : Color.white.opacity(0.08)
                )
                .frame(width: 3, height: 20)
        }
        .frame(height: 47)
    }

    // MARK: - Bot Node (progression tile)

    private func botNode(bot: BotCharacter, beaten: Bool, isNext: Bool,
                         locked: Bool, isBoss: Bool, rank: Int) -> some View {
        Button {
            guard !locked else { return }
            SoundManager.shared.play(.button)
            manager.startBotLadderMatch(bot)
        } label: {
            VStack(spacing: 0) {
                // Rank label above the card for the next challenge
                if isNext {
                    Text("⚔️ NEXT CHALLENGER")
                        .font(.custom(GK.pixelFontName, size: 7))
                        .foregroundColor(bot.accentColor)
                        .padding(.bottom, 6)
                }

                HStack(spacing: 14) {
                    // Rank number + portrait
                    ZStack {
                        botPortrait(bot: bot, beaten: beaten, locked: locked, isNext: isNext, isBoss: isBoss)

                        // Rank badge (top-left)
                        VStack {
                            HStack {
                                Text("\(rank)")
                                    .font(.custom(GK.pixelFontName, size: 7))
                                    .foregroundColor(beaten ? .white : .white.opacity(0.7))
                                    .frame(width: 18, height: 18)
                                    .background(
                                        Circle()
                                            .fill(beaten ? GK.Colors.buttonGreen : Color.black.opacity(0.4))
                                    )
                                Spacer()
                            }
                            Spacer()
                        }
                        .frame(width: 52, height: 52)
                    }

                    // Info column
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(bot.name)
                                .font(.custom(GK.pixelFontName, size: isNext ? 14 : 11))
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
                            Text("LOCKED")
                                .font(.custom(GK.pixelFontName, size: 6))
                                .foregroundColor(GK.Colors.panelBorder.opacity(0.3))
                        } else {
                            // Title line — clean, no ELO clutter
                            Text(beaten ? "DEFEATED ✓" : bot.title.uppercased())
                                .font(.custom(GK.pixelFontName, size: 7))
                                .foregroundColor(
                                    isNext ? .white.opacity(0.7) :
                                    beaten ? GK.Colors.buttonGreen.opacity(0.8) :
                                    GK.Colors.panelBorder.opacity(0.5))

                            // Target score — only shown for current challenge
                            if isNext {
                                Text("TARGET: \(bot.targetScore) PIPES")
                                    .font(.custom(GK.pixelFontName, size: 7))
                                    .foregroundColor(.white.opacity(0.6))
                                    .padding(.top, 1)
                            }

                            // Reward preview
                            if !beaten && !locked {
                                rewardPreview(for: bot)
                                    .padding(.top, 2)
                            }
                        }
                    }

                    Spacer()

                    // Action column
                    if isNext {
                        VStack(spacing: 4) {
                            Text("FIGHT")
                                .font(.custom(GK.pixelFontName, size: 10))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(Color.white.opacity(0.25))
                                        .overlay(Capsule().stroke(Color.white.opacity(0.4), lineWidth: 1.5))
                                )
                        }
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
                .padding(.vertical, isNext ? 16 : 12)
                .background(
                    Group {
                        if isNext {
                            // Active challenge — bot's accent color with glow
                            RoundedRectangle(cornerRadius: 14)
                                .fill(bot.accentColor)
                                .shadow(color: bot.accentColor.opacity(0.6), radius: 8, x: 0, y: 4)
                        } else if beaten {
                            // Beaten — subtle green-tinted cream
                            RoundedRectangle(cornerRadius: 14)
                                .fill(GK.Colors.panelCream)
                                .shadow(color: GK.Colors.buttonGreen.opacity(0.15), radius: 0, x: 0, y: 3)
                        } else {
                            // Locked or upcoming — dark translucent
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.black.opacity(locked ? 0.2 : 0.3))
                                .shadow(color: Color.black.opacity(0.1), radius: 0, x: 0, y: 3)
                        }
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            isNext ? Color.white.opacity(0.3) :
                            beaten ? GK.Colors.buttonGreen.opacity(0.3) :
                            Color.white.opacity(locked ? 0.05 : 0.1),
                            lineWidth: isNext ? 2.5 : 2)
                )
            }
        }
        .buttonStyle(.plain)
        .disabled(locked)
        .opacity(locked ? 0.45 : 1.0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(bot.name), \(bot.title), rank \(rank)" +
            (beaten ? ", beaten" : isNext ? ", next challenge" : locked ? ", locked" : ""))
        .accessibilityHint(
            isNext ? "Double-tap to challenge" :
            beaten ? "Double-tap to replay" :
            locked ? "Beat previous bots to unlock" : "")
    }

    // MARK: - Reward Preview

    /// Shows what you'll unlock by beating this bot (banner, pipe skin, or just "Unlock [skin name]")
    private func rewardPreview(for bot: BotCharacter) -> some View {
        HStack(spacing: 4) {
            Image(uiImage: icons.image(for: .star, pixelScale: 1.5))
                .interpolation(.none)
                .resizable()
                .frame(width: 10, height: 10)

            // Check for banner unlock
            if let banner = BattleBanner.allCases.first(where: { $0.requiredBotId == bot.id }) {
                Text("UNLOCKS: \(banner.displayName) BANNER")
                    .font(.custom(GK.pixelFontName, size: 5))
                    .foregroundColor(GK.Colors.scoreYellow.opacity(0.8))
            }
            // Check for pipe skin unlock
            else if let pipe = PipeSkin.allCases.first(where: { $0.requiredBotId == bot.id }) {
                Text("UNLOCKS: \(pipe.displayName) PIPES")
                    .font(.custom(GK.pixelFontName, size: 5))
                    .foregroundColor(GK.Colors.scoreYellow.opacity(0.8))
            }
            // Bot's duck skin as the aspirational reward
            else {
                Text("SKIN: \(bot.skin.displayName)")
                    .font(.custom(GK.pixelFontName, size: 5))
                    .foregroundColor(GK.Colors.scoreYellow.opacity(0.8))
            }
        }
    }

    // MARK: - Portrait

    private func botPortrait(bot: BotCharacter, beaten: Bool, locked: Bool,
                             isNext: Bool, isBoss: Bool) -> some View {
        ZStack {
            // Outer ring — glowing for next, green for beaten
            Circle()
                .fill(
                    isNext ? bot.accentColor.opacity(0.3) :
                    beaten ? GK.Colors.buttonGreen.opacity(0.15) :
                    Color.black.opacity(0.2)
                )
                .frame(width: 52, height: 52)

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
                .frame(width: 44, height: 44)
            }
        }
    }
}
