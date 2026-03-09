import SwiftUI

@main
struct FloppyDuckApp: App {
    @StateObject private var gameManager: GameManager
    @StateObject private var authManager: AuthManager

    init() {
        let manager = GameManager()
        let auth = AuthManager(gameManager: manager)
        manager.authManager = auth

        _gameManager = StateObject(wrappedValue: manager)
        _authManager = StateObject(wrappedValue: auth)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(gameManager)
                .environmentObject(authManager)
                .preferredColorScheme(.light)
        }
    }
}
