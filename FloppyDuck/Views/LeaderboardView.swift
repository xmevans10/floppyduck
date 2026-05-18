import SwiftUI

enum LeaderboardMode: String, CaseIterable {
    case elo = "ELO"
    case highScore = "HIGH SCORES"
}

struct LeaderboardView: View {
    @EnvironmentObject var manager: GameManager

    @State private var eloEntries: [LeaderboardEntry] = []
    @State private var highScoreEntries: [HighScoreEntry] = []
    @State private var isLoading: Bool = true
    @State private var errorMessage: String? = nil
    @State private var mode: LeaderboardMode = .elo

    private let icons = PixelIconFactory.shared

    private var currentUserId: String? {
        manager.authManager?.identity?.userId
    }

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
                    Text("LEADERBOARD")
                        .font(.custom(GK.pixelFontName, size: 18))
                        .foregroundColor(.white)
                        .shadow(color: GK.Colors.pipeBorder, radius: 0, x: 2, y: 2)
                    Spacer()
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                // Mode picker
                Picker("Leaderboard Mode", selection: $mode) {
                    ForEach(LeaderboardMode.allCases, id: \.self) { m in
                        Text(m.rawValue)
                            .font(.custom(GK.pixelFontName, size: 9))
                            .tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 30)
                .padding(.top, 8)

                if isLoading {
                    Spacer()
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(.white)
                        Text("LOADING...")
                            .font(.custom(GK.pixelFontName, size: 8))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    Spacer()
                } else if let error = errorMessage {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(uiImage: PixelIconFactory.shared.image(for: .warning, pixelScale: 4.0))
                            .interpolation(.none)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 36, height: 36)
                        Text("COULD NOT LOAD LEADERBOARD")
                            .font(.custom(GK.pixelFontName, size: 9))
                            .foregroundColor(.white)
                        Text(error)
                            .font(.custom(GK.pixelFontName, size: 7))
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                        Button {
                            Task { await loadLeaderboard() }
                        } label: {
                            Text("RETRY")
                                .font(.custom(GK.pixelFontName, size: 9))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(GK.Colors.buttonBlue)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Retry loading leaderboard")
                    }
                    .padding(30)
                    Spacer()
                } else if currentEntries().isEmpty {
                    Spacer()
                    Text("NO RANKINGS YET")
                        .font(.custom(GK.pixelFontName, size: 10))
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                } else {
                    ScrollViewReader { proxy in
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 8) {
                                if mode == .elo {
                                    ForEach(eloEntries) { entry in
                                        eloRow(entry)
                                            .id(entry.id)
                                    }
                                } else {
                                    ForEach(highScoreEntries) { entry in
                                        highScoreRow(entry)
                                            .id(entry.id)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 14)
                            .padding(.bottom, 30)
                        }
                        .refreshable {
                            await loadLeaderboard()
                        }
                        .onChange(of: mode) { _, _ in
                            Task { await loadLeaderboard() }
                        }
                        .onChange(of: eloEntries.map { $0.id }) { _, _ in
                            scrollToCurrentPlayer(proxy: proxy)
                        }
                        .onChange(of: highScoreEntries.map { $0.id }) { _, _ in
                            scrollToCurrentPlayer(proxy: proxy)
                        }
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .task {
            await loadLeaderboard()
        }
    }

    private func currentEntries() -> [any Identifiable] {
        mode == .elo ? eloEntries : highScoreEntries
    }

    private func currentEntryIds() -> Set<String> {
        mode == .elo ? Set(eloEntries.map { $0.id }) : Set(highScoreEntries.map { $0.id })
    }

    // MARK: - Auto-Scroll

    private func scrollToCurrentPlayer(proxy: ScrollViewProxy) {
        guard let userId = currentUserId,
              currentEntryIds().contains(userId) else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeInOut(duration: 0.3)) {
                proxy.scrollTo(userId, anchor: .center)
            }
        }
    }

    // MARK: - Load Data

    private func loadLeaderboard() async {
        isLoading = currentEntries().isEmpty
        errorMessage = nil
        do {
            switch mode {
            case .elo:
                eloEntries = try await ConvexClient.shared.getLeaderboard(limit: 50)
            case .highScore:
                highScoreEntries = try await ConvexClient.shared.getHighScoreLeaderboard(limit: 50)
            }
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    // MARK: - ELO Row

    private func eloRow(_ entry: LeaderboardEntry) -> some View {
        let isCurrentPlayer = entry.id == currentUserId

        return HStack(spacing: 12) {
            Text("#\(entry.rank)")
                .font(.custom(GK.pixelFontName, size: 12))
                .foregroundColor(rankColor(entry.rank))
                .frame(width: 44, alignment: .leading)

            Text(entry.username)
                .font(.custom(GK.pixelFontName, size: 10))
                .foregroundColor(isCurrentPlayer ? GK.Colors.scoreYellow : GK.Colors.panelBorder)
                .lineLimit(1)

            Spacer()

            Text("\(entry.rating)")
                .font(.custom(GK.pixelFontName, size: 12))
                .foregroundColor(GK.Colors.panelBorder)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isCurrentPlayer ? Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.12) : GK.Colors.panelCream)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isCurrentPlayer ? GK.Colors.scoreYellow : GK.Colors.panelBorder,
                        lineWidth: isCurrentPlayer ? 3 : 2)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Rank \(entry.rank), \(entry.username), rating \(entry.rating)\(isCurrentPlayer ? ", you" : "")")
    }

    // MARK: - High Score Row

    private func highScoreRow(_ entry: HighScoreEntry) -> some View {
        let isCurrentPlayer = entry.id == currentUserId

        return HStack(spacing: 12) {
            Text("#\(entry.rank)")
                .font(.custom(GK.pixelFontName, size: 12))
                .foregroundColor(rankColor(entry.rank))
                .frame(width: 44, alignment: .leading)

            Text(entry.username)
                .font(.custom(GK.pixelFontName, size: 10))
                .foregroundColor(isCurrentPlayer ? GK.Colors.scoreYellow : GK.Colors.panelBorder)
                .lineLimit(1)

            Spacer()

            Text("\(entry.bestScore)")
                .font(.custom(GK.pixelFontName, size: 12))
                .foregroundColor(GK.Colors.panelBorder)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isCurrentPlayer ? Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.12) : GK.Colors.panelCream)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isCurrentPlayer ? GK.Colors.scoreYellow : GK.Colors.panelBorder,
                        lineWidth: isCurrentPlayer ? 3 : 2)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Rank \(entry.rank), \(entry.username), score \(entry.bestScore)\(isCurrentPlayer ? ", you" : "")")
    }

    // MARK: - Shared Helpers

    private func rankColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return Color(red: 1.0, green: 0.84, blue: 0.0)
        case 2: return Color(red: 0.75, green: 0.75, blue: 0.80)
        case 3: return Color(red: 0.80, green: 0.50, blue: 0.20)
        default: return GK.Colors.panelBorder.opacity(0.6)
        }
    }
}
