import SwiftUI

@main
struct FloppyDuckApp: App {
    @StateObject private var gameManager: GameManager
    @StateObject private var authManager: AuthManager
    @State private var splashFinished = false

    init() {
        let manager = GameManager()
        let auth = AuthManager(gameManager: manager)
        manager.authManager = auth

        _gameManager = StateObject(wrappedValue: manager)
        _authManager = StateObject(wrappedValue: auth)
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                Color.black.ignoresSafeArea()

                if splashFinished {
                    ContentView()
                        .environmentObject(gameManager)
                        .environmentObject(authManager)
                        .preferredColorScheme(.light)
                        .transition(.opacity)
                }

                if !splashFinished {
                    SplashView(isFinished: $splashFinished)
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.2), value: splashFinished)
        }
    }
}
