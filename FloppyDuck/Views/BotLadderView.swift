import SwiftUI

struct BotLadderView: View {
    @EnvironmentObject var manager: GameManager
    private let bots = BotCharacter.all
    private let icons = PixelIconFactory.shared
    private let factory = TextureFactory.shared

    var body: some View {
        ZStack {
            // Dark dramatic background (matches VS intro vibe)
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.06, blue: 0.12),
                    Color(red: 0.10, green: 0.08, blue: 0.18),
                    Color(red: 0.05, green: 0.05, blue: 0.10),
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        ladderPath
                            .padding(.vertical, 24)
                            .padding(.horizontal, 16)
                    }
                    .onAppear {
                        let idx = manager.nextBotIndex
                        if idx < bots.count {
                            withAnimation { proxy.scrollTo(bots[idx].id, anchor: .center) }
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
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
            .accessibilityLabel("Back")
            Spacer()
            VStack(spacing: 2) {
                Text("⚔️ BOT LADDER")
                    .font(.custom(GK.pixelFontName, size: 16))
                    .foregroundColor(.white)
                Text("Defeat each challenger to unlock their skin")
                    .font(.custom(GK.pixelFontName, size: 5))
                    .foregroundColor(.white.opacity(0.4))
            }
            Spacer()
            // Progress counter
            let beaten = bots.filter { manager.isBotBeaten($0.id) }.count
            VStack(spacing: 1) {
                Text("\(beaten)/\(bots.count)")
                    .font(.custom(GK.pixelFontName, size: 14))
                    .foregroundColor(GK.Colors.scoreYellow)
                Text("BEATEN")
                    .font(.custom(GK.pixelFontName, size: 5))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(8)
            .accessibilityLabel("\(beaten) of \(bots.count) bots beaten")
        }
    }

    // MARK: - Ladder Path

    private var ladderPath: some View {
        // Reversed so hardest is at top, easiest at bottom (like climbing)
        VStack(spacing: 0) {
            ForEach(Array(bots.reversed().enumerated()), id: \.element.id) { index, bot in
                let realIndex = bots.count - 1 - index
                let beaten = manager.isBotBeaten(bot.id)
                let isNext = realIndex == manager.nextBotIndex
                let locked = realIndex > manager.nextBotIndex

                botCard(bot: bot, index: realIndex, beaten: beaten, isNext: isNext, locked: locked)
                    .id(bot.id)
                    // Zigzag offset
                    .offset(x: index % 2 == 0 ? -20 : 20)

                if index < bots.count - 1 {
                    pathSegment(beaten: manager.isBotBeaten(bots[bots.count - 2 - index].id))
                }
            }
        }
    }

    // MARK: - Bot Card

    private func botCard(bot: BotCharacter, index: Int, beaten: Bool, isNext: Bool, locked: Bool) -> some View {
        Button {
            if !locked {
                SoundManager.shared.play(.button)
                manager.startBotLadderMatch(bot)
            }
        } label: {
            HStack(spacing: 16) {
                // Duck portrait with accent ring
                ZStack {
                    // Glow ring for current challenge
                    if isNext {
                        Circle()
                            .fill(bot.accentColor.opacity(0.2))
                            .frame(width: 76, height: 76)

                        Circle()
                            .stroke(bot.accentColor, lineWidth: 2)
                            .frame(width: 76, height: 76)
                    }

                    // Background circle
                    Circle()
                        .fill(
                            locked ? Color.gray.opacity(0.15) :
                            beaten ? bot.accentColor.opacity(0.15) :
                            bot.accentColor.opacity(0.2)
                        )
                        .frame(width: 64, height: 64)

                    Circle()
                        .stroke(
                            locked ? Color.gray.opacity(0.3) :
                            beaten ? bot.accentColor.opacity(0.5) :
                            bot.accentColor,
                            lineWidth: 2
                        )
                        .frame(width: 64, height: 64)

                    if beaten {
                        // Show bot's duck sprite with a checkmark badge
                        ZStack {
                            Image(uiImage: factory.skinDuckUIImage(skin: bot.skin, pixelScale: 5.0))
                                .interpolation(.none)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 40, height: 40)

                            // Victory checkmark badge
                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    Image(uiImage: icons.image(for: .checkmark))
                                        .interpolation(.none)
                                        .resizable()
                                        .frame(width: 14, height: 14)
                                        .background(
                                            Circle()
                                                .fill(GK.Colors.buttonGreen)
                                                .frame(width: 18, height: 18)
                                        )
                                }
                            }
                            .frame(width: 50, height: 50)
                        }
                    } else if locked {
                        // Silhouette — dark mystery duck
                        Image(uiImage: factory.skinDuckUIImage(skin: bot.skin, pixelScale: 5.0))
                            .interpolation(.none)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 40, height: 40)
                            .colorMultiply(Color.black)
                            .opacity(0.5)

                        Image(uiImage: icons.image(for: .lock, pixelScale: 2.5))
                            .interpolation(.none)
                            .resizable()
                            .frame(width: 18, height: 18)
                    } else {
                        // Current challenge — show the bot's duck in full color
                        Image(uiImage: factory.skinDuckUIImage(skin: bot.skin, pixelScale: 5.0))
                            .interpolation(.none)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 40, height: 40)
                    }
                }
                .shadow(color: isNext ? bot.accentColor.opacity(0.6) : .clear, radius: 10)

                // Info column
                VStack(alignment: .leading, spacing: 4) {
                    // Name + title
                    HStack(spacing: 6) {
                        Text(bot.name)
                            .font(.custom(GK.pixelFontName, size: 13))
                            .foregroundColor(locked ? .gray.opacity(0.5) : .white)

                        if beaten {
                            Text("✓")
                                .font(.custom(GK.pixelFontName, size: 10))
                                .foregroundColor(GK.Colors.buttonGreen)
                        }
                    }

                    Text(bot.title.uppercased())
                        .font(.custom(GK.pixelFontName, size: 7))
                        .foregroundColor(locked ? .gray.opacity(0.3) :
                                         beaten ? bot.accentColor.opacity(0.7) :
                                         bot.accentColor)

                    // Stats row
                    HStack(spacing: 8) {
                        Label {
                            Text("\(bot.elo)")
                                .font(.custom(GK.pixelFontName, size: 6))
                        } icon: {
                            Text("⚡")
                                .font(.system(size: 8))
                        }
                        .foregroundColor(locked ? .gray.opacity(0.4) : .white.opacity(0.5))

                        if !locked {
                            Text("💀 DIES AT \(bot.targetScore)")
                                .font(.custom(GK.pixelFontName, size: 6))
                                .foregroundColor(.white.opacity(0.4))
                        }
                    }

                    // Taunt — always visible for unlocked bots
                    if !locked {
                        Text("\"\(bot.taunt)\"")
                            .font(.custom(GK.pixelFontName, size: 5))
                            .italic()
                            .foregroundColor(.white.opacity(isNext ? 0.6 : 0.3))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Skin reward badge
                    if !locked {
                        HStack(spacing: 4) {
                            Image(uiImage: factory.skinDuckUIImage(skin: bot.skin, pixelScale: 3.0))
                                .interpolation(.none)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 14, height: 14)

                            Text(beaten ? "SKIN UNLOCKED" : "UNLOCKS \(bot.skin.displayName) SKIN")
                                .font(.custom(GK.pixelFontName, size: 5))
                                .foregroundColor(beaten ? GK.Colors.buttonGreen.opacity(0.8) :
                                                 GK.Colors.scoreYellow.opacity(0.7))
                        }
                        .padding(.top, 2)
                    }
                }

                Spacer()

                // Right action indicator
                if isNext {
                    VStack(spacing: 4) {
                        Image(uiImage: icons.image(for: .play, pixelScale: 3.0))
                            .interpolation(.none)
                            .resizable()
                            .frame(width: 24, height: 24)
                        Text("FIGHT")
                            .font(.custom(GK.pixelFontName, size: 6))
                            .foregroundColor(bot.accentColor)
                    }
                } else if beaten {
                    VStack(spacing: 4) {
                        Image(uiImage: icons.image(for: .play, pixelScale: 2.5))
                            .interpolation(.none)
                            .resizable()
                            .frame(width: 18, height: 18)
                            .opacity(0.4)
                        Text("REPLAY")
                            .font(.custom(GK.pixelFontName, size: 5))
                            .foregroundColor(.white.opacity(0.3))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        isNext ? bot.accentColor.opacity(0.12) :
                        beaten ? Color.white.opacity(0.04) :
                        Color.white.opacity(0.02)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        isNext ? bot.accentColor.opacity(0.6) :
                        beaten ? bot.accentColor.opacity(0.15) :
                        Color.white.opacity(0.06),
                        lineWidth: isNext ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(locked)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(bot.name), \(bot.title), dies at \(bot.targetScore)\(beaten ? ", beaten, \(bot.skin.displayName) skin unlocked" : isNext ? ", next challenge" : locked ? ", locked" : "")")
        .accessibilityHint(isNext ? "Double-tap to challenge" : locked ? "Beat previous bots to unlock" : beaten ? "Double-tap to replay" : "")
    }

    // MARK: - Path Segment

    private func pathSegment(beaten: Bool) -> some View {
        VStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { _ in
                Circle()
                    .fill(beaten ? GK.Colors.buttonGreen.opacity(0.5) : Color.white.opacity(0.1))
                    .frame(width: 4, height: 4)
            }
        }
        .frame(height: 28)
    }
}
