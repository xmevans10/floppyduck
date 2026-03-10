import SwiftUI

struct ContentView: View {
    @EnvironmentObject var manager: GameManager
    @EnvironmentObject var auth: AuthManager

    var body: some View {
        Group {
            switch auth.authState {
            case .bootstrapping:
                bootstrappingView
            case .onboardingRequired:
                AuthOnboardingView()
            case .authenticated, .failed:
                appNavigation
            }
        }
        .task {
            await auth.bootstrapIdentityIfNeeded()
        }
    }

    private var appNavigation: some View {
        NavigationStack(path: $manager.path) {
            HomeView()
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .multiplayerModes:
                        MultiplayerModesView()
                    case .matchmaking(let mode):
                        MatchmakingView(mode: mode)
                    case .stats:
                        StatsView()
                    case .settings:
                        SettingsView()
                    case .shop:
                        ShopView()
                    case .botLadder:
                        BotLadderView()
                    case .closet:
                        SkinClosetView()
                    case .leaderboard:
                        LeaderboardView()
                    }
                }
        }
        .fullScreenCover(item: $manager.activeGameConfig) { config in
            GameContainerView(config: config)
                .environmentObject(manager)
        }
    }

    private var bootstrappingView: some View {
        ZStack {
            LinearGradient(
                colors: [GK.Colors.skyTop, GK.Colors.skyBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 12) {
                ProgressView()
                    .tint(.white)
                Text("LOADING PROFILE...")
                    .font(.custom(GK.pixelFontName, size: 9))
                    .foregroundColor(.white)
            }
        }
    }
}
