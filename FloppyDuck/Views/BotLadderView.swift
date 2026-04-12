import SwiftUI

// MARK: - Bot Ladder View
//
// The bot ladder — climb from QUACKERS to THE DUCK.
// Styled to match HomeView's 8-bit aesthetic: scrolling pixel clouds,
// distant hills, layered ground, consistent GK.Colors palette.

struct BotLadderView: View {
    @EnvironmentObject var manager: GameManager
    @State private var playerBounce = false
    @State private var cloudOffset: CGFloat = 0
    @State private var bossGlow = false

    private let bots = BotCharacter.all
    private let icons = PixelIconFactory.shared
    private let factory = TextureFactory.shared

    // MARK: - Layout Constants

    private enum Layout {
        // Header
        static let headerHorizontalPadding: CGFloat = 16
        static let headerTopPadding: CGFloat = 12
        static let backButtonSize: CGFloat = 28
        static let backButtonPadding: CGFloat = 8
        static let titleFontSize: CGFloat = 18
        static let counterFontSize: CGFloat = 12
        static let counterIconSize: CGFloat = 16
        static let counterPaddingH: CGFloat = 10
        static let counterPaddingV: CGFloat = 6

        // Progress bar
        static let progressBarHeight: CGFloat = 8
        static let progressBarCornerRadius: CGFloat = 4
        static let progressBarPaddingH: CGFloat = 20
        static let progressBarTopPadding: CGFloat = 12
        static let progressSubtitleFontSize: CGFloat = 6

        // Ladder
        static let ladderPaddingH: CGFloat = 20
        static let ladderTopPadding: CGFloat = 16
        static let ladderBottomPadding: CGFloat = 80

        // Bot card
        static let cardCornerRadius: CGFloat = 12
        static let cardBorderWidth: CGFloat = 2
        static let cardActiveBorderWidth: CGFloat = 3
        static let cardPaddingH: CGFloat = 14
        static let cardPaddingV: CGFloat = 10
        static let cardActivePaddingV: CGFloat = 14
        static let cardSpacing: CGFloat = 14

        // Portrait
        static let portraitSize: CGFloat = 52
        static let portraitBossSize: CGFloat = 60
        static let portraitGlowSize: CGFloat = 72
        static let portraitDuckSize: CGFloat = 30
        static let portraitDuckBossSize: CGFloat = 36
        static let portraitBorderWidth: CGFloat = 2
        static let portraitActiveBorderWidth: CGFloat = 3
        static let checkmarkSize: CGFloat = 10
        static let checkmarkBadgeSize: CGFloat = 14
        static let crownSize: CGFloat = 14
        static let lockOverlaySize: CGFloat = 14

        // Text
        static let botNameSize: CGFloat = 11
        static let botNameActiveSize: CGFloat = 13
        static let botTitleSize: CGFloat = 7
        static let lockedHintSize: CGFloat = 5
        static let defeatedLabelSize: CGFloat = 6
        static let bossTagSize: CGFloat = 6
        static let bossTagPaddingH: CGFloat = 5
        static let bossTagPaddingV: CGFloat = 2
        static let targetScoreSize: CGFloat = 6

        // Action buttons
        static let fightFontSize: CGFloat = 9
        static let fightPaddingH: CGFloat = 14
        static let fightPaddingV: CGFloat = 7
        static let replayFontSize: CGFloat = 7
        static let replayPaddingH: CGFloat = 10
        static let replayPaddingV: CGFloat = 5
        static let lockedIconSize: CGFloat = 16

        // Connector
        static let connectorWidth: CGFloat = 3
        static let connectorHeight: CGFloat = 28
        static let connectorDotSize: CGFloat = 5
        static let connectorDotSpacing: CGFloat = 8

        // Player marker
        static let playerMarkerSize: CGFloat = 22
        static let playerMarkerBounce: CGFloat = 2

        // Boss card
        static let bossCardCornerRadius: CGFloat = 14
        static let bossCardBorderWidth: CGFloat = 3
        static let bossGlowRadius: CGFloat = 12
        static let bossCrownOffset: CGFloat = -34
    }

