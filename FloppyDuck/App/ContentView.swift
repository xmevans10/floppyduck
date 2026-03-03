import SwiftUI

struct ContentView: View {
    @EnvironmentObject var gameManager: GameManager
    
    var body: some View {
        NavigationStack(path: $gameManager.navigationPath) {
            HomeView()
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .game(let mode):
                        GameContainerView(mode: mode)
                    case .matchmaking(let mode):
                        MatchmakingView(mode: mode)
                    }
                }
        }
        .tint(.white)
    }
}

enum AppRoute: Hashable {
    case game(GameMode)
    case matchmaking(MatchmakingMode)
}

enum MatchmakingMode: Hashable {
    case quickPlay
    case ranked
}
