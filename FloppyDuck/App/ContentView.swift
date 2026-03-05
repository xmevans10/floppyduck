import SwiftUI

struct ContentView: View {
    @EnvironmentObject var manager: GameManager

    var body: some View {
        NavigationStack(path: $manager.path) {
            HomeView()
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .game(let config):
                        GameContainerView(config: config)
                    case .matchmaking(let mode):
                        MatchmakingView(mode: mode)
                    case .stats:
                        StatsView()
                    case .settings:
                        SettingsView()
                    }
                }
        }
    }
}
