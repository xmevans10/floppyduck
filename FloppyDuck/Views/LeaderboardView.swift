import SwiftUI

struct LeaderboardView: View {
    @EnvironmentObject var manager: GameManager

    @State private var entries: [LeaderboardEntry] = []
    @State private var isLoading: Bool = true
    @State private var errorMessage: String? = nil

    private let icons = PixelIconFactory.shared

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [GK.Colors.skyTop, GK.Colors.skyBottom],
                startPoint: .top,
                endPoint: .bottom
            )
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
                            .background(Circle().fill(Color.black.opacity(0.15)))
                    }
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
                    }
                    .padding(30)
                    Spacer()
                } else if entries.isEmpty {
                    Spacer()
                    Text("NO RANKINGS YET")
                        .font(.custom(GK.pixelFontName, size: 10))
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 8) {
                            ForEach(entries) { entry in
                                leaderboardRow(entry)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 14)
                        .padding(.bottom, 30)
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .task {
            await loadLeaderboard()
        }
    }

    // MARK: - Load Data

    private func loadLeaderboard() async {
        isLoading = true
        errorMessage = nil
        do {
            entries = try await ConvexClient.shared.getLeaderboard(limit: 50)
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    // MARK: - Row

    private func leaderboardRow(_ entry: LeaderboardEntry) -> some View {
        let isCurrentPlayer = entry.username.lowercased() == manager.playerName.lowercased()

        return HStack(spacing: 12) {
            // Rank
            Text("#\(entry.rank)")
                .font(.custom(GK.pixelFontName, size: 12))
                .foregroundColor(rankColor(entry.rank))
                .frame(width: 44, alignment: .leading)

            // Username
            Text(entry.username)
                .font(.custom(GK.pixelFontName, size: 10))
                .foregroundColor(isCurrentPlayer ? GK.Colors.scoreYellow : GK.Colors.panelBorder)
                .lineLimit(1)

            Spacer()

            // Rating
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
    }

    private func rankColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return Color(red: 1.0, green: 0.84, blue: 0.0)   // gold
        case 2: return Color(red: 0.75, green: 0.75, blue: 0.80)  // silver
        case 3: return Color(red: 0.80, green: 0.50, blue: 0.20)  // bronze
        default: return GK.Colors.panelBorder.opacity(0.6)
        }
    }
}
