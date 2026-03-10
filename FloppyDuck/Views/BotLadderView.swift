import SwiftUI

struct BotLadderView: View {
    @EnvironmentObject var manager: GameManager
    private let bots = BotCharacter.all
    private let icons = PixelIconFactory.shared

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [GK.Colors.skyTop, GK.Colors.skyBottom],
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
                            .padding(.horizontal, 20)
                    }
                    .onAppear {
                        // Scroll to current challenge
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
                    .background(Circle().fill(Color.black.opacity(0.15)))
            }
            Spacer()
            VStack(spacing: 2) {
                Text("BOT LADDER")
                    .font(.custom(GK.pixelFontName, size: 16))
                    .foregroundColor(.white)
                Text("Beat each bot to advance")
                    .font(.custom(GK.pixelFontName, size: 6))
                    .foregroundColor(.white.opacity(0.6))
            }
            Spacer()
            // Progress counter
            let beaten = bots.filter { manager.isBotBeaten($0.id) }.count
            Text("\(beaten)/\(bots.count)")
                .font(.custom(GK.pixelFontName, size: 12))
                .foregroundColor(GK.Colors.scoreYellow)
                .padding(8)
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

                botNode(bot: bot, index: realIndex, beaten: beaten, isNext: isNext, locked: locked)
                    .id(bot.id)
                    // Zigzag offset
                    .offset(x: index % 2 == 0 ? -40 : 40)

                if index < bots.count - 1 {
                    pathSegment(beaten: manager.isBotBeaten(bots[bots.count - 2 - index].id))
                }
            }
        }
    }

    // MARK: - Bot Node

    private func botNode(bot: BotCharacter, index: Int, beaten: Bool, isNext: Bool, locked: Bool) -> some View {
        Button {
            if !locked {
                SoundManager.shared.play(.button)
                manager.startBotLadderMatch(bot)
            }
        } label: {
            HStack(spacing: 14) {
                // Avatar circle
                ZStack {
                    Circle()
                        .fill(locked ? Color.gray.opacity(0.3) : bot.accentColor)
                        .frame(width: 56, height: 56)
                    Circle()
                        .stroke(locked ? Color.gray.opacity(0.5) : Color.black.opacity(0.3), lineWidth: 3)
                        .frame(width: 56, height: 56)

                    if beaten {
                        // Checkmark
                        Image(systemName: "checkmark")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                    } else if locked {
                        Image(uiImage: icons.image(for: .lock, pixelScale: 2.5))
                            .interpolation(.none)
                            .resizable()
                            .frame(width: 22, height: 22)
                    } else {
                        // First letter of name
                        Text(String(bot.name.prefix(1)))
                            .font(.custom(GK.pixelFontName, size: 20))
                            .foregroundColor(.white)
                    }
                }
                .shadow(color: isNext ? bot.accentColor.opacity(0.6) : .clear, radius: 8)
                .scaleEffect(isNext ? 1.1 : 1.0)

                // Info
                VStack(alignment: .leading, spacing: 3) {
                    Text(bot.name)
                        .font(.custom(GK.pixelFontName, size: 11))
                        .foregroundColor(locked ? .gray : .white)

                    Text(bot.title)
                        .font(.custom(GK.pixelFontName, size: 7))
                        .foregroundColor(locked ? .gray.opacity(0.6) : .white.opacity(0.7))

                    HStack(spacing: 6) {
                        Text("ELO \(bot.elo)")
                            .font(.custom(GK.pixelFontName, size: 6))
                            .foregroundColor(locked ? .gray.opacity(0.5) : bot.accentColor)

                        if !locked {
                            Text("•")
                                .foregroundColor(.white.opacity(0.3))
                            Text("SCORE \(bot.targetScore)")
                                .font(.custom(GK.pixelFontName, size: 6))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }

                    if isNext {
                        Text("\"\(bot.taunt)\"")
                            .font(.custom(GK.pixelFontName, size: 5))
                            .italic()
                            .foregroundColor(.white.opacity(0.6))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer()

                if isNext {
                    // Play arrow
                    Image(uiImage: icons.image(for: .play, pixelScale: 2.5))
                        .interpolation(.none)
                        .resizable()
                        .frame(width: 20, height: 20)
                } else if beaten {
                    Text("✓")
                        .font(.custom(GK.pixelFontName, size: 12))
                        .foregroundColor(GK.Colors.buttonGreen)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isNext ? Color.black.opacity(0.35) :
                          beaten ? Color.black.opacity(0.15) :
                          Color.black.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isNext ? bot.accentColor : Color.white.opacity(0.1), lineWidth: isNext ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(locked)
    }

    // MARK: - Path Segment

    private func pathSegment(beaten: Bool) -> some View {
        VStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { _ in
                Circle()
                    .fill(beaten ? GK.Colors.buttonGreen.opacity(0.6) : Color.white.opacity(0.2))
                    .frame(width: 4, height: 4)
            }
        }
        .frame(height: 28)
    }
}
