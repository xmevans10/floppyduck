import SwiftUI

struct PublicProfileView: View {
    @EnvironmentObject var manager: GameManager

    let userId: String
    @State private var profile: PublicPlayerProfile?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isAddingFriend = false
    @State private var isBlocking = false
    @State private var showBlockConfirm = false

    private let icons = PixelIconFactory.shared

    var body: some View {
        ZStack {
            backgroundView

            VStack(spacing: 20) {
                headerView

                if isLoading {
                    loadingView
                } else if let errorMessage {
                    errorView(errorMessage)
                } else if let profile {
                    profileContent(profile)
                }
            }
        }
        .navigationBarHidden(true)
        .task {
            await loadProfile()
        }
        .alert("BLOCK PLAYER?", isPresented: $showBlockConfirm) {
            Button("CANCEL", role: .cancel) {}
            Button("BLOCK", role: .destructive) {
                Task { await blockPlayer() }
            }
        } message: {
            guard let profile else { return }
            Text("Block \(profile.username)? They will not be able to send you friend requests.")
        }
    }

    // MARK: - Background

    private var backgroundView: some View {
        GeometryReader { geo in
            Image(uiImage: UIImage(named: "floppy_theme") ?? UIImage())
                .interpolation(.none)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
        }
        .ignoresSafeArea()
    }

