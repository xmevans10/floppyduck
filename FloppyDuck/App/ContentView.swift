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
                    destinationView(for: route)
                        // Solid opaque background covers previous-view bleed during push/pop
                        .background(
                            Color(red: 0.35, green: 0.65, blue: 0.90)
                                .ignoresSafeArea()
                        )
                }
        }
        // Overall stack background so nothing peeks through during any transition
        .background(
            Color(red: 0.35, green: 0.65, blue: 0.90)
                .ignoresSafeArea()
        )
        .fullScreenCover(item: $manager.activeGameConfig) { config in
            GameContainerView(config: config)
                .environmentObject(manager)
        }
    }

    @ViewBuilder
    private func destinationView(for route: AppRoute) -> some View {
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
        case .collection:
            CollectionView()
        case .leaderboard:
            LeaderboardView()
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
