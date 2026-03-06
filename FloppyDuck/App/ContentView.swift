import SwiftUI

struct ContentView: View {
    @EnvironmentObject var manager: GameManager

    var body: some View {
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
                    }
                }
        }
        .fullScreenCover(item: $manager.activeGameConfig) { config in
            GameContainerView(config: config)
                .environmentObject(manager)
        }
    }
}
