import SwiftUI

struct StatsView: View {
    @EnvironmentObject var manager: GameManager
    private let icons = PixelIconFactory.shared

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [GK.Colors.skyTop, GK.Colors.skyBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                // Header
                HStack {
                    backButton
                    Spacer()
                    Text("STATS")
                        .font(.custom(GK.pixelFontName, size: 20))
                        .foregroundColor(.white)
                        .shadow(color: GK.Colors.pipeBorder, radius: 0, x: 2, y: 2)
                    Spacer()
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                ScrollView {
                    VStack(spacing: 16) {
                        // Big stat cards row
                        HStack(spacing: 12) {
                            statCard(title: "BEST", value: "\(manager.stats.bestScore)", icon: .trophy)
                            statCard(title: "GAMES", value: "\(manager.stats.gamesPlayed)", icon: .play)
                        }

                        HStack(spacing: 12) {
                            statCard(title: "WIN %", value: String(format: "%.0f%%", manager.stats.winRate * 100), icon: .headToHead)
                            statCard(title: "ELO", value: "\(manager.stats.elo)", icon: .classic)
                        }

                        // Bread
                        HStack(spacing: 10) {
                            Image(uiImage: TextureFactory.shared.breadUIImage(pixelScale: 3.0))
                                .interpolation(.none)
                                .resizable()
                                .frame(width: 28, height: 22)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("BREAD")
                                    .font(.custom(GK.pixelFontName, size: 8))
                                    .foregroundColor(GK.Colors.panelBorder.opacity(0.6))
                                Text("\(manager.stats.bread)")
                                    .font(.custom(GK.pixelFontName, size: 16))
                                    .foregroundColor(GK.Colors.breadGold)
                            }

                            Spacer()
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

                        // Recent scores chart
                        if !manager.stats.recentScores.isEmpty {
                            recentScoresChart
                        }

                        // Leaderboard button
                        Button {
                            SoundManager.shared.play(.button)
                            manager.navigate(to: .leaderboard)
                        } label: {
                            HStack(spacing: 10) {
                                Image(uiImage: icons.image(for: .trophy))
                                    .interpolation(.none)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 22, height: 22)
                                Text("LEADERBOARD")
                                    .font(.custom(GK.pixelFontName, size: 10))
                                    .foregroundColor(.white)
                                Spacer()
                                Image(uiImage: icons.image(for: .play, pixelScale: 2.0))
                                    .interpolation(.none)
                                    .resizable()
                                    .frame(width: 14, height: 14)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(GK.Colors.buttonBlue)
                                    .shadow(color: GK.Colors.buttonBlue.opacity(0.5), radius: 0, x: 0, y: 3)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.black.opacity(0.3), lineWidth: 2)
                            )
                        }
                        .buttonStyle(.plain)

                        // Average score
                        HStack {
                            Text("AVG SCORE")
                                .font(.custom(GK.pixelFontName, size: 8))
                                .foregroundColor(GK.Colors.panelBorder.opacity(0.6))
                            Spacer()
                            Text(String(format: "%.1f", manager.stats.averageScore))
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
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
        }
        .navigationBarHidden(true)
    }

    // MARK: - Stat Card

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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }

    // MARK: - Recent Scores

    private var recentScoresChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RECENT")
                .font(.custom(GK.pixelFontName, size: 8))
                .foregroundColor(GK.Colors.panelBorder.opacity(0.6))

            let scores = manager.stats.recentScores
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

    // MARK: - Back

    private var backButton: some View {
        Button {
            SoundManager.shared.play(.button)
            manager.goHome()
        } label: {
            Image(uiImage: icons.image(for: .back))
                .interpolation(.none)
                .resizable()
                .frame(width: 28, height: 28)
                .padding(8)
                .background(Circle().fill(Color.white.opacity(0.2)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back")
    }
}