    // MARK: - Computed State

    private var beatenCount: Int {
        bots.filter { manager.isBotBeaten($0.id) }.count
    }

    private var progress: CGFloat {
        CGFloat(beatenCount) / CGFloat(bots.count)
    }

    private var allBeaten: Bool {
        beatenCount == bots.count
    }

    // MARK: - Background (shared with HomeView)

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
                    startPoint: .top,
                    endPoint: .bottom
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
                    Rectangle()
                        .fill(Color(red: 0.28, green: 0.52, blue: 0.16))
                        .frame(height: 3)
                    Rectangle()
                        .fill(Color(red: 0.40, green: 0.72, blue: 0.22))
                        .frame(height: 14)
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

    // MARK: - Body

    var body: some View {
        ZStack {
            eightBitBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, Layout.headerHorizontalPadding)
                    .padding(.top, Layout.headerTopPadding)

                progressBar
                    .padding(.horizontal, Layout.progressBarPaddingH)
                    .padding(.top, Layout.progressBarTopPadding)

                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        ladderList
                            .padding(.top, Layout.ladderTopPadding)
                            .padding(.bottom, Layout.ladderBottomPadding)
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
                    .frame(width: Layout.backButtonSize, height: Layout.backButtonSize)
                    .padding(Layout.backButtonPadding)
                    .background(Circle().fill(Color.black.opacity(0.15)))
            }
            .accessibilityLabel("Back")

            Spacer()

            Text("BOT LADDER")
                .font(.custom(GK.pixelFontName, size: Layout.titleFontSize))
                .foregroundColor(.white)
                .shadow(color: GK.Colors.pipeBorder, radius: 0, x: 2, y: 2)

            Spacer()

            HStack(spacing: 4) {
                Image(uiImage: icons.image(for: .swords, pixelScale: 2.0))
                    .interpolation(.none)
                    .resizable()
                    .frame(width: Layout.counterIconSize, height: Layout.counterIconSize)
                Text("\(beatenCount)/\(bots.count)")
                    .font(.custom(GK.pixelFontName, size: Layout.counterFontSize))
                    .foregroundColor(GK.Colors.scoreYellow)
            }
            .padding(.horizontal, Layout.counterPaddingH)
            .padding(.vertical, Layout.counterPaddingV)
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
                    RoundedRectangle(cornerRadius: Layout.progressBarCornerRadius)
                        .fill(Color.black.opacity(0.15))
                        .frame(height: Layout.progressBarHeight)

