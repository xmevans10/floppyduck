import SwiftUI
import Sentry

@main
struct FloppyDuckApp: App {
    @StateObject private var gameManager: GameManager
    @StateObject private var authManager: AuthManager
    @State private var splashFinished = false

    init() {

        SentrySDK.start { options in
            options.dsn = "https://e7671e36f866d70b8620cf0d6ba9d847@o4510732962037760.ingest.us.sentry.io/4511135319719936"
            options.tracesSampleRate = 1.0
            options.enableAutoSessionTracking = true
            options.attachScreenshot = true
            options.enableUserInteractionTracing = true
            #if DEBUG
            options.debug = true
            options.environment = "development"
            #else
            options.environment = "production"
            #endif
        }

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
