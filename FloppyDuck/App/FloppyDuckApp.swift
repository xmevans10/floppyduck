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
                // Main app — always mounted so it initialises behind the splash
                ContentView()
                    .environmentObject(gameManager)
                    .environmentObject(authManager)
                    .preferredColorScheme(.light)

                // Splash overlay — removed once finished
                if !splashFinished {
                    SplashView(isFinished: $splashFinished)
                        .ignoresSafeArea()
                        .transition(.identity)   // no extra SwiftUI transition; view handles its own exit
                }
            }
        }
    }
}