                    RoundedRectangle(cornerRadius: Layout.progressBarCornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [GK.Colors.buttonGreen, GK.Colors.buttonGreen.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: max(geo.size.width * progress, progress > 0 ? 12 : 0),
                            height: Layout.progressBarHeight
                        )
                }
            }
            .frame(height: Layout.progressBarHeight)

            Text(allBeaten
                 ? "ALL BOTS DEFEATED! 🏆"
                 : "Defeat each bot to unlock their skin")
                .font(.custom(GK.pixelFontName, size: Layout.progressSubtitleFontSize))
                .foregroundColor(.white.opacity(0.6))
        }
    }

    // MARK: - Ladder List

    private var ladderList: some View {
        VStack(spacing: 0) {
            ForEach(Array(bots.reversed().enumerated()), id: \.element.id) { index, bot in
                let realIdx = bots.count - 1 - index
                let beaten = manager.isBotBeaten(bot.id)
                let isNext = realIdx == manager.nextBotIndex
                let locked = realIdx > manager.nextBotIndex
                let isBoss = realIdx == bots.count - 1

                if index > 0 {
                    connectorSegment(
                        completed: beaten,
                        active: isNext,
                        color: bot.accentColor
                    )
                }

                if isBoss {
                    bossCard(bot: bot, beaten: beaten, isNext: isNext, locked: locked)
                        .id(bot.id)
                } else {
                    botCard(bot: bot, beaten: beaten, isNext: isNext, locked: locked)
                        .id(bot.id)
                }
            }
        }
        .padding(.horizontal, Layout.ladderPaddingH)
    }

    // MARK: - Standard Bot Card

    private func botCard(
        bot: BotCharacter,
        beaten: Bool,
        isNext: Bool,
        locked: Bool
    ) -> some View {
        Button {
            if !locked {
                SoundManager.shared.play(.button)
                manager.startBotLadderMatch(bot)
            }
        } label: {
            HStack(spacing: Layout.cardSpacing) {
                botPortrait(bot: bot, beaten: beaten, isNext: isNext, locked: locked, isBoss: false)

                botInfo(bot: bot, beaten: beaten, isNext: isNext, locked: locked, isBoss: false)

                Spacer()

                cardAction(bot: bot, beaten: beaten, isNext: isNext, locked: locked)
            }
            .padding(.horizontal, Layout.cardPaddingH)
            .padding(.vertical, isNext ? Layout.cardActivePaddingV : Layout.cardPaddingV)
            .background(cardBackground(bot: bot, isNext: isNext, beaten: beaten, locked: locked))
            .overlay(cardBorder(bot: bot, isNext: isNext, beaten: beaten, locked: locked))
            .opacity(locked ? 0.55 : 1.0)
            .overlay(alignment: .leading) {
                if isNext { playerMarker }
            }
        }
        .buttonStyle(.plain)
        .disabled(locked)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(botAccessibilityLabel(bot: bot, beaten: beaten, isNext: isNext, locked: locked))
        .accessibilityHint(botAccessibilityHint(beaten: beaten, isNext: isNext, locked: locked))
    }

    // MARK: - Boss Card (THE DUCK)

    private func bossCard(
        bot: BotCharacter,
        beaten: Bool,
        isNext: Bool,
        locked: Bool
    ) -> some View {
        Button {
            if !locked {
                SoundManager.shared.play(.button)
                manager.startBotLadderMatch(bot)
            }
        } label: {
            VStack(spacing: 0) {
                // Crown + title banner
                if !locked {
                    HStack(spacing: 6) {
                        Image(uiImage: icons.image(for: .crown, pixelScale: 2.0))
                            .interpolation(.none)
                            .resizable()
                            .frame(width: Layout.crownSize, height: Layout.crownSize)

                        Text("FINAL BOSS")
                            .font(.custom(GK.pixelFontName, size: Layout.bossTagSize))
                            .foregroundColor(GK.Colors.scoreYellow)

                        Image(uiImage: icons.image(for: .crown, pixelScale: 2.0))
                            .interpolation(.none)
                            .resizable()
                            .frame(width: Layout.crownSize, height: Layout.crownSize)
                    }
                    .padding(.vertical, 6)
                }

                // Main card content
                HStack(spacing: Layout.cardSpacing) {
                    botPortrait(bot: bot, beaten: beaten, isNext: isNext, locked: locked, isBoss: true)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(bot.name)
                            .font(.custom(GK.pixelFontName, size: isNext ? Layout.botNameActiveSize + 2 : Layout.botNameActiveSize))
                            .foregroundColor(locked ? GK.Colors.panelBorder.opacity(0.3) : GK.Colors.panelBorder)

                        if !locked {
                            Text(bot.title.uppercased())
                                .font(.custom(GK.pixelFontName, size: Layout.botTitleSize))
                                .foregroundColor(
                                    beaten ? bot.accentColor.opacity(0.6) :
                                    GK.Colors.panelBorder.opacity(0.5)
                                )

                            Text("TARGET: \(bot.targetScore) PIPES")
                                .font(.custom(GK.pixelFontName, size: Layout.targetScoreSize))
                                .foregroundColor(GK.Colors.buttonRed.opacity(0.6))
                                .padding(.top, 1)
                        } else {
                            Text("DEFEAT ALL BOTS TO FACE THE DUCK")
                                .font(.custom(GK.pixelFontName, size: Layout.lockedHintSize))
                                .foregroundColor(GK.Colors.panelBorder.opacity(0.25))
                        }

                        if beaten {
                            HStack(spacing: 4) {
                                Image(uiImage: icons.image(for: .trophy, pixelScale: 2.0))
                                    .interpolation(.none)
                                    .resizable()
                                    .frame(width: 10, height: 10)
                                Text("CHAMPION")
                                    .font(.custom(GK.pixelFontName, size: Layout.defeatedLabelSize))
                                    .foregroundColor(GK.Colors.scoreYellow)
                            }
                        }
                    }

                    Spacer()

                    cardAction(bot: bot, beaten: beaten, isNext: isNext, locked: locked)
                }
                .padding(.horizontal, Layout.cardPaddingH)
                .padding(.vertical, Layout.cardActivePaddingV)
            }
            .background(bossCardBackground(bot: bot, isNext: isNext, beaten: beaten, locked: locked))
            .overlay(bossCardBorder(bot: bot, isNext: isNext, beaten: beaten, locked: locked))
            .opacity(locked ? 0.55 : 1.0)
            .shadow(
                color: locked ? .clear :
                       isNext ? bot.accentColor.opacity(0.5) :
                       beaten ? GK.Colors.scoreYellow.opacity(0.2) :
                       .clear,
                radius: isNext ? Layout.bossGlowRadius : 6,
                x: 0, y: 0
            )
            .overlay(alignment: .leading) {
                if isNext { playerMarker }
            }
        }
        .buttonStyle(.plain)
        .disabled(locked)
        .onAppear {
            guard !UIAccessibility.isReduceMotionEnabled else { return }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                bossGlow = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(botAccessibilityLabel(bot: bot, beaten: beaten, isNext: isNext, locked: locked))
        .accessibilityHint(botAccessibilityHint(beaten: beaten, isNext: isNext, locked: locked))
    }

    // MARK: - Bot Portrait

    private func botPortrait(
        bot: BotCharacter,
        beaten: Bool,
        isNext: Bool,
        locked: Bool,
        isBoss: Bool
    ) -> some View {
        let size = isBoss ? Layout.portraitBossSize : Layout.portraitSize
        let duckSize = isBoss ? Layout.portraitDuckBossSize : Layout.portraitDuckSize

        return ZStack {
            // Glow ring for current challenge
            if isNext {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [bot.accentColor.opacity(0.3), .clear],
                            center: .center, startRadius: 12, endRadius: 38
                        )
                    )
                    .frame(width: Layout.portraitGlowSize, height: Layout.portraitGlowSize)
            }

            // Portrait background circle
            Circle()
                .fill(
                    locked ? Color.black.opacity(0.08) :
                    beaten ? bot.accentColor.opacity(0.12) :
                    bot.accentColor.opacity(0.15)
                )
                .frame(width: size, height: size)
                .overlay(
                    Circle().stroke(
                        isNext ? bot.accentColor :
                        beaten ? GK.Colors.buttonGreen.opacity(0.5) :
                        locked ? GK.Colors.panelBorder.opacity(0.15) :
                        bot.accentColor.opacity(0.3),
                        lineWidth: isNext ? Layout.portraitActiveBorderWidth : Layout.portraitBorderWidth
                    )
                )

            // Duck sprite
            if locked {
                Image(uiImage: factory.skinDuckUIImage(skin: bot.skin, pixelScale: 5.0))
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: duckSize, height: duckSize)
                    .colorMultiply(.black)
                    .opacity(0.25)
            } else {
                Image(uiImage: factory.skinDuckUIImage(skin: bot.skin, pixelScale: 5.0))
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: duckSize, height: duckSize)
            }

            // Lock overlay
            if locked {
                Image(uiImage: icons.image(for: .lock, pixelScale: 2.0))
                    .interpolation(.none)
                    .resizable()
                    .frame(width: Layout.lockOverlaySize, height: Layout.lockOverlaySize)
            }

            // Beaten checkmark badge
            if beaten {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image(uiImage: icons.image(for: .checkmark))
                            .interpolation(.none)
                            .resizable()
                            .frame(width: Layout.checkmarkSize, height: Layout.checkmarkSize)
                            .background(
                                Circle()
                                    .fill(GK.Colors.buttonGreen)
                                    .frame(width: Layout.checkmarkBadgeSize, height: Layout.checkmarkBadgeSize)
                            )
                    }
                }
                .frame(width: size - 4, height: size - 4)
            }

            // Boss crown (non-boss crowns handled inline)
            if isBoss && !locked {
                Image(uiImage: icons.image(for: .crown, pixelScale: 2.0))
                    .interpolation(.none)
                    .resizable()
                    .frame(width: Layout.crownSize, height: Layout.crownSize)
                    .offset(y: Layout.bossCrownOffset)
            }
        }
        .frame(width: Layout.portraitGlowSize)
    }

    // MARK: - Bot Info

    private func botInfo(
        bot: BotCharacter,
        beaten: Bool,
        isNext: Bool,
        locked: Bool,
        isBoss: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(bot.name)
                    .font(.custom(GK.pixelFontName, size: isNext ? Layout.botNameActiveSize : Layout.botNameSize))
                    .foregroundColor(
                        locked ? GK.Colors.panelBorder.opacity(0.3) :
                        GK.Colors.panelBorder
                    )

                if isBoss && !locked {
                    Text("BOSS")
                        .font(.custom(GK.pixelFontName, size: Layout.bossTagSize))
                        .foregroundColor(.white)
                        .padding(.horizontal, Layout.bossTagPaddingH)
                        .padding(.vertical, Layout.bossTagPaddingV)
                        .background(Capsule().fill(bot.accentColor))
                }
            }

            if !locked {
                Text(bot.title.uppercased())
                    .font(.custom(GK.pixelFontName, size: Layout.botTitleSize))
                    .foregroundColor(
                        beaten ? bot.accentColor.opacity(0.6) :
                        GK.Colors.panelBorder.opacity(0.5)
                    )

                if isNext {
                    Text("TARGET: \(bot.targetScore) PIPES")
                        .font(.custom(GK.pixelFontName, size: Layout.targetScoreSize))
                        .foregroundColor(bot.accentColor.opacity(0.7))
                        .padding(.top, 1)
                }
            } else {
                Text("BEAT PREVIOUS BOTS TO UNLOCK")
                    .font(.custom(GK.pixelFontName, size: Layout.lockedHintSize))
                    .foregroundColor(GK.Colors.panelBorder.opacity(0.25))
            }

            if beaten {
                HStack(spacing: 4) {
                    Image(uiImage: icons.image(for: .checkmark))
                        .interpolation(.none)
                        .resizable()
                        .frame(width: 8, height: 8)
                    Text("DEFEATED")
                        .font(.custom(GK.pixelFontName, size: Layout.defeatedLabelSize))
                        .foregroundColor(GK.Colors.buttonGreen.opacity(0.8))
                }
            }
        }
    }

    // MARK: - Card Action (right side)

    private func cardAction(
        bot: BotCharacter,
        beaten: Bool,
        isNext: Bool,
        locked: Bool
    ) -> some View {
        Group {
            if isNext {
                Text("FIGHT")
                    .font(.custom(GK.pixelFontName, size: Layout.fightFontSize))
                    .foregroundColor(.white)
                    .padding(.horizontal, Layout.fightPaddingH)
                    .padding(.vertical, Layout.fightPaddingV)
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
                    .font(.custom(GK.pixelFontName, size: Layout.replayFontSize))
                    .foregroundColor(GK.Colors.panelBorder.opacity(0.5))
                    .padding(.horizontal, Layout.replayPaddingH)
                    .padding(.vertical, Layout.replayPaddingV)
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
                    .frame(width: Layout.lockedIconSize, height: Layout.lockedIconSize)
                    .opacity(0.2)
            }
        }
    }

    // MARK: - Card Backgrounds & Borders

    private func cardBackground(
        bot: BotCharacter,
        isNext: Bool,
        beaten: Bool,
        locked: Bool
    ) -> some View {
        RoundedRectangle(cornerRadius: Layout.cardCornerRadius)
            .fill(GK.Colors.panelCream)
            .shadow(
                color: isNext ? bot.accentColor.opacity(0.3) : Color.black.opacity(0.1),
                radius: isNext ? 6 : 0,
                x: 0,
                y: isNext ? 4 : 3
            )
    }

    private func cardBorder(
        bot: BotCharacter,
        isNext: Bool,
        beaten: Bool,
        locked: Bool
    ) -> some View {
        RoundedRectangle(cornerRadius: Layout.cardCornerRadius)
            .stroke(
                isNext ? bot.accentColor :
                beaten ? GK.Colors.buttonGreen.opacity(0.3) :
                GK.Colors.panelBorder.opacity(locked ? 0.08 : 0.15),
                lineWidth: isNext ? Layout.cardActiveBorderWidth : Layout.cardBorderWidth
            )
    }

    @ViewBuilder
    private func bossCardBackground(
        bot: BotCharacter,
        isNext: Bool,
        beaten: Bool,
        locked: Bool
    ) -> some View {
        if locked {
            RoundedRectangle(cornerRadius: Layout.bossCardCornerRadius)
                .fill(GK.Colors.panelCream)
                .shadow(color: Color.black.opacity(0.1), radius: 0, x: 0, y: 3)
        } else {
            RoundedRectangle(cornerRadius: Layout.bossCardCornerRadius)
                .fill(
                    LinearGradient(
                        colors: [
                            GK.Colors.panelCream,
                            Color(red: 1.0, green: 0.97, blue: 0.85),
                            GK.Colors.panelCream,
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(
                    color: isNext ? bot.accentColor.opacity(0.3) : Color.black.opacity(0.1),
                    radius: isNext ? 8 : 0,
                    x: 0,
                    y: isNext ? 4 : 3
                )
        }
    }

    private func bossCardBorder(
        bot: BotCharacter,
        isNext: Bool,
        beaten: Bool,
        locked: Bool
    ) -> some View {
        RoundedRectangle(cornerRadius: Layout.bossCardCornerRadius)
            .stroke(
                locked ? GK.Colors.panelBorder.opacity(0.08) :
                isNext ? GK.Colors.scoreYellow :
                beaten ? GK.Colors.scoreYellow.opacity(0.4) :
                GK.Colors.scoreYellow.opacity(0.3),
                lineWidth: locked ? Layout.cardBorderWidth : Layout.bossCardBorderWidth
            )
    }

    // MARK: - Connector Segment

    private func connectorSegment(completed: Bool, active: Bool, color: Color) -> some View {
        VStack(spacing: Layout.connectorDotSpacing) {
            ForEach(0..<3, id: \.self) { _ in
                Circle()
                    .fill(
                        completed ? GK.Colors.buttonGreen.opacity(0.5) :
                        active    ? color.opacity(0.4) :
                                    Color.black.opacity(0.08)
                    )
                    .frame(width: Layout.connectorDotSize, height: Layout.connectorDotSize)
            }
        }
        .frame(height: Layout.connectorHeight)
    }

    // MARK: - Player Marker

    private var playerMarker: some View {
        Image(uiImage: factory.skinDuckUIImage(
            skin: SkinManager.shared.selectedSkin, pixelScale: 3.5))
            .interpolation(.none)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: Layout.playerMarkerSize, height: Layout.playerMarkerSize)
            .shadow(color: .white.opacity(0.6), radius: 3)
            .offset(x: 6, y: playerBounce ? -Layout.playerMarkerBounce : Layout.playerMarkerBounce)
            .animation(
                .easeInOut(duration: 0.5).repeatForever(autoreverses: true),
                value: playerBounce
            )
            .onAppear { playerBounce = true }
    }

    // MARK: - Accessibility

    private func botAccessibilityLabel(
        bot: BotCharacter,
        beaten: Bool,
        isNext: Bool,
        locked: Bool
    ) -> String {
        "\(bot.name), \(bot.title)" +
        (beaten ? ", beaten" : isNext ? ", next challenge" : locked ? ", locked" : "")
    }

    private func botAccessibilityHint(beaten: Bool, isNext: Bool, locked: Bool) -> String {
        isNext ? "Double-tap to challenge" :
        locked ? "Beat previous bots to unlock" :
        beaten ? "Double-tap to replay" : ""
    }
}
