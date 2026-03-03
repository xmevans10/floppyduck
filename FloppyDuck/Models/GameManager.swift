import SwiftUI

/// Central game state manager — coordinates navigation, stats, and match state.
@MainActor
final class GameManager: ObservableObject {
    @Published var navigationPath = NavigationPath()
    @Published var stats = PlayerStats()
    @Published var currentMatch: Match?
    @Published var isSearching = false
    
    // Persisted with UserDefaults
    @AppStorage("bestScore") var bestScore: Int = 0
    @AppStorage("gamesPlayed") var gamesPlayed: Int = 0
    @AppStorage("playerRating") var playerRating: Int = 1000
    @AppStorage("playerWins") var playerWins: Int = 0
    @AppStorage("playerName") var playerName: String = "Player"
    
    func startSoloGame() {
        navigationPath.append(AppRoute.game(.solo))
    }
    
    func startMatchmaking(mode: MatchmakingMode) {
        navigationPath.append(AppRoute.matchmaking(mode))
    }
    
    func reportScore(_ score: Int) {
        gamesPlayed += 1
        if score > bestScore {
            bestScore = score
        }
    }
    
    func reportWin() {
        playerWins += 1
    }
    
    func popToRoot() {
        navigationPath = NavigationPath()
    }
}
