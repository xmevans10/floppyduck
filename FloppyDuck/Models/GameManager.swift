import SwiftUI

/// Manages navigation, stats persistence, and game settings.
@MainActor
final class GameManager: ObservableObject {
    @Published var path = NavigationPath()
    @Published var stats: PlayerStats
    @Published var activeGameConfig: GameModeConfig? = nil

    // Settings
    @AppStorage("playerName") var playerName: String = "Player"
    @AppStorage("soundEnabled") var soundEnabled: Bool = true
    @AppStorage("hapticsEnabled") var hapticsEnabled: Bool = true

    init() {
        if let data = UserDefaults.standard.data(forKey: "playerStats"),
           let decoded = try? JSONDecoder().decode(PlayerStats.self, from: data) {
            stats = decoded
        } else {
            stats = PlayerStats()
        }
    }

    func navigate(to route: AppRoute) {
        path.append(route)
    }

    func goHome() {
        path = NavigationPath()
    }

    /// Launch a game via fullScreenCover
    func startGame(_ config: GameModeConfig) {
        activeGameConfig = config
    }

    /// Dismiss the game overlay and return home
    func dismissGame() {
        activeGameConfig = nil
    }

    func recordGame(score: Int, won: Bool? = nil) {
        stats.recordGame(score: score, won: won)
        saveStats()
    }

    func resetStats() {
        stats = PlayerStats()
        saveStats()
    }

    private func saveStats() {
        if let data = try? JSONEncoder().encode(stats) {
            UserDefaults.standard.set(data, forKey: "playerStats")
        }
    }
}
