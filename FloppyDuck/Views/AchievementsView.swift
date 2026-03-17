import SwiftUI

struct AchievementsView: View {
    @EnvironmentObject var manager: GameManager

    @State private var progress: AchievementProgress = AchievementsView.loadProgress()

    private let icons = PixelIconFactory.shared
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    private var unlockedCount: Int {
        progress.unlocked.count
    }

    private var totalCount: Int {
        AchievementId.allCases.count
    }

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
                headerSection

                // Progress summary
                progressSection
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                // Achievement grid
                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(AchievementId.allCases, id: \.rawValue) { achievement in
                            achievementCard(achievement)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 30)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            progress = AchievementsView.loadProgress()
        }
    }

    // MARK: - Persistence

    static func loadProgress() -> AchievementProgress {
        guard let data = UserDefaults.standard.data(forKey: "achievementProgress"),
              let decoded = try? JSONDecoder().decode(AchievementProgress.self, from: data)
        else {
            return AchievementProgress()
        }
        return decoded
    }

    // MARK: - Header

    private var headerSection: some View {
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
            .buttonStyle(.plain)

            Spacer()

            Text("ACHIEVEMENTS")
                .font(.custom(GK.pixelFontName, size: 18))
                .foregroundColor(.white)
                .shadow(color: GK.Colors.pipeBorder, radius: 0, x: 2, y: 2)

            Spacer()

            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    // MARK: - Progress Summary

    private var progressSection: some View {
        VStack(spacing: 10) {
            // Count label
            Text("\(unlockedCount)/\(totalCount) Achievements Unlocked")
                .font(.custom(GK.pixelFontName, size: 8))
                .foregroundColor(.white)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.black.opacity(0.3))
                        .frame(height: 10)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(GK.Colors.buttonGreen)
                        .frame(
                            width: totalCount > 0
                                ? geo.size.width * CGFloat(unlockedCount) / CGFloat(totalCount)
                                : 0,
                            height: 10
                        )
                }
            }
            .frame(height: 10)

            // Bread earned from achievements
            HStack(spacing: 6) {
                Image(uiImage: TextureFactory.shared.breadUIImage(pixelScale: 2.5))
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 18, height: 14)

                Text("\(progress.totalBreadFromAchievements) earned")
                    .font(.custom(GK.pixelFontName, size: 7))
                    .foregroundColor(GK.Colors.breadGold)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.25))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
    }

    // MARK: - Achievement Card

    private func achievementCard(_ achievement: AchievementId) -> some View {
        let isUnlocked = progress.unlocked.contains(achievement)
        let isHidden = achievement.isSecret && !isUnlocked

        return VStack(spacing: 6) {
            // Pixel icon / Lock
            Image(uiImage: PixelIconFactory.shared.image(for: isHidden ? .questionMark : achievement.pixelIcon))
                .interpolation(.none)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 28, height: 28)
                .frame(height: 36)

            // Title
            Text(isHidden ? "???" : achievement.title.uppercased())
                .font(.custom(GK.pixelFontName, size: 7))
                .foregroundColor(isUnlocked ? GK.Colors.panelBorder : GK.Colors.panelBorder.opacity(0.5))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)

            // Description
            Text(isHidden ? "Keep playing to discover" : achievement.description)
                .font(.custom(GK.pixelFontName, size: 5))
                .foregroundColor(GK.Colors.panelBorder.opacity(isUnlocked ? 0.6 : 0.35))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.7)

            Spacer().frame(height: 2)

            // Status badge
            if isUnlocked {
                HStack(spacing: 3) {
                    Image(uiImage: PixelIconFactory.shared.image(for: .checkmark))
                        .interpolation(.none)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 10, height: 10)
                    Text("UNLOCKED")
                        .font(.custom(GK.pixelFontName, size: 5))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(GK.Colors.buttonGreen)
                )
            } else {
                HStack(spacing: 3) {
                    Image(uiImage: PixelIconFactory.shared.image(for: .lock))
                        .interpolation(.none)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 10, height: 10)
                    Text("LOCKED")
                        .font(.custom(GK.pixelFontName, size: 5))
                        .foregroundColor(GK.Colors.panelBorder.opacity(0.4))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.black.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(GK.Colors.panelBorder.opacity(0.15), lineWidth: 1)
                        )
                )
            }

            // Bread reward
            if !isHidden {
                HStack(spacing: 3) {
                    Image(uiImage: TextureFactory.shared.breadUIImage(pixelScale: 2.0))
                        .interpolation(.none)
                        .resizable()
                        .frame(width: 12, height: 10)
                    Text("+\(achievement.breadReward)")
                        .font(.custom(GK.pixelFontName, size: 5))
                        .foregroundColor(isUnlocked ? GK.Colors.breadGold : GK.Colors.breadGold.opacity(0.4))
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isUnlocked ? GK.Colors.panelCream : GK.Colors.panelCream.opacity(0.6))
                .shadow(color: Color.black.opacity(0.1), radius: 0, x: 0, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isUnlocked ? GK.Colors.buttonGreen : GK.Colors.panelBorder.opacity(0.3),
                    lineWidth: isUnlocked ? 3 : 2
                )
        )
        .opacity(isUnlocked ? 1.0 : 0.7)
    }
}
