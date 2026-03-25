import SwiftUI

// MARK: - Bot Ladder View (Mario-style world map)
//
// Presents the 8-bot ladder as a winding node-to-node path.  Circles
// represent each bot; a drawn path connects them bottom-to-top.  The
// player's duck sits on the current challenge node.  Bot death-scores
// are intentionally hidden — the player discovers them through gameplay.

struct BotLadderView: View {
    @EnvironmentObject var manager: GameManager
    @State private var playerBounce = false

    private let bots = BotCharacter.all
    private let icons = PixelIconFactory.shared
    private let factory = TextureFactory.shared

    /// Zigzag x-offsets for each bot index (0 = easiest, 7 = boss).
    /// THE DUCK (final boss) is centered; others wind left ↔ right.
    private let nodeOffsets: [CGFloat] = [-65, 65, -55, 70, -60, 60, -50, 0]

    var body: some View {
        ZStack {
            // Deep-space background
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.04, blue: 0.10),
                    Color(red: 0.08, green: 0.06, blue: 0.16),
                    Color(red: 0.03, green: 0.03, blue: 0.08),
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        worldMap
                            .padding(.top, 40)
                            .padding(.bottom, 80)
                    }
                    .onAppear {
                        let idx = manager.nextBotIndex
                        if idx < bots.count {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
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
                    .frame(width: 28, height: 28)
                    .padding(8)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
            .accessibilityLabel("Back")

            Spacer()

            VStack(spacing: 2) {
                Text("BOT LADDER")
                    .font(.custom(GK.pixelFontName, size: 16))
                    .foregroundColor(.white)
                Text("Defeat each challenger to unlock their skin")
                    .font(.custom(GK.pixelFontName, size: 5))
                    .foregroundColor(.white.opacity(0.4))
            }

            Spacer()

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

    // MARK: - World Map

    private var worldMap: some View {
        // Hardest at top, easiest at bottom — the player climbs the ladder
        VStack(spacing: 0) {
            ForEach(Array(bots.reversed().enumerated()), id: \.element.id) { index, bot in
                let realIdx = bots.count - 1 - index
                let beaten = manager.isBotBeaten(bot.id)
                let isNext = realIdx == manager.nextBotIndex
                let locked = realIdx > manager.nextBotIndex
                let isBoss = realIdx == bots.count - 1

                mapNode(
                    bot: bot,
                    beaten: beaten,
                    isNext: isNext,
                    locked: locked,
                    isBoss: isBoss
                )
                .id(bot.id)
                .offset(x: nodeOffsets[realIdx])

                // Path segment to the node below
                if index < bots.count - 1 {
                    let nextRealIdx = bots.count - 2 - index
                    // Segment is "completed" if the upper (harder) bot is beaten
                    let segCompleted = beaten
                    // Segment is "active" if the lower bot is beaten but upper is current
                    let segActive = !segCompleted && manager.isBotBeaten(bots[nextRealIdx].id)

                    pathSegment(
                        fromOffset: nodeOffsets[realIdx],
                        toOffset: nodeOffsets[nextRealIdx],
                        completed: segCompleted,
                        active: segActive
                    )
                }
            }
        }
    }

    // MARK: - Map Node

    private func mapNode(
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
            VStack(spacing: 5) {
                ZStack {
                    // Ambient glow for current / boss node
                    if isNext {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [bot.accentColor.opacity(0.35), .clear],
                                    center: .center, startRadius: 8, endRadius: 50
                                )
                            )
                            .frame(width: 90, height: 90)
                    } else if isBoss && !locked {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [bot.accentColor.opacity(0.2), .clear],
                                    center: .center, startRadius: 8, endRadius: 55
                                )
                            )
                            .frame(width: 100, height: 100)
                    }

                    let size: CGFloat = isBoss ? 70 : 58

                    // Node disc
                    Circle()
                        .fill(
                            locked ? Color(white: 0.10) :
                            beaten ? bot.accentColor.opacity(0.12) :
                            bot.accentColor.opacity(0.18)
                        )
                        .frame(width: size, height: size)
                        .overlay(
                            Circle().stroke(
                                isNext ? bot.accentColor :
                                beaten ? GK.Colors.buttonGreen.opacity(0.6) :
                                locked ? Color(white: 0.15) :
                                bot.accentColor.opacity(0.35),
                                lineWidth: isNext ? 3 : 2
                            )
                        )

                    // Bot portrait
                    Group {
                        if locked {
                            Image(uiImage: factory.skinDuckUIImage(skin: bot.skin, pixelScale: 5.0))
                                .interpolation(.none)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: isBoss ? 42 : 34, height: isBoss ? 42 : 34)
                                .colorMultiply(.black)
                                .opacity(0.4)
                        } else {
                            Image(uiImage: factory.skinDuckUIImage(skin: bot.skin, pixelScale: 5.0))
                                .interpolation(.none)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: isBoss ? 42 : 34, height: isBoss ? 42 : 34)
                        }
                    }

                    // Lock icon
                    if locked {
                        Image(uiImage: icons.image(for: .lock, pixelScale: 2.0))
                            .interpolation(.none)
                            .resizable()
                            .frame(width: 14, height: 14)
                    }

                    // Green ✓ badge for beaten bots
                    if beaten {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Image(uiImage: icons.image(for: .checkmark))
                                    .interpolation(.none)
                                    .resizable()
                                    .frame(width: 12, height: 12)
                                    .background(
                                        Circle()
                                            .fill(GK.Colors.buttonGreen)
                                            .frame(width: 16, height: 16)
                                    )
                            }
                        }
                        .frame(width: size - 6, height: size - 6)
                    }

                    // Player duck marker (bounces beside the current node)
                    if isNext {
                        Image(uiImage: factory.skinDuckUIImage(
                            skin: SkinManager.shared.selectedSkin, pixelScale: 4.0))
                            .interpolation(.none)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 26, height: 26)
                            .shadow(color: .white.opacity(0.6), radius: 4)
                            .offset(x: -(size / 2 + 18), y: playerBounce ? -2 : 2)
                            .animation(
                                .easeInOut(duration: 0.5).repeatForever(autoreverses: true),
                                value: playerBounce
                            )
                            .onAppear { playerBounce = true }
                    }

                    // Crown above the final boss
                    if isBoss && !locked {
                        Image(uiImage: icons.image(for: .crown, pixelScale: 2.0))
                            .interpolation(.none)
                            .resizable()
                            .frame(width: 16, height: 16)
                            .offset(y: -(size / 2 + 8))
                    }
                }

                // Bot name
                Text(bot.name)
                    .font(.custom(GK.pixelFontName, size: isNext ? 10 : 7))
                    .foregroundColor(
                        locked ? .white.opacity(0.18) :
                        isNext ? .white :
                        beaten ? bot.accentColor.opacity(0.7) :
                        .white.opacity(0.4)
                    )

                // Subtitle (title only — no scores, keep it a mystery)
                if !locked {
                    Text(bot.title.uppercased())
                        .font(.custom(GK.pixelFontName, size: 5))
                        .foregroundColor(
                            isNext ? bot.accentColor.opacity(0.6) :
                            beaten ? bot.accentColor.opacity(0.4) :
                            .white.opacity(0.2)
                        )
                }

                // FIGHT capsule on the current challenge
                if isNext {
                    Text("FIGHT")
                        .font(.custom(GK.pixelFontName, size: 8))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(bot.accentColor.opacity(0.25))
                                .overlay(
                                    Capsule().stroke(bot.accentColor, lineWidth: 1.5)
                                )
                        )
                        .padding(.top, 2)
                }
            }
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

    // MARK: - Path Segment

    /// Draws an angled line between two nodes — solid green when completed,
    /// dashed white when active (approaching), dim dashed when locked.
    private func pathSegment(
        fromOffset: CGFloat,
        toOffset: CGFloat,
        completed: Bool,
        active: Bool
    ) -> some View {
        GeometryReader { geo in
            let midX = geo.size.width / 2
            let from = CGPoint(x: midX + fromOffset, y: 2)
            let to = CGPoint(x: midX + toOffset, y: geo.size.height - 2)

            Path { p in
                p.move(to: from)
                p.addLine(to: to)
            }
            .stroke(
                completed ? GK.Colors.buttonGreen.opacity(0.5) :
                active    ? Color.white.opacity(0.20) :
                            Color.white.opacity(0.07),
                style: StrokeStyle(
                    lineWidth: completed ? 3 : 2,
                    lineCap: .round,
                    dash: completed ? [] : [6, 5]
                )
            )
        }
        .frame(height: 50)
    }
}