    // MARK: - Header

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
                    .background(PixelButtonBackground(style: .light, size: 44))
            }
            .accessibilityLabel("Back")
            Spacer()
            Text("PROFILE")
                .font(.custom(GK.pixelFontName, size: 18))
                .foregroundColor(.white)
                .shadow(color: GK.Colors.pipeBorder, radius: 0, x: 2, y: 2)
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Loading / Error

    private var loadingView: some View {
        Spacer()
        VStack(spacing: 12) {
            ProgressView().tint(.white)
            Text("LOADING...")
                .font(.custom(GK.pixelFontName, size: 8))
                .foregroundColor(.white.opacity(0.7))
        }
        Spacer()
    }

    private func errorView(_ error: String) -> some View {
        Spacer()
        VStack(spacing: 12) {
            Image(uiImage: icons.image(for: .warning, pixelScale: 4.0))
                .interpolation(.none)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 36, height: 36)
            Text("COULD NOT LOAD PROFILE")
                .font(.custom(GK.pixelFontName, size: 9))
                .foregroundColor(.white)
            Text(error)
                .font(.custom(GK.pixelFontName, size: 7))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
            Button {
                Task { await loadProfile() }
            } label: {
                Text("RETRY")
                    .font(.custom(GK.pixelFontName, size: 9))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 8).fill(GK.Colors.buttonBlue))
            }
            .buttonStyle(.plain)
        }
        .padding(30)
        Spacer()
    }

    // MARK: - Content

    private func profileContent(_ profile: PublicPlayerProfile) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                // Username + provider badge
                VStack(spacing: 6) {
                    Text(profile.username)
                        .font(.custom(GK.pixelFontName, size: 22))
                        .foregroundColor(.white)
                        .shadow(color: GK.Colors.pipeBorder, radius: 0, x: 2, y: 2)

                    HStack(spacing: 6) {
                        pixelIcon(profile.provider == .guest ? .classic : .trophy, size: 12)
                        Text(profile.provider == .guest ? "GUEST" : "GAME CENTER")
                            .font(.custom(GK.pixelFontName, size: 7))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(profile.provider == .guest ? GK.Colors.buttonOrange.opacity(0.6) : GK.Colors.buttonGreen.opacity(0.6))
                    )
                }
                .padding(.top, 8)

                // Big stat cards
                HStack(spacing: 12) {
                    statCard(title: "BEST", value: "\(profile.stats.bestScore)", icon: .trophy)
                    statCard(title: "GAMES", value: "\(profile.stats.gamesPlayed)", icon: .play)
                }

                HStack(spacing: 12) {
                    statCard(title: "WIN %", value: String(format: "%.0f%%", profile.stats.winRate * 100), icon: .headToHead)
                    statCard(title: "ELO", value: "\(profile.stats.elo)", icon: .classic)
                }

                // W/L Record + Peak Elo
                HStack(spacing: 12) {
                    wlRecordPanel(profile.stats)
                    peakEloPanel(profile.stats)
                }

                // Win Streak
                winStreakPanel(profile.stats)

                // Bot Ladder Progress
                botLadderPanel(profile.stats)

                // Recent scores
                if !profile.stats.recentScores.isEmpty {
                    recentScoresPanel(profile.stats)
                }

                // Average score
                HStack {
                    Text("AVG SCORE")
                        .font(.custom(GK.pixelFontName, size: 8))
                        .foregroundColor(GK.Colors.panelBorder.opacity(0.6))
                    Spacer()
                    Text(String(format: "%.1f", profile.stats.averageScore))
                        .font(.custom(GK.pixelFontName, size: 12))
                        .foregroundColor(GK.Colors.panelBorder)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(GK.Colors.panelCream)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(GK.Colors.panelBorder, lineWidth: 2)
                        )
                )

                // Add Friend button
                addFriendButton

                // Block button
                blockButton
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
    }

    // MARK: - Stat Cards

    private func statCard(title: String, value: String, icon: PixelIcon) -> some View {
        VStack(spacing: 8) {
            Image(uiImage: icons.image(for: icon))
                .interpolation(.none)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 22, height: 22)

            Text(value)
                .font(.custom(GK.pixelFontName, size: 18))
                .foregroundColor(GK.Colors.panelBorder)

            Text(title)
                .font(.custom(GK.pixelFontName, size: 7))
                .foregroundColor(GK.Colors.panelBorder.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(GK.Colors.panelCream)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(GK.Colors.panelBorder, lineWidth: 2)
                )
        )
    }

    private func wlRecordPanel(_ stats: PublicPlayerStats) -> some View {
        VStack(spacing: 6) {
            Text("RECORD")
                .font(.custom(GK.pixelFontName, size: 7))
                .foregroundColor(GK.Colors.panelBorder.opacity(0.5))

            HStack(spacing: 4) {
                Text("\(stats.wins)W")
                    .font(.custom(GK.pixelFontName, size: 16))
                    .foregroundColor(GK.Colors.buttonGreen)
                Text("-")
                    .font(.custom(GK.pixelFontName, size: 16))
                    .foregroundColor(GK.Colors.panelBorder.opacity(0.4))
                Text("\(stats.losses)L")
                    .font(.custom(GK.pixelFontName, size: 16))
                    .foregroundColor(Color(red: 0.85, green: 0.25, blue: 0.25))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(GK.Colors.panelCream)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(GK.Colors.panelBorder, lineWidth: 2)
                )
        )
    }

    private func peakEloPanel(_ stats: PublicPlayerStats) -> some View {
        VStack(spacing: 6) {
            Text("PEAK ELO")
                .font(.custom(GK.pixelFontName, size: 7))
                .foregroundColor(GK.Colors.panelBorder.opacity(0.5))

            Text("\(stats.peakElo)")
                .font(.custom(GK.pixelFontName, size: 18))
                .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(GK.Colors.panelCream)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(GK.Colors.panelBorder, lineWidth: 2)
                )
        )
    }

    private func winStreakPanel(_ stats: PublicPlayerStats) -> some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("WIN STREAK")
                    .font(.custom(GK.pixelFontName, size: 8))
                    .foregroundColor(GK.Colors.panelBorder.opacity(0.6))
                HStack(spacing: 6) {
                    Text("🔥")
                        .font(.system(size: 16))
                    Text("\(stats.winStreak)")
                        .font(.custom(GK.pixelFontName, size: 20))
                        .foregroundColor(stats.winStreak > 0
                            ? Color(red: 0.95, green: 0.55, blue: 0.10)
                            : GK.Colors.panelBorder)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("BEST")
                    .font(.custom(GK.pixelFontName, size: 8))
                    .foregroundColor(GK.Colors.panelBorder.opacity(0.6))
                Text("\(stats.bestWinStreak)")
                    .font(.custom(GK.pixelFontName, size: 20))
                    .foregroundColor(GK.Colors.panelBorder)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(GK.Colors.panelCream)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(GK.Colors.panelBorder, lineWidth: 2)
                )
        )
    }

    private func botLadderPanel(_ stats: PublicPlayerStats) -> some View {
        let beaten = stats.beatenBotsCount
        let total = BotCharacter.all.count

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("BOT LADDER")
                    .font(.custom(GK.pixelFontName, size: 8))
                    .foregroundColor(GK.Colors.panelBorder.opacity(0.6))
                Spacer()
                Text("\(beaten)/\(total) BEATEN")
                    .font(.custom(GK.pixelFontName, size: 10))
                    .foregroundColor(beaten == total
                        ? Color(red: 1.0, green: 0.84, blue: 0.0)
                        : GK.Colors.panelBorder)
            }

            HStack(spacing: 3) {
                ForEach(0..<total, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(i < beaten
                            ? GK.Colors.buttonGreen
                            : GK.Colors.panelBorder.opacity(0.15))
                        .frame(height: 14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(i < beaten
                                    ? GK.Colors.buttonGreen.opacity(0.6)
                                    : GK.Colors.panelBorder.opacity(0.08),
                                    lineWidth: 1)
                        )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(GK.Colors.panelCream)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(GK.Colors.panelBorder, lineWidth: 2)
                )
        )
    }

    private func recentScoresPanel(_ stats: PublicPlayerStats) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RECENT")
                .font(.custom(GK.pixelFontName, size: 8))
                .foregroundColor(GK.Colors.panelBorder.opacity(0.6))

            let scores = stats.recentScores
            let maxScore = max(scores.max() ?? 1, 1)

            HStack(alignment: .bottom, spacing: 3) {
                ForEach(scores.indices, id: \.self) { i in
                    let h = CGFloat(scores[i]) / CGFloat(maxScore) * 60
                    RoundedRectangle(cornerRadius: 2)
                        .fill(GK.Colors.buttonGreen)
                        .frame(height: max(h, 4))
                }
            }
            .frame(height: 60)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(GK.Colors.panelCream)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(GK.Colors.panelBorder, lineWidth: 2)
                )
        )
    }

    // MARK: - Action Buttons

    private var addFriendButton: some View {
        Button {
            Task { await addFriend() }
        } label: {
            HStack(spacing: 8) {
                if isAddingFriend {
                    ProgressView().tint(.white)
                } else {
                    pixelIcon(.headToHead, size: 18)
                }
                Text(isAddingFriend ? "SENDING..." : "ADD FRIEND")
                    .font(.custom(GK.pixelFontName, size: 10))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(GK.Colors.buttonGreen)
                    .shadow(color: GK.Colors.buttonGreen.opacity(0.4), radius: 0, x: 0, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.black.opacity(0.3), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .disabled(isAddingFriend)
    }

    private var blockButton: some View {
        Button {
            showBlockConfirm = true
        } label: {
            HStack(spacing: 8) {
                if isBlocking {
                    ProgressView().tint(.white)
                } else {
                    pixelIcon(.cancel, size: 14)
                }
                Text("BLOCK")
                    .font(.custom(GK.pixelFontName, size: 8))
            }
            .foregroundColor(.white.opacity(0.6))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.25))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(GK.Colors.buttonRed.opacity(0.4), lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(isBlocking)
    }

    // MARK: - Helpers

    private func pixelIcon(_ icon: PixelIcon, size: CGFloat) -> some View {
        Image(uiImage: icons.image(for: icon, pixelScale: 3.0))
            .interpolation(.none)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
    }

    // MARK: - Data

    private func loadProfile() async {
        isLoading = true
        errorMessage = nil
        do {
            profile = try await ConvexClient.shared.getPublicProfile(userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func addFriend() async {
        guard let profile else { return }
        isAddingFriend = true
        do {
            try await ConvexClient.shared.sendFriendRequest(toUserId: profile.userId)
            Haptic.friendAction()
        } catch {
            errorMessage = error.localizedDescription
        }
        isAddingFriend = false
    }

    private func blockPlayer() async {
        guard let profile else { return }
        isBlocking = true
        do {
            try await ConvexClient.shared.blockUser(toUserId: profile.userId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isBlocking = false
    }
}

extension Haptic {
    static func friendAction() {
        medium()
    }
}
