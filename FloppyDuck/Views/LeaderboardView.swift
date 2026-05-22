import SwiftUI
import os

enum LeaderboardMode: String, CaseIterable {
    case elo = "ELO"
    case highScore = "HIGH SCORES"
}

struct LeaderboardView: View {
    @EnvironmentObject var manager: GameManager

    @State private var eloEntries: [LeaderboardEntry] = []
    @State private var highScoreEntries: [HighScoreEntry] = []
    @State private var isLoading: Bool = true
    @State private var isLoadingMore: Bool = false
    @State private var errorMessage: String? = nil
    @State private var mode: LeaderboardMode = .elo

    private let icons = PixelIconFactory.shared
    private let initialPageSize = 20
    private let fullPageSize = 50
    private let log = Logger(subsystem: "com.xmevans10.FloppyDuck", category: "Leaderboard")

    private var currentUserId: String? {
        manager.authManager?.identity?.userId
    }

    private var hasLoadedAll: Bool {
        switch mode {
        case .elo: return eloEntries.count >= fullPageSize
        case .highScore: return highScoreEntries.count >= fullPageSize
        }
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
                headerView
                modePickerView
                contentView
            }
        }
        .navigationBarHidden(true)
        .task {
            log.debug("task fired — mode=\(self.mode.rawValue)")
            await loadLeaderboard()
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
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
    }

    private var modePickerView: some View {
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
        .onChange(of: mode) { _, newMode in
            log.debug("mode changed to \(newMode.rawValue), entries empty=\(currentEntries().isEmpty)")
            isLoading = true
            errorMessage = nil
            Task { await loadLeaderboard() }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        if isLoading {
            Spacer()
            VStack(spacing: 12) {
                ProgressView().tint(.white)
                Text("LOADING...")
                    .font(.custom(GK.pixelFontName, size: 8))
                    .foregroundColor(.white.opacity(0.7))
            }
            Spacer()
        } else if let error = errorMessage {
            Spacer()
            errorView(error)
            Spacer()
        } else if currentEntries().isEmpty {
            Spacer()
            Text("NO RANKINGS YET")
                .font(.custom(GK.pixelFontName, size: 10))
                .foregroundColor(.white.opacity(0.6))
            Spacer()
        } else {
            entriesListView
        }
    }

    private func errorView(_ error: String) -> some View {
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
                Task { await loadLeaderboard(limit: fullPageSize) }
            } label: {
                Text("RETRY")
                    .font(.custom(GK.pixelFontName, size: 9))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 8).fill(GK.Colors.buttonBlue))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Retry loading leaderboard")
        }
        .padding(30)
    }

    private var entriesListView: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 8) {
                    if mode == .elo {
                        ForEach(eloEntries) { entry in
                            eloRow(entry)
                                .id(entry.id)
                                .onAppear {
                                    if entry.id == eloEntries.last?.id {
                                        Task { await loadMoreIfNeeded() }
                                    }
                                }
                        }
                    } else {
                        ForEach(highScoreEntries) { entry in
                            highScoreRow(entry)
                                .id(entry.id)
                                .onAppear {
                                    if entry.id == highScoreEntries.last?.id {
                                        Task { await loadMoreIfNeeded() }
                                    }
                                }
                        }
                    }

                    if isLoadingMore {
                        HStack {
                            Spacer()
                            ProgressView().tint(.white)
                            Spacer()
                        }
                        .padding(.vertical, 12)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 30)
            }
            .refreshable {
                await loadLeaderboard(limit: fullPageSize)
            }
            .onChange(of: eloEntries.map { $0.id }) { _, _ in
                scrollToCurrentPlayer(proxy: proxy)
            }
            .onChange(of: highScoreEntries.map { $0.id }) { _, _ in
                scrollToCurrentPlayer(proxy: proxy)
            }
        }
    }

    // MARK: - Data Helpers

    private func currentEntries() -> [any Identifiable] {
        mode == .elo ? eloEntries : highScoreEntries
    }

    private func currentEntryIds() -> Set<String> {
        mode == .elo ? Set(eloEntries.map { $0.id }) : Set(highScoreEntries.map { $0.id })
    }

    private func entriesCount() -> Int {
        mode == .elo ? eloEntries.count : highScoreEntries.count
    }

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

    private func loadLeaderboard(limit: Int? = nil) async {
        let requestedLimit = limit ?? initialPageSize
        let isInitialLoad = currentEntries().isEmpty
        if isInitialLoad { isLoading = true }
        errorMessage = nil

        log.debug("loadLeaderboard mode=\(self.mode.rawValue) limit=\(requestedLimit) initialLoad=\(isInitialLoad)")

        do {
            switch mode {
            case .elo:
                let result = try await ConvexClient.shared.getLeaderboard(limit: requestedLimit)
                eloEntries = result
                log.debug("elo loaded: \(result.count) entries")
            case .highScore:
                let result = try await ConvexClient.shared.getHighScoreLeaderboard(limit: requestedLimit)
                highScoreEntries = result
                log.debug("highScore loaded: \(result.count) entries")
            }
            isLoading = false
        } catch {
            log.error("loadLeaderboard failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func loadMoreIfNeeded() async {
        guard !hasLoadedAll, !isLoadingMore else { return }
        isLoadingMore = true
        log.debug("loadMoreIfNeeded mode=\(self.mode.rawValue)")
        do {
            switch mode {
            case .elo:
                eloEntries = try await ConvexClient.shared.getLeaderboard(limit: fullPageSize)
            case .highScore:
                highScoreEntries = try await ConvexClient.shared.getHighScoreLeaderboard(limit: fullPageSize)
            }
        } catch {
            log.error("loadMore failed: \(error.localizedDescription)")
        }
        isLoadingMore = false
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
                .stroke(isCurrentPlayer ? GK.Colors.scoreYellow : GK.Colors.panelBorder, lineWidth: isCurrentPlayer ? 3 : 2)
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
                .stroke(isCurrentPlayer ? GK.Colors.scoreYellow : GK.Colors.panelBorder, lineWidth: isCurrentPlayer ? 3 : 2)
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
